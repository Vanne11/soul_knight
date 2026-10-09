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
	Narrator.say("floor_%d" % _run_manager.current_floor)  # antes que la pista del arma
	_weapon_room = null
	if start_room and not _has_real_weapon():
		_hide_weapon_chest(start_room)
	_pick_hormone_room()
	_assign_rewards()
	_show_floor_card()
	if _run_manager.is_liberated(_run_manager.current_floor):
		# Region liberada en otra partida: te recibe con un regalo.
		get_tree().create_timer(2.6).timeout.connect(func():
			Narrator.say("liberated_floor")
			_offer_blessing(_floor_kingdom(), "[b]%s te recuerda.[/b] Ya la liberaste una vez. Elige una bendición de regalo:" % _run_manager.floor_data().name))
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
		Narrator.say_first("door_no_weapon")
		return
	if next_room.room_type == Room.RoomType.BOSS and not _missing_hormones().is_empty():
		# Puerta Hormonal: solo pasa quien lleve la hormona del reino. Aunque le dé alergia.
		_transition_lock = 1.5
		get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -40),
			"PUERTA HORMONAL: falta %s" % ", ".join(_missing_hormones()), Color("ff7ac0"))
		Narrator.say_first("door_hormonal")
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
	if entry_door:
		Sound.play("door")
	Sound.music("boss" if room.room_type == Room.RoomType.BOSS and not room.cleared else "explore")
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
	
	_paint_room(room, room.cleared or room.room_type in CALM_ROOMS)
	_label_doors(room)
	if room.room_type in [Room.RoomType.TREASURE, Room.RoomType.REST, Room.RoomType.LORE]:
		_build_calm_room(room)
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
		Room.RoomType.SHOP: Narrator.say_first("room_shop")
		Room.RoomType.PUZZLE: Narrator.say_first("puzzle_start")

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
	# Las puertas estan centradas en el borde: sin margen la camara las cortaba por
	# la mitad. Arriba, ademas, la franja del HUD (en pixeles de mundo).
	var margin := 40.0
	camera.limit_left = world_pos.x - margin
	camera.limit_top = world_pos.y - margin - HUD.BAND / camera.zoom.y
	camera.limit_right = world_pos.x + room_rect.size.x * 64 + margin
	camera.limit_bottom = world_pos.y + room_rect.size.y * 64 + margin

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
const INTERACTABLE := preload("res://src/items/interactable.gd")
## Salas sin enemigos: entrar ya las "libera" (salen en color).
const CALM_ROOMS := [Room.RoomType.START, Room.RoomType.SHOP, Room.RoomType.SECRET, Room.RoomType.LORE,
	Room.RoomType.TREASURE, Room.RoomType.REST]

## Sala cuya recompensa es la hormona que exige la Puerta Hormonal del jefe.
var _hormone_room: Room = null

func _frames_path(variant: String) -> String:
	return "res://assets/sprites/enemies/%s_sprite_frames.tres" % variant

