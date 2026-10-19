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
## PASILLOS entre reinos (ver open_exit / _begin_corridor): puertas de salida de la sala del jefe, y el
## estado del pasillo mientras se recorre (current_room es entonces la sala del pasillo).
const DOOR_SCENE := preload("res://src/dungeon/door.tscn")
var exit_doors: Array = []
var corridor_active := false
var _corridor: Dictionary = {}   # {from, to, dir, add, fl, seed}
var _corridor_bar: CorridorBar = null
var _fade: ColorRect = null
var _fade_layer: CanvasLayer = null
var _exit_busy := false

func _process(delta: float) -> void:
	if corridor_active:
		_corridor_step()
	if _transition_lock > 0.0:
		_transition_lock -= delta
		if _transition_lock <= 0.0:
			_recheck_doors()


## Si durante el bloqueo de transicion el jugador ya se metio en una puerta, el area no
## vuelve a avisar (body_entered solo salta al entrar): se dejaba al jugador pegado en
## la puerta hasta salir y volver a entrar. Al terminar el bloqueo se revisa a mano.
func _recheck_doors() -> void:
	if current_room == null or floor_completed:
		return
	for door: Door in current_room.doors.values():
		if door.overlaps_body(player) and door.try_open(player):
			_on_door_entered_room(current_room, door)
			return

## true tras morir (la victoria final ya pone run_active en false): no se pausa.
var _ending := false

## Esc: menu de pausa. No se abre si otro sistema ya pausa (narrador con
## opciones, panel de depuracion F1) ni durante la muerte/victoria.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo():
		return
	if get_tree().paused or _ending or not _run_manager.run_active:
		return
	get_viewport().set_input_as_handled()
	PauseMenu.open(self)

var dungeon_generator: DungeonGenerator
var _lighting: RoomLighting
@onready var _game_controller: GameController = get_node("/root/GameController")
@onready var _global_events: GlobalEvents = get_node("/root/GlobalEvents")
@onready var _run_manager: RunManager = _game_controller.get_run_manager()

func _ready() -> void:
	add_to_group("main")
	EnemyRegistry.preload_all()  # como los preload de antes: sin tirones en el primer spawn
	dungeon_generator = DungeonGenerator.new()
	dungeon_generator.name = "DungeonGenerator"
	add_child(dungeon_generator)
	
	var hit_fx := HitFx.new()  # sacudida, pausa al impactar y destello (src/fx/hit_fx.gd)
	hit_fx.camera = camera
	add_child(hit_fx)
	add_child(WorldFx.new())  # polvo, casquillos, chispas, huellas, ambiente (src/fx/world_fx.gd)
	add_child(ScreenFx.new())  # vineta, polvo/rayos y mareo (src/fx/screen_fx.gd)
	add_child(AmbientAudio.new())  # ambiente, antorchas y pasos (src/fx/ambient_audio.gd)
	_lighting = RoomLighting.new()
	_lighting.name = "RoomLighting"
	add_child(_lighting)
	_lighting.setup(player)
	_setup_camera()
	_generate_dungeon()
	_game_controller.get_player_stats().emit_all_signals()
	_global_events.enemy_killed.connect(_on_enemy_killed)
	_global_events.player_died.connect(_on_player_died)
	_global_events.show_damage_number.connect(_on_show_damage_number)
	_global_events.show_floating_text.connect(_on_show_floating_text)
	_global_events.show_hero_number.connect(_on_show_hero_number)

func _setup_camera() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 1280
	camera.limit_bottom = 720

func _generate_dungeon() -> void:
	if has_meta("map_key") and get_meta("map_seed", -1) == _run_manager.current_seed and not dungeon_generator.rooms.is_empty():  # foto del piso que dejas (mapa del mundo)
		_run_manager.floor_maps[get_meta("map_key")] = MapMetroid.snapshot(self)
	set_meta("map_key", MapMetroid.floor_key(_run_manager.current_floor))
	set_meta("map_seed", _run_manager.current_seed)
	var seed = _run_manager.current_seed + _run_manager.current_floor * 7919  # cada piso su propio trazado
	dungeon_root = dungeon_generator.generate_floor(_run_manager.current_floor, seed)
	visited_rooms.clear()
	add_child(dungeon_root)
	_arm_exit_doors()  # puertas de salida del jefe (pasillos): selladas hasta vencerlo
	_lighting.setup_floor(dungeon_generator.rooms, _run_manager.current_floor, seed)
	# Tramo en paz de la run de rescate (reino ya liberado): una plaza sin combates ni trampas.
	var peace := RunManager.floor_is_peace(_run_manager.current_floor)
	if not peace:
		FloorEvents.setup(self, dungeon_generator.rooms, _run_manager.current_floor, _run_manager.current_seed)  # evento de piso + contrarreloj (src/run/floor_events.gd)
	RoomDressing.build_floor(dungeon_generator.rooms, _run_manager.current_floor, seed)  # muros 3/4, zocalo, puertas
	if not peace and not Silencio.active():
		RoomObstacles.build_floor(dungeon_generator.rooms, _run_manager.current_floor, seed)  # rocas, columnas, barriles, pinchos
	_lock_secret_rooms()
	if not peace:
		Utero.setup_floor(self)  # El Utero (src/utero): fases del ciclo
		Arcoiria.setup_floor(self)  # Arcoiria (src/arcoiria): bandera del HUD, poderes de colores, codice del reino
	Silencio.setup_floor(self)  # Las Tierras del Silencio (src/silencio): aviso, circulo del HUD; fuera del reino, lo limpia
	
	# Start player in start room
	var start_room = _find_start_room()
	if not peace:
		Narrator.say_hero("floor_" + str(_run_manager.floor_data().id))  # entrada a region, por heroe (narrator/etapas.json); antes que la pista del arma
	_weapon_room = null
	if start_room and not peace and not Silencio.active() and not _has_real_weapon():
		_hide_weapon_chest(start_room)  # (en el Silencio no hay cofres ni premios)
	_pick_hormone_room()
	_assign_rewards()
	_coin_mult = _compute_coin_mult()
	_show_floor_card()
	_announce_taken()
	if peace and start_room:
		_build_peace(start_room)
	elif _run_manager.is_liberated(_run_manager.current_floor) and RunManager.floor_stage(_run_manager.current_floor) == 1 and not Silencio.active():
		# Region liberada en otra partida: te recibe con un regalo (al entrar al reino, no en la 2a etapa).
		get_tree().create_timer(2.6).timeout.connect(func():
			Narrator.say("liberated_floor")
			_offer_blessing(_floor_kingdom(), tr("FLOOR_REMEMBERS") % Loc.region_name(_run_manager.current_floor)))
	if start_room:
		_enter_room(start_room)
	else:
		# Fallback to first room
		var rooms = dungeon_generator.rooms.values()
		if rooms.size() > 0:
			_enter_room(rooms[0])

## PLAN 6: al entrar a un reino TOMADO por la copia de seguridad (1a etapa), el aviso: ya no es paz,
## el jefe que lo tomo lo espera (BossPicker lo fuerza). Al vencerlo el reino queda liberado de nuevo.
func _announce_taken() -> void:
	var fd: Dictionary = _run_manager.floor_data()
	var tk := RunManager.taken_boss(str(fd.get("region", "")))
	if tk.is_empty() or RunManager.floor_stage(_run_manager.current_floor) != 1:
		return
	var line := tr("P6_TOMADO_AVISO") % [_nice_name(Loc.region_name_id(str(fd.region))), _nice_name(Loc.enemy_name(str(tk.name)))]
	Narrator.toast(tr("P6_TOMADO_TITLE"), line, "ff4040")
	get_tree().create_timer(3.2).timeout.connect(func(): Narrator.say_raw(line))

