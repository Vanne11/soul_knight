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

func generate_floor(floor: int, seed_override: int = 0) -> Node2D:
	current_floor = floor
	seed = seed_override if seed_override != 0 else RNG.get_seed()
	RNG.randomize(seed)
	
	var dungeon_root = Node2D.new()
	dungeon_root.name = "Dungeon_Floor_%d" % floor
	
	_clear_state()
	
	var bsp_root = BSPNode.new(Rect2(0, 0, 50, 35))
	_split_bsp(bsp_root, 4)
	
	var leaf_nodes = []
	_collect_leaves(bsp_root, leaf_nodes)
	
	_create_rooms(leaf_nodes, dungeon_root)
	_connect_rooms()
	_assign_room_types()
	_place_special_rooms()
	
	return dungeon_root

func _clear_state() -> void:
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
	
	if split_horizontal:
		var split_y = RNG.randi_range(
			int(node.rect.position.y + min_room_size.y + room_padding),
			int(node.rect.position.y + node.rect.size.y - min_room_size.y - room_padding)
		)
		node.left = BSPNode.new(Rect2(node.rect.position.x, node.rect.position.y, node.rect.size.x, split_y - node.rect.position.y))
		node.right = BSPNode.new(Rect2(node.rect.position.x, split_y, node.rect.size.x, node.rect.position.y + node.rect.size.y - split_y))
	else:
		var split_x = RNG.randi_range(
			int(node.rect.position.x + min_room_size.x + room_padding),
			int(node.rect.position.x + node.rect.size.x - min_room_size.x - room_padding)
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

func _create_rooms(leaves: Array, parent: Node2D) -> void:
	for leaf in leaves:
		var room_rect = _get_room_rect_in_leaf(leaf)
		var grid_pos = Vector2i(room_rect.position / 8)  # Rough grid pos
		
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
	
	for x in range(w):
		walls_map.set_cell(0, Vector2i(x, -1), WALL_SOURCE, Vector2i(0, 0))
		walls_map.set_cell(0, Vector2i(x, h), WALL_SOURCE, Vector2i(0, 0))
	for y in range(h):
		walls_map.set_cell(0, Vector2i(-1, y), WALL_SOURCE, Vector2i(0, 0))
		walls_map.set_cell(0, Vector2i(w, y), WALL_SOURCE, Vector2i(0, 0))

func _connect_rooms() -> void:
	var room_positions = rooms.keys()
	var mst_edges = _minimum_spanning_tree(room_positions)
	
	for edge in mst_edges:
		_create_corridor(edge.a, edge.b)
		room_graph[edge.a].append(edge.b)
		room_graph[edge.b].append(edge.a)
	
	# Add some extra connections for loops
	var extra_connections = RNG.randi_range(1, 3)
	for i in range(extra_connections):
		var a = room_positions[RNG.randi_range(0, room_positions.size() - 1)]
		var b = room_positions[RNG.randi_range(0, room_positions.size() - 1)]
		if a != b and b not in room_graph[a]:
			if _can_connect_direct(a, b):
				_create_corridor(a, b)
				room_graph[a].append(b)
				room_graph[b].append(a)

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
	# Only connect if roughly aligned horizontally or vertically
	return abs(a.x - b.x) < 3 or abs(a.y - b.y) < 3

func _create_corridor(a: Vector2i, b: Vector2i) -> void:
	var room_a = rooms[a]
	var room_b = rooms[b]
	if not room_a or not room_b:
		return
	
	var dir = _get_direction(a, b)
	var door_a = _create_door(room_a, dir)
	var door_b = _create_door(room_b, _opposite_direction(dir))
	
	if door_a and door_b:
		door_a.room = room_a
		door_b.room = room_b

func _get_direction(from: Vector2i, to: Vector2i) -> int:
	var dx = to.x - from.x
	var dy = to.y - from.y
	
	if abs(dx) > abs(dy):
		return 2 if dx < 0 else 3  # LEFT or RIGHT
	else:
		return 0 if dy < 0 else 1  # UP or DOWN

func _opposite_direction(dir: int) -> int:
	return [1, 0, 3, 2][dir]

func _create_door(room: Room, dir: int) -> Door:
	var doors_node := room.get_node_or_null("Doors")
	if doors_node == null:
		return null
	
	var door_instance = door_scene.instantiate()
	door_instance.direction = dir
	
	var dir_name = ["up", "down", "left", "right"][dir]
	doors_node.add_child(door_instance)
	room.doors[dir_name] = door_instance
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
	
	# Boss room: la mas lejana entre las grandes (en una sala de 8x6 el jefe no
	# deja sitio para esquivar nada).
	var boss_room = _find_furthest_room(start_room.grid_pos, Vector2i(11, 8))
	if boss_room == null:
		boss_room = _find_furthest_room(start_room.grid_pos)
	if boss_room:
		boss_room.room_type = Room.RoomType.BOSS
		boss_room.required_intoxication_tier = 0
	
	# Miniboss room (midway)
	var miniboss_room = _find_midway_room(start_room.grid_pos, boss_room.grid_pos if boss_room else Vector2i.ZERO)
	if miniboss_room and miniboss_room != start_room and miniboss_room != boss_room:
		miniboss_room.room_type = Room.RoomType.MINIBOSS
	
	# Intoxication-required room (1-2 per floor)
	var intox_count = RNG.randi_range(1, 2)
	var candidates = room_list.filter(func(r): return r.room_type == Room.RoomType.COMBAT)
	RNG.shuffle(candidates)
	for i in range(min(intox_count, candidates.size())):
		candidates[i].room_type = Room.RoomType.INTOXICATION
		candidates[i].required_intoxication_tier = RNG.randi_range(1, 2)
	
	# Secret rooms (1-2)
	var secret_count = RNG.randi_range(1, 2)
	candidates = room_list.filter(func(r): return r.room_type == Room.RoomType.COMBAT)
	RNG.shuffle(candidates)
	for i in range(min(secret_count, candidates.size())):
		candidates[i].room_type = Room.RoomType.SECRET
	
	# Shop (0-1)
	if RNG.randf() < 0.5:
		candidates = room_list.filter(func(r): return r.room_type == Room.RoomType.COMBAT)
		if candidates.size() > 0:
			candidates[0].room_type = Room.RoomType.SHOP
	
	# Trap/Puzzle (remaining combat rooms have chance)
	for room in room_list:
		if room.room_type == Room.RoomType.COMBAT:
			var r = RNG.randf()
			if r < 0.15:
				room.room_type = Room.RoomType.TRAP
			elif r < 0.25:
				room.room_type = Room.RoomType.PUZZLE
			elif r < 0.3:
				room.room_type = Room.RoomType.LORE

func _find_furthest_room(from_pos: Vector2i, min_size := Vector2i.ZERO) -> Room:
	var max_dist = -1
	var furthest = null
	for pos in rooms:
		var size: Vector2i = room_sizes.get(pos, Vector2i.ZERO)
		if pos == from_pos or size.x < min_size.x or size.y < min_size.y:
			continue
		var dist = pos.distance_to(from_pos)
		if dist > max_dist:
			max_dist = dist
			furthest = rooms[pos]
	return furthest

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
	var count = RNG.randi_range(2, 4) + current_floor
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