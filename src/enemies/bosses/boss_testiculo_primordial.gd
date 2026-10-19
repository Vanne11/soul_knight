extends EnemyBoss

## TESTICULO PRIMORDIAL (piso 2, Penelandia) - MOTOR DINAMICO (dynamic = true). Bola de pinball con mala leche.
## IDENTIDAD: PINBALL CONSTANTE. Incluso en reposo no camina: RUEDA y rebota por la sala (curvandose
## hacia ti). Sus ataques son ese mismo rebote con aviso:
## - PINBALL: embestidas encadenadas que rebotan en los muros, cada tramo mas rapido; cada tramo avisa
##   su direccion con una franja en el suelo; al final queda AGOTADO;
## - OLEADA (fase 2+): pared de espermatozoides con un hueco (el aviso marca de donde salen);
## - MITADES (fase 3): se parte en dos mitades que atacan COORDINADAS en pinza: salen de lados opuestos
##   y sus franjas se cruzan donde estabas; segunda pinza girada 90 grados. El cuerpo, pequeno, queda
##   AGOTADO en el centro (ventana para pegarle);
## - REBOTINES: bolitas de pinball con patas (enemy_rebotin.gd): pocas en fase 1, mas en la 3.
## Combos de 1-2 ataques ligeros en fase 2-3; agotado solo tras pinball, mitades y oleada.
## Cura (max 2): guardaespaldas o carrera.

const SPERM := Color(1.0, 0.92, 0.75)
const REBOTIN := preload("res://src/enemies/enemy_rebotin.tscn")
const BIG := [&"atk_pinball", &"atk_mitades", &"atk_oleada"]
const HP_MULT := 0.7
## Mitades de la fase 3 (tools/gen_testiculo_art.py): hojas de 4 cuadros de 96x96 (pinza + 3 de rodar), A mira a la derecha y B a la izquierda.
const HALF_A := preload("res://assets/sprites/enemies/penelandia/testiculo_primordial/testiculo_mitad_a_sheet.png")
const HALF_B := preload("res://assets/sprites/enemies/penelandia/testiculo_primordial/testiculo_mitad_b_sheet.png")
const REBOTIN_CAP := [2, 3, 5]
const ROLL_SPEED := [135.0, 155.0, 175.0]

var _aim := Vector2.RIGHT
var _aim_len := 400.0
var _base_scale := Vector2.ONE
var _roll_dir := Vector2.ZERO


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = SPERM
	rest_min = 0.4
	rest_max = 0.75
	bullet_speed = 290.0
	tele_caps = [0.85, 0.7, 0.6]
	move_speed = 90.0
	keep_min = 200.0
	keep_max = 330.0
	_base_scale = animated_sprite.scale
	max_health *= HP_MULT
	current_health = max_health
	_emit_health()
	_channels_total = 2
	_channels_left = 2
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	BossAnimator.attach(self)  # arte definitivo 176x184 (tools/gen_testiculo_art.py): cuadros nuevos + animacion por codigo


## El golpe del ataque ocurre cuando termina el aviso: se avisa al animador para que pase de la pose de carga
## (attack_<x>) a la de golpe (release_<x>) justo en ese momento.
func _tele(secs: float, col := Color(2.0, 2.0, 0.9), shake := 2.0, on_frame := Callable()) -> bool:
	var ok: bool = await super(secs, col, shake, on_frame)
	if ok:
		attack_released.emit(_last_attack)
	return ok


## Cuadros de rodar de una mitad (indices 1-3 de su hoja; el 0 es la pose de pinza).
func _half_frames(sheet: Texture2D) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, 4):
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * 96, 0, 96, 96)
		out.append(at)
	return out


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_fan", &"atk_pinball", &"atk_rebotines", &"atk_pinball"]
		2:
			return [&"atk_fan", &"atk_pinball", &"atk_oleada", &"atk_rebotines", &"atk_oleada"]
	return [&"atk_mitades", &"atk_pinball", &"atk_oleada", &"atk_fan", &"atk_mitades", &"atk_rebotines"]


