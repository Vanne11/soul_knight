extends EnemyBoss
class_name BossAltBase

## Base de los jefes ALTERNATIVOS (uno por reino, src/enemies/bosses/boss_<variante>.gd).
## Hereda todo de EnemyBoss (fases, ataques con aviso, cura interrumpible) y aporta:
## - las frases salen de `bossalt<reino>_<evento>` (assets/data/narrator/jefes_alt.json);
## - una biblioteca de DESAFIOS genericos para la cura (_ch_touch, _ch_break, _ch_hold,
##   _ch_chase, _ch_weak) con un dibujo propio por tema (draw_icon). Cada jefe los compone con
##   sus textos (BOSS_CH_<NOMBRE>_T/_D en locale/jefes_alt.csv) y su icono;
## - _fire_ring: anillo de balas con hueco.
## Las funciones ch_* de cada jefe son una linea que llama a estas, o un desafio propio.

const TOUCH_R := 44.0


func _say(suffix: String) -> void:
	var key := "bossalt%d_%s" % [_floor, suffix]
	if Narrator.has_lines(key):
		Narrator.say(key)


# ---------------------------------------------------------------- utilidades
## Anillo de `n` balas; si gap_w > 0 deja un hueco de ese ancho (rad) centrado en gap_at.
func _fire_ring(n: int, speed: float, offset := 0.0, gap_at := 0.0, gap_w := 0.0, mult := 0.6, tint := Color(0, 0, 0, 0)) -> void:
	for i in n:
		var a := offset + i * TAU / n
		if gap_w > 0.0 and absf(angle_difference(a, gap_at)) < gap_w * 0.5:
			continue
		_fire(a, speed, mult, tint)


## `n` puntos de la sala separados entre si y del jefe (para estaciones de desafio).
func _spread_points(n: int, min_gap := 170.0, margin := 100.0, from_boss := 130.0) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var tries := 0
	while pts.size() < n and tries < 200:
		tries += 1
		var p := arena_point(margin)
		if p.distance_to(global_position) < from_boss or pts.any(func(q): return q.distance_to(p) < min_gap):
			continue
		pts.append(p)
	while pts.size() < n:  # sala diminuta: relleno sin separacion
		pts.append(arena_point(margin))
	return pts


## Punto de rodeo para no pisar `avoid` yendo de `from` a `goal` (ayuda del bot).
func _detour(from: Vector2, goal: Vector2, avoid: Array, radius := 75.0) -> Vector2:
	for oc in avoid:
		var cp := Geometry2D.get_closest_point_to_segment(oc, from, goal)
		if cp.distance_to(oc) < radius and from.distance_to(oc) > 20.0:
			var side: Vector2 = (goal - from).normalized().orthogonal()
			if side.dot(cp - oc) < 0.0:
				side = -side
			return oc + side * (radius + 25.0)
	return goal


