extends CanvasLayer

@onready var _game_controller = get_node("/root/GameController")

func _ready() -> void:
	_create_ui()
	_update_meta_info()

func _create_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color("2a1440")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	bg.add_child(vbox)
	
	var title = Label.new()
	title.text = "ROGUE REPRODUCTIVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("ff4f9a"))
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "La Gran Censura: un roguelike sobre órganos, hormonas y malas decisiones"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.6, 0.7, 1))
	vbox.add_child(subtitle)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)
	
	var start_btn = Button.new()
	start_btn.text = "NUEVA RUN"
	start_btn.custom_minimum_size = Vector2(300, 60)
	start_btn.pressed.connect(_on_start)
	vbox.add_child(start_btn)
	
	var continue_btn = Button.new()
	continue_btn.text = "MEJORAS (HUESOS)"
	continue_btn.custom_minimum_size = Vector2(300, 60)
	continue_btn.pressed.connect(_open_upgrades)
	vbox.add_child(continue_btn)
	
	var lore_btn = Button.new()
	lore_btn.text = "CÓDICE (LORE)"
	lore_btn.custom_minimum_size = Vector2(300, 60)
	lore_btn.pressed.connect(_open_codex)
	vbox.add_child(lore_btn)
	
	var settings_btn = Button.new()
	settings_btn.text = "AJUSTES (WIP)"
	settings_btn.custom_minimum_size = Vector2(300, 60)
	settings_btn.disabled = true  # settings_menu.tscn aun no existe
	vbox.add_child(settings_btn)
	
	var quit_btn = Button.new()
	quit_btn.text = "SALIR"
	quit_btn.custom_minimum_size = Vector2(300, 60)
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)
	
	var meta_info = Label.new()
	meta_info.text = "Moneda: 0 | Perks: 0 | Lore: 0%"
	meta_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_info.add_theme_font_size_override("font_size", 16)
	meta_info.add_theme_color_override("font_color", Color(0.6, 0.5, 0.6, 1))
	vbox.add_child(meta_info)
	
	for b in [start_btn, continue_btn, lore_btn, settings_btn, quit_btn]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.grab_focus.call_deferred()
	
	# Store references
	self.start_btn = start_btn
	self.continue_btn = continue_btn
	self.lore_btn = lore_btn
	self.settings_btn = settings_btn
	self.quit_btn = quit_btn
	self.meta_info = meta_info

var start_btn: Button
var continue_btn: Button
var lore_btn: Button
var settings_btn: Button
var quit_btn: Button
var meta_info: Label

func _update_meta_info() -> void:
	var rm = _game_controller.get_run_manager()
	var lore_pct = _game_controller.get_lore_database().get_completion_percentage()
	meta_info.text = "Huesos: %d  |  Mejor piso: %d  |  Códice: %.0f%%" % [rm.meta_currency, rm.best_floor, lore_pct]

# ---------------------------------------------------------------- ventanas
## Ventana encima del menu con titulo, contenido y "Volver".
func _window(title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120; panel.offset_right = -120
	panel.offset_top = 60; panel.offset_bottom = -60
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.97)
	sb.border_color = Color("b08d4a")
	sb.set_border_width_all(2)
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 28)
	t.add_theme_color_override("font_color", Color("ff4f9a"))
	box.add_child(t)
	var back := Button.new()
	back.text = "VOLVER"
	back.pressed.connect(func():
		panel.queue_free()
		_update_meta_info())
	box.add_child(back)
	back.grab_focus.call_deferred()
	return box

## Mejoras permanentes: se pagan con los huesos que deja cada partida.
func _open_upgrades() -> void:
	var box := _window("MEJORAS PERMANENTES")
	var info := Label.new()
	box.add_child(info)
	var rows := VBoxContainer.new()
	box.add_child(rows)
	_fill_upgrades(info, rows)

func _fill_upgrades(info: Label, rows: VBoxContainer) -> void:
	var rm = _game_controller.get_run_manager()
	info.text = "Huesos: %d   (se ganan al terminar cada partida: 10 por piso, 1 cada 3 enemigos)" % rm.meta_currency
	for c in rows.get_children():
		c.queue_free()
	for id in RunManager.META_UPGRADES:
		var u: Dictionary = RunManager.META_UPGRADES[id]
		var lvl: int = rm.meta_level(id)
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if lvl >= u.max:
			b.text = "%s — %s   [%d/%d] MÁXIMO" % [u.name, u.desc, lvl, u.max]
			b.disabled = true
		else:
			b.text = "%s — %s   [%d/%d]   %d huesos" % [u.name, u.desc, lvl, u.max, rm.meta_cost(id)]
			b.disabled = rm.meta_currency < rm.meta_cost(id)
		b.pressed.connect(func():
			rm.buy_meta(id)
			_fill_upgrades(info, rows))
		rows.add_child(b)

## Codice: lo que has descubierto (inscripciones, objetos, enemigos...). Lo demas, "???".
func _open_codex() -> void:
	var lore = _game_controller.get_lore_database()
	var box := _window("CÓDICE  (%.0f%% descubierto)" % lore.get_completion_percentage())
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(split)
	var list := ItemList.new()
	list.custom_minimum_size = Vector2(320, 0)
	split.add_child(list)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.text = "Elige una entrada. Las que faltan se descubren jugando: inscripciones, objetos, enemigos y jefes."
	split.add_child(text)
	var entries: Array = lore.get_all_entries()
	entries.sort_custom(func(a, b): return a.unlocked and not b.unlocked if a.unlocked != b.unlocked else a.title < b.title)
	for e in entries:
		list.add_item(e.title if e.unlocked else "???")
		list.set_item_disabled(list.item_count - 1, not e.unlocked)
	list.item_selected.connect(func(i):
		var e = entries[i]
		text.text = "[b]%s[/b]\n\n%s\n\n[i]%s[/i]" % [e.title, e.text, e.flavor_text])

func _on_start() -> void:
	# historia + eleccion de personaje; la run empieza alli
	get_tree().change_scene_to_file("res://src/scenes/intro.tscn")

func _on_continue() -> void:
	pass

func _on_quit() -> void:
	get_tree().quit()