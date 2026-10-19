extends EnemyBoss

## EL ADUANERO HORMONAL (piso 4, Perineo) - usa el MOTOR DINAMICO (dynamic = true).
## Control de fronteras con mucho papeleo. IDENTIDAD "VENTANILLAS": divide la sala en carriles
## numerados y CIERRA algunos (el cartel dice cuales y parpadean 1 s antes de caer), y sus sellos
## te PERSIGUEN por la sala hasta que se clavan.
## - PRESION: camina pegado a ti y estampa un sellito suelto (aviso 0,6 s) donde vas mientras camina.
## - VENTANILLAS: 4 carriles; 1 / 2 / 2-3 se cierran segun la fase (zona TOXIC). Mientras estan
##   cerradas te dispara por quedarte quieto. Despues queda AGOTADO "sellando";
## - SELLOS PERSEGUIDORES: salen de sus manos, te siguen y se fijan 0,5 s antes de caer;
## - ADUANA: barreras laser con un hueco; SELLOS: estampas en circulos marcados;
## - DOCUMENTOS (fase 2+): "¡QUIETO!" o "¡CIRCULE!"; quien incumple se come balas;
## - LLAMAR: "¡EL SIGUIENTE!" trae mini-funcionarios (enemy_funcionario.gd): estampan donde vas;
##   si viven ~10 s le entregan un tramite y lo curan; revientalos y a veces sueltan corazon.
## Cura (2 cargas): VENTANILLAS, APAGON, LINTERNA, SELLO.

const TAPE := Color(1.0, 0.85, 0.25)
const LASER := Color(1.0, 0.25, 0.3)
const HP_MULT := 0.7
const FUNC := preload("res://src/enemies/enemy_funcionario.tscn")
const BASE_SPEED := [120.0, 140.0, 160.0]
const BASE_CAPS := [0.85, 0.7, 0.6]

var _aim := Vector2.RIGHT
var _sign: Label = null
var _sign_mat := ShaderMaterial.new()
var _room: Node = null
var _stamp_t := 3.0


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = TAPE
	move_speed = BASE_SPEED[0]
	keep_min = 90.0
	keep_max = 170.0
	rest_min = 0.45
	rest_max = 0.8
	bullet_speed = 320.0
	tele_caps = BASE_CAPS.duplicate()
	max_health *= HP_MULT
	current_health = max_health
	_emit_health()
	_channels_total = 2
	_channels_left = 2
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	_sign_mat.shader = BossZone.CENSOR_UNSHADED
	_room = find_owning_room()
	BossAnimator.attach(self, true)  # arte actual (40x60): animacion por codigo, sin cuadros nuevos


func _attack_pool() -> Array:
	var pool: Array
	match current_phase:
		1:
			pool = [&"atk_fan", &"atk_ventanillas", &"atk_persigue", &"atk_sellos", &"atk_llamar"]
		2:
			pool = [&"atk_fan", &"atk_ventanillas", &"atk_persigue", &"atk_aduana", &"atk_sellos", &"atk_documentos", &"atk_llamar"]
		_:
			pool = [&"atk_ventanillas", &"atk_ventanillas", &"atk_persigue", &"atk_aduana", &"atk_sellos", &"atk_documentos", &"atk_llamar", &"atk_llamar"]
	if _funcs() >= current_phase + 1:
		pool = pool.filter(func(x): return x != &"atk_llamar")
	return pool


func _funcs() -> int:
	return get_tree().get_nodes_in_group("funcionario_aduana").size()


## Todo peligro del Aduanero se ve como peligro (borde rojo oscuro, franjas).
func _add_hazard(z: BossZone) -> BossZone:
	if z.style == BossZone.Style.NORMAL:
		z.style = BossZone.Style.TOXIC
	return super(z)