# ---------------------------------------------------------------- iconos de desafio
## Dibuja el icono `kind` centrado en el origen del nodo n (BossProp o BossTarget).
## extra: numero del ticket.
static func draw_icon(n: CanvasItem, kind: String, c: Color, extra := 0.0) -> void:
	var dark := Color(0.08, 0.06, 0.1)
	var f := ThemeDB.fallback_font
	match kind:
		"plug":
			n.draw_rect(Rect2(-15, -2, 30, 24), Color(0.88, 0.88, 0.94))
			n.draw_rect(Rect2(-15, -2, 30, 24), dark, false, 3.0)
			n.draw_rect(Rect2(-10, -18, 6, 16), c.lightened(0.35))
			n.draw_rect(Rect2(4, -18, 6, 16), c.lightened(0.35))
			n.draw_line(Vector2(0, 22), Vector2(0, 34), dark, 5.0)
			n.draw_circle(Vector2(0, 10), 4.0, c)
		"pill":
			n.draw_set_transform(Vector2.ZERO, 0.6)
			n.draw_circle(Vector2(-14, 0), 10.0, Color(0.96, 0.96, 1.0))
			n.draw_rect(Rect2(-14, -10, 28, 20), Color(0.96, 0.96, 1.0))
			n.draw_rect(Rect2(0, -10, 14, 20), c)
			n.draw_circle(Vector2(14, 0), 10.0, c)
			n.draw_line(Vector2(0, -10), Vector2(0, 10), dark, 3.0)
			n.draw_arc(Vector2(-14, 0), 10.0, PI * 0.5, PI * 1.5, 10, dark, 3.0)
			n.draw_arc(Vector2(14, 0), 10.0, -PI * 0.5, PI * 0.5, 10, dark, 3.0)
			n.draw_line(Vector2(-14, -10), Vector2(14, -10), dark, 3.0)
			n.draw_line(Vector2(-14, 10), Vector2(14, 10), dark, 3.0)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"drop":
			n.draw_circle(Vector2(0, 6), 14.0, c)
			n.draw_colored_polygon(PackedVector2Array([Vector2(-13, 2), Vector2(13, 2), Vector2(0, -22)]), c)
			n.draw_circle(Vector2(-5, 4), 4.0, Color(1, 1, 1, 0.8))
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var r := 22.0 if i % 2 == 0 else 9.0
				var a := -PI * 0.5 + i * PI / 5.0
				pts.append(Vector2(cos(a), sin(a)) * r)
			n.draw_colored_polygon(pts, c.lightened(0.25))
			pts.append(pts[0])
			n.draw_polyline(pts, dark, 2.0)
		"ticket":
			n.draw_rect(Rect2(-24, -16, 48, 32), Color(1.0, 0.95, 0.75))
			n.draw_rect(Rect2(-24, -16, 48, 32), dark, false, 3.0)
			n.draw_circle(Vector2(-24, 0), 5.0, dark)
			n.draw_circle(Vector2(24, 0), 5.0, dark)
			if extra > 0.0:
				var s := str(int(extra))
				n.draw_string(f, Vector2(-9.0 * s.length(), 12), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, dark)
		"cup":
			n.draw_rect(Rect2(-16, -14, 28, 28), Color(0.98, 0.95, 0.9))
			n.draw_rect(Rect2(-16, -14, 28, 28), dark, false, 3.0)
			n.draw_arc(Vector2(14, 0), 9.0, -PI * 0.5, PI * 0.5, 10, dark, 3.0)
			n.draw_rect(Rect2(-14, -12, 24, 8), c.darkened(0.3))
			n.draw_line(Vector2(-6, -20), Vector2(-3, -28), Color(1, 1, 1, 0.7), 2.0)
			n.draw_line(Vector2(4, -20), Vector2(7, -28), Color(1, 1, 1, 0.7), 2.0)
		"paper":
			n.draw_rect(Rect2(-17, -22, 34, 44), Color(0.98, 0.97, 0.92))
			n.draw_rect(Rect2(-17, -22, 34, 44), dark, false, 3.0)
			for k in 4:
				n.draw_line(Vector2(-11, -12 + k * 9), Vector2(11 - (k % 2) * 6, -12 + k * 9), c.darkened(0.2), 2.0)
		"cookie":
			n.draw_circle(Vector2.ZERO, 20.0, Color(0.82, 0.55, 0.28))
			n.draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, dark, 3.0)
			for p in [Vector2(-8, -7), Vector2(7, -9), Vector2(2, 4), Vector2(-9, 8), Vector2(11, 8)]:
				n.draw_circle(p, 3.2, Color(0.28, 0.14, 0.08))
		"light":
			n.draw_rect(Rect2(-13, -26, 26, 52), Color(0.16, 0.16, 0.2))
			n.draw_rect(Rect2(-13, -26, 26, 52), Color(1, 1, 1, 0.85), false, 3.0)
			n.draw_circle(Vector2(0, -15), 7.0, Color(0.95, 0.25, 0.25))
			n.draw_circle(Vector2(0, 0), 7.0, Color(1.0, 0.85, 0.25))
			n.draw_circle(Vector2(0, 15), 7.0, Color(0.3, 0.9, 0.4))
		"tile":
			n.draw_rect(Rect2(-24, -24, 48, 48), Color(0.3, 0.32, 0.38))
			n.draw_rect(Rect2(-24, -24, 48, 48), Color(1, 1, 1, 0.5), false, 2.0)
			n.draw_colored_polygon(PackedVector2Array([Vector2(-12, 2), Vector2(0, -12), Vector2(12, 2)]), Color(0.6, 0.62, 0.7))
			n.draw_rect(Rect2(-8, 2, 16, 12), Color(0.6, 0.62, 0.7))
		"comet":
			for k in 6:
				n.draw_circle(Vector2(-12.0 - k * 9.0, 0.0), 10.0 - k * 1.4, Color(c, 0.5 - k * 0.07))
			n.draw_circle(Vector2.ZERO, 13.0, c.lightened(0.5))
			n.draw_arc(Vector2.ZERO, 13.0, 0.0, TAU, 16, dark, 2.0)
		_:
			n.draw_circle(Vector2.ZERO, 16.0, c)


