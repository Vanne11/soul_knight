extends Node2D
class_name Room

## Procedural room with doors, spawn points, and room type logic

enum RoomType { COMBAT = 0, SHOP = 1, LORE = 2, TRAP = 3, PUZZLE = 4, SECRET = 5, BOSS = 6, INTOXICATION = 7, MINIBOSS = 8, START = 9, TREASURE = 10, REST = 11,
	## Sala de situacion de Las Tierras del Silencio (src/silencio/): sin enemigos ni recompensas.
	SILENCIO = 12,
	## Pasillo de transicion entre reinos (src/dungeon/corridor.gd): sin enemigos ni recompensas.
	CORRIDOR = 13 }

enum DoorState { CLOSED = 0, OPEN = 1, LOCKED = 2, SEALED = 3 }

## Carga diferida a proposito: item_pickup.gd usa RoomUtil, que usa Room; con preload aqui el ciclo
## dejaba una PackedScene VACIA en quien la precargara primero (enemigos sin botin, "node count is 0").
const ITEM_PICKUP_PATH := "res://src/items/item_pickup.tscn"
var ITEM_PICKUP_SCENE: PackedScene:
	get:
		return load(ITEM_PICKUP_PATH)

## Recursos de enemigos (SpriteFrames, scripts de jefe) ya cargados. La cache de Godot es debil:
## al morir el ultimo bicho de un tipo sus frames se descargan y el siguiente spawn los relee del
## disco (20-40 ms de tiron al entrar a la sala). Aqui quedan vivos toda la partida.
static var _res_cache: Dictionary = {}


static func cached_load(path: String) -> Resource:
	if not _res_cache.has(path):
		_res_cache[path] = load(path)
	return _res_cache[path]


## Carga por adelantado (al generar el piso, tras la transicion) los recursos que usara la sala.
## reset: suelta lo del piso anterior (las hojas de los jefes pesan en la memoria de video).
static func warm(paths: Array, reset := false) -> void:
	if reset:
		_res_cache.clear()
	for p in paths:
		if not _res_cache.has(p) and ResourceLoader.exists(p):
			_res_cache[p] = load(p)

@export var room_type: RoomType = 0
@export var grid_pos: Vector2i = Vector2i.ZERO
@export var difficulty: int = 1
@export var required_intoxication_tier: int = 0

var doors: Dictionary = {}  # nombre del nodo -> Door (puede haber varias por pared)
var spawn_points: Array[Vector2] = []
var enemies_spawned: Array[Node] = []
var cleared: bool = false
var cleared_callback: Variant = null
## Lo que da al limpiarla (main.gd lo reparte y lo anuncia en las puertas):
## "bendicion" (de reward_kingdom), "monedas", "vida", "hormona" o "".
var reward: String = ""
var reward_kingdom: String = ""
## Sala en penumbra (la sortea RoomLighting al generar el piso).
var is_dark: bool = false
## Dinamica de sala con objetivo (src/rooms): mientras devuelva false la sala no se limpia
## (matar a todos no basta). Vacio = comportamiento de siempre.
var clear_gate: Callable = Callable()

## Forma del interior (src/dungeon/room_shapes.gd). Vacia = rectangulo completo pisable.
## Tipos de celda: 0 suelo, 1 muro, 2 abismo, 3 agua, 4 muro bajo (solo el 0 se pisa).
var shape_id: String = "rect"
var shape_size: Vector2i = Vector2i.ZERO
var shape_cells: PackedByteArray = PackedByteArray()
var shape_anchor: Vector2i = Vector2i(-1, -1)

@onready var floor_tilemap: TileMap = $Floor
@onready var walls_tilemap: TileMap = $Walls
@onready var doors_node: Node2D = $Doors
@onready var spawn_points_node: Node2D = $SpawnPoints
@onready var pickups_node: Node2D = $Pickups
@onready var props_node: Node2D = $Props

func _ready() -> void:
	_setup_doors()
	_setup_spawn_points()


