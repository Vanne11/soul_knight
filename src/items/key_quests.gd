extends Node
class_name KeyQuests

## Una mision de llave por piso (la crea Door._ready la primera vez, sin tocar main.gd):
## una llave con personalidad, custodiada en una sala, y un cofre con candado en otra.
##   crystal  llave de cristal: se rompe si te golpean mientras la llevas.
##   drunk    llave borracha: solo se deja coger y girar estando intoxicado; sobrio se
##            te escapa de las manos (hay botellas en la sala de la llave y junto al cofre).
##   blood    llave de sangre: se obtiene dejando vida en un altar; se seca a los 80 s
##            y el altar vuelve a pedir sangre. Abre el premio grande con emboscada.
##   master   llave maestra: la lleva un ladron que HUYE (si escapa, vuelve custodiada).
##            Abre cualquier cofre y las puertas con candado (door.gd).
##   belt     cinturon de castidad: el cofre lleva cadenas y candado; la llave esta en
##            otra sala, custodiada.
## Si una llave se pierde (se rompe, se escurre, se seca, el ladron huye) VUELVE a su sitio
## original y reaparecen sus custodios. La dificultad sale de PuzzleFactory.depth().

const KEY_IDS := {"crystal": "key_crystal", "drunk": "key_drunk", "blood": "key_bloody", "master": "key_master", "belt": "key_belt"}
const COLORS := {"crystal": "9be8ff", "drunk": "e0a93a", "blood": "c0283a", "master": "ffd75a", "belt": "c9c9d6"}
## Solo para pruebas: fuerza la clase de llave del piso ("" = al azar).
static var force_kind := ""
const SLIP_SECS := 2.5
const DRY_SECS := 80.0

var main: Node
var rng := RandomNumberGenerator.new()
var kind := ""
var key_id := ""
var home: Room            # sala de la llave (o del altar de sangre)
var vault: Room           # sala del cofre
var state := "none"       # none | home | carried | free | done
var key_node: KeyPickup
var chest: LockedChest
var altar: BloodAltar
var bottles: Array[DrunkBottle] = []
var ready_ok := false
var bot_gave_up := false
var _key_spot := Vector2.ZERO
var _follower: KeyFollower
var _guards: Array = []
var _guards_pending := false
var _fug_pending := false
var fugitive: Enemy
var _last_room: Room
var _sober_t := 0.0
var _dry_t := 0.0
var _bot_t0 := -1.0
var _last_hp := 0.0
var _last_sh := 0.0


## PlayerStats por ruta (como en door.gd): nombrar el autoload aqui crea un ciclo de compilacion.
func _ps() -> Node:
	return get_node("/root/PlayerStats")


static func key_tex(k: String) -> Texture2D:
	return load("res://assets/sprites/items/%s.png" % KEY_IDS[k])


static func key_color(k: String) -> Color:
	return Color(COLORS[k])


## Lo llama Door._ready: crea la mision una vez por piso (main se recarga con cada piso).
static func ensure(tree: SceneTree) -> void:
	var m := tree.get_first_node_in_group("main") if tree else null
	if m == null or not ("dungeon_generator" in m):
		return
	# Una mision por piso: main no se recarga al bajar, asi que se rehace cuando cambia la mazmorra.
	var floor_root: Variant = m.get("dungeon_root")
	var key: int = floor_root.get_instance_id() if floor_root is Object and is_instance_valid(floor_root) else 0
	if m.has_meta("key_quests") and int(m.get_meta("key_quests")) == key:
		return
	m.set_meta("key_quests", key)
	var old := m.get_node_or_null("KeyQuests")
	if old:
		old.name = "KeyQuestsOld"
		old.queue_free()
	var kq := KeyQuests.new()
	kq.name = "KeyQuests"
	kq.main = m
	m.add_child.call_deferred(kq)


static func of(tree: SceneTree) -> KeyQuests:
	var m := tree.get_first_node_in_group("main") if tree else null
	return m.get_node_or_null("KeyQuests") as KeyQuests if m else null


func _ready() -> void:
	# unos fotogramas: el piso termina de montarse (obstaculos, luces) y la fisica registra los cuerpos
	for _i in 4:
		await get_tree().physics_frame
	if main == null or not is_instance_valid(main):
		return
	setup()


