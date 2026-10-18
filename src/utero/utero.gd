class_name Utero
extends RefCounted

## EL UTERO: nivel secreto de Vulvania (etapa V). Ganchos estaticos que llaman main.gd,
## room.gd/player.gd y la tienda; todo lo demas vive en src/utero/.
##
## COMO SE ENTRA
##   1. En Trompas de Falopio (2a etapa de Vulvania) una sala sin salida pasa a ser la "Consulta
##      de la Doctora V." (guino a la autora): cartel + la Puerta del Cuello Uterino.
##   2. La puerta se abre con un TURNO (objeto "turno": se compra en la tienda de Vulvania o lo
##      suelta un elite de Vulvania; una vez por partida). Al abrirla RunManager.insert_utero()
##      mete el piso EXTRA "utero" justo despues de Trompas en la ruta activa.
##   3. Al vencer a la reina Ovaria II la escotilla baja al Utero; al vencer a Dona Regla (o al
##      morir) todo sigue como siempre. La dificultad es la de Trompas (region "vulvania").
##   Pruebas / bot: --force-utero=1 (Utero.force) lo abre solo al entrar a Trompas.
##
## EL PISO: 4 tramos, uno por fase del ciclo, segun la distancia (en puertas) desde la entrada:
##   0 menstruacion  1 folicular  2 ovulacion  3 lutea   (la sala del jefe: fase 4 = Dona Regla)
## Cada sala guarda su fase en el meta "utero_phase". Lo que hace cada fase esta en UteroFx
## (tinte, buffs, banner), UteroFolliculos, UteroOvulo y en los ganchos de abajo.
##
## EVENTOS DE CODICE (LoreDatabase.custom_event): utero_consulta (entras a la Consulta),
## utero_turno (abres la puerta), enter_utero (pisas el Utero; lo usa el codice: loc_utero), utero_fase_menstruacion /
## utero_fase_folicular / utero_fase_ovulacion / utero_fase_lutea, utero_ovulo (alcanzas el
## ovulo), utero_regla (vences a Dona Regla). Para el codice: boss_regla se desbloquea matando a "DOÑA REGLA".

const FLOOR_ID := "utero"
const HOST_ID := "trompas_falopio"
const TURNO := "turno"
const PHASE_NAMES := ["menstruacion", "folicular", "ovulacion", "lutea"]
const FIGHT := [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION]
const MENS_ITEMS := ["tampon", "menstrual_cup"]  # + todo lo de tag "toalla"
const MENS_BOOST := 1.5
const LUTEA_BOOST := 2.0  # el chocolate cura el doble
## Personalidades de enemigo (src/enemies/ai) irritables, para el SPM de la fase lutea.
const SPM_PERSONALITIES := ["terco", "rencoroso", "resentida", "quejona", "impredecible", "hiperactivo"]

## Prueba/bot: --force-utero=1. Abre el Utero solo al pisar Trompas, sin comprar el Turno.
static var force := false
## Fase de la sala actual (-1 = fuera del Utero). La actualiza UteroFx.
static var phase := -1


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _rm() -> Node:
	return _tree().root.get_node("RunManager")


static func is_utero() -> bool:
	return str(_rm().floor_data().get("id", "")) == FLOOR_ID


static func fx(main: Node) -> UteroFx:
	return main.get_node_or_null("UteroFx") as UteroFx


# ------------------------------------------------------------------ piso
## Al terminar de generar un piso (main._generate_dungeon). Trompas: elige la Consulta; Utero:
## reparte las fases; cualquier otro: limpia lo que dejo el Utero.
static func setup_floor(main: Node) -> void:
	var old := fx(main)
	if old != null:
		old.queue_free()  # su _exit_tree devuelve los buffs de la fase
	phase = -1
	var id := str(_rm().floor_data().get("id", ""))
	if id == HOST_ID and not RunManager.utero_used:
		_pick_consulta(main)
		if force:
			RunManager.insert_utero()
			print("[utero] --force-utero: el Utero queda en la ruta tras Trompas")
	elif id == FLOOR_ID:
		_assign_phases(main)
		var f := UteroFx.new()
		f.name = "UteroFx"
		f.main = main
		main.add_child(f)
		_lore("enter_utero")


static func _lore(event: String) -> void:
	_tree().root.get_node("LoreDatabase").custom_event(event)


static func _assign_phases(main: Node) -> void:
	var gen: DungeonGenerator = main.dungeon_generator
	var start: Room = main._find_start_room()
	if start == null:
		return
	var dist: Dictionary = gen._graph_dist(start.grid_pos)
	# las salas (sin la entrada ni la del jefe) ordenadas por distancia en puertas se reparten en 4
	# tramos iguales: asi salen siempre las 4 fases, aunque el piso sea poco profundo
	var order: Array = []
	for pos in gen.rooms:
		var rr: Room = gen.rooms[pos]
		if rr.room_type not in [Room.RoomType.BOSS, Room.RoomType.START]:
			order.append(pos)
	order.sort_custom(func(a, b): return int(dist.get(a, 0)) < int(dist.get(b, 0)))
	var best_ovulo: Room = null
	for pos in gen.rooms:
		var r: Room = gen.rooms[pos]
		var d := int(dist.get(pos, 0))
		var p := 0
		if pos in order:
			p = clampi(int(floor(order.find(pos) * 4.0 / order.size())), 0, 3)
		if r.room_type == Room.RoomType.BOSS:
			p = 4
		r.set_meta("utero_phase", p)
		if p == 2 and r.room_type == Room.RoomType.COMBAT and not r.has_meta("elite_room") \
				and (best_ovulo == null or d > int(dist.get(best_ovulo.grid_pos, 0))):
			best_ovulo = r
	if best_ovulo != null:
		best_ovulo.set_meta("utero_ovulo", true)  # la persecucion del ovulo: la sala mas honda de la fase