func _nice_name(boss_name: String) -> String:
	return Narrator._nice_name(boss_name)

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
	if door.has_meta("exit_region"):  # puerta de salida del jefe: pasillo al reino de destino
		if room == current_room and not corridor_active:
			_on_exit_door_used(door)
		return
	if room != current_room or floor_completed or _transition_lock > 0.0:
		return
	var next_room: Room = dungeon_generator.rooms.get(door.target_pos)
	if next_room == null:
		return
	if next_room.room_type == Room.RoomType.BOSS and not _has_real_weapon():
		# A un jefe no se entra a puñetazos: la puerta no deja pasar y el narrador se ensaña.
		_transition_lock = 1.5
		get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -40),
			tr("FX_NO_WEAPON"), Color("ff7ac0"))
		Narrator.say_first("door_no_weapon")
		return
	if next_room.room_type == Room.RoomType.BOSS and not _missing_hormones().is_empty():
		# Puerta Hormonal: solo pasa quien lleve la hormona del reino. Aunque le dé alergia.
		_transition_lock = 1.5
		get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -40),
			tr("FX_HORMONE_DOOR") % ", ".join(_missing_hormones().map(func(h): return tr("HUD_HORMONE_" + str(h).to_upper()))), Color("ff7ac0"))
		Narrator.say_first("door_hormonal")
		get_node("/root/LoreDatabase").custom_event("hormone_door")
		return
	_enter_room(next_room, next_room.door_to(room.grid_pos))


## Pista de la sala: exploracion por reino (explore_<reino>), jefe por id y fase (boss_<id>_p1; el
## propio jefe cruza a _p2/_p3, EnemyBoss.update_music), "voz" en las Tierras de la Voz y "paz" en
## los tramos en paz. Sin pista (el Silencio oscuro, la sala de memoria, el Pacto) no suena nada.
func _room_track(room: Room) -> String:
	var boss_alive := room.room_type == Room.RoomType.BOSS and not room.cleared
	if Silencio.active():
		if Silencio.liberado and not boss_alive and str(room.get_meta("silencio", "")) != "memoria":
			return "explore_voz"  # Las Tierras de la Voz: el Silencio liberado
		return ""  # el Silencio no tiene musica
	if RunManager.floor_is_peace(_run_manager.current_floor):
		return "explore_paz"
	var fd: Dictionary = _run_manager.floor_data()
	if boss_alive and RunManager.floor_has_boss(_run_manager.current_floor):
		var bv := BossPicker.pick(fd, _run_manager.current_seed, _run_manager.current_floor)
		return "boss_%s_p1" % str(bv.variant).trim_prefix("boss_")
	return "explore_" + str(fd.get("region", ""))


func _enter_room(room: Room, entry_door: Door = null) -> void:
	if current_room:
		Silencio.on_leave_room(self, current_room)
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
	Sound.music(_room_track(room))
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
	
	_lighting.enter_room(room)
	if not Silencio.active():  # el Silencio dibuja su propia sala (Silencio.on_enter_room)
		RoomDecals.build(room, _run_manager.floor_data().kingdom, _run_manager.current_seed, _run_manager.current_floor)  # calcomanias de suelo (una vez por sala)
		RoomDecor.build(room, _run_manager.floor_data().kingdom, _run_manager.current_seed, _run_manager.current_floor)  # decoracion junto a los muros (una vez por sala)
	_paint_room(room, room.cleared or (room.room_type in CALM_ROOMS and not room.has_meta("secret_boss")))
	_label_doors(room)
	Utero.on_enter(self, room, entry_door)  # fase del ciclo (src/utero), antes de las dinamicas de sala
	RoomDirector.on_enter(self, room, entry_door)  # dinamicas de sala (src/rooms/room_director.gd)
	Silencio.on_enter_room(self, room, entry_door)  # sala de situacion del Silencio (src/silencio)
	if room.room_type in [Room.RoomType.TREASURE, Room.RoomType.REST, Room.RoomType.LORE]:
		_build_calm_room(room)
	Arcoiria.on_enter_room(self, room)  # rincon "Como buscar ayuda" en la sala de inicio del reino
	if room.room_type == Room.RoomType.SHOP:
		_build_shop(room)
	if room.room_type == Room.RoomType.PUZZLE and not room.cleared:
		_build_puzzle(room)
	if not room.cleared:
		_narrate_room(room)
	
	# Spawn enemies for this room
	_spawn_room_enemies(room)
	
	get_node("/root/RunManager").current_room_index = _get_room_index(room)
	BossIntro.on_enter_room(self, room)  # presentacion del jefe (primera vez)
	Prostata.on_enter_room(self, room)  # codice y comentario ambiente de La Prostata (src/enemies/prostata/)
	FloorEvents.on_room_enter(room)  # reloj de la contrarreloj / llegada al jefe
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

## Las escenas de enemigos salen de EnemyRegistry (src/enemies/enemy_registry.gd) por id:
## "melee", "ranged", "swarmer", "tank", "boss", "taser" (Dildo Electrico), "inspector"
## (Inspector de Fluidos), "espinilla" (Espinilla Reventona), "its" (microbios de ITS).
## Economia (medida con tests/economy_sim.gd): ~8 salas por piso, ~3.8 de combate.
## Cada moneda recogida vale 1-2. Sale a unas 28 monedas en el piso 1 y 43 en el 5:
## una mejora o un arma por piso, no todo. Los precios estan en shop_item.gd.
## Etapa 6b: los pisos tienen 7-12 salas; _coin_mult (monedas de salas de pelea, sin contar la
## sala elite, que es premio opcional) mantiene el total del piso cerca de la referencia
## de COIN_BASE_FIGHTS salas de pelea, con tope para no romper pisos pequenos.
const COIN_BASE_FIGHTS := 3.8
const COIN_DROP_CHANCE := 0.4
const COINS_PER_ROOM_CLEAR := 2
const BOSS_COINS_BASE := 4
const UPGRADE_IDS := ["upgrade_health", "upgrade_shield", "upgrade_stamina", "upgrade_damage"]
const CHEST_SCENE := preload("res://src/items/chest.tscn")
const SHOP_ITEM_SCENE := preload("res://src/items/shop_item.tscn")
const ITEM_PICKUP_SCENE := preload("res://src/items/item_pickup.tscn")
const PUZZLE_PLATES := preload("res://src/puzzles/puzzle_factory.gd")
const INTERACTABLE := preload("res://src/items/interactable.gd")
## Salas sin enemigos: entrar ya las "libera" (salen en color).
const CALM_ROOMS := [Room.RoomType.START, Room.RoomType.SHOP, Room.RoomType.SECRET, Room.RoomType.LORE,
	Room.RoomType.TREASURE, Room.RoomType.REST]

## Multiplicador de monedas del piso (ver COIN_BASE_FIGHTS).
var _coin_mult := 1.0

## Sala cuya recompensa es la hormona que exige la Puerta Hormonal del jefe.
var _hormone_room: Room = null

func _frames_path(variant: String) -> String:
	return EnemyArt.frames(variant)

func _spawn_room_enemies(room: Room) -> void:
	if RoomDirector.takes_over(room):
		return  # la dinamica de la sala (aguantar, sigilo) crea sus propios enemigos
	if room.cleared or (room.room_type not in [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP, Room.RoomType.MINIBOSS, Room.RoomType.BOSS] and not room.has_meta("secret_boss")):
		return
	if not room.enemies_spawned.is_empty():
		# Ya huiste de aqui desarmado: los enemigos siguen dentro. Con arma, ya no hay huida.
		if _has_real_weapon():
			room.seal_doors()
		return
	if Waves.enabled_for(room) and Waves.start(self, room, _has_real_weapon()):
		return  # oleadas y formaciones (src/combat/waves.gd)
	room.spawn_enemies(_generate_enemy_data_for_room(room), _has_real_weapon())

## Balance (2026-10-17, a revisar con la autora): dano base de los enemigos comunes
## (antes 8) y multiplicador de los enjambres (ladillas, espermatozoides, calambres...).
const ENEMY_DAMAGE_BASE := 6.0
const SWARM_DAMAGE_MULT := 0.5
## Tanque (Hemorroide Fronteriza): multiplica la vida/dano generica del piso. Queda entre
## el minijefe (x3.5 vida) y el jefe; el tanque base (500 vida, 40 dano) no escala con el piso.
const TANK_HEALTH_MULT := 5.0
const TANK_DAMAGE_MULT := 1.5
## ITS (id "its"): multiplicadores sobre la vida/dano generica del piso + velocidad. Ninguna
## es mas letal que un bicho comun; su gracia es la mecanica y el contagio leve.
const ITS_STATS := {
	"clamidia": {"health": 0.7, "damage": 1.0, "speed": 150.0},
	"herpes": {"health": 0.9, "damage": 0.9, "speed": 105.0},
	"gonorrea": {"health": 1.0, "damage": 0.8, "speed": 110.0},
	"vph": {"health": 1.2, "damage": 0.7, "speed": 85.0},
	"sifilis": {"health": 1.0, "damage": 1.1, "speed": 115.0},
}
## En las salas de intoxicacion (el antro) las ITS salen el triple de a menudo.
const ITS_INTOX_WEIGHT_MULT := 3.0
## Espinilla Reventona: control de zona, no combate directo. Vida baja (se mata de 2-3 tiros
## antes de que reviente) y casi nunca suelta moneda.
const ESPINILLA_HEALTH_MULT := 0.5
const ESPINILLA_COIN_CHANCE := 0.15
## Elites (bicho comun reforzado; la probabilidad es "elite_chance" de cada piso, mas alta en la
## 2a etapa) y guardian de fin de la 1a etapa (sala final sin jefe: minijefe reforzado + escoltas).
const ELITE_HEALTH_MULT := 2.2
const ELITE_DAMAGE_MULT := 1.3
const ELITE_SCALE := 1.25
const ELITE_COIN_CHANCE := 0.5
const GUARDIAN_HEALTH_MULT := 7.0
const GUARDIAN_DAMAGE_MULT := 1.5
const GUARDIAN_ESCORTS := 2