func _spawn_room_enemies(room: Room) -> void:
	if room.cleared or room.room_type not in [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP, Room.RoomType.MINIBOSS, Room.RoomType.BOSS]:
		return
	if not room.enemies_spawned.is_empty():
		# Ya huiste de aqui desarmado: los enemigos siguen dentro. Con arma, ya no hay huida.
		if _has_real_weapon():
			room.seal_doors()
		return
	room.spawn_enemies(ENEMY_SCENES, _generate_enemy_data_for_room(room), _has_real_weapon())

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
			"drops": [{"item_id": "coin", "chance": COIN_DROP_CHANCE}, {"item_id": "health_small", "chance": 0.08},
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

func _spawn_chest(room: Room, contents: String, offset := Vector2(0, -40)) -> void:
	var c := CHEST_SCENE.instantiate()
	c.contents = contents
	c.position = room.get_center_position() + offset
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
	Narrator.say("puzzle_solved")
	unlock_secret_rooms()
	room.room_cleared()  # pinta la sala y da la recompensa normal

## Sin arma de inicio: hay que ir a buscarla. Cofre en la sala mas lejana (en
## puertas a cruzar) que no sea jefe ni secreta; por el camino, a esquivar.
func _hide_weapon_chest(start_room: Room) -> void:
	var graph: Dictionary = dungeon_generator.room_graph
	var dist := {start_room.grid_pos: 0}
	var queue := [start_room.grid_pos]
	var far: Room = null
	while not queue.is_empty():
		var pos = queue.pop_front()
		var r: Room = dungeon_generator.rooms[pos]
		if r.room_type not in [Room.RoomType.START, Room.RoomType.BOSS, Room.RoomType.SECRET, Room.RoomType.SHOP]:
			far = r  # BFS: el ultimo valido es el mas lejano
		for n in graph[pos]:
			if not dist.has(n) and dungeon_generator.rooms[n].room_type != Room.RoomType.BOSS:
				dist[n] = dist[pos] + 1
				queue.append(n)
	if far == null:
		far = start_room
	_weapon_room = far
	_spawn_chest(far, "weapon", Vector2(0, 70))  # abajo: no choca con el cofre de una sala de tesoro
	Narrator.say("weapon_hunt")

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
	if room.reward == "hormona" and _missing_hormones().is_empty():
		room.reward = "bendicion"  # ya la compraste en la tienda: algo a cambio
		room.reward_kingdom = _floor_kingdom()
	_paint_room(room, true, true)
	if room == _hormone_room:
		# Garantia: en cada piso hay al menos un arma antes del jefe.
		if not _has_real_weapon():
			_spawn_chest(room, "weapon")
		for h in _missing_hormones():
			_spawn_pickup(room, "hormone_" + h, room.get_center_position() + Vector2(RNG.randf_range(-60, 60), 40))
		if not _missing_hormones().is_empty():
			Narrator.say("hormone_found")
	if room.reward != "hormona" and room.room_type != Room.RoomType.BOSS:
		_give_reward(room)
	if room.room_type == Room.RoomType.BOSS:
		_spawn_chest(room, "weapon")
		var n := BOSS_COINS_BASE + _run_manager.current_floor
		for i in n:
			_spawn_pickup(room, "coin", room.get_center_position() + Vector2((i - (n - 1) / 2.0) * 30, 40))
	else:
		Sound.play("room_clear")
		for i in COINS_PER_ROOM_CLEAR:
			_spawn_pickup(room, "coin", room.get_center_position() + Vector2(-20 + i * 40, 60))

func _complete_floor() -> void:
	if floor_completed:
		return
	floor_completed = true
	Sound.music("")
	Sound.play("floor_complete")
	var boss_room := current_room
	var floor_n: int = _run_manager.current_floor
	if floor_n >= RunManager.FLOORS.size():
		_run_manager.liberate(floor_n)
		Narrator.say("victory")
		get_node("/root/LoreDatabase").custom_event("victory")
		_run_manager.end_run(true)
		get_tree().create_timer(4.0).timeout.connect(func(): get_tree().change_scene_to_file("res://src/scenes/game_over.tscn"))
		return
	get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position, "¡PISO %d COMPLETADO!" % floor_n, Color.GOLD)
	if _run_manager.liberate(floor_n):
		Narrator.toast("REGIÓN LIBERADA PARA SIEMPRE", "%s ya no vuelve al gris. En próximas partidas te dará una bendición al llegar." % _run_manager.floor_data().name, "ffd75a")
	# Recompensa: una mejora a elegir. Luego, sin prisa: recoges el botin y bajas por la escotilla.
	await get_tree().create_timer(1.5).timeout
	Narrator.choose("[b]Jefe derrotado.[/b] Elige una mejora para el resto de la partida:", BOSS_REWARDS.map(func(r): return r[0]))
	var pick: Array = BOSS_REWARDS[await Narrator.chosen]
	_game_controller.get_player_stats().apply_stat_mod(pick[1], pick[2])
	Sound.play("puzzle_solve")
	_add_prop(boss_room, boss_room.get_center_position() + Vector2(0, 150), _hatch_visual(),
		"[b]Escotilla al piso %d[/b]\n[font_size=13]Recoge lo que quieras antes: no se vuelve.[/font_size]\n[color=#b08d4a][E] Bajar[/color]" % (floor_n + 1),
		func(_p, it): it.finish(); _advance_to_next_floor())

## [texto, stat, cantidad] (apply_stat_mod, valores fijos que se suman).
const BOSS_REWARDS := [
	["+10 vida máxima", "max_health_flat", 10.0],
	["+15 estamina máxima", "max_stamina_flat", 15.0],
	["+10 escudo máximo", "max_shields_flat", 10.0],
]

# ---------------------------------------------------------------- recompensas por sala
## Cada sala de pelea anuncia en su puerta lo que da al limpiarla: el camino
## por el piso es una decision, no un pasillo.
const FIGHT_ROOMS := [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP, Room.RoomType.MINIBOSS]
const KINGDOM_COLORS := {"pene": Color("6ec6ff"), "vulva": Color("ff7ac0"), "mixto": Color("ffc93c")}
const KINGDOM_NAMES := {"pene": "PENELANDIA", "vulva": "VULVANIA"}
## Sala del cofre del arma inicial (su puerta dice ARMA mientras vayas desarmado).
var _weapon_room: Room = null

