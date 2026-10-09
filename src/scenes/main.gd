extends Node2D

## Main gameplay scene - handles dungeon generation, room transitions, run flow

@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
@onready var floating_text_mgr: FloatingTextManager = $FloatingTextManager

var dungeon_root: Node2D = null
var current_room: Room = null
var rooms_cleared_this_floor: int = 0
var floor_completed: bool = false
## grid_pos -> true de las salas pisadas este piso (las pinta el minimapa).
var visited_rooms: Dictionary = {}
var _transition_lock: float = 0.0

func _process(delta: float) -> void:
	if _transition_lock > 0.0:
		_transition_lock -= delta

var dungeon_generator: DungeonGenerator
@onready var _game_controller: GameController = get_node("/root/GameController")
@onready var _global_events: GlobalEvents = get_node("/root/GlobalEvents")
@onready var _run_manager: RunManager = _game_controller.get_run_manager()

func _ready() -> void:
	add_to_group("main")
	dungeon_generator = DungeonGenerator.new()
	dungeon_generator.name = "DungeonGenerator"
	add_child(dungeon_generator)
	
	_setup_camera()
	_generate_dungeon()
	_game_controller.get_player_stats().emit_all_signals()
	_global_events.enemy_killed.connect(_on_enemy_killed)
	_global_events.player_died.connect(_on_player_died)
	_global_events.show_damage_number.connect(_on_show_damage_number)
	_global_events.show_floating_text.connect(_on_show_floating_text)

func _setup_camera() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1280
	camera.limit_bottom = 720

func _generate_dungeon() -> void:
	var seed = _run_manager.current_seed + _run_manager.current_floor * 7919  # cada piso su propio trazado
	dungeon_root = dungeon_generator.generate_floor(_run_manager.current_floor, seed)
	visited_rooms.clear()
	add_child(dungeon_root)
	_lock_secret_rooms()
	
	# Start player in start room
	var start_room = _find_start_room()
	if start_room and not _has_real_weapon():
		# Sin cuerpo a cuerpo: la primera arma espera en el suelo de la sala inicial.
		_spawn_pickup(start_room, "pistol_basic", start_room.get_center_position() + Vector2(0, -80))
	_pick_hormone_room()
	Narrator.say("floor_%d" % _run_manager.current_floor, {}, true)
	_show_floor_card()
	if start_room:
		_enter_room(start_room)
	else:
		# Fallback to first room
		var rooms = dungeon_generator.rooms.values()
		if rooms.size() > 0:
			_enter_room(rooms[0])

func _find_start_room() -> Room:
	for room in dungeon_generator.rooms.values():
		if room.room_type == Room.RoomType.START:
			return room
	return null

func _connect_room_doors(room: Room) -> void:
	# Opening a door used to emit player_interacted with no listener, so the
	# player could never leave the starting room.
	for door: Door in room.doors.values():
		var callback := _on_door_entered_room.bind(room, door)
		if not door.player_interacted.is_connected(callback):
			door.player_interacted.connect(callback)

func _on_door_entered_room(room: Room, door: Door) -> void:
	if room != current_room or floor_completed or _transition_lock > 0.0:
		return
	var next_room: Room = dungeon_generator.rooms.get(door.target_pos)
	if next_room == null:
		return
	if next_room.room_type == Room.RoomType.BOSS and not _has_real_weapon():
		# A un jefe no se entra a puñetazos: la puerta no deja pasar y el narrador se ensaña.
		_transition_lock = 1.5
		get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -40),
			"SIN ARMA NO PASAS", Color("ff7ac0"))
		Narrator.say("door_no_weapon", {}, true)
		return
	if next_room.room_type == Room.RoomType.BOSS and not _missing_hormones().is_empty():
		# Puerta Hormonal: solo pasa quien lleve la hormona del reino. Aunque le dé alergia.
		_transition_lock = 1.5
		get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -40),
			"PUERTA HORMONAL: falta %s" % ", ".join(_missing_hormones()), Color("ff7ac0"))
		Narrator.say("door_hormonal", {}, true)
		get_node("/root/LoreDatabase").custom_event("hormone_door")
		return
	_enter_room(next_room, next_room.door_to(room.grid_pos))