func _challenges() -> Array:
	return [&"ch_guardaespaldas", &"ch_carrera"]


func _channel_color() -> Color:
	return Color(1.0, 0.75, 0.45)


func _hit_source() -> String:
	for g in get_tree().get_nodes_in_group("rebotin"):
		if is_instance_valid(g) and g.global_position.distance_to(target.global_position) < 50.0:
			return "rebotin"
	return "bola"


## Todo peligro del Testiculo se dibuja como maquina de pinball (rayas oscuras, borde rojo).
func _add_hazard(z: BossZone) -> BossZone:
	if z.style == BossZone.Style.NORMAL:
		z.style = BossZone.Style.TOXIC
	return super(z)


func _reset_idle() -> void:
	animated_sprite.scale = _base_scale


func _cure_cut_stun() -> float:
	return 5.0


func _combo_len() -> int:
	match current_phase:
		2:
			return RNG.randi_range(0, 1)
		3:
			return RNG.randi_range(1, 2)
	return 0


func _combo_next() -> StringName:
	var light: Array = [&"atk_fan", &"atk_rebotines"]
	light = light.filter(func(x): return x != _last_attack)
	return light[RNG.randi_range(0, light.size() - 1)]


func _pick_attack() -> StringName:
	var a := super()
	if a in BIG:
		_combo_left = 0
	return a


## PINBALL CONSTANTE: en reposo no camina, rueda. Rebota en los muros y se curva hacia ti (te presiona
## sin ser un perseguidor: puedes leer su trayectoria).
func _idle_move(delta: float) -> void:
	var to_t: Vector2 = target.global_position - global_position
	if _roll_dir == Vector2.ZERO:
		_roll_dir = to_t.normalized()
	if get_slide_collision_count() > 0:
		_roll_dir = _roll_dir.bounce(get_last_slide_collision().get_normal()).normalized()
	_roll_dir = _roll_dir.slerp(to_t.normalized(), clampf(0.9 * delta, 0.0, 1.0)).normalized()
	velocity = _roll_dir * ROLL_SPEED[clampi(current_phase, 1, 3) - 1]


# ---------------------------------------------------------------- pinball
func atk_pinball() -> void:
	var segs := 2 + current_phase
	_aim = (target.global_position - global_position).normalized()
	_roll_dir = Vector2.ZERO
	for s in segs:
		var first := s == 0
		var body := global_position + Vector2(0, -62)
		_aim_len = _ray_len(body, _aim, 900.0)
		var lane := BossZone.rect(body + _aim * _aim_len * 0.5, Vector2(_aim_len, 100), _aim.angle(), 2.0, 0.05, 0.0, Color(1.0, 0.35, 0.3))
		_add_hazard(lane)
		var track := func(left: float):
			if first and left > 0.25:
				_aim = (target.global_position - global_position).normalized()
			var b := global_position + Vector2(0, -62)
			_aim_len = _ray_len(b, _aim, 900.0)
			if is_instance_valid(lane):
				lane.size.x = maxf(_aim_len, 40.0)
				lane.global_position = b + _aim * lane.size.x * 0.5
				lane.rotation = _aim.angle()
		if not await _tele(0.85 if first else 0.55, Color(2.2, 0.6, 0.6), 3.0, track):
			return
		if is_instance_valid(lane):
			lane.dismiss()
		Sound.play("dash")
		_hit_done = false
		var t := 0.0
		var bounced := false
		while t < 1.6:
			velocity = _aim * minf(430.0 + current_phase * 40.0 + s * 45.0, 640.0)
			if not await _frame():
				return
			_strike()
			t += 1.0 / 60.0
			if get_slide_collision_count() > 0:
				var n := get_last_slide_collision().get_normal()
				_aim = _aim.bounce(n).normalized()
				bounced = true
				break
		velocity = Vector2.ZERO
		HitFx.shake(0.28)
		Sound.play("crack")
		if not bounced:
			break
	_tire(1.9)


