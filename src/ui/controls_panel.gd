class_name ControlsPanel
extends VBoxContainer

## Pagina "Controles" de Ajustes: cada accion con su tecla/boton, "pulsa una tecla" para
## cambiarla, conflictos marcados, restaurar por defecto. Se guarda sola (Controls ->
## user://settings.cfg [controls]). Se navega con raton, teclado y mando: las casillas son
## Buttons normales (foco por flechas/stick, aceptar para reasignar).
## Va incrustada en SettingsPanel (que le pone el tema); `back` = VOLVER.
## Textos: locale/controles.csv.

signal back

const LISTEN_GRACE := 0.25  # ignora lo pulsado justo al abrir (el propio "aceptar")
const LISTEN_TIME := 8.0
const COL_WARN := Color("ffb347")
const COL_BAD := Color("ff6a6a")
const COL_OK := Color("9be8a0")

var _device := Controls.KB
var _scroll: ScrollContainer
var _grid: GridContainer
var _msg: Label
var _tab_kb: Button
var _tab_pad: Button
var _restore: Button
var _btns := {}          # "accion:casilla" -> Button
var _icon_cache := {}
var _listen_action := ""
var _listen_slot := 0
var _listen_t := 0.0
var _last_focus := ""    # casilla enfocada antes de redibujar


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	add_theme_constant_override("separation", 10)
	_device = Controls.PAD if InputGlyphs.is_pad() else Controls.KB
	add_child(HudStyle.pixel_label(tr("CTRL_TITLE"), 24, Color("ff4f9a"), true))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	_tab_kb = _tab(tr("CTRL_TAB_KB"), Controls.KB)
	_tab_pad = _tab(tr("CTRL_TAB_PAD"), Controls.PAD)
	tabs.add_child(_tab_kb)
	tabs.add_child(_tab_pad)
	add_child(tabs)

	_scroll = ScrollContainer.new()
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, 250 if Settings.ui_size == 1 else 330)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 6)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_grid)

	_msg = HudStyle.pixel_label("", 16, HudStyle.CREAM)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size = Vector2(0, 44)
	add_child(_msg)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	_restore = Button.new()
	_restore.custom_minimum_size = Vector2(0, 46)
	_restore.pressed.connect(_on_restore)
	_wire(_restore)
	bottom.add_child(_restore)
	var bk := Button.new()
	bk.text = tr("SETTINGS_BACK")
	bk.custom_minimum_size = Vector2(0, 46)
	bk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bk.pressed.connect(func(): back.emit())
	_wire(bk)
	bottom.add_child(bk)
	add_child(bottom)
	_rebuild()
	_say(tr("CTRL_IDLE"), HudStyle.CREAM)


func focus_first() -> void:
	(_tab_pad if _device == Controls.PAD else _tab_kb).grab_focus()


func _wire(b: Button) -> void:
	b.mouse_entered.connect(func(): if not b.disabled and _listen_action == "": b.grab_focus())
	b.pressed.connect(func(): Sound.play("pickup"))


func _tab(text: String, device: String) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(250, 44)
	b.add_theme_stylebox_override("hover_pressed", HudStyle.button_box("pressed"))
	b.pressed.connect(func():
		_device = device
		_rebuild())
	_wire(b)
	return b


# ---------------------------------------------------------------- tabla
func _rebuild() -> void:
	_tab_kb.set_pressed_no_signal(_device == Controls.KB)
	_tab_pad.set_pressed_no_signal(_device == Controls.PAD)
	_restore.text = tr("CTRL_RESTORE_KB") if _device == Controls.KB else tr("CTRL_RESTORE_PAD")
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_btns.clear()
	var n: int = Controls.SLOTS[_device]
	_grid.columns = n + 2
	for a in Controls.ACTIONS:
		var act: String = a[0]
		var bad: bool = Controls.is_unassigned(act, _device)
		var clash: bool = Controls.has_conflict(act, _device)
		var l := HudStyle.pixel_label(tr(a[1]), 16, COL_BAD if bad else (COL_WARN if clash else HudStyle.CREAM))
		l.custom_minimum_size.x = 250
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_grid.add_child(l)
		var codes: Array = Controls.slots(act, _device)
		for i in n:
			var b := _slot_button(act, i, codes[i])
			_btns["%s:%d" % [act, i]] = b
			_grid.add_child(b)
		var note := ""
		var note_col := COL_WARN
		if bad:
			note = tr("CTRL_UNASSIGNED")
			note_col = COL_BAD
		elif clash:
			note = tr("CTRL_CONFLICT")
		elif _device == Controls.PAD and act.begins_with("move_"):
			note = tr("CTRL_STICK")
			note_col = Color(0.7, 0.66, 0.76)
		var nl := HudStyle.pixel_label(note, 16, note_col)
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_grid.add_child(nl)
	if _last_focus != "" and _btns.has(_last_focus):
		(_btns[_last_focus] as Button).grab_focus.call_deferred()