## Reino de las bendiciones de este piso: el suyo casi siempre, si tiene.
func _floor_kingdom() -> String:
	var k: String = _run_manager.floor_data().kingdom
	if k in ["pene", "vulva"] and RNG.randf() < 0.7:
		return k
	return "pene" if RNG.randf() < 0.5 else "vulva"

func _assign_rewards() -> void:
	var fights: Array = dungeon_generator.rooms.values().filter(func(r): return r.room_type in FIGHT_ROOMS)
	RNG.shuffle(fights)
	var blessed := 0
	for room in fights:
		if room == _hormone_room and not _missing_hormones().is_empty():
			room.reward = "hormona"
			continue
		# Dos bendiciones por piso, ni una mas: si todo da mejoras, nada pesa.
		# El resto: monedas, nada (solo pelea) o algo de vida.
		var r := RNG.randf()
		room.reward = "bendicion" if blessed < 2 else ("monedas" if r < 0.5 else ("" if r < 0.8 else "vida"))
		if room.reward == "bendicion":
			blessed += 1
			room.reward_kingdom = _floor_kingdom()

## Carteles de las puertas de la sala actual: que hay al otro lado.
func _label_doors(room: Room) -> void:
	for door: Door in room.doors.values():
		var target: Room = dungeon_generator.rooms.get(door.target_pos)
		var hint := ["", Color("f2ead6")]
		if target and not target.cleared:
			hint = _room_hint(target)
		door.set_hint(hint[0], hint[1])

func _room_hint(room: Room) -> Array:
	if room == _weapon_room and not _has_real_weapon():
		return ["ARMA", Color("ffa64a")]
	match room.room_type:
		Room.RoomType.BOSS: return ["JEFE", Color("ff5050")]
		Room.RoomType.SHOP: return ["TIENDA", Color("ffd75a")]
		Room.RoomType.REST: return ["DESCANSO", Color("6aa8ff")] if not room.has_meta("calm_built") else ["", Color.WHITE]
		Room.RoomType.TREASURE: return ["TESORO", Color("ffd75a")] if not room.has_meta("calm_built") else ["", Color.WHITE]
		Room.RoomType.LORE: return ["INSCRIPCIÓN", Color("c08cff")] if not room.has_meta("calm_built") else ["", Color.WHITE]
		Room.RoomType.PUZZLE: return ["ACERTIJO", Color("c08cff")]
	var head := "MINIJEFE · " if room.room_type == Room.RoomType.MINIBOSS else ""
	match room.reward:
		"bendicion":
			var k := room.reward_kingdom
			var warn := "\n(te da alergia)" if _run_manager.is_foreign(k) else ""
			return [head + "BENDICIÓN\n" + KINGDOM_NAMES[k] + warn, KINGDOM_COLORS[k]]
		"monedas": return [head + "MONEDAS", Color("ffd75a")]
		"vida": return [head + "VIDA", Color("ff6b6b")]
		"hormona": return [head + "HORMONA", Color("c08cff")]
	return [head + "SOLO PELEA", Color(0.6, 0.6, 0.65)]

func _give_reward(room: Room) -> void:
	var center := room.get_center_position()
	match room.reward:
		"monedas":
			var n := 4 + _run_manager.current_floor
			for i in n:
				_spawn_pickup(room, "coin", center + Vector2((i - (n - 1) / 2.0) * 28, -30))
		"vida":
			_spawn_pickup(room, "health_large", center + Vector2(0, -30))
		"bendicion":
			await get_tree().create_timer(0.7).timeout
			_offer_blessing(room.reward_kingdom, "[b]Bendición de %s.[/b] Elige una:" % KINGDOM_NAMES[room.reward_kingdom].capitalize())

func _offer_blessing(kingdom: String, title: String) -> void:
	var ids: Array = _run_manager.roll_blessings(kingdom)
	var options := ids.map(func(id):
		var b: Dictionary = RunManager.BLESSINGS[id]
		var lvl: int = _run_manager.blessing(id)
		var tag := ("  [nivel %d]" % (lvl + 1)) if lvl > 0 else ""
		if _run_manager.is_foreign(b.kingdom):
			tag += "  [AJENA: doble efecto + ALERGIA]"
		return "%s (%s): %s%s" % [b.name, KINGDOM_NAMES.get(b.kingdom, "MIXTA").capitalize(), b.desc, tag])
	Narrator.say_first("blessing_first")
	Narrator.choose(title, options)
	_take_blessing(ids[await Narrator.chosen])

