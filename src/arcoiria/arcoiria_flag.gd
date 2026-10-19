class_name ArcoiriaFlag
extends CanvasLayer

## Contador de la bandera del HUD (esquina inferior izquierda): seis franjas, apagadas hasta que
## liberas una sala de Arcoiria; la franja nueva se enciende con un destello. Arcoiria.setup_floor
## lo crea al pisar el reino (grupo arc_flag) y Arcoiria.on_room_cleared lo actualiza.

const W := 66.0
const H := 42.0
const POLE := 5.0

var _view: Control
var _lit := 0
var _flash := 0.0
var _flash_idx := -1


func _ready() -> void:
	layer = 6
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_view.custom_minimum_size = Vector2(W + POLE + 4.0, H + 6.0)
	_view.offset_left = 14.0
	_view.offset_bottom = -14.0
	_view.offset_top = -14.0 - H - 6.0
	_view.offset_right = 14.0 + W + POLE + 4.0
	_view.draw.connect(_draw_flag)
	add_child(_view)


func set_lit(n: int, animate: bool) -> void:
	if animate and n > _lit:
		_flash_idx = n - 1
		_flash = 1.0
	_lit = n
	if _view != null:
		_view.queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 1.6)
		_view.queue_redraw()


func _draw_flag() -> void:
	var sh := H / Arcoiria.MAX_STRIPES
	_view.draw_rect(Rect2(0.0, 1.0, POLE, H + 5.0), Color("2a2230"))
	_view.draw_rect(Rect2(1.0, 1.0, POLE - 2.0, H + 5.0), Color("8a7a96"))
	for i in Arcoiria.MAX_STRIPES:
		var r := Rect2(POLE + 1.0, 2.0 + i * sh, W, sh)
		var s := Arcoiria.stripe(i)
		if i < _lit:
			_view.draw_rect(r, s.color)
			_view.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1.5), Color(s.light, 0.8))
			if i == _flash_idx and _flash > 0.0:
				_view.draw_rect(r, Color(1, 1, 1, _flash * 0.8))
		else:
			_view.draw_rect(r, Color(0.2, 0.19, 0.24, 0.55))
	_view.draw_rect(Rect2(POLE + 1.0, 2.0, W, H), Color("1a1620"), false, 2.0)
