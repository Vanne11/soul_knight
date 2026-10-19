class_name Corridor
extends RefCounted

## PASILLO DE TRANSICION entre dos reinos: una sala especial, caminable y sin combate, cuyo suelo es un
## camino ESTRECHO (2-3 baldosas) con curvas y recodos que avanza en la direccion del viaje; a veces trae
## 1-2 ramales cortos sin salida (un pequeno laberinto: nada que frustre; el camino bueno se sigue por los
## chevrones del suelo, la mezcla de suelos y los carteles de flechas, que senalan el rumbo en cada
## bifurcacion). La forma cambia entre viajes (semilla). Empieza con el estilo del reino de origen y
## termina con el del destino; en el tramo del medio los dos se mezclan baldosa a baldosa (dos TileMap por
## capa). Atras una puerta sellada (no hay vuelta), al fondo la del reino nuevo.
## Lo arma main.gd (_begin_corridor); el indicador de progreso es corridor_bar.gd.
##
## Espacio del viaje (u, v): u avanza hacia el destino (0..LEN-1) y v cruza (0..ACROSS-1); `_cell` lo pasa a
## baldosas segun la direccion. Metas de la sala: corridor_cl (centro del camino, px locales, en orden),
## corridor_start / corridor_end (px locales), corridor_signs (puntos de cartel).

const TILE := 64
const LEN := 30          # baldosas a lo largo del viaje
const ACROSS := 12       # baldosas de ancho de la sala (el camino ocupa 2-3)
const BLEND_A := 0.18    # el mestizaje ocupa el 18%..82% del recorrido (el reino de origen manda al principio)
const BLEND_B := 0.82
const WALL_SOURCE := 4
const ROOM_SCENE := preload("res://src/dungeon/room.tscn")


## Tamano en baldosas de la sala segun la direccion del viaje.
static func size_for(dir: String) -> Vector2i:
	return Vector2i(LEN, ACROSS) if dir in ["left", "right"] else Vector2i(ACROSS, LEN)


static func _fwd(dir: String) -> Vector2:
	return {"right": Vector2.RIGHT, "left": Vector2.LEFT, "down": Vector2.DOWN, "up": Vector2.UP}[dir]


## Baldosa de la sala para el punto (u, v) del espacio del viaje.
static func _cell(dir: String, u: int, v: int) -> Vector2i:
	match dir:
		"right": return Vector2i(u, v)
		"left": return Vector2i(LEN - 1 - u, v)
		"down": return Vector2i(v, u)
	return Vector2i(v, LEN - 1 - u)


