extends CanvasLayer

@onready var _game_controller = get_node("/root/GameController")

func _ready() -> void:
	_create_ui()
	_update_meta_info()

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

	start_btn = _menu_button(vbox, "NUEVA PARTIDA", _on_start)
	continue_btn = _menu_button(vbox, "MEJORAS", _open_upgrades)
	lore_btn = _menu_button(vbox, "CÓDICE", _open_codex)
	settings_btn = _menu_button(vbox, "AJUSTES (WIP)", func(): pass)
	settings_btn.disabled = true  # settings_menu.tscn aun no existe
	quit_btn = _menu_button(vbox, "SALIR", _on_quit)
	start_btn.grab_focus.call_deferred()

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
	sv.add_child(HudStyle.pixel_label("EL MUNDO", 16, HudStyle.GOLD, true))
	sv.add_child(_world_strip())
	var meta_box := VBoxContainer.new()
	meta_box.add_theme_constant_override("separation", 4)
	sv.add_child(meta_box)
	_meta_box = meta_box


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
		var t := HudStyle.pixel_label("ROGUE REPRODUCTIVE", 64, l[1], true)
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
	ribbon.add_child(HudStyle.pixel_label("LA GRAN CENSURA · ÓRGANOS, HORMONAS Y MALAS DECISIONES", 16, HudStyle.CREAM))
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
	for i in RunManager.FLOORS.size():
		var f: Dictionary = RunManager.FLOORS[i]
		var free: bool = rm.is_liberated(i + 1)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.color = f.tint if free else Color(0.4, 0.4, 0.44)
		row.add_child(dot)
		row.add_child(HudStyle.pixel_label("%d %s" % [i + 1, f.name.replace("EL PALACIO DE LA ", "PALACIO ")], 16,
			f.tint.lightened(0.2) if free else Color(0.55, 0.55, 0.6)))
		col.add_child(row)
	var n: int = rm.liberated.size()
	var caption := Label.new()
	caption.text = "El mundo sigue gris. Libera una región venciendo a su jefe: queda a color para siempre." if n == 0 \
		else "%d de %d regiones liberadas. Cada una te regala una bendición al llegar." % [n, RunManager.FLOORS.size()]
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size.x = 250
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color(0.8, 0.72, 0.78))
	col.add_child(caption)
	return col

var start_btn: Button
var continue_btn: Button
var lore_btn: Button
var settings_btn: Button
var quit_btn: Button
var _meta_box: VBoxContainer
var _root: Control
var _logo: Control

func _update_meta_info() -> void:
	var rm = _game_controller.get_run_manager()
	var lore_pct = _game_controller.get_lore_database().get_completion_percentage()
	for c in _meta_box.get_children():
		c.queue_free()
	for pair in [["bone", "%d HUESOS" % rm.meta_currency], ["stairs", "MEJOR PISO %d" % rm.best_floor], ["skull", "CÓDICE %.0f%%" % lore_pct]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(HudStyle.icon(pair[0]))
		row.add_child(HudStyle.pixel_label(pair[1], 16))
		_meta_box.add_child(row)

# ---------------------------------------------------------------- ventanas
## Ventana encima del menu con titulo, contenido y "Volver".
func _window(title_text: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 120; panel.offset_right = -120
	panel.offset_top = 60; panel.offset_bottom = -60
	panel.add_theme_stylebox_override("panel", HudStyle.panel_box(22))
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(HudStyle.pixel_label(title_text, 24, Color("ff4f9a"), true))
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