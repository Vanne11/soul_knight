extends Defense
class_name DefImplante

## IMPLANTE SUBDERMICO (defensa PASIVA de largo plazo). Una vez puesto da una barrera chica (CAP puntos)
## que se REGENERA SOLA durante muchas salas y pisos (1 punto cada REGEN_EVERY s): no hay que apretar nada.
## No reemplaza a la guard del heroe: la tecla sigue siendo su habilidad. Absorbe dano de cualquier tipo
## antes que el escudo; contra golpes grandes no alcanza ("barrera pequena").

const CAP := 12.0
const REGEN_EVERY := 8.0
const COLOR := Color("8ef0b8")

var stored := CAP
var absorbed_total := 0.0
var _acc := 0.0
var _flash := 0.0
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = COLOR


func is_passive() -> bool:
	return true


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if stored < CAP:
		_acc += delta
		if _acc >= REGEN_EVERY:
			_acc = 0.0
			stored = minf(CAP, stored + 1.0)
	gauge_visible = stored < CAP
	gauge_value = stored / CAP


func filter_hit(dmg: float) -> float:
	if stored <= 0.0 or dmg <= 0.0:
		return dmg
	var soak := minf(stored, dmg)
	stored -= soak
	absorbed_total += soak
	_flash = 0.25
	if stored <= 0.0:
		text("DEF_IMPLANT_OUT", Color("c8d8cc"))
	else:
		text("DEF_IMPLANT_SOAK", COLOR)
	Sound.play("crack", 0.1)
	return dmg - soak


func _draw_tick() -> void:
	_t += get_process_delta_time()
	_flash = maxf(0.0, _flash - get_process_delta_time())
	if stored > 0.0 or _flash > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if stored <= 0.0:
		return
	var a := 0.12 + 0.18 * stored / CAP + _flash * 0.8
	var r := 17.0 + sin(_t * 2.0) * 0.8
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(0.35, 0.95, 0.65, a), 1.5)
