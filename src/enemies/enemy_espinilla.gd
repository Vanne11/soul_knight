extends Enemy
class_name EnemyEspinilla

## Espinilla Reventona: casi estatica, brota del suelo y se va inflando. Si te acercas (o
## pasa el tiempo) se pone roja, tiembla y REVIENTA en un anillo de gotitas lentas de crema,
## dejando un charco que no daña. Si la matas antes de que reviente, hace "pop" sin anillo:
## solo el charco. Control de zona: no persigue, no pega al roce y no viene en enjambre.

const GOTA_SCENE := preload("res://src/enemies/projectile_gota.tscn")
const SPROUT_TIME := 0.6        # brota del suelo (sin avisar todavia)
const TRIGGER_RANGE := 105.0    # si te acercas tanto, empieza a inflarse
const FUSE_MIN := 4.5           # y si no te acercas, revienta sola entre FUSE_MIN y FUSE_MAX s
const FUSE_MAX := 7.0
const INFLATE_TIME := 1.1       # el aviso: se infla, se pone roja y tiembla
const RING_DROPS := 10
const DROP_SPEED := 130.0       # lento y legible
const DROP_DAMAGE_MULT := 0.8   # sobre el daño generico del piso

enum Phase { SPROUT, DORMANT, INFLATE, DONE }
var phase: Phase = Phase.SPROUT
var _t := SPROUT_TIME
var _fuse := 0.0
var _burst_by_time := false


func _ready() -> void:
	super()
	_fuse = RNG.randf_range(FUSE_MIN, FUSE_MAX)
	animated_sprite.play("sprout")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
	match phase:
		Phase.SPROUT:
			_t -= delta
			if _t <= 0.0:
				phase = Phase.DORMANT
				animated_sprite.play("idle")
		Phase.DORMANT:
			_fuse -= delta
			var near: bool = target != null and global_position.distance_to(target.global_position) <= TRIGGER_RANGE
			if near or _fuse <= 0.0:
				_start_inflate()
		Phase.INFLATE:
			_t -= delta
			var p := clampf(1.0 - _t / INFLATE_TIME, 0.0, 1.0)
			animated_sprite.frame = mini(3, int(p * 4.0))
			animated_sprite.offset.x = RNG.randf_range(-1.0, 1.0) * (0.5 + 2.5 * p)
			animated_sprite.scale = Vector2.ONE * (1.0 + 0.06 * sin(p * 40.0) * p)
			if p > 0.55 and int(_t * 14.0) % 2 == 0:
				animated_sprite.modulate = Color(1.7, 1.2, 1.2)  # parpadeo: ya va
			else:
				animated_sprite.modulate = Color.WHITE
			if _t <= 0.0:
				_burst()


func _start_inflate() -> void:
	phase = Phase.INFLATE
	_t = INFLATE_TIME
	animated_sprite.animation = "attack"
	animated_sprite.stop()
	animated_sprite.frame = 0
	Sound.play("crack")


## Reventon por tiempo o cercania: anillo de gotitas y a morir (sin soltar nada raro).
func _burst() -> void:
	_burst_by_time = true
	phase = Phase.DONE
	Sound.play("enemy_shoot")
	HitFx.shake(0.3)
	var off := RNG.randf() * TAU
	for i in RING_DROPS:
		var proj := GOTA_SCENE.instantiate()
		proj.global_rotation = off + TAU * i / RING_DROPS
		proj.damage = damage * DROP_DAMAGE_MULT
		proj.speed = DROP_SPEED
		proj.projectile_owner = self
		_spawn_container().add_child(proj)
		proj.global_position = global_position + Vector2(0, -8)
	die(null)


func take_damage(amount: float, source: Node = null, _kb: Vector2 = Vector2.ZERO) -> float:
	# casi estatica: nada la empuja
	return super.take_damage(amount, source, Vector2.ZERO)


## Muerte: por tiempo ("burst") o a tiros ("death", pop seguro sin anillo). Siempre deja charco.
func die(killer: Node = null) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	animated_sprite.offset.x = 0.0
	animated_sprite.scale = Vector2.ONE
	animated_sprite.modulate = Color.WHITE
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(7, false)  # huecos (capa 64): el cuerpo sigue la misma regla que con los muros
	_make_puddle()
	if not _burst_by_time:
		get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -34), tr("FX_POP_SAFE"), Color("ffd0dc"))
		Sound.play("crack")
	animated_sprite.play("burst" if _burst_by_time else "death")
	await get_tree().create_timer(0.5).timeout
	_drop_loot()
	get_node("/root/GlobalEvents").enemy_killed.emit(self, killer)
	get_node("/root/RunManager").total_enemies_killed += 1
	queue_free()


## Charco de crema: lo registra WorldFx (deja huellas al pisarlo; no daña).
func _make_puddle() -> void:
	var fx := get_tree().get_first_node_in_group("world_fx")
	if fx and fx.has_method("add_puddle"):
		fx.add_puddle(global_position + Vector2(0, 2), 30.0 if _burst_by_time else 22.0)
