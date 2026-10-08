extends Node2D
class_name Room

## Procedural room with doors, spawn points, and room type logic

enum RoomType { COMBAT = 0, SHOP = 1, LORE = 2, TRAP = 3, PUZZLE = 4, SECRET = 5, BOSS = 6, INTOXICATION = 7, MINIBOSS = 8, START = 9 }

enum DoorState { CLOSED = 0, OPEN = 1, LOCKED = 2, SEALED = 3 }

const ITEM_PICKUP_SCENE := preload("res://src/items/item_pickup.tscn")

@export var room_type: RoomType = 0
@export var grid_pos: Vector2i = Vector2i.ZERO
@export var difficulty: int = 1
@export var required_intoxication_tier: int = 0

var doors: Dictionary = {}  # nombre del nodo -> Door (puede haber varias por pared)
var spawn_points: Array[Vector2] = []
var enemies_spawned: Array[Node] = []
var cleared: bool = false
var cleared_callback: Variant = null

@onready var floor_tilemap: TileMap = $Floor
@onready var walls_tilemap: TileMap = $Walls
@onready var doors_node: Node2D = $Doors
@onready var spawn_points_node: Node2D = $SpawnPoints
@onready var pickups_node: Node2D = $Pickups
@onready var props_node: Node2D = $Props

func _ready() -> void:
	_setup_doors()
	_setup_spawn_points()

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
		if door.state == DoorState.SEALED:
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


func spawn_enemies(enemy_scenes: Array[PackedScene], enemy_data: Array[Dictionary]) -> void:
	if spawn_points.is_empty() or enemy_scenes.is_empty() or enemy_data.is_empty():
		return
	
	RNG.shuffle(spawn_points)  # Array.shuffle() usa el azar global: misma semilla, mazmorra distinta
	
	for i in range(min(enemy_data.size(), spawn_points.size())):
		var data = enemy_data[i]
		var enemy_type = data.enemy_type if data.has("enemy_type") else 0
		
		# Select appropriate scene based on enemy_type
		var scene: PackedScene
		match enemy_type:
			0: scene = enemy_scenes[0]  # melee
			1: scene = enemy_scenes[1] if enemy_scenes.size() > 1 else enemy_scenes[0]  # ranged
			2: scene = enemy_scenes[2] if enemy_scenes.size() > 2 else enemy_scenes[0]  # swarmer
			3: scene = enemy_scenes[3] if enemy_scenes.size() > 3 else enemy_scenes[0]  # tank
			4: scene = enemy_scenes[4] if enemy_scenes.size() > 4 else enemy_scenes[0]  # boss
			_: scene = enemy_scenes[0]
		
		for g in range(int(data.get("group", 1))):
			var enemy = scene.instantiate()
			
			if data.has("name"): enemy.enemy_name = data.name
			if data.has("health"): enemy.max_health = data.health
			if data.has("damage"): enemy.damage = data.damage
			if data.has("speed"): enemy.move_speed = data.speed
			if data.has("drops"): enemy.drop_table = _as_drop_list(data.drops if g == 0 else [])
			if data.has("frames") and ResourceLoader.exists(data.frames):
				enemy.get_node("AnimatedSprite2D").sprite_frames = load(data.frames)
			if data.has("scale"):
				enemy.get_node("AnimatedSprite2D").scale *= data.scale
			
			enemies_spawned.append(enemy)
			_add_enemy_deferred(enemy, spawn_points[i] + Vector2(g * 28, (g % 2) * 24))
	
	if enemies_spawned.size() > 0:
		seal_doors()

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
	pickups_node.add_child.call_deferred(pickup)


func _spawn_rewards() -> void:
	var reward_pos = get_center_position()
	
	# Always spawn some health
	var pickup = ITEM_PICKUP_SCENE.instantiate()
	pickup.item_id = "health_small"
	pickup.position = reward_pos + Vector2(-40, 0)
	_add_pickup_deferred(pickup)
	
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
			return floor_tilemap.map_to_local(rect.get_center())
	return Vector2.ZERO

func can_enter(player_intoxication_tier: int) -> bool:
	return player_intoxication_tier >= required_intoxication_tier

func on_player_enter() -> void:
	# Override in specific room types
	pass

func on_player_exit() -> void:
	pass