func _tick(delta: float) -> void:
	if state in [State.INTRO, State.TRANSITION, State.DEAD] or target == null:
		return
	var ph := clampi(current_phase, 1, 3) - 1
	move_speed = BASE_SPEED[ph] * (1.35 if _furia else 1.0)
	if state != State.IDLE or _channeling:
		return
	_stamp_t -= delta
	if _stamp_t <= 0.0:  # sellito suelto mientras camina: circulo avisado 0,6 s donde vas a estar
		_stamp_t = [3.6, 3.0, 2.4][ph]
		var lead: Vector2 = target.global_position + (target.velocity * 0.5 if "velocity" in target else Vector2.ZERO)
		var z := BossZone.circle(clamp_to_arena(lead, 40.0), 44.0, 0.6, 0.2, damage * 0.7, TAPE)
		z.went_active.connect(func(): Sound.play("crack"))
		_add_hazard(z)


func _challenges() -> Array:
	return [&"ch_ventanillas", &"ch_apagon", &"ch_linterna", &"ch_sello"]


func _channel_color() -> Color:
	return TAPE


func _on_phase(n: int) -> void:
	_hide_sign()
	_float_text(tr("ADU_PHASE_%d" % n), TAPE)


func _on_death() -> void:
	_hide_sign()


func _reset_idle() -> void:
	_hide_sign()


# ---------------------------------------------------------------- aduana (laser)
func atk_aduana() -> void:
	if not await _walk_to(arena().get_center(), 1.2):
		return
	if not await _tele(0.8, Color(2.2, 0.6, 0.7)):
		return
	var sweeps := current_phase
	var longest := 0.0
	for s in sweeps:
		longest = _barrier(RNG.randi_range(0, 3))
		if s < sweeps - 1 and not await _wait(1.9):
			return
	if not await _wait(1.1 + longest):
		return
	_float_text(tr("BOSS_ADU_CLOSED"), TAPE)
	_tire(1.4)


## Crea una barrera que cruza la sala desde un lado con un hueco. Devuelve lo que tarda.
func _barrier(side: int) -> float:
	var a := arena()
	var speed := 175.0 + 25.0 * current_phase
	var thick := 40.0
	var gap := 165.0 - 15.0 * current_phase
	var horizontal := side < 2  # avanza en x
	var dir_sign := 1.0 if side % 2 == 0 else -1.0
	var travel := (a.size.x if horizontal else a.size.y) - thick
	var t_total := travel / speed
	var lo := (a.position.y if horizontal else a.position.x)
	var hi := (a.end.y if horizontal else a.end.x)
	var pref: float = target.global_position.y if horizontal else target.global_position.x
	var gc := clampf(pref + RNG.randf_range(-90, 90), lo + gap * 0.5 + 25.0, hi - gap * 0.5 - 25.0)
	var parts := [[lo, gc - gap * 0.5], [gc + gap * 0.5, hi]]
	for pr in parts:
		var length: float = pr[1] - pr[0]
		if length < 4.0:
			continue
		var mid: float = (pr[0] + pr[1]) * 0.5
		var z: BossZone
		if horizontal:
			var x0 := (a.position.x + thick * 0.5) if dir_sign > 0.0 else (a.end.x - thick * 0.5)
			z = BossZone.rect(Vector2(x0, mid), Vector2(thick, length), 0.0, 1.0, t_total + 0.05, damage, LASER)
			z.vel = Vector2(dir_sign * speed, 0.0)
		else:
			var y0 := (a.position.y + thick * 0.5) if dir_sign > 0.0 else (a.end.y - thick * 0.5)
			z = BossZone.rect(Vector2(mid, y0), Vector2(length, thick), 0.0, 1.0, t_total + 0.05, damage, LASER)
			z.vel = Vector2(0.0, dir_sign * speed)
		z.one_hit = true
		z.fade = 0.2
		_add_hazard(z)
	Sound.play("locked")
	return t_total + 0.2


