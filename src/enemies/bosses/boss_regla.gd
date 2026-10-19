extends EnemyBoss

## DOÑA REGLA (El Utero, nivel secreto de Vulvania) - usa el MOTOR DINAMICO (dynamic = true).
## Regla de medir de 2 metros; "la regla es la regla": llega puntual, cuando nadie la espera.
## IDENTIDAD (una sola mecanica propia): TE MIDE Y CASTIGA LA RUTINA + BARRIDOS DE 180 GRADOS.
## - MEDICION: toma la distancia a la que estas de ella. Si te quedas a la MISMA distancia (aunque la
##   rodees: la distancia es la misma), el anillo de medida aparece y se va llenando ("Mido 70 cm...
##   igual que hace rato"). Cuando se llena, la sancion: una regla cae sobre ti. Cambiar de distancia
##   (acercarte, alejarte) reinicia la cuenta. Los Centimetros vivos le ayudan: miden mas rapido.
## - BARRIDO: la regla entera gira 180 grados sobre ella (semicirculo marcado en el suelo). Sal del
##   semicirculo, rodeala por detras o cruzalo con dash. Fase 3: ida y vuelta.
## - GOLPES DE REGLA: lineas del ancho de la sala que caen una tras otra (la primera sobre ti);
## - TE MIDE (ataque): una regla que te sigue y se clava donde estabas; si fallas queda AGOTADA;
## - LLEGA PUNTUAL (fase 2+): desaparece, marca relojes en el suelo y reaparece en uno de ellos;
## - CALENDARIO (fase 2+): rejilla de "dias"; los marcados revientan, el resto es seguro;
## - REGLAZO: una embestida corta con aviso en el suelo.
## - ESBIRROS: Centimetros (reglas chiquitas que copian tu distancia y marcan una linea contigo).
##   Fase 1: pocos; fase 3: hasta 5. Matarlos suelta corazones.
## - Pasivo: regletazo suelto con aviso corto mientras camina. Avisos >= 0,55 s. Combos en fase 2-3.
## Tono: humor de reglas, medidas y puntualidad; nada de burlarse del ciclo (el Utero es educativo).
## Curacion interrumpible: tres reglas (la real tiene sombra), como los clones de Ovaria.
## Frases: bossutero_<intro|phase2|phase3|death|after> (narrator/lines.json).

const RED := Color(1.0, 0.3, 0.38)
const CAL_COLS := 6
const CAL_ROWS := 4
const CENTI := preload("res://src/enemies/enemy_centimetro.tscn")
const HP_MULT := 0.7
const BAND := 48.0                       ## tolerancia (px) para contar "misma distancia"
const SHOW_AT := 1.1                     ## s a la misma distancia hasta que aparece el anillo de medida
const SANCTION_AT := [2.9, 2.5, 2.1]     ## s hasta la sancion, por fase
const CENTI_CAP := [2, 3, 5]
const WAVE := [18.0, 13.0, 10.0]
const PX_PER_CM := 3.0

var _last_cm := 0
var _aim := Vector2.RIGHT
var _aim_len := 560.0
var _ref_d := 0.0                        ## distancia que esta midiendo
var _same_t := 0.0                       ## tiempo que llevas a esa misma distancia
var _sanction_cd := 0.0
var _ring: MeasureRing = null
var _wave_t := 8.0
var _def_t := 2.0
var _spit_t := 3.0
var _spit_warn := 0.0
var _rush_dir := Vector2.RIGHT


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = RED
	keep_min = 120.0
	keep_max = 210.0
	rest_min = 0.45
	rest_max = 0.8
	bullet_speed = 300.0
	tele_caps = [0.85, 0.7, 0.6]
	move_speed = 115.0
	max_health *= HP_MULT
	current_health = max_health
	_emit_health()
	_channels_total = 1
	_channels_left = 1
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	BossAnimator.attach(self, true)  # arte actual (40x60): animacion por codigo, sin cuadros nuevos


