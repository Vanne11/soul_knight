extends BossAltBase

## EL ALGORITMO MODERADOR (alternativo del Palacio de la Censura, reino 5). Un ojo sin
## parpadeo que lo revisa todo y aprende poco: confunde una lactancia con un delito.
## - ESCANEO: una linea de lectura cruza la sala con un hueco por el que pasar;
## - REPORTADO: marca tu posicion (el reticulo te sigue y se bloquea en el ultimo momento);
## - CONTENIDO SENSIBLE: bloques pixelados que se cierran en zonas de la sala;
## - BLOQUEO: barras negras de censura, escalonadas, con pasillos libres;
## - SPAM (abanico) y NOTIFICACIONES (anillo con hueco, fase 3). Agotado tras bloqueo y escaneo.
## Cura (2 cargas): MODO OSCURO, FALSO POSITIVO (clones), CAPTCHA, COOKIES, REVISION HUMANA.
## MOTOR DINAMICO (J1) + identidad J2 "APRENDE TU ESQUIVE": usa el cuaderno (boss_notebook.gd) a fondo.
## - AVISA lo que aprendio ("PATRON DETECTADO: SIEMPRE ESQUIVAS A LA IZQUIERDA") para que cambies;
## - PREDICCION: te espera donde sueles caer (dash), por donde sueles rodearlo y en tu zona favorita;
## - al avisar cualquier ataque y con un dash habitual, pone una marca justo en ese lado;
## - recuerda ENTRE partidas (user://algoritmo_memoria.json, como la memoria del narrador): te saluda
##   con lo que anoto la ultima vez y arranca ya apuntando ahi (con menos fuerza).
## - ESBIRROS: bots de reporte (enemy_bot_reporte.gd) que marcan tu posicion; con bots vivos sus
##   REPORTADOS marcan un sitio extra. Pocos en fase 1, mas en fase 3.

const GLASS := Color(0.7, 0.85, 1.0)
const ALERT := Color(1.0, 0.3, 0.3)
const BOT := preload("res://src/enemies/enemy_bot_reporte.tscn")
const MEMORY_PATH := "user://algoritmo_memoria.json"
const BASE_SPEED := [120.0, 140.0, 160.0]
const HP_MULT := 0.7
const BASE_CAPS := [0.85, 0.7, 0.6]
const FOOT := Vector2(0, 70)  ## textos bajo los pies: el HUD tapa la cabeza

var notebook := BossNotebook.new()
var _mem := {}               ## lo que recuerda de la partida anterior
var _mem_out := {}           ## lo que anota en esta
var _pat_text_t := {}
var _trap_cd := 2.0
var _mark_t := 3.0


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = GLASS
	move_speed = BASE_SPEED[0]
	keep_min = 90.0
	keep_max = 190.0
	rest_min = 0.45
	rest_max = 0.85
	bullet_speed = 320.0
	tele_caps = BASE_CAPS.duplicate()
	max_health *= HP_MULT  # el motor dinamico pega mas: menos vida, como los demas jefes dinamicos
	current_health = max_health
	_emit_health()
	_channels_total = 2
	_channels_left = 2
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	notebook.pattern_detected.connect(_on_pattern)
	telegraph_started.connect(_on_telegraph)
	_load_memory()
	BossAnimator.attach(self, true)  # arte de siempre, animacion por codigo
	_greet.call_deferred()


func _attack_pool() -> Array:
	var pool: Array
	match current_phase:
		1:
			pool = [&"atk_fan", &"atk_escaneo", &"atk_reportado", &"atk_prediccion", &"atk_bots"]
		2:
			pool = [&"atk_fan", &"atk_escaneo", &"atk_reportado", &"atk_pixelado", &"atk_bloqueo", &"atk_prediccion", &"atk_prediccion", &"atk_bots"]
		_:
			pool = [&"atk_escaneo", &"atk_reportado", &"atk_pixelado", &"atk_bloqueo", &"atk_notificaciones", &"atk_fan", &"atk_prediccion", &"atk_prediccion", &"atk_bots", &"atk_bots"]
	if _bots() >= current_phase + 1:
		pool = pool.filter(func(x): return x != &"atk_bots")
	if _habit().is_empty():
		pool = pool.filter(func(x): return x != &"atk_prediccion")  # nada aprendido aun: no hay que predecir
	return pool


