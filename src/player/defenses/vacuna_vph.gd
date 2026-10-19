extends Defense
class_name DefVacuna

## VACUNA VPH (defensa). PULSAR "guard": te la pones y, durante IMMUNE s, ningun estado te pega (esposas,
## jaula, mordaza, venda, correa, enrollado... ni los contagios ITS: picazon, ardor) y los que ya tenias se
## quitan. Luego enfriamiento. "Prevenir por adelantado": se pone ANTES, no cura lo que ya paso.
## No desvia balas ni dano: solo estados.

const IMMUNE := 20.0
const COOLDOWN := 50.0

var shots := 0
var _imm := 0.0
var _cd := 0.0
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("7fe0a0")


func blocks_contagion() -> bool:
	return _imm > 0.0


func blocks_status() -> bool:
	return _imm > 0.0


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	if _imm > 0.0:
		_imm -= delta
		if _imm <= 0.0:
			text("DEF_VAX_OFF", Color("9fb8a8"))
	guarding = _imm > 0.0
	if guard_pressed() and _cd <= 0.0 and _imm <= 0.0:
		_inject()
	cooling = _imm <= 0.0 and _cd > 0.0
	if _imm > 0.0:
		gauge_visible = true
		gauge_value = _imm / IMMUNE
		gauge_color = Color("7fe0a0")
	else:
		gauge_visible = _cd > 0.0
		gauge_value = 1.0 - _cd / COOLDOWN
		gauge_color = Color("6a8a78")


func _inject() -> void:
	shots += 1
	_imm = IMMUNE
	_cd = COOLDOWN
	var st := player.get_node_or_null("StatusEffects") as StatusEffects
	if st != null:
		st.clear()
	stats.clear_contagion()
	Sound.play("room_clear", 0.1)
	text("DEF_VAX_ON", Color("7fe0a0"), 40.0)


func _draw_tick() -> void:
	_t += get_process_delta_time()
	if _imm > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if _imm <= 0.0:
		return
	var a := 0.55 if _imm > 3.0 else (0.55 if int(_t * 8.0) % 2 == 0 else 0.15)  # parpadea al acabarse
	var r := 19.0 + sin(_t * 4.0) * 1.2
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.2, 0.55, 0.35, a), 3.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(0.5, 0.95, 0.65, a), 1.5)
	for i in 3:  # cruces "+" girando
		var p := Vector2.from_angle(_t * 1.6 + TAU * i / 3.0) * (r + 2.0)
		draw_line(p + Vector2(-2.5, 0), p + Vector2(2.5, 0), Color(0.7, 1.0, 0.8, a + 0.3), 1.5)
		draw_line(p + Vector2(0, -2.5), p + Vector2(0, 2.5), Color(0.7, 1.0, 0.8, a + 0.3), 1.5)
