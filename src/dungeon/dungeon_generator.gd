extends Node
class_name DungeonGenerator

## BSP-based procedural dungeon generator with lock-and-key progression

@export var min_room_size: Vector2i = Vector2i(8, 6)
@export var max_room_size: Vector2i = Vector2i(16, 12)
@export var room_padding: int = 2
@export var corridor_width: int = 2

const WALL_SOURCE := 4

var room_scene: PackedScene = preload("res://src/dungeon/room.tscn")
var door_scene: PackedScene = preload("res://src/dungeon/door.tscn")

var rooms: Dictionary = {}  # Vector2i -> Room
var room_sizes: Dictionary = {}  # Vector2i -> Vector2i (tile dimensions)
var room_graph: Dictionary = {}  # Vector2i -> Array[Vector2i]
var current_floor: int = 1
var seed: int = 0
## Camino mas corto inicio -> jefe (grid_pos) y salas opcionales de riesgo/premio (sala elite).
var main_path: Array = []
var elite_rooms: Array = []

## Salas por piso: de 7 + (piso-1)/3 a 9 + (piso-1)/3 (tope 12); la semilla elige dentro del rango.
const MIN_ROOMS := 7
const MAX_ROOMS := 12

func generate_floor(floor: int, seed_override: int = 0) -> Node2D:
	current_floor = floor
	seed = seed_override if seed_override != 0 else RNG.get_seed()
	RNG.randomize(seed)
	
	var dungeon_root = Node2D.new()
	dungeon_root.name = "Dungeon_Floor_%d" % floor
	
	_clear_state()
	
	# Trazado (7-12 salas segun piso y semilla): hojas del BSP elegidas + grafo con ramas y ciclos.
	var plan := _plan_layout()
	_create_rooms(plan.rects, dungeon_root)
	_connect_rooms(plan.edges)
	_layout_doors()
	_assign_room_types()
	_place_special_rooms()
	_assign_room_shapes()
	_paint_floor_tiles()
	
	return dungeon_root

func _clear_state() -> void:
	main_path = []
	elite_rooms = []
	rooms.clear()
	room_graph.clear()
	room_sizes.clear()

func _split_bsp(node: BSPNode, depth: int) -> void:
	if depth <= 0 or node.rect.size.x < min_room_size.x * 2 or node.rect.size.y < min_room_size.y * 2:
		return
	
	var split_horizontal = RNG.randf() < 0.5
	if node.rect.size.x > node.rect.size.y * 1.5:
		split_horizontal = false
	elif node.rect.size.y > node.rect.size.x * 1.5:
		split_horizontal = true
	# Solo se corta si caben dos salas minimas con su margen; si no, el rango del
	# corte salia invertido y nacian salas de 3 tiles de ancho.
	var can_h: bool = node.rect.size.y >= (min_room_size.y + room_padding * 2) * 2
	var can_v: bool = node.rect.size.x >= (min_room_size.x + room_padding * 2) * 2
	if split_horizontal and not can_h:
		split_horizontal = false
	elif not split_horizontal and not can_v:
		split_horizontal = true
	if (split_horizontal and not can_h) or (not split_horizontal and not can_v):
		return
	
	if split_horizontal:
		var split_y = RNG.randi_range(
			int(node.rect.position.y + min_room_size.y + room_padding * 2),
			int(node.rect.position.y + node.rect.size.y - min_room_size.y - room_padding * 2)
		)
		node.left = BSPNode.new(Rect2(node.rect.position.x, node.rect.position.y, node.rect.size.x, split_y - node.rect.position.y))
		node.right = BSPNode.new(Rect2(node.rect.position.x, split_y, node.rect.size.x, node.rect.position.y + node.rect.size.y - split_y))
	else:
		var split_x = RNG.randi_range(
			int(node.rect.position.x + min_room_size.x + room_padding * 2),
			int(node.rect.position.x + node.rect.size.x - min_room_size.x - room_padding * 2)
		)
		node.left = BSPNode.new(Rect2(node.rect.position.x, node.rect.position.y, split_x - node.rect.position.x, node.rect.size.y))
		node.right = BSPNode.new(Rect2(split_x, node.rect.position.y, node.rect.position.x + node.rect.size.x - split_x, node.rect.size.y))
	
	_split_bsp(node.left, depth - 1)
	_split_bsp(node.right, depth - 1)