func _slot_button(action: String, slot: int, code: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(170, 38)
	b.clip_text = true
	b.add_theme_constant_override("icon_max_width", 28)
	b.add_theme_constant_override("h_separation", 8)
	b.add_theme_stylebox_override("normal", _slot_box("normal"))
	b.add_theme_stylebox_override("hover", _slot_box("hover"))
	b.add_theme_stylebox_override("focus", _slot_box("hover"))
	b.add_theme_stylebox_override("pressed", _slot_box("pressed"))
	if code == "":
		b.text = tr("CTRL_EMPTY")
		b.add_theme_color_override("font_color", Color(0.5, 0.46, 0.56))
	else:
		var g := InputGlyphs.code_glyph(code)
		b.text = String(g.get("label", "?"))
		if g.get("kind", "") == "tex" and g.tex != null:
			b.icon = _big(g.tex)
	b.pressed.connect(_begin_listen.bind(action, slot))
	b.focus_entered.connect(func(): _last_focus = "%s:%d" % [action, slot])
	_wire(b)
	return b


static func _slot_box(state: String) -> StyleBox:
	var sb := HudStyle.button_box(state)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	return sb


## Glifo de 14 px de arte a 2x sin suavizar (los botones no escalan con NEAREST por si solos).
func _big(t: Texture2D) -> Texture2D:
	if not _icon_cache.has(t):
		var img := t.get_image()
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
		_icon_cache[t] = ImageTexture.create_from_image(img)
	return _icon_cache[t]


# ---------------------------------------------------------------- reasignar
func _begin_listen(action: String, slot: int) -> void:
	_listen_action = action
	_listen_slot = slot
	_listen_t = 0.0
	set_process(true)
	_update_listen_msg()


func _update_listen_msg() -> void:
	var key := "CTRL_LISTEN_KB" if _device == Controls.KB else "CTRL_LISTEN_PAD"
	_say(tr(key) % [tr(Controls.label_key(_listen_action)), maxi(0, int(ceil(LISTEN_TIME - _listen_t)))], Color("ffe27a"))


func _process(delta: float) -> void:
	if _listen_action == "":
		set_process(false)
		return
	_listen_t += delta
	if _listen_t >= LISTEN_TIME:
		_end_listen()
		_say(tr("CTRL_CANCELLED"), HudStyle.CREAM)
	else:
		_update_listen_msg()


func _end_listen() -> void:
	_listen_action = ""
	set_process(false)


## Mientras se escucha se traga TODO lo de teclado/raton/mando (nada llega a los botones).
func _input(e: InputEvent) -> void:
	if _listen_action == "":
		return
	var code := ""
	var clear := false
	if e is InputEventKey:
		if not e.pressed or e.echo:
			return
		if e.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_end_listen()
			_say(tr("CTRL_CANCELLED"), HudStyle.CREAM)
			return
		if _listen_t < LISTEN_GRACE:
			get_viewport().set_input_as_handled()
			return
		if e.physical_keycode in [KEY_DELETE, KEY_BACKSPACE]:
			clear = true
		elif _device == Controls.KB:
			code = Controls.code_of(e)
	elif e is InputEventMouseButton:
		if not e.pressed or _listen_t < LISTEN_GRACE:
			return
		if _device == Controls.KB and e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
			code = Controls.code_of(e)
	elif e is InputEventJoypadButton:
		if not e.pressed or _listen_t < LISTEN_GRACE:
			return
		if _device == Controls.PAD:
			code = Controls.code_of(e)
	elif e is InputEventJoypadMotion:
		if _device == Controls.PAD and _listen_t >= LISTEN_GRACE and e.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] and e.axis_value > 0.7:
			code = Controls.code_of(e)
	else:
		return
	get_viewport().set_input_as_handled()
	if code == "" and not clear:
		return
	_assign(code)


func _assign(code: String) -> void:
	var action := _listen_action
	_end_listen()
	var shown := _name_of(action)
	if code == "":
		Controls.set_code(action, _device, _listen_slot, "")
		_say(tr("CTRL_CLEARED") % shown, HudStyle.CREAM)
	else:
		var stolen: String = Controls.set_code(action, _device, _listen_slot, code)
		var kname := String(InputGlyphs.code_glyph(code).get("label", "?"))
		if stolen != "":
			_say(tr("CTRL_STOLEN") % [shown, kname, _name_of(stolen)], COL_WARN)
		else:
			_say(tr("CTRL_SAVED") % [shown, kname], COL_OK)
	_rebuild()


func _name_of(action: String) -> String:
	return tr(Controls.label_key(action))


func _on_restore() -> void:
	Controls.reset(_device)
	_rebuild()
	_say(tr("CTRL_RESTORED"), COL_OK)


func _say(text: String, color: Color) -> void:
	_msg.text = text
	_msg.add_theme_color_override("font_color", color)
