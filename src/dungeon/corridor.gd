class_name Corridor
extends RefCounted

## PASILLO DE TRANSICION entre dos reinos: una sala especial alargada en la direccion del viaje, caminable
## y sin combate. Empieza con el estilo del reino de origen (suelo, muros, decoracion) y termina con el del
## destino; en el tramo del medio los dos se mezclan baldosa a baldosa (dos TileMap por capa: la baldosa
## sale de uno u otro segun un sorteo que favorece al reino cercano). Cartel mudo de flechas y chevrones
## pintados en el suelo; al fondo una puerta del reino nuevo, atras una sellada (no hay vuelta).
## Lo arma main.gd (_begin_corridor); el indicador de progreso es corridor_bar.gd.

const TILE := 64
const LEN := 24          # baldosas a lo largo del viaje
const WID := 6           # baldosas de ancho
const BLEND_A := 0.18    # el mestizaje ocupa el 18%..82% del recorrido (el reino de origen manda al principio)
const BLEND_B := 0.82
const WALL_SOURCE := 4
const ROOM_SCENE := preload("res://src/dungeon/room.tscn")


## Tamano en baldosas segun la direccion del viaje.
static func size_for(dir: String) -> Vector2i:
	return Vector2i(LEN, WID) if dir in ["left", "right"] else Vector2i(WID, LEN)


## Avance 0..1 de un punto local (px) a lo largo del viaje.
static func progress(dir: String, local: Vector2) -> float:
	var s := size_for(dir)
	var len_px := float(LEN * TILE)
	match dir:
		"right": return clampf(local.x / len_px, 0.0, 1.0)
		"left": return clampf(1.0 - local.x / len_px, 0.0, 1.0)
		"down": return clampf(local.y / len_px, 0.0, 1.0)
	return clampf(1.0 - local.y / (float(s.y) * TILE), 0.0, 1.0)


## Donde aparece el heroe (local, px): dentro del extremo de salida.
static func start_pos(dir: String) -> Vector2:
	var s := size_for(dir) * TILE
	match dir:
		"right": return Vector2(1.6 * TILE, s.y * 0.5)
		"left": return Vector2(s.x - 1.6 * TILE, s.y * 0.5)
		"down": return Vector2(s.x * 0.5, 1.6 * TILE)
	return Vector2(s.x * 0.5, s.y - 1.6 * TILE)


static func _u(dir: String, c: Vector2i) -> float:
	var t := float(LEN - 1)
	match dir:
		"right": return float(c.x) / t
		"left": return 1.0 - float(c.x) / t
		"down": return float(c.y) / t
	return 1.0 - float(c.y) / t


## Construye la sala (aun fuera del arbol; main la agrega y llama a finish_setup).
static func build(from_region: String, to_region: String, dir: String, seed_: int) -> Room:
	var size := size_for(dir)
	var ka := RunManager.region_kingdom(from_region)
	var kb := RunManager.region_kingdom(to_region)
	var room: Room = ROOM_SCENE.instantiate()
	room.room_type = Room.RoomType.CORRIDOR
	room.grid_pos = Vector2i.ZERO
	room.set_meta("corridor_dir", dir)
	room.set_meta("corridor_from", from_region)
	room.set_meta("corridor_to", to_region)
	room.set_shape("rect", size, PackedByteArray(), Vector2i(size.x / 2, size.y / 2))
	var floor_a := room.get_node("Floor") as TileMap
	var walls_a := room.get_node("Walls") as TileMap
	var ts_fa := FloorTiles.tileset_for(ka)
	var ts_fb := FloorTiles.tileset_for(kb)
	if ts_fa == null:
		ts_fa = FloorTiles.tileset_for("neutral")
	if ts_fb == null:
		ts_fb = FloorTiles.tileset_for("neutral")
	var ts_wa := _walls(ka)
	var ts_wb := _walls(kb)
	var floor_b := _twin(room, floor_a, "FloorB")
	var walls_b := _twin(room, walls_a, "WallsB")
	if ts_fa != null:
		floor_a.tile_set = ts_fa
	if ts_fb != null:
		floor_b.tile_set = ts_fb
	if ts_wa != null:
		walls_a.tile_set = ts_wa
	if ts_wb != null:
		walls_b.tile_set = ts_wb
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_, from_region, to_region, "pasillo"])
	var w := size.x
	var h := size.y
	for x in w:
		for y in h:
			var c := Vector2i(x, y)
			var dest := rng.randf() < smoothstep(BLEND_A, BLEND_B, _u(dir, c))
			var coords := _floor_coords(c, w, h, rng)
			floor_a.set_cell(0, c, 0, coords)  # el reino de origen pinta TODO (mantiene el rectangulo de la sala)...
			if dest:
				floor_b.set_cell(0, c, 0, coords)  # ...y el de destino se superpone donde le toca
	# muros: el contorno con las esquinas (como dungeon_generator._setup_room_tilemap)
	var cells: Array[Vector2i] = []
	for x in range(-1, w + 1):
		cells.append(Vector2i(x, -1))
		cells.append(Vector2i(x, h))
	for y in range(h):
		cells.append(Vector2i(-1, y))
		cells.append(Vector2i(w, y))
	for c in cells:
		var dest := rng.randf() < smoothstep(BLEND_A, BLEND_B, _u(dir, Vector2i(clampi(c.x, 0, w - 1), clampi(c.y, 0, h - 1))))
		var v := hash(Vector3i(c.x * 131, c.y * 137, seed_)) & 1
		var front := 1 if c.y == -1 else 0
		walls_a.set_cell(0, c, WALL_SOURCE, Vector2i(front + v * 2, 0) if ts_wa != null else Vector2i.ZERO)
		if dest:
			walls_b.set_cell(0, c, WALL_SOURCE, Vector2i(front + v * 2, 0) if ts_wb != null else Vector2i.ZERO)
	return room