func _collect_leaves(node: BSPNode, leaves: Array) -> void:
	if node.left == null and node.right == null:
		leaves.append(node)
	else:
		if node.left:
			_collect_leaves(node.left, leaves)
		if node.right:
			_collect_leaves(node.right, leaves)

func _create_rooms(rects: Array, parent: Node2D) -> void:
	for room_rect: Rect2 in rects:
		# Posicion en tiles: unica por sala (antes /8, y dos salas podian pisarse la clave).
		var grid_pos = Vector2i(room_rect.position)
		
		var room_instance = room_scene.instantiate()
		room_instance.grid_pos = grid_pos
		room_instance.global_position = room_rect.position * 64  # Tile size
		
		_setup_room_tilemap(room_instance, room_rect.size)
		
		rooms[grid_pos] = room_instance
		room_graph[grid_pos] = []
		room_sizes[grid_pos] = Vector2i(room_rect.size)
		parent.add_child(room_instance)

func _get_room_rect_in_leaf(leaf: BSPNode) -> Rect2:
	var avail_w = maxi(int(leaf.rect.size.x) - room_padding * 2, 1)
	var avail_h = maxi(int(leaf.rect.size.y) - room_padding * 2, 1)
	var max_w = mini(max_room_size.x, avail_w)
	var max_h = mini(max_room_size.y, avail_h)
	var w = RNG.randi_range(mini(min_room_size.x, max_w), max_w)
	var h = RNG.randi_range(mini(min_room_size.y, max_h), max_h)
	
	var min_x = int(leaf.rect.position.x) + room_padding
	var min_y = int(leaf.rect.position.y) + room_padding
	var x = RNG.randi_range(min_x, maxi(min_x, min_x + avail_w - w))
	var y = RNG.randi_range(min_y, maxi(min_y, min_y + avail_h - h))
	
	return Rect2(x, y, w, h)

func _setup_room_tilemap(room: Room, size: Vector2) -> void:
	# Rooms are instantiated outside the tree, so @onready has not run yet:
	# resolve the nodes by path and stop early if there is nothing to paint.
	var floor_map := room.get_node_or_null("Floor") as TileMap
	var walls_map := room.get_node_or_null("Walls") as TileMap
	if floor_map == null or walls_map == null:
		return
	if floor_map.tile_set == null or walls_map.tile_set == null:
		push_warning("Room %s has no TileSet assigned" % room.name)
		return
	
	var w := int(size.x)
	var h := int(size.y)
	
	for x in range(w):
		for y in range(h):
			floor_map.set_cell(0, Vector2i(x, y), RNG.randi_range(0, 3), Vector2i(0, 0))
	
	# TileSet de muros del reino del piso (si falta, el viejo con la baldosa unica).
	var themed := _apply_wall_tileset(walls_map)
	# Incluye las esquinas (-1 y w): sin ellas se veia el fondo por los cuatro rincones.
	# Con tema: la fila de arriba es la cara frontal (atlas 1/3) y el resto la tapa (0/2);
	# la variante sale de un hash de la celda (no consume el RNG de la generacion).
	for x in range(-1, w + 1):
		walls_map.set_cell(0, Vector2i(x, -1), WALL_SOURCE, _wall_atlas(room, x, -1, true, themed))
		walls_map.set_cell(0, Vector2i(x, h), WALL_SOURCE, _wall_atlas(room, x, h, false, themed))
	for y in range(h):
		walls_map.set_cell(0, Vector2i(-1, y), WALL_SOURCE, _wall_atlas(room, -1, y, false, themed))
		walls_map.set_cell(0, Vector2i(w, y), WALL_SOURCE, _wall_atlas(room, w, y, false, themed))

## Asigna assets/tilesets/walls_<reino>.tres al TileMap de muros. false si no existe.
func _apply_wall_tileset(walls_map: TileMap) -> bool:
	var floors: Array = RunManager.FLOORS
	var kingdom: String = floors[clampi(current_floor - 1, 0, floors.size() - 1)].kingdom
	var path := "res://assets/tilesets/walls_%s.tres" % kingdom
	if not ResourceLoader.exists(path):
		return false
	walls_map.tile_set = load(path)
	return true

func _wall_atlas(room: Room, x: int, y: int, front_face: bool, themed: bool) -> Vector2i:
	if not themed:
		return Vector2i(0, 0)
	var v := hash(Vector3i(room.grid_pos.x * 131 + x, room.grid_pos.y * 137 + y, current_floor)) & 1
	return Vector2i((1 if front_face else 0) + v * 2, 0)

