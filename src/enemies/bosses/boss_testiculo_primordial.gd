extends EnemyBoss

## TESTICULO PRIMORDIAL (piso 2, Penelandia). Bola de pinball con mala leche:
## - PINBALL: embestidas encadenadas que rebotan en los muros; cada tramo avisa su
##   direccion con una franja en el suelo; al final choca y queda AGOTADO;
## - OLEADA (fase 2+): una pared de espermatozoides cruza la sala con un hueco; el
##   aviso marca de donde salen y el hueco queda libre;
## - MITADES (fase 3): se parte en dos mitades que rebotan por la sala dejando estela
##   mientras el cuerpo, pequeño y desprotegido, queda AGOTADO en el centro.

const SPERM := Color(1.0, 0.92, 0.75)

var _aim := Vector2.RIGHT
var _aim_len := 400.0
var _base_scale := Vector2.ONE


func _ready() -> void:
	super()
	fan_tint = SPERM
	move_speed = 90.0
	keep_min = 200.0
	keep_max = 330.0
	_base_scale = animated_sprite.scale


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_fan", &"atk_pinball", &"atk_pinball"]
		2:
			return [&"atk_fan", &"atk_pinball", &"atk_oleada", &"atk_oleada"]
	return [&"atk_mitades", &"atk_pinball", &"atk_oleada", &"atk_fan", &"atk_mitades"]


func _challenges() -> Array:
	return [&"ch_guardaespaldas", &"ch_carrera"]


func _channel_color() -> Color:
	return Color(1.0, 0.75, 0.45)


func _reset_idle() -> void:
	animated_sprite.scale = _base_scale


# ---------------------------------------------------------------- pinball
func atk_pinball() -> void:
	var segs := 2 + current_phase
	_aim = (target.global_position - global_position).normalized()
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
		if not await _tele(0.85 if first else 0.5, Color(2.2, 0.6, 0.6), 3.0, track):
			return
		if is_instance_valid(lane):
			lane.dismiss()
		Sound.play("dash")
		_hit_done = false
		var t := 0.0
		var bounced := false
		while t < 1.6:
			velocity = _aim * (470.0 + current_phase * 40.0)
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
			var z := BossZone.rect(seg[0], seg[1], 0.0, 0.9, 0.05, 0.0, SPERM)
			_add_hazard(z)
		animated_sprite.play("attack")
		Sound.play("locked")
		if not await _wait(0.9):
			return
		Sound.play("enemy_shoot")
		for p in pts:
			var b := _fire_from(p, dir.angle(), 215.0, 0.6, SPERM, 6.0)
			b.scale = Vector2(1.5, 1.5)
		if not await _wait(1.0):
			return
	if not await _wait(1.6):
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
func atk_mitades() -> void:
	var a0 := (target.global_position - global_position).angle()
	var dirs := [a0, a0 + TAU * 0.36]
	var body := global_position + Vector2(0, -50)
	for d in dirs:
		var v := Vector2.RIGHT.rotated(d)
		_warn_line(body, v, _ray_len(body, v, 900.0), 70.0, 1.1, Color(1.0, 0.35, 0.3))
	if not await _tele(1.1, Color(2.2, 1.4, 0.6), 4.0):
		return
	var tex := animated_sprite.sprite_frames.get_frame_texture("idle", 0)
	for d in dirs:
		var h := BossBouncer.new()
		h.tex = tex
		h.sprite_scale = 0.8
		h.dir = Vector2.RIGHT.rotated(d)
		h.speed = 330.0
		h.bounces_left = 4
		h.damage = damage * 0.9
		h.body_radius = 32.0
		_spawn_container().add_child(h)
		h.global_position = global_position
	Sound.play("crack")
	HitFx.shake(0.4)
	animated_sprite.scale = _base_scale * 0.72
	# El cuerpo, mas chico, se queda en el centro: ventana para pegarle
	# mientras esquivas las mitades.
	_tire(5.0)


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