# ---------------------------------------------------------------- desafios genericos
## ESTACIONES: tocar `pts` (cada una con el icono `kind`). Opciones (o):
##   ordered: hay que tocarlas en orden numerico; numbered: muestra el numero (barajado);
##   reveal_one: solo se ve la siguiente; decoys + decoy_kind: señuelos que quitan un acierto;
##   limit: segundos.
func _ch_touch(pts: Array, kind: String, o := {}) -> void:
	var decoys: Array = o.get("decoys", [])
	var decoy_kind: String = o.get("decoy_kind", kind)
	var ordered: bool = o.get("ordered", false)
	var numbered: bool = o.get("numbered", false)
	var reveal_one: bool = o.get("reveal_one", false)
	var limit: float = o.get("limit", 12.0)
	var col := _channel_color()
	var n_good := pts.size()
	var nums: Array = range(1, n_good + 1)
	if numbered:
		for i in range(n_good - 1, 0, -1):
			var j := RNG.randi_range(0, i)
			var tmp = nums[i]
			nums[i] = nums[j]
			nums[j] = tmp
	var st := {"done": 0, "flash": 0.0}
	var props: Array = []
	var all_pts: Array = pts + decoys
	for i in all_pts.size():
		var decoy := i >= n_good
		var p := _make_prop(all_pts[i], Callable(), Callable(), {"num": 0 if decoy else nums[i], "done": false, "cool": 0.0, "decoy": decoy})
		p.drawer = func(n):
			var d: Dictionary = n.data
			var nxt: bool = not d.decoy and not d.done and (not ordered or d.num == st.done + 1)
			if reveal_one and not d.decoy and not nxt and not d.done:
				return
			var c := col
			if st.flash > 0.0 and (d.decoy or nxt):
				c = Color(1.0, 0.3, 0.3)
			if d.done:
				c = Color(0.6, 1.0, 0.6)
			var pulse := 0.5 + 0.5 * sin(n.t * 8.0)
			n.draw_circle(Vector2.ZERO, TOUCH_R, Color(c, 0.1 + (0.14 * pulse if nxt else 0.0)))
			n.draw_arc(Vector2.ZERO, TOUCH_R, 0.0, TAU, 28, Color(c, 0.75 if nxt else 0.4), 4.0 if nxt else 2.0)
			draw_icon(n, decoy_kind if d.decoy else kind, c, float(d.num) if (numbered and not d.decoy) else 0.0)
			if d.done:
				n.draw_line(Vector2(-14, 4), Vector2(-4, 14), Color(0.6, 1, 0.6), 5.0)
				n.draw_line(Vector2(-4, 14), Vector2(16, -10), Color(0.6, 1, 0.6), 5.0)
		p.updater = func(n, dt):
			var d: Dictionary = n.data
			d.cool = maxf(0.0, d.cool - dt)
			st.flash = maxf(0.0, st.flash - dt)
			if d.cool > 0.0 or d.done or target.global_position.distance_to(n.global_position) > TOUCH_R:
				return
			d.cool = 0.5
			if d.decoy:
				st.flash = 0.7
				Sound.play("puzzle_fail")
				if st.done > 0:
					for o2 in props:
						if is_instance_valid(o2) and o2.data.done:
							o2.data.done = false
							break
					st.done -= 1
					_chan_prog = float(st.done) / n_good
			elif not ordered or d.num == st.done + 1:
				d.done = true
				st.done += 1
				Sound.play("pickup")
				_chan_prog = float(st.done) / n_good
				if st.done >= n_good:
					_chan_ok = true
			else:
				st.flash = 0.7
				Sound.play("puzzle_fail")
		props.append(p)
	await _ch_loop(limit, func(_dt):
		var best: BossProp = null
		var bd := 1e9
		for q in props:
			if not is_instance_valid(q) or q.data.decoy or q.data.done:
				continue
			if ordered and q.data.num != st.done + 1:
				continue
			var dd: float = target.global_position.distance_to(q.global_position)
			if dd < bd:
				bd = dd
				best = q
		if best != null:
			var avoid: Array = []
			for q in props:
				if is_instance_valid(q) and q != best and not q.data.done and (q.data.decoy or ordered):
					avoid.append(q.global_position)
			bot_goal_pos = _detour(target.global_position, best.global_position, avoid))