## Forma del interior de cada sala (src/dungeon/room_shapes.gd). Va tras los tipos y los puntos de
## aparicion: no consume el RNG del trazado, y deja los puntos de aparicion en suelo pisable.
func _assign_room_shapes() -> void:
	for pos in rooms:
		var room: Room = rooms[pos]
		RoomShapes.assign(room, room_sizes[pos], current_floor, seed)
		for sp in room.get_node("SpawnPoints").get_children():
			if sp is Node2D:
				sp.position = room.nearest_walkable(sp.position, 24.0)

## Suelo propio del reino del piso. Va tras asignar los tipos de sala (el tipo cambia el ornamento).
func _paint_floor_tiles() -> void:
	for pos in rooms:
		FloorTiles.paint(rooms[pos], room_sizes[pos], current_floor, seed)
		# Toda sala nace gris (censurada) hasta que main la libera: el material va desde ya.
		for n in ["Floor", "Walls"]:
			var tm := rooms[pos].get_node_or_null(n) as CanvasItem
			if tm:
				Censor.apply(rooms[pos], tm)

func _connect_rooms(edges: Array) -> void:
	for e in edges:
		_create_corridor(e[0], e[1])
		room_graph[e[0]].append(e[1])
		room_graph[e[1]].append(e[0])

# ------------------------------------------------------------------ trazado
func target_room_count(floor_n: int) -> int:
	var lo := mini(MIN_ROOMS + (floor_n - 1) / 3, MAX_ROOMS)
	var hi := mini(9 + (floor_n - 1) / 3, MAX_ROOMS)
	if RunManager.floor_stage(floor_n) > 1:
		lo = maxi(lo, MIN_ROOMS + 1)  # la 2a etapa pide 4 combates: con 7 salas no salen
	return RNG.randi_range(lo, hi)

## Elige rects de sala y aristas. Devuelve {rects, edges}. Repite hasta que el grafo tenga
## ramas muertas de sobra (secretas + sala elite), jefe a >= 3 puertas y algun ciclo.
func _plan_layout() -> Dictionary:
	var target := target_room_count(current_floor)
	var best := {}
	var best_score := -1
	var fallback := []
	for attempt in 14:
		# 8 hojas (60x44, prof. 3) para 7-8 salas; 16 (64x48, prof. 4) para 9-12
		var big := target > 8
		var bsp_root = BSPNode.new(Rect2(0, 0, 64, 48) if big else Rect2(0, 0, 60, 44))
		_split_bsp(bsp_root, 4 if big else 3)
		var leaves := []
		_collect_leaves(bsp_root, leaves)
		if leaves.size() < target and attempt < 13:
			fallback = leaves if leaves.size() > fallback.size() else fallback
			continue
		if attempt == 13 and leaves.size() < target and fallback.size() > leaves.size():
			leaves = fallback
		# se descartan hojas al azar (la primera es el inicio y se queda)
		var keep: Array = leaves.slice(1)
		RNG.shuffle(keep)
		keep = keep.slice(0, maxi(target - 1, 0))
		var chosen := [leaves[0]] + keep
		var rects := []
		for leaf in chosen:
			rects.append(_get_room_rect_in_leaf(leaf))
		var pos: Array = rects.map(func(r): return Vector2i(r.position))
		var edges := _plan_edges(pos)
		var score := _layout_score(pos, edges)
		if score > best_score:
			best_score = score
			best = {"rects": rects, "edges": edges}
		if score >= 100:
			break
	return best