func _generate_enemy_data_for_room(room: Room) -> Array[Dictionary]:
	# floor_n = profundidad (reino 1..5, +0.5 en la 2a etapa), no el numero de piso 1..10: asi
	# la curva de vida/dano por reino es la de antes (ver RunManager.depth).
	var floor_n: float = RunManager.depth(_run_manager.current_floor)
	var fd: Dictionary = _run_manager.floor_data()
	var has_boss: bool = RunManager.floor_has_boss(_run_manager.current_floor)
	var count := RNG.randi_range(2, 4) + RunManager.depth_i(_run_manager.current_floor) + FloorEvents.extra_enemies()
	var elite_room: bool = room.has_meta("elite_room")  # sala elite (6b): todos elite, uno mas
	if elite_room:
		count += 1
	if room.room_type == Room.RoomType.MINIBOSS:
		count = 1 if fd.has("miniboss") else 2  # minijefe propio del piso (datos) o dos gigantes
	elif room.room_type == Room.RoomType.BOSS:
		count = 1 if has_boss else GUARDIAN_ESCORTS + 1
	elif room.has_meta("secret_boss"):
		count = 1
	
	# Must stay typed: Room.spawn_enemies() expects Array[Dictionary].
	var data: Array[Dictionary] = []
	for i in range(count):
		var info := {
			"health": (30.0 + floor_n * 10.0) * RNG.randf_range(0.85, 1.15),
			"damage": (ENEMY_DAMAGE_BASE + floor_n * 3.0) * RNG.randf_range(0.85, 1.15),
			"drops": [{"item_id": "coin", "chance": COIN_DROP_CHANCE * _coin_mult * Censura.mult("coin_drop")}, {"item_id": "health_small", "chance": 0.08},
				{"item_id": _random_loot_id(), "chance": 0.06}],
		}
		# El Perineo es tierra de nadie: mezcla bichos de los dos reinos.
		var roster: Array = fd.roster
		var names: Array = fd.names
		if fd.has("alt_roster") and RNG.randf() < 0.5:
			roster = fd.alt_roster
			names = fd.alt_names
		# id de EnemyRegistry por puesto del roster
		var types: Array = ["melee", "ranged", "swarmer"]
		var weights: Array = Utero.weights(room, fd.weights)  # El Utero: la menstruacion saca Calambres
		var its_kinds: Array = ["", "", ""]
		# bichos extra del piso (aparte del trio fijo): {variant, name, type, weight}
		for x in fd.get("extra", []):
			roster = roster + [x.variant]
			names = names + [x.name]
			types = types + [x.type]
			its_kinds = its_kinds + [x.get("its", "")]
			var w: float = x.weight
			if x.has("its") and room.room_type == Room.RoomType.INTOXICATION:
				w *= ITS_INTOX_WEIGHT_MULT
			weights = weights + [w]
		match room.room_type:
			Room.RoomType.SECRET when room.has_meta("secret_boss"):
				# PLAN 6: el Algoritmo Moderador, jefe secreto y opcional del Archivo (piso con "secret_boss").
				var sv := str(room.get_meta("secret_boss"))
				var region_s: int = RunManager.region_index(_run_manager.current_floor) + 1
				info.enemy_type = "boss"
				info.health = EnemyBoss.health_for_floor(region_s) * Censura.mult("boss_health")
				info.script = EnemyBoss.script_path(sv)
				info.damage = 12.0 + region_s * 4.0
				info.name = str(fd.get("secret_boss_name", sv))
				info.frames = _frames_path(sv)
				info.drops = [{"item_id": "health_large", "chance": 1.0}]
			Room.RoomType.BOSS when has_boss:
				var region_n: int = RunManager.region_index(_run_manager.current_floor) + 1  # el jefe escala por reino, como antes
				info.enemy_type = "boss"
				info.health = EnemyBoss.health_for_floor(region_n) * Censura.mult("boss_health")
				var bv := BossPicker.pick(fd, _run_manager.current_seed, _run_manager.current_floor)  # original o alternativo (6c)
				info.script = EnemyBoss.script_path(bv.variant)
				info.damage = 12.0 + region_n * 4.0
				info.name = bv.name
				info.frames = _frames_path(bv.variant)
				info.drops = [{"item_id": "health_large", "chance": 1.0}]
			Room.RoomType.BOSS when i == 0:
				# Sala final de la 1a etapa: guardian (minijefe reforzado) que abre la salida.
				info.enemy_type = "melee"
				info.health *= GUARDIAN_HEALTH_MULT
				info.damage *= GUARDIAN_DAMAGE_MULT
				info.name = tr("ENEMY_GIANT") % names[0]
				info.frames = _frames_path(roster[0])
				info.scale = 1.8
				info.elite = true
				info.drops.append({"item_id": "health_large", "chance": 1.0})
			Room.RoomType.MINIBOSS when fd.has("miniboss"):
				# Minijefe propio (Gran Urologo, Gran Candado): su script ya multiplica vida/dano y escala.
				var mb: Dictionary = fd.miniboss
				info.enemy_type = str(mb.type)
				info.name = str(mb.name)
				info.frames = _frames_path(str(mb.variant))
				info.drops.append({"item_id": "health_large", "chance": 1.0})
			Room.RoomType.MINIBOSS:
				info.enemy_type = "melee"
				info.health *= 3.5
				info.damage *= 1.4
				info.name = tr("ENEMY_GIANT") % names[0]
				info.frames = _frames_path(roster[0])
				info.scale = 1.6
				info.drops.append({"item_id": "health_large", "chance": 0.8})
			_:
				var t := _weighted_index(weights)
				for _try in range(6 if elite_room else 0):  # sin espinillas en la sala elite (no se refuerzan)
					if types[t] != "espinilla":
						break
					t = _weighted_index(weights)
				t = TaserSpecial.pick_index(t, types, _run_manager.current_floor)  # Vulvania 1: garantiza un Dildo Electrico
				info.enemy_type = types[t]
				info.name = names[t]
				info.frames = _frames_path(roster[t])
				if types[t] == "tank":
					info.health *= TANK_HEALTH_MULT
					info.damage *= TANK_DAMAGE_MULT
				if its_kinds[t] != "":
					var st: Dictionary = ITS_STATS[its_kinds[t]]
					info.its = its_kinds[t]
					info.health *= st.health
					info.damage *= st.damage
					info.speed = st.speed
				if types[t] == "espinilla":
					info.health *= ESPINILLA_HEALTH_MULT
					info.drops = [{"item_id": "coin", "chance": ESPINILLA_COIN_CHANCE}]
				if types[t] == "swarmer":
					# Los enjambres nunca vienen solos, pero cada bicho pega poco: rapidos y
					# debiles. Antes pegaban como un enemigo pesado y, de a tres desde el
					# piso 1, te encerraban y mataban en segundos.
					info.group = 2 if floor_n <= 2.0 else 3
					info.damage *= SWARM_DAMAGE_MULT
				if room.room_type == Room.RoomType.INTOXICATION:
					info.drops.append({"item_id": "whiskey", "chance": 0.5})
				# Elite: mas vida y dano, algo mas grande y con aura roja. Mas comunes en la 2a etapa.
				# (No toca a las espinillas: reventar de un tiro es su gracia.)
				# Las escoltas del guardian (sala final de la 1a etapa) siempre son elite.
				var escort: bool = (room.room_type == Room.RoomType.BOSS and not has_boss) or elite_room or FloorEvents.force_elite(room, i)
				if types[t] != "espinilla" and (escort or RNG.randf() < float(fd.get("elite_chance", 0.0)) * Censura.mult("elite_chance")):
					info.health *= ELITE_HEALTH_MULT
					info.damage *= ELITE_DAMAGE_MULT
					info.scale = ELITE_SCALE
					info.elite = true
					info.affixes = Affixes.roll(types[t], floor_n)  # 1-2 afijos (src/enemies/affixes)
					info.drops.append({"item_id": "coin", "chance": ELITE_COIN_CHANCE})
		Utero.data_tweak(room, info)  # El Utero (lutea): enemigos irritables
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
	p.position = local_pos  # _add_pickup_deferred lo lleva a suelo pisable
	room._add_pickup_deferred(p)

