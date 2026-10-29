extends Control
class_name Minimap

## Minimapa del piso (esquina superior derecha, bajo la franja del HUD). Salas
## pisadas en color, vecinas sin pisar como "?", la actual parpadea. M (o Select del mando, o tocarlo)
## abre el mapa a pantalla completa estilo Metroid (map_metroid.gd, pausa el juego).
## Si el jugador pasa por debajo se vuelve casi transparente para no tapar.

const SMALL := Vector2(210, 140)
const ROOM_NAMES := {
	Room.RoomType.COMBAT: "MAP_ROOM_COMBAT", Room.RoomType.SHOP: "MAP_ROOM_SHOP", Room.RoomType.LORE: "MAP_ROOM_LORE",
	Room.RoomType.TREASURE: "MAP_ROOM_TREASURE", Room.RoomType.REST: "MAP_ROOM_REST",
	Room.RoomType.TRAP: "MAP_ROOM_TRAP", Room.RoomType.PUZZLE: "MAP_ROOM_PUZZLE", Room.RoomType.SECRET: "MAP_ROOM_SECRET",
	Room.RoomType.BOSS: "MAP_ROOM_BOSS", Room.RoomType.INTOXICATION: "MAP_ROOM_INTOXICATION", Room.RoomType.MINIBOSS: "MAP_ROOM_MINIBOSS",
	Room.RoomType.START: "MAP_ROOM_START", Room.RoomType.SILENCIO: "SIL_MAP_SALA",
}
## Letra dentro de la sala en el mapa (las que no salen aqui no llevan marca).
const ICONS := {Room.RoomType.SHOP: "$", Room.RoomType.BOSS: "J", Room.RoomType.START: "I",
	Room.RoomType.MINIBOSS: "M", Room.RoomType.SECRET: "?", Room.RoomType.TREASURE: "T",
	Room.RoomType.REST: "+", Room.RoomType.LORE: "i", Room.RoomType.PUZZLE: "P"}

const CORRIDOR := Color(0.7, 0.65, 0.55, 0.75)
const DOOR_MARK := Color("f2ead6")
const DIRS := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]  # Door.Direction
const STUB := 3.0  # px que el pasillo sale recto de la pared antes de quebrar

var _font: Font
var _label: Label
var _map_hint: HBoxContainer  # "[M] mapa" con el glifo de la tecla

var _frame := HudStyle.panel_box(0)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_label = HudStyle.pixel_label("", 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)
	_build_map_hint()
	_resize()

func _resize() -> void:
	var s := SMALL
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -s.x - 10; offset_right = -10
	offset_top = HUD.BAND + 6; offset_bottom = HUD.BAND + 6 + s.y
	# mas ancho que el mapa y alineado a la derecha: el texto crece hacia la izquierda
	_label.position = Vector2(-200, s.y + 4)
	_label.size = Vector2(s.x + 200, 20)
	_place_map_hint()

## Abre el mapa a pantalla completa (pausa el juego; no si otro sistema ya lo pausa).
func _open_map() -> void:
	if get_tree().paused or not get_node("/root/RunManager").run_active:
		return
	MapMetroid.open(get_tree().root)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and not event.is_echo():
		_open_map()  # accion "map" (Controls): M / Select-Back por defecto
	# con controles tactiles: tocar el minimapa abre el mapa
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and TouchControls.is_active() and get_global_rect().has_point(event.position):
		_open_map()

func _process(delta: float) -> void:
	queue_redraw()
	var target := 1.0
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and get_global_rect().grow(40).has_point(p.get_global_transform_with_canvas().origin):
		target = 0.25
	modulate.a = move_toward(modulate.a, target, delta * 4.0)

