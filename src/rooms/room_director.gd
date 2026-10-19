class_name RoomDirector
extends Node

## Director de dinamicas de sala (roadmap 3c). Decide, de forma determinista con la semilla
## del piso, que "otra cosa" pasa en cada sala ademas de "entra, mata todo, sal":
##
##  objetivos     escort (escolta del ovulo), hold (la fiesta, aguantar 45 s), thief (ladilla
##                ladrona), stealth (sigilo con linternas), clock (contra el reloj), challenge
##                (reto del narrador)
##  modificadores celo, lubricado, aduanera, apagon, censurada
##  entorno       barriles (explosivos), antorchas (caen e incendian), trampas (salas trampa:
##                pinchos, cera caliente y ventiladores, siempre con aviso)
##  encuentros    pacto (Hoja de Parra), ruleta (vendedor ambulante), mercado (negro)
##
## Cada dinamica es un RoomDynamic hijo de la sala. Lo anuncia el cartel de la puerta (se
## anade una linea al cartel que pone main._label_doors). Enganches en el resto del juego:
##   main._enter_room            -> RoomDirector.on_enter(self, room, entry_door)
##   main._spawn_room_enemies    -> RoomDirector.takes_over(room): hold y sigilo crean ellos
##                                  a sus enemigos
##   room.room_cleared()         -> room.clear_gate (hasta cumplir el objetivo no se abre)
##
## No usa el RNG global del juego para decidir (semilla local por piso y sala); solo los
## azares de dentro de una dinamica (apuestas, olas) usan randf().

const DIR := "res://src/rooms/"
## kind -> {cat, script, rooms (tipos de sala permitidos)}
const COMBATISH := [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP]
const KINDS := {
	"escort": {"cat": "objective", "script": "obj_escort.gd", "rooms": [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION]},
	"hold": {"cat": "objective", "script": "obj_hold.gd", "rooms": [Room.RoomType.INTOXICATION, Room.RoomType.COMBAT]},
	"thief": {"cat": "objective", "script": "obj_thief.gd", "rooms": [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION]},
	"stealth": {"cat": "objective", "script": "obj_stealth.gd", "rooms": [Room.RoomType.COMBAT]},
	"clock": {"cat": "objective", "script": "obj_clock.gd", "rooms": [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION]},
	"challenge": {"cat": "objective", "script": "obj_challenge.gd", "rooms": [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION]},
	"celo": {"cat": "modifier", "script": "mod_room.gd", "rooms": [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP, Room.RoomType.MINIBOSS]},
	"lubricado": {"cat": "modifier", "script": "mod_room.gd", "rooms": [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP, Room.RoomType.MINIBOSS]},
	"aduanera": {"cat": "modifier", "script": "mod_room.gd", "rooms": [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION]},
	"apagon": {"cat": "modifier", "script": "mod_room.gd", "rooms": [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP, Room.RoomType.MINIBOSS]},
	"censurada": {"cat": "modifier", "script": "mod_room.gd", "rooms": [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP, Room.RoomType.MINIBOSS]},
	"barriles": {"cat": "env", "script": "env_barrels.gd", "rooms": [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP]},
	"antorchas": {"cat": "env", "script": "env_torches.gd", "rooms": [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP]},
	"trampas": {"cat": "env", "script": "trap_room.gd", "rooms": [Room.RoomType.TRAP, Room.RoomType.COMBAT, Room.RoomType.INTOXICATION]},
	"pacto": {"cat": "encounter", "script": "enc_pact.gd", "rooms": [Room.RoomType.LORE, Room.RoomType.REST]},
	"ruleta": {"cat": "encounter", "script": "enc_roulette.gd", "rooms": [Room.RoomType.REST, Room.RoomType.LORE]},
	"mercado": {"cat": "encounter", "script": "enc_market.gd", "rooms": [Room.RoomType.SECRET, Room.RoomType.TREASURE]},
}
const OWN_SPAWN := ["hold", "stealth"]
## Cuantas veces como maximo por piso (el resto, ilimitado).
const FLOOR_CAP := {"pacto": 1, "ruleta": 1, "mercado": 1, "stealth": 1, "thief": 1, "hold": 2}
const MAX_OBJECTIVES := 3

