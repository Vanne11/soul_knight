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

	start_btn = _menu_button(vbox, tr("MENU_NEW_GAME"), _on_start)
	continue_btn = _menu_button(vbox, tr("MENU_UPGRADES"), _open_upgrades)
	lore_btn = _menu_button(vbox, tr("MENU_CODEX"), _open_codex)
	settings_btn = _menu_button(vbox, tr("SETTINGS_TITLE"), _open_settings)
	quit_btn = _menu_button(vbox, tr("MENU_QUIT"), _on_quit)
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
	sv.add_child(HudStyle.pixel_label(tr("MENU_WORLD"), 16, HudStyle.GOLD, true))
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
	caption.text = tr("MENU_WORLD_GRAY") if n == 0 \
		else tr("MENU_WORLD_FREED") % [n, RunManager.FLOORS.size()]
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
	back.pressed.connect(func():
		dim.queue_free()
		_update_meta_info()
		start_btn.grab_focus())
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
		dim.queue_free()
		if Settings.locale != locale_at_open:
			get_tree().reload_current_scene()
		else:
			settings_btn.grab_focus())
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
			b.text = tr("MENU_UPGRADE_MAX") % [u.name, u.desc, lvl, u.max]
			b.disabled = true
		else:
			b.text = tr("MENU_UPGRADE_BUY") % [u.name, u.desc, lvl, u.max, rm.meta_cost(id)]
			b.disabled = rm.meta_currency < rm.meta_cost(id)
		b.pressed.connect(func():
			rm.buy_meta(id)
			_fill_upgrades(info, rows))
		rows.add_child(b)

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
	entries.sort_custom(func(a, b): return a.unlocked and not b.unlocked if a.unlocked != b.unlocked else a.title < b.title)
	for e in entries:
		var img: Texture2D = _codex_image(e)
		list.add_item(e.title if e.unlocked else "???", _thumb(img, not e.unlocked) if img else null)
		list.set_item_disabled(list.item_count - 1, not e.unlocked)
	list.item_selected.connect(func(i):
		var e = entries[i]
		var img: Texture2D = _codex_image(e)
		frame.visible = img != null
		if img:
			# escala entera (pixel art nitido): lo mas grande que quepa en ~560x250
			var k := maxi(1, mini(int(560.0 / img.get_width()), int(250.0 / img.get_height())))
			pic.texture = img
			pic.custom_minimum_size = Vector2(img.get_width(), img.get_height()) * k
		text.text = "[b]%s[/b]\n\n%s\n\n[i]%s[/i]" % [e.title, e.text, e.flavor_text])


## Imagen de una entrada del codice, deducida de lo que la desbloquea.
func _codex_image(e) -> Texture2D:
	if e.sprite:
		return e.sprite
	var uc = e.unlock_condition if e.unlock_condition is Dictionary else {}
	var target: String = str(uc.get("target_id", ""))
	var path := ""
	match e.category:
		LoreEntry.Category.ITEM:
			path = "res://assets/sprites/items/%s.png" % target
		LoreEntry.Category.ENEMY:
			var v: String = _enemy_variants().get(target, "")
			if v != "":
				path = "res://assets/sprites/enemies/%s_idle_00.png" % v
		LoreEntry.Category.CHARACTER:
			path = "res://assets/sprites/player/%s/portrait.png" % target.trim_prefix("play_")
	if path == "" or not ResourceLoader.exists(path):
		path = CODEX_ART.get(e.id, "")
	return load(path) if path != "" and ResourceLoader.exists(path) else null

## Entradas sin objeto/bicho propio: su ilustracion de la intro o de pantalla.
const CODEX_ART := {
	"world_intro": "res://assets/sprites/intro/slide_00.png",
	"guerra_fria": "res://assets/sprites/intro/slide_01.png",
	"alergia_hormonal": "res://assets/sprites/intro/slide_02.png",
	"floor_anatomy": "res://assets/sprites/intro/slide_00.png",
	"loc_selva": "res://assets/sprites/intro/slide_06.png",
	"loc_penelandia": "res://assets/sprites/intro/slide_00.png",
	"loc_vulvania": "res://assets/sprites/intro/slide_00.png",
	"loc_perineo": "res://assets/sprites/intro/slide_01.png",
	"loc_palacio": "res://assets/sprites/intro/slide_04.png",
	"puerta_hormonal": "res://assets/sprites/intro/slide_07.png",
	"player_identity": "res://assets/sprites/intro/slide_08.png",
	"death_meaning": "res://assets/sprites/ui/screens/gameover.png",
	"final_censura": "res://assets/sprites/ui/screens/victory.png",
	"drunk_secret": "res://assets/sprites/items/whiskey.png",
	"intoxication_mechanic": "res://assets/sprites/items/absinthe.png",
	"boss_phases": "res://assets/sprites/intro/slide_03.png",
}

## Nombre visible del enemigo -> variante de sprite (rosters y jefes de cada piso).
func _enemy_variants() -> Dictionary:
	var m := {}
	for f in RunManager.FLOORS:
		for pair in [["roster", "names"], ["alt_roster", "alt_names"]]:
			if f.has(pair[0]):
				for i in f[pair[0]].size():
					m[f[pair[1]][i]] = f[pair[0]][i]
		for x in f.get("extra", []):
			m[x.name] = x.variant
		m[f.boss_name] = f.boss
	return m

## Miniatura 32x32 sin suavizar; en silueta negra si aun no se descubrio.
func _thumb(tex: Texture2D, silhouette: bool) -> Texture2D:
	var img := tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	if used.size.x > 0:
		img = img.get_region(used)
	var k := minf(32.0 / img.get_width(), 32.0 / img.get_height())
	var w := maxi(1, int(img.get_width() * k))
	var h := maxi(1, int(img.get_height() * k))
	img.resize(w, h, Image.INTERPOLATE_NEAREST)
	var out := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((32 - w) / 2, (32 - h) / 2))
	if silhouette:
		for y in 32:
			for x in 32:
				var c := out.get_pixel(x, y)
				if c.a > 0.0:
					out.set_pixel(x, y, Color(0.05, 0.03, 0.08, c.a))
	return ImageTexture.create_from_image(out)

func _on_start() -> void:
	# historia + eleccion de personaje; la run empieza alli
	get_tree().change_scene_to_file("res://src/scenes/intro.tscn")

func _on_continue() -> void:
	pass

func _on_quit() -> void:
	get_tree().quit()