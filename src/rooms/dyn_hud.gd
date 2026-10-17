class_name DynHud
extends CanvasLayer

## Cartel y barra de una dinamica de sala (cuenta atras, aguante, progreso...), arriba al
## centro justo bajo la franja del HUD. No toca hud.gd: es una capa propia.

var _title: Label
var _bar_bg: ColorRect
var _bar: ColorRect
var _text: Label
var color := Color("ffd75a")


static func make(parent: Node, title: String, col := Color("ffd75a")) -> DynHud:
	var h := DynHud.new()
	h.color = col
	h.layer = 24
	parent.add_child(h)
	h._build(title)
	return h


func _build(title: String) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_title = HudStyle.pixel_label(title, 16, color, true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title.offset_left = -300.0
	_title.offset_right = 300.0
	_title.offset_top = HUD.BAND + 8.0
	root.add_child(_title)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0.05, 0.04, 0.07, 0.8)
	_bar_bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bar_bg.offset_left = -160.0
	_bar_bg.offset_right = 160.0
	_bar_bg.offset_top = HUD.BAND + 32.0
	_bar_bg.offset_bottom = HUD.BAND + 44.0
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bar_bg)
	_bar = ColorRect.new()
	_bar.color = color
	_bar.position = Vector2(2, 2)
	_bar.size = Vector2(316, 8)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bg.add_child(_bar)
	_text = HudStyle.pixel_label("", 12, HudStyle.CREAM)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_text.offset_left = -300.0
	_text.offset_right = 300.0
	_text.offset_top = HUD.BAND + 48.0
	root.add_child(_text)


func set_title(t: String) -> void:
	_title.text = t


## frac 0..1 (barra llena = 1).
func set_value(frac: float, text := "") -> void:
	_bar.size.x = 316.0 * clampf(frac, 0.0, 1.0)
	_text.text = text


func set_color(c: Color) -> void:
	color = c
	_bar.color = c
	_title.add_theme_color_override("font_color", c)