## Solo para pruebas: fuerza la dinamica en toda sala donde quepa ("" = al azar).
static var force_kind := ""
## Solo para pruebas: apaga el director (pruebas que no lo quieren).
static var disabled := false

var main: Node
var plan: Dictionary = {}       # grid_pos -> kind principal
var plan2: Dictionary = {}      # grid_pos -> kind secundario (entorno extra en salas trampa)
var started: Dictionary = {}    # Room -> RoomDynamic
var owns: Dictionary = {}       # Room -> true (main no genera sus enemigos)
var extra_started: Dictionary = {}  # Room -> true (entorno secundario ya lanzado)
var _root: Node = null
var _pact_gray_until := 0.0     # msec
var _pact_mute_until := 0.0
var _last_gray_room: Room = null


# ------------------------------------------------------------------ enganches estaticos
static func of(tree: SceneTree) -> RoomDirector:
	var m := tree.get_first_node_in_group("main") if tree else null
	return m.get_node_or_null("RoomDirector") as RoomDirector if m else null


static func on_enter(main_: Node, room: Room, entry_door: Door = null) -> void:
	if disabled:
		return
	var d := main_.get_node_or_null("RoomDirector") as RoomDirector
	if d == null:
		d = RoomDirector.new()
		d.name = "RoomDirector"
		d.main = main_
		main_.add_child(d)
	d.enter(room, entry_door)


## true si una dinamica de esta sala crea sus propios enemigos (main no debe hacerlo).
static func takes_over(room: Room) -> bool:
	var d := RoomDirector.of(room.get_tree()) if room.is_inside_tree() else null
	return d != null and d.owns.has(room) and not room.cleared


# ------------------------------------------------------------------ plan del piso
func _reset_floor() -> void:
	_root = main.dungeon_root
	_kq_seen = false
	plan.clear()
	plan2.clear()
	started.clear()
	extra_started.clear()
	owns.clear()
	_build_plan()
	# Los scripts de las dinamicas arrastran escenas y texturas: cargarlos al entrar a la sala
	# congelaba hasta 100 ms. Se cargan ahora, junto con la generacion del piso.
	for k in plan.values() + plan2.values():
		if KINDS.has(k):
			_script_for(str(k))


static var _scripts: Dictionary = {}


static func _script_for(kind: String) -> GDScript:
	var path: String = DIR + str(KINDS[kind].script)
	if not _scripts.has(path):
		_scripts[path] = load(path)
	return _scripts[path]


func _build_plan() -> void:
	var rm_: Node = get_node("/root/RunManager")
	var f: int = rm_.current_floor
	var kingdom: String = str(rm_.floor_data().get("kingdom", ""))
	var gen: DungeonGenerator = main.dungeon_generator
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(rm_.current_seed), f, "dyn_plan"])
	# distancia (en puertas) desde la sala de inicio
	var start_room: Room = null
	for r in gen.rooms.values():
		if r.room_type == Room.RoomType.START:
			start_room = r
	var dist := {}
	if start_room:
		dist[start_room.grid_pos] = 0
		var q := [start_room.grid_pos]
		while not q.is_empty():
			var c: Vector2i = q.pop_front()
			for n in gen.room_graph.get(c, []):
				if not dist.has(n):
					dist[n] = dist[c] + 1
					q.append(n)
	var keys: Array = gen.rooms.keys()
	keys.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	var counts := {}
	var objectives := 0
	for pos in keys:
		var room: Room = gen.rooms[pos]
		if room.has_meta("elite_room") or room.has_meta("monte_venus") or room.room_type == Room.RoomType.SILENCIO:
			continue  # la sala elite (6b) y el Monte de Venus ya traen su propia mecanica
		if force_kind != "":
			if KINDS.has(force_kind) and room.room_type in KINDS[force_kind].rooms:
				plan[pos] = force_kind
			continue
		var near_start: bool = int(dist.get(pos, 9)) <= 1
		var kind := ""
		var roll := rng.randf()
		match room.room_type:
			Room.RoomType.COMBAT:
				var p := 0.45 if f == 1 else clampf(0.55 + 0.04 * f, 0.0, 0.85)
				if roll < p and not (near_start and f == 1):
					kind = _pick_combat(rng, f, kingdom, room, counts, objectives >= MAX_OBJECTIVES)
			Room.RoomType.INTOXICATION:
				if roll < 0.50 and _geo_ok("hold", room):
					kind = "hold"
				elif roll < 0.72 and objectives < MAX_OBJECTIVES:
					kind = _pick_objective(rng, f, kingdom, room, counts)
				elif roll < 0.86:
					kind = _weighted(rng, {"celo": 1.0, "lubricado": 1.0, "apagon": 1.0 if f >= 2 else 0.0})
			Room.RoomType.TRAP:
				kind = "trampas"
				if rng.randf() < 0.55:
					plan2[pos] = "barriles"
			Room.RoomType.MINIBOSS:
				if roll < 0.30:
					kind = _weighted(rng, {"celo": 1.0, "apagon": 1.0 if f >= 2 else 0.0, "censurada": 1.0 if f >= 3 else 0.0})
			Room.RoomType.REST:
				if roll < 0.55:
					kind = "ruleta"
			Room.RoomType.LORE:
				if roll < 0.65:
					kind = "pacto"
			Room.RoomType.TREASURE:
				if roll < 0.25:
					kind = "mercado"
			Room.RoomType.SECRET:
				if roll < 0.60:
					kind = "mercado"
		if kind == "":
			continue
		if FLOOR_CAP.has(kind) and int(counts.get(kind, 0)) >= int(FLOOR_CAP[kind]):
			continue
		counts[kind] = int(counts.get(kind, 0)) + 1
		if KINDS[kind].cat == "objective":
			objectives += 1
		plan[pos] = kind