# ---------------------------------------------------------------- oleada
func atk_oleada() -> void:
	var waves := current_phase  # 2 en fase 2, 3 en fase 3
	var a := arena()
	var horizontal := RNG.randf() < 0.5
	for w in waves:
		horizontal = not horizontal
		var from_start := RNG.randf() < 0.5
		var gap_half := 82.0
		var spacing := 24.0
		var pts: Array[Vector2] = []
		var dir: Vector2
		var gap_c: float
		if horizontal:
			var x := a.position.x + 34.0 if from_start else a.end.x - 34.0
			dir = Vector2.RIGHT if from_start else Vector2.LEFT
			gap_c = clampf(target.global_position.y + RNG.randf_range(-70, 70), a.position.y + gap_half + 20, a.end.y - gap_half - 20)
			var y := a.position.y + 24.0
			while y < a.end.y - 20.0:
				if absf(y - gap_c) > gap_half:
					pts.append(Vector2(x, y))
				y += spacing
		else:
			var y2 := a.position.y + 34.0 if from_start else a.end.y - 34.0
			dir = Vector2.DOWN if from_start else Vector2.UP
			gap_c = clampf(target.global_position.x + RNG.randf_range(-70, 70), a.position.x + gap_half + 20, a.end.x - gap_half - 20)
			var x2 := a.position.x + 24.0
			while x2 < a.end.x - 20.0:
				if absf(x2 - gap_c) > gap_half:
					pts.append(Vector2(x2, y2))
				x2 += spacing
		# Aviso: las franjas de donde salen. El hueco queda libre.
		for seg in _segments(pts, horizontal, spacing):
			var z := BossZone.rect(seg[0], seg[1], 0.0, 0.8, 0.05, 0.0, SPERM)
			_add_hazard(z)
		animated_sprite.play("attack")
		Sound.play("locked")
		if not await _wait(0.8):
			return
		attack_released.emit(&"atk_oleada")
		Sound.play("enemy_shoot")
		for p in pts:
			var b := _fire_from(p, dir.angle(), 270.0, 0.6, SPERM, 6.0)
			b.scale = Vector2(1.5, 1.5)
		if not await _wait(1.0):
			return
	if not await _wait(0.8):
		return
	_tire(1.2)


## Agrupa los puntos de salida en tramos continuos para dibujar el aviso.
func _segments(pts: Array[Vector2], horizontal: bool, spacing: float) -> Array:
	var out := []
	if pts.is_empty():
		return out
	var start := pts[0]
	var prev := pts[0]
	for i in range(1, pts.size() + 1):
		var cut := i == pts.size()
		if not cut:
			var gap := (pts[i].y - prev.y) if horizontal else (pts[i].x - prev.x)
			cut = gap > spacing * 1.5
		if cut:
			if horizontal:
				out.append([Vector2(start.x, (start.y + prev.y) * 0.5), Vector2(34.0, absf(prev.y - start.y) + spacing)])
			else:
				out.append([Vector2((start.x + prev.x) * 0.5, start.y), Vector2(absf(prev.x - start.x) + spacing, 34.0)])
			if i < pts.size():
				start = pts[i]
		if i < pts.size():
			prev = pts[i]
	return out