# ---------------------------------------------------------------- sellos
func atk_sellos() -> void:
	var n := 2 + current_phase
	if not await _tele(0.8, Color(2.2, 1.9, 0.7)):
		return
	for i in n:
		var p: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2(RNG.randf_range(-70, 70), RNG.randf_range(-70, 70)))
		var z := BossZone.circle(clamp_to_arena(p, 40.0), 66.0, 0.9, 0.22, damage * 1.1, TAPE)
		z.went_active.connect(func():
			HitFx.shake(0.22)
			Sound.play("crack"))
		_add_hazard(z)
		if not await _wait(0.42):
			return
	if not await _wait(1.1):
		return
	_tire(0.8)


# ---------------------------------------------------------------- ventanillas (identidad)
## La sala se divide en 4 carriles numerados; un cartel dice cuales se cierran (y parpadean ~1 s antes).
## Cerrado = zona de peligro 2 s. Fase 1: 1 carril; fase 2: 2 carriles x2 rondas; fase 3: 2-3 x3 rondas.
func atk_ventanillas() -> void:
	var a := arena().grow(-24.0)
	var vertical := RNG.randf() < 0.5
	var n := 4
	var rounds := current_phase
	var car := AduanaCarriles.new()
	car.area = a
	car.vertical = vertical
	car.n = n
	car.life = 2.6 + rounds * 4.2
	_spawn_container().add_child(car)
	var w := minf(1.1 - 0.1 * current_phase, tele_caps[current_phase - 1])
	for r in rounds:
		var k := 1 + (1 if current_phase >= 2 else 0) + (1 if current_phase == 3 and r == rounds - 1 else 0)
		var lanes: Array = range(n)
		lanes.shuffle()
		var shut: Array = lanes.slice(0, k)
		# casi siempre cierra el carril donde estas: te obliga a moverte
		var pp: Vector2 = target.global_position
		var mine := clampi(int(((pp.x - a.position.x) / a.size.x if vertical else (pp.y - a.position.y) / a.size.y) * n), 0, n - 1)
		if RNG.randf() < 0.75 and not (mine in shut):
			shut[0] = mine
		car.closing = shut
		car.closed = false
		var names := []
		for i in shut:
			names.append(str(i + 1))
		names.sort()
		_float_text(tr("ADU_LANE_CLOSE") % ", ".join(names), TAPE)
		for i in shut:
			var lr := car._lane(i)
			var z := BossZone.rect(lr.get_center(), lr.size, 0.0, w, 2.0, damage * 0.8, TAPE)
			z.one_hit = false
			z.fade = 0.3
			_add_hazard(z)
		if not await _tele(w, Color(2.2, 1.9, 0.7), 2.0):
			return
		car.closed = true
		Sound.play("crack")
		HitFx.shake(0.2)
		var t := 0.0
		var shot := 0.5
		while t < 2.0:
			if not await _frame():
				return
			t += 1.0 / 60.0
			shot -= 1.0 / 60.0
			if shot <= 0.0:  # no te quedes mirando: un sellazo directo
				shot = 0.75
				_fire((target.global_position - _muzzle()).angle(), bullet_speed * 1.05, 0.6, TAPE)
				Sound.play("enemy_shoot")
		car.closing = []
		car.closed = false
		if r < rounds - 1 and not await _wait(0.3):
			return
	_tire(1.2)