func _pick_combat(rng: RandomNumberGenerator, f: int, kingdom: String, room: Room, counts: Dictionary, no_obj: bool) -> String:
	var cat := _weighted(rng, {"objective": 0.0 if no_obj else 0.5, "modifier": 0.3, "env": 0.2})
	match cat:
		"objective":
			return _pick_objective(rng, f, kingdom, room, counts)
		"modifier":
			return _weighted(rng, {
				"celo": 1.0, "lubricado": 1.0,
				"aduanera": 1.0 if f >= 2 else 0.0,
				"apagon": 1.0 if f >= 2 else 0.0,
				"censurada": (2.0 if kingdom == "censura" else 1.0) if f >= 3 else 0.0,
			})
		_:
			return _weighted(rng, {"barriles": 1.5, "antorchas": 1.0 if f >= 2 else 0.0, "trampas": 1.4})


func _pick_objective(rng: RandomNumberGenerator, f: int, kingdom: String, room: Room, counts: Dictionary) -> String:
	var w := {
		"escort": 2.0,
		"challenge": 1.5,
		"thief": 1.2 if f >= 2 else 0.0,
		"clock": 1.4 if f >= 2 else 0.0,
		"stealth": (2.6 if kingdom == "censura" else 1.3) if f >= 3 else 0.0,
	}
	for k in w.keys():
		if room.room_type not in KINDS[k].rooms or not _geo_ok(k, room) or (FLOOR_CAP.has(k) and int(counts.get(k, 0)) >= int(FLOOR_CAP[k])):
			w[k] = 0.0
	return _weighted(rng, w)


func _weighted(rng: RandomNumberGenerator, w: Dictionary) -> String:
	var total := 0.0
	for k in w:
		total += float(w[k])
	if total <= 0.0:
		return ""
	var r := rng.randf() * total
	for k in w:
		r -= float(w[k])
		if r <= 0.0 and float(w[k]) > 0.0:
			return k
	return ""


## Geometria: lo que cada dinamica necesita de la sala (sin mirar nada de la partida).
func _geo_ok(kind: String, room: Room) -> bool:
	var t := RoomUtil.tiles_of(room)
	var lo := mini(t.x, t.y)
	var hi := maxi(t.x, t.y)
	match kind:
		"escort": return hi >= 9 and lo >= 6
		"stealth": return hi >= 10 and lo >= 7
		"clock": return hi >= 9
		"hold": return lo >= 6
	return true