func setup() -> void:
	var rm := get_node("/root/RunManager")
	rng.seed = int(rm.current_seed) * 17 + int(rm.current_floor) * 101
	var player: Player = main.player
	for id in KEY_IDS.values():
		player.collected_items.erase(id)  # las llaves de un piso no pasan al siguiente
	var rooms: Dictionary = main.dungeon_generator.rooms
	var depth := PuzzleFactory.depth()
	var weights := {"crystal": 3.0, "drunk": 2.0, "belt": 2.0}
	if depth >= 2:
		weights["blood"] = 1.5
		weights["master"] = 1.0
	kind = force_kind if force_kind != "" else _pick_kind(weights)
	key_id = KEY_IDS[kind]
	# sala de la llave: donde hay combate (custodios); el altar de sangre, en sala tranquila
	var home_types := [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION]
	if kind == "blood":
		home_types = [Room.RoomType.REST, Room.RoomType.LORE, Room.RoomType.TREASURE, Room.RoomType.COMBAT]
	var homes: Array = rooms.values().filter(func(r): return r.room_type in home_types)
	if kind == "blood" and homes.any(func(r): return r.room_type != Room.RoomType.COMBAT):
		homes = homes.filter(func(r): return r.room_type != Room.RoomType.COMBAT)
	if homes.is_empty():
		return
	home = homes[rng.randi_range(0, homes.size() - 1)]
	# el cofre, en sala tranquila si la hay (llegar a un combate sellado con la llave de cristal
	# seria injusto); si no, en un combate. La mas lejana de la llave.
	var calm := [Room.RoomType.TREASURE, Room.RoomType.REST, Room.RoomType.LORE, Room.RoomType.START]
	var vaults: Array = rooms.values().filter(func(r): return r != home and r.room_type in calm)
	if vaults.is_empty():
		vaults = rooms.values().filter(func(r): return r != home and r.room_type in [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION])
	if vaults.is_empty():
		return
	var dist := _distances_from(home)
	vaults.sort_custom(func(a, b): return int(dist.get(a.grid_pos, 0)) > int(dist.get(b.grid_pos, 0)))
	vault = vaults[0]
	# cofre
	chest = LockedChest.new()
	chest.quest = self
	chest.kind = kind
	chest.position = _free_spot(vault, vault.get_center_position() + Vector2(-130, 30))
	vault.pickups_node.add_child(chest)
	# llave / altar / ladron
	_key_spot = _free_spot(home, home.get_center_position() + Vector2(130, 30))
	state = "home"
	match kind:
		"blood":
			altar = BloodAltar.new()
			altar.quest = self
			altar.position = _key_spot
			home.pickups_node.add_child(altar)
		"master":
			_fug_pending = true
		_:
			_ensure_key_node()
	if kind == "drunk":
		_place_bottle(home, _key_spot + Vector2(-56, 24))
		_place_bottle(home, _key_spot + Vector2(56, 24))
		_place_bottle(vault, chest.position + Vector2(0, 54))
	var ge := get_node("/root/GlobalEvents")
	# cualquier golpe cuenta, tambien el que se come el escudo (player_damaged solo salta con la vida)
	var ps := _ps()
	_last_hp = ps.current_health
	_last_sh = ps.current_shields
	ps.health_changed.connect(_on_hp)
	ps.shields_changed.connect(_on_shield)
	ge.enemy_killed.connect(_on_enemy_killed)
	ready_ok = true
	print("[llaves] piso %d: %s, llave en %s (%s), cofre en %s (%s)" % [rm.current_floor, kind, home.grid_pos, Room.RoomType.keys()[home.room_type], vault.grid_pos, Room.RoomType.keys()[vault.room_type]])


