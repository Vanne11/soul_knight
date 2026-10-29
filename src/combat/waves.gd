class_name Waves
extends Node

## Oleadas: una sala de combate trae 1-3 tandas en vez de una sola. La siguiente entra cuando
## quedan pocos vivos, avisada en las puertas, y la sala no se da por limpia (ni se abren las
## puertas, ni hay recompensa) hasta acabar la ultima. Cuelga de la sala (meta "waves").
##
## Enganches: main._spawn_room_enemies -> Waves.enabled_for(room) / Waves.start(...);
## Room.room_cleared() -> hold_clear(). Los datos de cada bicho los sigue dando
## main._generate_enemy_data_for_room (elites, escalado, ITS... igual que antes).
##
## ---------------------------------------------------------------------------------
## CURVA (tabla CURVE, por posicion 1..10; _curve() la estira al largo real de la ruta: el ultimo
## piso es siempre la fila 10, con 10 pisos la tabla sale tal cual)
##   p_waves  probabilidad de 1 / 2 / 3 oleadas (se sortea con la semilla, RNG del juego)
##   mult     multiplica la cantidad de bichos de hoy (RNG.randi_range(2,4) + depth_i), asi el
##            total sube de a poco y repartido (nunca x3 de golpe)
##   form     probabilidad de que una oleada llegue en formacion (GRUPO o PINZA)
##   amb      probabilidad de EMBOSCADA (si la sala tiene 2+ oleadas)
##   piso | oleadas (1/2/3) | mult | form | amb | bichos por sala: antes -> ahora | oleadas/sala
##     1  |  60/35/5   | x1.15 | 25% | 10% |  4.8 ->  5.8 | 1.3
##     2  |  35/45/20  | x1.25 | 35% | 15% |  6.3 ->  8.0 | 1.8
##     3  |  40/42/18  | x1.20 | 30% | 12% |  6.1 ->  7.5 | 1.9
##     4  |  25/45/30  | x1.30 | 40% | 18% |  8.5 -> 10.8 | 2.0
##     5  |  30/45/25  | x1.25 | 40% | 15% |  8.2 -> 10.3 | 2.1
##     6  |  20/45/35  | x1.30 | 45% | 20% | 10.4 -> 12.1 | 2.3
##     7  |  25/45/30  | x1.25 | 45% | 18% |  9.2 -> 11.9 | 2.2
##     8  |  15/45/40  | x1.30 | 50% | 22% | 11.0 -> 13.2 | 2.2
##     9  |  20/45/35  | x1.30 | 50% | 20% | 10.4 -> 14.4 | 2.2
##    10  |  10/40/50  | x1.35 | 55% | 25% | 11.6 -> 17.2 | 2.4
##   (medias de 60 salas simuladas por piso, ruido de +-1; los enjambres cuentan por bicho,
##   group 2-3. El "antes" es lo que daba main sin oleadas.)
##   Suave: las 2 primeras salas de combate del piso 1 son de UNA tanda, sin extra ni formaciones.
##   Reparto de bichos por oleada: 2 oleadas 60/40 %, 3 oleadas 40/35/25 %.
##
## SIGUIENTE OLEADA: cuando quedan <= max(25 % de los que aparecieron, min(2, aparecidos-1))
## y pasaron >= 2.5 s desde la anterior (o cuando no queda ninguno: hold_clear la adelanta).
## Aviso de 1 s: puertas por las que entra parpadean en rojo + sonido + texto; aparece por las
## puertas o bordes lejanos (>= 230 px de ti), nunca encima del jugador.
## Tipos de oleada: dispersa (1a: puntos de aparicion de la sala), puertas (sueltos por las
## puertas lejanas), grupo / pinza / emboscada (ver formations.gd).
## ---------------------------------------------------------------------------------

const ENABLED_TYPES := [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION]

