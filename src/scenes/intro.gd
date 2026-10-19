extends CanvasLayer

## Historia (diapositivas de lines.json "intro_slides") + seleccion de personaje.
## Siempre empieza con la historia (ESC la salta); despues, elegir personaje.

const ORDER := ["pitocles", "vulvalquiria", "ornitorrinco"]
const CARD_COLORS := {"pitocles": Color("6ec6ff"), "vulvalquiria": Color("ff7ac0"), "ornitorrinco": Color("9be53c")}

var _slides: Array[Dictionary] = []  ## {text, art, gray}: las arma IntroStory segun tu avance (plan 6)
var _slide := -1
var _bg: ColorRect
## Ilustracion de la diapositiva (assets/sprites/intro/slide_NN.png, 320x180 a 4x)
## y la anterior debajo para el fundido.
var _art: TextureRect
var _art_prev: TextureRect
var _shade: TextureRect
var _story: RichTextLabel
var _hint: Label
var _more: Label
var _more_tween: Tween
var _more_base_y := 0.0
var _select: Control
var _tween: Tween
## Letras por segundo al escribir la historia (mas pausas en la puntuacion).
const CHARS_PER_SEC := 55.0
const PAUSES := {".": 0.32, "!": 0.32, "?": 0.32, ":": 0.22, ",": 0.12}
## Palabras en MAYUSCULAS de la historia: se pintan del color de su reino.
const WORD_COLORS := {"PENELANDIA": "6ec6ff", "VULVANIA": "ff7ac0", "LA HOJA DE PARRA": "7fe0a0", "GRIS": "9a9aa6",
	"PENELAND": "6ec6ff", "THE FIG LEAF": "7fe0a0", "GRAY": "9a9aa6"}  # ingles
var _plain := ""      ## texto sin bbcode: lo que se va "diciendo"
var _shown := 0.0     ## letras visibles (fraccionario)
var _wait := 0.0      ## pausa por puntuacion
## Tras completarse una frase, pausa antes de aceptar "seguir": sin ella una
## doble pulsacion completaba una frase y se saltaba la siguiente sin leerla.
const READ_LOCK_MS := 600
var _done_at_ms := 0


