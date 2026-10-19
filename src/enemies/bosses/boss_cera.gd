extends EnemyBoss

## DOÑA CERA CALIENTE (piso 1, Selva Publica) - PROTOTIPO DE JEFE DINAMICO (Plan 3).
## Usa el motor dinamico de enemy_boss.gd (dynamic = true): reposo corto, avisos acotados,
## combos en fase 2-3, balas rapidas, defensa durante la cura y resumen [boss-stats].
## IDENTIDAD: la cera que deja se ENDURECE y se vuelve pared (ver cera_wax.gd); la sala se
## llena y te acorrala, pero nunca te encierra (flood fill). Se rompe a tiros.
## - PRESION: se acerca apuntando a donde vas, se desliza si la kiteas, y ataca mientras camina
##   (goteo + escupitajo suelto). Si te pegas mucho rato: PISOTON (aviso + onda). Solo pega con
##   el cuerpo al embestir o pisar (el hitbox esta apagado en reposo).
## - ATAQUES: abanico, rafaga con prediccion, cortina (cierra huecos: hay que usar el dash),
##   salpicadura, tiron (agotada si falla), embestida, cruz (agotada), y en fase 3 la firma
##   DEPILACION TOTAL (olas que cruzan la sala) mientras la cera sube por los bordes.
## - CURAS (max 2): se defiende mientras canaliza; ch_tira acelera, esquiva, en fase 2-3 trae
##   senuelo y en fase 3 dos tiras reales. Completada: furia breve. Cortada: aturdida larga + danio.
## - CUADERNO (boss_notebook.gd): detecta si siempre esquivas al mismo lado (te pone un charco
##   ahi) o si la rodeas siempre igual (te corta el paso) y te AVISA con texto.
## - ESBIRROS: gotitas de cera (enemy_gota_cera.gd), oleadas segun fase.

const WAX := Color(1.0, 0.78, 0.3)
const MAX_PUDDLES := 6
const GOTA := preload("res://src/enemies/enemy_gota_cera.tscn")
const SOLID_CAP := [4, 6, 8]
const EDGE_W := 52.0
const BIG := [&"atk_cruz", &"atk_oleada"]
const HP_MULT := 0.65

var notebook := BossNotebook.new()
var _aim := Vector2.RIGHT
## Angulo de puntería fijado 0.2 s antes de disparar (la linea de aviso deja de seguirte: justo).
var _lock_ang := 0.0
## Ayuda para el bot de pruebas: sitio seguro (el hueco de la cortina o la ola). null = ninguno.
var bot_safe: Variant = null
var _aim_len := 500.0
var _walk := 0.0
var _drip_dist := 0.0
var _last_pos := Vector2.ZERO
var _spit_t := 3.0
var _spit_warn := 0.0
var _threat_hold := 0.0
var _rage_t := 0.0
var _punish := false
var _close_t := 0.0
var _orbit_dir := 1.0
var _slide_t := 0.0
var _slide_cd := 1.5
var _slide_dir := Vector2.ZERO
var _prev_rel_n := Vector2.ZERO
var _ang_speed := 0.0
var _wave_t := 8.0
var _edge_t := -1.0
var _edges_done := []
var _edge_in := {"L": 0.0, "R": 0.0, "T": 0.0, "B": 0.0}
var _grid_ready := false
var _grid_open := PackedByteArray()
var _grid_cols := 0
var _grid_rows := 0
var _grid_org := Vector2.ZERO
var _grid_base := 1
var _hard_msg := false
var _pat_text_t := {}
var _trap_cd := 0.0
var _def_t := 1.0
var _strip_pos := Vector2.ZERO  # tira real mas cercana (la defensa protege esa ruta)
var _strips: Array = []


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = WAX
	keep_min = 110.0
	keep_max = 150.0
	rest_min = 0.45
	rest_max = 0.8
	bullet_speed = 290.0
	tele_caps = [0.85, 0.7, 0.6]
	# Balance (meta del PLAN 3: 60-120 s y 3-8 golpes al bot sin modo dios): vida x0.65
	max_health *= HP_MULT
	current_health = max_health
	_emit_health()
	move_speed = 120.0
	# max 2 curas por pelea (antes = numero de piso)
	_channels_total = 2
	_channels_left = 2
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	_last_pos = global_position
	notebook.pattern_detected.connect(_on_pattern)
	telegraph_started.connect(_on_telegraph)
	BossAnimator.attach(self)  # cuadros nuevos + animacion por codigo (solo si el SpriteFrames los trae)


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_abanico", &"atk_rafaga", &"atk_salpicadura", &"atk_tiron", &"atk_abanico"]
		2:
			return [&"atk_abanico", &"atk_rafaga", &"atk_salpicadura", &"atk_cortina", &"atk_tiron", &"atk_embiste"]
	return [&"atk_cortina", &"atk_cortina", &"atk_rafaga", &"atk_tiron", &"atk_cruz", &"atk_embiste", &"atk_oleada", &"atk_salpicadura"]


func _challenges() -> Array:
	return [&"ch_tira"]


func _channel_color() -> Color:
	return WAX


func _on_phase(n: int) -> void:
	move_speed = [120.0, 145.0, 170.0][n - 1]
	_wave_t = 3.0
	_slide_cd = 1.0
	if n == 3:
		_edge_t = 3.0
		_float_text(tr("CERA_DESPERATE"), Color("ff8a3a"))


func _on_death() -> void:
	for w in get_tree().get_nodes_in_group(WaxBlock.GROUP):
		if is_instance_valid(w):
			w.crumble()


func _hit_source() -> String:
	var tp: Vector2 = target.global_position
	for g in get_tree().get_nodes_in_group("gota_cera"):
		if is_instance_valid(g) and g.global_position.distance_to(tp) < 60.0:
			return "gotita"
	for w in get_tree().get_nodes_in_group(WaxBlock.GROUP):
		if w is WaxBlock and w.kind == WaxBlock.Kind.PUDDLE and w.phase in [WaxBlock.Ph.BURN, WaxBlock.Ph.COOL] and w.global_position.distance_to(tp) < w.radius + 16.0:
			return "charco_goteo" if state != State.ATTACK else "charco"
	return "escupitajo"


