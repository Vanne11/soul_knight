extends CanvasLayer

@onready var _game_controller = get_node("/root/GameController")

func _ready() -> void:
	Sound.music("menu")  # sigue sonando en la intro y la eleccion de heroe
	_create_ui()
	_update_meta_info()
	FourthWall.menu_opened()  # cuarta pared: nombre (una vez) y comentario de vuelta

func _create_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = HudStyle.menu_theme()
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)
	_root = root

	# ilustracion de portada (320x180 a 4x, ver tools/gen_intro_art.py menu)
	var art := TextureRect.new()
	art.texture = load("res://assets/sprites/ui/screens/menu.png")
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)

	_build_logo(root)

	# botones: panel a la izquierda (los heroes de la ilustracion quedan al centro)
	var panel := PanelContainer.new()
	panel.position = Vector2(36, 190)
	panel.custom_minimum_size = Vector2(300, 0)
	root.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	start_btn = _menu_button(vbox, tr("MENU_NEW_GAME"), _on_start)
	if has_desordenes():
		_menu_button(vbox, tr("DESORDEN_MENU_BTN"), _open_desordenes)  # aviso del post-juego, hasta liberar todo
	daily_btn = _menu_button(vbox, tr("CENSURA_DAILY_BTN"), _on_daily)
	daily_btn.tooltip_text = tr("CENSURA_DAILY_TIP")
	continue_btn = _menu_button(vbox, tr("MENU_UPGRADES"), _open_upgrades)
	# Codice y Medallas comparten fila (asi la columna no crece y no pisa el selector de Censura)
	var lore_row := HBoxContainer.new()
	lore_row.add_theme_constant_override("separation", 10)
	vbox.add_child(lore_row)
	lore_btn = _menu_button(lore_row, tr("MENU_CODEX"), _open_codex)
	lore_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var medal_btn := _menu_button(lore_row, tr("MEDAL_MENU_BTN"), _open_medals)
	medal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Ajustes y espacio de guardado comparten fila (la columna no crece)
	var cfg_row := HBoxContainer.new()
	cfg_row.add_theme_constant_override("separation", 10)
	vbox.add_child(cfg_row)
	settings_btn = _menu_button(cfg_row, tr("SETTINGS_TITLE"), _open_settings)
	settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slots_btn := _menu_button(cfg_row, tr("MENU_SLOTS") % SaveSlots.current(), _open_slots)
	slots_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn = _menu_button(vbox, tr("MENU_QUIT"), _on_quit)
	start_btn.grab_focus.call_deferred()

	_build_censura_selector(root)

	# derecha: el mundo (regiones liberadas) + tu progreso
	var side := PanelContainer.new()
	side.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	side.offset_left = -326
	side.offset_right = -36
	side.offset_top = 190
	root.add_child(side)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	side.add_child(sv)
	sv.add_child(HudStyle.pixel_label(tr("MENU_WORLD"), 16, HudStyle.GOLD, true))
	sv.add_child(_world_strip())
	var meta_box := VBoxContainer.new()
	meta_box.add_theme_constant_override("separation", 4)
	sv.add_child(meta_box)
	_meta_box = meta_box


## Hay un aviso de "Desordenes" guardado (ganaste y quedaron reinos sin liberar).
func has_desordenes() -> bool:
	var rm = _game_controller.get_run_manager()
	return rm.desorden_notice and not rm.pending_regions().is_empty()


## Panel de DesordenPanel sobre el menu; "terminar por ahora" lo cierra y el aviso sigue.
func _open_desordenes() -> void:
	var rm = _game_controller.get_run_manager()
	var panel := DesordenPanel.create(rm)
	if panel == null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	center.add_child(panel)
	var close := func():
		_close_popup = Callable()
		dim.queue_free()
		start_btn.grab_focus.call_deferred()
	_close_popup = close
	panel.closed.connect(close)


