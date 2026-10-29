class_name MonteVenus
extends RefCounted

## Sala especial MONTE DE VENUS de la Selva Publica: una loma de dos mesetas (estilo A Link to the
## Past) con vello alto, cera de Dona Cera tapando rampas y una bandera en la cima. Sin combate. Una
## sola por partida (en uno de los 2 pisos de la Selva, elegido por la semilla) y la recompensa se
## recoge una sola vez.
##
## Tipo de sala: LORE (sala tranquila ya existente) con la marca meta "monte_venus"; el minimapa
## la dibuja con "^" y la puerta lleva su cartel (main._room_hint). Se decide ANTES de poner
## formas/obstaculos/decor (DungeonGenerator.generate_floor), asi la sala nace como sala tranquila.
##
## La loma (mesetas, paredes con colision, rampas, repisas, vello, cera) es src/dungeon/monte_hill.gd.
## Aqui: la sala elegida, la bandera de la cima y lo que pasa al subir y al llegar.
## Texto: locale/monte_venus.csv. Frases: assets/data/narrator/monte_venus.json (al pisar la primera
## rampa, una por heroe: monte_subir_<heroe>; en la cima: monte_cima = el dato, monte_cera = guino a
## Dona Cera). Codice: evento "monte_venus" (assets/data/lore/loc_monte_venus.tres).
## Arte: tools/gen_monte_venus_art2.py -> assets/sprites/environment/monte/

const REGION := "selva"
const META := "monte_venus"
const ICON := "^"
const REWARD := "emergency_briefs"  # "tu madre tenia razon": el vello protege, los calzones tambien
const FLAG_FOOT := Vector2(15, 62)  # la base del mastil dentro de monte/flag.png
const REWARD_AT := Vector2(150, 124)  # en la cima, a la izquierda de la bandera (locales de la loma)
## La loma mide 400x276: con 10x8 baldosas quedan 118 px libres arriba y abajo y 120 a los lados,
## suficiente para que el heroe aparezca junto a cualquier puerta sin quedar dentro de un muro.
const MIN_TILES := Vector2i(10, 8)
const OK_TYPES := [Room.RoomType.TREASURE, Room.RoomType.REST, Room.RoomType.LORE]
const FIGHT_TYPES := [Room.RoomType.COMBAT, Room.RoomType.TRAP]
## Prueba/capturas: --force-monte=1 la pone en el primer piso de la Selva que se genere.
static var force := false


static func _rm() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("RunManager")


static func is_monte(room: Room) -> bool:
	return room.has_meta(META)


## Piso de la Selva (1 o 2 dentro del reino) donde sale esta partida; -1 si la ruta no pasa por ella.
static func target_stage() -> int:
	var n := 0
	for f in range(1, RunManager.route_size() + 1):
		if RunManager.floor_region(f) == REGION:
			n += 1
	if n == 0:
		return -1
	var pick := absi(hash([_rm().current_seed, META])) % n
	return pick + 1


## true si el Monte sale en este piso (el de la Selva que eligio la semilla, o --force-monte).
static func wants_floor(f: int) -> bool:
	if RunManager.floor_region(f) != REGION:
		return false
	var rank := 0  # 1er o 2do piso de la Selva en la ruta
	for i in range(1, f + 1):
		if RunManager.floor_region(i) == REGION:
			rank += 1
	return force or rank == target_stage() or (rank == 2 and _deferred_seed == _rm().current_seed)


## Semilla de la partida cuyo Monte no cupo en el 1er piso de la Selva: pasa al 2do.
static var _deferred_seed := -1


## Al planear el piso del Monte (DungeonGenerator._plan_layout, antes de crear las salas): agranda
## hasta 3 salas (sin contar el inicio) a 11x8 si su hoja del BSP da. Sin esto la unica sala
## grande solia ser la del jefe y el Monte se perdia en ~2 de cada 3 partidas.
const WIDE := Vector2i(11, 8)
static func widen(rects: Array, leaves: Array, pad: int) -> void:
	var big := 0
	var options := []
	for i in range(1, rects.size()):
		var r: Rect2 = rects[i]
		if r.size.x >= WIDE.x and r.size.y >= WIDE.y:
			big += 1
			continue
		var avail: Vector2 = leaves[i].rect.size - Vector2(pad, pad) * 2.0
		if avail.x >= WIDE.x and avail.y >= WIDE.y:
			options.append(i)
	options.sort_custom(func(a, b): return leaves[a].rect.get_area() > leaves[b].rect.get_area())
	for i in options.slice(0, maxi(3 - big, 0)):
		var leaf_rect: Rect2 = leaves[i].rect
		var r: Rect2 = rects[i]
		var w := maxf(r.size.x, WIDE.x)
		var h := maxf(r.size.y, WIDE.y)
		var x0 := leaf_rect.position.x + pad
		var y0 := leaf_rect.position.y + pad
		var x := clampf(r.position.x, x0, x0 + leaf_rect.size.x - pad * 2 - w)
		var y := clampf(r.position.y, y0, y0 + leaf_rect.size.y - pad * 2 - h)
		rects[i] = Rect2(x, y, w, h)