## Red de seguridad: un enemigo apretado contra una esquina por otros (enjambres), o nacido en un punto de
## aparicion desfasado, puede acabar dentro del muro o fuera de la sala. Fuera nadie lo alcanza y la sala
## no se limpia nunca (las puertas siguen selladas). Cada medio segundo, el que quede fuera del suelo de
## la sala vuelve al suelo pisable mas cercano.
var _rescue_t := 0.0

func _physics_process(delta: float) -> void:
	_rescue_t -= delta
	if _rescue_t > 0.0 or enemies_spawned.is_empty():
		return
	_rescue_t = 0.5
	var used := floor_tilemap.get_used_rect()
	var rect := Rect2(Vector2(used.position) * 64.0, Vector2(used.size) * 64.0)
	for e in enemies_spawned:
		if not is_instance_valid(e) or e.is_queued_for_deletion() or not (e is CharacterBody2D) or not e.is_inside_tree():
			continue
		if e.get("current_health") != null and float(e.current_health) <= 0.0:
			continue
		var p: Vector2 = e.global_position - global_position
		# dentro del rectangulo pero metido en un muro macizo o fuera de las celdas (esquinas cortadas, 3 px
		# por encima del suelo): tampoco puede salir solo
		var kind := cell_kind(Vector2i(floori(p.x / 64.0), floori(p.y / 64.0)))
		if rect.grow(6.0).has_point(p) and kind != -1 and kind != 1:
			continue
		var back := Vector2(clampf(p.x, rect.position.x + 40.0, rect.end.x - 40.0), clampf(p.y, rect.position.y + 40.0, rect.end.y - 40.0))
		e.global_position = snap_global(global_position + back, 24.0)
		e.velocity = Vector2.ZERO
		print("[sala] enemigo fuera de %s %s en %s: vuelve a %s" % [RoomType.keys()[room_type], grid_pos, p, back])

# ------------------------------------------------------------------ forma de la sala (API de suelo pisable)
## Todo en coordenadas LOCALES de la sala (pixeles, baldosas de 64) salvo snap_global.
func set_shape(id: String, size: Vector2i, cells: PackedByteArray, anchor: Vector2i) -> void:
	shape_id = id
	shape_size = size
	shape_cells = cells
	shape_anchor = anchor


func _shape_dims() -> Vector2i:
	if shape_size != Vector2i.ZERO:
		return shape_size
	if floor_tilemap != null and floor_tilemap.is_inside_tree():
		return floor_tilemap.get_used_rect().size
	return Vector2i.ZERO


## Tipo de la celda (0 suelo, 1 muro, 2 abismo, 3 agua, 4 muro bajo); -1 fuera de la sala.
func cell_kind(c: Vector2i) -> int:
	var d := _shape_dims()
	if c.x < 0 or c.y < 0 or c.x >= d.x or c.y >= d.y:
		return -1
	if shape_cells.is_empty():
		return 0
	return shape_cells[c.y * d.x + c.x]


func is_cell_walkable(c: Vector2i) -> bool:
	return cell_kind(c) == 0


## true si el punto esta en suelo pisable; con `margin` tambien sus cuatro esquinas (un cuerpo de ese radio).
func is_walkable(pos: Vector2, margin := 0.0) -> bool:
	if margin <= 0.0:
		return is_cell_walkable(Vector2i(floori(pos.x / 64.0), floori(pos.y / 64.0)))
	for o in [Vector2(-margin, -margin), Vector2(margin, -margin), Vector2(-margin, margin), Vector2(margin, margin)]:
		var q: Vector2 = pos + o
		if not is_cell_walkable(Vector2i(floori(q.x / 64.0), floori(q.y / 64.0))):
			return false
	return true