# ---------------------------------------------------------------- mitades
## PINZA: se parte en dos mitades que atacan coordinadas. Salen de lados opuestos y sus franjas de
## aviso (1 s) se cruzan en el punto donde estabas; ambas parten a la vez. Segunda pinza girada 90
## grados. Mientras tanto el cuerpo, mas chico, se queda AGOTADO en el centro.
func atk_mitades() -> void:
	var fr_a := _half_frames(HALF_A)
	var fr_b := _half_frames(HALF_B)
	var waves := 2
	var base := RNG.randf() * TAU
	var tw := minf(1.0, tele_caps[current_phase - 1])
	for w in waves:
		var aim_pt := clamp_to_arena(target.global_position, 80.0)
		if w > 0:
			base += PI * 0.5
		var halves: Array = []
		for k in 2:
			var d := Vector2.RIGHT.rotated(base + k * PI)
			var from := clamp_to_arena(aim_pt - d * 330.0, 70.0)
			var v := (aim_pt - from).normalized()
			_warn_line(from + Vector2(0, -20), v, _ray_len(from + Vector2(0, -20), v, 900.0), 64.0, tw, Color(0.95, 0.3, 0.25))
			halves.append([from, v])
		if w == 0:
			animated_sprite.scale = _base_scale * 0.72
		if not await _tele(tw, Color(2.2, 1.4, 0.6), 4.0):
			return
		for h in halves:
			var bn := BossBouncer.new()
			bn.frames_right = fr_a
			bn.frames_left = fr_b
			bn.sprite_scale = 0.85
			bn.dir = h[1]
			bn.speed = 330.0
			bn.bounces_left = 3
			bn.damage = damage * 0.9
			bn.body_radius = 32.0
			_spawn_container().add_child(bn)
			bn.global_position = h[0]
		Sound.play("crack")
		HitFx.shake(0.4)
		if w < waves - 1 and not await _wait(1.8):
			return
	# El cuerpo, mas chico, se queda en el centro: ventana para pegarle mientras esquivas las mitades.
	_tire(3.5)


## REBOTINES: bolitas de pinball con patas (pocas en fase 1, mas en la 3). Con el tope lleno, abanico.
func atk_rebotines() -> void:
	var room_left: int = REBOTIN_CAP[current_phase - 1] - get_tree().get_nodes_in_group("rebotin").size()
	var n := mini(current_phase + (1 if current_phase == 3 else 0), room_left)
	if n <= 0:
		await atk_fan()
		return
	var spots: Array = []
	for i in n:
		spots.append(clamp_to_arena(global_position + Vector2.RIGHT.rotated(RNG.randf() * TAU) * RNG.randf_range(120.0, 230.0), 70.0))
	for p in spots:
		_add_hazard(BossZone.circle(p, 34.0, 0.6, 0.05, 0.0, SPERM))
	if not await _tele(0.6, Color(2.2, 1.4, 0.6), 2.0):
		return
	_spawn_minions(spots, 14.0, damage * 0.5, tr("ENEMY_REBOTIN_NAME"), REBOTIN)
	_float_text(tr("TEST_REBOTINES"), SPERM)
	Sound.play("crack")
	await _wait(0.4)


# ---------------------------------------------------------------- desafios de la cura
## GUARDAESPALDAS: espermatozoides que no hacen dano pero te empujan y te cierran el paso.
## Hay que abrirse paso (el dash los atraviesa) y pegarle de cerca (o tocarlo).
func ch_guardaespaldas() -> void:
	_refill_stamina()
	for i in 7:
		var g := _make_prop(global_position + Vector2.RIGHT.rotated(i * TAU / 7.0) * 120.0, Callable(), Callable(), {"i": i, "face": Vector2.RIGHT})
		g.drawer = func(n):
			var f: Vector2 = n.data.face
			n.draw_set_transform(Vector2(0, -16), f.angle())
			for k in 6:
				n.draw_circle(Vector2(-16 - k * 8, sin(n.t * 14.0 + k) * 4.0), 7.0 - k * 0.9, Color(1, 0.95, 0.85, 0.95))
			n.draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.97, 0.9))
			n.draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 20, Color(0.35, 0.2, 0.1), 2.5)
			n.draw_circle(Vector2(5, -4), 3.0, Color(0.2, 0.1, 0.1))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		g.updater = func(n, dt):
			var tp: Vector2 = target.global_position
			var dirv := (tp - global_position).normalized()
			var idx: int = n.data.i
			var desired := global_position + dirv * (112.0 + (idx % 2) * 36.0) + dirv.orthogonal() * ((idx - 3) * 38.0)
			n.global_position = n.global_position.move_toward(desired, 175.0 * dt)
			n.data.face = (tp - n.global_position).normalized()
			var d: Vector2 = tp - n.global_position
			if not target.is_dashing and d.length() < 50.0:
				target.move_and_collide(d.normalized() * 340.0 * dt)
	_ch_hit_cb = func(_a, _s):
		if _chan_t > 0.6 and target.global_position.distance_to(global_position) < 125.0:
			_chan_ok = true
	bot_target_node = self
	await _ch_loop(9.5, func(_dt):
		_flee(70.0, _dt)
		# al empezar, los guardaespaldas te sacan a empujones
		if _chan_t < 0.5 and target.global_position.distance_to(global_position) < 320.0:
			target.move_and_collide((target.global_position - global_position).normalized() * 14.0)
			return
		if _chan_t > 0.6 and target.global_position.distance_to(global_position) < 80.0:
			_chan_ok = true
		_chan_prog = clampf(1.0 - (target.global_position.distance_to(global_position) - 95.0) / 300.0, 0.0, 0.95)
		bot_goal_pos = global_position
		bot_dash_vec = (global_position - target.global_position).normalized() if target.global_position.distance_to(global_position) < 330.0 else Vector2.ZERO)


