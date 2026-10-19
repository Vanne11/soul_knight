extends Control
class_name Minimap

## Minimapa del piso (esquina superior derecha, bajo la franja del HUD). Salas
## pisadas en color, vecinas sin pisar como "?", la actual parpadea. M lo agranda.
## Si el jugador pasa por debajo se vuelve casi transparente para no tapar.

const SMALL := Vector2(210, 140)
const BIG := Vector2(720, 420)  # deja libre el cuadro del narrador
const ROOM_NAMES := {
	Room.RoomType.COMBAT: "MAP_ROOM_COMBAT", Room.RoomType.SHOP: "MAP_ROOM_SHOP", Room.RoomType.LORE: "MAP_ROOM_LORE",
	Room.RoomType.TREASURE: "MAP_ROOM_TREASURE", Room.RoomType.REST: "MAP_ROOM_REST",
	Room.RoomType.TRAP: "MAP_ROOM_TRAP", Room.RoomType.PUZZLE: "MAP_ROOM_PUZZLE", Room.RoomType.SECRET: "MAP_ROOM_SECRET",
	Room.RoomType.BOSS: "MAP_ROOM_BOSS", Room.RoomType.INTOXICATION: "MAP_ROOM_INTOXICATION", Room.RoomType.MINIBOSS: "MAP_ROOM_MINIBOSS",
	Room.RoomType.START: "MAP_ROOM_START",
}
## Letra dentro de la sala en el mapa (las que no salen aqui no llevan marca).
const ICONS := {Room.RoomType.SHOP: "$", Room.RoomType.BOSS: "J", Room.RoomType.START: "I",
	Room.RoomType.MINIBOSS: "M", Room.RoomType.SECRET: "?", Room.RoomType.TREASURE: "T",
	Room.RoomType.REST: "+", Room.RoomType.LORE: "i", Room.RoomType.PUZZLE: "P"}

var _big := false
var _font: Font
var _label: Label
var _map_hint: HBoxContainer  # "[M] mapa" con el glifo de la tecla

var _frame := HudStyle.panel_box(0)

## Pestanas del mapa grande: 0 = Piso (este minimapa), 1 = Mundo (world_map.gd, solo lectura).
const TAB_H := 26.0
const TAB_W := 92.0
var _tab := 0
var _world := WorldMap.new()
var _tab_hint: HBoxContainer  # glifo de Tab + "pestana"

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_label = HudStyle.pixel_label("", 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)
	_build_map_hint()
	_tab_hint = InputGlyphs.labeled("map_tab", "MAPA_TAB_HINT", HudStyle.CREAM, 16)
	_tab_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tab_hint)
	_resize()

func _resize() -> void:
	var s := BIG if _big else SMALL
	if _big:
		set_anchors_preset(Control.PRESET_CENTER)
		offset_left = -s.x / 2; offset_right = s.x / 2
		offset_top = -s.y / 2 - 40; offset_bottom = s.y / 2 - 40
	else:
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -s.x - 10; offset_right = -10
		offset_top = HUD.BAND + 6; offset_bottom = HUD.BAND + 6 + s.y
	# mas ancho que el mapa y alineado a la derecha: el texto crece hacia la izquierda
	_label.position = Vector2(-200, s.y + 4)
	_label.size = Vector2(s.x + 200, 20)
	_place_map_hint()
	if _tab_hint:
		_tab_hint.visible = _big
		_tab_hint.size = Vector2(_tab_hint.get_combined_minimum_size().x, 24)
		_tab_hint.position = Vector2(s.x - _tab_hint.size.x - 10, 4)

func _tab_rect(i: int) -> Rect2:
	return Rect2(Vector2(8 + i * (TAB_W + 4), 5), Vector2(TAB_W, TAB_H - 5))

