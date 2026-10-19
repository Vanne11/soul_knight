class_name MedalScreen
extends RefCounted

## Contenido de la pantalla "Medallas" del menu principal (junto al Codice): contador por nivel,
## progreso hacia Desnudo Integral y una grilla con todas las medallas (ganadas a color, bloqueadas
## en silueta, las ocultas como "???"). Pasa el cursor (o enfoca con el mando) para ver el detalle.
## Lo llena main_menu._open_medals() dentro de la ventana comun.

const CELL := 72
const COLUMNS := 12


static func build(box: VBoxContainer) -> void:
	var m = Engine.get_main_loop().root.get_node("Medallas")
	# contadores por nivel
	var counts := HBoxContainer.new()
	counts.add_theme_constant_override("separation", 28)
	box.add_child(counts)
	for lv in Medallas.LEVELS:
		var c: Vector2i = m.level_count(lv)
		counts.add_child(HudStyle.pixel_label(tr_static("MEDAL_COUNT_LINE") % [m.level_name(lv), c.x, c.y], 16, m.level_color(lv), true))
	# progreso hacia Desnudo Integral
	var p: Vector2i = m.platinum_progress()
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 12)
	box.add_child(prow)
	prow.add_child(HudStyle.pixel_label(tr_static("MEDAL_PROGRESS") % [p.x, p.y], 16, m.level_color("platino"), true))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxi(p.y, 1)
	bar.value = p.x
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(260, 18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = m.level_color("platino")
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.1, 0.07, 0.14)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(bar)
	# grilla
	var detail := RichTextLabel.new()
	detail.bbcode_enabled = true
	detail.custom_minimum_size = Vector2(0, 78)
	detail.text = "[i]%s[/i]" % tr_static("MEDAL_HINT")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	var order := {"sonrojo": 0, "destape": 1, "sin_pudor": 2, "platino": 3}
	var list: Array = m.defs().duplicate()
	list.sort_custom(func(a, b): return int(order[a.nivel]) < int(order[b.nivel]))  # estable: respeta el orden del catalogo
	for d in list:
		var won: bool = m.is_won(d.id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(CELL, CELL)
		b.flat = true
		b.icon = m.icono(d.id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.focus_mode = Control.FOCUS_ALL
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if not won:
			b.modulate = Color(0.16, 0.14, 0.2, 1.0) if bool(d.oculta) else Color(0.4, 0.37, 0.48, 1.0)
		var show := func():
			detail.text = _detail_text(m, d, won)
		b.mouse_entered.connect(show)
		b.focus_entered.connect(show)
		if bool(d.oculta) and not won:
			var q := HudStyle.pixel_label("?", 24, Color("ffd75a"), true)
			q.set_anchors_preset(Control.PRESET_FULL_RECT)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			q.modulate = Color(6, 6, 6, 1)  # contrarresta el oscurecido del boton
			b.add_child(q)
		grid.add_child(b)
	box.add_child(detail)


static func _detail_text(m, d: Dictionary, won: bool) -> String:
	var lv: String = m.level_name(d.nivel)
	var col: String = m.level_color(d.nivel).to_html(false)
	if bool(d.oculta) and not won:
		return "[b]%s[/b]  [color=#%s]%s[/color]\n%s" % [tr_static("MEDAL_SECRET_NAME"), col, lv, tr_static("MEDAL_SECRET_DESC")]
	var state: String = ("[color=#9be88a]%s[/color]" % m.won_date(d.id)) if won else "[color=#8a8298]%s[/color]" % tr_static("MEDAL_LOCKED")
	return "[b]%s[/b]  [color=#%s]%s[/color]  %s\n%s" % [m.medal_name(d.id), col, lv, state, m.medal_desc(d.id)]


## tr() no esta disponible en funciones estaticas de un RefCounted: TranslationServer hace lo mismo.
static func tr_static(key: String) -> String:
	return TranslationServer.translate(key)
