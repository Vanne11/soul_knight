extends Defense
class_name DefPep

## PEP (defensa, USO UNICO de emergencia). PULSAR "guard" tras un contagio: lo limpia, pero SOLO si estas
## dentro de la ventana corta (WINDOW s desde que te contagiaste): "cuanto antes, mejor". Fuera de la
## ventana no sirve ("consulta de urgencia") y no se gasta; sin contagio tampoco. Al usarla queda `spent`.
## No reemplaza al condon: es el plan B.

const WINDOW := 6.0

var _was_infected := false
var _since := -99.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("ff6a5a")


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _physics_process(_d: float) -> void:
	if player == null or spent:
		return
	var inf: bool = stats.contagion_time > 0.0
	if inf and not _was_infected:
		_since = _now()
	_was_infected = inf
	var left := WINDOW - (_now() - _since)
	gauge_visible = inf and left > 0.0
	gauge_value = clampf(left / WINDOW, 0.0, 1.0)
	if guard_pressed():
		if not inf:
			text("DEF_PEP_NOTHING", Color("d8c8c4"))
		elif left <= 0.0:
			text("DEF_PEP_LATE", Color("ff9a8a"), 44.0)
		else:
			stats.clear_contagion()
			spent = true
			gauge_visible = false
			text("DEF_PEP_CLEAN", Color("ff8a7a"), 44.0)
			Sound.play("room_clear", 0.1)
			HitFx.shake(0.15)