func _spawn_chest(room: Room, contents: String, offset := Vector2(0, -40)) -> void:
	var c := CHEST_SCENE.instantiate()
	c.contents = contents
	c.position = RoomUtil.loot_spot(room, room.get_center_position() + offset, [], null, 48.0)
	room.pickups_node.add_child.call_deferred(c)

func _build_shop(room: Room) -> void:
	if room.has_meta("shop_built"):
		return
	room.set_meta("shop_built", true)
	var stock := [_random_weapon_id(), _random_loot_id(), _random_loot_id()]
	stock[0] = BossDamage.shop_hint(_run_manager.floor_data(), stock[0])  # pista: arma que es debilidad del jefe del piso
	if _run_manager.floor_data().get("region", "") == "perineo" and not player.collected_items.has("lubricante_agua") and RNG.randf() < 0.55:
		stock[0] = "lubricante_agua"  # la tienda del Perineo a veces lo ofrece (secreto de la puerta biologica, sin decir nada)
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
		room.get_meta("puzzle").replay()  # al volver a entrar (la memoria repite la secuencia)
		return
	# Los acertijos no se explican: se silencia la frase generica con instrucciones y el
	# narrador solo comenta de pasada (puzzles.json); las pistas llegan tras fallar.
	Narrator._seen["puzzle_start"] = true
	Narrator.say_first("pz_start")
	var pz: Puzzle = PUZZLE_PLATES.create(room, _run_manager.current_seed * 31 + _run_manager.current_floor)
	pz.solved.connect(_on_puzzle_solved.bind(room))
	room.set_meta("puzzle", pz)
	room.props_node.add_child.call_deferred(pz)  # se entra desde un callback de fisica

func _on_puzzle_solved(room: Room) -> void:
	Narrator.say("puzzle_solved")
	get_node("/root/GlobalEvents").game_event.emit("puzzle_solved")  # medallas
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
		candidates = dungeon_generator.rooms.values().filter(func(r): return r.room_type == Room.RoomType.COMBAT and not r.has_meta("elite_room"))
	if candidates.is_empty():
		# Pisos sin minijefe ni combate normal (solo trampa/antro): sin esto la hormona solo
		# se podia comprar y, sin monedas, la Puerta Hormonal dejaba la partida sin salida.
		candidates = dungeon_generator.rooms.values().filter(func(r): return r.room_type in FIGHT_ROOMS)
	if not candidates.is_empty():
		_hormone_room = candidates[RNG.randi_range(0, candidates.size() - 1)]

# ---------------------------------------------------------------- color (la censura)
## Las salas nacen grises (censuradas) y recuperan el color al liberarlas.
func _paint_room(room: Room, colored: bool, animate := false) -> void:
	# Sin modulate: el arte de cada reino ya trae su color y el shader lo desatura/devuelve.
	colored = colored and not Silencio.active()  # el Silencio nunca recupera el color (aun)
	Censor.apply(room, room.floor_tilemap)
	Censor.apply(room, room.walls_tilemap)
	room.floor_tilemap.modulate = Color.WHITE
	room.walls_tilemap.modulate = Color.WHITE
	Censor.set_colored(room, colored, animate)
	_lighting.paint(room, colored, animate)

func _on_room_cleared(room: Room) -> void:
	if floor_completed:
		return
	rooms_cleared_this_floor += 1
	get_node("/root/RunManager").clear_room()
	if room.reward == "hormona" and _missing_hormones().is_empty():
		room.reward = "bendicion"  # ya la compraste en la tienda: algo a cambio
		room.reward_kingdom = _floor_kingdom()
	_paint_room(room, true, true)
	if room.has_meta("secret_boss"):
		_on_secret_boss_cleared(room)
	Utero.on_room_cleared(self, room)  # premios de cada fase del Utero
	Arcoiria.on_room_cleared(self, room)  # franja de la bandera de Arcoiria (y curas de los poderes)
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
		var n := BOSS_COINS_BASE + RunManager.depth_i(_run_manager.current_floor)
		RoomUtil.coins(self, room, n, room.get_center_position() + Vector2(0, 40))
		if not RunManager.floor_has_boss(_run_manager.current_floor):
			_complete_floor()  # 1a etapa: vencer al guardian abre la salida (sin jefe, sin liberar)
	else:
		Sound.play("room_clear")
		RoomUtil.coins(self, room, maxi(1, roundi(COINS_PER_ROOM_CLEAR * _coin_mult)), room.get_center_position() + Vector2(0, 60))

## PLAN 6: cae el Algoritmo Moderador (jefe secreto del Archivo). Marca la bandera persistente
## (RunManager.defeat_algoritmo: ya no hay copia de seguridad), da botin y una bendicion.
func _on_secret_boss_cleared(room: Room) -> void:
	_run_manager.defeat_algoritmo()
	get_node("/root/LoreDatabase").custom_event("copia_seguridad")  # codice
	Narrator.toast(tr("P6_ALG_TOAST_TITLE"), tr("P6_ALG_TOAST_BODY"), "7fd0ff")
	Narrator.say_raw(tr("P6_ALG_VENCIDO"))
	_spawn_chest(room, "weapon")
	RoomUtil.coins(self, room, 10 + 2 * RunManager.depth_i(_run_manager.current_floor), room.get_center_position() + Vector2(0, 70))
	get_tree().create_timer(2.5).timeout.connect(func():
		_offer_blessing(_floor_kingdom(), tr("P6_ALG_BLESSING")))

var _boss_fall_pos := Vector2.ZERO  # donde cayo el ultimo jefe (la notita de Vane aparece ahi)

func _complete_floor() -> void:
	if floor_completed:
		return
	floor_completed = true
	Sound.music("")
	Sound.play("floor_complete")
	var boss_room := current_room
	var floor_n: int = _run_manager.current_floor
	var boss_floor: bool = RunManager.floor_has_boss(floor_n)
	if RunManager.award_seal(floor_n):
		_run_manager.seal_gained.emit(RunManager.seals())
		Narrator.say("seal_gained")
		Narrator.toast(tr("SEAL_TOAST_TITLE"), tr("SEAL_TOAST_BODY") % [RunManager.seals(), RunManager.seals_needed()], "ffd75a")
	if RunManager.is_route_end(floor_n):
		var was_liberated := _run_manager.is_liberated(floor_n)
		_run_manager.liberate(floor_n)
		var ending := _run_manager.resolve_victory(floor_n, was_liberated)  # PLAN 6: copia de seguridad / completo / verdadero
		Narrator.say("victory")
		match ending:
			"copia":
				get_node("/root/LoreDatabase").custom_event("copia_seguridad")  # codice
				Narrator.say_raw(tr("P6_COPIA_NARR"))
				Narrator.say_raw(tr("P6_TOMADOS_NARR") % DesordenPanel.taken_names(_run_manager))
				if "silencio" in _run_manager.liberated:
					Narrator.say_raw(tr("P6_SILENCIO_PAZ"))  # sin humor: el Silencio no vuelve
			"completo":
				Narrator.say_raw(tr("P6_COMPLETO_NARR"))
			"verdadero":
				Narrator.say_raw(tr("P6_VERDADERO_NARR"))
		if ending not in ["verdadero", "copia"] and not _run_manager.pending_regions().is_empty():
			Narrator.say_raw(tr("DESORDEN_NARR") % DesordenPanel.pending_names(_run_manager))
		get_node("/root/LoreDatabase").custom_event("victory")
		_run_manager.end_run(true)
		var end_wait := 8.0 if ending in ["copia", "verdadero"] else 4.0
		if VaneWinks.drop_note(boss_room, _boss_fall_pos):  # guiño a Vanessa: la notita bajo el jefe final
			end_wait = 10.0  # tiempo de encontrarla
		if _run_manager.last_censura_unlocked > 0:  # Censura: ganar abre el nivel siguiente (ver RunManager.end_run)
			Narrator.say("censura_up")
			Narrator.toast(tr("CENSURA_UNLOCKED_TITLE"), tr("CENSURA_UNLOCKED_BODY") % _run_manager.last_censura_unlocked, "ff4f9a")
		get_tree().create_timer(end_wait).timeout.connect(func(): Transition.change_scene("res://src/scenes/game_over.tscn"))
		return
	get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position, tr("FX_FLOOR_DONE") % floor_n, Color.GOLD)
	if boss_floor:
		# Vencer al jefe libera el reino entero (sus dos etapas); el toast usa el nombre del reino.
		if _run_manager.liberate(floor_n):
			Narrator.toast(tr("FLOOR_LIBERATED_TITLE"), tr("FLOOR_LIBERATED_BODY") % Loc.region_name(floor_n), "ffd75a")
		Utero.on_boss_dead(self)  # Dona Regla: bendicion de ciclo + codice
		# Recompensa: una mejora a elegir. Luego, sin prisa: recoges el botin y bajas por la escotilla.
		await get_tree().create_timer(1.5).timeout
		Narrator.choose(tr("FLOOR_BOSS_DEFEATED"), BOSS_REWARDS.map(func(r): return tr(r[0])))
		var pick: Array = BOSS_REWARDS[await Narrator.chosen]
		_game_controller.get_player_stats().apply_stat_mod(pick[1], pick[2])
		Sound.play("puzzle_solve")
		Utero.cycle_blessing(self)  # Dona Regla: ademas, una bendicion de ciclo
		_templo_reward(boss_room)  # El Coprolito: reliquia y bendicion propias del Templo de Anubis
	else:
		await get_tree().create_timer(1.5).timeout  # guardian vencido: sin mejora, solo la salida
	open_exit(boss_room, floor_n)