func _open_slots() -> void:
	SaveSlotsScreen.from_menu = true
	Transition.change_scene("res://src/scenes/save_slots.tscn")


func _menu_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(cb)
	HudStyle.juice_button(b)
	parent.add_child(b)
	return b


## Logo: Silkscreen gordo con dos sombras duras (morado + oro) y un vaivén suave.
func _build_logo(root: Control) -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_CENTER_TOP)
	holder.offset_top = 22
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var layers := [[Vector2(8, 8), Color("1a0b26")], [Vector2(4, 4), Color("b08d4a")], [Vector2.ZERO, Color("ff4f9a")]]
	for l in layers:
		var t := HudStyle.pixel_label(tr("MENU_TITLE"), 64, l[1], true)
		t.add_theme_constant_override("shadow_offset_x", 0)
		t.add_theme_constant_override("shadow_offset_y", 0)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.position = Vector2(-640, 0) + l[0]
		t.size = Vector2(1280, 80)
		holder.add_child(t)
	# subtitulo en una cinta oscura: sobre las nubes no se leia
	var ribbon := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.05, 0.15, 0.82)
	sb.set_content_margin_all(6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	ribbon.add_theme_stylebox_override("panel", sb)
	ribbon.add_child(HudStyle.pixel_label(tr("MENU_SUBTITLE"), 16, HudStyle.CREAM))
	holder.add_child(ribbon)
	ribbon.size = ribbon.get_combined_minimum_size()
	ribbon.position = Vector2(-roundf(ribbon.size.x / 2.0), 90)
	_logo = holder
	_logo_y = holder.position.y


## Vaiven del logo en pixeles enteros (un tween lo dejaria en medio pixel: borroso).
var _t := 0.0
var _logo_y := 0.0
func _process(delta: float) -> void:
	_t += delta
	if _logo:
		_logo.position.y = _logo_y + roundf(sin(_t * 2.4) * 3.0)

## El mundo: cada region liberada alguna vez sale en su color; las demas, grises.
## Es lo que se gana a la larga, a la vista nada mas abrir el juego.
func _world_strip() -> Control:
	var rm = _game_controller.get_run_manager()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var regions := RunManager.world_order()  # orden de la historia, no el de los archivos
	for i in regions.size():
		# un reino = sus dos etapas: se muestra con el nombre y color de la 1a
		var first := 1 + RunManager.FLOORS.find_custom(func(x): return x.region == regions[i])
		var f: Dictionary = RunManager.FLOORS[first - 1]
		var free: bool = rm.is_region_liberated(regions[i])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = f.tint if free else Color(0.4, 0.4, 0.44)
		row.add_child(dot)
		row.add_child(HudStyle.pixel_label("%d %s" % [i + 1, Loc.floor_name(f, true)], 16,
			f.tint.lightened(0.2) if free else Color(0.55, 0.55, 0.6)))
		col.add_child(row)
	var n: int = rm.liberated.size()
	var caption := Label.new()
	caption.text = tr("MENU_WORLD_GRAY") if n == 0 \
		else tr("MENU_WORLD_FREED") % [n, regions.size()]
	if has_desordenes():
		caption.text += "\n" + tr("DESORDEN_TITULO") % DesordenPanel.pending_names(rm)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = 250
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color(0.8, 0.72, 0.78))
	col.add_child(caption)
	return col

var start_btn: Button
var daily_btn: Button
var _cens_label: Label
var _cens_rules: GridContainer
var _cens_down: Button
var _cens_up: Button
var continue_btn: Button
var lore_btn: Button
var settings_btn: Button
var quit_btn: Button
var _meta_box: VBoxContainer
var _root: Control
var _close_popup := Callable()  # cierra la ventana emergente abierta (codice, mejoras, ajustes): ESC
var _logo: Control