## Arbol de expansion minimo (ramas) + 1-3 aristas extra entre vecinas cercanas (ciclos).
func _plan_edges(pos: Array) -> Array:
	var edges := []
	var deg := {}
	for p in pos:
		deg[p] = 0
	for e in _minimum_spanning_tree(pos):
		edges.append([e.a, e.b])
		deg[e.a] += 1
		deg[e.b] += 1
	var extra := 1 + (1 if pos.size() >= 9 else 0) + (1 if RNG.randf() < 0.4 else 0)
	# pares sin arista, de cortos a largos; solo entre salas que ya tienen 2+ puertas (no mata ramas)
	var pairs := []
	for i in pos.size():
		for j in range(i + 1, pos.size()):
			var a: Vector2i = pos[i]
			var b: Vector2i = pos[j]
			if deg[a] < 2 or deg[b] < 2 or deg[a] >= 4 or deg[b] >= 4:
				continue
			if edges.any(func(e): return (e[0] == a and e[1] == b) or (e[0] == b and e[1] == a)):
				continue
			pairs.append({"a": a, "b": b, "dist": a.distance_to(b)})
	pairs.sort_custom(Callable(self, "_compare_edges"))
	var pool := pairs.slice(0, 6)
	RNG.shuffle(pool)
	for pr in pool:
		if extra <= 0:
			break
		if deg[pr.a] >= 4 or deg[pr.b] >= 4:
			continue
		edges.append([pr.a, pr.b])
		deg[pr.a] += 1
		deg[pr.b] += 1
		extra -= 1
	return edges

## 100+ = trazado bueno. Penaliza lo que rompe garantias (pocas ramas muertas, jefe cerca).
func _layout_score(pos: Array, edges: Array) -> int:
	var adj := {}
	for p in pos:
		adj[p] = []
	for e in edges:
		adj[e[0]].append(e[1])
		adj[e[1]].append(e[0])
	var start: Vector2i = pos[0]
	var dist := _bfs(adj, start)
	if dist.size() < pos.size():
		return 0
	var far := 0
	for p in pos:
		far = maxi(far, int(dist[p]))
	var dead := 0
	for p in pos:
		if p != start and adj[p].size() == 1 and int(dist[p]) < far:
			dead += 1  # (la mas lejana sera el jefe)
	var cycles: int = edges.size() - (pos.size() - 1)
	var score := 10
	if far >= 3:
		score += 30
	if dead >= 2:
		score += 40
	if dead >= 3 or pos.size() < 9:
		score += 10
	if cycles >= 1:
		score += 20
	return score

func _bfs(adj: Dictionary, start: Vector2i) -> Dictionary:
	var dist := {start: 0}
	var q := [start]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for n in adj[c]:
			if not dist.has(n):
				dist[n] = dist[c] + 1
				q.append(n)
	return dist

## Camino mas corto entre dos salas segun room_graph (incluye ambos extremos).
func path_between(a: Vector2i, b: Vector2i) -> Array:
	var prev := {a: a}
	var q := [a]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == b:
			break
		for n in room_graph[c]:
			if not prev.has(n):
				prev[n] = c
				q.append(n)
	if not prev.has(b):
		return []
	var out := [b]
	while out[0] != a:
		out.push_front(prev[out[0]])
	return out

func _minimum_spanning_tree(nodes: Array) -> Array:
	var edges = []
	for i in range(nodes.size()):
		for j in range(i + 1, nodes.size()):
			var dist = nodes[i].distance_to(nodes[j])
			edges.append({"a": nodes[i], "b": nodes[j], "dist": dist})
	
	edges.sort_custom(Callable(self, "_compare_edges"))
	
	var parent = {}
	for n in nodes:
		parent[n] = n
	
	var mst = []
	for edge in edges:
		var ra = _uf_find(parent, edge.a)
		var rb = _uf_find(parent, edge.b)
		if ra != rb:
			parent[ra] = rb
			mst.append(edge)
			if mst.size() == nodes.size() - 1:
				break
	
	return mst

func _uf_find(parent: Dictionary, n: Variant) -> Variant:
	var root = n
	while parent[root] != root:
		root = parent[root]
	while parent[n] != root:
		var next_n = parent[n]
		parent[n] = root
		n = next_n
	return root

func _compare_edges(a: Dictionary, b: Dictionary) -> bool:
	# sort_custom expects a bool comparator ("is a < b"), not an int (-1/0/1).
	return a.dist < b.dist

func _can_connect_direct(a: Vector2i, b: Vector2i) -> bool:
	# Only connect if roughly aligned horizontally or vertically (en tiles)
	return abs(a.x - b.x) < 24 or abs(a.y - b.y) < 24

func _create_corridor(a: Vector2i, b: Vector2i) -> void:
	var room_a = rooms[a]
	var room_b = rooms[b]
	if not room_a or not room_b:
		return
	
	var dir = _pick_direction(room_a, room_b, a, b)
	var door_a = _create_door(room_a, dir)
	var door_b = _create_door(room_b, _opposite_direction(dir))
	
	if door_a and door_b:
		door_a.room = room_a
		door_b.room = room_b
		# Cada puerta sabe a que sala lleva. Antes se adivinaba por direccion y,
		# con dos vecinos hacia el mismo lado, todas las puertas acababan en el
		# mismo sitio: el bucle infinito entre salas.
		door_a.target_pos = b
		door_b.target_pos = a