## Toda zona de peligro de Cera se dibuja como cera caliente (estilo WAX).
func _add_hazard(z: BossZone) -> BossZone:
	if z.style == BossZone.Style.NORMAL:
		z.style = BossZone.Style.WAX
	return super(z)


func _speed() -> float:
	return move_speed * (1.25 if _rage_t > 0.0 else 1.0)


func _is_threatening() -> bool:
	return state == State.ATTACK or (state == State.IDLE and _threat_hold > 0.0)


## Zona jugable: la arena menos las bandas de cera que han subido por los bordes.
func _inner() -> Rect2:
	var a := arena()
	return Rect2(a.position + Vector2(_edge_in.L, _edge_in.T), a.size - Vector2(_edge_in.L + _edge_in.R, _edge_in.T + _edge_in.B))


func _cl(p: Vector2, margin := 50.0) -> Vector2:
	var a := _inner().grow(-margin)
	return _on_floor(Vector2(clampf(p.x, a.position.x, a.end.x), clampf(p.y, a.position.y, a.end.y)))


func _ts(x: float) -> float:
	return minf(x, tele_caps[clampi(current_phase, 1, 3) - 1])


## Donde estara el jugador cuando llegue una bala de velocidad `spd` (prediccion).
func _lead(spd: float, k := 0.9) -> Vector2:
	var p: Vector2 = target.global_position
	var v := Vector2.ZERO
	if target is CharacterBody2D:
		v = (target as CharacterBody2D).velocity
	var t := minf(p.distance_to(_muzzle()) / spd, 0.8)
	return p + v * t * k


# ---------------------------------------------------------------- pasivos y presion
func _tick(delta: float) -> void:
	if state in [State.INTRO, State.DEAD]:
		return
	notebook.update(delta, target, self, arena())
	_rage_t = maxf(0.0, _rage_t - delta)
	_threat_hold = maxf(0.0, _threat_hold - delta)
	_trap_cd = maxf(0.0, _trap_cd - delta)
	if _minion_count() > 0:
		_threat_hold = maxf(_threat_hold, 0.3)
	if state == State.TRANSITION:
		_last_pos = global_position
		return
	_wave_logic(delta)
	_edge_logic(delta)
	# castigo si te pegas: cuenta el tiempo seguido cerca de ella
	if state == State.IDLE and target.global_position.distance_to(global_position) < 115.0:
		_close_t += delta
		if _close_t > 1.7 and not _punish:
			_punish = true
			_timer = minf(_timer, 0.05)
	else:
		_close_t = maxf(0.0, _close_t - delta * 0.7)
	# ataca mientras camina
	if state == State.ATTACK and _walk > 0.0 and not _channeling and _slide_t <= 0.0:
		var to_t: Vector2 = _lead(300.0, 0.6) - global_position
		velocity = to_t.normalized() * _speed() * _walk if to_t.length() > 140.0 else to_t.orthogonal().normalized() * _speed() * _walk * 0.6 * _orbit_dir
	# goteo: charcos que se endurecen
	if state in [State.IDLE, State.ATTACK]:
		var moved := global_position.distance_to(_last_pos)
		if moved > 0.3 and moved < 60.0 and not _channeling:
			_drip_dist += moved
			if _drip_dist >= 320.0:
				_drip_dist = 0.0
				_puddle(global_position + Vector2(0, 6), 0.6, 2.5)
	_last_pos = global_position
	# escupitajo suelto con aviso corto (solo en reposo: en ataque ya tiene sus avisos)
	if state == State.IDLE:
		_spit_t -= delta * (1.5 if _rage_t > 0.0 else 1.0)
		if _spit_warn > 0.0:
			_spit_warn -= delta
			animated_sprite.modulate = Color(2.2, 1.6, 0.8) if int(_spit_warn * 24.0) % 2 == 0 else Color.WHITE
			if _spit_warn <= 0.0:
				animated_sprite.modulate = Color.WHITE
				var spd: float = [240.0, 280.0, 310.0][RNG.randi_range(0, 2)]
				var ang := (_lead(spd) - _muzzle()).angle()
				_fire(ang, spd, 0.5)
				_threat_hold = 1.5
				_spit_t = RNG.randf_range(4.2, 5.6) / (1.0 + 0.2 * (current_phase - 1))
		elif _spit_t <= 0.0:
			_spit_warn = 0.45


func _idle_move(delta: float) -> void:
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	_orbit_t -= delta
	if _orbit_t <= 0.0:
		_orbit_dir = -_orbit_dir
		_orbit_t = RNG.randf_range(1.2, 2.4)
	_slide_cd = maxf(0.0, _slide_cd - delta)
	# a donde va: delante de ti; si siempre la rodeas igual, se adelanta para cortarte el paso
	var aim_pt := _lead(_speed(), 1.0)
	var op := notebook.orbit_pattern()
	if not op.is_empty():
		var tang := to_t.orthogonal().normalized() * (-1.0 if op.dir == &"horario" else 1.0)
		aim_pt += tang * 130.0
	if _slide_t > 0.0:
		_slide_t -= delta
		velocity = _slide_dir * _speed() * 2.8
		if int(_slide_t * 30.0) % 3 == 0:
			_add_hazard(BossZone.circle(global_position, 26.0, 0.0, 0.2, 0.0, Color(WAX, 0.6)))  # estela (inofensiva)
		return
	# reposicion rapida si la kiteas en circulos o te alejas
	var rel_n := to_t.normalized()
	if _prev_rel_n != Vector2.ZERO:
		_ang_speed = lerpf(_ang_speed, absf(_prev_rel_n.cross(rel_n)) / maxf(delta, 0.001), 0.1)
	_prev_rel_n = rel_n
	if _slide_cd <= 0.0 and ((d > 340.0) or (_ang_speed > 1.0 and d > 150.0)):
		_slide_dir = (aim_pt - global_position).normalized()
		_slide_t = 0.4
		_slide_cd = 2.4
		_ang_speed = 0.0
		Sound.play("dash")
		return
	var dir := Vector2.ZERO
	if d > 165.0:
		dir = (aim_pt - global_position).normalized()
	elif d < 105.0:
		dir = -rel_n * 0.8 + rel_n.orthogonal() * _orbit_dir * 0.6
	else:
		dir = rel_n.orthogonal() * _orbit_dir * 0.8 + rel_n * 0.2
	var a := _inner()
	var edge := minf(minf(global_position.x - a.position.x, a.end.x - global_position.x), minf(global_position.y - a.position.y, a.end.y - global_position.y))
	if edge < 90.0:
		dir += (a.get_center() - global_position).normalized() * 1.2
	velocity = dir.normalized() * _speed()