func _bots() -> int:
	return get_tree().get_nodes_in_group("bot_reporte").size()


## Todo peligro del Algoritmo se ve como peligro (los estilos propios, PIXEL/BAR, se respetan).
func _add_hazard(z: BossZone) -> BossZone:
	if z.style == BossZone.Style.NORMAL:
		z.style = BossZone.Style.TOXIC
	return super(z)


# ---------------------------------------------------------------- cuaderno y memoria
func _tick(delta: float) -> void:
	if state in [State.INTRO, State.DEAD] or target == null:
		return
	notebook.update(delta, target, self, arena())
	_trap_cd = maxf(0.0, _trap_cd - delta)
	if state == State.TRANSITION:
		return
	var ph := clampi(current_phase, 1, 3) - 1
	move_speed = BASE_SPEED[ph] * (1.35 if _furia else 1.0)
	if state != State.IDLE or _channeling:
		return
	_mark_t -= delta
	if _mark_t <= 0.0:  # reporte suelto mientras camina: circulo avisado 0,65 s donde vas a estar
		_mark_t = [3.6, 3.0, 2.4][ph]
		var lead: Vector2 = target.global_position + (target.velocity * 0.5 if "velocity" in target else Vector2.ZERO)
		var z := BossZone.circle(clamp_to_arena(lead, 40.0), 46.0, 0.65, 0.2, damage * 0.7, ALERT)
		z.went_active.connect(func(): Sound.play("crack"))
		_add_hazard(z)


## Habito vigente: el del cuaderno o, si aun no hay, lo que recuerda de la partida anterior.
## {dir, kind: &"dash"/&"orbit"/&"mem"}; {} si no sabe nada.
func _habit() -> Dictionary:
	var dp := notebook.dash_pattern()
	if not dp.is_empty():
		return {"dir": dp.dir, "kind": &"dash"}
	var op := notebook.orbit_pattern()
	if not op.is_empty():
		return {"dir": op.dir, "kind": &"orbit"}
	if _mem.has("dash"):
		return {"dir": StringName(_mem.dash), "kind": &"mem"}
	return {}


func _on_pattern(kind: StringName, detail: Variant) -> void:
	_mem_out[String(kind)] = String(detail.dir)
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_pat_text_t.get(kind, -99.0)) < 14.0:
		return
	_pat_text_t[kind] = now
	var key := "ALG_PAT_DASH" if kind == &"dash" else "ALG_PAT_ORBIT"
	_float_text(tr(key) % tr("ALG_DIR_" + String(detail.dir).to_upper()), Color("ff5a3a"), FOOT)
	get_tree().create_timer(1.4).timeout.connect(func():
		if state != State.DEAD:
			_float_text(tr("%s_Q%d" % [key, RNG.randi_range(1, 2)]), GLASS, FOOT + Vector2(0, 28)))
	_save_memory()


func _load_memory() -> void:
	if not FileAccess.file_exists(MEMORY_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(MEMORY_PATH))
	if d is Dictionary:
		_mem = d


func _save_memory() -> void:
	var out := _mem.duplicate()
	if _mem_out.has("dash"):
		out["dash"] = _mem_out.dash
	if _mem_out.has("orbit"):
		out["orbit"] = _mem_out.orbit
	var zone := notebook.favorite_zone()
	if zone != "":
		out["zone"] = zone
	var f := FileAccess.open(MEMORY_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))