static func _walls(kingdom: String) -> TileSet:
	var path := "res://assets/tilesets/walls_%s.tres" % kingdom
	return load(path) as TileSet if ResourceLoader.exists(path) else null


## Segundo TileMap gemelo (mismo sitio y mascara de luz) para el otro reino.
static func _twin(room: Room, src: TileMap, name_: String) -> TileMap:
	var t := TileMap.new()
	t.name = name_
	t.light_mask = src.light_mask
	t.tile_set = src.tile_set
	room.add_child(t)
	room.move_child(t, src.get_index() + 1)
	return t


## Baldosa de suelo (atlas de floor_tiles.gd): relleno con variantes y borde pegado al muro.
static func _floor_coords(c: Vector2i, w: int, h: int, rng: RandomNumberGenerator) -> Vector2i:
	var n := c.y == 0
	var s := c.y == h - 1
	var o := c.x == 0
	var e := c.x == w - 1
	if (n or s) and (o or e):
		return Vector2i(4 + (0 if o else 1) if n else 4 + (3 if o else 2), 2)
	if n or s or o or e:
		var d := 0 if n else (1 if e else (2 if s else 3))
		return Vector2i(d, 3 if rng.randf() < FloorTiles.BORDER_B_CHANCE else 2)
	var v := FloorTiles._pick_fill(rng, false)
	return Vector2i(v % 8, v / 8)


## Tras agregar la sala al arbol: censura/color, puertas (fondo abierta, atras sellada), decoracion mezclada,
## chevrones y cartel. `seed_` y `floor_n` solo siembran la decoracion.
static func finish_setup(room: Room, seed_: int, floor_n: int) -> void:
	var dir: String = room.get_meta("corridor_dir")
	var from_r: String = room.get_meta("corridor_from")
	var to_r: String = room.get_meta("corridor_to")
	var size := size_for(dir)
	var size_px := Vector2(size) * TILE
	for n in ["FloorB", "WallsB"]:
		var tm := room.get_node_or_null(n) as CanvasItem
		if tm:
			Censor.apply(room, tm)
	Censor.apply(room, room.floor_tilemap)
	Censor.apply(room, room.walls_tilemap)
	# puertas: la del fondo (reino nuevo) y la de atras (reino viejo, sellada)
	var end_dir := dir
	var back_dir := Pasillos.opposite(dir)
	var end_pos := _wall_mid(end_dir, size_px)
	var back_pos := _wall_mid(back_dir, size_px)
	for spec in [[end_dir, end_pos, to_r, true], [back_dir, back_pos, from_r, false]]:
		var door: Door = load("res://src/dungeon/door.tscn").instantiate()
		door.direction = Pasillos.dir_index(spec[0])
		door.set_meta("door_kingdom", RunManager.region_kingdom(spec[2]))
		door.name = "Door_%s" % spec[0]
		door.position = spec[1]
		room.doors_node.add_child(door)
		door.room = room
		room.doors[door.name] = door
		door.set_state(Door.State.OPEN if spec[3] else Door.State.SEALED)
	# decoracion: cada reino solo en su mitad (la zona del otro es "vedada")
	var half := _half_rects(dir, size_px)
	RoomDecor.build(room, RunManager.region_kingdom(from_r), seed_, floor_n, [half[1]])
	room.remove_meta("decor")
	RoomDecor.build(room, RunManager.region_kingdom(to_r), seed_, floor_n, [half[0]])
	# chevrones pintados en el suelo y cartel mudo de flechas
	var marks := Chevrons.new()
	marks.name = "Chevrons"
	marks.dir = dir
	marks.size_px = size_px
	marks.color_a = RunManager.region_tint(from_r)
	marks.color_b = RunManager.region_tint(to_r)
	marks.z_index = 0
	room.add_child(marks)
	room.move_child(marks, room.walls_tilemap.get_index())
	var sign_ := ArrowSign.new()
	sign_.name = "ArrowSign"
	sign_.dir = dir
	sign_.position = _sign_pos(dir, size_px)
	room.add_child(sign_)