func _enter_room(room: Room, entry_door: Door = null) -> void:
	if current_room:
		current_room.on_player_exit()
		# Disable previous room
		current_room.set_process(false)
		current_room.set_physics_process(false)
		for child in current_room.get_children():
			child.set_process(false)
			child.set_physics_process(false)
	
	current_room = room
	visited_rooms[room.grid_pos] = true
	room.cleared_callback = _on_room_cleared.bind(room)
	room.on_player_enter()
	_connect_room_doors(room)
	
	# Enable current room
	room.set_process(true)
	room.set_physics_process(true)
	for child in room.get_children():
		child.set_process(true)
		child.set_physics_process(true)
	
	# Position player just inside the door they walked through, or at the room
	# centre when the room is entered for the first time.
	_place_player_in_room(room, entry_door)
	
	# Update camera limits to room bounds
	_update_camera_limits(room)
	
	_paint_room(room, room.cleared or room.room_type in [Room.RoomType.START, Room.RoomType.SHOP, Room.RoomType.SECRET, Room.RoomType.LORE])
	if room.room_type == Room.RoomType.SHOP:
		_build_shop(room)
	if room.room_type == Room.RoomType.PUZZLE and not room.cleared:
		_build_puzzle(room)
	if not room.cleared:
		_narrate_room(room)
	
	# Spawn enemies for this room
	_spawn_room_enemies(room)
	
	get_node("/root/RunManager").current_room_index = _get_room_index(room)
	print("Entered room: %s at %s" % [room.room_type, room.grid_pos])

func _narrate_room(room: Room) -> void:
	match room.room_type:
		Room.RoomType.BOSS: Narrator.say("room_boss", {}, true)
		Room.RoomType.SHOP: Narrator.say_first("room_shop")
		Room.RoomType.SECRET: Narrator.say("room_secret")
		Room.RoomType.INTOXICATION: Narrator.say("room_intoxication")
		Room.RoomType.LORE: Narrator.say("room_empty")
		Room.RoomType.PUZZLE: Narrator.say_first("puzzle_start")
		Room.RoomType.START: pass
		_: Narrator.say_first("room_combat")

func _place_player_in_room(room: Room, door: Door) -> void:
	var spawn := room.get_center_position()
	if door:
		var offset := Vector2(0, 96)
		match door.get_direction_name():
			"up": offset = Vector2(0, 96)
			"down": offset = Vector2(0, -96)
			"left": offset = Vector2(96, 0)
			"right": offset = Vector2(-96, 0)
		# door.position is relative to the room node.
		spawn = door.position + offset
	player.global_position = room.global_position + spawn
	player.velocity = Vector2.ZERO
	# Ignore the door we just came through for a moment so it cannot bounce the
	# player straight back.
	_transition_lock = 0.4

func _update_camera_limits(room: Room) -> void:
	var room_rect = room.floor_tilemap.get_used_rect()
	var world_pos = room.global_position
	camera.limit_left = world_pos.x
	camera.limit_top = world_pos.y
	camera.limit_right = world_pos.x + room_rect.size.x * 64
	camera.limit_bottom = world_pos.y + room_rect.size.y * 64

func _get_room_index(room: Room) -> int:
	var keys = dungeon_generator.rooms.keys()
	for i in range(keys.size()):
		var pos = keys[i]
		if dungeon_generator.rooms[pos] == room:
			return i
	return 0

const ENEMY_SCENES: Array[PackedScene] = [
	preload("res://src/enemies/enemy.tscn"),
	preload("res://src/enemies/enemy_ranged.tscn"),
	preload("res://src/enemies/enemy_swarmer.tscn"),
	preload("res://src/enemies/enemy_tank.tscn"),
	preload("res://src/enemies/enemy_boss.tscn"),
]
## Economia (medida con tests/economy_sim.gd): ~8 salas por piso, ~3.8 de combate.
## Cada moneda recogida vale 1-2. Sale a unas 28 monedas en el piso 1 y 43 en el 5:
## una mejora o un arma por piso, no todo. Los precios estan en shop_item.gd.
const COIN_DROP_CHANCE := 0.4
const COINS_PER_ROOM_CLEAR := 2
const BOSS_COINS_BASE := 4
const UPGRADE_IDS := ["upgrade_health", "upgrade_shield", "upgrade_stamina", "upgrade_damage"]
const CHEST_SCENE := preload("res://src/items/chest.tscn")
const SHOP_ITEM_SCENE := preload("res://src/items/shop_item.tscn")
const ITEM_PICKUP_SCENE := preload("res://src/items/item_pickup.tscn")
const PUZZLE_PLATES := preload("res://src/dungeon/puzzle_plates.gd")

## Sala cuya recompensa es la hormona que exige la Puerta Hormonal del jefe.
var _hormone_room: Room = null

