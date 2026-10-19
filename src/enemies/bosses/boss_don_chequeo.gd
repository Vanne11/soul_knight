extends BossAltBase

## DON CHEQUEO (alternativo de La Prostata, etapa R; id "don_chequeo") - usa el MOTOR DINAMICO (dynamic = true).
## Una nuez burocrata (hombre) con lentes, corbata gris, credencial y planilla: la caricatura del
## "primero hay que hacerse el chequeo". Tema educativo: el chequeo de prostata a tiempo (codice).
## IDENTIDAD "PASE AL BOX" (ataque firma): te encierra en un box de examen. Aparece un rectangulo de
## cortinas alrededor tuyo con UN hueco (aviso 0,9 s, "¡Pase al box!"): las cortinas pegan al cruzarlas y
## la cortina del hueco se va cerrando (se llena como un aviso). Hay que salir por el hueco antes de que se
## cierre; si sigues dentro cuando cierra, el box entero te cobra. Mientras tanto firma "ordenes de
## examen" (papeles lentos) hacia ti. Fase 2: huecos mas chicos, mas ordenes; fase 3: un SEGUNDO box vacio
## te corta una ruta y cierra antes.
## - PRESION: camina pegado a ti y suelta una orden suelta (aviso 0,55 s) mientras tanto.
## - ORDENES (papeleo): abanicos de papeles con linea de aviso hacia ti.
## - SELLOS: te sella donde estas (circulos con aviso, uno tras otro): no te quedes quieto.
## - PACIENTES: llama timbres de turno (esbirros): DING con cuatro balitas; reventarlos a veces suelta corazon.
## - EMBESTIDA (fase 2+): "¡El que sigue!", carril avisado; agotado tras chocar.
## Cura (2 cargas): PLANILLAS (romper 5 papeles que vagan) y SELLOS (tocar 4 sellos antes de que acabe el tiempo).

const PAPER := Color(0.95, 0.9, 0.68)
const CURTAIN := Color(0.28, 0.74, 0.66)
const HP_MULT := 0.7
const BELL := preload("res://src/enemies/enemy_timbre_chequeo.tscn")
const BASE_SPEED := [120.0, 140.0, 160.0]
const BASE_CAPS := [0.85, 0.7, 0.6]
const WALL_T := 26.0
const BOX_WARN := 0.9
## Ataque -> animacion de cuadros (BossAnimator busca attack_<x> / release_<x>).
const ANIM := {
	&"atk_box": "cubiculos", &"atk_ordenes": "papeleo", &"atk_sellos": "ticket", &"atk_pacientes": "timbres",
}

var _call_t := 3.0
var _call_warn := 0.0


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = PAPER
	move_speed = BASE_SPEED[0]
	keep_min = 80.0
	keep_max = 150.0
	rest_min = 0.45
	rest_max = 0.8
	bullet_speed = 300.0
	tele_caps = BASE_CAPS.duplicate()
	max_health *= HP_MULT
	current_health = max_health
	_emit_health()
	_channels_total = 2
	_channels_left = 2
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	BossAnimator.attach(self)  # arte definitivo 176x184 (3 fases): cuadros por ataque + animacion por codigo


## El golpe ocurre al terminar el aviso: el animador pasa de attack_<x> a release_<x> justo ahi.
func _tele(secs: float, col := Color(2.0, 2.0, 0.9), shake := 2.0, on_frame := Callable()) -> bool:
	var ok: bool = await super(secs, col, shake, on_frame)
	if ok:
		attack_released.emit(_last_attack)
	return ok


## Frases del narrador: bosschequeo_<evento> (assets/data/narrator/jefes_alt.json).
func _say(suffix: String) -> void:
	var key := "bosschequeo_" + suffix
	if Narrator.has_lines(key):
		Narrator.say(key)


func _pick_attack() -> StringName:
	var a := super()
	set_meta("atk", str(ANIM.get(a, String(a).trim_prefix("atk_"))))
	return a