static func _wall_mid(dir: String, size_px: Vector2) -> Vector2:
	match dir:
		"up": return Vector2(size_px.x * 0.5, 0.0)
		"down": return Vector2(size_px.x * 0.5, size_px.y)
		"left": return Vector2(0.0, size_px.y * 0.5)
	return Vector2(size_px.x, size_px.y * 0.5)


## [mitad de origen, mitad de destino] como Rect2 locales (con el tramo mestizo en cada una a su lado).
static func _half_rects(dir: String, size_px: Vector2) -> Array:
	var half := size_px * 0.5
	match dir:
		"right": return [Rect2(Vector2.ZERO, Vector2(half.x, size_px.y)), Rect2(Vector2(half.x, 0), Vector2(half.x, size_px.y))]
		"left": return [Rect2(Vector2(half.x, 0), Vector2(half.x, size_px.y)), Rect2(Vector2.ZERO, Vector2(half.x, size_px.y))]
		"down": return [Rect2(Vector2.ZERO, Vector2(size_px.x, half.y)), Rect2(Vector2(0, half.y), Vector2(size_px.x, half.y))]
	return [Rect2(Vector2(0, half.y), Vector2(size_px.x, half.y)), Rect2(Vector2.ZERO, Vector2(size_px.x, half.y))]


## El cartel va pegado al muro, cerca del arranque.
static func _sign_pos(dir: String, size_px: Vector2) -> Vector2:
	match dir:
		"right": return Vector2(3.0 * TILE, 1.0 * TILE + 20.0)
		"left": return Vector2(size_px.x - 3.0 * TILE, size_px.y - 1.0 * TILE + 20.0)
		"down": return Vector2(size_px.x - 1.0 * TILE, 3.0 * TILE)
	return Vector2(1.0 * TILE, size_px.y - 3.0 * TILE)


## Chevrones ">" repetidos a lo largo del camino, del color del reino de origen al de destino.
class Chevrons extends Node2D:
	var dir := "right"
	var size_px := Vector2.ZERO
	var color_a := Color.WHITE
	var color_b := Color.WHITE

	func _draw() -> void:
		var forward := {"right": Vector2.RIGHT, "left": Vector2.LEFT, "down": Vector2.DOWN, "up": Vector2.UP}[dir] as Vector2
		var side := forward.orthogonal()
		var len_px := float(Corridor.LEN * Corridor.TILE)
		var center := size_px * 0.5
		var step := 3.0 * Corridor.TILE
		var n := int(len_px / step)
		for i in range(1, n):
			var t := float(i) / float(n)
			var along := (t - 0.5) * len_px
			var p := center + forward * along
			var col := color_a.lerp(color_b, smoothstep(Corridor.BLEND_A, Corridor.BLEND_B, t))
			col = col.lerp(Color.WHITE, 0.35)
			col.a = 0.38
			var tip := p + forward * 14.0
			var l := p - forward * 6.0 + side * 18.0
			var r := p - forward * 6.0 - side * 18.0
			draw_polyline(PackedVector2Array([l, tip, r]), col, 6.0)


## Cartel mudo: una tabla con tres flechas, sin una palabra (la direccion se explica sola).
class ArrowSign extends Node2D:
	var dir := "right"

	func _draw() -> void:
		var forward := {"right": Vector2.RIGHT, "left": Vector2.LEFT, "down": Vector2.DOWN, "up": Vector2.UP}[dir] as Vector2
		var side := forward.orthogonal()
		# poste
		draw_rect(Rect2(-3, -2, 6, 26), Color("3b2a1c"))
		var board := Rect2(-30, -30, 60, 28)
		draw_rect(board.grow(3), Color("120c10"))
		draw_rect(board, Color("e8d8a8"))
		for i in 3:
			var c := Vector2((i - 1) * 17.0, -16.0)
			var f := forward
			var s := side
			var pts := PackedVector2Array([c + f * 7.0, c - f * 5.0 + s * 8.0, c - f * 2.0, c - f * 5.0 - s * 8.0])
			draw_colored_polygon(pts, Color("b0342c"))