func _pick_attack() -> StringName:
	if _punish:
		_punish = false
		_close_t = 0.0
		_combo_left = 0
		return &"atk_pisoton"
	var a := super()
	if a in BIG:
		_combo_left = 0
	return a


func _combo_len() -> int:
	return RNG.randi_range(0, 1) if current_phase >= 2 else 0


func _combo_next() -> StringName:
	var light: Array = [&"atk_abanico", &"atk_rafaga", &"atk_salpicadura"]
	if current_phase >= 2:
		light.append(&"atk_cortina")
	light = light.filter(func(x): return x != _last_attack)
	return light[RNG.randi_range(0, light.size() - 1)]


func _reset_idle() -> void:
	_walk = 0.0
	bot_safe = null


func _fire_fan(shots: int) -> void:
	var base: float = _lock_ang
	for i in range(shots):
		_fire(base + (i - (shots - 1) / 2.0) * 0.2, 380.0 if i % 2 == 0 else 300.0, 0.5)


func _cure_cut_stun() -> float:
	return 5.0


# ---------------------------------------------------------------- cera: charcos que se endurecen
## Charco de cera: avisa, quema, se enfria y (si cabe) se vuelve pared.
func _puddle(pos: Vector2, warn: float, burn: float, harden := true) -> WaxBlock:
	var live := 0
	for z in get_tree().get_nodes_in_group(WaxBlock.GROUP):
		if z is WaxBlock and z.kind == WaxBlock.Kind.PUDDLE and z.phase < WaxBlock.Ph.SOLID:
			live += 1
	if live >= MAX_PUDDLES:
		for z in get_tree().get_nodes_in_group(WaxBlock.GROUP):
			if z is WaxBlock and z.kind == WaxBlock.Kind.PUDDLE and z.phase < WaxBlock.Ph.BURN:
				z.dismiss()
				break
	var w := WaxBlock.puddle(self, Vector2.ZERO, 38.0, warn, burn, damage * 0.33, harden)
	_spawn_container().add_child(w)
	w.global_position = _cl(pos, 44.0)
	return w


## Charquito de una gotita muerta: quema un momento y no se endurece.
func wax_spill(pos: Vector2) -> void:
	if state == State.DEAD:
		return
	var w := WaxBlock.puddle(self, Vector2.ZERO, 30.0, 0.3, 2.5, damage * 0.3, false)
	_spawn_container().add_child(w)
	w.global_position = pos


func _solids() -> Array:
	var out := []
	for w in get_tree().get_nodes_in_group(WaxBlock.GROUP):
		if w is WaxBlock and w.is_solid():
			out.append(w)
	return out


## El bloque quiere endurecerse: tope por fase y que no te deje sin salida (flood fill).
func wax_may_solidify(b: WaxBlock) -> bool:
	if state == State.DEAD:
		return false
	if b.kind == WaxBlock.Kind.EDGE:
		return true
	var solids := _solids()
	var puddles := solids.filter(func(x): return x.kind == WaxBlock.Kind.PUDDLE)
	if puddles.size() >= SOLID_CAP[current_phase - 1]:
		var oldest: WaxBlock = puddles[0]
		for x in puddles:
			if x.solid_age > oldest.solid_age:
				oldest = x
		oldest.crumble()
		solids.erase(oldest)
	if not _flood_ok(solids, b):
		return false
	if not _hard_msg:
		_hard_msg = true
		_float_text(tr("CERA_HARDEN"), WAX, Vector2(0, -190))
	return true


func _grid_init() -> void:
	var a := arena()
	var cell := 40.0
	_grid_cols = int(ceil(a.size.x / cell))
	_grid_rows = int(ceil(a.size.y / cell))
	_grid_org = a.position
	_grid_open.resize(_grid_cols * _grid_rows)
	var space := get_world_2d().direct_space_state
	var ex: Array[RID] = [target.get_rid()]
	for w in get_tree().get_nodes_in_group(WaxBlock.GROUP):
		if w is WaxBlock:
			ex.append(w.get_rid())
	var n := 0
	for j in _grid_rows:
		for i in _grid_cols:
			var q := PhysicsPointQueryParameters2D.new()
			q.position = _grid_org + Vector2((i + 0.5) * cell, (j + 0.5) * cell)
			q.collision_mask = 1
			q.exclude = ex
			var open := space.intersect_point(q, 1).is_empty()
			_grid_open[j * _grid_cols + i] = 1 if open else 0
			n += 1 if open else 0
	_grid_ready = true
	_grid_base = maxi(n, 1)


