extends Defense
class_name DefBolsaAgua

## BOLSA DE AGUA CALIENTE (defensa). PULSAR "guard" con la vida incompleta: te la pegas y durante WARM_TIME s
## un aura tibia (radio AURA_R) CURA poco a poco a quien este dentro (tu: HEAL_PER_S por segundo). Alivia
## los colicos, pero "cuidado con quemaduras": no se puede usar con la vida llena y la recarga es larga.

const WARM_TIME := 8.0
const HEAL_PER_S := 1.2
const COOLDOWN := 35.0
const AURA_R := 46.0

var uses := 0
var _warm := 0.0
var _cd := 0.0
var _acc := 0.0
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("ff7a5a")


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	cooling = _cd > 0.0 and _warm <= 0.0
	guarding = _warm > 0.0
	if guard_pressed() and _cd <= 0.0 and _warm <= 0.0:
		if stats.current_health >= stats.max_health:
			text("DEF_HOTBAG_FULL", Color("ffb8a0"))
		else:
			_warm = WARM_TIME
			_cd = COOLDOWN
			uses += 1
			text("DEF_HOTBAG_ON", Color("ff9a7a"), 40.0)
			Sound.play("room_clear", 0.1)
	if _warm > 0.0:
		_warm -= delta
		_acc += HEAL_PER_S * delta
		if _acc >= 1.0:
			_acc -= 1.0
			if stats.current_health < stats.max_health:
				stats.heal(1.0)
		if _warm <= 0.0:
			text("DEF_HOTBAG_OFF", Color("c8a8a0"))
		gauge_visible = true
		gauge_value = _warm / WARM_TIME
		gauge_color = Color("ff7a5a")
	else:
		gauge_visible = _cd > 0.0
		gauge_value = 1.0 - _cd / COOLDOWN
		gauge_color = Color("8a6a62")


func _draw_tick() -> void:
	_t += get_process_delta_time()
	if _warm > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if _warm <= 0.0:
		return
	var a := 0.3 if _warm > 1.5 else 0.12
	draw_circle(Vector2.ZERO, AURA_R, Color(1.0, 0.45, 0.25, a * 0.5))
	draw_arc(Vector2.ZERO, AURA_R, 0.0, TAU, 32, Color(1.0, 0.6, 0.35, a + 0.2), 1.5)
	for i in 4:  # vapor que sube
		var ph := fmod(_t * 0.7 + i * 0.25, 1.0)
		var p := Vector2(-14.0 + i * 9.0 + sin(_t * 3.0 + i) * 2.0, 8.0 - ph * 34.0)
		draw_circle(p, 2.5, Color(1.0, 0.85, 0.7, 0.5 * (1.0 - ph)))