## Sellos que salen de sus manos y TE PERSIGUEN; se fijan 0,5 s antes de caer (aviso final claro).
func atk_persigue() -> void:
	var n := 1 + current_phase
	var life := 2.0
	var gap := 0.55
	if not await _tele(0.8, Color(2.2, 1.9, 0.7)):
		return
	var stamps: Array = []
	var spawned := 0
	var t := 0.0
	var next := 0.0
	var end_t := (n - 1) * gap + life + 0.5
	var chase := 165.0 + 15.0 * current_phase
	while t < end_t:
		if not await _frame():
			return
		t += 1.0 / 60.0
		if spawned < n and t >= next:
			next += gap
			spawned += 1
			var z := BossZone.circle(_muzzle(), 52.0, life, 0.25, damage * 1.1, TAPE)
			z.went_active.connect(func():
				HitFx.shake(0.22)
				Sound.play("crack"))
			_add_hazard(z)
			stamps.append(z)
			Sound.play("enemy_shoot")
		for z in stamps:
			if is_instance_valid(z) and z.phase == 0 and z.t < life - 0.5:
				var to: Vector2 = target.global_position - z.global_position
				z.global_position += to.normalized() * minf(to.length(), chase / 60.0)
	_tire(0.9)


## "¡EL SIGUIENTE!": llama mini-funcionarios (1 / 2 / 3 segun la fase).
func atk_llamar() -> void:
	if not await _tele(0.8, Color(2.2, 1.9, 0.7), 2.0):
		return
	var pts: Array = []
	for i in current_phase:
		pts.append(clamp_to_arena(global_position + Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * 90.0, 50.0))
	_float_text(tr("ADU_CALL"), TAPE)
	_spawn_minions(pts, 12.0 + _floor * 2.0, 6.0 + _floor * 1.5, tr("FUNC_NAME"), FUNC)
	Sound.play("crack")
	HitFx.shake(0.15)
	await _wait(0.4)


# ---------------------------------------------------------------- documentos
func atk_documentos() -> void:
	var first := 1 + RNG.randi_range(0, 1)  # 1 = quieto, 2 = circule
	var rules := [first] if current_phase < 3 else [first, 3 - first]
	for r in rules:
		_show_sign(r)
		if not await _tele(0.9, Color(2.2, 1.9, 0.7), 1.5):
			return
		var dur := 3.0 if current_phase < 3 else 2.6
		var t := 0.0
		var bad := 0.0
		var shot_cd := 0.0
		while t < dur:
			if not await _frame():
				return
			t += 1.0 / 60.0
			shot_cd = maxf(0.0, shot_cd - 1.0 / 60.0)
			var speed: float = (target as CharacterBody2D).velocity.length()
			var violating: bool = (r == 1 and speed > 45.0) or (r == 2 and speed < 25.0)
			bad = bad + 1.0 / 60.0 if violating else 0.0
			if bad > 0.4 and shot_cd <= 0.0:
				shot_cd = 0.5
				var ang := (target.global_position - _muzzle()).angle()
				_fire(ang, 340.0, 0.7, TAPE)
				Sound.play("enemy_shoot")
		_hide_sign()
		if not await _wait(0.5):
			return
	_tire(1.7)


func _show_sign(rule: int) -> void:
	_hide_sign()
	var text := tr("BOSS_ADU_STOP") if rule == 1 else tr("BOSS_ADU_GO")
	_sign = HudStyle.pixel_label(text, 34, Color(1.0, 0.95, 0.5) if rule == 1 else Color(0.7, 1.0, 0.7), true)
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.size = Vector2(420, 50)
	_sign.position = Vector2(-210, 16)
	_sign.material = _sign_mat
	_sign_mat.set_shader_parameter("color_amount", Censor.amount(_room) if _room else 1.0)
	_sign.z_index = 60
	add_child(_sign)
	Sound.play("puzzle_fail")


func _hide_sign() -> void:
	if is_instance_valid(_sign):
		_sign.queue_free()
	_sign = null