## true si, con el bloque `extra` endurecido, desde donde estas llegas a >= 50% de la sala libre.
func _flood_ok(solids: Array, extra: WaxBlock) -> bool:
	if not _grid_ready:
		_grid_init()
	var cell := 40.0
	var all := solids.duplicate()
	all.append(extra)
	var blocked := PackedByteArray()
	blocked.resize(_grid_cols * _grid_rows)
	for j in _grid_rows:
		for i in _grid_cols:
			var idx := j * _grid_cols + i
			if _grid_open[idx] == 0:
				blocked[idx] = 1
				continue
			var c := _grid_org + Vector2((i + 0.5) * cell, (j + 0.5) * cell)
			for w in all:
				if w.covers(c, 15.0):
					blocked[idx] = 1
					break
	var pc: Vector2 = target.global_position - _grid_org
	var si := clampi(int(pc.x / cell), 0, _grid_cols - 1)
	var sj := clampi(int(pc.y / cell), 0, _grid_rows - 1)
	var start := -1
	for r in 3:  # la celda del jugador puede caer en cera: busca una libre cerca
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				var ii := si + di
				var jj := sj + dj
				if ii >= 0 and jj >= 0 and ii < _grid_cols and jj < _grid_rows and blocked[jj * _grid_cols + ii] == 0 and start < 0:
					start = jj * _grid_cols + ii
	if start < 0:
		return false
	var seen := PackedByteArray()
	seen.resize(_grid_cols * _grid_rows)
	var stack := [start]
	seen[start] = 1
	var count := 0
	while not stack.is_empty():
		var cur: int = stack.pop_back()
		count += 1
		var ci := cur % _grid_cols
		var cj := cur / _grid_cols
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni: int = ci + o.x
			var nj: int = cj + o.y
			if ni < 0 or nj < 0 or ni >= _grid_cols or nj >= _grid_rows:
				continue
			var ni2 := nj * _grid_cols + ni
			if blocked[ni2] == 0 and seen[ni2] == 0:
				seen[ni2] = 1
				stack.append(ni2)
	return float(count) >= 0.5 * float(_grid_base)


## Fase 3: la cera sube por los bordes y achica la sala (una banda cada pocos segundos).
func _edge_logic(delta: float) -> void:
	if _edge_t < 0.0 or current_phase < 3:
		return
	_edge_t -= delta
	if _edge_t > 0.0:
		return
	_edge_t = 7.0
	var a := arena()
	var sides: Array = ["T", "B", "L", "R"]
	if a.size.x < 700.0:
		sides.erase("L")
		sides.erase("R")
	if a.size.y < 520.0:
		sides.erase("T")
		sides.erase("B")
	sides = sides.filter(func(s): return not _edges_done.has(s))
	if sides.is_empty():
		_edge_t = -1.0
		return
	var s: String = sides[RNG.randi_range(0, sides.size() - 1)]
	_edges_done.append(s)
	var pos: Vector2
	var sz: Vector2
	match s:
		"T":
			pos = Vector2(a.get_center().x, a.position.y + EDGE_W * 0.5)
			sz = Vector2(a.size.x, EDGE_W)
		"B":
			pos = Vector2(a.get_center().x, a.end.y - EDGE_W * 0.5)
			sz = Vector2(a.size.x, EDGE_W)
		"L":
			pos = Vector2(a.position.x + EDGE_W * 0.5, a.get_center().y)
			sz = Vector2(EDGE_W, a.size.y)
		_:
			pos = Vector2(a.end.x - EDGE_W * 0.5, a.get_center().y)
			sz = Vector2(EDGE_W, a.size.y)
	var w := WaxBlock.edge(self, Vector2.ZERO, sz, 2.2)
	_spawn_container().add_child(w)
	w.global_position = pos
	_edge_in[s] = EDGE_W
	_float_text(tr("CERA_EDGES"), Color("ff8a3a"))


# ---------------------------------------------------------------- esbirros
func _wave_logic(delta: float) -> void:
	if state in [State.TRANSITION, State.INTRO]:
		return
	_wave_t -= delta
	if _wave_t > 0.0:
		return
	var n: int = [1, 1, 2][current_phase - 1]
	var cap: int = [2, 3, 4][current_phase - 1]
	_wave_t = [20.0, 16.0, 13.0][current_phase - 1]
	if _channeling:
		_wave_t = 4.0
		n = mini(n, 2)
	n = mini(n, cap - get_tree().get_nodes_in_group("gota_cera").size())
	if n > 0:
		_summon(n)


func _summon(n: int) -> void:
	var spots: Array = []
	for i in n:
		var p := arena_point(70.0)
		for _try in 8:
			p = _cl(Vector2(RNG.randf_range(_inner().position.x, _inner().end.x), RNG.randf_range(_inner().position.y, _inner().end.y)), 70.0)
			if p.distance_to(target.global_position) > 220.0:
				break
		spots.append(p)
		_add_hazard(BossZone.circle(p, 30.0, 0.7, 0.05, 0.0, WAX))
	await get_tree().create_timer(0.75, true, true).timeout
	if state == State.DEAD or not is_inside_tree():
		return
	var made := _spawn_minions(spots, 14.0 + 3.0 * current_phase, damage * 0.4, tr("CERA_GOTA"), GOTA)
	for m in get_tree().get_nodes_in_group("gota_cera"):
		if is_instance_valid(m):
			m.move_speed = 150.0 + 12.0 * current_phase
			m.add_collision_exception_with(self)
	if made > 0:
		Sound.play("enemy_shoot")


# ---------------------------------------------------------------- cuaderno del jugador
func _on_pattern(kind: StringName, detail: Variant) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_pat_text_t.get(kind, -99.0)) < 14.0:
		return
	_pat_text_t[kind] = now
	if kind == &"dash":
		var dn := String(detail.dir).to_upper()
		_float_text(tr("CERA_PAT_DASH") % tr("CERA_DIR_" + dn), Color("ff5a3a"), Vector2(0, -190))
		get_tree().create_timer(1.4).timeout.connect(func():
			if state != State.DEAD:
				_float_text(tr("CERA_PAT_DASH_Q%d" % RNG.randi_range(1, 2)), WAX, Vector2(0, -160)))
	elif kind == &"orbit":
		_float_text(tr("CERA_PAT_ORBIT") % tr("CERA_DIR_" + String(detail.dir).to_upper()), Color("ff5a3a"), Vector2(0, -190))
		get_tree().create_timer(1.4).timeout.connect(func():
			if state != State.DEAD:
				_float_text(tr("CERA_PAT_ORBIT_Q%d" % RNG.randi_range(1, 2)), WAX, Vector2(0, -160)))