func _say(suffix: String) -> void:
	var key := "bossutero_%s" % suffix  # propias (lines.json): boss<piso>_* son las de la jefa de Vulvania
	if Narrator.has_lines(key):
		Narrator.say(key)


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_golpes", &"atk_mide", &"atk_fan", &"atk_barrido"]
		2:
			return [&"atk_golpes", &"atk_mide", &"atk_puntual", &"atk_fan", &"atk_calendario", &"atk_reglazo", &"atk_barrido"]
	return [&"atk_golpes", &"atk_calendario", &"atk_puntual", &"atk_barrido", &"atk_barrido", &"atk_mide", &"atk_reglazo"]


func _combo_next() -> StringName:
	var light: Array = [&"atk_fan", &"atk_golpes", &"atk_mide"]
	if current_phase >= 2:
		light.append(&"atk_reglazo")
	light = light.filter(func(x): return x != _last_attack)
	return light[RNG.randi_range(0, light.size() - 1)]


func _challenges() -> Array:
	return [&"ch_reglas"]


func _channel_color() -> Color:
	return RED


func _on_phase(n: int) -> void:
	move_speed = [115.0, 135.0, 155.0][n - 1]
	_same_t = 0.0
	_sanction_cd = 1.5
	_wave_t = 3.0
	if n >= 2:
		_float_text(tr("REGLA_PHASE_%d" % n), Color("ffe08a"))


func _on_death() -> void:
	if is_instance_valid(_ring):
		_ring.queue_free()
	for c in get_tree().get_nodes_in_group("centimetro"):
		if is_instance_valid(c) and c.has_method("take_damage"):
			c.take_damage(9999.0, self)


func _hit_source() -> String:
	for c in get_tree().get_nodes_in_group("centimetro"):
		if is_instance_valid(c) and c.global_position.distance_to(target.global_position) < 70.0:
			return "centimetro"
	return "sancion/pasivo"


func _ts(x: float) -> float:
	return minf(x, tele_caps[clampi(current_phase, 1, 3) - 1])


func _centi_count() -> int:
	return get_tree().get_nodes_in_group("centimetro").size()


# ---------------------------------------------------------------- pasivos: medicion, centimetros, regletazo
func _tick(delta: float) -> void:
	if state in [State.INTRO, State.DEAD, State.TRANSITION] or target == null:
		return
	_measure(delta)
	_wave_logic(delta)
	_spit_logic(delta)


## MEDICION: cuanto llevas a la misma distancia de ella. Se ve (anillo) y se avisa (texto) antes de castigar.
func _measure(delta: float) -> void:
	if _ring == null or not is_instance_valid(_ring):
		_ring = MeasureRing.new()
		_ring.boss = self
		_ring.show_behind_parent = true
		add_child(_ring)
		_ring.position = Vector2(0, -20)
	_sanction_cd = maxf(0.0, _sanction_cd - delta)
	if _channeling or state == State.TIRED:
		_same_t = 0.0
		_ring.shown = false
		return
	var d := target.global_position.distance_to(global_position + Vector2(0, -20))
	if absf(d - _ref_d) <= BAND:
		_same_t += delta * (1.0 + 0.35 * minf(_centi_count(), 3))  # los centimetros ayudan a medir
	else:
		_ref_d = d
		_same_t = 0.0
	var ph := clampi(current_phase, 1, 3) - 1
	var limit: float = SANCTION_AT[ph]
	var was_shown := _ring.shown
	_ring.shown = _same_t >= SHOW_AT
	_ring.ref_r = _ref_d
	_ring.progress = clampf((_same_t - SHOW_AT) / maxf(limit - SHOW_AT, 0.1), 0.0, 1.0)
	if _ring.shown and not was_shown:
		_float_text(tr("REGLA_MEASURE") % int(_ref_d / PX_PER_CM), RED, Vector2(0, -150))
		_float_text(tr("REGLA_MEASURE_TIP"), Color("ffe08a"), Vector2(0, -128))
		Sound.play("enemy_shoot")
	if _same_t >= limit and _sanction_cd <= 0.0:
		_same_t = 0.0
		_sanction_cd = 2.0
		_ring.shown = false
		_sanction()