## La dinamica que de verdad corre en la sala: la del plan, salvo que sea un objetivo en una sala
## que no puede llevarlo (la de la hormona o la de la mision de llave): entonces un modificador
## (deterministico), asi esas salas tampoco son siempre "entra, mata todo, sal".
func effective_kind(room: Room) -> String:
	var kind: String = str(plan.get(room.grid_pos, ""))
	if kind != "" and KINDS.has(kind) and KINDS[kind].cat == "objective" and _objective_blocked(room):
		var opts := ["celo", "lubricado", "apagon"]
		return opts[absi(hash([room.grid_pos.x, room.grid_pos.y, "fallback"])) % opts.size()]
	return kind


func _objective_blocked(room: Room) -> bool:
	if room == main._hormone_room:
		return true
	var kq := KeyQuests.of(get_tree())
	if kq == null:
		return false
	# ojo: la mision puede ser de un piso anterior (sus salas ya estan liberadas de memoria)
	var h = kq.get("home")
	var v = kq.get("vault")
	return (is_instance_valid(h) and h == room) or (is_instance_valid(v) and v == room)


## Condiciones de la partida: la misma que usa on_enter y el cartel de la puerta (para no mentir).
func _will_run(room: Room, kind: String) -> bool:
	if kind == "" or not KINDS.has(kind) or room.cleared or room.has_meta("dyn_done"):
		return false
	if started.has(room):
		return false
	if KINDS[kind].cat == "objective" and _objective_blocked(room):
		return false
	if KINDS[kind].cat == "encounter":
		var kq2 := KeyQuests.of(get_tree())
		var vault = kq2.get("vault") if kq2 != null else null
		if is_instance_valid(vault) and vault == room and kind != "mercado":
			return false  # el cofre con candado ya ocupa la sala
	return true


# ------------------------------------------------------------------ entrar en una sala
func enter(room: Room, entry_door: Door) -> void:
	if _root != main.dungeon_root:
		_reset_floor()
	_decorate_doors(room)
	_pact_enforce(room)
	if room.cleared or room.has_meta("dyn_done"):
		return
	var kind: String = effective_kind(room)
	# la ladilla que se escapo de otra sala te espera aqui
	if room.has_meta("dyn_thief_loot") and not started.has(room) and room.room_type in COMBATISH:
		kind = "thief"
	if kind == "" or started.has(room) or not _will_run(room, kind):
		_start_extra(room, entry_door)
		return
	var info: Dictionary = KINDS[kind]
	if info.cat in ["objective", "modifier"] and not main._has_real_weapon():
		return  # desarmado las puertas no se sellan y se va a por el arma: ni objetivos ni modificadores (quedan pendientes)
	_launch(room, kind, entry_door)
	_start_extra(room, entry_door)


func _start_extra(room: Room, entry_door: Door) -> void:
	var k2: String = str(plan2.get(room.grid_pos, ""))
	if k2 != "" and not extra_started.has(room) and not room.cleared:
		extra_started[room] = true
		_launch(room, k2, entry_door, false)


func _launch(room: Room, kind: String, entry_door: Door, main_one := true) -> void:
	var info: Dictionary = KINDS[kind]
	if info.cat == "objective":
		room.set_meta("dynamic", kind)  # las oleadas (src/combat/waves.gd) no se mezclan con un objetivo
	var dyn: RoomDynamic = _script_for(kind).new()
	dyn.main = main
	dyn.room = room
	dyn.director = self
	dyn.kind = kind
	dyn.entry_door = entry_door
	dyn.name = "Dyn_" + kind
	print("[salas] piso %d sala %s %s: %s" % [get_node("/root/RunManager").current_floor, Room.RoomType.keys()[room.room_type], room.grid_pos, kind])
	if main_one:
		started[room] = dyn
		if kind in OWN_SPAWN:
			dyn.owns_spawn = true
			owns[room] = true
		if info.cat == "objective":
			room.clear_gate = dyn.gate
	room.add_child.call_deferred(dyn)  # se entra desde un callback de fisica