## Al avisar un ataque: si siempre esquivas al mismo lado, pone un charco ahi (con su aviso).
func _on_telegraph(_secs: float) -> void:
	if _trap_cd > 0.0 or state != State.ATTACK or _channeling:
		return
	var dp := notebook.dash_pattern()
	if dp.is_empty() or RNG.randf() > 0.6:
		return
	_trap_cd = 3.5
	var dv := BossNotebook.dir_vector(dp.dir)
	_puddle(target.global_position + dv * 135.0, 0.9, 4.0)


# ---------------------------------------------------------------- ataques
func atk_abanico() -> void:
	_walk = 0.5
	var line := BossZone.rect(global_position, Vector2(300, 8), 0.0, _ts(0.65) + 0.05, 0.05, 0.0, WAX)
	_add_hazard(line)
	var track := func(left: float):
		if left > 0.2:
			_lock_ang = (_lead(300.0) - _muzzle()).angle()
		if is_instance_valid(line):
			line.global_position = _muzzle() + Vector2.RIGHT.rotated(_lock_ang) * 150.0
			line.rotation = _lock_ang
	if not await _tele(0.65, Color(2.2, 1.6, 0.6), 2.0, track):
		return
	_walk = 0.3
	var volleys := 1 + current_phase / 2
	for v in volleys:
		_fire_fan(3 + current_phase / 2 + (1 if current_phase == 3 else 0))
		if v < volleys - 1 and not await _wait(0.4):
			return
	await _wait(0.2)


## Rafaga con prediccion: tiros rapidos y lentos hacia donde VAS a estar.
func atk_rafaga() -> void:
	_walk = 0.4
	var line := BossZone.rect(global_position, Vector2(300, 8), 0.0, _ts(0.5) + 0.05, 0.05, 0.0, WAX)
	_add_hazard(line)
	var track := func(left: float):
		if left > 0.2:
			_lock_ang = (_lead(320.0) - _muzzle()).angle()
		if is_instance_valid(line):
			line.global_position = _muzzle() + Vector2.RIGHT.rotated(_lock_ang) * 150.0
			line.rotation = _lock_ang
	if not await _tele(0.5, Color(2.2, 1.6, 0.6), 2.0, track):
		return
	_walk = 0.2
	for i in 3 + current_phase / 3:
		var spd := 320.0 if i % 2 == 0 else 260.0
		_fire(_lock_ang + RNG.randf_range(-0.04, 0.04), spd, 0.5)
		if not await _wait(0.2):
			return
	await _wait(0.15)


## Cortina de cera: una pared de gotas con un hueco lejos de ti. Hay que dashear al hueco.
func atk_cortina() -> void:
	_walk = 0.0
	var bp := _muzzle()
	var dir: Vector2 = (target.global_position - bp).normalized()
	var perp := dir.orthogonal()
	var d := bp.distance_to(target.global_position)
	var center := bp + dir * clampf(d - 230.0, 40.0, 400.0)
	var half := 260.0 + 30.0 * current_phase
	var lat := (target.global_position - center).dot(perp)
	var side := 1.0 if RNG.randf() < 0.5 else -1.0
	var gap_c := clampf(lat + side * RNG.randf_range(150.0, 230.0), -half + 70.0, half - 70.0)
	var gap_h := 90.0
	var warn := _ts(0.5) + 0.05
	var seg := func(a: float, b: float):
		if b - a < 10.0:
			return
		_add_hazard(BossZone.rect(center + perp * (a + b) * 0.5, Vector2(b - a, 10.0), perp.angle(), warn, 0.05, 0.0, WAX))
	bot_safe = center + perp * gap_c + dir * (target.global_position - center).dot(dir)
	seg.call(-half, gap_c - gap_h)
	seg.call(gap_c + gap_h, half)
	if not await _tele(0.5, Color(2.2, 1.6, 0.6), 2.5):
		bot_safe = null
		return
	var spd := 290.0 + 10.0 * current_phase
	var x := -half
	while x <= half:
		if absf(x - gap_c) > gap_h:
			_fire_from(center + perp * x, dir.angle(), spd, 0.5, WAX, 4.0)
		x += 42.0
	Sound.play("enemy_shoot")
	await _wait(0.7)
	bot_safe = null


## Tira de cera: aviso, si te alcanza te arrastra. Si falla queda pegada y AGOTADA.
func atk_tiron() -> void:
	_walk = 0.0
	_aim = (target.global_position - _muzzle()).normalized()
	var lane := BossZone.rect(_muzzle(), Vector2(500, 60), 0.0, _ts(0.9) + 0.05, 0.05, 0.0, WAX)
	_add_hazard(lane)
	var track := func(left: float):
		if left > 0.35:
			_aim = (_lead(700.0, 0.25) - _muzzle()).normalized()
		_aim_len = _ray_len(_muzzle(), _aim, 620.0)
		if is_instance_valid(lane):
			lane.size.x = _aim_len
			lane.global_position = _muzzle() + _aim * _aim_len * 0.5
			lane.rotation = _aim.angle()
	if not await _tele(0.9, Color(2.2, 1.6, 0.6), 2.5, track):
		return
	var hit: bool = is_instance_valid(lane) and lane.contains(target.global_position)
	var strike := BossZone.rect(_muzzle() + _aim * _aim_len * 0.5, Vector2(_aim_len, 60), _aim.angle(), 0.0, 0.2, 0.0, Color.WHITE)
	_add_hazard(strike)
	if is_instance_valid(lane):
		lane.dismiss()
	Sound.play("crack")
	HitFx.shake(0.25)
	if not hit:
		# La tira se queda pegada en el suelo: tu ventana.
		_tire(1.4)
		return
	var t := 0.0
	while t < 0.5:
		if not await _frame():
			return
		t += 1.0 / 60.0
		var to_b := global_position - target.global_position
		var dist := to_b.length()
		if dist <= 105.0:
			break
		target.move_and_collide(to_b.normalized() * minf(1100.0 / 60.0, dist - 105.0))
	if target.has_method("receive_hit"):
		target.receive_hit(damage * 0.35)
	# el manotazo da tiempo de escapar tras el arrastre (antes casi siempre pegaba dos veces)
	var slap := BossZone.circle(global_position, 120.0, 0.7, 0.2, damage, WAX)
	_add_hazard(slap)
	slap.follow = self
	if not await _tele(0.7, Color(2.2, 0.6, 0.6), 3.0):
		return
	await _wait(0.2)