## Recompensa propia del Templo de Anubis al vencer a El Coprolito: el Anj de Anubis (reliquia) y una bendicion.
func _templo_reward(boss_room: Room) -> void:
	if _run_manager.floor_region(_run_manager.current_floor) != "puerta_trasera":
		return
	get_node("/root/LoreDatabase").custom_event("templo_anubis_coprolito")
	_spawn_pickup(boss_room, "ankh_anubis", boss_room.get_center_position() + Vector2(0, -90))
	Narrator.toast(tr("TA_REWARD_TOAST"), "", "ffd75a")
	_offer_blessing(_floor_kingdom(), tr("TA_BLESSING_TITLE"))


## La salida del piso: una puerta por reino si hay que elegir, o el portal al siguiente piso.
## `at` = donde se pone, relativo al centro de la sala; `hatch_text` = el cartel del portal (vacio = el de
## siempre). La usa _complete_floor y, sin jefe ni guardian, el Silencio (src/silencio: salida de S4).
func open_exit(boss_room: Room, floor_n: int, at := Vector2(0, 150), hatch_text := "") -> void:
	if hatch_text == "" and _open_exit_doors(boss_room):
		return
	# FloorPortal: solo la escotilla entre las etapas de un reino (y la salida del Silencio y casos sin puertas);
	# el portal de eleccion de reino ya no se usa para viajar entre reinos (depuracion F1 aparte).
	var already := floor_n < RunManager.route_floors.size()
	var options: Array = RunManager.next_options() if RunManager.route_dynamic and not already else []
	var portal := _hatch_visual()
	_add_prop(boss_room, boss_room.get_center_position() + at, portal,
		hatch_text if hatch_text != "" else tr("FLOOR_HATCH") % (floor_n + 1),
		func(p, it):
			it.finish()
			await portal.absorb(p)  # el heroe se encoge y gira hacia el centro antes de bajar
			if options.size() == 1:
				RunManager.add_region(str(options[0]))
			_advance_to_next_floor()
			FloorPortal.restore(p))


## PASILLOS: al generar el piso, las puertas de salida de la sala del jefe (las crea dungeon_generator) nacen
## SELLADAS y con su cartel (reino destino y, si es del centro, los sellos); la Puerta Trasera (desvio de
## routes.json) es un iris biologico sellado en la pared sur.
func _arm_exit_doors() -> void:
	exit_doors.clear()
	var boss: Room = null
	for r in dungeon_generator.rooms.values():
		if r.room_type == Room.RoomType.BOSS:
			boss = r
	if boss == null:
		return
	for door: Door in boss.doors.values():
		if not door.has_meta("exit_region"):
			continue
		exit_doors.append(door)
		door.set_state(Door.State.SEALED)
		var region := str(door.get_meta("exit_region"))
		var text := Loc.region_name_id(region)
		if region in RunManager.center_regions():
			text += "\n" + tr("PAS_DOOR_SEALS") % [RunManager.seals() + (1 if RunManager.would_award_seal(_run_manager.current_floor) else 0), RunManager.seals_needed()]
		door.set_hint(text, RunManager.region_tint(region).lerp(Color.WHITE, 0.35))
		_add_emblem(door, RunManager.region_tint(region))
	# desvio opcional (la entrada de servicio del Perineo -> Templo de Anubis): puerta biologica con su condicion secreta
	var detour: Dictionary = RunManager.detour_for(RunManager.floor_region(_run_manager.current_floor)) if not exit_doors.is_empty() and not RunManager.rescue_mode else {}
	if detour.is_empty():
		return
	var size_px := Vector2(dungeon_generator.room_sizes.get(boss.grid_pos, Vector2i(8, 6))) * 64.0
	var taken: Array = boss.doors.values().map(func(dd): return dd.position)
	var inward := {"up": Vector2.DOWN, "down": Vector2.UP, "left": Vector2.RIGHT, "right": Vector2.LEFT}
	var ok := func(pos: Vector2, dir: String) -> bool:
		return boss.is_walkable(pos + (inward[dir] as Vector2) * 40.0, 18.0)
	for it in Pasillos.layout([{"region": str(detour.get("to", "")), "dir": "up", "along": 0.0}], taken, size_px, ok):
		var iris := IrisDoor.new()
		iris.wall_dir = it.dir
		iris.position = it.pos + (inward[it.dir] as Vector2) * (50.0 if it.dir == "up" else -6.0)  # en la pared norte la camara corta su borde: se baja al suelo para que se vea entera
		iris.set_meta("exit_region", it.region)
		iris.can_open = bool(detour.get("open", false)) and str(detour.get("to", "")) in RunManager.regions()
		boss.props_node.add_child(iris)
		iris.entered.connect(_on_iris_entered.bind(iris))
		if it.dir == "up":
			TemploAnubis.flank(iris, boss.props_node)  # dos estatuas de Anubis, inscripcion muda y graffiti


## Emblema del reino: rombo de su color junto al cartel de la puerta.
func _add_emblem(door: Door, tint: Color) -> void:
	var out := {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}[door.get_direction_name()] as Vector2
	var pos := -out * 82.0 if door.direction < 2 else -out * 52.0 + Vector2(0, -36)
	var rim := Polygon2D.new()
	rim.polygon = PackedVector2Array([Vector2(0, -12), Vector2(12, 0), Vector2(0, 12), Vector2(-12, 0)])
	rim.color = Color("0d0b0f")
	rim.position = pos
	var em := Polygon2D.new()
	em.polygon = PackedVector2Array([Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0)])
	em.color = tint
	em.position = pos
	door.add_child(rim)
	door.add_child(em)


## Vencido el jefe: las puertas de salida se ABREN (animacion de la puerta + sonido). false si el piso no las tiene.
func _open_exit_doors(boss_room: Room) -> bool:
	for n in get_tree().get_nodes_in_group("iris_door"):
		n.armed = true  # vencido el jefe, la puerta biologica ya puede abrirse (con su condicion secreta)
	var doors := exit_doors.filter(func(d): return is_instance_valid(d))
	if doors.is_empty():
		return false
	Sound.play("door")
	for door: Door in doors:
		door.remove_meta("hold_sealed")
		door.set_state(Door.State.OPEN)
	return true


func _on_exit_door_used(door: Door) -> void:
	if corridor_active or _exit_busy:
		return
	_exit_busy = true
	_begin_corridor(RunManager.floor_region(_run_manager.current_floor), str(door.get_meta("exit_region")), door.get_direction_name())