static func _center_px(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * TILE


## Avance 0..1 de un punto local (px) por el camino (indice del punto del centro mas cercano).
static func progress(room: Room, local: Vector2) -> float:
	var cl: PackedVector2Array = room.get_meta("corridor_cl", PackedVector2Array())
	if cl.size() < 2:
		return 0.0
	var best := 0
	var bd := INF
	for i in cl.size():
		var d := cl[i].distance_squared_to(local)
		if d < bd:
			bd = d
			best = i
	return float(best) / float(cl.size() - 1)


static func start_pos(room: Room) -> Vector2:
	return room.get_meta("corridor_start")


static func end_pos(room: Room) -> Vector2:
	return room.get_meta("corridor_end")


## Genera el camino (centro) y los ramales. Devuelve {cl: Array[Vector2i] (u,v), floor: Dictionary (u,v)->true,
## junctions: Array[{cell:(u,v), tangent:Vector2i}], w: ancho}.
static func _carve(rng: RandomNumberGenerator, slide := false) -> Dictionary:
	if slide:
		# TOBOGAN (caida a la Puerta Trasera): un tubo recto de 3 baldosas, sin ramales
		var straight: Array[Vector2i] = []
		for uu in LEN:
			straight.append(Vector2i(uu, ACROSS / 2))
		var fl_s := {}
		_brush_all(fl_s, straight, 3)
		return {"cl": straight, "floor": fl_s, "junctions": [], "w": 3}
	var w := 3 if rng.randf() < 0.65 else 2
	var lo := 1 if w == 3 else 0
	var hi := ACROSS - 2
	var v := rng.randi_range(lo + 1, hi - 1)
	var u := 0
	var cl: Array[Vector2i] = [Vector2i(0, v)]
	while u < LEN - 1:
		var u2 := mini(u + rng.randi_range(3, 7), LEN - 1)
		for uu in range(u + 1, u2 + 1):
			cl.append(Vector2i(uu, v))
		u = u2
		if u >= LEN - 1:
			break
		# recodo: tramo lateral (hacia el lado con mas sitio, a veces al otro), de 3 a 7 baldosas
		var up_room := v - lo
		var down_room := hi - v
		var sgn := -1 if up_room > down_room else 1
		if rng.randf() < 0.3:
			sgn = -sgn
		var dv := mini(rng.randi_range(3, 7), up_room if sgn < 0 else down_room)
		if dv < 2:
			sgn = -sgn
			dv = mini(rng.randi_range(3, 6), up_room if sgn < 0 else down_room)
		for i in range(1, dv + 1):
			cl.append(Vector2i(u, v + sgn * i))
		v += sgn * dv
	var fl := {}
	_brush_all(fl, cl, w)
	# ramales sin salida: pocos y cortos (0-2)
	var junctions: Array = []
	var n_br: int = [0, 1, 1, 2][rng.randi_range(0, 3)]
	var tries := 0
	while junctions.size() < n_br and tries < 30:
		tries += 1
		var i := rng.randi_range(4, cl.size() - 5)
		var t := cl[i + 1] - cl[i - 1]
		if t.x != 0 and t.y != 0:
			continue  # solo en tramos rectos
		if cl[i + 2] - cl[i - 2] != t * 2:
			continue
		var perp := Vector2i(-t.y, t.x)
		if rng.randf() < 0.5:
			perp = -perp
		var k := rng.randi_range(3, 5)
		var stub: Array[Vector2i] = []
		# el ramal crece hasta k baldosas (o hasta donde quepa) sin tocar el camino salvo en su arranque
		for s in range(2, k + 3):
			var cand := cl[i] + perp * s
			var fits := true
			for c in _brush(cand, w):
				if c.x < 0 or c.y < 0 or c.x >= LEN or c.y >= ACROSS:
					fits = false
			if fits and stub.size() >= 2:
				for c in _brush(cand, w):
					if fl.has(c):
						fits = false
					for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						if fl.has(c + dd) and not _in_brush(stub + [cand], stub.size(), c + dd, w):
							fits = false
			if not fits:
				break
			stub.append(cand)
		var ok := stub.size() >= 4
		for j in junctions:
			if absi(int(j.index) - i) < 6:
				ok = false
		if not ok:
			continue
		_brush_all(fl, stub, w)
		junctions.append({"index": i, "cell": cl[i], "tangent": t, "perp": perp})
	return {"cl": cl, "floor": fl, "junctions": junctions, "w": w}


static func _brush(c: Vector2i, w: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var a := -1 if w == 3 else 0
	var b := 1
	for du in range(a, b + 1):
		for dv in range(a, b + 1):
			out.append(c + Vector2i(du, dv))
	return out


static func _brush_all(fl: Dictionary, cells: Array, w: int) -> void:
	for c in cells:
		for b in _brush(c, w):
			if b.x >= 0 and b.y >= 0 and b.x < LEN and b.y < ACROSS:
				fl[b] = true


static func _in_brush(stub: Array, upto: int, c: Vector2i, w: int) -> bool:
	for s in range(0, upto + 1):
		for b in _brush(stub[s], w):
			if b == c:
				return true
	return false


## Construye la sala (aun fuera del arbol; main la agrega y llama a finish_setup).
static func build(from_region: String, to_region: String, dir: String, seed_: int, slide := false) -> Room:
	var size := size_for(dir)
	var ka := RunManager.region_kingdom(from_region)
	var kb := RunManager.region_kingdom(to_region)
	if slide:
		ka = "vulva"  # tubo organico de tejido rosado con pliegues, del principio al fin
		kb = "vulva"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_, from_region, to_region, "pasillo"])
	var path := _carve(rng, slide)
	var cl: Array = path.cl
	var fl_uv: Dictionary = path.floor
	var room: Room = ROOM_SCENE.instantiate()
	room.room_type = Room.RoomType.CORRIDOR
	room.grid_pos = Vector2i.ZERO
	room.set_meta("corridor_dir", dir)
	room.set_meta("corridor_slide", slide)
	room.set_meta("corridor_from", from_region)
	room.set_meta("corridor_to", to_region)
	# forma: 0 suelo (el camino), 1 muro (todo lo demas)
	var is_floor := {}
	for c in fl_uv:
		is_floor[_cell(dir, c.x, c.y)] = true
	var cells := PackedByteArray()
	cells.resize(size.x * size.y)
	for y in size.y:
		for x in size.x:
			cells[y * size.x + x] = 0 if is_floor.has(Vector2i(x, y)) else 1
	room.set_shape("corridor", size, cells, _cell(dir, 0, cl[0].y))
	# metas del camino
	var pts := PackedVector2Array()
	for c in cl:
		pts.append(_center_px(_cell(dir, c.x, c.y)))
	room.set_meta("corridor_cl", pts)
	var fwd := _fwd(dir)
	room.set_meta("corridor_start", pts[0] + fwd * TILE * 1.0)
	room.set_meta("corridor_end", pts[pts.size() - 1])
	var signs: Array = [{"pos": pts[0] + fwd * TILE * 2.0, "fwd": _step_dir(dir, cl[0], cl[mini(3, cl.size() - 1)])}]
	for j in path.junctions:
		var cu: Vector2i = j.cell
		var tg: Vector2i = j.tangent
		var pp: Vector2i = j.perp
		# el cartel va en el lado opuesto al ramal, mirando hacia donde sigue el camino bueno
		signs.append({"pos": _center_px(_cell(dir, cu.x, cu.y)) + _step_vec(dir, -pp) * TILE * (1.0 if path.w == 3 else 0.5) - _step_vec(dir, tg) * TILE * 0.0,
			"fwd": _step_dir(dir, Vector2i.ZERO, tg)})
	room.set_meta("corridor_signs", signs)
	# tilemaps
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
	var w := size.x
	var h := size.y
	for x in w:
		for y in h:
			var c := Vector2i(x, y)
			var u := _u(dir, c)
			var dest := rng.randf() < smoothstep(BLEND_A, BLEND_B, u)
			# suelo en TODA la rejilla (el rectangulo de la sala no cambia); los muros lo tapan donde toca
			var coords := _floor_coords(c, is_floor, rng)
			floor_a.set_cell(0, c, 0, coords)
			if dest:
				floor_b.set_cell(0, c, 0, coords)
	# muros: toda celda no pisable de la rejilla y el contorno (con esquinas)
	var wall_cells: Array[Vector2i] = []
	for x in range(-1, w + 1):
		for y in range(-1, h + 1):
			var c := Vector2i(x, y)
			if not is_floor.has(c):
				wall_cells.append(c)
	for c in wall_cells:
		var u := _u(dir, Vector2i(clampi(c.x, 0, w - 1), clampi(c.y, 0, h - 1)))
		var dest := rng.randf() < smoothstep(BLEND_A, BLEND_B, u)
		var v := hash(Vector3i(c.x * 131, c.y * 137, seed_)) & 1
		var front := 1 if is_floor.has(c + Vector2i(0, 1)) else 0  # cara frontal si debajo hay suelo (vista 3/4)
		walls_a.set_cell(0, c, WALL_SOURCE, Vector2i(front + v * 2, 0) if ts_wa != null else Vector2i.ZERO)
		if dest:
			walls_b.set_cell(0, c, WALL_SOURCE, Vector2i(front + v * 2, 0) if ts_wb != null else Vector2i.ZERO)
	return room