## Escupe cera sobre ti (y donde vas a estar): los charcos tardan en salir y luego se endurecen.
func atk_salpicadura() -> void:
	_walk = 0.45
	if not await _tele(0.45, Color(2.2, 1.6, 0.6)):
		return
	var n := mini(current_phase, 2) + (1 if current_phase == 3 else 0)
	for i in n:
		var p: Vector2 = _lead(250.0) if i % 2 == 0 else target.global_position + Vector2(RNG.randf_range(-90, 90), RNG.randf_range(-90, 90))
		_puddle(p, 0.8, 4.5)
		Sound.play("enemy_shoot")
		if not await _wait(0.3):
			return
	await _wait(0.2)


## Castigo al que se pega: pisoton con aviso y onda de gotas.
func atk_pisoton() -> void:
	_walk = 0.0
	var w := _ts(0.45)
	_float_text(tr("CERA_STOMP"), Color("ff8a3a"))
	_add_hazard(BossZone.circle(global_position, 155.0, w + 0.05, 0.18, damage, WAX))
	if not await _tele(0.45, Color(2.2, 0.6, 0.6), 3.0):
		return
	await _wait(0.1)
	HitFx.shake(0.35)
	Sound.play("crack")
	var n := 8 + 2 * current_phase
	for i in n:
		_fire_from(_muzzle(), TAU * i / n, 230.0, 0.45, WAX, 3.0)
	await _wait(0.2)


## Embestida: solo aqui (y en el pisoton) pega con el cuerpo. Deja un charco donde choca.
func atk_embiste() -> void:
	_walk = 0.0
	var lane := BossZone.rect(global_position, Vector2(600, 90), 0.0, _ts(0.85) + 0.05, 0.05, 0.0, Color(1.0, 0.25, 0.2))
	_add_hazard(lane)
	_charge_dir = (target.global_position - global_position).normalized()
	var track := func(left: float):
		if left > 0.35:
			_charge_dir = (_lead(450.0, 0.3) - global_position).normalized()
		if is_instance_valid(lane):
			var ln := _ray_len(global_position + Vector2(0, -50), _charge_dir, 700.0)
			lane.size.x = ln
			lane.global_position = global_position + _charge_dir * ln * 0.5
			lane.rotation = _charge_dir.angle()
	if not await _tele(0.85, Color(2.2, 0.6, 0.6), 3.0, track):
		return
	Sound.play("dash")
	_hit_done = false
	var t := 0.0
	var wall := false
	while t < 0.7:
		velocity = _charge_dir * (420.0 + current_phase * 30.0)
		if not await _frame():
			return
		_strike()
		t += 1.0 / 60.0
		if get_slide_collision_count() > 0:
			wall = true
			break
	velocity = Vector2.ZERO
	HitFx.shake(0.3 if wall else 0.1)
	if wall:
		_puddle(global_position - _charge_dir * 30.0, 0.5, 4.0)
	await _wait(0.2)


## Dos tiras en cruz que giran por la sala. Despues queda AGOTADA.
func atk_cruz() -> void:
	_walk = 0.0
	var ang := RNG.randf_range(0.0, PI)
	var sp := 0.55 * (1.0 if RNG.randf() < 0.5 else -1.0)
	var reach := arena().size.length() * 0.95
	if not await _walk_to(_inner().get_center(), 1.2, 380.0):
		return
	var c := _muzzle()
	for k in 2:
		var z := BossZone.rect(c, Vector2(reach, 46), ang + k * PI * 0.5, _ts(0.95) + 0.05, 1.9, damage, WAX)
		z.spin = sp
		z.one_hit = true  # cada tira pega una vez (antes repetia mientras siguieras encima)
		z.fade = 0.4
		_add_hazard(z)
	if not await _tele(0.95, Color(2.2, 1.6, 0.6), 2.5):
		return
	if not await _wait(2.0):
		return
	_tire(1.5)


