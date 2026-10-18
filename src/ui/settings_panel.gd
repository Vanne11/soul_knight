class_name SettingsPanel
extends PanelContainer

## Panel de ajustes reutilizable (menu principal y pausa). Se construye por
## codigo y se reconstruye al cambiar de idioma. Emite `closed` con VOLVER.
## Los cambios se aplican y guardan al momento (autoload Settings).
##   var p := SettingsPanel.new(); parent.add_child(p); p.closed.connect(...)

signal closed

var _lang_option: OptionButton


func _init() -> void:
	theme = _make_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(560, 0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # tambien funciona con el juego en pausa
	_build()
	Settings.changed.connect(_on_settings_changed)


func _on_settings_changed() -> void:
	_rebuild_deferred.call_deferred()


func focus_first() -> void:
	for c in find_children("*", "HSlider", true, false):
		c.grab_focus()
		return


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14 if Settings.ui_size == 0 else 9)  # UI grande: cabe en pantalla chica
	add_child(box)
	box.add_child(HudStyle.pixel_label(tr("SETTINGS_TITLE"), 24, Color("ff4f9a"), true))

	box.add_child(_row(tr("SETTINGS_MUSIC"), _slider(Settings.music_volume, Settings.set_music_volume, false)))
	box.add_child(_row(tr("SETTINGS_SFX"), _slider(Settings.sfx_volume, Settings.set_sfx_volume, true)))

	var fs := CheckButton.new()
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on: bool): Settings.set_fullscreen(on))
	fs.mouse_entered.connect(fs.grab_focus)
	box.add_child(_row(tr("SETTINGS_FULLSCREEN"), fs))

	var fx := OptionButton.new()
	fx.custom_minimum_size = Vector2(220, 40)
	for i in 3:
		fx.add_item(tr("SETTINGS_FX_%d" % i), i)
	fx.select(Settings.screen_fx)
	fx.item_selected.connect(func(i: int): Settings.set_screen_fx(i))
	fx.mouse_entered.connect(fx.grab_focus)
	box.add_child(_row(tr("SETTINGS_FX"), fx))

	var sh := CheckButton.new()
	sh.button_pressed = Settings.screen_shake
	sh.toggled.connect(func(on: bool): Settings.set_screen_shake(on))
	sh.mouse_entered.connect(sh.grab_focus)
	box.add_child(_row(tr("SETTINGS_SHAKE"), sh))

	_lang_option = OptionButton.new()
	_lang_option.custom_minimum_size = Vector2(220, 40)
	var sel := 0
	for i in Settings.LOCALES.size():
		_lang_option.add_item(Settings.LOCALES[i][1], i)
		if Settings.LOCALES[i][0] == Settings.locale:
			sel = i
	_lang_option.select(sel)
	_lang_option.item_selected.connect(_on_lang)
	_lang_option.mouse_entered.connect(_lang_option.grab_focus)
	box.add_child(_row(tr("SETTINGS_LANGUAGE"), _lang_option))

	_build_touch_rows(box)

	var back := Button.new()
	back.text = tr("SETTINGS_BACK")  # antes de juice_button: guarda el texto final
	back.custom_minimum_size = Vector2(0, 46)
	back.pressed.connect(func(): closed.emit())
	HudStyle.juice_button(back)
	box.add_child(back)


## Bloque movil/tactil (F4): tamano de la interfaz y controles tactiles.
func _build_touch_rows(box: VBoxContainer) -> void:
	var ui := OptionButton.new()
	ui.custom_minimum_size = Vector2(220, 40)
	for i in 2:
		ui.add_item(tr("SETTINGS_UISIZE_%d" % i), i)
	ui.select(Settings.ui_size)
	ui.item_selected.connect(func(i: int): Settings.set_ui_size(i))
	ui.mouse_entered.connect(ui.grab_focus)
	box.add_child(_row(tr("SETTINGS_UISIZE"), ui))

	var tc := OptionButton.new()
	tc.custom_minimum_size = Vector2(220, 40)
	for i in 3:
		tc.add_item(tr("SETTINGS_TOUCH_%d" % i), i)
	tc.select(Settings.touch_mode)
	tc.item_selected.connect(func(i: int): Settings.set_touch_mode(i))
	tc.mouse_entered.connect(tc.grab_focus)
	box.add_child(_row(tr("SETTINGS_TOUCH"), tc))


func _row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := HudStyle.pixel_label(label_text, 16)
	l.custom_minimum_size.x = 200
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if control is HSlider else Control.SIZE_SHRINK_BEGIN
	row.add_child(control)
	return row