func _attack_pool() -> Array:
	var pool: Array
	match current_phase:
		1:
			pool = [&"atk_box", &"atk_ordenes", &"atk_sellos", &"atk_pacientes"]
		2:
			pool = [&"atk_box", &"atk_ordenes", &"atk_sellos", &"atk_pacientes", &"atk_charge", &"atk_box"]
		_:
			pool = [&"atk_box", &"atk_box", &"atk_ordenes", &"atk_sellos", &"atk_sellos", &"atk_pacientes", &"atk_charge"]
	if _bells() >= current_phase + 1:
		pool = pool.filter(func(x): return x != &"atk_pacientes")
	return pool


func _bells() -> int:
	return get_tree().get_nodes_in_group("timbre_ventanilla").size()


func _challenges() -> Array:
	return [&"ch_planillas", &"ch_sellos"]


func _channel_color() -> Color:
	return PAPER


func _on_phase(n: int) -> void:
	_float_text(tr("CHEQ_PHASE_%d" % n), PAPER)


func _reset_fx() -> void:
	super()
	animated_sprite.visible = true


## Todo peligro de Don Chequeo se ve como peligro (borde rojo oscuro, franjas).
func _add_hazard(z: BossZone) -> BossZone:
	if z.style == BossZone.Style.NORMAL:
		z.style = BossZone.Style.TOXIC
	return super(z)


func _tick(delta: float) -> void:
	if state in [State.INTRO, State.TRANSITION, State.DEAD] or target == null:
		return
	var ph := clampi(current_phase, 1, 3) - 1
	move_speed = BASE_SPEED[ph] * (1.35 if _furia else 1.0)
	_passive_call(delta)


## Orden suelta mientras camina: parpadea 0,55 s y sale una bala rapida hacia donde vas.
func _passive_call(delta: float) -> void:
	if state != State.IDLE or _channeling:
		if _call_warn > 0.0:
			_call_warn = 0.0
			animated_sprite.modulate = Color.WHITE
		return
	if _call_warn > 0.0:
		_call_warn -= delta
		animated_sprite.modulate = Color(2.2, 2.0, 1.2) if int(_call_warn * 16.0) % 2 == 0 else Color.WHITE
		if _call_warn <= 0.0:
			animated_sprite.modulate = Color.WHITE
			var lead: Vector2 = target.global_position + (target.velocity * 0.35 if "velocity" in target else Vector2.ZERO)
			_fire((lead - _muzzle()).angle(), bullet_speed * 1.1, 0.6, PAPER)
			Sound.play("enemy_shoot")
			_call_t = [3.6, 3.0, 2.4][clampi(current_phase, 1, 3) - 1]
		return
	_call_t -= delta
	if _call_t <= 0.0:
		_call_warn = 0.55