## Direccion en la sala (px) de un paso (du, dv) del espacio del viaje.
static func _step_vec(dir: String, d: Vector2i) -> Vector2:
	var a := _cell(dir, 0, 0)
	var b := _cell(dir, d.x, d.y)
	return Vector2(b - a)


static func _step_dir(dir: String, from_uv: Vector2i, to_uv: Vector2i) -> Vector2:
	var v := _step_vec(dir, to_uv - from_uv)
	return v.normalized() if v != Vector2.ZERO else _fwd(dir)


static func _u(dir: String, c: Vector2i) -> float:
	var t := float(LEN - 1)
	match dir:
		"right": return float(c.x) / t
		"left": return 1.0 - float(c.x) / t
		"down": return float(c.y) / t
	return 1.0 - float(c.y) / t


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


## Baldosa de suelo (atlas de floor_tiles.gd): relleno con variantes y borde pegado a lo que sea muro.
static func _floor_coords(c: Vector2i, is_floor: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	var n := not is_floor.has(c + Vector2i(0, -1))
	var s := not is_floor.has(c + Vector2i(0, 1))
	var o := not is_floor.has(c + Vector2i(-1, 0))
	var e := not is_floor.has(c + Vector2i(1, 0))
	if (n or s) and (o or e):
		return Vector2i(4 + (0 if o else 1) if n else 4 + (3 if o else 2), 2)
	if n or s or o or e:
		var d := 0 if n else (1 if e else (2 if s else 3))
		return Vector2i(d, 3 if rng.randf() < FloorTiles.BORDER_B_CHANCE else 2)
	var v := FloorTiles._pick_fill(rng, false)
	return Vector2i(v % 8, v / 8)


## Tras agregar la sala al arbol: censura/color, puertas (fondo abierta, atras sellada), decoracion mezclada,
## chevrones y carteles. `seed_` y `floor_n` solo siembran la decoracion.
static func finish_setup(room: Room, seed_: int, floor_n: int) -> void:
	var dir: String = room.get_meta("corridor_dir")
	var from_r: String = room.get_meta("corridor_from")
	var to_r: String = room.get_meta("corridor_to")
	var size_px := Vector2(size_for(dir)) * TILE
	var cl: PackedVector2Array = room.get_meta("corridor_cl")
	var slide: bool = bool(room.get_meta("corridor_slide", false))
	for n in ["FloorB", "WallsB"]:
		var tm := room.get_node_or_null(n) as CanvasItem
		if tm:
			Censor.apply(room, tm)
	Censor.apply(room, room.floor_tilemap)
	Censor.apply(room, room.walls_tilemap)
	if slide:
		return  # el tobogan es solo el tubo: sin puertas, decoracion ni carteles
	# puertas: al fondo la del reino nuevo (abierta) y atras la del viejo (sellada), pegadas a los extremos del camino
	var fwd := _fwd(dir)
	var end_dir := dir
	var back_dir := Pasillos.opposite(dir)
	var end_pos_ := cl[cl.size() - 1] + fwd * (TILE * 0.5)
	var back_pos := cl[0] - fwd * (TILE * 0.5)
	for spec in [[end_dir, end_pos_, to_r, true], [back_dir, back_pos, from_r, false]]:
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
	# chevrones pintados en el suelo (siguen el camino bueno) y carteles mudos de flechas
	var marks := Chevrons.new()
	marks.name = "Chevrons"
	marks.points = cl
	marks.color_a = RunManager.region_tint(from_r)
	marks.color_b = RunManager.region_tint(to_r)
	room.add_child(marks)
	room.move_child(marks, room.walls_tilemap.get_index())
	for sg in room.get_meta("corridor_signs"):
		var sign_ := ArrowSign.new()
		sign_.fwd = sg.fwd
		sign_.position = sg.pos
		room.add_child(sign_)


## [mitad de origen, mitad de destino] como Rect2 locales.
static func _half_rects(dir: String, size_px: Vector2) -> Array:
	var half := size_px * 0.5
	match dir:
		"right": return [Rect2(Vector2.ZERO, Vector2(half.x, size_px.y)), Rect2(Vector2(half.x, 0), Vector2(half.x, size_px.y))]
		"left": return [Rect2(Vector2(half.x, 0), Vector2(half.x, size_px.y)), Rect2(Vector2.ZERO, Vector2(half.x, size_px.y))]
		"down": return [Rect2(Vector2.ZERO, Vector2(size_px.x, half.y)), Rect2(Vector2(0, half.y), Vector2(size_px.x, half.y))]
	return [Rect2(Vector2(0, half.y), Vector2(size_px.x, half.y)), Rect2(Vector2.ZERO, Vector2(size_px.x, half.y))]


## Chevrones ">" cada 3 baldosas del camino bueno, del color del reino de origen al de destino.
class Chevrons extends Node2D:
	var points := PackedVector2Array()
	var color_a := Color.WHITE
	var color_b := Color.WHITE

	func _draw() -> void:
		var n := points.size()
		var i := 2
		while i < n - 2:
			var t := float(i) / float(n - 1)
			var fwd := (points[i + 1] - points[i - 1]).normalized()
			var side := fwd.orthogonal()
			var col := color_a.lerp(color_b, smoothstep(Corridor.BLEND_A, Corridor.BLEND_B, t)).lerp(Color.WHITE, 0.35)
			col.a = 0.5
			var p := points[i]
			draw_polyline(PackedVector2Array([p - fwd * 6.0 + side * 16.0, p + fwd * 12.0, p - fwd * 6.0 - side * 16.0]), col, 5.0)
			i += 3


## Cartel mudo: una tabla con tres flechas, sin una palabra (la direccion se explica sola).
class ArrowSign extends Node2D:
	var fwd := Vector2.RIGHT

	func _draw() -> void:
		var side := fwd.orthogonal()
		draw_rect(Rect2(-3, -2, 6, 26), Color("3b2a1c"))  # poste
		var board := Rect2(-30, -30, 60, 28)
		draw_rect(board.grow(3), Color("120c10"))
		draw_rect(board, Color("e8d8a8"))
		for i in 3:
			var c := Vector2((i - 1) * 17.0, -16.0)
			# flechas dibujadas segun el rumbo (en pantalla; la tabla es plana)
			var f := fwd
			var s := side
			var pts := PackedVector2Array([c + f * 7.0, c - f * 5.0 + s * 8.0, c - f * 2.0, c - f * 5.0 - s * 8.0])
			draw_colored_polygon(pts, Color("b0342c"))