func _frames_path(variant: String) -> String:
	return "res://assets/sprites/enemies/%s_sprite_frames.tres" % variant

func _spawn_room_enemies(room: Room) -> void:
	if room.cleared or room.room_type not in [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP, Room.RoomType.MINIBOSS, Room.RoomType.BOSS]:
		return
	room.spawn_enemies(ENEMY_SCENES, _generate_enemy_data_for_room(room))

func _generate_enemy_data_for_room(room: Room) -> Array[Dictionary]:
	var floor_n: int = _run_manager.current_floor
	var fd: Dictionary = _run_manager.floor_data()
	var count := RNG.randi_range(2, 4) + floor_n
	if room.room_type == Room.RoomType.MINIBOSS:
		count = 2
	elif room.room_type == Room.RoomType.BOSS:
		count = 1
	
	# Must stay typed: Room.spawn_enemies() expects Array[Dictionary].
	var data: Array[Dictionary] = []
	for i in range(count):
		var info := {
			"health": (30.0 + floor_n * 10.0) * RNG.randf_range(0.85, 1.15),
			"damage": (8.0 + floor_n * 3.0) * RNG.randf_range(0.85, 1.15),
			"drops": [{"item_id": "coin", "chance": COIN_DROP_CHANCE}, {"item_id": "health_small", "chance": 0.15},
				{"item_id": _random_loot_id(), "chance": 0.06}],
		}
		# El Perineo es tierra de nadie: mezcla bichos de los dos reinos.
		var roster: Array = fd.roster
		var names: Array = fd.names
		if fd.has("alt_roster") and RNG.randf() < 0.5:
			roster = fd.alt_roster
			names = fd.alt_names
		match room.room_type:
			Room.RoomType.BOSS:
				info.enemy_type = 4
				info.health = 450.0 + floor_n * 150.0
				info.damage = 12.0 + floor_n * 4.0
				info.name = fd.boss_name
				info.frames = _frames_path(fd.boss)
				info.drops = [{"item_id": "health_large", "chance": 1.0}]
			Room.RoomType.MINIBOSS:
				info.enemy_type = 0
				info.health *= 3.5
				info.damage *= 1.4
				info.name = "%s Gigante" % names[0]
				info.frames = _frames_path(roster[0])
				info.scale = 1.6
				info.drops.append({"item_id": "health_large", "chance": 0.8})
			_:
				var t := _weighted_index(fd.weights)
				# indices de ENEMY_SCENES: 0 melee, 1 ranged, 2 swarmer
				info.enemy_type = t
				info.name = names[t]
				info.frames = _frames_path(roster[t])
				if t == 2:
					info.group = 3  # los enjambres nunca vienen solos
				if room.room_type == Room.RoomType.INTOXICATION:
					info.drops.append({"item_id": "whiskey", "chance": 0.5})
		data.append(info)
	return data

func _weighted_index(weights: Array) -> int:
	var r: float = RNG.randf() * weights.reduce(func(a, b): return a + b, 0.0)
	for i in range(weights.size()):
		r -= weights[i]
		if r <= 0.0:
			return i
	return 0

## Botin aleatorio: consumibles y reliquias. Las armas salen de cofres, jefes y tienda.
func _random_loot_id() -> String:
	return _random_item_id(func(it): return it.equip_slot != Item.EquipSlot.WEAPON)

func _random_weapon_id() -> String:
	return _random_item_id(func(it): return it.equip_slot == Item.EquipSlot.WEAPON)

func _random_item_id(filter: Callable) -> String:
	var db = get_node("/root/ItemDatabase")
	for _i in range(40):
		var item = db.get_random_item()
		if item and filter.call(item) and not ("especial" in item.tags or "único" in item.tags or "moneda" in item.tags or "hormona" in item.tags or "mejora" in item.tags):
			return item.id
	return "health_small"

# ---------------------------------------------------------------- recompensas
func _spawn_pickup(room: Room, item_id: String, local_pos: Vector2) -> void:
	var p := ITEM_PICKUP_SCENE.instantiate()
	p.item_id = item_id
	p.position = local_pos
	room._add_pickup_deferred(p)

func _spawn_chest(room: Room, contents: String) -> void:
	var c := CHEST_SCENE.instantiate()
	c.contents = contents
	c.position = room.get_center_position() + Vector2(0, -40)
	room.pickups_node.add_child.call_deferred(c)

