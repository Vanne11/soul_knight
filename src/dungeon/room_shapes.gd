class_name RoomShapes
extends RefCounted

## Formas del INTERIOR de cada sala (roadmap_nico, etapa 5c). El rectangulo exterior (muros del
## borde, puertas, camara, minimapa, get_used_rect del suelo) no cambia nunca: lo que cambia es
## que celdas de dentro se pueden pisar.
##
## Cada celda de la sala es de un tipo:
##   FLOOR  suelo normal (lo unico que se pisa)
##   WALL   muro macizo: baldosa en el TileMap Walls (L, cruz, octogono, circulo, pilar, centro elevado)
##   PIT    abismo: no se pisa (cuerpo en la capa 1 + dibujo ShapeFx)
##   WATER  agua profunda: igual que el abismo pero azul y con olas
##   LOW    muro bajo: baldosa "cara" en el TileMap Walls (para que las balas tampoco pasen)
## Todo lo no pisable choca en la capa fisica 1 (la de los muros): asi el jugador, los enemigos,
## las balas, los rayos de luz y las consultas de src/rooms y del bot lo ven sin cambiar nada.
##
## Se guarda en la sala (Room.set_shape) y se consulta con la API de Room:
## is_walkable(pos, margen), rect_walkable(rect), walkable_rect_list(), nearest_walkable(pos).
##
## Determinista: RandomNumberGenerator local con hash(semilla, piso, grid_pos); NO toca el RNG
## global (el trazado del piso es identico con o sin formas).
## Garantias: cada puerta (2 baldosas de ancho x 2 de fondo) es suelo y queda conectada por suelo
## al ancla (la celda pisable mas cercana al centro); las celdas pisables que quedan aisladas se
## rellenan; el rectangulo exterior conserva suelo en sus cuatro lados; jefe y minijefe solo
## llevan formas de arena amplia; START/TIENDA/DESCANSO/tesoro/lore/puzzle/secreta son rectangulos.

const TILE := 64
const WALL_SOURCE := 4
const FLOOR := 0
const WALL := 1
const PIT := 2
const WATER := 3
const LOW := 4

## id -> {min: tamano minimo (lado corto, largo) o (x, y), tier: piso desde el que sale, w: peso}
const DEFS := {
	"l": {"min": Vector2i(8, 6), "tier": 1, "w": 3.0},
	"octagon": {"min": Vector2i(8, 6), "tier": 1, "w": 2.0},
	"columns": {"min": Vector2i(11, 8), "tier": 1, "w": 2.0},
	"split": {"min": Vector2i(8, 6), "tier": 1, "w": 2.0},
	"cross": {"min": Vector2i(9, 8), "tier": 3, "w": 2.5},
	"circle": {"min": Vector2i(8, 6), "tier": 3, "w": 2.5},
	"hall": {"min": Vector2i(9, 7), "tier": 3, "w": 2.0},
	"island_pair": {"min": Vector2i(10, 6), "tier": 3, "w": 2.0},
	"island": {"min": Vector2i(8, 6), "tier": 5, "w": 2.5},
	"ring": {"min": Vector2i(10, 8), "tier": 5, "w": 2.5},
}
const ARENA_SHAPES := ["octagon", "circle"]  # jefe / minijefe / guardian
const FIGHT_ROOMS := [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP]
## Probabilidad de agua (en vez de abismo) en los huecos, por reino.
const WATER_CHANCE := {"neutral": 0.6, "pene": 0.3, "vulva": 0.6, "mixto": 0.2, "censura": 0.0, "prostata": 0.2}
## Prueba/capturas: fuerza esta forma en toda sala de combate donde quepa ("" = sorteo normal).
static var force_id := ""
const MIN_RATIO := 0.5
const MIN_RATIO_ARENA := 0.72


## Probabilidad de que una sala de combate lleve forma (sube con la profundidad).
static func chance(floor_n: int) -> float:
	return clampf(0.3 + 0.07 * float(floor_n - 1), 0.0, 0.9)


