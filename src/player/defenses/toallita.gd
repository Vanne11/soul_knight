extends Defense
class_name DefToallita

## TOALLITA HUMEDA (defensa). PULSAR "guard": te pasas la toallita por fuera: se van los estados pegados
## (esposas, jaula, venda, mordaza...), el picor/ardor de contagio y lo que te frena el suelo (cera, charcos).
## Luego, CLEAN_TIME s de SUELO LIMPIO: charcos pegajosos, cera y rampas no te frenan. Limpieza externa:
## no toca la intoxicacion ("no hay lavados internos"). Recarga larga.

const CLEAN_TIME := 6.0
const COOLDOWN := 20.0

var wipes := 0
var _clean := 0.0
var _cd := 0.0
var _t := 0.0
var _swipe := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("ff9ec8")


func floor_clean() -> bool:
	return _clean > 0.0


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	_clean = maxf(0.0, _clean - delta)
	_swipe = maxf(0.0, _swipe - delta)
	cooling = _cd > 0.0 and _clean <= 0.0
	if guard_pressed() and _cd <= 0.0:
		_wipe()
	if _clean > 0.0:
		gauge_visible = true
		gauge_value = _clean / CLEAN_TIME
		gauge_color = Color("7fd8ff")
	else:
		gauge_visible = _cd > 0.0
		gauge_value = 1.0 - _cd / COOLDOWN
		gauge_color = Color("ff9ec8")


func _wipe() -> void:
	wipes += 1
	_cd = COOLDOWN
	_clean = CLEAN_TIME
	_swipe = 0.35
	var st := player.get_node_or_null("StatusEffects") as StatusEffects
	if st != null:
		st.clear()
	stats.clear_contagion()
	for key in ["gota", "sticky"]:  # cera y pegajoso: se acaba la ralentizacion pegada
		stats.set_meta(key + "_until", 0)
	if stats.has_meta("gota_on"):
		EnemyGotaCera.GotaSlow.unstick(stats)
	Sound.play("room_clear", 0.1)
	text("DEF_WIPE_DONE", Color("ffb8d8"), 40.0)


func _draw_tick() -> void:
	_t += get_process_delta_time()
	if _clean > 0.0 or _swipe > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if _swipe > 0.0:
		var k := 1.0 - _swipe / 0.35
		for i in 3:
			var y := -14.0 + i * 12.0
			draw_line(Vector2(-16.0 + 32.0 * k, y), Vector2(-16.0 + 32.0 * k - 10.0, y + 4.0), Color(1, 1, 1, 0.8), 3.0)
	if _clean > 0.0:
		var a := 0.5 if _clean > 1.5 else (0.5 if int(_t * 8.0) % 2 == 0 else 0.1)
		draw_arc(Vector2(0, 10), 15.0, 0.0, TAU, 24, Color(0.5, 0.85, 1.0, a), 1.5)
		for i in 3:
			var p := Vector2(0, 10) + Vector2.from_angle(_t * 2.0 + TAU * i / 3.0) * 15.0
			draw_circle(p, 2.0, Color(0.7, 0.92, 1.0, a + 0.3))