func _set_tab(i: int) -> void:
	_tab = i
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		_big = not _big
		_resize()
	# mapa grande: cambiar de pestana con Tab o clic (L1/R1 no: son usar objeto y guardia)
	elif _big and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		_set_tab(1 - _tab)
		get_viewport().set_input_as_handled()
	elif _big and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = event.position - get_global_rect().position
		for i in 2:
			if _tab_rect(i).has_point(local):
				_set_tab(i)
				get_viewport().set_input_as_handled()
				return
		if TouchControls.is_active() and get_global_rect().has_point(event.position):
			_big = not _big
			_resize()
	# con controles tactiles: tocar el mapa lo agranda / achica
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and TouchControls.is_active() and get_global_rect().has_point(event.position):
		_big = not _big
		_resize()

func _process(delta: float) -> void:
	queue_redraw()
	var target := 1.0
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and not _big and get_global_rect().grow(40).has_point(p.get_global_transform_with_canvas().origin):
		target = 0.25
	modulate.a = move_toward(modulate.a, target, delta * 4.0)

func _draw_tabs() -> void:
	var names := ["MAPA_TAB_PISO", "MAPA_TAB_MUNDO"]
	for i in 2:
		var r := _tab_rect(i)
		var on := i == _tab
		draw_rect(r, Color(0.07, 0.06, 0.09, 0.9) if on else Color(0.2, 0.19, 0.23, 0.7))
		draw_rect(r, HudStyle.GOLD if on else Color(0.5, 0.47, 0.42), false, 2.0)
		var col := HudStyle.CREAM if on else Color(0.6, 0.58, 0.52)
		var txt := tr(names[i])
		draw_string(HudStyle.FONT, r.position + Vector2(2, 17), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, HudStyle.SHADOW)
		draw_string(HudStyle.FONT, r.position + Vector2(0, 15), txt, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, col)