# ---------------------------------------------------------------- PASE AL BOX
## Arma las cortinas de un box centrado en `c` (tamano `sz`): 4 lados, el `gap_side` (0 arriba, 1 derecha,
## 2 abajo, 3 izquierda) con un hueco de `gap_w`. Las cortinas avisan `BOX_WARN` s y pegan `hold` s; la
## cortina del hueco se llena durante `BOX_WARN + open_t` s (lo que tienes para salir) y el interior cobra
## 0,2 s despues de cerrarse. Devuelve la posicion global del hueco.
func _build_box(c: Vector2, sz: Vector2, gap_side: int, gap_w: float, open_t: float, dmg_mult := 1.0) -> Vector2:
	var hx := sz.x * 0.5
	var hy := sz.y * 0.5
	var hold := open_t + 0.9
	var gap_pos := c
	for side in 4:
		var horiz := side == 0 or side == 2
		var half := hx if horiz else hy          # mitad del lado
		var off := (-hy if side == 0 else hy) if horiz else (hx if side == 1 else -hx)  # distancia al centro
		var segs: Array = []                      # tramos [desde, hasta] a lo largo del lado
		if side == gap_side:
			segs = [[-half - WALL_T * 0.5, -gap_w * 0.5], [gap_w * 0.5, half + WALL_T * 0.5]]
		else:
			segs = [[-half - WALL_T * 0.5, half + WALL_T * 0.5]]
		for s in segs:
			var mid: float = (float(s[0]) + float(s[1])) * 0.5
			var len_: float = float(s[1]) - float(s[0])
			var p := c + (Vector2(mid, off) if horiz else Vector2(off, mid))
			var wsz := Vector2(len_, WALL_T) if horiz else Vector2(WALL_T, len_)
			var z := BossZone.rect(p, wsz, 0.0, BOX_WARN, hold, damage * 0.8 * dmg_mult, CURTAIN)
			z.fade = 0.3
			_add_hazard(z)
		if side == gap_side:
			gap_pos = c + (Vector2(0.0, off) if horiz else Vector2(off, 0.0))
			var gsz := Vector2(gap_w, WALL_T) if horiz else Vector2(WALL_T, gap_w)
			# la cortina del hueco se va llenando: cuando termina de llenarse, el hueco queda cerrado
			var g := BossZone.rect(gap_pos, gsz, 0.0, BOX_WARN + open_t, 0.9, damage * 0.8 * dmg_mult, CURTAIN)
			g.fade = 0.3
			_add_hazard(g)
	# interior: se va llenando durante todo el box y cobra un instante despues de que cierre el hueco
	var inner := BossZone.rect(c, sz - Vector2(WALL_T, WALL_T), 0.0, BOX_WARN + open_t + 0.2, 0.4, damage * 1.1 * dmg_mult, CURTAIN.darkened(0.15))
	inner.fade = 0.35
	_add_hazard(inner)
	return gap_pos


## Lado por donde sale el hueco: el que mira al centro de la sala (hay espacio para huir).
func _gap_toward_center(c: Vector2) -> int:
	var d := arena().get_center() - c
	if absf(d.x) > absf(d.y):
		return 1 if d.x > 0.0 else 3
	return 2 if d.y > 0.0 else 0


## "PASE AL BOX" (ataque firma). Ver el comentario de arriba.
func atk_box() -> void:
	var ph := clampi(current_phase, 1, 3)
	var sz: Vector2 = [Vector2(340, 260), Vector2(310, 240), Vector2(290, 230)][ph - 1]
	var gap_w: float = [150.0, 125.0, 110.0][ph - 1]
	var open_t: float = [1.6, 1.4, 1.2][ph - 1]
	var tp: Vector2 = target.global_position
	# dentro de la sala, pero siempre con el heroe a >= 60 px de cualquier cortina
	var a := arena().grow(-40.0)
	var c := Vector2(clampf(tp.x, a.position.x + sz.x * 0.5, maxf(a.end.x - sz.x * 0.5, a.position.x + sz.x * 0.5)),
		clampf(tp.y, a.position.y + sz.y * 0.5, maxf(a.end.y - sz.y * 0.5, a.position.y + sz.y * 0.5)))
	c.x = clampf(c.x, tp.x - (sz.x * 0.5 - 60.0), tp.x + (sz.x * 0.5 - 60.0))
	c.y = clampf(c.y, tp.y - (sz.y * 0.5 - 60.0), tp.y + (sz.y * 0.5 - 60.0))
	var side := _gap_toward_center(c)
	var gap_at := _build_box(c, sz, side, gap_w, open_t)
	var second := Rect2()
	if ph == 3:  # box vecino vacio: te corta una ruta; no se solapa con el tuyo
		var box1 := Rect2(c - sz * 0.5, sz).grow(70.0)
		for i in 20:
			var p := arena_point(150.0)
			var r2 := Rect2(p - Vector2(130, 100), Vector2(260, 200))
			if not box1.intersects(r2) and p.distance_to(global_position) > 160.0:
				second = r2
				_build_box(p, r2.size, _gap_toward_center(p), 120.0, open_t - 0.2, 0.9)
				break
	_float_text(tr("CHEQ_BOX"), CURTAIN.lightened(0.3), c - global_position + Vector2(0, -sz.y * 0.5 - 24.0))
	_float_text(tr("CHEQ_EXIT"), PAPER, gap_at - global_position)
	if not await _tele(BOX_WARN - 0.1, Color(1.6, 2.2, 2.0), 2.5):
		return
	Sound.play("crack")
	HitFx.shake(0.15)
	# firma "ordenes de examen" mientras el hueco se cierra
	var n := [2, 3, 5][ph - 1]
	var gap := open_t / float(n + 1)
	for i in n:
		if not await _wait(gap):
			return
		var ang := (target.global_position - _muzzle()).angle()
		_fire(ang, bullet_speed * 0.8, 0.5, PAPER)
		if ph >= 3:
			_fire(ang + 0.3, bullet_speed * 0.8, 0.5, PAPER)
			_fire(ang - 0.3, bullet_speed * 0.8, 0.5, PAPER)
		Sound.play("enemy_shoot")
	if not await _wait(0.2 + 0.4 + 0.6):
		return
	_tire(1.0)