func _build_shop(room: Room) -> void:
	if room.has_meta("shop_built"):
		return
	room.set_meta("shop_built", true)
	var stock := [_random_weapon_id(), _random_loot_id(), _random_loot_id()]
	if _missing_hormones().size() > 0:
		stock[2] = "hormone_" + _missing_hormones()[0]  # la tienda tambien vende la hormona que te falta
	# Mejoras permanentes: siempre la de vida y otra al azar.
	var others := UPGRADE_IDS.slice(1)
	stock.append("upgrade_health")
	stock.append(others[RNG.randi_range(0, others.size() - 1)])
	for i in range(stock.size()):
		var s := SHOP_ITEM_SCENE.instantiate()
		s.item_id = stock[i]
		# armas y botin arriba, mejoras abajo
		var row := 0 if i < 3 else 1
		var col: float = (i - 1) if row == 0 else (i - 3.5)
		s.position = room.get_center_position() + Vector2(col * 120, -40 + row * 110)
		room.pickups_node.add_child.call_deferred(s)

# ---------------------------------------------------------------- puzzle / salas secretas
## Las puertas hacia salas secretas nacen cerradas si el piso tiene puzzle que las abra.
func _lock_secret_rooms() -> void:
	var rooms: Array = dungeon_generator.rooms.values()
	if not rooms.any(func(r): return r.room_type == Room.RoomType.PUZZLE):
		return
	for door in _doors_to_secret_rooms():
		door.set_state(Door.State.LOCKED)

func unlock_secret_rooms() -> void:
	for door in _doors_to_secret_rooms():
		if door.state == Door.State.LOCKED:
			door.set_state(Door.State.CLOSED)

func _doors_to_secret_rooms() -> Array:
	var out := []
	for room in dungeon_generator.rooms.values():
		for door in room.doors.values():
			var target: Room = dungeon_generator.rooms.get(door.target_pos)
			if target and target.room_type == Room.RoomType.SECRET:
				out.append(door)
	return out

func _build_puzzle(room: Room) -> void:
	if room.has_meta("puzzle"):
		room.get_meta("puzzle").play()  # al volver a entrar, repite la secuencia
		return
	var pz := PUZZLE_PLATES.new()
	pz.length = 3 + _run_manager.current_floor / 2
	pz.position = room.get_center_position()
	pz.solved.connect(_on_puzzle_solved.bind(room))
	room.set_meta("puzzle", pz)
	room.props_node.add_child.call_deferred(pz)  # se entra desde un callback de fisica

func _on_puzzle_solved(room: Room) -> void:
	Narrator.say("puzzle_solved", {}, true)
	unlock_secret_rooms()
	room.room_cleared()  # pinta la sala y da la recompensa normal

func _has_real_weapon() -> bool:
	return player.current_weapon != null

func _missing_hormones() -> Array:
	return _run_manager.floor_data().needs.filter(func(h): return not _run_manager.hormones.get(h, false))

func _pick_hormone_room() -> void:
	_hormone_room = null
	var candidates: Array = dungeon_generator.rooms.values().filter(func(r): return r.room_type == Room.RoomType.MINIBOSS)
	if candidates.is_empty():
		candidates = dungeon_generator.rooms.values().filter(func(r): return r.room_type == Room.RoomType.COMBAT)
	if not candidates.is_empty():
		_hormone_room = candidates[RNG.randi_range(0, candidates.size() - 1)]

# ---------------------------------------------------------------- color (la censura)
## Las salas nacen grises (censuradas) y recuperan el color al liberarlas.
func _paint_room(room: Room, colored: bool, animate := false) -> void:
	var tint: Color = _run_manager.floor_data().tint
	var target_floor := tint if colored else Color(0.42, 0.42, 0.46)
	var target_walls := tint.darkened(0.35) if colored else Color(0.3, 0.3, 0.34)
	if animate:
		var tw := room.create_tween().set_parallel()
		tw.tween_property(room.floor_tilemap, "modulate", target_floor, 1.2)
		tw.tween_property(room.walls_tilemap, "modulate", target_walls, 1.2)
	else:
		room.floor_tilemap.modulate = target_floor
		room.walls_tilemap.modulate = target_walls

