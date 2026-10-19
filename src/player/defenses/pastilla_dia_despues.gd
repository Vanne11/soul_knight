extends Defense
class_name DefPastillaDiaDespues

## PASTILLA DEL DIA DESPUES (defensa, USO UNICO). PULSAR "guard" tras recibir un golpe: deshace el ULTIMO
## golpe (te devuelve esa vida, hasta MAX_UNDO) y se consume (queda `spent`: vuelve la guard del heroe).
## El golpe tiene que ser reciente (WINDOW s): "cuanto antes, mejor". Si pulsas sin nada que deshacer no se
## gasta. "Es de emergencia, no un metodo".

const WINDOW := 10.0
const MAX_UNDO := 40.0

var _last_dmg := 0.0
var _last_t := -99.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("8fe0d0")


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func filter_hit(dmg: float) -> float:
	if dmg > 0.0 and not spent:
		_last_dmg = dmg
		_last_t = _now()
	return dmg


func _physics_process(_d: float) -> void:
	if player == null or spent:
		return
	var recent: bool = _now() - _last_t <= WINDOW and _last_dmg > 0.0
	gauge_visible = recent
	gauge_value = clampf(1.0 - (_now() - _last_t) / WINDOW, 0.0, 1.0)
	if guard_pressed():
		if not recent or stats.current_health >= stats.max_health:
			text("DEF_PILL_NOTHING", Color("b8d8d0"))
			return
		stats.heal(minf(_last_dmg, MAX_UNDO))
		spent = true
		gauge_visible = false
		text("DEF_PILL_UNDO", Color("8fe0d0"), 44.0)
		Sound.play("room_clear", 0.1)
		HitFx.shake(0.15)