func _get_direction(from: Vector2i, to: Vector2i) -> int:
	var dx = to.x - from.x
	var dy = to.y - from.y
	
	if abs(dx) > abs(dy):
		return 2 if dx < 0 else 3  # LEFT or RIGHT
	else:
		return 0 if dy < 0 else 1  # UP or DOWN

## Lado principal; si alguna de las dos salas ya tiene puerta ahi, el otro eje.
## Si tambien esta ocupado, se comparte pared (_layout_doors las reparte).
func _pick_direction(room_a: Room, room_b: Room, a: Vector2i, b: Vector2i) -> int:
	var main_dir := _get_direction(a, b)
	var d := Vector2(b - a)
	var alt_dir: int
	if abs(d.x) > abs(d.y):
		alt_dir = 0 if d.y < 0 else 1
	else:
		alt_dir = 2 if d.x < 0 else 3
	for dir in [main_dir, alt_dir]:
		if not _has_door(room_a, dir) and not _has_door(room_b, _opposite_direction(dir)):
			return dir
	return main_dir

func _has_door(room: Room, dir: int) -> bool:
	for door in room.doors.values():
		if door.direction == dir:
			return true
	return false

## Reparte a lo largo de la pared las puertas que comparten lado.
func _layout_doors() -> void:
	for pos in rooms:
		var room: Room = rooms[pos]
		var size: Vector2i = room_sizes.get(pos, Vector2i(8, 6))
		for dir in 4:
			var same: Array = room.doors.values().filter(func(dd): return dd.direction == dir)
			for i in same.size():
				var t := float(i + 1) / float(same.size() + 1)
				match dir:
					0: same[i].position = Vector2(size.x * 64 * t, 0)
					1: same[i].position = Vector2(size.x * 64 * t, size.y * 64)
					2: same[i].position = Vector2(0, size.y * 64 * t)
					3: same[i].position = Vector2(size.x * 64, size.y * 64 * t)

func _opposite_direction(dir: int) -> int:
	return [1, 0, 3, 2][dir]

func _create_door(room: Room, dir: int) -> Door:
	var doors_node := room.get_node_or_null("Doors")
	if doors_node == null:
		return null
	
	var door_instance = door_scene.instantiate()
	door_instance.direction = dir
	
	door_instance.name = "Door%d" % doors_node.get_child_count()
	doors_node.add_child(door_instance)
	room.doors[door_instance.name] = door_instance
	door_instance.room = room
	# room.gd::_setup_doors() connects state_changed once the room enters the
	# tree, so do not connect it here as well.
	
	# Position door at room edge. Rooms live outside the tree while the
	# generator builds them, so read the size we recorded instead of the
	# @onready TileMap.
	var room_size: Vector2i = room_sizes.get(room.grid_pos, Vector2i(8, 6))
	match dir:
		0: door_instance.position = Vector2(room_size.x * 32, 0)  # UP
		1: door_instance.position = Vector2(room_size.x * 32, room_size.y * 64)  # DOWN
		2: door_instance.position = Vector2(0, room_size.y * 32)  # LEFT
		3: door_instance.position = Vector2(room_size.x * 64, room_size.y * 32)  # RIGHT
	
	return door_instance