## Cuarta pared: al empezar te dice lo que anoto la ultima vez.
func _greet() -> void:
	await get_tree().create_timer(2.6).timeout
	if not is_instance_valid(self) or state == State.DEAD or _mem.is_empty():
		return
	if _mem.has("dash"):
		_float_text(tr("ALG_MEM_DASH") % tr("ALG_DIR_" + String(_mem.dash).to_upper()), Color("ff5a3a"), FOOT)
	elif _mem.has("zone"):
		_float_text(tr("ALG_MEM_ZONE"), Color("ff5a3a"), FOOT)
	elif _mem.has("orbit"):
		_float_text(tr("ALG_MEM_ORBIT") % tr("ALG_DIR_" + String(_mem.orbit).to_upper()), Color("ff5a3a"), FOOT)


func _on_death() -> void:
	_save_memory()


func _challenges() -> Array:
	return [&"ch_modo_oscuro", &"ch_falso_positivo", &"ch_captcha", &"ch_cookies", &"ch_revision"]


func _channel_color() -> Color:
	return GLASS


func _on_phase(_n: int) -> void:
	_mark_t = 2.0
	_save_memory()


## Al avisar un ataque: si ya te conoce, pone una marca justo donde sueles caer (con su aviso).
func _on_telegraph(_secs: float) -> void:
	if _trap_cd > 0.0 or state != State.ATTACK or _channeling:
		return
	var h := _habit()
	if h.is_empty() or h.kind == &"orbit":
		return
	if RNG.randf() > (0.4 if h.kind == &"mem" else 0.65):
		return
	_trap_cd = 3.0
	var at: Vector2 = clamp_to_arena(target.global_position + BossNotebook.dir_vector(h.dir) * 140.0, 50.0)
	var z := BossZone.circle(at, 56.0, 0.75, 0.25, damage * 0.8, ALERT)
	z.went_active.connect(func(): Sound.play("crack"))
	_add_hazard(z)


# ---------------------------------------------------------------- ataques
## Linea de lectura: cruza la sala de lado a lado con un hueco libre.
func atk_escaneo() -> void:
	var a := arena()
	var horiz := RNG.randf() < 0.5  # linea horizontal que sube/baja (o vertical que avanza)
	var up := RNG.randf() < 0.5
	var span := a.size.x if horiz else a.size.y
	var gap := 170.0
	var gap_c := RNG.randf_range(gap, maxf(span - gap, gap + 1.0))
	var warn := 1.2
	var sp := 210.0 + current_phase * 25.0
	var thick := 56.0
	var segs: Array = [[0.0, gap_c - gap * 0.5], [gap_c + gap * 0.5, span]]
	for s in segs:
		var seg_len: float = s[1] - s[0]
		if seg_len < 8.0:
			continue
		var mid: float = s[0] + seg_len * 0.5
		var z: BossZone
		if horiz:
			var y := a.end.y - thick * 0.5 - 4.0 if up else a.position.y + thick * 0.5 + 4.0
			z = BossZone.rect(Vector2(a.position.x + mid, y), Vector2(seg_len, thick), 0.0, warn, ((a.size.y if horiz else a.size.x) - thick) / sp + 0.2, damage * 0.9, GLASS)
			z.vel = Vector2(0.0, -sp if up else sp)
		else:
			var x := a.end.x - thick * 0.5 - 4.0 if up else a.position.x + thick * 0.5 + 4.0
			z = BossZone.rect(Vector2(x, a.position.y + mid), Vector2(thick, seg_len), 0.0, warn, ((a.size.y if horiz else a.size.x) - thick) / sp + 0.2, damage * 0.9, GLASS)
			z.vel = Vector2(-sp if up else sp, 0.0)
		z.fade = 0.2
		_add_hazard(z)
	if not await _tele(warn - 0.1, Color(1.4, 1.8, 2.4), 2.0):
		return
	Sound.play("suck")
	var travel := ((a.size.y if horiz else a.size.x) - thick) / sp + 0.3
	if not await _wait(travel):
		return
	_tire(1.0)


