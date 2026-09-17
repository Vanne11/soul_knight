class_name RoomBuilder
extends RefCounted
## Pinta salas sobre dos TileMapLayer (suelo y muros).
##
## Un TileMapLayer dibuja miles de celdas con una sola llamada de render y
## genera la colision de los muros a partir del TileSet. Rellenarlo por codigo
## con set_cell() en vez de a mano en el editor es justo lo que necesita un
## roguelite: manana esto generara mazmorras enteras.
##
## RefCounted (no Node) porque esto es una utilidad, no algo que viva en el
## arbol de escena. Todo son funciones estaticas.

## Id de la fuente de tiles dentro del TileSet (nuestro unico atlas).
const SOURCE_ID: int = 0

## Coordenadas dentro del atlas assets/sprites/tiles.png.
const FLOOR_A := Vector2i(0, 0)
const FLOOR_B := Vector2i(1, 0)   # variante con grietas
const WALL_BODY := Vector2i(2, 0)
const WALL_TOP := Vector2i(3, 0)

## Probabilidad de usar la baldosa con grietas, para romper la repeticion.
const FLOOR_VARIANT_CHANCE: float = 0.12


## Dibuja una sala rectangular de `size` tiles con su anillo de muros.
## El interior ocupa de (0,0) a (size.x-1, size.y-1) en coordenadas de celda.
static func build_room(floor_layer: TileMapLayer, wall_layer: TileMapLayer, size: Vector2i) -> void:
	floor_layer.clear()
	wall_layer.clear()

	# Empezamos en y = -2 para que el muro superior tenga dos tiles de alto y
	# se lea como una pared con volumen, no como una linea.
	for y in range(-2, size.y + 1):
		for x in range(-1, size.x + 1):
			var cell := Vector2i(x, y)
			var inside := x >= 0 and x < size.x and y >= 0 and y < size.y
			if inside:
				var tile := FLOOR_B if randf() < FLOOR_VARIANT_CHANCE else FLOOR_A
				floor_layer.set_cell(cell, SOURCE_ID, tile)
			elif y == -2:
				wall_layer.set_cell(cell, SOURCE_ID, WALL_TOP)
			else:
				wall_layer.set_cell(cell, SOURCE_ID, WALL_BODY)


## Rectangulo del interior de la sala en pixeles (para limitar la camara).
static func interior_rect(size: Vector2i, tile_size: int) -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size) * float(tile_size))


## Centro de la sala en pixeles.
static func center(size: Vector2i, tile_size: int) -> Vector2:
	return Vector2(size) * float(tile_size) * 0.5


## Devuelve `count` posiciones de suelo aleatorias, a `min_tiles` celdas o mas
## de `away_from`, y separadas del borde para que nada aparezca dentro de un muro.
static func spawn_points(size: Vector2i, tile_size: int, count: int,
		away_from: Vector2, min_tiles: int) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var min_distance := float(min_tiles * tile_size)
	var attempts := 0

	while points.size() < count and attempts < count * 60:
		attempts += 1
		var cell := Vector2i(randi_range(1, size.x - 2), randi_range(1, size.y - 2))
		var world := (Vector2(cell) + Vector2(0.5, 0.9)) * float(tile_size)
		if world.distance_to(away_from) < min_distance:
			continue
		points.append(world)

	return points
