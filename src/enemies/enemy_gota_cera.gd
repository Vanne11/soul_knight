extends EnemySwarmer
class_name EnemyGotaCera

## GOTITA DE CERA (esbirro de Doña Cera). Persigue, AVISA (se queda quieta y brilla 0.45 s), salta
## sobre ti y si te alcanza se te PEGA: te ralentiza mientras sigas con ella encima (un dash o
## matarla te libera) y te empuja hacia el charco de cera mas cercano. Al morir se funde en un
## charquito que quema un momento. A veces suelta un corazon chico. Ayuda al jefe: frena al que
## va a por la tira de la cura.

enum G { CHASE, WINDUP, LEAP, STUCK, RECOVER }

const WAX := Color(1.0, 0.78, 0.3)
const SLOW := 0.75
const SLOW_SECS := 0.6

var g_state := G.CHASE
var g_t := 0.0
var g_dir := Vector2.RIGHT
var g_cd := 1.0
var _stuck_off := Vector2.ZERO


func _init() -> void:
	personality = "none"


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.2}]
	super()
	animated_sprite.self_modulate = WAX
	add_to_group("gota_cera")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return
	g_t -= delta
	g_cd = maxf(0.0, g_cd - delta)
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	var chan := false
	var b := get_tree().get_first_node_in_group("boss")
	if b != null:
		chan = bool(b.get("_channeling"))
	match g_state:
		G.CHASE:
			var sp := move_speed * (1.25 if chan else 1.0)
			var sep := Vector2.ZERO
			for o in get_tree().get_nodes_in_group("gota_cera"):
				if o != self and is_instance_valid(o):
					var diff: Vector2 = global_position - o.global_position
					if diff.length() < 50.0 and diff.length() > 0.1:
						sep += diff.normalized()
			velocity = (to_t.normalized() + sep * 0.8 + to_t.normalized().orthogonal() * sin(_wiggle) * 0.3).normalized() * sp
			_wiggle += delta * 9.0
			if d < 135.0 and g_cd <= 0.0:
				g_state = G.WINDUP
				g_t = 0.45
				g_dir = to_t.normalized()
		G.WINDUP:
			velocity = Vector2.ZERO
			if g_t > 0.12:
				g_dir = to_t.normalized()
			animated_sprite.modulate = Color(2.2, 2.0, 1.2) if int(g_t * 20.0) % 2 == 0 else Color.WHITE
			if g_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				g_state = G.LEAP
				g_t = 0.28
				_hit_done = false
		G.LEAP:
			velocity = g_dir * 430.0
			if not _hit_done and d < 34.0 and target.has_method("receive_hit"):
				_hit_done = true
				if target.receive_hit(damage):
					_attach()
				else:
					_end_leap()  # esquivada (dash o invulnerable): no se pega
			if g_state == G.LEAP and g_t <= 0.0:
				_end_leap()
		G.STUCK:
			if bool(target.get("is_dashing")):
				_detach(1.8)
			else:
				var want: Vector2 = target.global_position + _stuck_off
				velocity = (want - global_position) * 12.0
				_apply_slow()
				if g_t <= 0.0:
					_detach(2.2)
		G.RECOVER:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			if g_t <= 0.0:
				g_state = G.CHASE
	_update_animation(to_t)
	move_and_slide()


func _end_leap() -> void:
	g_state = G.RECOVER
	g_t = 0.8
	g_cd = 2.2


func _attach() -> void:
	g_state = G.STUCK
	g_t = 3.2
	_stuck_off = Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * 18.0
	# empujon hacia el charco de cera mas cercano (te lleva a su terreno)
	var best: Node2D = null
	var bd := 320.0
	for w in get_tree().get_nodes_in_group("cera_wax"):
		if w is WaxBlock and w.phase in [WaxBlock.Ph.BURN, WaxBlock.Ph.COOL]:
			var dd: float = w.global_position.distance_to(target.global_position)
			if dd < bd:
				bd = dd
				best = w
	if best != null and target is CharacterBody2D:
		(target as CharacterBody2D).move_and_collide((best.global_position - target.global_position).normalized() * 46.0)


func _detach(cd: float) -> void:
	g_state = G.RECOVER
	g_t = 0.6
	g_cd = cd
	velocity = (global_position - target.global_position).normalized() * 160.0


## Ralentizacion al estilo del afijo Pegajoso, con su propia marca para no pisarse con el.
func _apply_slow() -> void:
	var ps := get_node("/root/PlayerStats")
	if ps.has_item_immunity("slow"):
		return
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.get("defense") != null and pl.defense.floor_clean():
		return  # toallita: la cera resbala
	if not ps.has_meta("gota_on"):
		ps.speed_modifier *= SLOW
		ps.set_meta("gota_on", true)
		ps.get_tree().create_timer(SLOW_SECS).timeout.connect(GotaSlow.unstick.bind(ps))
	ps.set_meta("gota_until", Time.get_ticks_msec() + int(SLOW_SECS * 1000.0))


func die(killer: Node = null) -> void:
	if state != State.DEAD:
		var b := get_tree().get_first_node_in_group("boss")
		if b != null and b.has_method("wax_spill"):
			b.wax_spill(global_position)
	super(killer)


## Atada al PlayerStats (no a la gotita): se restaura aunque ya no exista.
class GotaSlow:
	static func unstick(ps: Node) -> void:
		if not is_instance_valid(ps) or not ps.has_meta("gota_on"):
			return
		var left := int(ps.get_meta("gota_until", 0)) - Time.get_ticks_msec()
		if left > 0:
			ps.get_tree().create_timer(left / 1000.0 + 0.02).timeout.connect(unstick.bind(ps))
			return
		ps.speed_modifier /= EnemyGotaCera.SLOW
		ps.remove_meta("gota_on")