func _update_meta_info() -> void:
	var rm = _game_controller.get_run_manager()
	var lore_pct = _game_controller.get_lore_database().get_completion_percentage()
	for c in _meta_box.get_children():
		c.queue_free()
	for pair in [["bone", tr("MENU_BONES") % rm.meta_currency], ["stairs", tr("MENU_BEST_FLOOR") % rm.best_floor], ["skull", tr("MENU_CODEX_PCT") % lore_pct]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(HudStyle.icon(pair[0]))
		row.add_child(HudStyle.pixel_label(pair[1], 16))
		_meta_box.add_child(row)

# ---------------------------------------------------------------- ventanas
## Ventana encima del menu con titulo, contenido y "Volver".
func _window(title_text: String) -> VBoxContainer:
	# velo oscuro detras: la caja es semitransparente y se colaba el menu
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120; panel.offset_right = -120
	panel.offset_top = 60; panel.offset_bottom = -60
	panel.add_theme_stylebox_override("panel", HudStyle.panel_box(22))
	dim.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(HudStyle.pixel_label(title_text, 24, Color("ff4f9a"), true))
	var back := Button.new()
	back.text = tr("MENU_BACK")
	var close := func():
		_close_popup = Callable()
		dim.queue_free()
		_update_meta_info()
		start_btn.grab_focus()
	back.pressed.connect(close)
	_close_popup = close
	HudStyle.juice_button(back)
	box.add_child(back)
	back.grab_focus.call_deferred()
	return box

## Ajustes (el mismo panel que en la pausa). Al cambiar de idioma el menu se
## reconstruye entero para que los textos se actualicen.
func _open_settings() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var sp := SettingsPanel.new()
	center.add_child(sp)
	var locale_at_open: String = Settings.locale
	sp.closed.connect(func():
		_close_popup = Callable()
		dim.queue_free()
		if Settings.locale != locale_at_open:
			Transition.reload()
		else:
			settings_btn.grab_focus())
	_close_popup = func(): sp.closed.emit()
	sp.focus_first.call_deferred()


## Mejoras permanentes: se pagan con los huesos que deja cada partida.
func _open_upgrades() -> void:
	var box := _window(tr("MENU_UPGRADES_TITLE"))
	var info := Label.new()
	box.add_child(info)
	var rows := VBoxContainer.new()
	box.add_child(rows)
	_fill_upgrades(info, rows)

func _fill_upgrades(info: Label, rows: VBoxContainer) -> void:
	var rm = _game_controller.get_run_manager()
	info.text = tr("MENU_UPGRADES_INFO") % rm.meta_currency
	for c in rows.get_children():
		c.queue_free()
	for id in RunManager.META_UPGRADES:
		var u: Dictionary = RunManager.META_UPGRADES[id]
		var lvl: int = rm.meta_level(id)
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if lvl >= u.max:
			b.text = tr("MENU_UPGRADE_MAX") % [Loc.meta(id, "name"), Loc.meta(id, "desc"), lvl, u.max]
			b.disabled = true
		else:
			b.text = tr("MENU_UPGRADE_BUY") % [Loc.meta(id, "name"), Loc.meta(id, "desc"), lvl, u.max, rm.meta_cost(id)]
			b.disabled = rm.meta_currency < rm.meta_cost(id)
		b.pressed.connect(func():
			rm.buy_meta(id)
			_fill_upgrades(info, rows))
		rows.add_child(b)

## Medallas (logros): grilla con las ganadas y las bloqueadas (src/ui/medal_screen.gd).
func _open_medals() -> void:
	var m = get_node("/root/Medallas")
	var box := _window(tr("MEDAL_TITLE") % [m.won_count(), m.total()])
	MedalScreen.build(box)


## Codice: lo que has descubierto (inscripciones, objetos, enemigos...). Lo demas, "???".
## Cada entrada lleva su imagen: el objeto, el bicho, el heroe o la ilustracion
## del lugar. Las bloqueadas salen en silueta negra, para picar la curiosidad.
func _open_codex() -> void:
	var lore = _game_controller.get_lore_database()
	var box := _window(tr("CODEX_TITLE") % lore.get_completion_percentage())
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(340, 0)
	list.fixed_icon_size = Vector2i(32, 32)
	list.add_theme_constant_override("icon_margin", 8)
	split.add_child(list)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 12)
	split.add_child(detail)
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.visible = false
	detail.add_child(frame)
	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	frame.add_child(pic)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.text = tr("CODEX_HINT")
	detail.add_child(text)
	var entries: Array = lore.get_all_entries()
	# Secciones propias "Orgullo", "Silencio" y "Educacion": van al final de la lista, con su marca en el nombre
	var pride: int = LoreEntry.Category.ORGULLO
	var silence: int = LoreEntry.Category.SILENCIO
	var tail := func(e) -> int:
		if Edu.is_codex_entry(e.id):
			return 3
		return 2 if e.category == silence else (1 if e.category == pride else 0)
	entries.sort_custom(func(a, b):
		if tail.call(a) != tail.call(b):
			return tail.call(a) < tail.call(b)
		return a.unlocked and not b.unlocked if a.unlocked != b.unlocked else Loc.lore_title(a) < Loc.lore_title(b))
	for e in entries:
		var img: Texture2D = CodexArt.image(e)
		var label: String = Loc.lore_title(e) if e.unlocked else "???"
		if Edu.is_codex_entry(e.id) and e.unlocked:
			label = tr("EDU_CODEX_TAG") + label
		elif e.category == pride and e.unlocked:
			label = tr("ORGULLO_CODEX_TAG") + label
		elif e.category == silence and e.unlocked:
			label = tr("SIL_CODEX_TAG") + label
		list.add_item(label, CodexArt.thumb(img, 32, not e.unlocked) if img else null)
		# Las bloqueadas NO van deshabilitadas: asi las flechas siguen bajando y se ve cuanto falta.
		if not e.unlocked:
			list.set_item_custom_fg_color(list.item_count - 1, Color(0.55, 0.5, 0.6))
	list.item_selected.connect(func(i):
		var e = entries[i]
		if not e.unlocked:
			# solo la silueta y un empujon: nada de spoilers
			var sil: Texture2D = CodexArt.image(e)
			frame.visible = sil != null
			if sil:
				pic.texture = CodexArt.thumb(sil, 160, true, true)
				pic.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
				pic.custom_minimum_size = Vector2(pic.texture.get_width(), pic.texture.get_height())
			text.text = "[b]???[/b]\n\n" + tr("CODEX_LOCKED")
			return
		var art: Texture2D = CodexArt.illustration(e)  # lamina ilustrada; si no hay, el sprite de siempre
		var img: Texture2D = art if art else CodexArt.image(e)
		frame.visible = img != null
		if img:
			pic.texture = img
			if art:
				# ilustracion (no es pixel art): escala suave a un cuadrado de 280
				pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
				pic.custom_minimum_size = Vector2(280, 280)
			else:
				# escala entera (pixel art nitido): lo mas grande que quepa en ~560x250
				var k := maxi(1, mini(int(560.0 / img.get_width()), int(250.0 / img.get_height())))
				pic.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
				pic.custom_minimum_size = Vector2(img.get_width(), img.get_height()) * k
		text.text = "[b]%s[/b]\n\n%s\n\n[i]%s[/i]" % [Loc.lore_title(e), Loc.lore_text(e), Loc.lore_flavor(e)] + _edu_source(e.id))