# ---------------------------------------------------------------- desafios de la cura
## VENTANILLAS: cuatro ventanillas numeradas y un cartel con el orden. Pisalas en orden;
## si te equivocas se reinicia.
func ch_ventanillas() -> void:
	var pts: Array[Vector2] = []
	var tries := 0
	while pts.size() < 4 and tries < 120:
		tries += 1
		var p := arena_point(100.0)
		if p.distance_to(global_position) < 130.0 or pts.any(func(q): return q.distance_to(p) < 170.0):
			continue
		pts.append(p)
	while pts.size() < 4:  # sala chica: relleno sin separacion (si no, faltaban ventanillas y fallaba el indice)
		pts.append(arena_point(100.0))
	var seq: Array = [1, 2, 3, 4]
	for i in range(3, 0, -1):
		var j := RNG.randi_range(0, i)
		var tmp = seq[i]
		seq[i] = seq[j]
		seq[j] = tmp
	var st := {"idx": 0, "flash": 0.0}
	var wins: Array = []
	var order := ""
	for x in seq:
		order += ("" if order == "" else " > ") + str(x)
	_chan_fx.label2 = tr("BOSS_CH_VENTANILLAS_D") + "   " + order
	for i in pts.size():
		var w := _make_prop(pts[i], Callable(), Callable(), {"num": i + 1, "done": false, "cool": 0.0})
		w.drawer = func(n):
			var fl: float = st.flash
			var col := Color(1, 1, 1, 0.9)
			if fl > 0.0:
				col = Color(1.0, 0.3, 0.3, 1.0)
			n.draw_rect(Rect2(-34, -76, 68, 84), Color(0.12, 0.12, 0.16, 0.85))
			n.draw_rect(Rect2(-34, -76, 68, 84), col, false, 4.0)
			n.draw_rect(Rect2(-26, -68, 52, 30), Color(0.85, 0.9, 1.0, 0.35))
			var f := ThemeDB.fallback_font
			n.draw_string_outline(f, Vector2(-12, -42), str(n.data.num), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 6, Color(0, 0, 0))
			n.draw_string(f, Vector2(-12, -42), str(n.data.num), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(1, 1, 0.6) if not n.data.done else Color(0.6, 1, 0.6))
			if n.data.done:
				n.draw_line(Vector2(-16, -14), Vector2(-4, -4), Color(0.6, 1, 0.6), 5.0)
				n.draw_line(Vector2(-4, -4), Vector2(18, -26), Color(0.6, 1, 0.6), 5.0)
			n.draw_circle(Vector2(0, 14), 26.0, Color(1, 1, 1, 0.12))
			n.draw_arc(Vector2(0, 14), 26.0, 0.0, TAU, 20, Color(1, 1, 1, 0.5), 2.0)
		w.updater = func(n, dt):
			n.data.cool = maxf(0.0, n.data.cool - dt)
			st.flash = maxf(0.0, st.flash - dt * 0.5)
			if n.data.cool > 0.0 or target.global_position.distance_to(n.global_position + Vector2(0, 14)) > 40.0:
				return
			n.data.cool = 0.5
			if n.data.num == seq[st.idx]:
				st.idx += 1
				n.data.done = true
				Sound.play("pickup")
				_chan_prog = float(st.idx) / seq.size()
				if st.idx >= seq.size():
					_chan_ok = true
			else:
				st.idx = 0
				st.flash = 0.8
				for o in wins:
					if is_instance_valid(o):
						o.data.done = false
				_chan_prog = 0.0
				Sound.play("puzzle_fail")
		wins.append(w)
	await _ch_loop(13.0, func(_dt):
		if st.idx < seq.size():
			var w: BossProp = wins[seq[st.idx] - 1]
			if is_instance_valid(w):
				var g: Vector2 = w.global_position + Vector2(0, 14)
				var pp: Vector2 = target.global_position
				bot_goal_pos = g
				# ayuda del bot: rodear las ventanillas que no toca (pisarlas reinicia el orden)
				for o in wins:
					if o == w or not is_instance_valid(o):
						continue
					var oc: Vector2 = o.global_position + Vector2(0, 14)
					var cp := Geometry2D.get_closest_point_to_segment(oc, pp, g)
					if cp.distance_to(oc) < 75.0 and pp.distance_to(oc) > 20.0:
						var side: Vector2 = (g - pp).normalized().orthogonal()
						if side.dot(cp - oc) < 0.0:
							side = -side
						bot_goal_pos = oc + side * 100.0
						break)