## La sancion: una regla cae sobre ti (con aviso fijo de 0,65 s: se ve venir y se esquiva moviendote).
func _sanction() -> void:
	_float_text(tr("REGLA_SANCTION"), RED, Vector2(0, -150))
	var from := _muzzle()
	var base := (target.global_position - from).angle()
	var offs: Array = [0.0] if current_phase < 3 else [0.0, -0.5, 0.5]
	for o in offs:
		var d := Vector2.RIGHT.rotated(base + o)
		var ln := _ray_len(from, d, 640.0)
		_add_hazard(RulerZone.bar(from + d * ln * 0.5, Vector2(ln, 58.0), d.angle(), 0.65, 0.25, damage * 0.9))
	Sound.play("crack")


func _wave_logic(delta: float) -> void:
	_wave_t -= delta
	if _wave_t > 0.0:
		return
	var ph := clampi(current_phase, 1, 3) - 1
	_wave_t = 5.0 if _channeling else WAVE[ph]
	var n := mini(2, CENTI_CAP[ph] - _centi_count())
	if n > 0:
		_summon(n)


func _summon(n: int) -> void:
	var spots: Array = []
	for i in n:
		var p := arena_point(70.0)
		for _try in 8:
			p = arena_point(70.0)
			if p.distance_to(target.global_position) > 200.0:
				break
		spots.append(p)
		_add_hazard(RulerZone.disc(p, 30.0, 0.7, 0.05, 0.0))
	await get_tree().create_timer(0.75, true, true).timeout
	if state == State.DEAD or not is_inside_tree():
		return
	var made := _spawn_minions(spots, 12.0 + 3.0 * current_phase, damage * 0.5, tr("REGLA_CENTIMETER"), CENTI)
	for m in get_tree().get_nodes_in_group("centimetro"):
		if is_instance_valid(m):
			m.move_speed = 120.0 + 10.0 * current_phase
			m.add_collision_exception_with(self)
	if made > 0:
		Sound.play("enemy_shoot")


## Regletazo suelto con aviso corto, solo en reposo (en ataque ya tiene sus avisos).
func _spit_logic(delta: float) -> void:
	if state != State.IDLE or _channeling:
		_spit_warn = 0.0
		return
	if _spit_warn > 0.0:
		_spit_warn -= delta
		animated_sprite.modulate = Color(2.2, 1.0, 1.0) if int(_spit_warn * 24.0) % 2 == 0 else Color.WHITE
		if _spit_warn <= 0.0:
			animated_sprite.modulate = Color.WHITE
			var spd := 310.0 + 20.0 * current_phase
			var tv := Vector2.ZERO
			if target is CharacterBody2D:
				tv = (target as CharacterBody2D).velocity
			var aim: Vector2 = target.global_position + tv * minf(target.global_position.distance_to(_muzzle()) / spd, 0.7) * 0.8
			_fire((aim - _muzzle()).angle(), spd, 0.5)
			_spit_t = RNG.randf_range(4.0, 5.5) / (1.0 + 0.2 * (current_phase - 1))
		return
	_spit_t -= delta
	if _spit_t <= 0.0:
		_spit_warn = 0.45


## Defensa de la cura: centimetros (con tope) o un abanico corto. No se mueve (la real es la que tiene sombra).
func _defend(dt: float) -> void:
	_def_t -= dt
	if _def_t > 0.0:
		return
	_def_t = 3.2
	if _centi_count() < 3:
		_summon(1)
	else:
		var base := (target.global_position - _muzzle()).angle()
		for i in 3:
			_fire(base + (i - 1) * 0.22, 270.0, 0.5)


func _on_cure_cut() -> void:
	for c in get_tree().get_nodes_in_group("centimetro"):
		if is_instance_valid(c) and c.has_method("take_damage"):
			c.take_damage(9999.0, self)


func _on_cure_done() -> void:
	_same_t = 0.0
	_sanction_cd = 2.5