## Linea "Fuente: ..." al final del detalle del codice (solo entradas educativas).
func _edu_source(lore_id: String) -> String:
	var s := Edu.source_line(lore_id)
	return "\n\n" + s if s != "" else ""


## Selector de Censura (nivel 0 = juego normal): flechas hasta el maximo desbloqueado y la
## lista de reglas activas. Siempre visible: vale para la partida normal y para la del dia.
func _build_censura_selector(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(36, 548)
	panel.custom_minimum_size = Vector2(300, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_cens_down = Button.new()
	_cens_down.text = "◀"
	_cens_down.pressed.connect(_censura_step.bind(-1))
	row.add_child(_cens_down)
	_cens_label = HudStyle.pixel_label("", 16, Color("ff4f9a"), true)
	_cens_label.custom_minimum_size.x = 150
	_cens_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_cens_label)
	_cens_up = Button.new()
	_cens_up.text = "▶"
	_cens_up.pressed.connect(_censura_step.bind(1))
	row.add_child(_cens_up)
	# reglas activas: panel aparte, a la derecha bajo "El mundo" (a la izquierda no cabe la lista)
	var rpanel := PanelContainer.new()
	rpanel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rpanel.offset_left = -326
	rpanel.offset_right = -36
	rpanel.offset_top = 530
	root.add_child(rpanel)
	_cens_rules = GridContainer.new()  # 2 columnas: con 10 reglas una sola no cabe
	_cens_rules.columns = 2
	_cens_rules.add_theme_constant_override("h_separation", 10)
	_cens_rules.add_theme_constant_override("v_separation", 3)
	rpanel.add_child(_cens_rules)
	_refresh_censura()


func _censura_step(d: int) -> void:
	var rm = _game_controller.get_run_manager()
	rm.censura_selected = clampi(rm.censura_selected + d, 0, rm.censura_unlocked)
	rm.save_meta_progression()
	_refresh_censura()


func _refresh_censura() -> void:
	var rm = _game_controller.get_run_manager()
	var n: int = rm.censura_selected
	_cens_label.text = tr("CENSURA_LEVEL") % [n, rm.censura_unlocked]
	_cens_down.disabled = n <= 0
	_cens_up.disabled = n >= rm.censura_unlocked
	Censura.level = n  # solo para que rule_ids() de abajo use el nivel elegido
	for c in _cens_rules.get_children():
		c.queue_free()
	if n == 0:
		_cens_rules.add_child(_rule_label(tr("CENSURA_NORMAL")))
	for id in Censura.rule_ids():
		_cens_rules.add_child(_rule_label("• " + Censura.rule_name(id)))
	_cens_rules.tooltip_text = "\n".join(Censura.rule_ids().map(func(id): return "%s: %s" % [Censura.rule_name(id), Censura.rule_desc(id)]))
	# partida del dia: resumen del record de hoy en el boton
	var rec: Dictionary = rm.daily_record()
	daily_btn.text = tr("CENSURA_DAILY_BTN") if rec.is_empty() else tr("CENSURA_DAILY_BTN_REC") % _daily_summary(rec)


func _rule_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.9, 0.82, 0.88))
	return l