## La puerta biologica abierta: tobogan al Templo de Anubis.
func _on_iris_entered(iris: IrisDoor) -> void:
	if corridor_active or _exit_busy:
		return
	_exit_busy = true
	_begin_corridor(RunManager.floor_region(_run_manager.current_floor), str(iris.get_meta("exit_region")), "up")


## Fundido a negro (alfa 1) o de vuelta (0). Capa propia sobre el HUD, bajo la cortinilla de escenas.
func _fade_to(alpha: float, time: float) -> void:
	if _fade == null:
		_fade_layer = CanvasLayer.new()
		_fade_layer.layer = 90
		_fade = ColorRect.new()
		_fade.color = Color.BLACK
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.modulate.a = 0.0
		_fade_layer.add_child(_fade)
		add_child(_fade_layer)
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", alpha, time)
	await tw.finished


## Cruza la puerta de un reino: fundido, el piso se reemplaza por el pasillo de transicion (sala alargada
## que mezcla los dos reinos) y el heroe aparece en su extremo de salida. Al llegar al final (_corridor_step)
## entra al reino nuevo.
func _begin_corridor(from_r: String, to_r: String, dir: String) -> void:
	var rm := _run_manager
	var fl: int = rm.current_floor
	_corridor = {"from": from_r, "to": to_r, "dir": dir, "add": fl >= RunManager.route_floors.size(), "fl": fl,
		"seed": rm.current_seed + fl * 7919, "switched": false, "enc_done": false}
	var slide := to_r in RunManager.detour_regions()  # la Puerta Trasera se entra CAYENDO por un tobogan organico
	if slide:
		dir = "down"
	_corridor.slide = slide
	_corridor.enc = {} if slide else CorridorEncounter.roll(int(_corridor.seed), from_r, to_r)  # encuentro aleatorio (~30%)
	if has_meta("map_key") and get_meta("map_seed", -1) == rm.current_seed and not dungeon_generator.rooms.is_empty():
		rm.floor_maps[get_meta("map_key")] = MapMetroid.snapshot(self)  # foto del piso que dejas (mapa del mundo)
	set_meta("map_seed", -1)  # el pasillo no es un piso: _generate_dungeon no vuelve a fotografiar
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	await _fade_to(1.0, 0.35)
	if current_room:
		current_room.on_player_exit()
	if dungeon_root:
		dungeon_root.queue_free()
	exit_doors.clear()
	var room := Corridor.build(from_r, to_r, dir, int(_corridor.seed), slide)
	dungeon_root = Node2D.new()
	dungeon_root.name = "Corridor_%s_%s" % [from_r, to_r]
	add_child(dungeon_root)
	dungeon_root.add_child(room)
	dungeon_generator.rooms = {Vector2i.ZERO: room}
	dungeon_generator.room_sizes = {Vector2i.ZERO: Corridor.size_for(dir)}
	dungeon_generator.room_graph = {Vector2i.ZERO: []}
	dungeon_generator.main_path = []
	dungeon_generator.elite_rooms = []
	current_room = room
	visited_rooms.clear()
	visited_rooms[Vector2i.ZERO] = true
	room.cleared = true
	await get_tree().process_frame  # la sala entra al arbol (@onready)
	Corridor.finish_setup(room, int(_corridor.seed), fl)
	_lighting.setup_floor(dungeon_generator.rooms, fl, int(_corridor.seed))
	_lighting.enter_room(room)
	_paint_room(room, true)
	Sound.music("explore_" + from_r)
	player.global_position = room.global_position + Corridor.start_pos(room)
	player.velocity = Vector2.ZERO
	_update_camera_limits(room)
	camera.reset_smoothing()
	_corridor_bar = CorridorBar.new()
	_corridor_bar.from_name = Loc.region_name_id(from_r)
	_corridor_bar.to_name = Loc.region_name_id(to_r)
	_corridor_bar.color_a = RunManager.region_tint(from_r)
	_corridor_bar.color_b = RunManager.region_tint(to_r)
	var bar_layer := CanvasLayer.new()
	bar_layer.name = "CorridorBarLayer"
	bar_layer.layer = 30
	bar_layer.add_child(_corridor_bar)
	add_child(bar_layer)
	corridor_active = true
	if slide:
		await _fade_to(0.0, 0.35)
		_exit_busy = false
		_run_slide(room)
		return
	player.set_physics_process(true)
	await _fade_to(0.0, 0.35)
	_exit_busy = false


## TOBOGAN a la Puerta Trasera: el heroe cae por el tubo, cada vez mas rapido (2,6 s), dando vueltas y gritando;
## la camara lo sigue. Al llegar (corridor_step) se entra al reino y aterriza con rebote (_slide_landing).
func _run_slide(room: Room) -> void:
	var cl: PackedVector2Array = room.get_meta("corridor_cl")
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	var spr: Node2D = player.get("animated_sprite")
	var dur := 2.6
	var ge := get_node("/root/GlobalEvents")
	var tw := create_tween()
	tw.tween_method(_slide_step.bind(room, cl, spr), 0.0, 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for pair in [[0.2, "¡WIII!"], [1.1, "¡WIIIII!"], [1.9, "¡¡WIIIIIII!!"]]:
		get_tree().create_timer(float(pair[0])).timeout.connect(func():
			if corridor_active and is_instance_valid(player):
				ge.show_floating_text.emit(player.global_position + Vector2(0, -30), str(pair[1]), Color("ffd0f0")))
	for t in [0.5, 1.4, 2.2]:
		get_tree().create_timer(float(t)).timeout.connect(func():
			if corridor_active:
				Sound.play("suck")
				if spr:
					HitFx.flash(spr))


func _slide_step(t: float, room: Room, cl: PackedVector2Array, spr: Node2D) -> void:
	if not is_instance_valid(player) or not corridor_active or not is_instance_valid(room):
		return
	var idx := t * float(cl.size() - 1)
	var i := mini(floori(idx), cl.size() - 2)
	var pos := cl[i].lerp(cl[i + 1], idx - float(i)) + Vector2(sin(t * 18.0) * 22.0, 0.0)
	player.global_position = room.global_position + pos
	if spr:
		spr.rotation = t * TAU * 3.0


## Aterrizaje con rebote tras el tobogan (el heroe llega aplastado y rebota).
func _slide_landing() -> void:
	var spr: Node2D = player.get("animated_sprite")
	if spr == null:
		return
	spr.rotation = 0.0
	spr.scale = Vector2(1.4, 0.55)
	var tw := create_tween()
	tw.tween_property(spr, "scale", Vector2(0.85, 1.25), 0.14)
	tw.tween_property(spr, "scale", Vector2(1.12, 0.9), 0.12)
	tw.tween_property(spr, "scale", Vector2.ONE, 0.12)
	Sound.play("crack")
	get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -34), "¡PLOF!", Color("ffd0f0"))


## Avance 0..1 del heroe por el pasillo actual.
func corridor_progress() -> float:
	if not corridor_active or current_room == null:
		return 0.0
	return Corridor.progress(current_room, player.global_position - current_room.global_position)


func _corridor_step() -> void:
	if _corridor.is_empty() or _exit_busy:
		return
	var p := corridor_progress()
	if _corridor_bar:
		_corridor_bar.set_value(p)
	var enc: Dictionary = _corridor.get("enc", {})
	if not enc.is_empty() and not _corridor.enc_done and p >= float(enc.at):
		_corridor.enc_done = true
		CorridorEncounter.run(self, enc.types)
	if p >= 0.5 and not _corridor.switched:
		_corridor.switched = true
		Sound.music("explore_" + str(_corridor.to))  # a mitad de camino suena ya el reino nuevo
	if p >= 0.97 and player.global_position.distance_to(current_room.global_position + Corridor.end_pos(current_room)) < 90.0:
		_finish_corridor()


## Fin del pasillo: fundido, el reino nuevo entra a la ruta (si hace falta) y se genera su primer piso
## (el cartel con su nombre sale solo: _show_floor_card).
func _finish_corridor() -> void:
	_exit_busy = true
	var c := _corridor
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	await _fade_to(1.0, 0.4)
	if c.add:
		RunManager.add_region(str(c.to))
	_advance_to_next_floor()
	player.set_physics_process(true)
	if c.get("slide", false):
		_slide_landing()
	await get_tree().create_timer(0.1).timeout
	await _fade_to(0.0, 0.5)
	_exit_busy = false

