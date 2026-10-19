extends Control
class_name UIBar

## Barra pixel art (vida, escudo, estamina, toxicidad, jefe): icono + marco
## dorado 9-slice + relleno segmentado tenido con bar_color. Al bajar deja un
## "chip" claro que cae con retraso, asi se lee cuanto te acaban de quitar.

const FRAME_MARGIN := 6.0  ## 3 px de arte
const ICON_W := 22.0
const ICON_OVERLAP := 8.0

@export var bar_color: Color = Color.RED
## Compat: antes era el texto de la barra; ahora manda el icono.
@export var label_text: String = ""

var _current: float = 100.0
var _max: float = 100.0
var _pct := 1.0
var _chip_pct := 1.0
var _chip_tween: Tween
var _frame: NinePatchRect
var _chip: ColorRect
var _fill: TextureRect
var _gloss: TextureRect
var _icon: TextureRect
var _icon_name := ""
var label: Label
var _marks: Array[float] = []
var _mark_rects: Array[ColorRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if custom_minimum_size.y < 28:
		custom_minimum_size.y = 28
	_frame = NinePatchRect.new()
	_frame.texture = HudStyle.tex("bar_frame")
	_frame.patch_margin_left = 6
	_frame.patch_margin_right = 6
	_frame.patch_margin_top = 6
	_frame.patch_margin_bottom = 6
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_chip = ColorRect.new()
	_chip.color = Color(1, 0.95, 0.85, 0.9)
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chip)
	_fill = TextureRect.new()
	_fill.texture = HudStyle.tex("bar_fill")
	_fill.stretch_mode = TextureRect.STRETCH_TILE
	_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)
	_gloss = TextureRect.new()
	_gloss.texture = HudStyle.tex("bar_gloss")
	_gloss.stretch_mode = TextureRect.STRETCH_TILE
	_gloss.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gloss)
	label = HudStyle.pixel_label("", 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	add_child(_icon)
	if _icon_name != "":
		_icon.texture = HudStyle.tex("icon_" + _icon_name)
	_fill.modulate = bar_color
	resized.connect(_layout)
	_layout()
	update_bar(_current, _max)


func set_icon(icon_name: String) -> void:
	_icon_name = icon_name
	if _icon:  # si aun no entro al arbol, lo pone _ready
		_icon.texture = HudStyle.tex("icon_" + icon_name)
		_layout()


func _inner() -> Rect2:
	var x0 := (ICON_W - ICON_OVERLAP if _icon and _icon.texture else 0.0) + FRAME_MARGIN
	return Rect2(x0, FRAME_MARGIN, size.x - x0 - FRAME_MARGIN, size.y - FRAME_MARGIN * 2.0)


func _layout() -> void:
	if not _frame:
		return
	var has_icon := _icon.texture != null
	var fx := ICON_W - ICON_OVERLAP if has_icon else 0.0
	_frame.position = Vector2(fx, 0)
	_frame.size = Vector2(size.x - fx, size.y)
	_icon.position = Vector2(0, roundf((size.y - ICON_W) / 2.0))
	_icon.size = Vector2(ICON_W, ICON_W)
	var r := _inner()
	label.position = r.position + Vector2(0, -1)
	label.size = Vector2(r.size.x - 4, r.size.y)
	_apply()


## Marcas verticales a esos porcentajes (0-1) de la barra: fases del jefe (0.66, 0.33).
func set_marks(fracs: Array[float]) -> void:
	_marks = fracs
	for m in _mark_rects:
		m.queue_free()
	_mark_rects.clear()
	for i in fracs.size():
		var m := ColorRect.new()
		m.color = Color(1, 0.93, 0.7, 0.95)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(m)
		_mark_rects.append(m)
	_apply()


func _apply() -> void:
	var r := _inner()
	for i in _mark_rects.size():
		_mark_rects[i].position = Vector2(r.position.x + floorf(r.size.x * _marks[i] / 2.0) * 2.0 - 1.0, r.position.y - 3.0)
		_mark_rects[i].size = Vector2(2.0, r.size.y + 6.0)
	# de a 2 px: el relleno nunca corta un pixel de arte por la mitad
	var w := floorf(r.size.x * _pct / 2.0) * 2.0
	var cw := floorf(r.size.x * _chip_pct / 2.0) * 2.0
	_fill.position = r.position
	_fill.size = Vector2(w, r.size.y)
	_gloss.position = r.position
	_gloss.size = Vector2(w, r.size.y)
	_chip.position = r.position
	_chip.size = Vector2(cw, r.size.y)
	_fill.visible = w > 0.0
	_gloss.visible = w > 0.0
	_chip.visible = cw > w


func update_bar(current: float, max: float) -> void:
	var prev := _pct
	_current = current
	_max = max
	_pct = 0.0 if max <= 0 else clampf(current / max, 0.0, 1.0)
	if label:
		label.text = "%d/%d" % [roundi(current), roundi(max)]
	if not _frame:
		return
	if _pct < prev:
		# el chip se queda donde estaba y cae tras una pausa
		_chip_pct = maxf(_chip_pct, prev)
		if _chip_tween:
			_chip_tween.kill()
		_chip_tween = create_tween()
		_chip_tween.tween_interval(0.35)
		_chip_tween.tween_method(func(v: float): _chip_pct = v; _apply(), _chip_pct, _pct, 0.35)
	else:
		_chip_pct = _pct
	_apply()


func set_color(color: Color) -> void:
	bar_color = color
	if _fill:
		_fill.modulate = color


## Latido del icono (vida baja, golpe...): destello + saltito de 2 px, sin
## escalar (escalar pixel art a 1.25x lo emborrona).
func pulse_icon() -> void:
	if not _icon or not _icon.texture:
		return
	var y := roundf((size.y - ICON_W) / 2.0)
	var t := create_tween().set_parallel()
	_icon.modulate = Color(2.2, 2.2, 2.2)
	_icon.position.y = y - 2.0
	t.tween_property(_icon, "modulate", Color.WHITE, 0.25)
	t.tween_property(_icon, "position:y", y, 0.12).set_delay(0.06)