## Al generar un piso (DungeonGenerator, tras los tipos y antes de las formas): si toca, convierte
## una sala en el Monte de Venus. Como las formas solo van en salas de combate, queda rectangular.
static func assign(gen: DungeonGenerator) -> void:
	var rm := _rm()
	var f: int = gen.current_floor
	if not wants_floor(f):
		return
	var cands := _candidates(gen)
	if cands.is_empty():
		cands = _swap_candidate(gen)
	if cands.is_empty():
		if _deferred_seed != rm.current_seed and f < RunManager.route_size() and RunManager.floor_region(f + 1) == REGION:
			_deferred_seed = rm.current_seed  # segundo intento en el piso siguiente de la Selva
			return
		push_warning("Monte de Venus: no hay sala donde ponerlo en este piso")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([rm.current_seed, f, META])
	var room: Room = cands[rng.randi_range(0, cands.size() - 1)]
	room.room_type = Room.RoomType.LORE
	room.set_meta(META, true)
	print("[monte_venus] sala %s del piso %d" % [room.grid_pos, f])


static func _candidates(gen: DungeonGenerator) -> Array:
	var fights := gen.rooms.values().filter(func(r: Room): return r.room_type in [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP]).size()
	var all: Array = gen.rooms.values().filter(func(r: Room):
		var sz: Vector2i = gen.room_sizes.get(r.grid_pos, Vector2i.ZERO)
		return sz.x >= MIN_TILES.x and sz.y >= MIN_TILES.y and not r.has_meta("elite_room"))
	var off_path := func(r: Room): return r.grid_pos not in gen.main_path
	var dead := func(r: Room): return gen.room_graph[r.grid_pos].size() == 1
	var tiers: Array = [all.filter(func(r): return r.room_type in OK_TYPES and off_path.call(r))]
	if fights >= 3:  # quedan al menos 2 combates
		tiers.append(all.filter(func(r): return r.room_type == Room.RoomType.COMBAT and off_path.call(r) and dead.call(r)))
		tiers.append(all.filter(func(r): return r.room_type in FIGHT_TYPES and off_path.call(r)))
	tiers.append(all.filter(func(r): return r.room_type in OK_TYPES))
	if fights >= 3:
		tiers.append(all.filter(func(r): return r.room_type == Room.RoomType.COMBAT))
	for t in tiers:
		if not t.is_empty():
			return t
	return []


## Ultimo recurso: una sala grande que quedo de tienda, antro o puzzle (tipos que el generador
## reparte entre combates cualesquiera) le pasa su tipo a un combate y queda libre para el Monte.
static func _swap_candidate(gen: DungeonGenerator) -> Array:
	var fights := gen.rooms.values().filter(func(r: Room): return r.room_type in [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP]).size()
	if fights < 3:
		return []
	var combats: Array = gen.rooms.values().filter(func(r: Room): return r.room_type == Room.RoomType.COMBAT and not r.has_meta("elite_room"))
	if combats.is_empty():
		return []
	for t in [Room.RoomType.INTOXICATION, Room.RoomType.SHOP, Room.RoomType.PUZZLE]:
		for r: Room in gen.rooms.values():
			var sz: Vector2i = gen.room_sizes.get(r.grid_pos, Vector2i.ZERO)
			if r.room_type != t or sz.x < MIN_TILES.x or sz.y < MIN_TILES.y or r.has_meta("elite_room"):
				continue
			var other: Room = combats[0]
			other.room_type = t
			other.required_intoxication_tier = r.required_intoxication_tier
			r.required_intoxication_tier = 0
			return [r]
	return []


## Al entrar a la sala (main._build_calm_room): arma la loma, la bandera de la cima y la reaccion del heroe.
static func build(main: Node, room: Room) -> void:
	if room.has_meta("monte_built"):
		return
	room.set_meta("monte_built", true)
	var hill := MonteHill.build(room)
	var summit := hill.position + hill.summit.get_center() + Vector2(0, 14)
	# la bandera de la cima: lo que se lee
	var flag := Sprite2D.new()
	flag.texture = load(MonteHill.DIR + "flag.png")
	flag.centered = false
	flag.offset = -FLAG_FOOT
	flag.set_meta("tall", true)
	var holder := Node2D.new()
	holder.add_child(flag)
	holder.set_meta("tall", true)
	var used := false
	main._add_prop(room, summit, holder, main.tr("MONTE_PROMPT"), func(_p, it):
		if used:
			return
		used = true
		_on_summit(main, room, hill)
		it.finish())
	# al pisar la primera rampa, reaccion del heroe (una vez)
	hill.ramp_entered.connect(func():
		if not room.has_meta("monte_climbed"):
			room.set_meta("monte_climbed", true)
			_say_hero("monte_subir"))


static func _on_summit(main: Node, room: Room, hill: MonteHill) -> void:
	room.set_meta("monte_done", true)
	Sound.play("puzzle_solve")
	Narrator.say("monte_cima", {}, true)
	Narrator.say("monte_cera", {}, true)
	main.get_node("/root/LoreDatabase").custom_event("monte_venus")
	main._spawn_pickup(room, REWARD, hill.position + REWARD_AT)
	Narrator.toast(main.tr("MONTE_TOAST_T"), main.tr("MONTE_TOAST_D"), "f06aa0")


## "<evento>_<heroe>" con la frase importante (sale siempre, una vez por sala).
static func _say_hero(event: String) -> void:
	var ev := "%s_%s" % [event, _rm().character]
	if Narrator.has_lines(ev):
		Narrator.say(ev, {}, true)