## Reportado: el reticulo te sigue y se bloquea justo antes de caer.
func atk_reportado() -> void:
	var secs := float(tele_caps[clampi(current_phase, 1, 3) - 1])
	for k in current_phase:
		var z := BossZone.circle(target.global_position, 78.0, secs, 0.3, damage * 0.9, ALERT)
		_add_hazard(z)
		# con bots vivos, cada reporte marca ademas un sitio extra (donde acabas de dashear o cerca)
		if _bots() > 0:
			var sp := notebook.dash_spot()
			var at: Vector2 = clamp_to_arena(sp if sp != Vector2.INF else target.global_position + Vector2(RNG.randf_range(-170, 170), RNG.randf_range(-170, 170)), 50.0)
			_add_hazard(BossZone.circle(at, 60.0, secs + 0.1, 0.3, damage * 0.8, ALERT))
		var track := func(left: float):
			if left > 0.3 and is_instance_valid(z):
				z.global_position = target.global_position
		if not await _tele(secs, Color(2.4, 1.0, 1.0), 2.0, track):
			return
		Sound.play("crack")
		if not await _wait(0.3):
			return
	_tire(0.8)


## PREDICCION: te espera donde suele caer tu esquive (o por donde sueles rodearlo, o donde mas te
## quedas) y AVISA que lo aprendio. Cada marca tiene su aviso: cambiar de habito la desarma.
func atk_prediccion() -> void:
	var h := _habit()
	if h.is_empty():
		return
	var secs := float(tele_caps[clampi(current_phase, 1, 3) - 1])
	var spots: Array[Vector2] = []
	var tp: Vector2 = target.global_position
	if h.kind == &"orbit":
		var tang := (tp - global_position).normalized().orthogonal()
		if h.dir == &"antihorario":
			tang = -tang
		spots = [tp + tang * 130.0, tp + tang * 250.0]
	else:
		var dv := BossNotebook.dir_vector(h.dir)
		spots = [tp + dv * 140.0, tp + dv * 260.0]
	var sp := notebook.dash_spot()
	if sp != Vector2.INF:
		spots.append(sp)
	var fz := notebook.favorite_zone()
	if fz != "" and current_phase >= 2:
		spots.append(_zone_center(fz))
	_float_text(tr("ALG_PREDICT"), Color("ff5a3a"), FOOT)
	for p in spots:
		_add_hazard(BossZone.circle(clamp_to_arena(p, 50.0), 62.0, secs + 0.35, 0.3, damage * 0.9, ALERT))
	if not await _tele(secs, Color(2.4, 1.0, 1.0), 2.0):
		return
	Sound.play("crack")
	if not await _wait(0.5):
		return
	_tire(0.9)


## Centro de una celda "x,y" de la sala 3x3 (el formato de BossNotebook.favorite_zone).
func _zone_center(zk: String) -> Vector2:
	var parts := zk.split(",")
	var a := arena()
	return a.position + Vector2((int(parts[0]) + 0.5) * a.size.x / 3.0, (int(parts[1]) + 0.5) * a.size.y / 3.0)


## BOTS: salen bots de reporte (1 / 2 / 3 segun la fase) que marcan tu posicion.
func atk_bots() -> void:
	if not await _tele(0.8, Color(1.4, 1.8, 2.4), 2.0):
		return
	var pts: Array = []
	for i in current_phase:
		pts.append(clamp_to_arena(global_position + Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * 90.0, 50.0))
	_float_text(tr("ALG_BOTS"), GLASS, FOOT)
	_spawn_minions(pts, 12.0 + _floor * 2.0, 6.0 + _floor * 1.5, tr("BOT_NAME"), BOT)
	Sound.play("crack")
	HitFx.shake(0.15)
	await _wait(0.4)