## true si TODAS las celdas que toca el rectangulo (local, px) son suelo pisable.
func rect_walkable(r: Rect2) -> bool:
	var x0 := floori(r.position.x / 64.0)
	var y0 := floori(r.position.y / 64.0)
	var x1 := floori((r.end.x - 0.01) / 64.0)
	var y1 := floori((r.end.y - 0.01) / 64.0)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			if not is_cell_walkable(Vector2i(x, y)):
				return false
	return true


## Suelo pisable como rectangulos (local, px): tramos horizontales fusionados hacia abajo.
func walkable_rect_list() -> Array[Rect2]:
	var d := _shape_dims()
	var out: Array[Rect2] = []
	if d == Vector2i.ZERO:
		return out
	var open: Dictionary = {}  # "x0,x1" -> Rect2 en construccion (en celdas)
	for y in range(d.y + 1):
		var runs: Array[Vector2i] = []
		if y < d.y:
			var x := 0
			while x < d.x:
				if not is_cell_walkable(Vector2i(x, y)):
					x += 1
					continue
				var x1 := x
				while x1 + 1 < d.x and is_cell_walkable(Vector2i(x1 + 1, y)):
					x1 += 1
				runs.append(Vector2i(x, x1))
				x = x1 + 1
		var next_open: Dictionary = {}
		for run in runs:
			var key := "%d,%d" % [run.x, run.y]
			if open.has(key):
				var r: Rect2 = open[key]
				r.size.y += 1.0
				next_open[key] = r
				open.erase(key)
			else:
				next_open[key] = Rect2(float(run.x), float(y), float(run.y - run.x + 1), 1.0)
		for key in open:
			var r: Rect2 = open[key]
			out.append(Rect2(r.position * 64.0, r.size * 64.0))
		open = next_open
	return out


## El punto pisable mas cercano a `pos` (con `margin` de aire hasta lo no pisable). Si ya vale, el mismo.
func nearest_walkable(pos: Vector2, margin := 18.0) -> Vector2:
	if is_walkable(pos, margin):
		return pos
	var d := _shape_dims()
	if d == Vector2i.ZERO:
		return pos
	var m := minf(margin, 30.0)
	var best := pos
	var best_d := INF
	for x in d.x:
		for y in d.y:
			if not is_cell_walkable(Vector2i(x, y)):
				continue
			var cr := Rect2(Vector2(x, y) * 64.0, Vector2(64, 64)).grow(-m)
			var q := Vector2(clampf(pos.x, cr.position.x, cr.end.x), clampf(pos.y, cr.position.y, cr.end.y))
			var dd := q.distance_squared_to(pos)
			if dd < best_d:
				best_d = dd
				best = q
	return best


## Punto global dentro del rectangulo del suelo (a `margin` de los muros) y, si la sala tiene forma, en suelo pisable.
## Para lo que se genera con un desplazamiento (escoltas, hojas orbitando) y puede caer dentro de un muro.
func clamp_global(pos: Vector2, margin := 40.0) -> Vector2:
	var used := floor_tilemap.get_used_rect()
	var rect := Rect2(Vector2(used.position) * 64.0, Vector2(used.size) * 64.0)
	var p := pos - global_position
	p = Vector2(clampf(p.x, rect.position.x + margin, rect.end.x - margin), clampf(p.y, rect.position.y + margin, rect.end.y - margin))
	return snap_global(global_position + p, margin)


## Igual que nearest_walkable pero con posiciones globales.
func snap_global(pos: Vector2, margin := 18.0) -> Vector2:
	if shape_cells.is_empty():
		return pos  # rectangulo completo: nada que corregir
	return nearest_walkable(pos - global_position, margin) + global_position


func _setup_doors() -> void:
	# Rebuild the dict from the actual children so each door appears exactly once.
	doors.clear()
	for child in doors_node.get_children():
		if child is Door:
			doors[child.name] = child
			child.room = self
			if not child.state_changed.is_connected(_on_door_state_changed):
				child.state_changed.connect(_on_door_state_changed)

func _setup_spawn_points() -> void:
	for child in spawn_points_node.get_children():
		if child is Node2D:
			spawn_points.append(child.global_position)