## [texto, stat, cantidad] (apply_stat_mod, valores fijos que se suman).
const BOSS_REWARDS := [
	["BOSS_REWARD_HEALTH", "max_health_flat", 10.0],
	["BOSS_REWARD_STAMINA", "max_stamina_flat", 15.0],
	["BOSS_REWARD_SHIELD", "max_shields_flat", 10.0],
]

# ---------------------------------------------------------------- recompensas por sala
## Cada sala de pelea anuncia en su puerta lo que da al limpiarla: el camino
## por el piso es una decision, no un pasillo.
const FIGHT_ROOMS := [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP, Room.RoomType.MINIBOSS]
const KINGDOM_COLORS := {"pene": Color("6ec6ff"), "vulva": Color("ff7ac0"), "mixto": Color("ffc93c")}
const KINGDOM_NAMES := {"pene": "KINGDOM_PENE", "vulva": "KINGDOM_VULVA"}

## Nombre visible del reino (MAYUSCULAS); los que no estan (mixto) salen como MIXTA.
func _kingdom_name(k: String) -> String:
	return tr(KINGDOM_NAMES.get(k, "KINGDOM_MIXED"))
## Sala del cofre del arma inicial (su puerta dice ARMA mientras vayas desarmado).
var _weapon_room: Room = null

## Reino de las bendiciones de este piso: el suyo casi siempre, si tiene.
func _floor_kingdom() -> String:
	var k: String = _run_manager.floor_data().kingdom
	if k in ["pene", "vulva"] and RNG.randf() < 0.7:
		return k
	return "pene" if RNG.randf() < 0.5 else "vulva"

func _compute_coin_mult() -> float:
	var fights := dungeon_generator.rooms.values().filter(func(r): return r.room_type in FIGHT_ROOMS and not r.has_meta("elite_room")).size()
	return clampf(COIN_BASE_FIGHTS / maxf(fights, 1.0), 0.6, 1.2)

func _assign_rewards() -> void:
	var fights: Array = dungeon_generator.rooms.values().filter(func(r): return r.room_type in FIGHT_ROOMS)
	RNG.shuffle(fights)
	var blessed := 0
	for room in fights:
		if room.has_meta("elite_room"):
			room.reward = "elite"  # premio gordo (ver _give_reward); no cuenta como bendicion
			continue
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
		if door.has_meta("exit_region"):
			continue  # el cartel de las puertas de salida lo pone _arm_exit_doors
		var target: Room = dungeon_generator.rooms.get(door.target_pos)
		var hint := ["", Color("f2ead6")]
		if target and not target.cleared:
			hint = _room_hint(target)
		door.set_hint(hint[0], hint[1])

func _room_hint(room: Room) -> Array:
	if room.room_type == Room.RoomType.SILENCIO:
		return ["", Color.WHITE]
	if MonteVenus.is_monte(room):
		return [tr("MONTE_DOOR_HINT"), Color("f06aa0")]
	if room.has_meta("elite_room") and not room.cleared:
		return [tr("DOOR_HINT_ELITE"), Color("ff6a3a")]
	if room == _weapon_room and not _has_real_weapon():
		return [tr("DOOR_HINT_WEAPON"), Color("ffa64a")]
	match room.room_type:
		Room.RoomType.BOSS:
			if not RunManager.floor_has_boss(_run_manager.current_floor):
				return [tr("DOOR_HINT_GUARD"), Color("ff9a50")]
			return [tr("DOOR_HINT_BOSS"), Color("ff5050")]
		Room.RoomType.SHOP: return [tr("DOOR_HINT_SHOP"), Color("ffd75a")]
		Room.RoomType.REST: return [tr("DOOR_HINT_REST"), Color("6aa8ff")] if not room.has_meta("calm_built") else ["", Color.WHITE]
		Room.RoomType.TREASURE: return [tr("DOOR_HINT_TREASURE"), Color("ffd75a")] if not room.has_meta("calm_built") else ["", Color.WHITE]
		Room.RoomType.LORE: return [tr("DOOR_HINT_LORE"), Color("c08cff")] if not room.has_meta("calm_built") else ["", Color.WHITE]
		Room.RoomType.PUZZLE: return [tr("DOOR_HINT_PUZZLE"), Color("c08cff")]
	var head := tr("DOOR_HINT_MINIBOSS") if room.room_type == Room.RoomType.MINIBOSS else ""
	match room.reward:
		"bendicion":
			var k := room.reward_kingdom
			var warn := ("\n" + tr("DOOR_HINT_ALLERGY")) if _run_manager.is_foreign(k) else ""
			return [head + tr("DOOR_HINT_BLESSING") + "\n" + _kingdom_name(k) + warn, KINGDOM_COLORS[k]]
		"monedas": return [head + tr("DOOR_HINT_COINS"), Color("ffd75a")]
		"vida": return [head + tr("DOOR_HINT_LIFE"), Color("ff6b6b")]
		"hormona": return [head + tr("DOOR_HINT_HORMONE"), Color("c08cff")]
	return [head + tr("DOOR_HINT_FIGHT"), Color(0.6, 0.6, 0.65)]

func _give_reward(room: Room) -> void:
	var center := room.get_center_position()
	match room.reward:
		"monedas":
			var n := maxi(2, roundi((4 + RunManager.depth_i(_run_manager.current_floor)) * _coin_mult))
			RoomUtil.coins(self, room, n, center + Vector2(0, -30))
		"elite":
			# Sala elite: cofre de arma y botin grande (premio por el riesgo, fuera del camino).
			Narrator.toast(tr("ELITE_CLEAR_TITLE"), tr("ELITE_CLEAR_BODY"), "ff7a4a")
			Narrator.say("elite_clear")
			_spawn_chest(room, "weapon", Vector2(0, -40))
			var ne := 8 + 2 * RunManager.depth_i(_run_manager.current_floor)
			RoomUtil.coins(self, room, ne, center + Vector2(0, 70))
			_spawn_pickup(room, "health_large", center + Vector2(-90, 20))
		"vida":
			_spawn_pickup(room, "health_large", center + Vector2(0, -30))
		"bendicion":
			await get_tree().create_timer(0.7).timeout
			_offer_blessing(room.reward_kingdom, tr("BLESSING_PICK") % _kingdom_name(room.reward_kingdom).capitalize())

func _offer_blessing(kingdom: String, title: String) -> void:
	var ids: Array = _run_manager.roll_blessings(kingdom)
	Narrator.say_first("blessing_first")
	var picker := BlessingPicker.open(self, title, ids)
	_take_blessing(ids[await picker.picked])

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
	if MonteVenus.is_monte(room):
		MonteVenus.build(self, room)  # Monte de Venus de la Selva (src/dungeon/monte_venus.gd)
		return
	var center := room.get_center_position()
	match room.room_type:
		Room.RoomType.TREASURE:
			_spawn_chest(room, "")
			RoomUtil.coins(self, room, 3, center + Vector2(0, 30))
		Room.RoomType.REST:
			var water := _disc(20, Color("4aa3df"))
			var fountain := Node2D.new()
			fountain.add_child(_disc(28, Color("cfc4ae")))
			fountain.add_child(water)
			_add_prop(room, center, fountain,
				tr("PROP_FOUNTAIN"),
				func(_p, it):
					var ps = _game_controller.get_player_stats()
					ps.heal(ps.max_health)
					ps.current_stamina = ps.max_stamina
					ps.stamina_changed.emit(ps.current_stamina, ps.max_stamina)
					water.color = Color(0.35, 0.35, 0.38)
					Sound.play("room_clear")
					Narrator.toast(tr("PROP_FOUNTAIN_TOAST_TITLE"), tr("PROP_FOUNTAIN_TOAST_BODY"))
					it.finish())
			Consultorio.build(self, room)  # consultorio opcional (src/edu)
		Room.RoomType.LORE:
			var stone := Polygon2D.new()
			stone.polygon = PackedVector2Array([Vector2(-18, 26), Vector2(-18, -18), Vector2(-10, -28), Vector2(10, -28), Vector2(18, -18), Vector2(18, 26)])
			stone.color = Color("8a8494")
			stone.set_meta("tall", true)
			_add_prop(room, center, stone,
				tr("PROP_INSCRIPTION"),
				func(_p, it):
					_read_inscription()
					stone.color = Color("5a5662")
					it.finish())
			MitoVerdad.build(self, room)  # Mito o Verdad opcional (src/edu)

