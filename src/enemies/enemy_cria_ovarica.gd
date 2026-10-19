extends EnemySwarmer
class_name EnemyCriaOvarica

## CRIA OVARICA (esbirro de Su Majestad Ovaria II; nace cuando un huevo eclosiona). No pega por
## contacto: llora a distancia (se queda quieta y brilla 0.6 s) y suelta un lagrimon lento.
## Ayuda a la reina: si la dejas viva ~9 s vuelve CORRIENDO con mama y la cura (1,2 % de vida).
## Si la revientas antes, suelta un corazon chico a veces.

enum C { WANDER, WINDUP, RECOVER, HOME }

const PINK := Color(1.0, 0.45, 0.7)
const PROJECTILE := preload("res://src/enemies/projectile_enemy.tscn")
const HOME_AFTER := 9.0
const HEAL_PCT := 0.012

var c_state := C.WANDER
var c_t := 1.5
var _age := 0.0
var _dir := 1.0


func _init() -> void:
	personality = "none"


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.25}]
	super()
	animated_sprite.self_modulate = PINK
	add_to_group("cria_ovarica")
	_dir = 1.0 if RNG.randf() < 0.5 else -1.0
	c_t = RNG.randf_range(1.0, 2.0)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return
	_age += delta
	c_t -= delta
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	if _age >= HOME_AFTER and c_state != C.HOME:
		c_state = C.HOME
		animated_sprite.modulate = Color.WHITE
		_float(tr("CRIA_HOME"))
	match c_state:
		C.WANDER:
			var radial := clampf((d - 230.0) / 80.0, -1.0, 1.0)
			velocity = (to_t.normalized() * radial + to_t.normalized().orthogonal() * _dir * 0.7).normalized() * move_speed
			if c_t <= 0.0 and d < 460.0:
				c_state = C.WINDUP
				c_t = 0.6
		C.WINDUP:
			velocity = Vector2.ZERO
			animated_sprite.modulate = Color(2.2, 1.5, 1.9) if int(c_t * 20.0) % 2 == 0 else Color.WHITE
			if c_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				_cry()
				c_state = C.RECOVER
				c_t = 0.8
		C.RECOVER:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			if c_t <= 0.0:
				c_state = C.WANDER
				c_t = RNG.randf_range(2.0, 3.0)
				_dir = -_dir
		C.HOME:
			var b := get_tree().get_first_node_in_group("boss")
			if b == null or not is_instance_valid(b):
				c_state = C.WANDER
			else:
				var to_b: Vector2 = b.global_position - global_position
				velocity = to_b.normalized() * move_speed * 1.9
				if to_b.length() < 40.0:
					_reabsorb(b)
	_update_animation(to_t)
	move_and_slide()


func _cry() -> void:
	var p := PROJECTILE.instantiate()
	p.damage = damage
	p.speed = 190.0
	p.projectile_owner = self
	p.lifetime = 5.0
	p.tint = PINK
	_spawn_container().add_child(p)
	var ang: float = (target.global_position - global_position).angle()
	p.global_rotation = ang
	p.global_position = global_position + Vector2.RIGHT.rotated(ang) * 18.0 + Vector2(0, -10)
	Sound.play("enemy_shoot")


func _reabsorb(b: Node) -> void:
	if state == State.DEAD:
		return
	if b is EnemyBoss and b.state != EnemyBoss.State.DEAD and not b._channeling:
		b.current_health = minf(b.max_health, b.current_health + b.max_health * HEAL_PCT)
		b._emit_health()
		b._float_text(tr("CRIA_HEAL"), Color("8fe08f"), Vector2(0, -150))
	state = State.DEAD
	queue_free()


func _float(text: String) -> void:
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -40), text, PINK)