func _draw() -> void:
	var tab_top := TAB_H if _big else 0.0
	if _big and _tab == 1:
		draw_style_box(_frame, Rect2(Vector2.ZERO, size))
		_draw_tabs()
		var rm := get_node_or_null("/root/RunManager")
		if rm:
			_world.draw(self, Rect2(Vector2(8, 6 + tab_top), size - Vector2(16, 12 + tab_top)), rm)
			var cur := WorldMap.current_region(rm)
			var nm := cur
			for r in WorldMap.data().get("regions", []):
				if r.id == cur:
					nm = WorldMap.region_label(r)
			_label.text = tr("MAPA_MUNDO_AQUI") % nm
		return
	var main := get_tree().get_first_node_in_group("main")
	if main == null or main.dungeon_generator == null or main.dungeon_generator.rooms.is_empty():
		return
	var gen: DungeonGenerator = main.dungeon_generator
	var visited: Dictionary = main.visited_rooms
	var current: Room = main.current_room

	# Lo que se conoce: lo pisado y sus vecinos directos.
	var known := {}
	for pos in visited:
		known[pos] = true
		for n in gen.room_graph.get(pos, []):
			known[n] = true

	# Kit de autoexamen (src/items/item_actions.gd): revela todo el piso, secretas incluidas.
	var revealed: bool = main.has_meta("map_revealed_floor") and main.get_meta("map_revealed_floor") == get_node("/root/RunManager").current_floor
	if revealed:
		for pos in gen.rooms:
			known[pos] = true

	# Encaja todo el piso (no solo lo conocido) para que el mapa no "salte".
	var bounds := Rect2i()
	var first := true
	for pos in gen.rooms:
		var r := Rect2i(pos, gen.room_sizes.get(pos, Vector2i(8, 6)))
		bounds = r if first else bounds.merge(r)
		first = false
	var box := size - Vector2(12, 12 + tab_top)
	var k: float = minf(box.x / bounds.size.x, box.y / bounds.size.y)
	var origin := Vector2(6, 6 + tab_top) + (box - Vector2(bounds.size) * k) / 2 - Vector2(bounds.position) * k

	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	if _big:
		_draw_tabs()
	if FloorEvents.hide_map():  # evento "Censura total": sin mapa
		_label.text = ""
		draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), Color(0.05, 0.05, 0.07, 0.9))
		draw_string(_font, Vector2(0, size.y / 2 + 6), tr("MAP_CENSORED"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color("d8d8e6"))
		return

	var rect_of := func(pos: Vector2i) -> Rect2:
		return Rect2(origin + Vector2(pos) * k, Vector2(gen.room_sizes.get(pos, Vector2i(8, 6))) * k)

	# Pasillos entre salas conocidas.
	for pos in known:
		for n in gen.room_graph.get(pos, []):
			if known.has(n) and (visited.has(pos) or visited.has(n)):
				draw_line(rect_of.call(pos).get_center(), rect_of.call(n).get_center(), Color(0.7, 0.65, 0.55, 0.6), 2.0)

	var blink := int(Time.get_ticks_msec() / 400) % 2 == 0
	for pos in known:
		var room: Room = gen.rooms[pos]
		var r: Rect2 = rect_of.call(pos).grow(-1)
		var fill: Color
		if room == current:
			fill = Color("f2ead6") if blink else Color("ffc93c")
		elif visited.has(pos):
			fill = Color(0.45, 0.75, 0.45) if room.cleared or room.enemies_spawned.is_empty() else Color(0.8, 0.4, 0.4)
		else:
			fill = Color(0.42, 0.42, 0.48)
		draw_rect(r, fill)
		draw_rect(r, Color("0d0b0f"), false, 1.0)
		# Tienda y jefe se ven en cuanto conoces la sala; el resto, al pisarla.
		var icon: String = ICONS.get(room.room_type, "")
		if not visited.has(pos) and not revealed and room.room_type not in [Room.RoomType.SHOP, Room.RoomType.BOSS]:
			icon = "?"
		if MonteVenus.is_monte(room) and (visited.has(pos) or revealed):
			icon = MonteVenus.ICON  # la loma: sala tranquila con marca propia
		if room.has_meta("elite_room"):
			icon = "E"  # la sala elite se conoce desde la puerta (su cartel lo dice)
		if room.room_type == Room.RoomType.BOSS:
			icon = tr("MAP_ICON_BOSS")
		elif room.room_type == Room.RoomType.START:
			icon = tr("MAP_ICON_START")
		if icon != "":
			var fs := int(clampf(r.size.y * 0.6, 9, 28))
			var col := Color("ff5050") if room.room_type == Room.RoomType.BOSS else (Color("ffd700") if room.room_type == Room.RoomType.SHOP else Color("0d0b0f"))
			if room.has_meta("elite_room"):
				col = Color("ff3a1a")
			if room == current:
				col = Color("0d0b0f")  # sobre el amarillo de "estas aqui" no se veia
			draw_string(_font, Vector2(r.position.x, r.get_center().y + fs * 0.35), icon, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)

	if current:
		var rname: String = tr("MAP_ROOM_ELITE") if current.has_meta("elite_room") else tr(ROOM_NAMES.get(current.room_type, "?"))
		var rm := get_node_or_null("/root/RunManager")
		if rm:
			if current.room_type == Room.RoomType.BOSS and not RunManager.floor_has_boss(rm.current_floor):
				rname = tr("MAP_ROOM_GUARD")  # 1a etapa: la sala final es un guardian, no un jefe
			rname = "%s · %s" % [Loc.floor_name(rm.floor_data(), true), rname]  # nombre de la etapa
		_label.text = rname
		_place_map_hint()

## Glifo de "map" + "mapa" a la derecha del nombre de la sala (en mando no hay tecla: se esconde).
func _build_map_hint() -> void:
	_map_hint = InputGlyphs.labeled("map", "GLYPH_MAP", HudStyle.CREAM, 16)
	_map_hint.add_theme_constant_override("separation", 4)
	_map_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_hint)

func _place_map_hint() -> void:
	if _map_hint == null:
		return
	# el texto de la sala se recorta a la izquierda del indicador de la tecla
	var w := _map_hint.get_combined_minimum_size().x if _map_hint.visible else 0.0
	var s := BIG if _big else SMALL
	_map_hint.size = Vector2(w, 28)
	_map_hint.position = Vector2(s.x - w, s.y + 2)
	_label.size.x = s.x + 200 - w - 8
