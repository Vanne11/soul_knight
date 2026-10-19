extends EnemySwarmer
class_name EnemyPelusaEstatica

## PELUSA ESTATICA (esbirro de La Afeitadora). Lo que queda en el cabezal: un mechon cargado de
## electricidad estatica que flota hacia ti. Cuando esta cerca se QUEDA QUIETA, se eriza y carga un
## anillo (0,65 s, borde rojizo que se cierra); luego descarga una chispa en area. Fuera del anillo
## no pasa nada: basta con apartarse. Mientras La Afeitadora canaliza su cura, flota mas rapido.
## Matarla suelta a veces un corazon chico.

enum P { CHASE, CHARGE, ZAP, RECOVER }

const RING_R := 84.0
const CHARGE_T := 0.65

var p_state := P.CHASE
var p_t := 0.0
var p_cd := 1.2


func _init() -> void:
	personality = "none"


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.3}]
	super()
	add_to_group("pelusa_estatica")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return
	p_t -= delta
	p_cd = maxf(0.0, p_cd - delta)
	_wiggle += delta * 7.0
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	var chan := false
	var b := get_tree().get_first_node_in_group("boss")
	if b != null:
		chan = bool(b.get("_channeling"))
	match p_state:
		P.CHASE:
			var sep := Vector2.ZERO
			for o in get_tree().get_nodes_in_group("pelusa_estatica"):
				if o != self and is_instance_valid(o):
					var diff: Vector2 = global_position - o.global_position
					if diff.length() < 55.0 and diff.length() > 0.1:
						sep += diff.normalized()
			var dir := (to_t.normalized() + sep * 0.7 + to_t.normalized().orthogonal() * sin(_wiggle) * 0.6).normalized()
			velocity = dir * move_speed * (1.3 if chan else 1.0)
			if d < RING_R * 1.5 and p_cd <= 0.0:
				p_state = P.CHARGE
				p_t = CHARGE_T
		P.CHARGE:
			velocity = Vector2.ZERO
			animated_sprite.modulate = Color(1.8, 1.9, 2.2) if int(p_t * 22.0) % 2 == 0 else Color.WHITE
			animated_sprite.offset.x = sin(p_t * 90.0) * 2.0
			if p_t <= 0.0:
				p_state = P.ZAP
				p_t = 0.18
				animated_sprite.modulate = Color.WHITE
				animated_sprite.offset.x = 0.0
				Sound.play("crack")
				if target.global_position.distance_to(global_position) < RING_R and target.has_method("receive_hit"):
					target.receive_hit(damage)
		P.ZAP:
			velocity = Vector2.ZERO
			if p_t <= 0.0:
				p_state = P.RECOVER
				p_t = 0.9
				p_cd = 2.4
		P.RECOVER:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			if p_t <= 0.0:
				p_state = P.CHASE
	_pelusa_anim(to_t)
	queue_redraw()
	move_and_slide()


## Cuadros propios (tools/gen_afeitadora_art.py): flota, se eriza al cargar, aplasta al descargar.
func _pelusa_anim(to_t: Vector2) -> void:
	var anim := &"idle"
	match p_state:
		P.CHARGE:
			anim = &"charge"
		P.ZAP:
			anim = &"zap"
		_:
			anim = &"walk" if velocity.length() > 10.0 else &"idle"
	if animated_sprite.animation != anim or not animated_sprite.is_playing():
		animated_sprite.play(anim)
	if absf(to_t.x) > 1.0:
		animated_sprite.flip_h = to_t.x < 0.0


func _draw() -> void:
	if state == State.DEAD:
		return
	var c := Vector2(0, -8)
	if p_state == P.CHARGE:
		var k := 1.0 - clampf(p_t / CHARGE_T, 0.0, 1.0)
		draw_circle(c, RING_R * k, Color(0.9, 0.2, 0.15, 0.10 + 0.18 * k))
		draw_arc(c, RING_R, 0.0, TAU, 40, Color(0.85, 0.15, 0.12, 0.85), 2.5)
	elif p_state == P.ZAP:
		draw_circle(c, RING_R, Color(0.75, 0.9, 1.0, 0.5))
		draw_arc(c, RING_R, 0.0, TAU, 40, Color(0.5, 0.75, 1.0, 0.9), 3.0)