func ch_apagon() -> void:
	await _ch_blackout(150.0, Color(0.0, 0.0, 0.0), 5, 46.0, 12.0)


## LINTERNA: el aduanero barre la sala con un haz. Llega al interruptor escondiendote tras
## las cajas; si el haz te toca vuelves al principio (sin dano).
func ch_linterna() -> void:
	var sw := Vector2.ZERO
	var best_d := -1.0
	for k in 30:
		var p := arena_point(100.0)
		var dd := p.distance_to(global_position)
		if dd > best_d:
			best_d = dd
			sw = p
	var start: Vector2 = target.global_position
	var crates: Array[Vector2] = []
	var dirv := (sw - global_position).normalized()
	for k in 4:
		var base := global_position.lerp(sw, 0.25 + 0.17 * k)
		crates.append(clamp_to_arena(base + dirv.orthogonal() * RNG.randf_range(-130.0, 130.0), 90.0))
	for cp in crates:
		var c := _make_prop(cp, Callable(), Callable(), {})
		c.drawer = func(n):
			n.draw_rect(Rect2(-32, -50, 64, 56), Color(0.75, 0.6, 0.4))
			n.draw_rect(Rect2(-32, -50, 64, 56), Color(0.25, 0.15, 0.05), false, 3.0)
			n.draw_line(Vector2(-32, -50), Vector2(32, 6), Color(0.25, 0.15, 0.05), 3.0)
			n.draw_line(Vector2(32, -50), Vector2(-32, 6), Color(0.25, 0.15, 0.05), 3.0)
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(60, 40)
		cs.shape = rs
		cs.position = Vector2(0, -16)
		body.add_child(cs)
		c.add_child(body)
	var sws := _make_prop(sw, Callable(), Callable(), {})
	sws.drawer = func(n):
		var pulse := 0.5 + 0.5 * sin(n.t * 8.0)
		n.draw_circle(Vector2(0, -10), 34.0 + 4.0 * pulse, Color(1, 1, 0.5, 0.2))
		n.draw_arc(Vector2(0, -10), 34.0, 0.0, TAU, 24, Color(1, 1, 0.6, 0.9), 3.0)
		n.draw_rect(Rect2(-14, -26, 28, 30), Color(0.2, 0.2, 0.25))
		n.draw_rect(Rect2(-14, -26, 28, 30), Color.WHITE, false, 3.0)
		n.draw_line(Vector2(0, -8), Vector2(10, -24), Color(1, 0.4, 0.3), 5.0)
	sws.updater = func(n, dt):
		if target.global_position.distance_to(n.global_position) < 40.0:
			_chan_ok = true
	var origin := global_position
	var beam := _make_prop(origin, Callable(), Callable(), {"ang": (target.global_position - origin).angle() - 0.9, "dir": 1.0, "flip": 2.0, "cool": 0.0})
	var half := 0.2
	var length := 600.0
	beam.drawer = func(n):
		var pts := PackedVector2Array([Vector2(0, -20)])
		for k in 9:
			var a: float = n.data.ang - half + 2.0 * half * k / 8.0
			pts.append(Vector2(0, -20) + Vector2.RIGHT.rotated(a) * length)
		n.draw_colored_polygon(pts, Color(1, 1, 0.8, 0.26))
		n.draw_line(pts[0], pts[1], Color(1, 1, 0.85, 0.8), 3.0)
		n.draw_line(pts[0], pts[9], Color(1, 1, 0.85, 0.8), 3.0)
	beam.updater = func(n, dt):
		n.data.cool = maxf(0.0, n.data.cool - dt)
		n.data.flip -= dt
		if n.data.flip <= 0.0:
			n.data.flip = RNG.randf_range(1.6, 3.2)
			n.data.dir = -n.data.dir
		n.data.ang += n.data.dir * 0.8 * dt
		var tp: Vector2 = target.global_position
		var to := tp - origin
		var occluded := false
		for cp in crates:
			if Geometry2D.segment_intersects_circle(origin, tp, cp + Vector2(0, -16), 42.0) >= 0.0:
				occluded = true
				break
		var diff := absf(angle_difference(to.angle(), n.data.ang))
		if n.data.cool <= 0.0 and to.length() < length and diff < half + 0.04 and not occluded:
			n.data.cool = 1.0
			target.global_position = start
			Sound.play("puzzle_fail")
			_float_text(tr("BOSS_CH_LINTERNA_HIT"), Color("ffe08a"), Vector2(0, -120))
		# ayuda del bot: ir al interruptor cuando el haz esta lejos, si no a cubierto
		if occluded or diff > 0.75:
			bot_goal_pos = sw
		else:
			var nearest := crates[0]
			for cp in crates:
				if cp.distance_to(tp) < nearest.distance_to(tp):
					nearest = cp
			bot_goal_pos = nearest + (nearest - origin).normalized() * 55.0
	await _ch_loop(14.0)