func _draw() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main == null or main.dungeon_generator == null or main.dungeon_generator.rooms.is_empty():
		return
	if main.corridor_active:
		_draw_corridor(main)  # pasillo entre reinos: el minimapa muestra el tramo, no un piso
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

	# Autotest de VIH (defensa de mano izquierda): unos segundos, las salas secretas cercanas se ven en el mapa.
	var peeked := {}
	if main.has_meta("autotest_until") and Time.get_ticks_msec() < int(main.get_meta("autotest_until")) and current != null:
		var cur_pos := Vector2.ZERO
		for pos in gen.rooms:
			if gen.rooms[pos] == current:
				cur_pos = Vector2(pos)
		for pos in gen.rooms:
			if gen.rooms[pos].room_type == Room.RoomType.SECRET and Vector2(pos).distance_to(cur_pos) <= 45.0:
				known[pos] = true
				peeked[pos] = true

	# Encaja todo el piso (no solo lo conocido) para que el mapa no "salte".
	var bounds := Rect2i()
	var first := true
	for pos in gen.rooms:
		var r := Rect2i(pos, gen.room_sizes.get(pos, Vector2i(8, 6)))
		bounds = r if first else bounds.merge(r)
		first = false
	var box := size - Vector2(12, 12)
	var k: float = minf(box.x / bounds.size.x, box.y / bounds.size.y)
	var origin := Vector2(6, 6) + (box - Vector2(bounds.size) * k) / 2 - Vector2(bounds.position) * k

	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	if FloorEvents.hide_map():  # evento "Censura total": sin mapa
		_label.text = ""
		draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), Color(0.05, 0.05, 0.07, 0.9))
		draw_string(_font, Vector2(0, size.y / 2 + 6), tr("MAP_CENSORED"), HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color("d8d8e6"))
		return

	var rect_of := func(pos: Vector2i) -> Rect2:
		return Rect2(origin + Vector2(pos) * k, Vector2(gen.room_sizes.get(pos, Vector2i(8, 6))) * k)

	# Pasillos entre salas conocidas: de puerta a puerta en codo (antes iban centro a centro
	# en diagonal, cruzaban otras salas y no se sabia por que pared salir).
	var door_marks := []
	for pos in known:
		for n in gen.room_graph.get(pos, []):
			if not known.has(n) or not (visited.has(pos) or visited.has(n)) or (n.x < pos.x or (n.x == pos.x and n.y < pos.y)):
				continue  # cada pasillo una vez
			var da = _door_toward(gen, pos, n)
			var db = _door_toward(gen, n, pos)
			if da == null or db == null:
				draw_line(rect_of.call(pos).get_center(), rect_of.call(n).get_center(), CORRIDOR, 2.0)
				continue
			var a0: Vector2 = origin + da.cell * k
			var b0: Vector2 = origin + db.cell * k
			draw_polyline(_corridor_path(a0, da.dir, b0, db.dir), CORRIDOR, 2.0)
			door_marks.append(a0)
			door_marks.append(b0)

	var blink := int(Time.get_ticks_msec() / 400) % 2 == 0
	for pos in known:
		var room: Room = gen.rooms[pos]
		var r: Rect2 = rect_of.call(pos).grow(-1)
		var fill: Color
		if room == current:
			fill = Color("f2ead6") if blink else Color("ffc93c")
		elif visited.has(pos):
			fill = Color(0.45, 0.75, 0.45) if room.cleared or room.enemies_spawned.is_empty() else Color(0.8, 0.4, 0.4)
		elif peeked.has(pos):
			fill = Color("5fd0c8") if blink else Color("2f8f8a")
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

	# hueco claro en la pared donde esta cada puerta
	for m in door_marks:
		draw_rect(Rect2(m - Vector2(2, 2), Vector2(4, 4)), DOOR_MARK)

	if current:
		Silencio.draw_minimap(self, rect_of.call(current.grid_pos), current)  # S4: "Te siguen"
		var rname: String = tr("MAP_ROOM_ELITE") if current.has_meta("elite_room") else tr(ROOM_NAMES.get(current.room_type, "?"))
		var rm := get_node_or_null("/root/RunManager")
		if rm:
			if current.room_type == Room.RoomType.BOSS and not RunManager.floor_has_boss(rm.current_floor):
				rname = tr("MAP_ROOM_GUARD")  # 1a etapa: la sala final es un guardian, no un jefe
			rname = "%s · %s" % [Loc.floor_name(rm.floor_data(), true), rname]  # nombre de la etapa
		_label.text = rname
		_place_map_hint()

## Puerta de la sala `pos` que lleva a `to`: {cell (celdas del piso), dir}; null si no hay.
func _door_toward(gen: DungeonGenerator, pos: Vector2i, to: Vector2i) -> Variant:
	var room: Room = gen.rooms.get(pos)
	if room == null:
		return null
	for d in room.doors.values():
		if d.target_pos == to:
			return {"cell": Vector2(pos) + d.position / 64.0, "dir": DIRS[d.direction]}
	return null

## Codo ortogonal de puerta a puerta: sale perpendicular a la pared, quiebra a mitad de camino y entra igual.
func _corridor_path(a0: Vector2, da: Vector2, b0: Vector2, db: Vector2) -> PackedVector2Array:
	var a1 := a0 + da * STUB
	var b1 := b0 + db * STUB
	var pts := PackedVector2Array([a0, a1])
	if da.x != 0.0:
		var mx := (a1.x + b1.x) / 2.0
		pts.append(Vector2(mx, a1.y))
		pts.append(Vector2(mx, b1.y))
	else:
		var my := (a1.y + b1.y) / 2.0
		pts.append(Vector2(a1.x, my))
		pts.append(Vector2(b1.x, my))
	pts.append(b1)
	pts.append(b0)
	return pts

## Pasillo entre reinos: los dos reinos unidos por una barra con la ficha del heroe (corridor_bar.gd).
func _draw_corridor(main: Node) -> void:
	var c: Dictionary = main._corridor
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var from_r := str(c.get("from", ""))
	var to_r := str(c.get("to", ""))
	CorridorBar.draw_bar(self, Rect2(Vector2(10, size.y * 0.5 - 22), Vector2(size.x - 20, 44)), Loc.region_name_id(from_r), Loc.region_name_id(to_r),
		RunManager.region_tint(from_r), RunManager.region_tint(to_r), main.corridor_progress(), true)
	_label.text = tr("PAS_TRANSIT")
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
	var s := SMALL
	_map_hint.size = Vector2(w, 28)
	_map_hint.position = Vector2(s.x - w, s.y + 2)
	_label.size.x = s.x + 200 - w - 8
