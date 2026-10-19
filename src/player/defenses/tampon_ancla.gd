extends Defense
class_name DefTamponAncla

## TAMPON ANCLA (defensa). MANTENER "guard": te ANCLAS: inmune a empujones, succiones, correas y knockback
## (Player.shove, StatusEffects.push/pull) mientras lo mantienes. Caminas lento, pero puedes disparar.
## "Cambialo cada pocas horas": aqui se gasta estamina mientras esta puesto y, al agotarse, hay que
## cambiarlo (CHANGE_TIME sin poder usarlo).

const WALK_MULT := 0.45
const DRAIN := 9.0
const CHANGE_TIME := 3.0

var anchors := 0
var _lock := 0.0
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("5a86d8")


func speed_mult() -> float:
	return WALK_MULT if guarding else 1.0


func anchored() -> bool:
	return guarding


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_lock = maxf(0.0, _lock - delta)
	cooling = _lock > 0.0
	var want: bool = guard_held() and _lock <= 0.0 and stats.current_stamina > 1.0
	if want and not guarding:
		guarding = true
		anchors += 1
		text("DEF_ANCHOR_ON", Color("8fb4ff"))
		Sound.play("locked", 0.1)
	elif not want and guarding:
		guarding = false
		if stats.current_stamina <= 1.0:
			_lock = CHANGE_TIME
			text("DEF_ANCHOR_CHANGE", Color("c8c8d8"))
	if guarding:
		stats.use_stamina(DRAIN * delta)
	gauge_visible = guarding or _lock > 0.0
	gauge_value = (stats.current_stamina / stats.max_stamina) if guarding else 1.0 - _lock / CHANGE_TIME


func _draw_tick() -> void:
	_t += get_process_delta_time()


func _draw_body() -> void:
	if not guarding:
		return
	var c := Vector2(0, 26)
	draw_circle(c, 11.0, Color(0.2, 0.3, 0.6, 0.35))
	draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color.BLACK, 4.0)
	draw_line(c + Vector2(-6, -3), c + Vector2(6, -3), Color.BLACK, 4.0)
	draw_arc(c + Vector2(0, 2), 8.0, 0.2, PI - 0.2, 10, Color.BLACK, 4.0)
	draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color("8fb4ff"), 2.0)
	draw_line(c + Vector2(-6, -3), c + Vector2(6, -3), Color("8fb4ff"), 2.0)
	draw_arc(c + Vector2(0, 2), 8.0, 0.2, PI - 0.2, 10, Color("8fb4ff"), 2.0)
