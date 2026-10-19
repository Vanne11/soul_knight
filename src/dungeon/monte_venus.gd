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


## Al generar un piso (DungeonGenerator, tras los tipos y antes de las formas): si toca, convierte
## una sala en el Monte de Venus. Como las formas solo van en salas de combate, queda rectangular.
static func assign(gen: DungeonGenerator) -> void:
	var rm := _rm()
	var f: int = gen.current_floor
	if RunManager.floor_region(f) != REGION:
		return
	var rank := 0  # 1er o 2do piso de la Selva en la ruta
	for i in range(1, f + 1):
		if RunManager.floor_region(i) == REGION:
			rank += 1
	if not force and rank != target_stage():
		return
	var cands := _candidates(gen)
	if cands.is_empty():
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