## Elige y aplica la forma de la sala. Devuelve el id ("rect" si no lleva forma).
static func assign(room: Room, size: Vector2i, floor_n: int, run_seed: int) -> String:
	var id := _pick(room, size, floor_n, run_seed)
	var rng := _rng(room, run_seed, floor_n)
	rng.randf()  # separa la tirada del sorteo
	if id != "rect":
		var kingdom := FloorTiles.kingdom_for_floor(floor_n)
		var res := _make(id, size.x, size.y, rng, kingdom)
		var cells: PackedByteArray = res.cells
		if _finalize(room, size.x, size.y, cells, int(res.fill), room.room_type in [Room.RoomType.BOSS, Room.RoomType.MINIBOSS]):
			var anchor := _anchor(cells, size.x, size.y)
			room.set_shape(id, size, cells, anchor)
			_build(room, size.x, size.y, cells, floor_n)
			return id
	room.set_shape("rect", size, PackedByteArray(), Vector2i(size.x / 2, size.y / 2))
	return "rect"


static func _rng(room: Room, run_seed: int, floor_n: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([run_seed, floor_n, room.grid_pos.x, room.grid_pos.y, "shape"])
	return r


## Sorteo del id segun tipo de sala, profundidad y tamano. Sin formas en las salas "especiales".
static func _pick(room: Room, size: Vector2i, floor_n: int, run_seed: int) -> String:
	var rng := _rng(room, run_seed, floor_n)
	var t: int = room.room_type
	var arena := t in [Room.RoomType.BOSS, Room.RoomType.MINIBOSS]
	if force_id != "" and t in FIGHT_ROOMS and DEFS.has(force_id):
		var fm: Vector2i = DEFS[force_id].min
		var lo_f := mini(size.x, size.y)
		var hi_f := maxi(size.x, size.y)
		var fits_f := (lo_f >= mini(fm.x, fm.y) and hi_f >= maxi(fm.x, fm.y)) if force_id == "hall" else (size.x >= fm.x and size.y >= fm.y)
		return force_id if fits_f else "rect"
	if not arena and t not in FIGHT_ROOMS:
		return "rect"
	if rng.randf() >= (0.5 if arena else chance(floor_n)):
		return "rect"
	var lo := mini(size.x, size.y)
	var hi := maxi(size.x, size.y)
	var pool: Array[String] = []
	var weights: Array[float] = []
	for id in DEFS:
		var d: Dictionary = DEFS[id]
		if arena and id not in ARENA_SHAPES:
			continue
		if floor_n < int(d.tier):
			continue
		var mn: Vector2i = d.min
		var fits: bool = (lo >= mini(mn.x, mn.y) and hi >= maxi(mn.x, mn.y)) if id == "hall" else (size.x >= mn.x and size.y >= mn.y)
		if not fits:
			continue
		pool.append(id)
		weights.append(float(d.w))
	if pool.is_empty():
		return "rect"
	var total := 0.0
	for x in weights:
		total += x
	var r := rng.randf() * total
	for i in pool.size():
		r -= weights[i]
		if r <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


# ------------------------------------------------------------------ plantillas
static func _idx(x: int, y: int, w: int) -> int:
	return y * w + x


static func _fill_rect(cells: PackedByteArray, w: int, h: int, x0: int, y0: int, rw: int, rh: int, kind: int) -> void:
	for x in range(maxi(x0, 0), mini(x0 + rw, w)):
		for y in range(maxi(y0, 0), mini(y0 + rh, h)):
			cells[_idx(x, y, w)] = kind


## {cells, fill}: fill = en que se convierten las celdas pisables que quedan aisladas.
static func _make(id: String, w: int, h: int, rng: RandomNumberGenerator, kingdom: String) -> Dictionary:
	var cells := PackedByteArray()
	cells.resize(w * h)
	var fill := WALL
	var hole := WATER if rng.randf() < float(WATER_CHANCE.get(kingdom, 0.3)) else PIT
	match id:
		"l":
			var cw := clampi(int(round(float(w) * rng.randf_range(0.34, 0.46))), 2, w - 4)
			var ch := clampi(int(round(float(h) * rng.randf_range(0.38, 0.5))), 2, h - 3)
			var left := rng.randf() < 0.5
			var top := rng.randf() < 0.5
			_fill_rect(cells, w, h, 0 if left else w - cw, 0 if top else h - ch, cw, ch, WALL)
		"cross":
			var cw := clampi(int(float(w) * 0.28), 2, (w - 3) / 2)
			var ch := clampi(int(float(h) * 0.3), 2, (h - 3) / 2)
			_fill_rect(cells, w, h, 0, 0, cw, ch, WALL)
			_fill_rect(cells, w, h, w - cw, 0, cw, ch, WALL)
			_fill_rect(cells, w, h, 0, h - ch, cw, ch, WALL)
			_fill_rect(cells, w, h, w - cw, h - ch, cw, ch, WALL)
		"octagon":
			var c := maxi(2, int(float(mini(w, h)) / 3.0))
			for x in w:
				for y in h:
					if mini(x, w - 1 - x) + mini(y, h - 1 - y) < c:
						cells[_idx(x, y, w)] = WALL
		"circle":
			for x in w:
				for y in h:
					var u := (float(x) + 0.5 - float(w) * 0.5) / (float(w) * 0.5)
					var v := (float(y) + 0.5 - float(h) * 0.5) / (float(h) * 0.5)
					if u * u + v * v > 1.04:
						cells[_idx(x, y, w)] = WALL
		"columns":
			var fx := float(w - 1) * 0.5
			var fy := float(h - 1) * 0.5
			var xs: Array[int] = []
			var ys: Array[int] = []
			for k in range(-6, 7):
				var off := float(k) * 3.0 + (1.5 if w % 2 == 0 else 0.0)
				var x := int(round(fx + off))
				if x >= 2 and x <= w - 3 and not xs.has(x):
					xs.append(x)
			for k in range(-6, 7):
				var off := float(k) * 3.0 + (1.5 if h % 2 == 0 else 0.0)
				var y := int(round(fy + off))
				if y >= 2 and y <= h - 3 and not ys.has(y):
					ys.append(y)
			for x in xs:
				for y in ys:
					if absf(float(x) - fx) <= 1.2 and absf(float(y) - fy) <= 1.2:
						continue  # el centro queda libre (recompensas)
					cells[_idx(x, y, w)] = WALL
		"hall":
			var horiz := w >= h
			var long_d := w if horiz else h
			var short_d := h if horiz else w
			var ya := maxi(2, short_d / 3)
			var yb := short_d - 1 - ya
			var g1 := clampi(long_d / 4 + rng.randi_range(-1, 1), 2, long_d - 5)
			var g2 := clampi(long_d - long_d / 4 - 2 + rng.randi_range(-1, 1), g1 + 3, long_d - 3)
			for u in range(1, long_d - 1):
				if (u >= g1 and u <= g1 + 1) or (u >= g2 and u <= g2 + 1):
					continue
				for v in [ya, yb]:
					var cx: int = u if horiz else v
					var cy: int = v if horiz else u
					cells[_idx(cx, cy, w)] = LOW
			fill = LOW
		"split":
			var horiz := w < h  # el muro corta la dimension larga
			var long_d := h if horiz else w
			var short_d := w if horiz else h
			var line := clampi(long_d / 2 + rng.randi_range(-1, 1), 2, long_d - 3)
			var gaps: Array[int] = []
			if short_d >= 9:
				gaps.append(rng.randi_range(1, short_d / 2 - 2))
				gaps.append(rng.randi_range(short_d / 2 + 1, short_d - 3))
			else:
				gaps.append(rng.randi_range(1, short_d - 3))
			for s in short_d:
				var open := false
				for g in gaps:
					if s == g or s == g + 1:
						open = true
				if open:
					continue
				var cx: int = line if not horiz else s
				var cy: int = s if not horiz else line
				cells[_idx(cx, cy, w)] = LOW
			fill = LOW
		"island":
			var pw := clampi(int(float(w) * 0.3), 2, w - 4)
			var ph := clampi(int(float(h) * 0.3), 2, h - 4)
			pw += (w - pw) % 2
			ph += (h - ph) % 2
			_fill_rect(cells, w, h, (w - pw) / 2, (h - ph) / 2, pw, ph, hole)
			fill = hole
		"island_pair":
			var pw := clampi(int(float(w) * 0.2), 2, 4)
			var ph := clampi(int(float(h) * 0.45), 2, h - 4)
			var y0 := (h - ph) / 2
			var x0 := clampi(int(float(w) * 0.2), 1, (w - 3) / 2 - pw + 1)
			_fill_rect(cells, w, h, x0, y0, pw, ph, hole)
			_fill_rect(cells, w, h, w - x0 - pw, y0, pw, ph, hole)
			fill = hole
		"ring":
			var pw := clampi(int(float(w) * 0.34), 3, w - 4)
			var ph := clampi(int(float(h) * 0.34), 2, h - 4)
			pw += (w - pw) % 2
			ph += (h - ph) % 2
			_fill_rect(cells, w, h, (w - pw) / 2, (h - ph) / 2, pw, ph, WALL)
	return {"cells": cells, "fill": fill}


# ------------------------------------------------------------------ garantias
## Celdas (2 de ancho x 2 de fondo) que ocupa la entrada de una puerta. La primera fila (la del
## muro) es la que toca el borde; el jugador aparece 96 px dentro, en la segunda.
static func door_cells(door: Door, w: int, h: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var p := door.position
	var d: int = door.direction
	var axis := p.x if d < 2 else p.y
	var a0 := int(floor((axis - 31.0) / TILE))
	var a1 := int(floor((axis + 31.0) / TILE))
	for a in range(a0, a1 + 1):
		for depth in 2:
			var c := Vector2i.ZERO
			match d:
				0: c = Vector2i(a, depth)
				1: c = Vector2i(a, h - 1 - depth)
				2: c = Vector2i(depth, a)
				_: c = Vector2i(w - 1 - depth, a)
			if c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
				out.append(c)
	return out


static func _anchor(cells: PackedByteArray, w: int, h: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	var c := Vector2(float(w) * 0.5, float(h) * 0.5)
	for x in w:
		for y in h:
			if cells[_idx(x, y, w)] != FLOOR:
				continue
			var dd := (Vector2(x + 0.5, y + 0.5) - c).length_squared()
			if dd < best_d:
				best_d = dd
				best = Vector2i(x, y)
	return best


static func _flood(cells: PackedByteArray, w: int, h: int, from: Vector2i) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(w * h)
	if from.x < 0 or cells[_idx(from.x, from.y, w)] != FLOOR:
		return seen
	var stack: Array[Vector2i] = [from]
	seen[_idx(from.x, from.y, w)] = 1
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			var i := _idx(n.x, n.y, w)
			if cells[i] == FLOOR and seen[i] == 0:
				seen[i] = 1
				stack.append(n)
	return seen


## Abre las entradas, conecta cada puerta con el ancla, rellena lo aislado y comprueba la forma.
static func _finalize(room: Room, w: int, h: int, cells: PackedByteArray, fill: int, arena: bool) -> bool:
	var entries: Array[Vector2i] = []
	for door: Door in room.doors.values():
		var dc := door_cells(door, w, h)
		for c in dc:
			cells[_idx(c.x, c.y, w)] = FLOOR
		if not dc.is_empty():
			entries.append(dc[dc.size() - 1])
	var anchor := _anchor(cells, w, h)
	if anchor.x < 0:
		return false
	var seen := _flood(cells, w, h, anchor)
	for e in entries:
		if seen[_idx(e.x, e.y, w)] == 1:
			continue
		# camino mas corto (a traves de lo que sea) hasta la region conectada: se abre a suelo
		var prev := {e: e}
		var queue: Array[Vector2i] = [e]
		var hit := Vector2i(-1, -1)
		while not queue.is_empty() and hit.x < 0:
			var c: Vector2i = queue.pop_front()
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dv
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or prev.has(n):
					continue
				prev[n] = c
				if seen[_idx(n.x, n.y, w)] == 1:
					hit = n
					break
				queue.append(n)
		if hit.x < 0:
			return false
		var step: Vector2i = prev[hit]
		while step != e:
			cells[_idx(step.x, step.y, w)] = FLOOR
			step = prev[step]
		cells[_idx(e.x, e.y, w)] = FLOOR
		seen = _flood(cells, w, h, anchor)
	# lo pisable que no se alcanza se rellena
	var floor_n := 0
	for i in w * h:
		if cells[i] == FLOOR:
			if seen[i] == 0:
				cells[i] = fill
			else:
				floor_n += 1
	if float(floor_n) / float(w * h) < (MIN_RATIO_ARENA if arena else MIN_RATIO):
		return false
	# los cuatro lados del rectangulo conservan suelo (get_used_rect no cambia)
	var top := false
	var bottom := false
	var left := false
	var right := false
	for x in w:
		top = top or cells[_idx(x, 0, w)] == FLOOR
		bottom = bottom or cells[_idx(x, h - 1, w)] == FLOOR
	for y in h:
		left = left or cells[_idx(0, y, w)] == FLOOR
		right = right or cells[_idx(w - 1, y, w)] == FLOOR
	return top and bottom and left and right


# ------------------------------------------------------------------ construccion visual y fisica
static func _build(room: Room, w: int, h: int, cells: PackedByteArray, floor_n: int) -> void:
	var walls_map := room.get_node_or_null("Walls") as TileMap
	var themed := walls_map != null and walls_map.tile_set != null and walls_map.tile_set.resource_path.contains("walls_")
	if walls_map != null and walls_map.tile_set != null:
		for x in w:
			for y in h:
				var k := cells[_idx(x, y, w)]
				if k != WALL and k != LOW:
					continue
				var below := y + 1 < h and cells[_idx(x, y + 1, w)] in [FLOOR, PIT, WATER]
				var front := k == LOW or below
				var coords := Vector2i.ZERO
				if themed:
					var v := hash(Vector3i(room.grid_pos.x * 131 + x, room.grid_pos.y * 137 + y, floor_n)) & 1
					coords = Vector2i((1 if front else 0) + v * 2, 0)
				walls_map.set_cell(0, Vector2i(x, y), WALL_SOURCE, coords)
	# huecos: cuerpo fisico por tramos horizontales (capa 1, como los muros)
	var body := StaticBody2D.new()
	body.name = "ShapeBlockers"
	body.collision_layer = 64  # capa 7 "huecos": bloquea cuerpos, no proyectiles
	body.collision_mask = 0
	var any_hole := false
	for y in h:
		var x := 0
		while x < w:
			var k := cells[_idx(x, y, w)]
			if k != PIT and k != WATER:
				x += 1
				continue
			var x1 := x
			while x1 + 1 < w and cells[_idx(x1 + 1, y, w)] in [PIT, WATER]:
				x1 += 1
			var cs := CollisionShape2D.new()
			var rs := RectangleShape2D.new()
			rs.size = Vector2((x1 - x + 1) * TILE, TILE)
			cs.shape = rs
			cs.position = Vector2((x + x1 + 1) * 0.5 * TILE, (y + 0.5) * TILE)
			body.add_child(cs)
			any_hole = true
			x = x1 + 1
	var fx := ShapeFx.new()
	fx.name = "ShapeFx"
	fx.w = w
	fx.h = h
	fx.cells = cells
	fx.kingdom = FloorTiles.kingdom_for_floor(floor_n)
	room.add_child(fx)
	var floor_map := room.get_node_or_null("Floor")
	if floor_map != null:
		room.move_child(fx, floor_map.get_index() + 1)
	if any_hole:
		room.add_child(body)
	else:
		body.free()
	Censor.apply(room, fx)


## Dibujo de huecos (abismo/agua) y sombras de contacto junto a los muros interiores.
class ShapeFx extends Node2D:
	var w := 0
	var h := 0
	var cells := PackedByteArray()
	var kingdom := "neutral"
	var _t := 0.0
	var _has_water := false

	func _ready() -> void:
		for c in cells:
			if c == RoomShapes.WATER:
				_has_water = true
		queue_redraw()

	func _process(delta: float) -> void:
		if not _has_water:
			set_process(false)
			return
		_t += delta
		if int(_t * 8.0) != int((_t - delta) * 8.0):
			queue_redraw()

	func _k(x: int, y: int) -> int:
		if x < 0 or y < 0 or x >= w or y >= h:
			return RoomShapes.WALL
		return cells[y * w + x]

	func _draw() -> void:
		var T := float(RoomShapes.TILE)
		var water_col := {"neutral": Color(0.16, 0.34, 0.3), "pene": Color(0.14, 0.32, 0.44), "vulva": Color(0.52, 0.2, 0.36), "mixto": Color(0.2, 0.3, 0.36)}.get(kingdom, Color(0.15, 0.3, 0.4)) as Color
		for y in h:
			for x in w:
				var k := cells[y * w + x]
				var r := Rect2(Vector2(x, y) * T, Vector2(T, T))
				if k == RoomShapes.PIT:
					draw_rect(r, Color(0.035, 0.025, 0.045))
					# pared del fondo que se ve al norte del hueco
					if _k(x, y - 1) != RoomShapes.PIT and _k(x, y - 1) != RoomShapes.WATER:
						draw_rect(Rect2(r.position, Vector2(T, 26.0)), Color(0.16, 0.13, 0.15))
						draw_rect(Rect2(r.position + Vector2(0, 26.0), Vector2(T, 10.0)), Color(0.08, 0.06, 0.08))
					_rim(x, y, r, Color(0.5, 0.46, 0.42, 0.9))
				elif k == RoomShapes.WATER:
					draw_rect(r, water_col.darkened(0.25))
					draw_rect(r.grow(-3.0), water_col)
					for i in 2:
						var ph := _t * 2.2 + float(x * 3 + y * 5 + i * 7)
						var yy := r.position.y + 16.0 + float(i) * 28.0 + sin(ph) * 3.0
						var x0 := r.position.x + 8.0 + fmod(float(x * 13 + y * 7 + i * 19), 18.0)
						draw_line(Vector2(x0, yy), Vector2(x0 + 22.0, yy), water_col.lightened(0.45), 2.0)
					_rim(x, y, r, water_col.lightened(0.55) * Color(1, 1, 1, 0.9))
				elif k == RoomShapes.FLOOR:
					_contact_shadow(x, y, r)

	## Borde claro del lado donde el hueco toca suelo o muro.
	func _rim(x: int, y: int, r: Rect2, col: Color) -> void:
		for d in [[Vector2i(0, 1), Rect2(0, 60, 64, 4)], [Vector2i(-1, 0), Rect2(0, 0, 4, 64)], [Vector2i(1, 0), Rect2(60, 0, 4, 64)]]:
			var n: Vector2i = d[0]
			var kk := _k(x + n.x, y + n.y)
			if kk != RoomShapes.PIT and kk != RoomShapes.WATER:
				var b: Rect2 = d[1]
				draw_rect(Rect2(r.position + b.position, b.size), col)

	## Sombra de contacto del suelo junto a un muro interior (la del borde exterior ya la pone RoomLighting).
	func _contact_shadow(x: int, y: int, r: Rect2) -> void:
		var solid := [RoomShapes.WALL, RoomShapes.LOW]
		if y > 0 and cells[(y - 1) * w + x] in solid:
			for i in 4:
				draw_rect(Rect2(r.position + Vector2(0, i * 5), Vector2(64, 5)), Color(0, 0, 0, 0.32 - 0.07 * i))
		if y + 1 < h and cells[(y + 1) * w + x] in solid:
			draw_rect(Rect2(r.position + Vector2(0, 58), Vector2(64, 6)), Color(0, 0, 0, 0.14))
		if x > 0 and cells[y * w + x - 1] in solid:
			draw_rect(Rect2(r.position, Vector2(8, 64)), Color(0, 0, 0, 0.22))
		if x + 1 < w and cells[y * w + x + 1] in solid:
			draw_rect(Rect2(r.position + Vector2(56, 0), Vector2(8, 64)), Color(0, 0, 0, 0.22))