# ---------------------------------------------------------------- golpes de regla
## Lineas en el suelo (todas del ancho de la sala): la 1a sobre ti, las demas desplazadas.
func atk_golpes() -> void:
	var a := arena()
	var vertical := RNG.randf() < 0.5
	var n := 2 + current_phase
	var warn := 1.0 - 0.1 * current_phase
	if not await _tele(0.5, Color(2.2, 0.8, 0.8), 2.5):
		return
	var base: Vector2 = target.global_position
	var gap := 110.0
	var dir := 1.0 if RNG.randf() < 0.5 else -1.0
	for i in n:
		# la primera cae sobre ti; las demas se van desplazando en un sentido y otro
		var off: float = 0.0 if i == 0 else gap * ceil(i / 2.0) * (dir if i % 2 == 1 else -dir)
		var z: RulerZone
		if vertical:
			var x := clampf(base.x + off, a.position.x + 20.0, a.end.x - 20.0)
			z = RulerZone.bar(Vector2(x, a.get_center().y), Vector2(a.size.y, 56.0), PI * 0.5, warn, 0.25, damage * 0.9)
		else:
			var y := clampf(base.y + off, a.position.y + 20.0, a.end.y - 20.0)
			z = RulerZone.bar(Vector2(a.get_center().x, y), Vector2(a.size.x, 56.0), 0.0, warn, 0.25, damage * 0.9)
		_add_hazard(z)
		Sound.play("enemy_shoot")
		if not await _wait(0.38 - 0.04 * current_phase):
			return
	if not await _wait(warn + 0.3):
		return
	_tire(0.8)


# ---------------------------------------------------------------- te mide
## La regla te sigue y se clava donde estabas. "Mide" una cifra cada vez.
func atk_mide() -> void:
	_aim = (target.global_position - _muzzle()).normalized()
	_aim_len = 560.0
	var lane := RulerZone.bar(_muzzle(), Vector2(_aim_len, 64.0), 0.0, 1.6, 0.05, 0.0)
	_add_hazard(lane)
	var track := func(left: float):
		if left > 0.25:
			_aim = (target.global_position - _muzzle()).normalized()
		_aim_len = _ray_len(_muzzle(), _aim, 620.0)
		if is_instance_valid(lane):
			lane.size.x = _aim_len
			lane.global_position = _muzzle() + _aim * _aim_len * 0.5
			lane.rotation = _aim.angle()
	_last_cm = 150 + RNG.randi_range(0, 45)
	_float_text(tr("UTERO_REGLA_MIDE") % [_last_cm / 100.0], Color("ffe08a"))
	if not await _tele(0.95, Color(2.2, 0.7, 0.7), 2.5, track):
		return
	var hit: bool = is_instance_valid(lane) and lane.contains(target.global_position)
	var strike := RulerZone.bar(_muzzle() + _aim * _aim_len * 0.5, Vector2(_aim_len, 64.0), _aim.angle(), 0.0, 0.22, damage)
	_add_hazard(strike)
	if is_instance_valid(lane):
		lane.dismiss()
	Sound.play("crack")
	HitFx.shake(0.28)
	if not await _wait(0.3):
		return
	_tire(1.0 if hit else 1.6)  # si fallas, la regla queda clavada: tu ventana


# ---------------------------------------------------------------- llega puntual
## Desaparece, marca relojes y llega a uno: nadie la espera, pero avisa.
func atk_puntual() -> void:
	if not await _tele(0.4, Color(2.0, 1.2, 1.2), 1.5):
		return
	var spots: Array[Vector2] = [clamp_to_arena(target.global_position, 90.0)]
	for i in current_phase:
		spots.append(arena_point(100.0))
	invuln = true
	animated_sprite.modulate.a = 0.0
	hitbox.set_deferred("monitoring", false)
	_float_text(tr("UTERO_REGLA_PUNTUAL"), Color("ffe08a"))
	for p in spots:
		_add_hazard(RulerZone.disc(p, 118.0, 1.0, 0.22, damage * 1.1))
	if not await _wait(1.0):
		_reappear()
		return
	var at: Vector2 = spots[RNG.randi_range(0, spots.size() - 1)]
	global_position = at
	_reappear()
	Sound.play("crack")
	HitFx.shake(0.45)
	if not await _wait(0.3):
		return
	_tire(1.3)


func _reappear() -> void:
	invuln = false
	animated_sprite.modulate = Color.WHITE
	hitbox.set_deferred("monitoring", true)


func _cancel_attack() -> void:
	super()
	_reappear()  # si la cortan desaparecida (cambio de fase), que no se quede invisible


