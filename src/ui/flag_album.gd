class_name FlagAlbum
extends RefCounted

## Seccion "Mapa de las banderas" del codice (boton arriba del codice en main_menu._open_codex): las 10
## banderas del Orgullo en una grilla, encontradas a color con el reino donde aparecieron y las que faltan
## en silueta. Enfoca o pasa el cursor por una para leer su entrada. Logica en src/arcoiria/banderas.gd.

const CELL := 150


static func build(box: VBoxContainer) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var lore := tree.root.get_node("LoreDatabase")
	var m := tree.root.get_node("Medallas")
	var n := Banderas.found().size()
	var hint := HudStyle.pixel_label(_t("FLAG_MAP_HINT"), 14, HudStyle.CREAM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var bar := ProgressBar.new()
	bar.max_value = Banderas.IDS.size()
	bar.value = n
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ff4f9a")
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.07, 0.14)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	box.add_child(bar)
	var detail := RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.text = "[i]%s[/i]" % (_t("FLAG_MAP_DONE_BODY") if n >= Banderas.IDS.size() else _t("FLAG_MAP_PICK"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	for id in Banderas.IDS:
		var e = lore.get_entry(id)
		var got := Banderas.is_found(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(CELL, 110)
		b.focus_mode = Control.FOCUS_ALL
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var img: Texture2D = CodexArt.image(e) if e else null
		if img:
			b.icon = img if got else CodexArt.thumb(img, 64, true)
		b.text = Loc.lore_title(e) if got else "???"
		var where: String = m.bandera_donde(id)
		var show := func():
			if not got:
				detail.text = "[b]???[/b]\n%s" % _t("FLAG_MAP_MISSING")
				return
			var place := (_t("FLAG_MAP_WHERE") % Loc.region_name_id(where)) if where != "" else ""
			detail.text = "[b]%s[/b]  [color=#ffd640]%s[/color]\n%s\n[i]%s[/i]" % [Loc.lore_title(e), place, Loc.lore_text(e), Loc.lore_flavor(e)]
		b.mouse_entered.connect(show)
		b.focus_entered.connect(show)
		grid.add_child(b)
	box.add_child(detail)


static func _t(key: String) -> String:
	return TranslationServer.translate(key)