static func phase_of(room: Room) -> int:
	return int(room.get_meta("utero_phase", -1)) if room != null else -1


# ------------------------------------------------------------------ ganchos de main.gd
## main._enter_room, antes del director de salas.
static func on_enter(main: Node, room: Room, entry_door: Door) -> void:
	if room.has_meta("consulta"):
		_lore("utero_consulta")
		return
	var f := fx(main)
	if f != null:
		f.enter_room(room, entry_door)


## main._generate_enemy_data_for_room: pesos del roster (la menstruacion saca a los Calambres).
static func weights(room: Room, w: Array) -> Array:
	if phase_of(room) != 0:
		return w
	var out := w.duplicate()
	if out.size() > 2:
		out[2] = float(out[2]) * 3.5  # Calambre: el protagonista
	return out


## main._generate_enemy_data_for_room: ajustes a un enemigo antes de crearlo.
static func data_tweak(room: Room, info: Dictionary) -> void:
	var p := phase_of(room)
	if p == 3 and info.get("enemy_type", "") != "boss":
		info.personality = SPM_PERSONALITIES[randi() % SPM_PERSONALITIES.size()]  # SPM: irritables y cambiantes


## Elites de Vulvania: a veces sueltan el Turno (si todavia lo puedes usar).
static func elite_drop(main: Node, info: Dictionary) -> void:
	if info.get("elite", false) and turno_obtainable(main):
		info.drops.append({"item_id": TURNO, "chance": 0.18})


## main._on_room_cleared: premios propios de cada fase.
static func on_room_cleared(main: Node, room: Room) -> void:
	var p := phase_of(room)
	if p < 0 or room.room_type not in FIGHT:
		return
	var c: Vector2 = room.get_center_position()
	match p:
		0:  # la menstruacion deja toallas, tampones y copas
			if randf() < 0.4:
				main._spawn_pickup(room, ["towel_cotton", "tampon", "menstrual_cup", "towel_mesh"][randi() % 4], c + Vector2(40, 40))
		2:  # en celo: mas botin
			RoomUtil.coins(main, room, 3 + RunManager.depth_i(_rm().current_floor), c + Vector2(0, 50))
		3:  # antojos
			if randf() < 0.5:
				main._spawn_pickup(room, "chocolate_bar", c + Vector2(-40, 40))


## Player.affinity_boost: lo que rinden los objetos segun la fase.
static func item_mult(item: Item) -> float:
	if phase == 0 and ("toalla" in item.tags or item.id in MENS_ITEMS):
		return MENS_BOOST
	if phase == 3 and item.id == "chocolate_bar":
		return LUTEA_BOOST
	return 1.0


## main._complete_floor (jefe del piso vencido).
static func on_boss_dead(main: Node) -> void:
	if not is_utero():
		return
	_lore("utero_regla")  # (la frase de despedida es bossutero_after, la dice el propio jefe)


## main._complete_floor, tras elegir la mejora del jefe: la bendicion "de ciclo" (3 cartas del
## reino del heroe; el Ornitorrinco, de Vulvania, que es donde estamos).
static func cycle_blessing(main: Node) -> void:
	if not is_utero():
		return
	var k: String = str(_rm().character_data().kingdom)
	main._offer_blessing(k if k in ["pene", "vulva"] else "vulva", main.tr("UTERO_BLESSING_TITLE"))


# ------------------------------------------------------------------ Turno
static func owns_turno(main: Node) -> bool:
	return TURNO in main.player.collected_items


## true si todavia tiene sentido ofrecer/soltar el Turno: en Vulvania, sin usar y sin tenerlo.
static func turno_obtainable(main: Node) -> bool:
	return str(_rm().floor_data().get("region", "")) == "vulvania" and str(_rm().floor_data().get("id", "")) != FLOOR_ID \
		and not RunManager.utero_used and not owns_turno(main)


## main._build_shop: la tienda de Vulvania vende el Turno (2a etapa: solo si no lo tienes ya).
static func shop_stock(main: Node, stock: Array) -> Array:
	if turno_obtainable(main) and stock.size() > 1:
		stock[1] = TURNO
	return stock


# ------------------------------------------------------------------ la Consulta
static func _pick_consulta(main: Node) -> void:
	var gen: DungeonGenerator = main.dungeon_generator
	var cands: Array = gen.rooms.values().filter(func(r):
		return r.room_type == Room.RoomType.COMBAT and not r.has_meta("elite_room") and r.grid_pos not in gen.main_path)
	var dead: Array = cands.filter(func(r): return gen.room_graph[r.grid_pos].size() == 1)
	if not dead.is_empty():
		cands = dead
	# el piso necesita sus combates: (quedan >= 3 mas el minijefe y el jefe)
	var fights := gen.rooms.values().filter(func(r): return r.room_type in FIGHT).size()
	if cands.is_empty() or fights < 4:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_rm().current_seed, "consulta"])
	var room: Room = cands[rng.randi_range(0, cands.size() - 1)]
	room.room_type = Room.RoomType.LORE  # sala tranquila (el cartel de su puerta lo pone _room_hint)
	room.set_meta("consulta", true)


## main._build_calm_room: la sala marcada es la Consulta.
static func build_consulta(main: Node, room: Room) -> void:
	UteroConsulta.build(main, room)
