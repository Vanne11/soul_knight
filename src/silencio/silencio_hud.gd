class_name SilencioHud
extends CanvasLayer

## HUD propio de Las Tierras del Silencio (Silencio.setup_floor lo crea al pisar el reino):
##  - el CIRCULO: 3 puntos de luz (tus personas de confianza) junto a tu vida. Aparece en S3 y ahi se
##    apagan de a uno. Su estado vive en Silencio.circle_on; la API (circle_set / circle_relight) la
##    usara el jefe.
##  - una linea de ayuda abajo (hint): lo que se puede hacer en la sala ("Manten E: hablar").
##  - el boton "Como buscar ayuda", siempre a la vista (con pausar, guardar y salir, lo unico que el
##    reino no esconde nunca; tambien esta en el menu de pausa).

const LIGHT := Color("ffe0a0")
const OFF := Color("3d3c42")
const RING_R := 20.0
const DOT_R := 7.0
const FADE_SPEED := 2.2

var _circle: Control
var _hint: Label
var _help: Button
var _level: Array = [1.0, 1.0, 1.0]  # brillo actual de cada luz (0 apagada .. 1 encendida)
var _alpha := 0.0
var _flicker: Array = [0.0, 0.0, 0.0]


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS  # el circulo se apaga tambien mientras el inventario pausa el juego
	_circle = Control.new()
	_circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_circle.position = Vector2(40, HUD.BAND + 62)
	_circle.draw.connect(_draw_circle)
	add_child(_circle)
	_hint = HudStyle.pixel_label("", 16, Color("e4e0d8"))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -22
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_help = Button.new()
	_help.text = tr("SIL_AYUDA_BOTON")
	_help.focus_mode = Control.FOCUS_NONE  # que ni espacio ni E la pulsen jugando
	_help.add_theme_font_override("font", HudStyle.FONT)
	_help.add_theme_font_size_override("font_size", 16)
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.offset_left = 10
	_help.offset_top = -44
	_help.offset_bottom = -10
	_help.offset_right = 270
	_help.pressed.connect(Silencio.ayuda)
	add_child(_help)
	for i in 3:
		_level[i] = 1.0 if Silencio.circle_is_on(i) else 0.0
	_alpha = 1.0 if Silencio.circle_shown else 0.0


## Texto de ayuda de la sala ("" lo quita). [E] se cambia por la tecla (o boton) de "interact".
func set_hint(text: String) -> void:
	_hint.text = text.replace("[E]", InputGlyphs.text("interact"))


## Contemplacion (sala de memoria): el HUD se oculta; solo queda el boton "Como buscar ayuda".
func set_contemplation(on: bool) -> void:
	_circle.visible = not on
	_hint.visible = not on


## Pone al dia el circulo con Silencio.circle_on (fade_in: aparece por primera vez).
func circle_refresh(fade_in: bool) -> void:
	if fade_in:
		_alpha = 0.0
	for i in 3:
		if _level[i] > 0.0 and not Silencio.circle_is_on(i):
			_flicker[i] = 0.7  # un parpadeo corto antes de apagarse
	set_process(true)


func _process(delta: float) -> void:
	var target_a := 1.0 if Silencio.circle_shown else 0.0
	_alpha = move_toward(_alpha, target_a, delta * 1.2)
	for i in 3:
		_flicker[i] = maxf(0.0, _flicker[i] - delta)
		var want := 1.0 if Silencio.circle_is_on(i) else 0.0
		if _flicker[i] <= 0.0:
			_level[i] = move_toward(_level[i], want, delta * FADE_SPEED)
	_circle.queue_redraw()


func _draw_circle() -> void:
	if _alpha <= 0.0:
		return
	var ring := Color(0.78, 0.74, 0.66, 0.7 * _alpha)
	_circle.draw_arc(Vector2.ZERO, RING_R, 0.0, TAU, 32, ring, 1.5)
	for i in 3:
		var p := Vector2.RIGHT.rotated(deg_to_rad(-90.0 + 120.0 * i)) * RING_R
		var lv: float = _level[i]
		if _flicker[i] > 0.0:
			lv = 1.0 if int(_flicker[i] * 14.0) % 2 == 0 else 0.25
		var col := OFF.lerp(LIGHT, lv)
		col.a = _alpha
		if lv > 0.05:
			var glow := LIGHT
			glow.a = 0.18 * lv * _alpha
			_circle.draw_circle(p, DOT_R + 5.0, glow)
		_circle.draw_circle(p, DOT_R, col)
		_circle.draw_arc(p, DOT_R, 0.0, TAU, 16, Color(0.62, 0.6, 0.56, _alpha) if lv < 0.5 else Color(0.05, 0.05, 0.06, _alpha), 1.0)
