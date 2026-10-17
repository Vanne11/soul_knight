extends Enemy3a
class_name EnemySonda

## Sonda Uretral (idea de Vanessa; Penelandia, sobre todo en el Conducto Deferente): fina,
## rapida, se lanza en LINEA RECTA como una lanza. Se para, apunta (una linea roja marca por
## donde va) y sale disparada; si falla, queda clavada/agotada un buen rato. La peor pesadilla
## de Penelandia... y el humor es que lo sabe.

const AIM_LEN := 420.0
var _line: Line2D = null
var _quip_cd := 0.0


func _setup() -> void:
	personality = "sonda"
	move_speed = 160.0
	lunge_trigger = 400.0
	windup_time = 0.7
	lunge_time = 0.4
	lunge_speed = 1000.0
	recover_time = 1.1
	attack_cooldown = 0.6
	detection_range = 560.0


func _ready() -> void:
	super._ready()
	_line = Line2D.new()
	_line.width = 2.0
	_line.default_color = Color(1.0, 0.25, 0.3, 0.0)
	_line.z_index = -1
	_line.add_point(Vector2.ZERO)
	_line.add_point(Vector2.RIGHT * AIM_LEN)
	add_child(_line)


func _physics_process(delta: float) -> void:
	_quip_cd = maxf(0.0, _quip_cd - delta)
	super._physics_process(delta)
	if _line == null:
		return
	if state == State.WINDUP:
		# la linea sigue el apuntado y se vuelve mas gruesa/intensa al final del aviso
		var k := 1.0 - clampf(_state_timer / windup_time, 0.0, 1.0)
		_line.rotation = _lunge_dir.angle()
		_line.width = lerpf(1.5, 4.0, k)
		_line.default_color = Color(1.0, 0.25, 0.3, lerpf(0.25, 0.9, k))
	else:
		_line.default_color.a = 0.0


func _start_lunge() -> void:
	super._start_lunge()
	if _quip_cd <= 0.0:
		_quip_cd = 5.0
		_say("sonda_lunge", 1.2)
		E3a.note("e3a_sonda")