# ---------------------------------------------------------------- otros ataques
## ORDENES DE EXAMEN: abanicos de papeles con la linea de aviso hacia ti.
func atk_ordenes() -> void:
	var line := BossZone.rect(global_position, Vector2(320, 8), 0.0, 0.75, 0.05, 0.0, PAPER)
	_add_hazard(line)
	var track := func(_left: float):
		if is_instance_valid(line):
			var d: Vector2 = (target.global_position - _muzzle()).normalized()
			line.global_position = _muzzle() + d * 160.0
			line.rotation = d.angle()
	if not await _tele(0.75, Color(2.2, 2.0, 1.2), 2.0, track):
		return
	var volleys := 1 + current_phase
	var shots := 3 + (current_phase - 1) * 2
	for v in volleys:
		var base := (target.global_position - _muzzle()).angle()
		Sound.play("enemy_shoot")
		for k in shots:
			_fire(base + (k - (shots - 1) / 2.0) * 0.2, bullet_speed * 0.9, 0.6, PAPER)
		if v < volleys - 1 and not await _wait(0.6 - current_phase * 0.06):
			return
	await _wait(0.3)


## SELLOS: te sella donde estas, uno tras otro (cada circulo avisa 0,8 s). No te quedes quieto.
func atk_sellos() -> void:
	var n := 3 + current_phase
	if not await _tele(0.7, Color(2.2, 2.0, 1.2), 2.0):
		return
	_float_text(tr("CHEQ_STAMP"), PAPER)
	for i in n:
		var p := clamp_to_arena(target.global_position, 50.0)
		var z := BossZone.circle(p, 62.0, 0.8, 0.3, damage * 0.8, CURTAIN)
		_add_hazard(z)
		if not await _wait(0.45):
			return
	await _wait(0.9)


## PACIENTES: llama timbres de turno (1 / 2 / 3 segun la fase).
func atk_pacientes() -> void:
	if not await _tele(0.8, Color(2.2, 2.0, 1.2), 2.0):
		return
	var pts: Array = []
	for i in current_phase:
		pts.append(clamp_to_arena(global_position + Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * 90.0, 50.0))
	_float_text(tr("CHEQ_CALL"), PAPER)
	_spawn_minions(pts, 12.0 + _floor * 2.0, 6.0 + _floor * 1.5, tr("TIMBRE_NAME"), BELL)
	Sound.play("crack")
	HitFx.shake(0.15)
	await _wait(0.4)


# ---------------------------------------------------------------- desafios de la cura
## PLANILLAS: cinco planillas vagan por la sala. Rompelas a tiros.
func ch_planillas() -> void:
	await _ch_break(5, "paper", {"hp": 12.0, "speed": 60.0, "limit": 13.0})


## SELLOS: cuatro sellos repartidos; tocalos todos antes de que se acabe el tiempo.
func ch_sellos() -> void:
	await _ch_touch(_spread_points(4, 160.0), "star", {"limit": 12.0})