func _on_door_state_changed(direction: String, state: int) -> void:
	if state == DoorState.OPEN and all_doors_open():
		room_cleared()

func all_doors_open() -> bool:
	for door in doors.values():
		if door.has_meta("hold_sealed"):
			continue  # puerta de salida del jefe (pasillos): no cuenta para limpiar la sala
		if door.state != DoorState.OPEN:
			return false
	return true

func seal_doors() -> void:
	for door in doors.values():
		# Doors start CLOSED, and sealing only the already-OPEN ones left every
		# door CLOSED for the whole fight, so clearing the room never opened them.
		# LOCKED is preserved: sealing it would silently drop its key requirement.
		if door.state == DoorState.CLOSED or door.state == DoorState.OPEN:
			door.set_state(DoorState.SEALED)

func unseal_doors() -> void:
	for door in doors.values():
		if door.state == DoorState.SEALED and not door.has_meta("hold_sealed"):
			door.set_state(DoorState.OPEN)

func _add_enemy_deferred(enemy: Node2D, pos: Vector2) -> void:
	# Rooms are entered from door._on_body_entered(), i.e. while the physics
	# server is flushing queries, and adding a CharacterBody2D there raises
	# "Can't change this state while flushing queries". The enemy is added one
	# frame later; global_position must be set after add_child because on a node
	# outside the tree it is interpreted as parent-local (that bug pushed every
	# enemy far outside the room, past its own detection range).
	add_child.call_deferred(enemy)
	enemy.set_deferred("global_position", pos)


## seal=false deja las puertas abiertas (main lo usa si vas desarmado: puedes huir).
## enemy_data[i].enemy_type = id de EnemyRegistry ("melee", "its"...; por defecto "melee").
## positions (opcional, globales, una por entrada): donde aparece cada una (oleadas y
## formaciones, src/combat/waves.gd); vacio = los puntos de aparicion de la sala, al azar.
func spawn_enemies(enemy_data: Array[Dictionary], seal := true, positions: Array = []) -> void:
	if enemy_data.is_empty() or (spawn_points.is_empty() and positions.is_empty()):
		return

	var use_pos := not positions.is_empty()
	var used_spots: Array[Vector2] = []
	for e in enemies_spawned:  # oleadas: tampoco encima de los que ya estan en la sala
		if is_instance_valid(e) and e is Node2D and e.is_inside_tree() and float(e.get("current_health")) > 0.0:
			used_spots.append((e as Node2D).global_position)
	if not use_pos:
		RNG.shuffle(spawn_points)  # Array.shuffle() usa el azar global: misma semilla, mazmorra distinta

	for i in range(mini(enemy_data.size(), positions.size() if use_pos else spawn_points.size())):
		var data = enemy_data[i]
		var scene: PackedScene = EnemyRegistry.scene(str(data.get("enemy_type", EnemyRegistry.FALLBACK)))

		for g in range(int(data.get("group", 1))):
			var enemy = scene.instantiate()
			
			if data.has("script") and ResourceLoader.exists(data.script):
				enemy.set_script(cached_load(data.script))  # jefes: cada uno con sus ataques
			if data.has("name"): enemy.enemy_name = data.name
			if data.has("health"): enemy.max_health = data.health
			if data.has("damage"): enemy.damage = data.damage
			if data.has("speed"): enemy.move_speed = data.speed
			if data.get("enemy_type", "") != "boss": enemy.move_speed *= Censura.mult("enemy_speed")  # Censura: enemigos mas rapidos
			if data.has("its") and "its_kind" in enemy: enemy.its_kind = data.its
			if data.has("personality") and "personality" in enemy: enemy.personality = data.personality  # El Utero (lutea): irritables
			if data.has("drops"): enemy.drop_table = _as_drop_list(data.drops if g == 0 else [])
			if data.has("frames") and ResourceLoader.exists(data.frames):
				enemy.get_node("AnimatedSprite2D").sprite_frames = cached_load(data.frames)
			if data.has("scale"):
				enemy.get_node("AnimatedSprite2D").scale *= data.scale
			if data.get("elite", false):
				enemy.add_child(EliteAura.new())  # reforzado: aura roja bajo los pies
			Affixes.attach(enemy, data.get("affixes", []))  # afijos de elite (src/enemies/affixes)
			
			enemies_spawned.append(enemy)
			var at := _free_spawn_spot(snap_global((positions[i] if use_pos else spawn_points[i]) + Vector2(g * 28, (g % 2) * 24), 22.0), used_spots)
			used_spots.append(at)
			_add_enemy_deferred(enemy, at)
	
	if enemies_spawned.size() > 0 and seal:
		seal_doors()