func _assign_room_types() -> void:
	var room_list = rooms.values()
	if room_list.is_empty():
		return
	
	# Start room (first)
	var start_room = room_list[0]
	start_room.room_type = Room.RoomType.START
	start_room.cleared = true
	
	# Boss room: la mas lejana en puertas (desempata la distancia en el plano) entre las
	# grandes (en una sala de 8x6 el jefe no deja sitio para esquivar nada).
	var gdist := _graph_dist(start_room.grid_pos)
	var far := 0
	for v in gdist.values():
		far = maxi(far, int(v))
	# grande y a (casi) la maxima distancia en puertas; si no hay, la mas lejana de cualquier tamano
	var boss_room = _find_furthest_room(start_room.grid_pos, Vector2i(11, 8), gdist, maxi(far - 1, 2))
	if boss_room == null:
		boss_room = _find_furthest_room(start_room.grid_pos, Vector2i.ZERO, gdist)
	if boss_room:
		boss_room.room_type = Room.RoomType.BOSS
		boss_room.required_intoxication_tier = 0
		main_path = path_between(start_room.grid_pos, boss_room.grid_pos)
	
	# Miniboss room: a medio camino, sobre el camino al jefe (no en una rama).
	var miniboss_room: Room = null
	if main_path.size() >= 3:
		miniboss_room = rooms[main_path[main_path.size() / 2]]
	else:
		miniboss_room = _find_midway_room(start_room.grid_pos, boss_room.grid_pos if boss_room else Vector2i.ZERO)
	if miniboss_room and miniboss_room != start_room and miniboss_room != boss_room:
		miniboss_room.room_type = Room.RoomType.MINIBOSS
	
	# Secret rooms (1-2). Solo salas sin salida: van cerradas hasta resolver el
	# puzzle, y una sala de paso cerrada podria dejar al jefe inalcanzable.
	# 7-8 salas: a veces ninguna (cada secreta cuesta ademas la sala del puzzle); 9: una; 10+: 1-2.
	var secret_count := 1 if room_list.size() < 10 else RNG.randi_range(1, 2)
	if room_list.size() <= 8 and RNG.randf() < 0.4:
		secret_count = 0
	# Minimo de combates por piso (1a etapa 3, 2a etapa 4; antro/trampa/elite cuentan): las salas
	# opcionales (secreta + su puzzle, respiro) solo se crean si despues de la tienda sobran salas.
	var min_fights := 3 if RunManager.floor_stage(current_floor) == 1 else 4
	var spare := room_list.filter(func(r): return r.room_type == Room.RoomType.COMBAT).size() - 1 - min_fights
	secret_count = clampi(secret_count, 0, maxi(spare - 1, 0))  # k secretas cuestan k + 1 (el puzzle)
	var candidates = room_list.filter(func(r): return r.room_type == Room.RoomType.COMBAT and room_graph[r.grid_pos].size() == 1)
	RNG.shuffle(candidates)
	for i in range(min(secret_count, candidates.size())):
		candidates[i].room_type = Room.RoomType.SECRET
	
	# Sala elite (riesgo/premio, fuera del camino al jefe): todos los enemigos elite y botin
	# grande. Prefiere una rama muerta; si no queda, una sala fuera del camino principal.
	_assign_elite_rooms(room_list)
	
	# Tienda: una por piso, siempre (sin ella las monedas no sirven de nada).
	candidates = room_list.filter(func(r): return r.room_type == Room.RoomType.COMBAT and not r.has_meta("elite_room"))
	if candidates.is_empty():
		candidates = room_list.filter(func(r): return r.room_type in [Room.RoomType.SECRET, Room.RoomType.INTOXICATION])
	if candidates.size() > 0:
		candidates[0].room_type = Room.RoomType.SHOP
		candidates[0].required_intoxication_tier = 0
	
	# Con sala secreta hace falta un puzzle que la abra (main.gd la cierra si lo hay).
	if room_list.any(func(r): return r.room_type == Room.RoomType.SECRET):
		candidates = room_list.filter(func(r): return r.room_type == Room.RoomType.COMBAT and not r.has_meta("elite_room"))
		if candidates.size() > 0:
			candidates[0].room_type = Room.RoomType.PUZZLE
	
	# Respiro: UNA sala tranquila (tesoro, descanso o lore) si quedan combates de
	# sobra. Mas que eso era pasear: las recompensas ya estan en los combates.
	# Puzzle solo el de arriba: uno sin sala secreta que abrir seria una promesa vacia.
	candidates = room_list.filter(func(r): return r.room_type == Room.RoomType.COMBAT and not r.has_meta("elite_room"))
	RNG.shuffle(candidates)
	var calm := [Room.RoomType.TREASURE, Room.RoomType.REST, Room.RoomType.LORE]
	RNG.shuffle(calm)  # con 1-2 salas tranquilas por piso, que no salga siempre la misma
	var n_calm := 1 if candidates.size() >= 3 and candidates.size() + elite_rooms.size() - 1 >= min_fights else 0
	for i in n_calm:
		candidates[i].room_type = calm[i % calm.size()]
	# Del combate que queda: un antro (enemigos que sueltan alcohol) y alguna trampa.
	var fights := candidates.slice(n_calm)
	for i in fights.size():
		if i == 0:
			fights[i].room_type = Room.RoomType.INTOXICATION
			fights[i].required_intoxication_tier = RNG.randi_range(1, 2)
		elif RNG.randf() < 0.15:
			fights[i].room_type = Room.RoomType.TRAP