## SELLO: te lanza un sello grande y lento. Haz dash contra el justo cuando llegue y se lo
## devuelves; si te alcanza te pega y lo vuelve a intentar.
func ch_sello() -> void:
	_refill_stamina()
	var st := {"state": 0, "t": 0.0, "dir": Vector2.RIGHT, "throws": 0}
	var stamp := _make_prop(_muzzle(), Callable(), Callable(), st)
	stamp.drawer = func(n):
		if st.state == 3:
			return
		if st.state == 0:
			var pulse := 0.5 + 0.5 * sin(n.t * 24.0)
			n.draw_line(Vector2.ZERO, st.dir * 420.0, Color(1, 0.4, 0.3, 0.4 + 0.5 * pulse), 4.0)
		n.draw_circle(Vector2.ZERO, 40.0, Color(0.85, 0.2, 0.25, 0.9) if st.state != 2 else Color(0.3, 0.8, 1.0, 0.95))
		n.draw_arc(Vector2.ZERO, 40.0, 0.0, TAU, 28, Color.WHITE, 4.0)
		n.draw_rect(Rect2(-8, -64, 16, 26), Color(0.3, 0.2, 0.15))
		n.draw_string(ThemeDB.fallback_font, Vector2(-22, 8), "OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	stamp.updater = func(n, dt):
		var tp: Vector2 = target.global_position + Vector2(0, -20)
		match st.state:
			0:
				st.t += dt
				n.global_position = _muzzle()
				if st.t < 0.55:
					st.dir = (tp - n.global_position).normalized()
				if st.t >= 0.85:
					st.state = 1
					st.throws += 1
					Sound.play("enemy_shoot")
			1:
				n.global_position += st.dir * 155.0 * dt
				var dist: float = n.global_position.distance_to(tp)
				if target.is_dashing and dist < 115.0:
					st.state = 2
					Sound.play("crack")
					HitFx.shake(0.3)
				elif dist < 38.0:
					target.receive_hit(damage * 0.8)
					st.state = 3
					st.t = 0.0
				elif not arena().grow(60.0).has_point(n.global_position):
					st.state = 3
					st.t = 0.0
				bot_dash_vec = (n.global_position - tp).normalized() if dist < 150.0 else Vector2.ZERO
			2:
				bot_dash_vec = Vector2.ZERO
				var to_b: Vector2 = _muzzle() - n.global_position
				n.global_position += to_b.normalized() * 520.0 * dt
				if to_b.length() < 60.0:
					_chan_ok = true
			3:
				bot_dash_vec = Vector2.ZERO
				st.t += dt
				if st.t > 0.7 and st.throws < 4:
					st.state = 0
					st.t = 0.0
	await _ch_loop(12.0)