# ---------------------------------------------------------------- calendario
## Rejilla de dias: los marcados revientan, los demas son seguros.
func atk_calendario() -> void:
	var a := arena().grow(-40.0)
	var cw := a.size.x / CAL_COLS
	var ch := a.size.y / CAL_ROWS
	var cells: Array[Vector2i] = []
	for cx in CAL_COLS:
		for cy in CAL_ROWS:
			cells.append(Vector2i(cx, cy))
	RNG.shuffle(cells)
	var marked := 6 + 3 * current_phase
	# siempre uno bajo ti, para que el aviso se lea
	var under := Vector2i(clampi(int((target.global_position.x - a.position.x) / cw), 0, CAL_COLS - 1), clampi(int((target.global_position.y - a.position.y) / ch), 0, CAL_ROWS - 1))
	cells.erase(under)
	cells.push_front(under)
	if not await _tele(0.55, Color(2.0, 0.9, 0.9), 2.0):
		return
	for i in marked:
		var c: Vector2i = cells[i]
		var centre := a.position + Vector2((c.x + 0.5) * cw, (c.y + 0.5) * ch)
		_add_hazard(RulerZone.bar(centre, Vector2(cw - 8.0, ch - 8.0), 0.0, 1.0, 0.3, damage * 0.85, Color(1.0, 0.35, 0.5)))
	Sound.play("enemy_shoot")
	if not await _wait(1.6):
		return
	_tire(0.7)


# ---------------------------------------------------------------- reglazo (embestida)
## Embestida con aviso: franja roja en el suelo; agotada si choca con la pared.
func atk_reglazo() -> void:
	var lane := RulerZone.bar(global_position, Vector2(600, 80), 0.0, 0.8, 0.05, 0.0)
	_add_hazard(lane)
	_rush_dir = (target.global_position - global_position).normalized()
	var track := func(left: float):
		if left > 0.22:
			_rush_dir = (target.global_position - global_position).normalized()
		if is_instance_valid(lane):
			var ln := _ray_len(global_position + Vector2(0, -50), _rush_dir, 700.0)
			lane.size.x = ln
			lane.global_position = global_position + _rush_dir * ln * 0.5
			lane.rotation = _rush_dir.angle()
	if not await _tele(0.8, Color(2.2, 0.6, 0.6), 3.0, track):
		return
	Sound.play("dash")
	_hit_done = false
	var t := 0.0
	var hit_wall := false
	while t < 0.7:
		velocity = _rush_dir * (440.0 + current_phase * 50.0)
		if not await _frame():
			return
		_strike()
		t += 1.0 / 60.0
		if get_slide_collision_count() > 0:
			hit_wall = true
			break
	HitFx.shake(0.3 if hit_wall else 0.1)
	_tire(1.6 if hit_wall else 0.9)
	set_meta("stunned", hit_wall)


# ---------------------------------------------------------------- barrido de 180 grados
## La regla entera (2 m) gira 180 grados sobre ella. El semicirculo se marca en el suelo: sal de el,
## rodeala por detras o cruzalo con dash. Fase 3: ida y vuelta.
func atk_barrido() -> void:
	var from := _muzzle()
	var reach := minf(arena().size.length() * 0.5, 470.0)
	var dir := 1.0 if RNG.randf() < 0.5 else -1.0
	var start := (target.global_position - from).angle() - dir * PI * 0.5  # el barrido pasa por tu posicion
	var sweep_t: float = [1.25, 1.05, 0.9][current_phase - 1]
	var warn := _ts(0.8)
	_float_text(tr("REGLA_SWEEP"), RED, Vector2(0, -150))
	var guide := SweepGuide.new()
	guide.pivot = from
	guide.start = start
	guide.dir = dir
	guide.reach = reach
	guide.warn = warn
	guide.life = warn + sweep_t * (2.0 if current_phase >= 3 else 1.0) + 0.3
	_spawn_container().add_child(guide)
	guide.global_position = from
	var z := RulerZone.bar(from + Vector2.RIGHT.rotated(start) * reach * 0.5, Vector2(reach, 46.0), start, warn, sweep_t + 0.15, damage)
	z.fade = 0.2
	_add_hazard(z)
	if not await _tele(0.8, Color(2.2, 0.8, 0.8), 2.5):
		return
	var passes := 2 if current_phase >= 3 else 1
	var cur := start
	for ps in passes:
		var t := 0.0
		if ps > 0:
			z = RulerZone.bar(from + Vector2.RIGHT.rotated(cur) * reach * 0.5, Vector2(reach, 46.0), cur, 0.0, sweep_t + 0.15, damage)
			z.fade = 0.2
			_add_hazard(z)
			Sound.play("enemy_shoot")
		while t < sweep_t:
			if not await _frame():
				if is_instance_valid(guide):
					guide.queue_free()
				return
			t += 1.0 / 60.0
			var k := clampf(t / sweep_t, 0.0, 1.0)
			var kk := k * k * (3.0 - 2.0 * k)
			var ang := cur + dir * PI * kk
			if is_instance_valid(z):
				z.rotation = ang
				z.global_position = from + Vector2.RIGHT.rotated(ang) * reach * 0.5
		cur += dir * PI
		dir = -dir
		guide.dir = dir
		guide.start = cur
	HitFx.shake(0.3)
	if not await _wait(0.3):
		return
	_tire(1.5)