## CARRERA: aparece un ovulo en la sala y una manada corre a por el. Llega tu antes.
func ch_carrera() -> void:
	var best := Vector2.ZERO
	var best_score := -1.0e9
	for k in 40:
		var p := arena_point(90.0)
		var dp := p.distance_to(target.global_position)
		var db := p.distance_to(global_position)
		if dp > 430.0 or dp < 230.0 or db < 240.0:
			continue
		var sc := db - dp * 1.2
		if sc > best_score:
			best_score = sc
			best = p
	if best_score < -1.0e8:
		best = clamp_to_arena(target.global_position + (target.global_position - global_position).normalized() * 150.0, 90.0)
	var pack: Array = []
	var egg := _make_prop(best, Callable(), Callable(), {})
	egg.drawer = func(n):
		var pulse := 0.5 + 0.5 * sin(n.t * 10.0)
		n.draw_circle(Vector2(0, -16), 50.0 + 6.0 * pulse, Color(1, 1, 1, 0.18))
		n.draw_arc(Vector2(0, -16), 50.0 + 6.0 * pulse, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 3.0)
		n.draw_circle(Vector2(0, -16), 24.0, Color(1.0, 0.85, 0.88))
		n.draw_arc(Vector2(0, -16), 24.0, 0.0, TAU, 24, Color(0.4, 0.1, 0.2), 3.0)
		n.draw_circle(Vector2(0, -16), 9.0, Color(0.85, 0.2, 0.3))
	egg.updater = func(n, dt):
		if n.t > 0.9:
			for s in pack:
				if is_instance_valid(s):
					s.data.go = true
		var tp: Vector2 = target.global_position
		var dist := tp.distance_to(n.global_position)
		if dist < 40.0:
			_chan_ok = true
		bot_goal_pos = n.global_position
		bot_dash_vec = (n.global_position - tp).normalized() if dist > 160.0 and n.t > 0.9 else Vector2.ZERO
	for i in 6:
		var s := _make_prop(global_position + Vector2(RNG.randf_range(-50, 50), RNG.randf_range(-20, 20)), Callable(), Callable(), {"go": false})
		s.drawer = func(n):
			var f: Vector2 = (best - n.global_position).normalized()
			n.draw_set_transform(Vector2(0, -14), f.angle())
			for k in 5:
				n.draw_circle(Vector2(-14 - k * 8, sin(n.t * 16.0 + k) * 4.0), 6.0 - k * 0.8, Color(1, 0.95, 0.85, 0.9))
			n.draw_circle(Vector2.ZERO, 13.0, Color(1.0, 0.97, 0.9))
			n.draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 20, Color(0.35, 0.2, 0.1), 2.5)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		s.updater = func(n, dt):
			if not n.data.go:
				return
			var dv: Vector2 = best - n.global_position
			if dv.length() < 28.0:
				_chan_fail = true
			else:
				n.global_position += dv.normalized().rotated(sin(n.t * 6.0 + n.get_instance_id() % 7) * 0.25) * 200.0 * dt
		pack.append(s)
	await _ch_loop(8.5)
