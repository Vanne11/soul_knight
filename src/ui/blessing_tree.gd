class_name BlessingTree
extends PanelContainer

## Panel del menu de pausa: arbol de bendiciones (rama Penelandia, rama Vulvania y Equilibrio
## Hormonal al centro unido a ambas) con lo que tienes y a que nivel, lo que falta (apagado),
## el progreso para desbloquear Equilibrio, y un resumen de tus estadisticas (PlayerStats).
## Solo lee RunManager y PlayerStats. Se usa dentro de PauseMenu (como SettingsPanel).

signal closed

var _back: Button
var _hub_icon: Control
var _branch_heads: Dictionary = {}  # reino -> Control del que sale la linea
var _links: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var title := HudStyle.pixel_label(tr("BTREE_TITLE"), 32, HudStyle.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	v.add_child(row)
	row.add_child(_branch("pene"))
	row.add_child(_hub())
	row.add_child(_branch("vulva"))

	v.add_child(HSeparator.new())
	v.add_child(_stats_box())

	_back = Button.new()
	_back.text = tr("BTREE_BACK")
	_back.custom_minimum_size = Vector2(0, 46)
	_back.pressed.connect(func(): closed.emit())
	HudStyle.juice_button(_back)
	v.add_child(_back)

	# las lineas van por debajo de las cajas, pero encima del fondo del panel
	_links = Control.new()
	_links.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_links.set_anchors_preset(Control.PRESET_FULL_RECT)
	_links.draw.connect(_draw_links)
	add_child(_links)
	move_child(_links, 0)
	resized.connect(_links.queue_redraw)
	_redraw_later.call_deferred()


func _redraw_later() -> void:
	await get_tree().process_frame
	if is_instance_valid(_links):
		_links.queue_redraw()


func focus_first() -> void:
	_back.grab_focus()


func _color(kingdom: String) -> Color:
	return BlessingPicker.KINGDOM_COLORS[kingdom]


## Una rama: cabecera con el reino y sus 6 bendiciones (encendidas si las tienes).
func _branch(kingdom: String) -> Control:
	var col := _color(kingdom)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.custom_minimum_size.x = 330
	var head := HudStyle.pixel_label(tr(BlessingPicker.KINGDOM_KEYS[kingdom]), 24, col, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	_branch_heads[kingdom] = head
	var lv := HudStyle.pixel_label(str(BlessingPicker.rm().kingdom_levels(kingdom)), 16, col)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lv)
	for id in RunManager.BLESSINGS:
		if RunManager.BLESSINGS[id].kingdom == kingdom:
			v.add_child(_entry(id))
	return v


func _entry(id: String) -> Control:
	var lvl: int = BlessingPicker.rm().blessing(id)
	var on := lvl > 0
	var col := BlessingPicker.kingdom_color(id)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_STOP
	h.tooltip_text = "%s\n%s" % [Loc.blessing(id, "name"), Loc.blessing(id, "desc")]
	var ic := TextureRect.new()
	ic.texture = BlessingPicker.icon_tex(id)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(36, 36)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.modulate = Color.WHITE if on else Color(0.3, 0.3, 0.36, 0.8)
	h.add_child(ic)
	var col_v := VBoxContainer.new()
	col_v.add_theme_constant_override("separation", 0)
	col_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := HudStyle.pixel_label(Loc.blessing(id, "name"), 16, col if on else Color(0.45, 0.43, 0.5), on)
	col_v.add_child(nm)
	var sub := HudStyle.pixel_label(
		(tr("BPICK_LEVEL") % lvl) if on else tr("BTREE_LOCKED"),
		16, HudStyle.GOLD if on else Color(0.35, 0.33, 0.4))
	col_v.add_child(sub)
	h.add_child(col_v)
	return h


## Equilibrio Hormonal al centro, con el progreso (n/2 de cada reino).
func _hub() -> Control:
	var id := "equilibrio"
	var have: int = BlessingPicker.rm().blessing(id)
	var pene: int = BlessingPicker.rm().kingdom_levels("pene")
	var vulva: int = BlessingPicker.rm().kingdom_levels("vulva")
	var ready := pene >= 2 and vulva >= 2
	var col := BlessingPicker.kingdom_color(id)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size.x = 250
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	v.tooltip_text = "%s\n%s" % [Loc.blessing(id, "name"), Loc.blessing(id, "desc")]
	var ic := TextureRect.new()
	ic.texture = BlessingPicker.icon_tex(id)
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(108, 108)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.modulate = Color.WHITE if (have > 0 or ready) else Color(0.3, 0.3, 0.36, 0.85)
	v.add_child(ic)
	_hub_icon = ic
	var nm := HudStyle.pixel_label(Loc.blessing(id, "name"), 16, col if (have > 0 or ready) else Color(0.5, 0.48, 0.55), true)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var state := tr("BTREE_BALANCE_TAKEN") if have > 0 else (tr("BTREE_BALANCE_READY") if ready else tr("BTREE_BALANCE_PROGRESS") % [mini(pene, 2), mini(vulva, 2)])
	var st := HudStyle.pixel_label(state, 16, HudStyle.GOLD if (have > 0 or ready) else Color(0.6, 0.57, 0.65))
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(st)
	return v


func _draw_links() -> void:
	if _hub_icon == null or not is_instance_valid(_hub_icon):
		return
	var origin := _links.get_global_rect().position
	var c := _hub_icon.get_global_rect().get_center() - origin
	var have: int = BlessingPicker.rm().blessing("equilibrio")
	for k in ["pene", "vulva"]:
		var head: Control = _branch_heads[k]
		var r := head.get_global_rect()
		var side_x := (r.end.x if k == "pene" else r.position.x) - origin.x
		var p := Vector2(side_x, r.get_center().y - origin.y)
		var lit := BlessingPicker.rm().kingdom_levels(k) >= 2
		var col := _color(k) if lit else Color(0.3, 0.28, 0.36)
		_links.draw_line(p, Vector2(c.x, p.y), col, 4.0)
		_links.draw_line(Vector2(c.x, p.y), c + Vector2(0, -56), col, 4.0)
		if have > 0:
			_links.draw_circle(c + Vector2(0, -56), 5.0, _color("mixto"))


## Resumen de tus numeros de ahora mismo (PlayerStats).
func _stats_box() -> Control:
	var ps: PlayerStats = get_node("/root/PlayerStats")
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var t := HudStyle.pixel_label(tr("BSTAT_TITLE"), 16, HudStyle.GOLD, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 36)
	g.add_theme_constant_override("v_separation", 4)
	g.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var items := [
		["BSTAT_DAMAGE", "x%.2f" % ps.damage_modifier],
		["BSTAT_FIRE_RATE", "x%.2f" % ps.fire_rate_modifier],
		["BSTAT_CRIT", "+%d%%" % roundi(ps.crit_chance_modifier * 100.0)],
		["BSTAT_SPEED", "x%.2f" % ps.speed_modifier],
		["BSTAT_HEALTH", "%d" % roundi(ps.max_health)],
		["BSTAT_SHIELD", "%d" % roundi(ps.max_shields)],
		["BSTAT_STAMINA", "%d" % roundi(ps.max_stamina)],
	]
	for it in items:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cell.add_child(HudStyle.pixel_label(tr(it[0]), 16, Color(0.8, 0.72, 0.78)))
		cell.add_child(HudStyle.pixel_label(it[1], 16, HudStyle.CREAM, true))
		g.add_child(cell)
	v.add_child(g)
	return v