func _ready() -> void:
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color("2a1440")
	add_child(_bg)
	_art_prev = _make_art()
	_art = _make_art()
	# degradado oscuro abajo: el texto se lee sobre cualquier ilustracion
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.03, 0.08, 0.0))
	g.set_color(1, Color(0.05, 0.03, 0.08, 0.92))
	g.add_point(0.45, Color(0.05, 0.03, 0.08, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	_shade = TextureRect.new()
	_shade.texture = gt
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_build_story()
	_build_select()
	var rm: RunManager = get_node("/root/RunManager")
	_slides = IntroStory.build(rm)
	if rm.rescue_requested:
		_show_select()  # post-juego "Desordenes": la historia ya se conoce, directo a elegir heroe
	else:
		Sound.music("intro")  # tema de la historia; al elegir heroe vuelve el del menu
		rm.mark_intro_seen()
		_next_slide()


func _make_art() -> TextureRect:
	var t := TextureRect.new()
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


func _set_art(i: int) -> void:
	var path := "res://assets/sprites/intro/slide_%02d.png" % i
	_art_prev.texture = _art.texture
	_art.texture = load(path) if ResourceLoader.exists(path) else null
	_art.modulate.a = 0.0
	create_tween().tween_property(_art, "modulate:a", 1.0, 0.45)


func _build_story() -> void:
	_story = RichTextLabel.new()
	_story.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_story.offset_left = 140
	_story.offset_right = -140
	_story.offset_top = -270
	_story.offset_bottom = -100
	_story.bbcode_enabled = true
	_story.scroll_active = false
	_story.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story.add_theme_font_size_override("normal_font_size", 30)
	_story.add_theme_color_override("default_color", Color("fff1d6"))
	_story.add_theme_color_override("font_outline_color", Color("1a0b26"))
	_story.add_theme_constant_override("outline_size", 8)
	# efectos propios que mueven las letras de a pixel entero: [wave]/[shake]
	# las dejan en medio pixel y se ven borrosas
	_story.install_effect(Bob.new())
	_story.install_effect(Jitter.new())
	add_child(_story)
	# flechita que late cuando la frase ya termino
	_more = Label.new()
	_more.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_more.offset_top = -100
	_more.offset_left = -20
	_more.offset_right = 20
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_more.text = "▼"
	_more.add_theme_font_size_override("font_size", 28)
	_more.add_theme_color_override("font_color", Color("ff4f9a"))
	_more.visible = false
	add_child(_more)
	_more_base_y = _more.position.y
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -60
	_hint.offset_left = -300
	_hint.offset_right = 300
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.text = InputGlyphs.localize_text(tr("INTRO_HINT"))  # [ESC] = la tecla de pausa del jugador
	_hint.add_theme_color_override("font_color", Color("b48cff"))
	add_child(_hint)


func _next_slide() -> void:
	_slide += 1
	if _slide >= _slides.size():
		_show_select()
		return
	_set_art(int(_slides[_slide].art))
	_story.text = "[center]%s[/center]" % _decorate(str(_slides[_slide].text))
	_plain = _story.get_parsed_text()
	_story.visible_characters = 0
	_shown = 0.0
	_wait = 0.15
	_more.visible = false
	_story.modulate.a = 0.0
	# El fondo pasa de gris (censura) a color segun avanza la historia... y vuelve a gris cuando llega la Hoja.
	var censored: bool = _slides[_slide].gray
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_story, "modulate:a", 1.0, 0.2)
	_tween.tween_property(_bg, "color", Color("3a3a42") if censored else Color("2a1440"), 0.8)


## Mayusculas -> color del reino + onda; GRIS tiembla de verguenza.
func _decorate(line: String) -> String:
	var re := RegEx.create_from_string("[A-ZÁÉÍÓÚÑ]{2,}(?: [A-ZÁÉÍÓÚÑ]{2,})*")
	var out := ""
	var last := 0
	for m in re.search_all(line):
		var w := m.get_string()
		var col: String = WORD_COLORS.get(w, "ff4f9a")
		var fx := "jitter" if (w == "GRIS" or w == "GRAY") else "bob"
		out += line.substr(last, m.get_start() - last) + "[color=#%s][%s]%s[/%s][/color]" % [col, fx, w, fx.get_slice(" ", 0)]
		last = m.get_end()
	return out + line.substr(last)


func _process(delta: float) -> void:
	if not _story.visible or _typing_done():
		return
	if _wait > 0.0:
		_wait -= delta
		return
	var before := int(_shown)
	_shown = minf(_shown + CHARS_PER_SEC * delta, _plain.length())
	var now := int(_shown)
	for i in range(before, now):
		var ch := _plain[i]
		# una silaba cada dos letras: cada letra suena a ametralladora
		if i % 2 == 0 and ch.strip_edges() != "" and ch not in PAUSES:
			Sound.voice(ch)
		if PAUSES.has(ch) and i < _plain.length() - 1:
			_wait = PAUSES[ch]
			now = i + 1
			_shown = now
			break
	_story.visible_characters = now
	if _typing_done():
		_finish_typing()


func _typing_done() -> bool:
	return _story.visible_characters < 0 or _story.visible_characters >= _plain.length()


func _finish_typing() -> void:
	_story.visible_characters = -1
	_done_at_ms = Time.get_ticks_msec()
	_more.visible = true
	if _more_tween:
		_more_tween.kill()
	var y := _more_base_y
	_more.position.y = y
	_more_tween = create_tween().set_loops()
	_more_tween.tween_property(_more, "position:y", y + 6.0, 0.35).set_trans(Tween.TRANS_SINE)
	_more_tween.tween_property(_more, "position:y", y, 0.35).set_trans(Tween.TRANS_SINE)


func _input(event: InputEvent) -> void:
	if not _story.visible or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if event.is_action("pause"):
		_show_select()
	elif not _typing_done():
		_finish_typing()  # primero termina de escribir, luego avanza
	elif Time.get_ticks_msec() - _done_at_ms >= READ_LOCK_MS:
		_next_slide()


# ---------------------------------------------------------------- seleccion
func _build_select() -> void:
	_select = VBoxContainer.new()
	_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	_select.alignment = BoxContainer.ALIGNMENT_CENTER
	_select.add_theme_constant_override("separation", 18)
	_select.theme = HudStyle.menu_theme()
	_select.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_select)
	var title := HudStyle.pixel_label(tr("INTRO_CHOOSE_TITLE"), 48, Color("ff4f9a"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	_select.add_child(title)
	if get_node("/root/RunManager").daily_requested:  # partida del dia: aviso bajo el titulo
		var dl := HudStyle.pixel_label(tr("CENSURA_DAILY_NOTICE") % RunManager.daily_date(), 16, Color("ffc93c"), true)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_select.add_child(dl)
	var rm: RunManager = get_node("/root/RunManager")
	if rm.rescue_requested:  # post-juego: mision de rescate de los reinos en desorden
		var rl := HudStyle.pixel_label(tr("DESORDEN_ELEGIR") if rm.rescue_swap_from != "" else tr("DESORDEN_RUTA"), 16, Color("ffc93c"), true)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_select.add_child(rl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	_select.add_child(row)
	var first_btn: Button = null
	var cards: Array[Button] = []
	for id in ORDER:
		var btn := _card(id, row)
		if rm.rescue_requested and id == rm.rescue_swap_from:
			btn.disabled = true  # quien acaba de ganar no vuelve a ir
			continue
		cards.append(btn)
		if first_btn == null:
			first_btn = btn
	var story_btn := Button.new()
	story_btn.text = tr("INTRO_REPLAY")
	story_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	HudStyle.juice_button(story_btn)
	story_btn.pressed.connect(func():
		_slide = -1
		Sound.music("intro")
		_select.visible = false
		_story.visible = true
		_hint.visible = true
		for n in [_art, _art_prev, _shade]:
			n.visible = true
		_next_slide())
	_select.add_child(story_btn)
	# Navegacion: izquierda/derecha rotan entre los heroes (en circulo) y solo abajo
	# lleva a "Ver la historia"; desde ahi, arriba vuelve al ultimo heroe enfocado.
	for i in cards.size():
		var c := cards[i]
		c.focus_neighbor_left = c.get_path_to(cards[(i - 1 + cards.size()) % cards.size()])
		c.focus_neighbor_right = c.get_path_to(cards[(i + 1) % cards.size()])
		c.focus_neighbor_bottom = c.get_path_to(story_btn)
		c.focus_neighbor_top = c.get_path_to(c)
		c.focus_next = c.focus_neighbor_right
		c.focus_previous = c.focus_neighbor_left
		c.focus_entered.connect(func(): story_btn.focus_neighbor_top = story_btn.get_path_to(c))
	story_btn.focus_neighbor_top = story_btn.get_path_to(first_btn)
	story_btn.focus_neighbor_left = story_btn.get_path_to(story_btn)
	story_btn.focus_neighbor_right = story_btn.get_path_to(story_btn)
	story_btn.focus_neighbor_bottom = story_btn.get_path_to(story_btn)
	_select.visible = false
	_select.set_meta("first", first_btn)


func _card(id: String, parent: Control) -> Button:
	var data: Dictionary = RunManager.CHARACTERS[id]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 490)
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
	for pair in [[Loc.char_field(id, "name"), 30, CARD_COLORS[id]], [Loc.char_field(id, "title"), 16, Color("b48cff")], [Loc.char_field(id, "bio"), 14, Color("fff1d6")], [Loc.char_field(id, "perk"), 15, Color("ffc93c")]]:
		var l := Label.new()
		l.text = pair[0]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 290
		l.add_theme_font_size_override("font_size", pair[1])
		l.add_theme_color_override("font_color", pair[2])
		v.add_child(l)
	v.add_child(_controls_block(id))
	var btn := Button.new()
	btn.text = tr("INTRO_CHOOSE_BTN")
	btn.custom_minimum_size = Vector2(0, 44)
	btn.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	btn.pressed.connect(choose.bind(id))
	btn.name = "Choose_" + id
	HudStyle.juice_button(btn)
	v.add_child(btn)
	return btn


## Los controles del heroe con los GLIFOS de la tecla/boton que el jugador tiene asignados
## (Controls) y del dispositivo que esta usando (InputGlyphs): atacar, dash y sus habilidades.
func _controls_block(id: String) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rows: Array = [["attack", "GLYPH_HELP_ATTACK"], ["dash", "GLYPH_HELP_DASH"]]
	rows.append_array(AbilityGauge.HINTS.get(id, []))
	for r in rows:
		var line := InputGlyphs.labeled(r[0], r[1], HudStyle.CREAM, 16)
		line.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(line)
	return col


func _show_select() -> void:
	Sound.music("menu")
	if _tween:
		_tween.kill()
	_story.visible = false
	_hint.visible = false
	_more.visible = false
	for n in [_art, _art_prev, _shade]:
		n.visible = false
	_select.visible = true
	create_tween().tween_property(_bg, "color", Color("2a1440"), 0.5)
	(_select.get_meta("first") as Button).grab_focus()
	FourthWall.select_shown()  # cuarta pared: un heroe opina desde las sombras


func choose(id: String) -> void:
	var rm = get_node("/root/RunManager")
	rm.character = id
	Narrator.say("chosen_" + id)  # (select_<heroe> es de cuarta_pared.json)
	if rm.daily_requested:
		rm.start_daily_run()  # partida del dia: semilla de la fecha (ver RunManager.daily_seed)
	else:
		rm.start_new_run()
	Transition.change_scene("res://src/scenes/main.tscn")


## [bob]: ola suave, letra a letra, en pixeles enteros.
class Bob extends RichTextEffect:
	var bbcode := "bob"
	func _process_custom_fx(c: CharFXTransform) -> bool:
		c.offset = Vector2(0.0, roundf(sin(c.elapsed_time * 5.0 + c.relative_index * 0.55) * 3.0))
		return true


## [jitter]: tiembla (de verguenza) a saltos de 1 px, 12 veces por segundo.
class Jitter extends RichTextEffect:
	var bbcode := "jitter"
	func _process_custom_fx(c: CharFXTransform) -> bool:
		var h := absi(hash(int(c.elapsed_time * 12.0) * 31 + c.relative_index))
		c.offset = Vector2(float(h % 3 - 1), float((h / 3) % 3 - 1))
		return true