const CURVE := {
	1: {"p_waves": [0.60, 0.35, 0.05], "mult": 1.15, "form": 0.25, "amb": 0.10},
	2: {"p_waves": [0.35, 0.45, 0.20], "mult": 1.25, "form": 0.35, "amb": 0.15},
	3: {"p_waves": [0.40, 0.42, 0.18], "mult": 1.20, "form": 0.30, "amb": 0.12},
	4: {"p_waves": [0.25, 0.45, 0.30], "mult": 1.30, "form": 0.40, "amb": 0.18},
	5: {"p_waves": [0.30, 0.45, 0.25], "mult": 1.25, "form": 0.40, "amb": 0.15},
	6: {"p_waves": [0.20, 0.45, 0.35], "mult": 1.30, "form": 0.45, "amb": 0.20},
	7: {"p_waves": [0.25, 0.45, 0.30], "mult": 1.25, "form": 0.45, "amb": 0.18},
	8: {"p_waves": [0.15, 0.45, 0.40], "mult": 1.30, "form": 0.50, "amb": 0.22},
	9: {"p_waves": [0.20, 0.45, 0.35], "mult": 1.30, "form": 0.50, "amb": 0.20},
	10: {"p_waves": [0.10, 0.40, 0.50], "mult": 1.35, "form": 0.55, "amb": 0.25},
}
const SPLITS := {2: [0.6, 0.4], 3: [0.4, 0.35, 0.25]}
const SOFT_ROOMS := 2          # salas de combate suaves al empezar el piso 1
const MIN_PLAYER_DIST := 230.0 # las oleadas aparecen al menos tan lejos del jugador
const HARD_MIN_DIST := 140.0   # y si el jugador se acerca durante el aviso, se corre hasta aqui
const AMBUSH_DIST := 230.0     # la emboscada sale cuando ya te alejaste tanto de la puerta
const WARN_TIME := 1.0
const MIN_GAP := 2.5
const AGGRO_RANGE := 1600.0    # las oleadas ya saben donde estas (no deambulan en su puerta)

var room: Room
var waves: Array = []          # [{entries: Array[Dictionary], kind: String}]
var entry_door: Door = null    # la puerta por la que entraste (emboscada)
var kinds_used: Array = []     # registro (pruebas): tipo de cada oleada ya lanzada
var _next := 0
var _t_warn := -1.0
var _age := 0.0  # segundos de juego desde que empezo la sala (sin pausas: con el reloj real la emboscada entraba al despausar)
var _since := 0.0
var _peak := 0
var _pending_pos: Array = []
var _pending_anchors: Array = []
var _finished := false


## Hay oleadas en esta sala? Gancho unico para mezclar con otras dinamicas: una sala con
## metadato "dynamic" (objetivos/modificadores de sala) o "no_waves" se queda como esta.
static func enabled_for(room_: Room) -> bool:
	if room_ == null or room_.cleared or room_.room_type not in ENABLED_TYPES:
		return false
	if room_.has_meta("dynamic") or room_.has_meta("no_waves"):
		return false
	return true


## Cuantos bichos (contando los grupos) hay en una lista de datos.
static func head_count(entries: Array) -> int:
	var n := 0
	for e in entries:
		n += int(e.get("group", 1))
	return n


## Crea las oleadas de la sala y lanza la primera. true = ya se encargo (main no spawnea).
static func start(main: Node, room_: Room, seal: bool) -> bool:
	if room_.has_meta("waves"):
		return true
	var floor_n: int = main._run_manager.current_floor
	var soft: bool = floor_n == 1 and int(main.rooms_cleared_this_floor) < SOFT_ROOMS
	var pool: Array[Dictionary] = build_pool(main, room_, floor_n, soft)
	if pool.is_empty():
		return false
	if not seal:
		# Vas desarmado y puedes huir: una sola tanda, como siempre.
		room_.spawn_enemies(pool, false)
		return true
	var w := Waves.new()
	w.name = "Waves"
	w.room = room_
	w.waves = make_plan(pool, floor_n, soft, true)
	w.entry_door = _find_entry_door(room_)
	if w.entry_door == null:  # sin puerta de entrada no hay "espalda"
		for wv in w.waves:
			if wv.kind == "emboscada":
				wv.kind = "puertas"
	room_.set_meta("waves", w)
	room_.add_child(w)
	w._spawn_wave(true)
	return true


## Los bichos de la sala: lo de siempre (main) + el extra de la curva, barajado.
static func build_pool(main: Node, room_: Room, floor_n: int, soft: bool) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	pool.assign(main._generate_enemy_data_for_room(room_))
	var mult: float = 1.0 if soft else float(_curve(floor_n).mult) * Censura.mult("wave_mult")  # Censura: mas bichos por sala
	var extra := roundi(float(pool.size()) * (mult - 1.0))
	if extra > 0:
		var more: Array = main._generate_enemy_data_for_room(room_)
		RNG.shuffle(more)
		for i in mini(extra, more.size()):
			pool.append(more[i])
	RNG.shuffle(pool)
	return pool