## Lee una entrada de historia (mundo, personajes, lugares, enemigos), mejor una nueva.
func _read_inscription() -> void:
	var lore = get_node("/root/LoreDatabase")
	var pool: Array = lore.get_all_entries().filter(func(e): return e.category in [0, 1, 3, 4, 5])
	var fresh := pool.filter(func(e): return not e.unlocked)
	var entry = (fresh if not fresh.is_empty() else pool)[RNG.randi_range(0, (fresh if not fresh.is_empty() else pool).size() - 1)]
	lore.unlock_entry(entry.id)
	Narrator.say_raw(tr("PROP_INSCRIPTION_SAY") % [Loc.lore_title(entry), Loc.lore_text(entry)])

func _add_prop(room: Room, pos: Vector2, visual: Node2D, text: String, on_use: Callable) -> void:
	var it := INTERACTABLE.new()
	it.position = pos
	it.prompt_text = text
	it.add_child(visual)
	_prop_shadow(it, visual)
	TallProp.attach_visual(it, visual)  # alto: el heroe pasa por detras (src/fx/tall_prop.gd)
	it.used.connect(on_use.bind(it))
	room.props_node.add_child.call_deferred(it)

## Sombra de contacto (y proyectada si el dibujo es alto) segun el tamano del dibujo.
func _prop_shadow(it: Node2D, visual: Node2D) -> void:
	if visual.has_meta("flat"):
		return
	var polys: Array = visual.get_children().filter(func(c): return c is Polygon2D)
	if visual is Polygon2D:
		polys.append(visual)
	if polys.is_empty():
		return
	var r := 0.0
	var foot := 0.0
	for c in polys:
		for pt in c.polygon:
			r = maxf(r, absf(pt.x))
			foot = maxf(foot, pt.y)
	LightKit.add_contact_shadow(it, r + 4.0, foot + 2.0)
	if visual.has_meta("tall"):
		LightKit.mark_caster(it, r, foot + 2.0)

func _disc(radius: float, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(Vector2.RIGHT.rotated(TAU * i / 24) * radius)
	p.polygon = pts
	p.color = color
	return p

## Plaza de un reino liberado, recorrido en paz (run de rescate, RunManager.begin_rescue): UNA sala
## ya a color, sin enemigos, monedas ni cofres (no se puede farmear). Dos carteles que celebran
## (texto corto por reino en desordenes.csv) y el portal al siguiente tramo.
func _build_peace(room: Room) -> void:
	room.set_meta("calm_built", true)
	var region := RunManager.floor_region(_run_manager.current_floor)
	var center := room.get_center_position()
	var key := "DESORDEN_PAZ_%s_" % region.to_upper()
	if tr(key + "0") == key + "0":
		key = "DESORDEN_PAZ_GENERICO_"  # reino sin textos propios (uno nuevo): frases genericas
	Narrator.toast(tr("DESORDEN_PAZ_TITULO"), Loc.region_name_id(region), "7fe0a0")
	get_tree().create_timer(1.2).timeout.connect(func(): Narrator.say_raw(tr(key + "0")))
	for i in 2:
		var board := Polygon2D.new()  # cartel: tabla con poste
		board.polygon = PackedVector2Array([Vector2(-26, -34), Vector2(26, -34), Vector2(26, -6), Vector2(4, -6), Vector2(4, 24), Vector2(-4, 24), Vector2(-4, -6), Vector2(-26, -6)])
		board.color = Color("d8b86a")
		board.set_meta("tall", true)
		var text := tr(key + str(i + 1))
		_add_prop(room, center + Vector2(-110 + i * 220, -60), board, tr("DESORDEN_CARTEL"),
			func(_p, _it):
				Narrator.say_raw(text)
				Sound.play("puzzle_solve"))  # se puede releer: sin it.finish()
	var portal := _hatch_visual()
	_add_prop(room, center + Vector2(0, 110), portal, tr("DESORDEN_PAZ_PORTAL"),
		func(p, it):
			it.finish()
			await portal.absorb(p)
			_advance_to_next_floor()
			FloorPortal.restore(p))

## Portal de salida (src/fx/floor_portal.gd): arte y luz del reino; gris si el reino sigue censurado.
func _hatch_visual() -> FloorPortal:
	var floor_n: int = _run_manager.current_floor
	return FloorPortal.create(RunManager.floor_region(floor_n), _run_manager.is_liberated(floor_n))

func _advance_to_next_floor() -> void:
	# Antes llamaba a RunManager.next_floor(), que no existe: el juego reventaba aqui.
	_end_corridor_state()
	_run_manager.advance_floor()
	rooms_cleared_this_floor = 0
	floor_completed = false
	current_room = null
	if dungeon_root:
		dungeon_root.queue_free()
	_generate_dungeon()

## Limpia lo del pasillo (barra de progreso, puertas de salida) antes de generar el siguiente piso.
func _end_corridor_state() -> void:
	corridor_active = false
	_corridor = {}
	exit_doors.clear()
	if _corridor_bar and is_instance_valid(_corridor_bar):
		_corridor_bar.get_parent().queue_free()
	_corridor_bar = null


func _show_floor_card() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	var label := Label.new()
	var floor_n: int = _run_manager.current_floor
	label.text = tr("FLOOR_CARD") % [floor_n, Loc.floor_name(_run_manager.floor_data())]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	# fuente pixel como el resto del HUD, crema con sombra dura (el color del piso
	# se perdia contra el suelo del mismo tono)
	HudStyle.style_label(label, 48, HudStyle.CREAM, true)
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	layer.add_child(label)
	# Indicador discreto bajo el nombre del piso: nivel de Censura y maldiciones de pactos mayores.
	var below := 190
	if Censura.level > 0:
		_floor_card_line(layer, tr("CENSURA_BADGE") % Censura.level, below, 20)
		below += 52
	if not Censura.pact_curses.is_empty():
		var names: Array = Censura.pact_curses.map(func(id): return Censura.curse_name(id))
		_floor_card_line(layer, "%s: %s" % [tr("PAUSE_PACTS"), " · ".join(names)], below, 16)
	add_child(layer)
	var tw := label.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(label, "modulate:a", 0.0, 0.8)
	tw.tween_callback(layer.queue_free)

func _floor_card_line(layer: CanvasLayer, text: String, offset_top: int, size: int) -> void:
	var cl := Label.new()
	cl.text = text
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cl.offset_top = offset_top
	HudStyle.style_label(cl, size, Color("ff4f9a"), true)
	layer.add_child(cl)

func _on_enemy_killed(enemy: Node, killer: Node) -> void:
	if enemy.is_in_group("boss"):
		_boss_fall_pos = (enemy as Node2D).global_position if enemy is Node2D else player.global_position
		if current_room == null or not current_room.has_meta("secret_boss"):
			_complete_floor()  # (el jefe secreto no cierra el piso: ver _on_secret_boss_cleared)
	if killer == player:
		var regen: int = _run_manager.blessing("regla")
		if regen > 0:
			_game_controller.get_player_stats().heal(regen)
		get_node("/root/RunManager").total_enemies_killed += 1
		get_node("/root/RunManager").total_damage_dealt += enemy.max_health  # Approximate
	# La sala se comprueba con cualquier muerte (la espinilla que revienta sola, explosiones,
	# invocados...), no solo las del jugador; room_cleared() ya respeta oleadas y clear_gate.
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
	floating_text_mgr.spawn(position, "%.0f" % amount, HudStyle.GOLD if is_crit else Color("ff3b4a"), is_crit)

func _on_show_hero_number(position: Vector2, text: String, color: Color, big: bool) -> void:
	floating_text_mgr.spawn(position, text, color, false, 24 if big else 18)

func _on_show_floating_text(position: Vector2, text: String, color: Color) -> void:
	floating_text_mgr.spawn(position, text, color)

func _on_player_died() -> void:
	_ending = true
	# player_died is emitted from PlayerStats.take_damage(), which runs inside the
	# player's Hurtbox area_entered callback. Freeing the scene from there removes
	# CollisionObject nodes mid physics callback, which Godot rejects.
	Transition.change_scene("res://src/scenes/game_over.tscn")

func _exit_tree() -> void:
	get_node("/root/GlobalEvents").enemy_killed.disconnect(_on_enemy_killed)
	get_node("/root/GlobalEvents").player_died.disconnect(_on_player_died)
	get_node("/root/GlobalEvents").show_damage_number.disconnect(_on_show_damage_number)
	get_node("/root/GlobalEvents").show_floating_text.disconnect(_on_show_floating_text)