func _pick_kind(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return "crystal"


func _distances_from(start: Room) -> Dictionary:
	var graph: Dictionary = main.dungeon_generator.room_graph
	var dist := {start.grid_pos: 0}
	var q := [start.grid_pos]
	while not q.is_empty():
		var c = q.pop_front()
		for n in graph.get(c, []):
			if not dist.has(n):
				dist[n] = dist[c] + 1
				q.append(n)
	return dist


## Sitio libre (sin muros ni obstaculos) cerca de `prefer`, en coordenadas locales de la sala.
func _free_spot(room: Room, prefer: Vector2) -> Vector2:
	# lo que ya ocupa el centro (fuente, inscripcion, cofre del arma, monedas del tesoro)
	var taken: Array = [room.get_center_position(), room.get_center_position() + Vector2(0, -40)]
	var spot := RoomUtil.free_spot(main, room, prefer, 22.0, false, taken)
	return prefer if spot == Vector2.INF else spot


func _place_bottle(room: Room, near: Vector2) -> void:
	var b := DrunkBottle.new()
	b.position = _free_spot(room, near)
	room.pickups_node.add_child(b)
	bottles.append(b)


func _ensure_key_node(at_local := Vector2.INF, locked := true) -> void:
	if key_node != null and is_instance_valid(key_node):
		return
	key_node = KeyPickup.new()
	key_node.quest = self
	key_node.kind = kind
	key_node.locked = locked
	key_node.position = _key_spot if at_local == Vector2.INF else at_local
	home.pickups_node.add_child(key_node)


# ------------------------------------------------------------------ bucle
func _process(delta: float) -> void:
	if not ready_ok or main == null or not is_instance_valid(main):
		return
	var room: Room = main.current_room
	if room != _last_room:
		_last_room = room
		if room == home:
			_enter_home()
	if state == "home" and key_node != null and is_instance_valid(key_node) and key_node.locked and _home_ready():
		key_node.set_locked(false)
	if state == "carried":
		if kind == "drunk":
			if _ps().intoxication_tier < 1:
				_sober_t += delta
				if _sober_t > SLIP_SECS:
					lose("slip")
			else:
				_sober_t = 0.0
		elif kind == "blood":
			_dry_t += delta
			if _dry_t > DRY_SECS:
				lose("dry")


func _home_ready() -> bool:
	return home.cleared and not _guards_pending and _alive(_guards).is_empty() and not (kind == "master" and (_fug_pending or fugitive != null))


func _alive(list: Array) -> Array:
	return list.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion() and (e.get("current_health") == null or e.current_health > 0.0))


## Al entrar en la sala de la llave: reaparecen los custodios (y el ladron) si hacen falta.
func _enter_home() -> void:
	if state != "home" or kind == "blood":
		return
	if _fug_pending:
		_spawn_fugitive()
	if _guards_pending:
		_spawn_guards()


func _spawn_guards() -> void:
	_guards_pending = false
	var depth := PuzzleFactory.depth()
	var n := clampi(2 + depth / 3, 2, 5)
	var data: Array = main._generate_enemy_data_for_room(home)
	var typed: Array[Dictionary] = []
	for i in mini(n, data.size()):
		typed.append(data[i])
	_ensure_spawn_points(home)
	home.spawn_enemies(typed, false)
	_guards = home.enemies_spawned.duplicate()
	Narrator.say_first("pz_key_guards")


func _spawn_fugitive() -> void:
	_fug_pending = false
	var rm := get_node("/root/RunManager")
	var e: Enemy = EnemyRegistry.scene("melee").instantiate()
	e.enemy_name = tr("PZ_THIEF")
	e.max_health = 24.0 + PuzzleFactory.depth() * 8.0
	e.damage = 0.0
	var fd: Dictionary = rm.floor_data()
	var roster: Array = fd.get("roster", [])
	var frames: String = main._frames_path(str(roster[0])) if not roster.is_empty() else ""
	if frames != "" and ResourceLoader.exists(frames):
		e.get_node("AnimatedSprite2D").sprite_frames = load(frames)
	var spr := Sprite2D.new()
	spr.texture = key_tex("master")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = Vector2(0, -46)
	spr.z_index = 2
	e.add_child(spr)
	ActorFx.add_glow(spr, key_color("master"), 0.6, 0.6)
	var ctrl := KeyFugitive.new()
	ctrl.escaped.connect(_on_fugitive_escaped)
	e.add_child(ctrl)
	fugitive = e
	home._add_enemy_deferred(e, home.global_position + _free_spot(home, home.get_center_position() + Vector2(0, 40)))
	Narrator.say_first("pz_key_master_seen")