func _find_furthest_room(from_pos: Vector2i, min_size := Vector2i.ZERO, gdist := {}, min_gd := 0) -> Room:
	var max_dist = -1.0
	var furthest = null
	for pos in rooms:
		var size: Vector2i = room_sizes.get(pos, Vector2i.ZERO)
		if pos == from_pos or size.x < min_size.x or size.y < min_size.y or int(gdist.get(pos, 0)) < min_gd:
			continue
		var dist: float = pos.distance_to(from_pos) + float(gdist.get(pos, 0)) * 1000.0
		if dist > max_dist:
			max_dist = dist
			furthest = rooms[pos]
	return furthest

## Distancia en puertas desde una sala.
func _graph_dist(from_pos: Vector2i) -> Dictionary:
	return _bfs(room_graph, from_pos)

func _assign_elite_rooms(room_list: Array) -> void:
	var n := room_list.size()
	if n < 9 or RNG.randf() > 0.6 + 0.04 * current_floor:
		return
	var wanted := 2 if (n >= 11 and RNG.randf() < 0.4) else 1
	for k in wanted:
		var cands: Array = room_list.filter(func(r): return r.room_type == Room.RoomType.COMBAT and room_graph[r.grid_pos].size() == 1 and not r.has_meta("elite_room"))
		if cands.is_empty():
			cands = room_list.filter(func(r): return r.room_type == Room.RoomType.COMBAT and r.grid_pos not in main_path and not r.has_meta("elite_room"))
		if cands.is_empty():
			return
		var pick: Room = cands[RNG.randi_range(0, cands.size() - 1)]
		pick.set_meta("elite_room", true)
		pick.set_meta("no_waves", true)  # sin oleadas: son sus enemigos elite de siempre
		elite_rooms.append(pick.grid_pos)

func _find_midway_room(from_pos: Vector2i, to_pos: Vector2i) -> Room:
	var mid = (from_pos + to_pos) / 2
	var min_dist = INF
	var mid_room = null
	for pos in rooms:
		var dist = pos.distance_to(mid)
		if dist < min_dist:
			min_dist = dist
			mid_room = rooms[pos]
	return mid_room

func _place_special_rooms() -> void:
	# Add spawn points to combat rooms based on difficulty
	for pos in rooms:
		var room = rooms[pos]
		if room.room_type in [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP, Room.RoomType.PUZZLE]:
			_add_spawn_points(room)
		
		if room.room_type in [Room.RoomType.BOSS, Room.RoomType.MINIBOSS]:
			# Sin spawn points Room.spawn_enemies() no hace nada: el jefe nunca aparecia.
			var size: Vector2i = room_sizes.get(room.grid_pos, Vector2i(8, 6))
			for off in [Vector2(0, -64), Vector2(-96, 0), Vector2(96, 0)]:
				var spawn := Node2D.new()
				spawn.position = Vector2(size.x * 32, size.y * 32) + off
				room.get_node("SpawnPoints").add_child(spawn)
		
		if room.room_type == Room.RoomType.SECRET:
			# Secret rooms need special entry condition
			room.required_intoxication_tier = 2

func _add_spawn_points(room: Room) -> void:
	var count = RNG.randi_range(2, 4) + RunManager.depth_i(current_floor)
	# Rooms are still outside the tree here, so use the recorded tile size
	# instead of the @onready TileMap.
	var room_size: Vector2i = room_sizes.get(room.grid_pos, Vector2i(8, 6))
	
	var spawns_node := room.get_node_or_null("SpawnPoints")
	if spawns_node == null:
		return
	
	for i in range(count):
		var spawn = Node2D.new()
		spawn.position = Vector2(
			RNG.randf_range(100, maxi(room_size.x * 64 - 100, 101)),
			RNG.randf_range(100, maxi(room_size.y * 64 - 100, 101))
		)
		spawns_node.add_child(spawn)

class BSPNode:
	var rect: Rect2
	var left: BSPNode = null
	var right: BSPNode = null
	
	func _init(_rect: Rect2):
		rect = _rect