## Reparte el pool en oleadas y sortea el tipo de cada una (todo con el RNG del juego, al
## entrar a la sala, asi la misma semilla da las mismas oleadas).
static func make_plan(pool: Array, floor_n: int, soft: bool, can_ambush: bool) -> Array:
	var c: Dictionary = _curve(floor_n)
	var n_waves := 1
	if not soft:
		var r := RNG.randf()
		var p: Array = c.p_waves
		n_waves = 1 if r < float(p[0]) else (2 if r < float(p[0]) + float(p[1]) else 3)
	n_waves = clampi(n_waves, 1, maxi(1, pool.size() / 2))
	var out: Array = []
	var from := 0
	for i in n_waves:
		var cnt := pool.size() - from
		if i < n_waves - 1:
			cnt = clampi(roundi(float(pool.size()) * float(SPLITS[n_waves][i])), 1, pool.size() - from - (n_waves - 1 - i))
		var entries: Array[Dictionary] = []
		entries.assign(pool.slice(from, from + cnt))
		from += cnt
		var kind := "dispersa" if i == 0 else "puertas"
		if not soft and RNG.randf() < float(c.form):
			var opts: Array = []
			if Formations.can_group(entries):
				opts += ["grupo", "grupo"]
			if entries.size() >= 4:
				opts.append("pinza")
			if not opts.is_empty():
				kind = opts[RNG.randi_range(0, opts.size() - 1)]
		out.append({"entries": entries, "kind": kind})
	if can_ambush and out.size() >= 2 and not soft and RNG.randf() < float(c.amb):
		out[1].kind = "emboscada"
	return out


## Fila de la curva para el piso n de la ruta. La tabla esta escrita para 10 pisos; con una ruta de
## otro largo (11 con la Prostata, 12 con el Utero y la Prostata) se estira: el ultimo piso es el 10 de la tabla y
## los intermedios se interpolan (con 10 pisos sale la tabla tal cual).
static func _curve(floor_n: int) -> Dictionary:
	var total := maxi(RunManager.route_size(), 2)
	var pos := 1.0 + 9.0 * float(clampi(floor_n, 1, total) - 1) / float(total - 1)
	var lo := clampi(int(floorf(pos)), 1, 10)
	var hi := mini(lo + 1, 10)
	var k := pos - float(lo)
	var a: Dictionary = CURVE[lo]
	var b: Dictionary = CURVE[hi]
	var pw: Array = []
	for i in 3:
		pw.append(lerpf(float(a.p_waves[i]), float(b.p_waves[i]), k))
	return {"p_waves": pw, "mult": lerpf(float(a.mult), float(b.mult), k),
		"form": lerpf(float(a.form), float(b.form), k), "amb": lerpf(float(a.amb), float(b.amb), k)}


## Puerta por la que entraste: la mas cercana al jugador si esta cerca (si entraste "de
## golpe" al centro de la sala no hay espalda).
static func _find_entry_door(room_: Room) -> Door:
	var player: Node2D = room_.get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	var best: Door = null
	var best_d := 220.0
	for d in room_.doors.values():
		var dd: float = d.global_position.distance_to(player.global_position)
		if dd < best_d:
			best_d = dd
			best = d
	return best


# ---------------------------------------------------------------------------------
# Vida de la sala
# ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _finished:
		return
	if room.cleared:
		_finished = true
		return
	_since += delta
	_age += delta
	if _t_warn >= 0.0:
		_t_warn -= delta
		if _t_warn < 0.0:
			_spawn_wave(false)
		return
	if _next >= waves.size():
		return
	var kind: String = waves[_next].kind
	var go := false
	if kind == "emboscada":
		# a tu espalda: cuando ya te alejaste de la puerta (o pasaron 10 s)
		var el := _age
		var player := _player()
		go = el > 1.5 and ((player != null and entry_door != null and \
				player.global_position.distance_to(entry_door.global_position) > AMBUSH_DIST) or el > 10.0)
	if kind != "emboscada" and _since >= MIN_GAP and _alive() <= _threshold():
		go = true
	if go:
		_begin_warn()


## Sala sin limpiar mientras queden oleadas: Room.room_cleared() pregunta aqui.
func hold_clear() -> bool:
	if _finished or _next >= waves.size():
		return false
	if _t_warn < 0.0:
		_begin_warn()  # se mataron todos antes de tiempo: la siguiente entra ya
	return true


## Vivos de la sala (cuentan los invocados/clones que se agregan a enemies_spawned).
func _alive() -> int:
	var n := 0
	for e in room.enemies_spawned:
		if e != null and is_instance_valid(e) and not e.is_queued_for_deletion() \
				and (not ("current_health" in e) or float(e.current_health) > 0.0):
			n += 1
	return n