## FIRMA DE LA FASE 3: DEPILACION TOTAL. Dos olas de cera hirviendo cruzan la sala de lado a lado
## con un hueco (lejos de ti: hay que dashear). Quedan charcos que se endurecen. Agotada despues.
func atk_oleada() -> void:
	_walk = 0.0
	_float_text(tr("CERA_FIRMA"), Color("ff5a3a"), Vector2(0, -190))
	if not await _tele(0.9, Color(2.2, 0.6, 0.6), 3.0):
		return
	var a := _inner()
	var horiz := a.size.x >= a.size.y
	var spd := 250.0 + 20.0 * (current_phase - 2)
	for k in (1 if current_phase < 3 else 2):
		var tp: Vector2 = target.global_position
		var from_start := (tp.x > a.get_center().x) if horiz else (tp.y > a.get_center().y)
		if k == 1:
			from_start = not from_start
		var cross_lo := a.position.y if horiz else a.position.x
		var cross_hi := a.end.y if horiz else a.end.x
		var gap_half := 95.0
		var pc := (tp.y if horiz else tp.x)
		var gap_c := clampf(pc + (1.0 if RNG.randf() < 0.5 else -1.0) * RNG.randf_range(130.0, 210.0), cross_lo + gap_half + 20.0, cross_hi - gap_half - 20.0)
		bot_safe = Vector2(tp.x, gap_c) if horiz else Vector2(gap_c, tp.y)
		var travel := (a.size.x if horiz else a.size.y) - 70.0
		var secs := travel / spd
		var thick := 70.0
		for part in 2:
			var lo := cross_lo if part == 0 else gap_c + gap_half
			var hi := gap_c - gap_half if part == 0 else cross_hi
			if hi - lo < 10.0:
				continue
			var mid := (lo + hi) * 0.5
			var sign_ := 1.0 if from_start else -1.0
			var z: BossZone
			if horiz:
				var x0 := (a.position.x + thick * 0.5) if from_start else (a.end.x - thick * 0.5)
				z = BossZone.rect(Vector2(x0, mid), Vector2(thick, hi - lo), 0.0, 0.95, secs, damage * 0.8, WAX)
				z.vel = Vector2(spd * sign_, 0.0)
			else:
				var y0 := (a.position.y + thick * 0.5) if from_start else (a.end.y - thick * 0.5)
				z = BossZone.rect(Vector2(mid, y0), Vector2(hi - lo, thick), 0.0, 0.95, secs, damage * 0.8, WAX)
				z.vel = Vector2(0.0, spd * sign_)
			z.fade = 0.3
			_add_hazard(z)
		if not await _wait(0.95 + secs + 0.2):
			bot_safe = null
			return
		bot_safe = null
		for i in 2:
			_puddle(_cl(Vector2(RNG.randf_range(a.position.x, a.end.x), RNG.randf_range(a.position.y, a.end.y)), 60.0), 0.7, 3.5)
	_tire(1.1)


# ---------------------------------------------------------------- la cura
func _on_cure_cut() -> void:
	# premio: un buen mordisco de vida (sin saltarse de fase) ademas del aturdimiento largo
	var floor_hp := max_health * (PHASE2_AT if current_phase == 1 else (PHASE3_AT if current_phase == 2 else 0.02)) + 1.0
	var chunk := minf(max_health * 0.06, maxf(0.0, current_health - floor_hp))
	if chunk > 0.0:
		current_health -= chunk
		_emit_health()
		_ge.show_damage_number.emit(global_position + Vector2(0, -150), chunk, true)
	_float_text(tr("CERA_CUT_BONUS"), Color("ffe08a"), Vector2(0, -190))


func _on_cure_done() -> void:
	_rage_t = 7.0
	_wave_t = minf(_wave_t, 2.0)
	_float_text(tr("CERA_RAGE"), Color("ff5a3a"), Vector2(0, -190))


## Se defiende mientras canaliza: barre la ruta hacia la tira, planta charcos que la protegen
## y en fase 2-3 suelta gotitas. Siempre con aviso.
func _defend(dt: float) -> void:
	_def_t -= dt
	var a := _inner()
	# se mueve despacio por el centro (no es una estatua)
	var c := a.get_center() + Vector2(sin(_chan_t * 0.7) * a.size.x * 0.22, cos(_chan_t * 0.5) * a.size.y * 0.18)
	velocity = (c - global_position).limit_length(60.0) * 1.0
	if _def_t > 0.0:
		return
	_def_t = [3.0, 2.6, 2.2][current_phase - 1]
	var pick := RNG.randi_range(0, 2 if current_phase >= 2 else 1)
	match pick:
		0:
			# barrido: abanico corto hacia la ruta entre tu y la tira
			var mid: Vector2 = target.global_position.lerp(_strip_pos, 0.5)
			var base := (mid - _muzzle()).angle()
			var spd: float = [260.0, 290.0, 310.0][current_phase - 1]
			for i in 3:
				_fire(base + (i - 1) * 0.2, spd, 0.5)
		1:
			# charco protector entre tu y la tira (se endurece: pared)
			var p: Vector2 = _strip_pos.lerp(target.global_position, RNG.randf_range(0.35, 0.6)) + Vector2(RNG.randf_range(-40, 40), RNG.randf_range(-40, 40))
			_puddle(p, 0.8, 3.5)
		_:
			if get_tree().get_nodes_in_group("gota_cera").size() < 3:
				_summon(1)