const SPAWN_GAP := 34.0


## Punto de aparicion libre: si otro enemigo ya nacio ahi (varios puntos caian en el mismo borde de
## suelo al ajustarlos a una sala con forma) busca en anillos crecientes un sitio pisable a SPAWN_GAP.
## Dos cuerpos que nacen encimados se separan a patadas de fisica y salen disparados a traves de los muros.
func _free_spawn_spot(at: Vector2, used: Array[Vector2]) -> Vector2:
	if not _spot_taken(at, used):
		return at
	for ring in range(1, 9):
		var r := SPAWN_GAP * ring
		for k in 8 * ring:
			var cand := snap_global(at + Vector2.from_angle(TAU * k / (8.0 * ring)) * r, 22.0)
			if not _spot_taken(cand, used):
				return cand
	return at


func _spot_taken(at: Vector2, used: Array[Vector2]) -> bool:
	for u in used:
		if u.distance_to(at) < SPAWN_GAP:
			return true
	return false


## Walks up the tree to the owning Room, so spawned nodes end up inside the
## room they belong to instead of relying on get_tree().current_scene.
func find_owning_room() -> Room:
	var node: Node = get_parent()
	while node != null:
		if node is Room:
			return node
		node = node.get_parent()
	return null

## Contenedores de esta sala (antes buscaban la sala "padre" empezando por el
## padre de la propia sala, nunca se encontraban y todo acababa en Main/root).
func get_drop_container() -> Node:
	return pickups_node

func get_spawn_container() -> Node:
	return props_node

func _as_drop_list(raw) -> Array[Dictionary]:
	# Enemy.drop_table is Array[Dictionary]; the incoming literal from
	# main.gd is an untyped Array, which cannot be assigned directly.
	var out: Array[Dictionary] = []
	if raw is Array:
		for entry in raw:
			if entry is Dictionary:
				out.append(entry)
	return out

func room_cleared() -> void:
	if cleared:
		return
	# Oleadas pendientes (src/combat/waves.gd): la sala no se da por limpia hasta la ultima.
	var waves: Variant = get_meta("waves") if has_meta("waves") else null
	if waves != null and is_instance_valid(waves) and waves.hold_clear():
		return
	# Objetivo de sala abierto (src/rooms/, director de dinamicas): matar a todos no basta.
	if clear_gate.is_valid() and not clear_gate.call():
		return
	cleared = true
	unseal_doors()
	
	for enemy in enemies_spawned:
		if enemy and is_instance_valid(enemy):
			enemy.queue_free()
	enemies_spawned.clear()
	
	_spawn_rewards()
	
	if cleared_callback:
		cleared_callback.call()

func _add_pickup_deferred(pickup: Node) -> void:
	# Spawning an Area2D while the physics server is flushing queries (the room
	# clears from a door body_entered callback) throws "Can't change this state
	# while flushing queries", so the actual add_child waits one frame.
	if pickup is Node2D:
		pickup.position = RoomUtil.loot_spot(self, pickup.position)  # siempre en suelo pisable
	pickups_node.add_child.call_deferred(pickup)