## ROMPER: `n` blancos (icono `kind`) que vagan por la sala; hay que romperlos a tiros.
## o: hp, speed, limit.
func _ch_break(n: int, kind: String, o := {}) -> void:
	var hp: float = o.get("hp", 14.0)
	var limit: float = o.get("limit", 12.0)
	var speed: float = o.get("speed", 55.0)
	var col := _channel_color()
	var st := {"done": 0}
	var ts: Array = []
	var ang0 := RNG.randf_range(0.0, TAU)
	var a := arena().grow(-70.0)
	for i in n:
		var b := BossTarget.new()
		b.max_health = hp
		b.radius = 28.0
		b.data = {"v": Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * speed}
		b.drawer = func(x):
			var hf := clampf(x.current_health / x.max_health, 0.0, 1.0)
			draw_icon(x, kind, Color.WHITE if x.is_flashing() else col, 0.0)
			x.draw_arc(Vector2.ZERO, 30.0, -PI * 0.5, -PI * 0.5 + TAU * hf, 24, Color(1, 1, 1, 0.8), 3.0)
		b.tick_cb = func(x, dt):
			var v: Vector2 = x.data.v
			var p: Vector2 = x.global_position + v * dt
			if p.x < a.position.x or p.x > a.end.x:
				v.x = -v.x
			if p.y < a.position.y or p.y > a.end.y:
				v.y = -v.y
			x.data.v = v
			x.global_position = Vector2(clampf(p.x, a.position.x, a.end.x), clampf(p.y, a.position.y, a.end.y))
		_spawn_container().add_child(b)
		b.global_position = clamp_to_arena(arena().get_center() + Vector2.RIGHT.rotated(ang0 + i * TAU / n) * 190.0, 90.0)
		b.broken.connect(func(_b):
			st.done += 1
			_chan_prog = float(st.done) / n
			if st.done >= n:
				_chan_ok = true)
		ts.append(b)
	await _ch_loop(limit, func(_dt):
		var best: Node2D = null
		var bd := 1e9
		for q in ts:
			if is_instance_valid(q) and q.is_alive():
				var dd: float = target.global_position.distance_to(q.global_position)
				if dd < bd:
					bd = dd
					best = q
		bot_target_node = best)
	for q in ts:
		if is_instance_valid(q):
			q.die()


## MANTENER: un anillo (icono `kind`) recorre la sala; quedate dentro `need` s en total
## (fuera de el el progreso baja). o: need, limit, radius, speed (rad/s).
func _ch_hold(kind: String, o := {}) -> void:
	var need: float = o.get("need", 4.5)
	var limit: float = o.get("limit", 13.0)
	var radius: float = o.get("radius", 90.0)
	var spd: float = o.get("speed", 0.42)
	var col := _channel_color()
	var a := arena()
	var c := a.get_center()
	var rx := maxf(a.size.x * 0.5 - radius - 40.0, 40.0)
	var ry := maxf(a.size.y * 0.5 - radius - 40.0, 40.0)
	var ph := RNG.randf_range(0.0, TAU)
	var st := {"p": 0.0, "in": false}
	var ring := _make_prop(c, Callable(), Callable(), {})
	ring.drawer = func(n):
		var cc: Color = Color(0.6, 1.0, 0.6) if st["in"] else col
		n.draw_circle(Vector2.ZERO, radius, Color(cc, 0.16 + 0.1 * sin(n.t * 7.0)))
		n.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(cc, 0.9), 4.0)
		n.draw_arc(Vector2.ZERO, radius - 9.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(st.p / need, 0.0, 1.0), 40, Color(1, 1, 1, 0.9), 5.0)
		draw_icon(n, kind, cc, 0.0)
	ring.updater = func(n, dt):
		var tt: float = n.t * spd * TAU * 0.5 + ph
		n.global_position = c + Vector2(cos(tt) * rx, sin(tt * 1.31) * ry)
		st["in"] = target.global_position.distance_to(n.global_position) < radius - 6.0
		st.p = clampf(st.p + (dt if st["in"] else -dt * 0.6), 0.0, need)
		_chan_prog = st.p / need
		if st.p >= need:
			_chan_ok = true
		bot_goal_pos = n.global_position
	await _ch_loop(limit)