## TIRA: tiras de depilar corren por la sala. Hay que tocarlas (cuerpo o dash). La tira acelera,
## esquiva cuando te acercas, rebota en la cera dura. Fase 2: un SENUELO (tocarlo quema y le
## da tiempo a la cura). Fase 3: dos tiras reales y un senuelo.
func ch_tira() -> void:
	var a := _inner().grow(-30.0)
	var reals := 2 if current_phase >= 3 else 1
	var decoys := 0 if current_phase == 1 else 1
	var limit: float = [6.0, 5.5, 5.0][current_phase - 1]
	if is_instance_valid(_chan_fx):
		_chan_fx.label2 = tr("CERA_CH_TIRA_D%d" % current_phase)
	_strips = []
	for i in reals + decoys:
		var decoy := i >= reals
		var v0 := Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * 430.0
		var s := _make_prop(_muzzle() + Vector2(0, 60) + Vector2.RIGHT.rotated(i * 2.1) * 40.0, Callable(), Callable(), {"v": v0, "turn": 0.9, "decoy": decoy, "done": false, "hits": 0, "boost": 0.0, "touch_txt": tr("CERA_TOUCH"), "jink": 0.0, "cd": 0.0})
		s.drawer = func(n):
			var v: Vector2 = n.data.v
			var pulse := 0.5 + 0.5 * sin(n.t * 22.0)
			var dec: bool = n.data.decoy
			var done: bool = n.data.done
			var ring := Color(1.0, 0.25, 0.3) if dec else Color(0.3, 1.0, 0.5)
			var body := Color(0.78, 0.6, 0.72) if dec else Color(1.0, 0.96, 0.75)
			var al := 0.35 if done else 1.0
			n.draw_circle(Vector2(0, -12), 46.0, Color(ring, (0.16 + 0.16 * pulse) * al))
			n.draw_arc(Vector2(0, -12), 46.0, 0.0, TAU, 32, Color(1, 1, 1, 0.7 * al), 3.0)
			n.draw_set_transform(Vector2(0, -12), v.angle())
			n.draw_rect(Rect2(-44, -11, 88, 22), Color(body, al))
			n.draw_rect(Rect2(-44, -11, 88, 22), Color(0.35, 0.22, 0.05, al), false, 3.0)
			for k in 4:
				n.draw_line(Vector2(-30 + k * 20, -11), Vector2(-30 + k * 20, 11), Color(0.35, 0.22, 0.05, 0.6 * al), 2.0)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if dec:
				# aspa roja: senuelo
				n.draw_line(Vector2(-14, -26), Vector2(14, 2), Color(1.0, 0.2, 0.25), 5.0)
				n.draw_line(Vector2(14, -26), Vector2(-14, 2), Color(1.0, 0.2, 0.25), 5.0)
			else:
				if not done:
					# idioma de TOCAR: aro verde que pulsa + flecha y rotulo; nunca dorado
					n.draw_arc(Vector2(0, -12), 54.0 + 6.0 * pulse, 0.0, TAU, 32, Color(0.4, 1.0, 0.55, 0.9), 4.0)
					var by := -78.0 - 6.0 * pulse
					n.draw_colored_polygon(PackedVector2Array([Vector2(-12, by), Vector2(12, by), Vector2(0, by + 18)]), Color(0.4, 1.0, 0.55))
					var f := ThemeDB.fallback_font
					var txt: String = n.data.touch_txt
					var sz := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
					n.draw_string_outline(f, Vector2(-sz.x * 0.5, by - 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0))
					n.draw_string(f, Vector2(-sz.x * 0.5, by - 6.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.5, 1.0, 0.6))
			if done and not dec:
				n.draw_line(Vector2(-12, -12), Vector2(-3, -2), Color(0.3, 1.0, 0.4), 5.0)
				n.draw_line(Vector2(-3, -2), Vector2(14, -26), Color(0.3, 1.0, 0.4), 5.0)
		_strips.append(s)
	await _ch_loop(limit, func(dt):
		_move_strips(dt, a, reals))
	for s in _strips:
		if is_instance_valid(s):
			s.queue_free()
	_strips = []


func _move_strips(dt: float, a: Rect2, reals: int) -> void:
	var tp: Vector2 = target.global_position
	var sp := minf(430.0 + 28.0 * _chan_t, 640.0)
	var goal = null
	var goal_d := 1.0e9
	var dash_vec := Vector2.ZERO
	var solids := _solids()
	var done_n := 0
	for s in _strips:
		if not is_instance_valid(s):
			continue
		var dd: Dictionary = s.data
		var v: Vector2 = dd.v
		var p: Vector2 = s.global_position
		dd.cd = maxf(0.0, float(dd.cd) - dt)
		dd.jink = maxf(0.0, float(dd.jink) - dt)
		var away: Vector2 = p - tp
		if away.length() < 230.0:
			v += away.normalized() * 650.0 * dt
			# esquiva: cerca de ti cambia de rumbo de golpe (una vez cada rato)
			if away.length() < 170.0 and dd.jink <= 0.0:
				dd.jink = 0.6
				var side := 1.0 if v.cross(away) > 0.0 else -1.0
				v = v.rotated(side * RNG.randf_range(1.1, 1.8))
		dd.turn -= dt
		if dd.turn <= 0.0:
			dd.turn = RNG.randf_range(0.6, 1.2)
			v = v.rotated(RNG.randf_range(-1.4, 1.4))
		dd.boost = maxf(0.0, float(dd.boost) - dt)
		v = v.normalized() * sp * (1.3 if dd.boost > 0.0 else 1.0)
		p += v * dt
		# rebota en la cera dura
		for w in solids:
			if w.kind == WaxBlock.Kind.PUDDLE:
				var off: Vector2 = p - w.global_position
				if off.length() < w.radius + 30.0:
					var nrm := off.normalized() if off.length() > 0.1 else Vector2.RIGHT
					v = v.bounce(nrm)
					p = w.global_position + nrm * (w.radius + 31.0)
		if p.x < a.position.x:
			p.x = a.position.x
			v.x = absf(v.x)
		elif p.x > a.end.x:
			p.x = a.end.x
			v.x = -absf(v.x)
		if p.y < a.position.y:
			p.y = a.position.y
			v.y = absf(v.y)
		elif p.y > a.end.y:
			p.y = a.end.y
			v.y = -absf(v.y)
		dd.v = v
		s.global_position = p
		var dist := tp.distance_to(p)
		if dist < 44.0 and dd.cd <= 0.0:
			if dd.decoy:
				dd.cd = 1.5
				_ch_extra += 2.5
				_float_text(tr("CERA_DECOY"), Color("ff5a3a"), Vector2(0, -190))
				if target.has_method("receive_hit"):
					target.receive_hit(damage * 0.5)
				Sound.play("crack")
			elif not dd.done:
				# hay que tocarla DOS veces: tras la 1a se recalienta, huye al otro lado y acelera
				dd.hits += 1
				dd.cd = 0.9
				Sound.play("enemy_hit")
				if dd.hits >= 2:
					dd.done = true
				else:
					var far := _cl(a.get_center() * 2.0 - tp, 40.0)
					s.global_position = far
					dd.v = dd.v.rotated(RNG.randf_range(-1.0, 1.0))
					dd.boost = 1.6
				_chan_prog = 0.0
				for s2 in _strips:
					if is_instance_valid(s2) and not s2.data.decoy:
						_chan_prog += float(s2.data.hits) / (2.0 * reals)
				if _chan_prog >= 0.999:
					_chan_ok = true
		if not dd.decoy:
			if dd.done:
				done_n += 1
			elif dist < goal_d:
				goal_d = dist
				goal = p + v * 0.22
				if dist < 190.0:
					dash_vec = (p - tp).normalized()
				_strip_pos = p
	if goal != null:
		bot_goal_pos = goal
	bot_dash_vec = dash_vec