func _spawn_rewards() -> void:
	var reward_pos = get_center_position()
	
	# Sin vida gratis al limpiar: la recompensa de cada sala la anuncia su puerta (main.gd).
	# Chance for whiskey (intoxication item)
	if RNG.randf() < 0.4:
		var pickup2 = ITEM_PICKUP_SCENE.instantiate()
		pickup2.item_id = "whiskey"
		pickup2.position = reward_pos + Vector2(40, 0)
		_add_pickup_deferred(pickup2)
	
	# Room-type specific rewards
	match room_type:
		RoomType.SHOP:
			_spawn_shop_items(reward_pos)
		RoomType.SECRET:
			_spawn_secret_rewards(reward_pos)
		RoomType.BOSS:
			_spawn_boss_rewards(reward_pos)
		RoomType.INTOXICATION:
			_spawn_intoxication_rewards(reward_pos)

func _spawn_shop_items(pos: Vector2) -> void:
	# TODO: spawn shopkeeper, items for sale
	pass

func _spawn_secret_rewards(pos: Vector2) -> void:
	if RNG.randf() < 0.5:
		var pickup = ITEM_PICKUP_SCENE.instantiate()
		pickup.item_id = RNG.weighted_pick({"health_large": 0.5, "pistol_basic": 0.3, "relic_liver": 0.2})
		pickup.position = pos + Vector2(RNG.randf_range(-50, 50), RNG.randf_range(-50, 50))
		_add_pickup_deferred(pickup)

func _spawn_boss_rewards(pos: Vector2) -> void:
	# Guaranteed good loot
	var pickup = ITEM_PICKUP_SCENE.instantiate()
	pickup.item_id = "health_large"
	pickup.position = pos + Vector2(-60, 0)
	_add_pickup_deferred(pickup)
	
	var pickup2 = ITEM_PICKUP_SCENE.instantiate()
	pickup2.item_id = RNG.weighted_pick({"pistol_basic": 0.4, "relic_liver": 0.3, "whiskey": 0.3})
	pickup2.position = pos + Vector2(60, 0)
	_add_pickup_deferred(pickup2)
	
	# Boss always drops a key item
	if RNG.randf() < 0.7:
		var pickup3 = ITEM_PICKUP_SCENE.instantiate()
		pickup3.item_id = "key_drunk"
		pickup3.position = pos + Vector2(0, -60)
		_add_pickup_deferred(pickup3)

func _spawn_intoxication_rewards(pos: Vector2) -> void:
	var pickup = ITEM_PICKUP_SCENE.instantiate()
	pickup.item_id = "whiskey"
	pickup.position = pos + Vector2(-30, 0)
	_add_pickup_deferred(pickup)
	
	if RNG.randf() < 0.5:
		var pickup2 = ITEM_PICKUP_SCENE.instantiate()
		pickup2.item_id = "health_small"
		pickup2.position = pos + Vector2(30, 0)
		_add_pickup_deferred(pickup2)

## La puerta de esta sala que lleva a la sala en from_pos (o null).
func door_to(from_pos: Vector2i) -> Door:
	for door in doors.values():
		if door.target_pos == from_pos:
			return door
	return null

func get_center_position() -> Vector2:
	# Derive the centre from the painted floor so it matches the room the
	# generator actually built (rooms vary between 8x6 and 16x12 tiles).
	# A hardcoded 640x360 placed the player outside of every smaller room.
	if floor_tilemap and floor_tilemap.tile_set:
		var rect := floor_tilemap.get_used_rect()
		if rect.size.x > 0 and rect.size.y > 0:
			var c := floor_tilemap.map_to_local(rect.get_center())
			if not shape_cells.is_empty() and not is_walkable(c, 20.0):
				c = nearest_walkable(c, 20.0)  # centro ocupado por un hueco o un pedestal
			return c
	return Vector2.ZERO

func can_enter(player_intoxication_tier: int) -> bool:
	return player_intoxication_tier >= required_intoxication_tier

func on_player_enter() -> void:
	# Override in specific room types
	pass

func on_player_exit() -> void:
	pass