## PERSEGUIR: el icono `kind` huye por la sala rebotando; tocalo (cuerpo o dash).
## o: speed, limit.
func _ch_chase(kind: String, o := {}) -> void:
	var a := arena().grow(-30.0)
	var spd: float = o.get("speed", 370.0)
	var limit: float = o.get("limit", 8.0)
	var col := _channel_color()
	var v0 := Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * spd
	var it := _make_prop(_muzzle() + Vector2(0, 60), Callable(), Callable(), {"v": v0, "turn": 0.9})
	it.drawer = func(n):
		var pulse := 0.5 + 0.5 * sin(n.t * 22.0)
		n.draw_circle(Vector2.ZERO, 46.0, Color(col, 0.16 + 0.16 * pulse))
		n.draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 3.0)
		n.draw_set_transform(Vector2.ZERO, (n.data.v as Vector2).angle() if kind == "comet" else 0.0)
		draw_icon(n, kind, col, 0.0)
		n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	it.updater = func(n, dt):
		var v: Vector2 = n.data.v
		var away: Vector2 = n.global_position - target.global_position
		if away.length() < 230.0:
			v += away.normalized() * 650.0 * dt
			v = v.limit_length(spd * 1.16)
		n.data.turn -= dt
		if n.data.turn <= 0.0:
			n.data.turn = RNG.randf_range(0.6, 1.2)
			v = v.rotated(RNG.randf_range(-1.4, 1.4))
		var p: Vector2 = n.global_position + v * dt
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
		n.data.v = v
		n.global_position = p
		var tp: Vector2 = target.global_position
		var dist := tp.distance_to(p)
		if dist < 44.0:
			_chan_ok = true
		bot_goal_pos = p + v * 0.22
		bot_dash_vec = (p - tp).normalized() if dist < 190.0 else Vector2.ZERO
	await _ch_loop(limit)


## PUNTO DEBIL: un escudo rodea al jefe con un hueco que gira (y cambia de sentido). Solo
## cuentan los disparos hechos desde el lado del hueco. o: hits, limit, radius.
func _ch_weak(o := {}) -> void:
	var hits: int = o.get("hits", 4)
	var limit: float = o.get("limit", 13.0)
	var radius: float = o.get("radius", 100.0)
	var col := _channel_color()
	var st := {"ang": RNG.randf_range(-PI, PI), "dir": 1.0, "flip": 2.2, "n": 0, "flash": 0.0}
	var gap := 0.9  # ancho del hueco (rad)
	var sh := _make_prop(_body_center(), Callable(), Callable(), {})
	sh.drawer = func(n):
		var c := Color(1.0, 0.3, 0.3) if st.flash > 0.0 else col
		n.draw_arc(Vector2.ZERO, radius, st.ang + gap * 0.5, st.ang + TAU - gap * 0.5, 40, Color(c, 0.95), 9.0)
		n.draw_arc(Vector2.ZERO, radius + 8.0, st.ang + gap * 0.5, st.ang + TAU - gap * 0.5, 40, Color(1, 1, 1, 0.4), 2.0)
		var mid := Vector2.RIGHT.rotated(st.ang)
		n.draw_line(mid * (radius + 34.0), mid * (radius + 8.0), Color(1, 1, 0.5), 4.0)
		n.draw_line(mid * (radius + 8.0), mid * (radius + 22.0) + mid.orthogonal() * 9.0, Color(1, 1, 0.5), 4.0)
		n.draw_line(mid * (radius + 8.0), mid * (radius + 22.0) - mid.orthogonal() * 9.0, Color(1, 1, 0.5), 4.0)
	sh.updater = func(n, dt):
		n.global_position = _body_center()
		st.flash = maxf(0.0, st.flash - dt)
		st.flip -= dt
		if st.flip <= 0.0:
			st.flip = RNG.randf_range(1.6, 2.8)
			st.dir = -st.dir
		st.ang = wrapf(st.ang + st.dir * 1.15 * dt, -PI, PI)
	_ch_hit_cb = func(_amt, _src):
		var ang: float = (target.global_position - _body_center()).angle()
		if absf(angle_difference(ang, st.ang)) < gap * 0.5 + 0.1:
			st.n += 1
			_chan_prog = float(st.n) / hits
			Sound.play("enemy_hit")
			if st.n >= hits:
				_chan_ok = true
		else:
			st.flash = 0.25
	bot_target_node = self
	await _ch_loop(limit, func(_dt):
		bot_goal_pos = clamp_to_arena(_body_center() + Vector2.RIGHT.rotated(st.ang) * (radius + 150.0), 60.0))
