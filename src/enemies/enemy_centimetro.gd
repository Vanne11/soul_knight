extends EnemySwarmer
class_name EnemyCentimetro

## CENTIMETRO (esbirro de Dona Regla). Una regla chiquita que te MIDE: se coloca a ~210 px y copia
## tu distancia (si te acercas o te alejas, ajusta). Cada pocos segundos AVISA (se frena, brilla 0.75 s y
## marca una linea con rayitas hacia ti) y baja la regla. No pega por contacto. Ayuda a la jefa:
## mientras hay centimetros vivos, su medicion de "misma distancia" corre mas rapido.
## Matarlo suelta a veces un corazon chico.

enum C { POSE, AIM, RECOVER }

const RED := Color(0.95, 0.22, 0.28)
const REACH := 380.0

var c_state := C.POSE
var c_t := 0.0
var c_cd := 2.0
var c_side := 1.0
var _dir := Vector2.RIGHT
var _line: RulerZone = null


func _init() -> void:
	personality = "none"


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.3}]
	super()
	animated_sprite.self_modulate = Color(1.0, 0.7, 0.7)
	add_to_group("centimetro")
	c_side = 1.0 if RNG.randf() < 0.5 else -1.0
	c_cd = RNG.randf_range(1.6, 3.4)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return
	c_t -= delta
	c_cd = maxf(0.0, c_cd - delta)
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	match c_state:
		C.POSE:
			# mantiene ~210 px de ti y se desliza de lado: te "mide" desde todos los angulos
			var radial := clampf((d - 210.0) / 70.0, -1.0, 1.0)
			var dir := to_t.normalized() * radial + to_t.normalized().orthogonal() * c_side * 0.7
			velocity = dir.normalized() * move_speed + _separation() * 50.0
			if c_cd <= 0.0 and d < 430.0:
				_start_aim(to_t)
		C.AIM:
			velocity = Vector2.ZERO
			if c_t > 0.2:
				_dir = to_t.normalized()
				_place_line()
			animated_sprite.modulate = Color(2.2, 1.2, 1.2) if int(c_t * 20.0) % 2 == 0 else Color.WHITE
			if c_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				_strike_line()
				c_state = C.RECOVER
				c_t = 1.0
		C.RECOVER:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			if c_t <= 0.0:
				c_state = C.POSE
				c_cd = RNG.randf_range(3.0, 4.5)
				c_side = -c_side
	_update_animation(to_t)
	move_and_slide()


func _start_aim(to_t: Vector2) -> void:
	c_state = C.AIM
	c_t = 0.75
	_dir = to_t.normalized()
	_line = RulerZone.bar(global_position, Vector2(REACH, 26.0), 0.0, 0.75, 0.2, damage, RED)
	_spawn_container().add_child(_line)
	_place_line()


func _place_line() -> void:
	if is_instance_valid(_line):
		_line.global_position = global_position + _dir * REACH * 0.5
		_line.rotation = _dir.angle()


## La zona ya esta en su aviso: la dejamos activar donde esta (el aviso dura justo lo que el brillo).
func _strike_line() -> void:
	Sound.play("crack")


func _separation() -> Vector2:
	var sep := Vector2.ZERO
	for o in get_tree().get_nodes_in_group("centimetro"):
		if o != self and is_instance_valid(o):
			var diff: Vector2 = global_position - o.global_position
			if diff.length() < 70.0 and diff.length() > 0.1:
				sep += diff.normalized()
	return sep


func die(killer: Node = null) -> void:
	if state != State.DEAD and is_instance_valid(_line) and _line.phase == 0:
		_line.dismiss()
	super(killer)