## Slider 0-100 con su cifra al lado. `preview`: el de efectos suena al soltar.
func _slider(value: int, setter: Callable, preview: bool) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.value = value
	s.custom_minimum_size = Vector2(220, 32)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var num := HudStyle.pixel_label("%d" % value, 16, HudStyle.GOLD)
	num.custom_minimum_size.x = 48
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(v: float):
		setter.call(int(v))
		num.text = "%d" % int(v))
	if preview:
		s.drag_ended.connect(func(_changed: bool): Sound.play("pickup"))
	s.mouse_entered.connect(s.grab_focus)
	h.add_child(s)
	h.add_child(num)
	return h


func _on_lang(index: int) -> void:
	Settings.set_locale(Settings.LOCALES[index][0])  # emite changed: el panel se reconstruye


func _rebuild_deferred() -> void:
	if not is_inside_tree():
		return
	_build()
	if _lang_option:
		_lang_option.grab_focus()


# ---------------------------------------------------------------- estilo
## Menu theme + sliders, check y desplegable en dorado/crema.
static func _make_theme() -> Theme:
	var t := HudStyle.menu_theme()

	# HSlider: riel oscuro fino, tramo lleno dorado, tirador crema
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color("1a0b26")
	rail.set_border_width_all(2)
	rail.border_color = Color("b08d4a")
	rail.content_margin_top = 5
	rail.content_margin_bottom = 5
	t.set_stylebox("slider", "HSlider", rail)
	var fill := StyleBoxFlat.new()
	fill.bg_color = HudStyle.GOLD
	fill.content_margin_top = 5
	fill.content_margin_bottom = 5
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _block_icon(Vector2i(12, 28), HudStyle.CREAM)
	var grab_hi := _block_icon(Vector2i(12, 28), Color("ff4f9a"))
	t.set_icon("grabber", "HSlider", grab)
	t.set_icon("grabber_highlight", "HSlider", grab_hi)
	t.set_icon("grabber_disabled", "HSlider", grab)

	# CheckButton / OptionButton: mismo tipo de letra y colores
	for cls in ["CheckButton", "OptionButton", "PopupMenu"]:
		t.set_font("font", cls, HudStyle.FONT_BOLD)
		t.set_font_size("font_size", cls, 16)
		t.set_color("font_color", cls, HudStyle.CREAM)
		t.set_color("font_hover_color", cls, Color("fff1a8"))
		t.set_color("font_focus_color", cls, Color("fff1a8"))
		t.set_color("font_pressed_color", cls, HudStyle.GOLD)
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "OptionButton", HudStyle.button_box(st))
	t.set_stylebox("focus", "OptionButton", HudStyle.button_box("hover"))
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())

	var sw_off := _switch_icon(false)
	var sw_on := _switch_icon(true)
	t.set_icon("unchecked", "CheckButton", sw_off)
	t.set_icon("unchecked_disabled", "CheckButton", sw_off)
	t.set_icon("checked", "CheckButton", sw_on)
	t.set_icon("checked_disabled", "CheckButton", sw_on)

	var pop := StyleBoxFlat.new()
	pop.bg_color = Color("1a0b26")
	pop.set_border_width_all(2)
	pop.border_color = HudStyle.GOLD
	pop.set_content_margin_all(6)
	t.set_stylebox("panel", "PopupMenu", pop)
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color("4a2a5e")
	t.set_stylebox("hover", "PopupMenu", hov)
	t.set_constant("v_separation", "PopupMenu", 10)
	return t


## Interruptor pixel: caja oscura con borde dorado y un tirador a un lado.
static func _switch_icon(on: bool) -> Texture2D:
	var img := Image.create(48, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color("b08d4a"))
	img.fill_rect(Rect2i(2, 2, 44, 20), HudStyle.GOLD if on else Color("1a0b26"))
	var kx := 26 if on else 4
	img.fill_rect(Rect2i(kx, 4, 18, 16), HudStyle.SHADOW)
	img.fill_rect(Rect2i(kx + 2, 6, 14, 12), HudStyle.CREAM if on else Color("8a8494"))
	return ImageTexture.create_from_image(img)


static func _block_icon(size: Vector2i, color: Color) -> Texture2D:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(HudStyle.SHADOW)
	img.fill_rect(Rect2i(2, 2, size.x - 4, size.y - 4), color)
	return ImageTexture.create_from_image(img)
