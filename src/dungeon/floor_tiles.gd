class_name FloorTiles
extends RefCounted

## Suelo propio por reino (tools/gen_floor_art.py): relleno con variantes, borde/esquinas
## pegados al muro, motivo central en salas grandes y mas ornamento en jefe/tienda/tesoro.
## Todo determinista y SIN tocar el RNG autoload: usa un RandomNumberGenerator local
## sembrado con hash(semilla, piso, grid_pos).
## Atlas (64x64 por baldosa): fila 0-1 relleno 0-11 (+ornamentado 4-7 en fila 1),
## fila 2 borde A (0-3 N,E,S,O) + esquinas (4-7 NO,NE,SE,SO), fila 3 borde B,
## motivo 3x3 en cols 5-7 filas 3-5.

const RM := preload("res://src/autoloads/run_manager.gd")

## Pesos de las 12 variantes de relleno: las limpias (0-4) mandan, las raras (10-11) casi no salen.
const FILL_WEIGHTS: Array[float] = [14.0, 14.0, 13.0, 12.0, 10.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0]
## 2a etapa de cada reino: suelo mas sucio/agrietado (mandan las variantes "raras" 5-11) y mas ornamento.
const DEEP_FILL_WEIGHTS: Array[float] = [4.0, 4.0, 5.0, 6.0, 6.0, 9.0, 10.0, 10.0, 9.0, 8.0, 7.0, 6.0]
const ORNATE_CHANCE := 0.22
const BORDER_B_CHANCE := 0.25
const MOTIF_MIN := Vector2i(11, 8)

static var _cache: Dictionary = {}


static func kingdom_for_floor(floor_num: int) -> String:
	if RM.FLOORS.is_empty():
		return ""
	return String(RM.floor_at(floor_num).get("kingdom", ""))


## TileSet del reino, o null si no existe (entonces la sala conserva el suelo antiguo).
static func tileset_for(kingdom: String) -> TileSet:
	if _cache.has(kingdom):
		return _cache[kingdom]
	var path := "res://assets/tilesets/floor_%s.tres" % kingdom
	var ts: TileSet = null
	if kingdom != "" and ResourceLoader.exists(path):
		ts = load(path) as TileSet
	_cache[kingdom] = ts
	return ts


static func _pick_fill(rng: RandomNumberGenerator, deep := false) -> int:
	var weights: Array[float] = DEEP_FILL_WEIGHTS if deep else FILL_WEIGHTS
	var total := 0.0
	for w in weights:
		total += w
	var r := rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return 0


static func paint(room: Room, size: Vector2i, floor_num: int, run_seed: int) -> void:
	var floor_map := room.get_node_or_null("Floor") as TileMap
	if floor_map == null:
		return
	var ts := tileset_for(kingdom_for_floor(floor_num))
	if ts == null:
		return  # reino sin arte propio: se queda el suelo de siempre
	var w := size.x
	var h := size.y
	if room.shape_size == Vector2i.ZERO:
		room.set_shape("rect", size, PackedByteArray(), Vector2i(w / 2, h / 2))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, floor_num, room.grid_pos])
	var deep: bool = RM.floor_stage(floor_num) > 1
	var ornate: bool = room.room_type in [Room.RoomType.BOSS, Room.RoomType.SHOP, Room.RoomType.TREASURE]
	var motif := ornate or (w >= MOTIF_MIN.x and h >= MOTIF_MIN.y)
	var mx := (w - 3) / 2
	var my := (h - 3) / 2
	floor_map.tile_set = ts
	floor_map.clear()
	for x in w:
		for y in h:
			var cell := Vector2i(x, y)
			var kind := room.cell_kind(cell)
			if kind != 0 and kind != RoomShapes.LOW:
				continue  # muro, abismo o agua: sin suelo (el muro bajo si lo lleva debajo)
			var coords: Vector2i
			# Borde pegado a lo que sea muro (el del contorno o un recorte/pedestal interior).
			var n := _is_wall(room, x, y - 1)
			var s := _is_wall(room, x, y + 1)
			var o := _is_wall(room, x - 1, y)
			var e := _is_wall(room, x + 1, y)
			if kind == RoomShapes.LOW:
				n = false
				s = false
				o = false
				e = false
			if (n or s) and (o or e):
				coords = Vector2i(4 + (0 if o else 1) if n else 4 + (3 if o else 2), 2)
			elif n or s or o or e:
				var dir := 0 if n else (1 if e else (2 if s else 3))
				var row := 3 if (ornate or rng.randf() < BORDER_B_CHANCE) else 2
				coords = Vector2i(dir, row)
			elif motif and x >= mx and x < mx + 3 and y >= my and y < my + 3 and _motif_ok(room, mx, my):
				coords = Vector2i(5 + x - mx, 3 + y - my)
			elif (ornate or deep) and rng.randf() < (ORNATE_CHANCE if ornate else 0.08):
				coords = Vector2i(4 + rng.randi_range(0, 3), 1)
			else:
				var v := _pick_fill(rng, deep)
				coords = Vector2i(v % 8, v / 8)
			floor_map.set_cell(0, cell, 0, coords)


## Muro (borde de la sala o celda de muro interior); abismo, agua y muro bajo no cuentan.
static func _is_wall(room: Room, x: int, y: int) -> bool:
	var k := room.cell_kind(Vector2i(x, y))
	return k == -1 or k == RoomShapes.WALL


## El motivo central de 3x3 solo se pinta si esas nueve celdas son suelo.
static func _motif_ok(room: Room, mx: int, my: int) -> bool:
	for x in range(mx, mx + 3):
		for y in range(my, my + 3):
			if room.cell_kind(Vector2i(x, y)) != 0:
				return false
	return true
