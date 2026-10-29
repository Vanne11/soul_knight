class_name BlessingPicker
extends CanvasLayer

## Eleccion de bendicion con 3 cartas (icono grande, nombre, efecto, nivel y aviso de alergia).
## Pausa el arbol mientras eliges, como Narrator.choose. Raton (clic), teclado (1-3, flechas
## + ENTER/ESPACIO) y mando (cruceta/stick + A). Emite picked(i) con el indice elegido.
## Los datos y la logica (roll_blessings, _take_blessing) siguen en RunManager y main.gd.

signal picked(index: int)

const DIR := "res://assets/sprites/ui/blessings/"
const KINGDOM_COLORS := {"pene": Color("6ec6ff"), "vulva": Color("ff7ac0"), "mixto": Color("ffc93c")}
const KINGDOM_KEYS := {"pene": "KINGDOM_PENE", "vulva": "KINGDOM_VULVA", "mixto": "KINGDOM_MIXED"}
const CARD_SIZE := Vector2(300, 420)
## Ignora entradas los primeros ms: que el clic/tecla anterior no elija sin querer.
const GRACE_MS := 250

var _ids: Array = []
var _title := ""
var _cards: Array[PanelContainer] = []
var _sel := 0
var _opened_ms := 0
var _done := false


static func icon_tex(id: String) -> Texture2D:
	var path := DIR + id + ".png"
	return load(path) if ResourceLoader.exists(path) else null


## RunManager es autoload (nodo) y class_name a la vez: sus metodos de instancia se piden al nodo.
static func rm() -> RunManager:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/RunManager")


static func kingdom_color(id: String) -> Color:
	return KINGDOM_COLORS.get(RunManager.BLESSINGS[id].kingdom, Color.WHITE)


## Crea el picker bajo host (title con BBCode simple: se quitan las etiquetas) y pausa el juego.
static func open(host: Node, title: String, ids: Array) -> BlessingPicker:
	var p := BlessingPicker.new()
	p._ids = ids
	p._title = title
	host.add_child(p)
	return p


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("blessing_picker")
	get_tree().paused = true
	_opened_ms = Time.get_ticks_msec()

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = HudStyle.menu_theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	center.add_child(v)
	var re := RegEx.create_from_string("\\[/?[a-z]+\\]")
	# Dos lineas: la frase en negrita arriba y "Elige una" abajo; ajusta al ancho de las cartas.
	var title := HudStyle.pixel_label(re.sub(_title.replace("[/b] ", "\n"), "", true), 24, HudStyle.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(880, 0)
	v.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in _ids.size():
		var card := _build_card(i, _ids[i])
		row.add_child(card)
		_cards.append(card)
	v.add_child(_build_hint())
	_select(0)


## Ayuda de abajo: teclado/raton ("1-3 / flechas + ENTER, o clic") o, si el ultimo
## dispositivo fue el mando, "CRUCETA / ESTICK + (A)" con el glifo del boton de aceptar.
func _build_hint() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	var l := HudStyle.pixel_label("", 16, Color(0.8, 0.72, 0.78))
	box.add_child(l)
	var gbox := HBoxContainer.new()  # el glifo decide su propia visibilidad: se oculta la caja
	var g := InputGlyph.new()
	g.action = "ui_accept"
	gbox.add_child(g)
	box.add_child(gbox)
	var upd := func(pad: bool):
		l.text = tr("GLYPH_BPICK_PAD") if pad else tr("BPICK_HINT")
		gbox.visible = pad
	upd.call(InputGlyphs.is_pad())
	InputGlyphs.watcher().device_changed.connect(upd)
	return box


func _build_card(i: int, id: String) -> PanelContainer:
	var b: Dictionary = RunManager.BLESSINGS[id]
	var col: Color = kingdom_color(id)
	var foreign: bool = rm().is_foreign(b.kingdom)
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_card_input.bind(i))
	card.mouse_entered.connect(_select.bind(i))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key := HudStyle.pixel_label(str(i + 1), 24, HudStyle.GOLD, true)
	head.add_child(key)
	var kname := HudStyle.pixel_label(tr(KINGDOM_KEYS.get(b.kingdom, "KINGDOM_MIXED")), 16, col, true)
	kname.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kname.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(kname)
	v.add_child(head)

	var ic := TextureRect.new()
	ic.texture = icon_tex(id)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(144, 144)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(ic)

	v.add_child(_wrapped(Loc.blessing(id, "name"), 16, col, true, HORIZONTAL_ALIGNMENT_CENTER))
	var desc := _wrapped(Loc.blessing(id, "desc"), 16, HudStyle.CREAM, false, HORIZONTAL_ALIGNMENT_CENTER)
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(desc)

	var lvl: int = rm().blessing(id)
	var after: int = lvl + (2 if foreign else 1)
	var lv_text := (tr("BPICK_LEVEL") % after) if lvl == 0 else (tr("BPICK_LEVEL_UP") % [lvl, after])
	v.add_child(_wrapped(lv_text, 16, HudStyle.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	if foreign:
		v.add_child(_wrapped(tr("BPICK_ALLERGY"), 16, Color("ff6b6b"), true, HORIZONTAL_ALIGNMENT_CENTER))
	return card


func _wrapped(text: String, size: int, color: Color, bold: bool, align: HorizontalAlignment) -> Label:
	var l := HudStyle.pixel_label(text, size, color, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align
	l.custom_minimum_size.x = CARD_SIZE.x - 40
	return l


func _select(i: int) -> void:
	_sel = clampi(i, 0, _cards.size() - 1)
	for k in _cards.size():
		var on := k == _sel
		_cards[k].modulate = Color.WHITE if on else Color(0.62, 0.58, 0.68)
		_cards[k].pivot_offset = CARD_SIZE * 0.5
		_cards[k].scale = Vector2(1.04, 1.04) if on else Vector2.ONE


func _on_card_input(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick(i)


func _input(event: InputEvent) -> void:
	if _done or Time.get_ticks_msec() - _opened_ms < GRACE_MS:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var n := -1
		match event.keycode:
			KEY_1, KEY_KP_1: n = 0
			KEY_2, KEY_KP_2: n = 1
			KEY_3, KEY_KP_3: n = 2
		if n >= 0 and n < _cards.size():
			get_viewport().set_input_as_handled()
			_pick(n)
			return
	if event.is_action_pressed("ui_left"):
		_select((_sel - 1 + _cards.size()) % _cards.size())
	elif event.is_action_pressed("ui_right"):
		_select((_sel + 1) % _cards.size())
	elif event.is_action_pressed("ui_accept"):
		_pick(_sel)
	else:
		return
	get_viewport().set_input_as_handled()


## Para el bot (tools/autoplay): elige la carta i como si hubiera hecho clic.
func bot_pick(i: int = 0) -> void:
	_pick(clampi(i, 0, _ids.size() - 1))


func _pick(i: int) -> void:
	if _done:
		return
	_done = true
	PauseMenu.release(get_tree(), self)
	Narrator._ate_input_ms = Time.get_ticks_msec()  # el clic no dispara
	picked.emit(i)
	queue_free()
