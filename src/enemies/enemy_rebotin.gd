extends EnemySwarmer
class_name EnemyRebotin

## REBOTIN (esbirro del Testiculo Primordial). Una bolita de pinball con patas: se queda quieta y
## tiembla (0,6 s, aviso), sale rodando recto hacia donde estabas y REBOTA en los muros (en cada
## rebote se curva un poco hacia ti). Tras 3 rebotes se marea: 1,6 s inofensiva y brillando, el
## momento de romperla. Rodando hace dano de contacto. Mientras el jefe canaliza su cura, rueda
## mas rapido. Matarla suelta a veces un corazon chico.

enum R { WINDUP, ROLL, DIZZY }

const BALL := Color(1.0, 0.92, 0.75)
const ROLL_SPEED := 250.0
const WINDUP_T := 0.6
const DIZZY_T := 1.6

var r_state := R.WINDUP
var r_t := WINDUP_T
var r_dir := Vector2.RIGHT
var r_bounces := 0
var r_hit_cd := 0.0


func _init() -> void:
	personality = "none"


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.3}]
	super()
	animated_sprite.self_modulate = BALL
	add_to_group("rebotin")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return
	r_t -= delta
	r_hit_cd = maxf(0.0, r_hit_cd - delta)
	var to_t: Vector2 = target.global_position - global_position
	var chan := false
	var b := get_tree().get_first_node_in_group("boss")
	if b != null:
		chan = bool(b.get("_channeling"))
	match r_state:
		R.WINDUP:
			velocity = Vector2.ZERO
			r_dir = to_t.normalized()
			animated_sprite.modulate = Color(2.2, 2.0, 1.4) if int(r_t * 20.0) % 2 == 0 else Color.WHITE
			animated_sprite.offset.x = sin(r_t * 90.0) * 2.0
			if r_t <= 0.0:
				r_state = R.ROLL
				r_t = 4.0
				animated_sprite.modulate = Color.WHITE
				animated_sprite.offset.x = 0.0
		R.ROLL:
			velocity = r_dir * ROLL_SPEED * (1.3 if chan else 1.0)
			animated_sprite.rotation += delta * 14.0 * (1.0 if r_dir.x >= 0.0 else -1.0)
			if r_hit_cd <= 0.0 and to_t.length() < 32.0 and target.has_method("receive_hit"):
				if target.receive_hit(damage):
					r_hit_cd = 0.9
			if r_t <= 0.0:
				_dizzy()
		R.DIZZY:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			animated_sprite.rotation = sin(r_t * 12.0) * 0.25
			animated_sprite.modulate = Color(1.4, 1.4, 1.0) if int(r_t * 8.0) % 2 == 0 else Color.WHITE
			if r_t <= 0.0:
				animated_sprite.rotation = 0.0
				animated_sprite.modulate = Color.WHITE
				r_state = R.WINDUP
				r_t = WINDUP_T
				r_bounces = 0
	move_and_slide()
	if r_state == R.ROLL and get_slide_collision_count() > 0:
		var n := get_last_slide_collision().get_normal()
		r_dir = r_dir.bounce(n).normalized()
		r_dir = r_dir.slerp(to_t.normalized(), 0.3).normalized()
		r_bounces += 1
		if r_bounces >= 3:
			_dizzy()
	_update_animation(to_t)


func _dizzy() -> void:
	r_state = R.DIZZY
	r_t = DIZZY_T
	animated_sprite.rotation = 0.0
