extends CanvasLayer

## Historia (diapositivas de lines.json "intro_slides") + seleccion de personaje.
## Siempre empieza con la historia (ESC la salta); despues, elegir personaje.

const ORDER := ["pitocles", "vulvalquiria", "ornitorrinco"]
const CARD_COLORS := {"pitocles": Color("6ec6ff"), "vulvalquiria": Color("ff7ac0"), "ornitorrinco": Color("9be53c")}

var _slides: Array = []
var _slide := -1
var _bg: ColorRect
var _story: Label
var _hint: Label
var _select: Control
var _tween: Tween
## Letras por segundo al escribir la historia.
const CHARS_PER_SEC := 22.0
## Tras completarse una frase, pausa antes de aceptar "seguir": sin ella una
## doble pulsacion completaba una frase y se saltaba la siguiente sin leerla.
const READ_LOCK_MS := 600
var _done_at_ms := 0


func _ready() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color("2a1440")
	add_child(_bg)
	_build_story()
	_build_select()
	_slides = Narrator.get_lines("intro_slides")
	_next_slide()


func _build_story() -> void:
	_story = Label.new()
	_story.set_anchors_preset(Control.PRESET_FULL_RECT)
	_story.offset_left = 160
	_story.offset_right = -160
	_story.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.add_theme_font_size_override("font_size", 30)
	_story.add_theme_color_override("font_color", Color("fff1d6"))
	add_child(_story)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -60
	_hint.offset_left = -300
	_hint.offset_right = 300
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = "[cualquier tecla] seguir      [ESC] saltar la historia"
	_hint.add_theme_color_override("font_color", Color("b48cff"))
	add_child(_hint)


func _next_slide() -> void:
	_slide += 1
	if _slide >= _slides.size():
		_show_select()
		return
	_story.text = _slides[_slide]
	_story.visible_ratio = 0.0
	# El fondo pasa de gris (censura) a color segun avanza la historia... y vuelve a gris cuando llega la Hoja.
	var censored := _slide >= 4
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_story, "visible_ratio", 1.0, _story.text.length() / CHARS_PER_SEC)
	_tween.chain().tween_callback(func(): _done_at_ms = Time.get_ticks_msec())
	_tween.tween_property(_bg, "color", Color("3a3a42") if censored else Color("2a1440"), 0.8)


func _input(event: InputEvent) -> void:
	if not _story.visible or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if event.is_action("pause"):
		_show_select()
	elif _story.visible_ratio < 1.0:
		_story.visible_ratio = 1.0  # primero termina de escribir, luego avanza
		_done_at_ms = Time.get_ticks_msec()
		if _tween:
			_tween.kill()
	elif Time.get_ticks_msec() - _done_at_ms >= READ_LOCK_MS:
		_next_slide()


# ---------------------------------------------------------------- seleccion
func _build_select() -> void:
	_select = VBoxContainer.new()
	_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	_select.alignment = BoxContainer.ALIGNMENT_CENTER
	_select.add_theme_constant_override("separation", 18)
	add_child(_select)
	var title := Label.new()
	title.text = "ELIGE A TU HÉROE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("ff4f9a"))
	title.add_theme_color_override("font_outline_color", Color("1a0b26"))
	title.add_theme_constant_override("outline_size", 10)
	_select.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	_select.add_child(row)
	var first_btn: Button = null
	for id in ORDER:
		var btn := _card(id, row)
		if first_btn == null:
			first_btn = btn
	var story_btn := Button.new()
	story_btn.text = "Ver la historia otra vez"
	story_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	story_btn.pressed.connect(func(): _slide = -1; _select.visible = false; _story.visible = true; _hint.visible = true; _next_slide())
	_select.add_child(story_btn)
	_select.visible = false
	_select.set_meta("first", first_btn)


func _card(id: String, parent: Control) -> Button:
	var data: Dictionary = RunManager.CHARACTERS[id]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 420)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1a0b26")
	box.border_color = CARD_COLORS[id]
	box.set_border_width_all(4)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", box)
	parent.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var portrait := TextureRect.new()
	var tex_path := "res://assets/sprites/player/%s/portrait.png" % id
	if ResourceLoader.exists(tex_path):
		portrait.texture = load(tex_path)
	portrait.custom_minimum_size = Vector2(128, 128)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.add_child(portrait)
	for pair in [[data.name, 30, CARD_COLORS[id]], [data.title, 16, Color("b48cff")], [data.bio, 14, Color("fff1d6")], [data.perk, 15, Color("ffc93c")]]:
		var l := Label.new()
		l.text = pair[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 290
		l.add_theme_font_size_override("font_size", pair[1])
		l.add_theme_color_override("font_color", pair[2])
		v.add_child(l)
	var btn := Button.new()
	btn.text = "ELEGIR"
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	btn.pressed.connect(choose.bind(id))
	btn.name = "Choose_" + id
	v.add_child(btn)
	return btn


func _show_select() -> void:
	if _tween:
		_tween.kill()
	_story.visible = false
	_hint.visible = false
	_select.visible = true
	create_tween().tween_property(_bg, "color", Color("2a1440"), 0.5)
	(_select.get_meta("first") as Button).grab_focus()


func choose(id: String) -> void:
	var rm = get_node("/root/RunManager")
	rm.character = id
	Narrator.say("select_" + id)
	rm.start_new_run()
	get_tree().change_scene_to_file("res://src/scenes/main.tscn")
