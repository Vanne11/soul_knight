class_name SilencioMensajesHud
extends CanvasLayer

## Los mensajes de S4 "Mensajes" (diseno_E3): burbujas de texto blancas que llegan desde los costados de
## la pantalla, sin avatar, y se acumulan en dos columnas. Cada una tiñe un poco mas el borde de la
## pantalla. Responder quita una y llegan dos: imposible vaciarlas. Ignorarlas tampoco las frena.
## Solo dibuja; el ritmo y la tecla de responder los lleva SilencioMensajes.

const SLOT_H := 34.0
const MAX_PER_SIDE := 14
const BOTTOM := 676.0
const MARGIN := 12.0
const BUBBLE_W := 250.0  # cabe el mensaje mas largo en una linea
const SLIDE := 0.35
const TINT_PER_MSG := 0.03
const TINT_MAX := 0.42
const TINT_COLOR := Color(0.88, 0.9, 0.96)

var _root: Control
var _tint_view: Control
var _sides: Array = [[], []]  # [izquierda, derecha]: burbujas, de la mas vieja a la mas nueva
var _next_side := 0
var _tint := 0.0
var arrived := 0  # cuantas han llegado en total (el borde se tiñe segun este numero)


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root)
	_tint_view = Control.new()
	_tint_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint_view.draw.connect(_draw_tint)
	_root.add_child(_tint_view)


## Llega un mensaje (alterna izquierda y derecha).
func receive(text: String) -> void:
	var side := _next_side
	_next_side = 1 - _next_side
	arrived += 1
	var b := SilencioBurbuja.create(text, Color("f2f1ed"), Color("1c1b1f"), BUBBLE_W)
	b.label.add_theme_font_size_override("font_size", 16)
	_root.add_child(b)
	_sides[side].append(b)
	if _sides[side].size() > MAX_PER_SIDE:
		var old: Control = _sides[side].pop_front()
		old.queue_free()  # las mas viejas se van al fondo: la pantalla no se llena del todo
	b.reset_size()
	b.position = Vector2(-b.size.x if side == 0 else 1280.0, _slot_y(side, _sides[side].size() - 1))
	b.set_meta("side", side)
	_reflow()


## Responder: la mas vieja sale. (El que llama manda otras dos.)
func answer() -> void:
	var side := 0 if _sides[0].size() >= _sides[1].size() else 1
	if _sides[side].is_empty():
		return
	var b: Control = _sides[side].pop_front()
	var tw := b.create_tween()
	tw.tween_property(b, "modulate:a", 0.0, 0.3)
	tw.tween_callback(b.queue_free)
	_reflow()


func count() -> int:
	return _sides[0].size() + _sides[1].size()


func _slot_y(_side: int, i: int) -> float:
	return BOTTOM - SLOT_H * float(_sides[_side].size() - i)


func _reflow() -> void:
	for side in 2:
		for i in _sides[side].size():
			var b: Control = _sides[side][i]
			var x := MARGIN if side == 0 else 1280.0 - MARGIN - b.size.x
			var tw := b.create_tween().set_parallel(true)
			tw.tween_property(b, "position", Vector2(x, _slot_y(side, i)), SLIDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_tint = move_toward(_tint, minf(float(arrived) * TINT_PER_MSG, TINT_MAX), delta * 0.2)
	_tint_view.queue_redraw()


## El borde de la pantalla se tiñe de a poco con cada mensaje: un degradado desde los 4 lados.
func _draw_tint() -> void:
	if _tint <= 0.005:
		return
	var w := 1280.0
	var h := 720.0
	var d := 150.0
	var a := TINT_COLOR
	a.a = _tint
	var z := TINT_COLOR
	z.a = 0.0
	_tint_view.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(d, 0), Vector2(d, h), Vector2(0, h)]), PackedColorArray([a, z, z, a]))
	_tint_view.draw_polygon(PackedVector2Array([Vector2(w - d, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - d, h)]), PackedColorArray([z, a, a, z]))
	_tint_view.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, d), Vector2(0, d)]), PackedColorArray([a, a, z, z]))
	_tint_view.draw_polygon(PackedVector2Array([Vector2(0, h - d), Vector2(w, h - d), Vector2(w, h), Vector2(0, h)]), PackedColorArray([z, z, a, a]))