func _take_blessing(id: String) -> void:
	var b: Dictionary = RunManager.BLESSINGS[id]
	var foreign: bool = _run_manager.is_foreign(b.kingdom)
	var levels := 2 if foreign else 1
	_run_manager.blessings[id] = _run_manager.blessing(id) + levels
	var ps = _game_controller.get_player_stats()
	for i in levels:
		if b.has("stat"):
			ps.apply_stat_mod(b.stat[0], b.stat[1])
		if id == "testosterona":
			ps.apply_stat_mod("max_shields_flat", 5.0)
	if foreign:
		player.start_allergy(20.0)
		Narrator.say_first("blessing_foreign")
	Sound.play("puzzle_solve")
	_global_events.blessings_changed.emit()

# ---------------------------------------------------------------- salas tranquilas
func _build_calm_room(room: Room) -> void:
	if room.has_meta("calm_built"):
		return
	room.set_meta("calm_built", true)
	var center := room.get_center_position()
	match room.room_type:
		Room.RoomType.TREASURE:
			_spawn_chest(room, "")
			for i in 3:
				_spawn_pickup(room, "coin", center + Vector2(-40 + i * 40, 30))
		Room.RoomType.REST:
			var water := _disc(20, Color("4aa3df"))
			var fountain := Node2D.new()
			fountain.add_child(_disc(28, Color("cfc4ae")))
			fountain.add_child(water)
			_add_prop(room, center, fountain,
				"[color=#6aa8ff][b]Fuente de Lubricante Bendito[/b][/color]\n[font_size=13]Cura toda la vida y la estamina. Un trago por fuente.[/font_size]\n[color=#b08d4a][E] Beber[/color]",
				func(_p, it):
					var ps = _game_controller.get_player_stats()
					ps.heal(ps.max_health)
					ps.current_stamina = ps.max_stamina
					ps.stamina_changed.emit(ps.current_stamina, ps.max_stamina)
					water.color = Color(0.35, 0.35, 0.38)
					Sound.play("room_clear")
					Narrator.toast("Fuente", "Vida y estamina al máximo.")
					it.finish())
		Room.RoomType.LORE:
			var stone := Polygon2D.new()
			stone.polygon = PackedVector2Array([Vector2(-18, 26), Vector2(-18, -18), Vector2(-10, -28), Vector2(10, -28), Vector2(18, -18), Vector2(18, 26)])
			stone.color = Color("8a8494")
			_add_prop(room, center, stone,
				"[color=#c08cff][b]Inscripción antigua[/b][/color]\n[font_size=13]Alguien grabó algo aquí antes de la censura.[/font_size]\n[color=#b08d4a][E] Leer[/color]",
				func(_p, it):
					_read_inscription()
					stone.color = Color("5a5662")
					it.finish())

## Lee una entrada de historia (mundo, personajes, lugares, enemigos), mejor una nueva.
func _read_inscription() -> void:
	var lore = get_node("/root/LoreDatabase")
	var pool: Array = lore.get_all_entries().filter(func(e): return e.category in [0, 1, 3, 4, 5])
	var fresh := pool.filter(func(e): return not e.unlocked)
	var entry = (fresh if not fresh.is_empty() else pool)[RNG.randi_range(0, (fresh if not fresh.is_empty() else pool).size() - 1)]
	lore.unlock_entry(entry.id)
	Narrator.say_raw("INSCRIPCIÓN: [b]%s.[/b] %s" % [entry.title, entry.text])

func _add_prop(room: Room, pos: Vector2, visual: Node2D, text: String, on_use: Callable) -> void:
	var it := INTERACTABLE.new()
	it.position = pos
	it.prompt_text = text
	it.add_child(visual)
	it.used.connect(on_use.bind(it))
	room.props_node.add_child.call_deferred(it)

func _disc(radius: float, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(Vector2.RIGHT.rotated(TAU * i / 24) * radius)
	p.polygon = pts
	p.color = color
	return p

func _hatch_visual() -> Node2D:
	var n := Node2D.new()
	n.add_child(_disc(30, Color("b08d4a")))
	n.add_child(_disc(24, Color("0d0b0f")))
	return n

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
		var regen: int = _run_manager.blessing("regla")
		if regen > 0:
			_game_controller.get_player_stats().heal(regen)
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