# ------------------------------------------------------------------ carteles de las puertas
func tag_for(room: Room) -> String:
	if room.cleared or room.has_meta("dyn_done"):
		return ""
	if room.has_meta("dyn_thief_loot"):
		return tr("RM_TAG_THIEF2")
	var kind: String = effective_kind(room)
	if kind == "" or not _will_run(room, kind):
		return ""
	var tag := tr("RM_TAG_" + kind.to_upper())
	var k2: String = str(plan2.get(room.grid_pos, ""))
	if k2 != "":
		tag += " + " + tr("RM_TAG_" + k2.to_upper())
	return tag


## Anade al cartel de cada puerta (ya puesto por main._label_doors) lo que hay detras.
func _decorate_doors(room: Room) -> void:
	var gen: DungeonGenerator = main.dungeon_generator
	for door: Door in room.doors.values():
		var target: Room = gen.rooms.get(door.target_pos)
		if target == null:
			continue
		var tag := tag_for(target)
		if tag == "":
			continue
		var hint: Label = door._hint
		var col := Color("f2ead6")
		var txt := ""
		if hint != null:
			txt = hint.text
			col = hint.get_theme_color("font_color")
		# si ya le puse una linea (el plan cambio al conocerse la mision de llave), se quita antes
		var prev: String = str(door.get_meta("dyn_tag", ""))
		if prev != "" and txt.ends_with(prev):
			txt = txt.left(txt.length() - prev.length()).trim_suffix("\n")
		door.set_meta("dyn_tag", tag)
		door.set_hint((txt + "\n" if txt != "" else "") + tag, col)


# ------------------------------------------------------------------ pacto de la Hoja de Parra
## Durante el pacto del Recato el mundo se queda gris y el narrador calla.
func pact_start_gray(seconds: float) -> void:
	_pact_gray_until = Time.get_ticks_msec() + seconds * 1000.0
	_pact_mute_until = _pact_gray_until
	if main.current_room != null:
		_pact_enforce(main.current_room)


func pact_active() -> bool:
	return Time.get_ticks_msec() < _pact_gray_until


func _pact_enforce(room: Room) -> void:
	if not pact_active():
		return
	if bool(room.get_meta("rl_colored", false)):
		Censor.set_colored(room, false, false)
		main._lighting.paint(room, false, false)
	_last_gray_room = room


var _kq_seen := false
var _dead_t := 0.0


## Red de seguridad (respaldo): main._on_enemy_killed ya comprueba la sala con cualquier muerte,
## con o sin autor; si aun asi quedara una sala con todos sus enemigos muertos sin limpiar
## (muertes sin enemy_killed, enemigos quitados a mano...) se limpia a los 2 s. Respeta clear_gate: no toca las salas con objetivo abierto.
func _dead_room_watch(delta: float) -> void:
	var r: Room = main.current_room
	if r == null or r.cleared or r.enemies_spawned.is_empty() or not (r.room_type in COMBATISH or r.room_type in [Room.RoomType.MINIBOSS, Room.RoomType.BOSS]):
		_dead_t = 0.0
		return
	if RoomUtil.alive(r).is_empty() and not (r.clear_gate.is_valid() and not r.clear_gate.call()):
		_dead_t += delta
		if _dead_t > 2.0:
			_dead_t = 0.0
			r.room_cleared()
			if r.cleared:
				print("[salas] sala %s sin enemigos vivos y sin limpiar: se limpia (red de seguridad)" % r.grid_pos)
	else:
		_dead_t = 0.0


func _process(delta: float) -> void:
	_dead_room_watch(delta)
	if not _kq_seen and main.current_room != null:
		var kq := KeyQuests.of(get_tree())
		if kq != null and kq.ready_ok:
			_kq_seen = true  # ya se sabe donde esta la mision de llave: los carteles pueden cambiar
			_decorate_doors(main.current_room)
	if _pact_gray_until > 0.0:
		if pact_active():
			Narrator._queue.clear()  # el narrador calla (Narrator no se toca: se le vacia la cola)
			if main.current_room != null and bool(main.current_room.get_meta("rl_colored", false)):
				_pact_enforce(main.current_room)
		else:
			_pact_gray_until = 0.0
			_pact_mute_until = 0.0
			Narrator.toast(tr("RM_PACT_END_T"), tr("RM_PACT_END"), "c08cff")
			var r: Room = main.current_room
			if r != null:
				main._paint_room(r, r.cleared or r.room_type in main.CALM_ROOMS, true)