func _on_fugitive_escaped() -> void:
	if fugitive == null or not is_instance_valid(fugitive):
		return
	_burst(fugitive.global_position, key_color("master"))
	fugitive.queue_free()
	fugitive = null
	_fug_pending = true
	_guards_pending = true
	Narrator.toast(tr("PZ_KEY_MASTER_NAME"), tr("PZ_THIEF_ESCAPED"), "ffd75a")
	# el ladron y sus custodios vuelven la proxima vez que entres en la sala (no al instante)


func _on_enemy_killed(e: Node, _killer: Node) -> void:
	if kind != "master" or e != fugitive or fugitive == null:
		return
	var pos: Vector2 = e.global_position
	fugitive = null
	state = "free"
	_ensure_key_node(home.pickups_node.to_local(pos), false)
	Sound.play("pickup")
	Narrator.toast(tr("PZ_KEY_MASTER_NAME"), tr("PZ_THIEF_DROPPED"), "ffd75a")


func _on_hp(cur: float, _max: float) -> void:
	if cur < _last_hp - 0.01 and state == "carried" and kind == "crystal":
		lose("shatter")
	_last_hp = cur


func _on_shield(cur: float, _max: float) -> void:
	if cur < _last_sh - 0.01 and state == "carried" and kind == "crystal":
		lose("shatter")
	_last_sh = cur


# ------------------------------------------------------------------ llevar, perder, abrir
## true si se cogio. Lo llaman KeyPickup y BloodAltar.
func take_key(player: Node, _src: Node) -> bool:
	if state == "carried" or state == "done":
		return false
	if kind == "drunk" and _ps().intoxication_tier < 1:
		get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -40), tr("PZ_KEY_SLIP_SOBER"), Color("e0a93a"))
		Sound.play("locked")
		Narrator.say_first("pz_key_drunk_sober")
		return false
	state = "carried"
	_sober_t = 0.0
	_dry_t = 0.0
	if not player.collected_items.has(key_id):
		player.collected_items.append(key_id)
	_follower = KeyFollower.new()
	_follower.kind = kind
	_follower.target = player
	main.add_child(_follower)
	Sound.play("pickup")
	Narrator.toast(tr("PZ_KEY_%s_NAME" % kind.to_upper()), tr("PZ_KEY_%s_TAKEN" % kind.to_upper()), COLORS[kind])
	Narrator.say_first("pz_key_%s_take" % kind)
	if altar:
		altar.set_armed(false)
	return true


## La llave se pierde: vuelve a su sitio y sus custodios reaparecen.
func lose(reason: String) -> void:
	if state != "carried":
		return
	var player: Player = main.player
	player.collected_items.erase(key_id)
	var at := player.global_position
	if _follower and is_instance_valid(_follower):
		at = _follower.global_position
		_follower.queue_free()
	_follower = null
	_burst(at, key_color(kind))
	Sound.play("crack")
	get_node("/root/GlobalEvents").show_floating_text.emit(at + Vector2(0, -20), tr("PZ_KEY_LOST_%s" % reason.to_upper()), key_color(kind))
	Narrator.toast(tr("PZ_KEY_%s_NAME" % kind.to_upper()), tr("PZ_KEY_BACK"), COLORS[kind])
	Narrator.say("pz_key_%s_lost" % kind)
	state = "home"
	match kind:
		"blood":
			altar.set_armed(true)
		"master":
			_fug_pending = true
			_guards_pending = true
		_:
			_guards_pending = true
			_ensure_key_node()
	if main.current_room == home:
		_enter_home()


func can_open(chest_kind: String) -> bool:
	var player: Player = main.player
	if player.has_item("key_master"):
		return true
	if not player.has_item(KEY_IDS[chest_kind]):
		return false
	return chest_kind != "drunk" or _ps().intoxication_tier >= 1


