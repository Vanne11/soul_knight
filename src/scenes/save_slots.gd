extends CanvasLayer
class_name SaveSlotsScreen

## Pantalla de espacios de guardado (SaveSlots): sale al iniciar el juego, tras el aviso +16, y desde el
## boton del menu. Tres tarjetas con el resumen de cada espacio y JUGAR / DUPLICAR / ELIMINAR.
## ELIMINAR pide pulsar dos veces (la segunda en menos de 3 s). DUPLICAR copia al primer espacio libre.

const MENU_SCENE := "res://src/scenes/main_menu.tscn"
const SURE_SECS := 3.0
const CARD_W := 360.0

## true si se abrio desde el menu (sale VOLVER); al iniciar el juego hay que elegir.
static var from_menu := false

var _root: Control
var _cards: HBoxContainer
var _sure_slot := 0
var _sure_t := 0.0
var _notice: Label
var _focus_slot := 0


func _ready() -> void:
	Sound.music("menu")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = HudStyle.menu_theme()
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root)

	var art := TextureRect.new()
	art.texture = load("res://assets/sprites/ui/screens/menu.png")
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(0.45, 0.4, 0.5)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(art)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)
	var title := HudStyle.pixel_label(tr("SLOTS_TITLE"), 32, Color("ff4f9a"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := HudStyle.pixel_label(tr("SLOTS_SUBTITLE"), 16, HudStyle.CREAM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override("separation", 18)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_cards)
	_notice = HudStyle.pixel_label("", 16, HudStyle.GOLD, true)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_notice)
	if from_menu:
		var back := Button.new()
		back.text = tr("SLOTS_BACK")
		back.custom_minimum_size = Vector2(240, 46)
		back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		back.pressed.connect(_back)
		HudStyle.juice_button(back)
		v.add_child(back)
	_focus_slot = SaveSlots.current()
	_rebuild()


func _process(delta: float) -> void:
	if _sure_slot != 0:
		_sure_t -= delta
		if _sure_t <= 0.0:
			_sure_slot = 0
			_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if from_menu and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back()


func _rebuild() -> void:
	for c in _cards.get_children():
		_cards.remove_child(c)
		c.queue_free()
	var focus: Button = null
	for i in range(1, SaveSlots.COUNT + 1):
		var play := _card(i)
		if i == _focus_slot:
			focus = play
	if focus:
		focus.grab_focus.call_deferred()


## Tarjeta de un espacio; devuelve su boton JUGAR (para el foco).
func _card(i: int) -> Button:
	var s := SaveSlots.summary(i)
	var in_use := i == SaveSlots.current()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_W, 0)
	_cards.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_child(HudStyle.pixel_label(tr("SLOTS_SLOT") % i, 24, HudStyle.GOLD, true))
	if in_use:
		var tag := HudStyle.pixel_label(tr("SLOTS_IN_USE"), 16, Color("7fe0a0"), true)
		tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(tag)
	v.add_child(head)

	var lines: Array = []
	if s.empty:
		lines = [[tr("SLOTS_EMPTY"), HudStyle.CREAM], [tr("SLOTS_EMPTY_HINT"), Color(0.7, 0.66, 0.74)]]
	else:
		lines = [
			[tr("SLOTS_BONES") % s.bones, HudStyle.CREAM],
			[tr("SLOTS_FREED") % [s.liberated, RunManager.regions().size()], HudStyle.CREAM],
			[tr("SLOTS_BEST") % s.best_floor, HudStyle.CREAM],
			[tr("SLOTS_RUNS") % s.runs, HudStyle.CREAM],
			[tr("SLOTS_CODEX") % [s.codex, s.medals], HudStyle.CREAM],
			[tr("SLOTS_DATE") % s.date, Color(0.7, 0.66, 0.74)],
		]
	for l in lines:
		var lab := HudStyle.pixel_label(l[0], 16, l[1])
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.custom_minimum_size.x = CARD_W - 30
		v.add_child(lab)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)

	var play := _button(v, tr("SLOTS_START") if s.empty else tr("SLOTS_PLAY"), _play.bind(i))
	var dst := SaveSlots.first_empty(i)
	var copy := _button(v, (tr("SLOTS_COPY") % dst) if dst != 0 else tr("SLOTS_COPY_NONE"), _copy.bind(i))
	copy.disabled = s.empty or dst == 0
	var del := _button(v, tr("SLOTS_DELETE_SURE") if _sure_slot == i else tr("SLOTS_DELETE"), _delete.bind(i))
	del.disabled = s.empty
	if _sure_slot == i:
		del.add_theme_color_override("font_color", Color("ff6b6b"))
		del.add_theme_color_override("font_focus_color", Color("ff6b6b"))
	return play


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.pressed.connect(cb)
	HudStyle.juice_button(b)
	parent.add_child(b)
	return b


func _play(i: int) -> void:
	SaveSlots.select(i)
	from_menu = false
	Transition.change_scene(MENU_SCENE)


func _copy(i: int) -> void:
	var dst := SaveSlots.first_empty(i)
	if dst == 0:
		return
	SaveSlots.copy(i, dst)
	_notice.text = tr("SLOTS_COPIED") % [i, dst]
	Sound.play("pickup")
	_focus_slot = dst
	_rebuild()


func _delete(i: int) -> void:
	if _sure_slot != i:
		_sure_slot = i
		_sure_t = SURE_SECS
		Sound.play("locked")
		_focus_slot = i
		_rebuild()
		_focus_delete.call_deferred(i)
		return
	_sure_slot = 0
	SaveSlots.erase(i)
	_notice.text = tr("SLOTS_DELETED") % i
	Sound.play("crack")
	_focus_slot = i
	_rebuild()


## Tras el primer ELIMINAR, el foco queda en ese mismo boton (para confirmar con el mando sin moverse).
func _focus_delete(i: int) -> void:
	var card := _cards.get_child(i - 1)
	if card == null:
		return
	var buttons := card.find_children("*", "Button", true, false)
	if buttons.size() >= 3:
		(buttons[2] as Button).grab_focus()


func _back() -> void:
	from_menu = false
	Transition.change_scene(MENU_SCENE)