func _on_room_cleared(room: Room) -> void:
	if floor_completed:
		return
	rooms_cleared_this_floor += 1
	get_node("/root/RunManager").clear_room()
	_paint_room(room, true, true)
	if room == _hormone_room:
		# Garantia: en cada piso hay al menos un arma antes del jefe.
		if not _has_real_weapon():
			_spawn_chest(room, "weapon")
		for h in _missing_hormones():
			_spawn_pickup(room, "hormone_" + h, room.get_center_position() + Vector2(RNG.randf_range(-60, 60), 40))
		if not _missing_hormones().is_empty():
			Narrator.say("hormone_found", {}, true)
	if room.room_type == Room.RoomType.BOSS:
		_spawn_chest(room, "weapon")
		var n := BOSS_COINS_BASE + _run_manager.current_floor
		for i in n:
			_spawn_pickup(room, "coin", room.get_center_position() + Vector2((i - (n - 1) / 2.0) * 30, 40))
	else:
		Narrator.say("room_cleared")
		for i in COINS_PER_ROOM_CLEAR:
			_spawn_pickup(room, "coin", room.get_center_position() + Vector2(-20 + i * 40, 60))
		if RNG.randf() < 0.3:
			_spawn_chest(room, "")

func _complete_floor() -> void:
	if floor_completed:
		return
	floor_completed = true
	var floor_n: int = _run_manager.current_floor
	if floor_n >= RunManager.FLOORS.size():
		Narrator.say("victory", {}, true)
		get_node("/root/LoreDatabase").custom_event("victory")
		_run_manager.end_run(true)
		get_tree().create_timer(4.0).timeout.connect(func(): get_tree().change_scene_to_file("res://src/scenes/game_over.tscn"))
		return
	Narrator.say("floor_complete", {}, true)
	get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position, "¡PISO %d COMPLETADO!" % floor_n, Color.GOLD)
	get_tree().create_timer(4.0).timeout.connect(_advance_to_next_floor)

func _advance_to_next_floor() -> void:
	# Antes llamaba a RunManager.next_floor(), que no existe: el juego reventaba aqui.
	_run_manager.advance_floor()
	rooms_cleared_this_floor = 0
	floor_completed = false
	current_room = null
	if dungeon_root:
		dungeon_root.queue_free()
	_generate_dungeon()

func _show_floor_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	var label := Label.new()
	var floor_n: int = _run_manager.current_floor
	label.text = "PISO %d\n%s" % [floor_n, _run_manager.floor_data().name]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color("cfc4ae"))
	label.add_theme_color_override("font_outline_color", Color("0d0b0f"))
	label.add_theme_constant_override("outline_size", 10)
	layer.add_child(label)
	add_child(layer)
	var tw := label.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(layer.queue_free)

func _on_enemy_killed(enemy: Node, killer: Node) -> void:
	if enemy.is_in_group("boss"):
		_complete_floor()
	if killer == player:
		get_node("/root/RunManager").total_enemies_killed += 1
		get_node("/root/RunManager").total_damage_dealt += enemy.max_health  # Approximate
		_check_room_clear_for_enemy(enemy)

func _check_room_clear_for_enemy(killed_enemy: Node) -> void:
	if not current_room:
		return
	
	var alive = 0
	for enemy in current_room.enemies_spawned:
		# Do not compare state against Enemy.State.DEAD: every enemy script has
		# its own State enum where DEAD is 4, 5 or 6, so ranged/tank/boss kills
		# were counted as alive and the room could never be cleared.
		if enemy and is_instance_valid(enemy) and enemy != killed_enemy and not enemy.is_queued_for_deletion():
			alive += 1
	
	if alive == 0 and not current_room.cleared:
		current_room.room_cleared()

func _on_show_damage_number(position: Vector2, amount: float, is_crit: bool) -> void:
	floating_text_mgr.spawn(position, "%.0f" % amount, Color(1, 0.9, 0.2) if is_crit else Color(1, 0.3, 0.3), is_crit)

func _on_show_floating_text(position: Vector2, text: String, color: Color) -> void:
	floating_text_mgr.spawn(position, text, color)

func _on_player_died() -> void:
	# player_died is emitted from PlayerStats.take_damage(), which runs inside the
	# player's Hurtbox area_entered callback. Freeing the scene from there removes
	# CollisionObject nodes mid physics callback, which Godot rejects.
	get_tree().call_deferred("change_scene_to_file", "res://src/scenes/game_over.tscn")

func _exit_tree() -> void:
	get_node("/root/GlobalEvents").enemy_killed.disconnect(_on_enemy_killed)
	get_node("/root/GlobalEvents").player_died.disconnect(_on_player_died)
	get_node("/root/GlobalEvents").show_damage_number.disconnect(_on_show_damage_number)
	get_node("/root/GlobalEvents").show_floating_text.disconnect(_on_show_floating_text)