func try_open(player: Node, c: LockedChest) -> bool:
	if not can_open(c.kind):
		var txt := tr("PZ_CHEST_DRUNK_NEED") if player.has_item(KEY_IDS[c.kind]) else tr("PZ_CHEST_NEED_KEY")
		get_node("/root/GlobalEvents").show_floating_text.emit(c.global_position + Vector2(0, -40), txt, Color("ff7a7a"))
		Sound.play("locked")
		return false
	var used: String = KEY_IDS[c.kind] if player.has_item(KEY_IDS[c.kind]) else ""
	if used != "":  # la llave propia se gasta; la maestra sirve para todo el piso
		player.collected_items.erase(used)
	if _follower and is_instance_valid(_follower) and used != "":
		_follower.queue_free()
		_follower = null
	state = "done"
	_reward(c)
	return true


func _reward(c: LockedChest) -> void:
	var depth := PuzzleFactory.depth()
	var room := vault
	var base := c.position
	var ids: Array[String] = ["health_large", main._random_loot_id()]
	if kind in ["blood", "master"]:
		ids.append(main._random_loot_id())
	if kind == "blood" or rng.randf() < 0.5:
		ids.append(main._random_weapon_id())
	for i in ids.size():
		main._spawn_pickup(room, ids[i], base + Vector2((i - (ids.size() - 1) * 0.5) * 36.0, 46))
	var coins := 5 + depth * 2 + (6 if kind == "blood" else 0)
	RoomUtil.coins(main, room, coins, base + Vector2(0, 75))
	Narrator.say("pz_chest_open_%s" % kind)
	if kind == "blood":
		# riesgo grande: la sangre llama a los que huelen (emboscada)
		var data: Array = main._generate_enemy_data_for_room(room)
		var typed: Array[Dictionary] = []
		for i in mini(3, data.size()):
			var d: Dictionary = data[i]
			d["health"] = float(d.get("health", 40.0)) * 1.8
			typed.append(d)
		_ensure_spawn_points(room)
		room.spawn_enemies(typed, false)


## Salas sin puntos de aparicion (inicio, tesoro...): se improvisan en anillo alrededor del centro.
func _ensure_spawn_points(room: Room) -> void:
	if not room.spawn_points.is_empty():
		return
	var c := room.global_position + room.get_center_position()
	for i in 4:
		room.spawn_points.append(c + Vector2(110, 0).rotated(TAU * i / 4.0 + 0.4))


func _burst(at: Vector2, color: Color) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = Settings.fx_amount(18)
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0
	p.damping_min = 80.0
	p.damping_max = 120.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	p.global_position = at
	p.z_index = 4
	p.material = LightKit.unshaded_material()
	main.add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


# ------------------------------------------------------------------ bot
## Lo que el bot debe hacer para esta mision: {} (nada), {"room": Room} (ir alli) o
## {"go": Vector2 global, "interact": bool} (ir ahi y pulsar E). Ver tools/autoplay.
func bot_goal(room: Room) -> Dictionary:
	if not ready_ok or bot_gave_up or state == "done" or state == "none":
		return {}
	var now := Time.get_ticks_msec() / 1000.0
	if _bot_t0 < 0.0:
		_bot_t0 = now
	elif now - _bot_t0 > 300.0:
		bot_gave_up = true  # que no se obsesione: sigue con el piso
		return {}
	var tier: int = _ps().intoxication_tier
	match state:
		"home", "free":
			if kind == "blood":
				if _ps().current_health < _ps().max_health * 0.6:
					return {}
				if room != home:
					return {"room": home}
				return {"go": altar.global_position, "interact": true}
			if room != home:
				return {"room": home}
			if kind == "drunk" and _ps().intoxication_level < 70.0:
				var near := _nearest_bottle(room)
				if near != null:
					return {"go": near.global_position, "interact": false}
			if key_node != null and is_instance_valid(key_node) and not key_node.locked:
				return {"go": key_node.global_position, "interact": true}
			return {}
		"carried":
			if kind == "drunk" and tier < 2:
				var near := _nearest_bottle(room)
				if near != null:
					return {"go": near.global_position, "interact": false}
			if room != vault:
				return {"room": vault}
			return {"go": chest.global_position, "interact": true}
	return {}


func _nearest_bottle(room: Room) -> DrunkBottle:
	var best: DrunkBottle = null
	var bd := INF
	for b in bottles:
		if is_instance_valid(b) and not b.is_queued_for_deletion() and room.is_ancestor_of(b):
			var d := b.global_position.distance_to(main.player.global_position)
			if d < bd:
				bd = d
				best = b
	return best