## Cuantos vivos hacen entrar la siguiente: <= 25 % de los que aparecieron o <= 2.
func _threshold() -> int:
	return maxi(_peak / 4, mini(2, _peak - 1))


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null


func _begin_warn() -> void:
	var wv: Dictionary = waves[_next]
	var anchors: Array = []
	_pending_pos = _positions(wv, _next, anchors)
	_pending_anchors = anchors
	_t_warn = WARN_TIME
	for a in anchors:
		if a.door != null:
			_flash_door(a.door)
	Sound.play("locked")
	var player := _player()
	if player != null:
		var key := "WAVE_AMBUSH" if wv.kind == "emboscada" else ("WAVE_PINCER" if wv.kind == "pinza" else "WAVE_INCOMING")
		get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -52), tr(key) % [_next + 1, waves.size()], Color("ff6a4a"))


func _spawn_wave(first: bool) -> void:
	var wv: Dictionary = waves[_next]
	var positions: Array = _pending_pos if not first else _positions(wv, _next, [])
	_pending_pos = []
	_pending_anchors = []
	_t_warn = -1.0
	_keep_off_player(positions)
	var before := room.enemies_spawned.size()
	var typed: Array[Dictionary] = []
	typed.assign(wv.entries)
	room.spawn_enemies(typed, first, positions)
	kinds_used.append(wv.kind)
	_next += 1
	_since = 0.0
	_peak = 0
	for i in range(before, room.enemies_spawned.size()):
		_peak += 1
	if not first:
		Sound.play("door")
		_aggro(before)


## Las oleadas siguientes ya te han visto entrar: persiguen desde el principio.
func _aggro(from: int) -> void:
	await get_tree().create_timer(0.15).timeout
	if room == null or room.cleared:
		return
	for i in range(from, room.enemies_spawned.size()):
		var e = room.enemies_spawned[i]
		if e != null and is_instance_valid(e) and "detection_range" in e:
			e.detection_range = maxf(float(e.detection_range), AGGRO_RANGE)


func _flash_door(door: Door) -> void:
	if door == null or not is_instance_valid(door) or door.sprite == null:
		return
	var orig := door.sprite.modulate
	var tw := door.create_tween()
	for k in 4:
		tw.tween_property(door.sprite, "modulate", Color(2.4, 0.45, 0.45), 0.12)
		tw.tween_property(door.sprite, "modulate", orig, 0.12)
	tw.tween_callback(func(): if is_instance_valid(door): door.sprite.modulate = orig)


## Interior de la sala (global), con margen para no aparecer dentro del muro.
func _inner_rect() -> Rect2:
	var used: Rect2i = room.floor_tilemap.get_used_rect()
	var r := Rect2(room.global_position + Vector2(used.position) * 64.0, Vector2(used.size) * 64.0)
	return r.grow(-48.0) if r.size.x > 120.0 and r.size.y > 120.0 else r


## Nunca encima del jugador ni fuera de la sala: si alguien quedo muy cerca (te acercaste
## durante el aviso) se corre al punto mas cercano que este a HARD_MIN_DIST y dentro de la sala.
func _keep_off_player(positions: Array) -> void:
	var player := _player()
	var inner := _inner_rect()
	for i in positions.size():
		var p: Vector2 = positions[i]
		if player != null and p.distance_to(player.global_position) < HARD_MIN_DIST:
			var best := p
			var best_d := INF
			for k in 16:
				var c: Vector2 = player.global_position + Vector2.RIGHT.rotated(TAU * float(k) / 16.0) * HARD_MIN_DIST * 1.15
				if inner.has_point(c) and c.distance_to(p) < best_d:
					best_d = c.distance_to(p)
					best = c
			p = best
		positions[i] = room.snap_global(Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y)), 24.0)  # y en suelo pisable (forma de sala)


# ---------------------------------------------------------------------------------
# Donde aparece cada oleada
# ---------------------------------------------------------------------------------

