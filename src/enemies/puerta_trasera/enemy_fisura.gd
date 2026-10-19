extends EnemyPtBase
class_name EnemyFisura

## FISURA FINA (PT-04/05). Rapida y delgada: zigzaguea hacia ti dejando GRIETAS en el suelo (aviso tenue 0,45 s y luego
## queman un rato) y cada tanto AVISA (se agacha y se pone naranja 0,55 s, con una linea de la direccion) y se lanza
## en un tiron recto dejando una estela de grietas. Esquivar = no pisar sus rajas y apartarse de la linea.
## Moraleja: es pequeña pero duele; con fibra, agua y calma suele cerrar sola.

enum S { RUN, WINDUP, DASH, REST }

const ORANGE := Color(1.0, 0.55, 0.2)

var st := S.RUN
var st_t := 1.6
var _crack_t := 0.35
var _wob := 0.0
var _dash_dir := Vector2.RIGHT
var _line: Line2D = null


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.25}]
	move_speed = 210.0
	super()
	add_to_group("fisura")
	st_t = RNG.randf_range(1.3, 2.2)


func _physics_process(delta: float) -> void:
	if state == State.DEAD or not _has_target():
		return
	st_t -= delta
	_wob += delta * 9.0
	var to_t: Vector2 = target.global_position - global_position
	match st:
		S.RUN:
			var dir := to_t.normalized()
			velocity = (dir + dir.orthogonal() * sin(_wob) * 0.9).normalized() * move_speed
			_crack_t -= delta
			if _crack_t <= 0.0 and velocity.length() > 20.0:
				_crack_t = 0.4
				_leave_crack(velocity.angle() + PI * 0.5)
			_play(&"walk")
			if st_t <= 0.0 and to_t.length() < 380.0:
				st = S.WINDUP
				st_t = 0.55
				_dash_dir = to_t.normalized()
				_show_line()
		S.WINDUP:
			velocity = Vector2.ZERO
			if st_t > 0.18:
				_dash_dir = to_t.normalized()
				_update_line()
			animated_sprite.modulate = Color(2.2, 1.5, 0.9) if int(st_t * 20.0) % 2 == 0 else Color.WHITE
			_play(&"attack")
			if st_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				_hide_line()
				st = S.DASH
				st_t = 0.34
				_hit_done = false
				_crack_t = 0.0
		S.DASH:
			velocity = _dash_dir * 560.0
			_play(&"strike")
			_crack_t -= delta
			if _crack_t <= 0.0:
				_crack_t = 0.09
				_leave_crack(_dash_dir.angle() + RNG.randf_range(-0.5, 0.5))
			if not _hit_done and contact(damage):
				_hit_done = true
			if st_t <= 0.0:
				st = S.REST
				st_t = 0.8
		S.REST:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			_play(&"idle")
			if st_t <= 0.0:
				st = S.RUN
				st_t = RNG.randf_range(1.8, 2.8)
	_face(velocity.x if st != S.WINDUP else to_t.x)
	move_and_slide()


func _leave_crack(rot: float) -> void:
	PtHazard.spawn(_spawn_container(), global_position + Vector2(0, 4), PtHazard.Kind.GRIETA, damage * 0.45, rot)


func _show_line() -> void:
	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = Color(ORANGE, 0.75)
	_line.z_index = 5
	add_child(_line)
	_update_line()


func _update_line() -> void:
	if _line != null:
		_line.points = PackedVector2Array([Vector2(0, -6), Vector2(0, -6) + _dash_dir * 190.0])


func _hide_line() -> void:
	if _line != null:
		_line.queue_free()
		_line = null


func die(killer: Node = null) -> void:
	_hide_line()
	super.die(killer)