# ---------------------------------------------------------------- desafio de la cura
## TRES REGLAS: como los clones de la reina; la real es la que proyecta sombra.
func ch_reglas() -> void:
	await _ch_clones(3)


# ---------------------------------------------------------------- dibujos auxiliares (se ven, borde oscuro)
## Anillo de medida: aparece cuando llevas rato a la misma distancia y se va llenando hasta la sancion.
class MeasureRing extends Node2D:
	var boss: Node2D = null
	var shown := false
	var ref_r := 200.0
	var progress := 0.0
	var _fade := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		_fade = move_toward(_fade, 1.0 if shown else 0.0, delta * 4.0)
		queue_redraw()

	func _draw() -> void:
		if _fade <= 0.01:
			return
		var dark := Color(0.30, 0.03, 0.08)
		var red := Color(0.95, 0.22, 0.28)
		var pulse := 0.5 + 0.5 * sin(_t * (10.0 + 18.0 * progress))
		draw_arc(Vector2.ZERO, ref_r, 0.0, TAU, 64, Color(dark, 0.85 * _fade), 5.0)
		draw_arc(Vector2.ZERO, ref_r, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, Color(red, (0.7 + 0.3 * pulse) * _fade), 5.0)
		for i in 24:
			var a := i * TAU / 24.0
			var d := Vector2.RIGHT.rotated(a)
			draw_line(d * (ref_r - (10.0 if i % 6 == 0 else 5.0)), d * ref_r, Color(dark, 0.9 * _fade), 2.0)


## Semicirculo del barrido: contorno oscuro + relleno rojizo tenue + flecha del sentido.
class SweepGuide extends Node2D:
	var pivot := Vector2.ZERO
	var start := 0.0
	var dir := 1.0
	var reach := 400.0
	var warn := 0.8
	var life := 2.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 if _t < life - 0.3 else clampf((life - _t) / 0.3, 0.0, 1.0)
		var dark := Color(0.30, 0.03, 0.08)
		var red := Color(0.95, 0.22, 0.28)
		var pulse := 0.5 + 0.5 * sin(_t * 18.0)
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 25:
			pts.append(Vector2.RIGHT.rotated(start + dir * PI * i / 24.0) * reach)
		draw_colored_polygon(pts, Color(red, (0.07 + 0.05 * pulse) * a))
		draw_arc(Vector2.ZERO, reach, minf(start, start + dir * PI), maxf(start, start + dir * PI), 48, Color(dark, 0.85 * a), 4.0)
		for e in [start, start + dir * PI]:
			draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(e) * reach, Color(dark, 0.6 * a), 3.0)
		# flecha del sentido de giro en el medio del arco
		var mid := start + dir * PI * 0.5
		var tip := Vector2.RIGHT.rotated(mid) * reach * 0.8
		var tg := Vector2.RIGHT.rotated(mid + PI * 0.5) * dir
		draw_line(tip - tg * 40.0, tip + tg * 40.0, Color(red, 0.9 * a), 5.0)
		draw_line(tip + tg * 40.0, tip + tg * 20.0 + Vector2.RIGHT.rotated(mid) * 16.0, Color(red, 0.9 * a), 5.0)
		draw_line(tip + tg * 40.0, tip + tg * 20.0 - Vector2.RIGHT.rotated(mid) * 16.0, Color(red, 0.9 * a), 5.0)