## Anclas lejanas al jugador: puertas primero y despues bordes (puntos de aparicion).
func _anchors(rng: RandomNumberGenerator, only_doors := false) -> Array:
	var player := _player()
	var ppos: Vector2 = player.global_position if player != null else room.global_position + room.get_center_position()
	var center: Vector2 = room.global_position + room.get_center_position()
	var doors: Array = []
	var points: Array = []
	for d in room.doors.values():
		var a := Formations.door_anchor(d)
		if a.base.distance_to(ppos) >= MIN_PLAYER_DIST:
			doors.append(a)
	if not only_doors:
		for sp in room.spawn_points:
			if sp.distance_to(ppos) >= MIN_PLAYER_DIST:
				points.append(Formations.point_anchor(sp, center))
	var out: Array = doors + points
	if out.is_empty():  # sala chica o jugador en medio: el mas lejano que haya
		var best = null
		var best_d := -1.0
		for d in room.doors.values():
			var a := Formations.door_anchor(d)
			if a.base.distance_to(ppos) > best_d:
				best_d = a.base.distance_to(ppos)
				best = a
		for sp in room.spawn_points:
			if sp.distance_to(ppos) > best_d:
				best_d = sp.distance_to(ppos)
				best = Formations.point_anchor(sp, center)
		if best != null:
			out.append(best)
	# barajado determinista
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## Posiciones globales (una por entrada) de la oleada; `used` recibe las anclas (puertas a avisar).
func _positions(wv: Dictionary, idx: int, used: Array) -> Array:
	var entries: Array = wv.entries
	var rng := RandomNumberGenerator.new()
	var rm := get_node("/root/RunManager")
	rng.seed = hash([rm.current_seed, rm.current_floor, room.grid_pos.x, room.grid_pos.y, idx, "oleada"])
	var kind: String = wv.kind
	var out: Dictionary = {}
	var all_idx: Array = range(entries.size())
	var center: Vector2 = room.global_position + room.get_center_position()

	if kind == "emboscada" and entry_door != null:
		var a := Formations.door_anchor(entry_door)
		a.front = 40.0  # pegados a la puerta: tu espalda, no el medio de la sala
		var player := _player()
		if player != null and (a.base + a.inward * float(a.front)).distance_to(player.global_position) < HARD_MIN_DIST * 1.1:
			var alt := _anchors(rng, true)  # sigues pegado a la puerta: otra puerta lejana
			kind = "grupo"
			a = alt[0] if not alt.is_empty() else a
		Formations.place(entries, all_idx, a, out)
		used.append(a)
	elif kind == "pinza":
		var cand := _anchors(rng)
		var pair := _farthest_pair(cand)
		if pair.is_empty():
			kind = "grupo"
		else:
			var sides: Array = [[], []]
			var front_n := 0
			var back_n := 0
			for i in all_idx:  # reparte alternando por rol para que cada lado tenga delante y detras
				if Formations.role(entries[i]) == "fondo":
					sides[back_n % 2].append(i)
					back_n += 1
				else:
					sides[front_n % 2].append(i)
					front_n += 1
			for s in 2:
				Formations.place(entries, sides[s], pair[s], out)
				used.append(pair[s])
	if kind == "grupo" and out.is_empty():
		var cand := _anchors(rng)
		var a: Dictionary = cand[0] if not cand.is_empty() else Formations.point_anchor(center, center)
		Formations.place(entries, all_idx, a, out)
		used.append(a)
	elif kind == "puertas":
		var cand := _anchors(rng, true)
		if cand.is_empty():
			cand = _anchors(rng)
		for i in all_idx:
			var a: Dictionary = cand[rng.randi_range(0, cand.size() - 1)] if not cand.is_empty() else Formations.point_anchor(center, center)
			out[i] = a.base + a.inward * rng.randf_range(0.0, 90.0) + a.inward.orthogonal() * rng.randf_range(-45.0, 45.0)
			if a.door != null and not used.has(a):
				used.append(a)
	elif kind == "dispersa":
		var ppos := _player().global_position if _player() != null else center
		var pts: Array = []
		for sp in room.spawn_points:
			if sp.distance_to(ppos) >= MIN_PLAYER_DIST:
				pts.append(sp)
		if pts.size() < entries.size():  # pocos puntos lejos: completa con los mas lejanos
			var rest: Array = room.spawn_points.filter(func(p): return not pts.has(p))
			rest.sort_custom(func(a, b): return a.distance_to(ppos) > b.distance_to(ppos))
			pts += rest
		if pts.is_empty():
			pts = [center]
		for i in range(pts.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = pts[i]
			pts[i] = pts[j]
			pts[j] = t
		for i in all_idx:
			out[i] = pts[i % pts.size()]
	var res: Array = []
	for i in all_idx:
		res.append(out.get(i, center))
	return res


## Las dos anclas mas separadas entre si (>= 300 px); [] si no hay un par asi.
func _farthest_pair(cand: Array) -> Array:
	var best: Array = []
	var best_d := 300.0
	for i in cand.size():
		for j in range(i + 1, cand.size()):
			var d: float = cand[i].base.distance_to(cand[j].base)
			if d > best_d:
				best_d = d
				best = [cand[i], cand[j]]
	return best
