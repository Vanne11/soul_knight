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
	var floors: Array = RM.FLOORS
	if floors.is_empty():
		return ""
	return String(floors[clampi(floor_num - 1, 0, floors.size() - 1)].get("kingdom", ""))


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
			var coords: Vector2i
			var n := y == 0
			var s := y == h - 1
			var o := x == 0
			var e := x == w - 1
			if (n or s) and (o or e):
				coords = Vector2i(4 + (0 if o else 1) if n else 4 + (3 if o else 2), 2)
			elif n or s or o or e:
				var dir := 0 if n else (1 if e else (2 if s else 3))
				var row := 3 if (ornate or rng.randf() < BORDER_B_CHANCE) else 2
				coords = Vector2i(dir, row)
			elif motif and x >= mx and x < mx + 3 and y >= my and y < my + 3:
				coords = Vector2i(5 + x - mx, 3 + y - my)
			elif (ornate or deep) and rng.randf() < (ORNATE_CHANCE if ornate else 0.08):
				coords = Vector2i(4 + rng.randi_range(0, 3), 1)
			else:
				var v := _pick_fill(rng, deep)
				coords = Vector2i(v % 8, v / 8)
			floor_map.set_cell(0, cell, 0, coords)
