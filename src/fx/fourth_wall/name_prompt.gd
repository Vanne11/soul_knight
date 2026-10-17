class_name NamePrompt
extends CanvasLayer

## Cuadro "¿Como te llamo, valiente?": se muestra UNA vez (lo decide FourthWall) y se puede
## saltar (boton, Esc o dejarlo vacio). No pausa el juego. finished("") = sin nombre.

signal finished(text: String)

const MAX_LEN := 16
var _edit: LineEdit
var _done := false


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = HudStyle.menu_theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 520
	panel.add_theme_stylebox_override("panel", HudStyle.panel_box(22))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(HudStyle.pixel_label(tr("CP_NAME_TITLE"), 24, Color("ff4f9a"), true))
	var hint := Label.new()
	hint.text = tr("CP_NAME_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 14)
	box.add_child(hint)
	_edit = LineEdit.new()
	_edit.placeholder_text = tr("CP_NAME_PLACEHOLDER")
	_edit.max_length = MAX_LEN
	_edit.custom_minimum_size.y = 40
	_edit.text_submitted.connect(func(_t): _accept())
	box.add_child(_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var ok := Button.new()
	ok.text = tr("CP_NAME_OK")
	ok.custom_minimum_size = Vector2(0, 42)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_accept)
	HudStyle.juice_button(ok)
	row.add_child(ok)
	var skip := Button.new()
	skip.text = tr("CP_NAME_SKIP")
	skip.custom_minimum_size = Vector2(0, 42)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.pressed.connect(_finish.bind(""))
	HudStyle.juice_button(skip)
	row.add_child(skip)
	_edit.grab_focus.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_finish("")


func _accept() -> void:
	_finish(clean(_edit.text))


## Sin corchetes ni llaves (romperian bbcode y format de las frases) y con largo maximo.
static func clean(raw: String) -> String:
	var s := raw
	for ch in ["[", "]", "{", "}", "\n", "\t"]:
		s = s.replace(ch, "")
	return s.strip_edges().left(MAX_LEN)


func _finish(text: String) -> void:
	if _done:
		return
	_done = true
	finished.emit(text)
	queue_free()