## Bloques de pixelado que se cierran en varias zonas (la primera, sobre ti).
func atk_pixelado() -> void:
	var n := 2 + current_phase
	for i in n:
		var p := target.global_position if i == 0 else arena_point(110.0)
		if i == 1 and notebook.favorite_zone() != "":  # el segundo bloque cae en tu zona favorita
			p = _zone_center(notebook.favorite_zone())
		var z := BossZone.rect(clamp_to_arena(p, 100.0), Vector2(200, 200), 0.0, 1.1 + i * 0.2, 0.5, damage * 0.9, Color.WHITE)
		z.style = BossZone.Style.PIXEL
		_add_hazard(z)
	if not await _tele(1.0, Color(1.4, 1.8, 2.4), 2.0):
		return
	if not await _wait(0.4 + n * 0.2 + 0.6):
		return
	_tire(0.7)


## Barras de censura escalonadas, con pasillos libres.
func atk_bloqueo() -> void:
	var a := arena()
	var horiz := RNG.randf() < 0.5
	var span := a.size.y if horiz else a.size.x
	var n := maxi(int(span / 115.0), 4)
	var w := span / n
	var lanes: Array = range(n)
	lanes.shuffle()
	var bars := mini(n - 2, 3)
	for i in bars:
		var l: int = lanes[i]
		var z: BossZone
		if horiz:
			z = BossZone.rect(Vector2(a.get_center().x, a.position.y + (l + 0.5) * w), Vector2(a.size.x, w - 8.0), 0.0, 1.1 + i * 0.45, 0.4, damage * 0.9, Color.WHITE)
		else:
			z = BossZone.rect(Vector2(a.position.x + (l + 0.5) * w, a.get_center().y), Vector2(w - 8.0, a.size.y), 0.0, 1.1 + i * 0.45, 0.4, damage * 0.9, Color.WHITE)
		z.style = BossZone.Style.BAR
		_add_hazard(z)
	if not await _tele(1.0, Color(1.4, 1.8, 2.4), 2.0):
		return
	if not await _wait(0.2 + bars * 0.45 + 0.8):
		return
	_tire(1.0)


## Anillos de notificaciones con hueco (fase 3).
func atk_notificaciones() -> void:
	var warn := BossZone.circle(global_position, 120.0, 0.7, 0.05, 0.0, GLASS)
	warn.follow = self
	_add_hazard(warn)
	if not await _tele(0.7, Color(1.4, 1.8, 2.4), 2.0):
		return
	for r in 3:
		var gap_at := RNG.randf_range(-PI, PI)
		_fire_ring(20, 200.0, 0.0, gap_at, 0.9, 0.55, GLASS)
		Sound.play("enemy_shoot")
		if r < 2 and not await _wait(0.6):
			return
	await _wait(0.4)


# ---------------------------------------------------------------- desafios de la cura
## MODO OSCURO: se apaga la pantalla. Encuentralo por su brillo y golpealo.
func ch_modo_oscuro() -> void:
	await _ch_blackout(130.0, Color(0.02, 0.02, 0.05), 5, 50.0, 12.0)


## FALSO POSITIVO: tres copias del algoritmo. Solo una es real.
func ch_falso_positivo() -> void:
	await _ch_clones(3)


## CAPTCHA: pisa solo los semaforos; los demas cuadros restan.
func ch_captcha() -> void:
	var pts := _spread_points(3, 150.0, 100.0)
	var decoys: Array = []
	for p in _spread_points(5, 110.0, 100.0):
		if not pts.any(func(q): return q.distance_to(p) < 100.0):
			decoys.append(p)
	await _ch_touch(pts, "light", {"decoys": decoys, "decoy_kind": "tile", "limit": 14.0})


## COOKIES: seis cookies de seguimiento. Rompelas todas.
func ch_cookies() -> void:
	await _ch_break(6, "cookie", {"hp": 12.0, "speed": 65.0, "limit": 13.0})


## REVISION HUMANA: el filtro tiene un hueco que gira. Dispara desde el lado del hueco.
func ch_revision() -> void:
	await _ch_weak({"hits": 5, "limit": 14.0})