func _daily_summary(rec: Dictionary) -> String:
	if bool(rec.get("victory", false)):
		var t := int(rec.get("time", 0.0))
		return tr("CENSURA_DAILY_WIN") % [t / 60, t % 60]
	return tr("CENSURA_DAILY_FLOOR") % int(rec.get("floor", 1))


func _on_daily() -> void:
	_game_controller.get_run_manager().rescue_requested = false
	# misma historia + eleccion de heroe; intro.gd arranca la run con la semilla de hoy
	_game_controller.get_run_manager().daily_requested = true
	Transition.change_scene("res://src/scenes/intro.tscn")


func _on_start() -> void:
	_game_controller.get_run_manager().rescue_requested = false  # partida normal, no de rescate
	_game_controller.get_run_manager().daily_requested = false
	# historia + eleccion de personaje; la run empieza alli
	Transition.change_scene("res://src/scenes/intro.tscn")

func _on_continue() -> void:
	pass

func _on_quit() -> void:
	await FourthWall.farewell()  # despedida corta (~2 s, se salta con una tecla)
	get_tree().quit()


## ESC (accion "pause") cierra la ventana emergente abierta, como su boton VOLVER.
func _unhandled_input(event: InputEvent) -> void:
	if _close_popup.is_valid() and event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_close_popup.call()
