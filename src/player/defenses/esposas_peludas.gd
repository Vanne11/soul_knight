extends Defense
class_name DefEsposasPeludas

## ESPOSAS PELUDAS (defensa; la version del HEROE, no el enemigo "esposas" del Palacio). PULSAR "guard":
## lanzas las esposas al enemigo mas cercano de frente (RANGE) y lo INMOVILIZAN HOLD s (stun). A los jefes
## no los sujetan. Recarga larga (COOLDOWN); si no hay nadie a la vista no se gasta.
## Con palabra de seguridad, siempre.

const RANGE := 230.0
const MIN_DOT := 0.45
const HOLD := 3.5
const COOLDOWN := 16.0

var cuffs := 0
var _cd := 0.0
var _target: Node2D = null
var _hold_left := 0.0
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("ff6fb8")


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	cooling = _cd > 0.0
	gauge_visible = _cd > 0.0
	gauge_value = 1.0 - _cd / COOLDOWN
	if _hold_left > 0.0:
		_hold_left -= delta
		if _target == null or not is_instance_valid(_target) or float(_target.get("current_health")) <= 0.0:
			_hold_left = 0.0
			_target = null
	if guard_pressed() and _cd <= 0.0:
		var e := nearest_enemy(RANGE, MIN_DOT, false)
		if e == null or not e.has_method("stun"):
			text("DEF_CUFFS_NONE", Color("c88aa8"))
			return
		_target = e
		_hold_left = HOLD
		_cd = COOLDOWN
		cuffs += 1
		e.stun(HOLD)
		text("DEF_CUFFS_ON", Color("ff7ac0"))
		Sound.play("locked", 0.1)
		HitFx.shake(0.2)


func _draw_tick() -> void:
	_t += get_process_delta_time()
	if _hold_left > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if _hold_left <= 0.0 or _target == null or not is_instance_valid(_target):
		return
	var c: Vector2 = _target.global_position - global_position + Vector2(0, -6)
	var a := 1.0 if _hold_left > 0.8 else (1.0 if int(_t * 10.0) % 2 == 0 else 0.3)
	for dx in [-9.0, 9.0]:
		draw_circle(c + Vector2(dx, 0), 6.5, Color(0.2, 0.0, 0.12, 0.85 * a))
		draw_arc(c + Vector2(dx, 0), 5.0, 0.0, TAU, 12, Color(1.0, 0.45, 0.75, a), 3.0)
	draw_line(c + Vector2(-4, 0), c + Vector2(4, 0), Color(0.85, 0.85, 0.92, a), 2.0)
