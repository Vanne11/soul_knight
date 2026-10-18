extends EnemyBoss

## SU PUDOROSIDAD, LA HOJA DE PARRA (piso 5, Palacio de la Censura; jefe final):
## - BARRAS: barras negras de censura cruzan la sala, cada una avisada por su contorno
##   (fase 3: tambien en diagonal). Despues se RUBORIZA: queda AGOTADA;
## - PIXELADO (fase 2+): parches de pixeles que tapan parte de la sala (no hacen dano:
##   esconden lo que pasa dentro, incluidas sus balas) mientras dispara abanicos lentos;
## - ESCUDO DE HOJAS: un anillo de hojas que giran a su alrededor la hace invulnerable;
##   si las rompes todas queda AGOTADA un buen rato;
## - FASE 3: toda la pantalla se vuelve gris (la censura total), te persigue y
##   te tapa a manotazos si te quedas cerca.

const LEAFG := Color(0.55, 0.9, 0.45)
const INK := Color(0.9, 0.9, 0.95)

var _shield: BossZone = null
var _leaves: Array = []
var _leaf_angle := 0.0
var _leaves_total := 0
var _leaves_broken := 0
var _grey_layer: CanvasLayer = null
var _grey_mat: ShaderMaterial = null
var _bubble_up := false


func _ready() -> void:
	super()
	fan_tint = LEAFG
	move_speed = 80.0
	keep_min = 230.0
	keep_max = 350.0


func _attack_pool() -> Array:
	var pool: Array
	match current_phase:
		1:
			pool = [&"atk_fan", &"atk_barras", &"atk_escudo"]
		2:
			pool = [&"atk_barras", &"atk_pixelado", &"atk_escudo", &"atk_fan", &"atk_barras"]
		_:
			pool = [&"atk_barras", &"atk_pixelado", &"atk_escudo", &"atk_barras", &"atk_pixelado"]
	if _leaves_alive() > 0:
		pool = pool.filter(func(x): return x != &"atk_escudo")
	return pool


func _pick_attack() -> StringName:
	if current_phase >= 3 and global_position.distance_to(target.global_position) < 160.0 and _last_attack != &"atk_tapar":
		return &"atk_tapar"
	return super()


func _challenges() -> Array:
	return [&"ch_burbuja", &"ch_apagon_censurado", &"ch_achica", &"ch_clones_hojas", &"ch_secuencia"]


func is_suck_immune() -> bool:
	return _bubble_up


func _channel_color() -> Color:
	return LEAFG


func _on_phase(n: int) -> void:
	_drop_shield()
	_leaves.clear()
	if n >= 2:
		move_speed = 80.0
	if n >= 3:
		move_speed = 112.0
		_grey_screen(true)


func _on_death() -> void:
	_drop_shield()
	_grey_screen(false)


func _exit_tree() -> void:
	super()
	if is_instance_valid(_grey_layer):
		_grey_layer.queue_free()


func _idle_move(_delta: float) -> void:
	if current_phase < 3:
		_drift()
		return
	# Fase final: no te suelta.
	var to_t: Vector2 = target.global_position - global_position
	velocity = to_t.normalized() * move_speed if to_t.length() > 110.0 else Vector2.ZERO


# ---------------------------------------------------------------- pantalla gris
func _grey_screen(on: bool) -> void:
	if on and not is_instance_valid(_grey_layer):
		_grey_layer = CanvasLayer.new()
		_grey_layer.layer = 1
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grey_mat = ShaderMaterial.new()
		_grey_mat.shader = load("res://src/shaders/screen_grey.gdshader")
		_grey_mat.set_shader_parameter("amount", 0.0)
		rect.material = _grey_mat
		_grey_layer.add_child(rect)
		var main := get_tree().get_first_node_in_group("main")
		var host: Node = main if main else get_tree().current_scene
		host.add_child(_grey_layer)
		host.move_child(_grey_layer, mini(1, host.get_child_count() - 1))  # tras el mundo, antes del HUD
		create_tween().tween_property(_grey_mat, "shader_parameter/amount", 0.94, 1.2)
	elif not on and is_instance_valid(_grey_layer):
		var layer := _grey_layer
		var tw := layer.create_tween()
		tw.tween_property(_grey_mat, "shader_parameter/amount", 0.0, 0.5)
		tw.tween_callback(layer.queue_free)
		_grey_layer = null


# ---------------------------------------------------------------- barras
func atk_barras() -> void:
	var n := 1 + current_phase
	if not await _tele(0.5, Color(0.5, 0.5, 0.7), 2.0):
		return
	var a := arena()
	var reach := a.size.length() * 1.1
	var used: Array[Vector2] = []
	for i in n:
		var kind := RNG.randi_range(0, 2 if current_phase >= 3 else 1)  # 0 horizontal, 1 vertical, 2 diagonal
		var rot := 0.0
		match kind:
			1:
				rot = PI * 0.5
			2:
				rot = PI * 0.25 * (1.0 if RNG.randf() < 0.5 else -1.0)
		var c: Vector2 = target.global_position if i == 0 else arena_point(60.0)
		# Que las barras no se amontonen
		for tries in 8:
			if used.all(func(u): return u.distance_to(c) > 170.0):
				break
			c = arena_point(60.0)
		used.append(c)
		var z := BossZone.rect(c, Vector2(reach, 56.0), rot, 0.9, 0.35, damage, INK)
		z.style = BossZone.Style.BAR
		z.one_hit = true
		z.fade = 0.3
		z.went_active.connect(func():
			HitFx.shake(0.2)
			Sound.play("crack"))
		_add_hazard(z)
		Sound.play("locked")
		if not await _wait(0.5):
			return
	if not await _wait(1.0):
		return
	_float_text(tr("BOSS_HOJA_BLUSH"), Color("ff9ec4"))
	_tire(1.3)


# ---------------------------------------------------------------- pixelado
func atk_pixelado() -> void:
	var n := current_phase  # 2 en fase 2, 3 en fase 3
	var side := 190.0 + 20.0 * (current_phase - 2)
	# Se aparta al lado contrario de la sala para disparar a traves de los parches.
	var a := arena()
	var far := a.get_center() - (target.global_position - a.get_center()) * 0.6
	if not await _walk_to(clamp_to_arena(far, 110.0), 1.3):
		return
	if not await _tele(0.5, Color(0.7, 0.7, 0.9), 2.0):
		return
	for i in n:
		var c: Vector2 = clamp_to_arena(target.global_position + Vector2(RNG.randf_range(-130, 130), RNG.randf_range(-130, 130)), 80.0) if i == 0 else arena_point(100.0)
		var z := BossZone.rect(c, Vector2(side, side), 0.0, 1.0, 5.5, 0.0, INK)
		z.style = BossZone.Style.PIXEL
		z.fade = 0.5
		_add_hazard(z)
	Sound.play("locked")
	if not await _wait(1.1):
		return
	for k in 3:
		animated_sprite.play("attack")
		var base := (target.global_position - _muzzle()).angle()
		var shots := 7
		for j in shots:
			_fire(base + (j - (shots - 1) / 2.0) * 0.22, 175.0, 0.65, LEAFG)
		Sound.play("enemy_shoot")
		if not await _wait(0.95):
			return
	if not await _wait(0.5):
		return


# ---------------------------------------------------------------- escudo de hojas
func atk_escudo() -> void:
	if not await _tele(0.7, Color(0.6, 2.0, 0.7), 2.0):
		return
	var n := 3 + current_phase
	_leaves.clear()
	_leaves_total = n
	_leaves_broken = 0
	_leaf_angle = RNG.randf_range(0.0, TAU)
	for i in n:
		var l := BossBreakable.new()
		l.kind = BossBreakable.Kind.LEAF
		l.enemy_name = "Hoja"
		l.max_health = 14.0 + _floor * 2.0
		l.life = 13.0
		l.contact_damage = damage * 0.4
		l.color = LEAFG
		_spawn_container().add_child(l)
		l.global_position = _muzzle()
		l.broken.connect(_on_leaf_broken)
		l.expired.connect(_on_leaf_expired)
		_leaves.append(l)
	invuln = true
	_drop_shield_zone()
	_shield = BossZone.circle(global_position, 80.0, 0.0, -1.0, 0.0, LEAFG)
	_shield.style = BossZone.Style.SHIELD
	_shield.follow = self
	_shield.follow_offset = Vector2(0, -60)
	_add_hazard(_shield)
	_float_text(tr("BOSS_HOJA_SHIELD"), LEAFG)
	Sound.play("enemy_shoot")


func _leaves_alive() -> int:
	var c := 0
	for l in _leaves:
		if is_instance_valid(l) and l.is_alive():
			c += 1
	return c


func _tick(delta: float) -> void:
	if _leaves.is_empty():
		return
	var alive := _leaves.filter(func(l): return is_instance_valid(l) and l.is_alive())
	if alive.is_empty():
		_leaves.clear()
		_drop_shield()
		return
	_leaf_angle += delta * (1.4 + 0.35 * current_phase)
	var r := 112.0 + 8.0 * current_phase
	var center := _muzzle()
	var room := find_owning_room()
	for i in alive.size():
		var ang: float = _leaf_angle + i * TAU / alive.size()
		var at := center + Vector2.RIGHT.rotated(ang) * r
		if room != null:
			at = room.clamp_global(at, 30.0)  # con la jefa junto a un muro las hojas salian del suelo
		alive[i].global_position = at


func _on_leaf_broken(_l: BossBreakable) -> void:
	_leaves_broken += 1
	_check_leaves_done(true)


func _on_leaf_expired(_l: BossBreakable) -> void:
	_check_leaves_done(false)


func _check_leaves_done(by_player: bool) -> void:
	await get_tree().process_frame  # que la hoja que cae salga ya del conteo
	if not is_instance_valid(self) or state == State.DEAD:
		return
	if _leaves_alive() > 0:
		return
	var had := invuln
	_drop_shield()
	if had and by_player and _leaves_broken >= _leaves_total and state != State.TRANSITION:
		_float_text(tr("BOSS_HOJA_BARE"), Color("ffe08a"))
		_stun(2.4)


func _drop_shield_zone() -> void:
	if is_instance_valid(_shield):
		_shield.queue_free()
	_shield = null


func _drop_shield() -> void:
	invuln = false
	_drop_shield_zone()


# ---------------------------------------------------------------- tapar (fase 3, cuerpo a cuerpo)
func atk_tapar() -> void:
	var z := BossZone.circle(global_position, 135.0, 0.55, 0.2, damage, INK)
	z.follow = self
	_add_hazard(z)
	if not await _tele(0.55, Color(0.6, 0.6, 0.9), 3.0):
		return
	HitFx.shake(0.2)
	await _wait(0.35)


# ---------------------------------------------------------------- desafios de la cura
## BURBUJA: una burbuja de hojas la envuelve: refleja tus balas hacia ti y el vortice del
## Satisfyer no la arrastra. Tiene una abertura que gira; mete balas por ahi.
func ch_burbuja() -> void:
	var R := 125.0
	var need := 5
	var st := {"open": RNG.randf_range(0.0, TAU), "pass": 0, "omega": 1.9, "flip": 2.5}
	var half := 0.22
	_bubble_up = true
	var bub := _make_prop(_body_center(), Callable(), Callable(), st)
	bub.drawer = func(n):
		var o: float = st.open
		var segs := 36
		for k in segs:
			var a0 := o + half + (TAU - 2.0 * half) * k / segs
			var a1 := o + half + (TAU - 2.0 * half) * (k + 1) / segs
			var col := Color(0.45, 0.85, 0.4, 0.95) if k % 2 == 0 else Color(0.3, 0.7, 0.3, 0.95)
			n.draw_arc(Vector2.ZERO, R, a0, a1, 4, col, 14.0)
		n.draw_circle(Vector2.ZERO, R, Color(0.5, 1.0, 0.5, 0.08))
		# la abertura bien marcada
		var p0 := Vector2.RIGHT.rotated(o - half) * R
		var p1 := Vector2.RIGHT.rotated(o + half) * R
		n.draw_line(p0, p0 * 0.8, Color(1, 1, 1, 0.9), 4.0)
		n.draw_line(p1, p1 * 0.8, Color(1, 1, 1, 0.9), 4.0)
		n.draw_arc(Vector2.ZERO, R + 12.0, o - half, o + half, 8, Color(1, 1, 0.6, 0.9), 4.0)
	bub.updater = func(n, dt):
		n.global_position = _body_center()
		st.flip -= dt
		if st.flip <= 0.0:
			st.flip = RNG.randf_range(1.8, 3.4)
			st.omega = -st.omega
		st.open += st.omega * dt
		for c in target.get_parent().get_children():
			if not (c is PlayerBullet) or c.has_meta("hoja"):
				continue
			var d: Vector2 = c.global_position - n.global_position
			var r := d.length()
			if r < R + 12.0 and r > R - 40.0:
				c.set_meta("hoja", true)
				var heading := Vector2.RIGHT.rotated(c.rotation)
				if heading.dot(d) > 0.0:
					continue  # sale de la burbuja, no entra
				if absf(angle_difference(d.angle(), st.open)) < half:
					st.pass += 1
					_chan_prog = float(st.pass) / need
					Sound.play("pickup")
					if st.pass >= need:
						_chan_ok = true
				else:
					var pos: Vector2 = c.global_position
					c.queue_free()
					_fire_from(pos, (target.global_position - pos).angle(), 290.0, 0.35, Color(1, 1, 1), 4.0)
					Sound.play("enemy_hit")
	await _ch_loop(16.0, func(dt):
		# desesperada: huye de ti por la sala
		_flee(150.0, dt)
		# ayuda del bot: apuntar a donde estara la abertura cuando llegue la bala
		var flight: float = target.global_position.distance_to(_body_center()) / 500.0
		var oang: float = st.open + st.omega * flight
		var oc: Vector2 = _body_center() + Vector2.RIGHT.rotated(oang) * R
		var facing: bool = (oc - _body_center()).dot(target.global_position - _body_center()) > 0.0
		bot_aim_pos = oc if facing else null)
	_bubble_up = false
	velocity = Vector2.ZERO


func ch_apagon_censurado() -> void:
	await _ch_blackout(130.0, Color(0.02, 0.02, 0.04), 6, 52.0, 13.0)


## SALA QUE SE ACHICA: barras de censura cierran la sala hacia un boton. Llega a el antes de
## quedar encerrado (si te encierran no te mata: falla el desafio).
func ch_achica() -> void:
	var a := arena()
	var btn := a.get_center()
	var best_d := -1.0
	for k in 40:
		var p := arena_point(90.0)
		var dd := p.distance_to(target.global_position)
		if dd > best_d:
			best_d = dd
			btn = p
	var t_close := 4.4
	var warn := 1.0
	var bars := _make_prop(a.position, Callable(), Callable(), {"k": 0.0})
	bars.drawer = func(n):
		var k: float = n.data.k
		var sz := a.size
		var L := (btn.x - a.position.x) * k
		var T := (btn.y - a.position.y) * k
		var Rr := sz.x - (a.end.x - btn.x) * k
		var B := sz.y - (a.end.y - btn.y) * k
		var ink := Color(0.02, 0.02, 0.03, 0.93)
		if n.t < warn:
			# aviso: parpadea el recuadro al que se va a reducir la sala
			var pulse := 0.5 + 0.5 * sin(n.t * 20.0)
			var fx := (btn - a.position)
			n.draw_rect(Rect2(fx - Vector2(80, 80), Vector2(160, 160)), Color(1, 1, 1, 0.5 + 0.5 * pulse), false, 4.0)
			return
		n.draw_rect(Rect2(-60, -60, sz.x + 120, T + 60), ink)
		n.draw_rect(Rect2(-60, B, sz.x + 120, sz.y - B + 60), ink)
		n.draw_rect(Rect2(-60, T, L + 60, B - T), ink)
		n.draw_rect(Rect2(Rr, T, sz.x - Rr + 60, B - T), ink)
		n.draw_rect(Rect2(L, T, Rr - L, B - T), Color(1, 1, 1, 0.9), false, 4.0)
	bars.updater = func(n, dt):
		var k := clampf((n.t - warn) / t_close, 0.0, 1.0)
		n.data.k = k
		if n.t >= warn:
			var pp: Vector2 = target.global_position - a.position
			var L := (btn.x - a.position.x) * k
			var T := (btn.y - a.position.y) * k
			var Rr := a.size.x - (a.end.x - btn.x) * k
			var B := a.size.y - (a.end.y - btn.y) * k
			if not Rect2(L, T, Rr - L, B - T).grow(-2.0).has_point(pp):
				_chan_fail = true
				Sound.play("puzzle_fail")
	var button := _make_prop(btn, Callable(), Callable(), {})
	button.drawer = func(n):
		var pulse := 0.5 + 0.5 * sin(n.t * 9.0)
		n.draw_circle(Vector2(0, -6), 36.0 + 5.0 * pulse, Color(1, 1, 0.5, 0.2))
		n.draw_circle(Vector2(0, -6), 22.0, Color(0.85, 0.15, 0.15))
		n.draw_arc(Vector2(0, -6), 22.0, 0.0, TAU, 20, Color.WHITE, 4.0)
		n.draw_circle(Vector2(0, -10), 14.0, Color(1, 0.4, 0.4))
	button.updater = func(n, dt):
		if target.global_position.distance_to(n.global_position) < 38.0:
			_chan_ok = true
		bot_goal_pos = n.global_position
		bot_dash_vec = (n.global_position - target.global_position).normalized() if target.global_position.distance_to(n.global_position) > 200.0 and n.t > 1.0 else Vector2.ZERO
	bot_goal_pos = btn
	await _ch_loop(warn + t_close + 1.0)


func ch_clones_hojas() -> void:
	await _ch_clones(4, 12.0)


## SECUENCIA: ella muestra tres flechas; repitelas con dashes en esas direcciones.
func ch_secuencia() -> void:
	_refill_stamina()
	var dirs: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var seq: Array[Vector2] = []
	for i in 3:
		var d: Vector2 = dirs[RNG.randi_range(0, 3)]
		if not seq.is_empty() and seq[-1] == d:
			d = dirs[(dirs.find(d) + 2) % 4]
		seq.append(d)
	var st := {"phase": 0, "t": 0.0, "idx": 0, "was": false, "bad": 0.0}
	var show := _make_prop(global_position + Vector2(210, -30), Callable(), Callable(), st)
	show.drawer = func(n):
		for i in 3:
			var c := Vector2(i * 62.0 - 62.0, 0)
			var live: bool = (st.phase == 0 and int(st.t / 0.8) == i) or (st.phase == 1 and i < st.idx)
			n.draw_rect(Rect2(c - Vector2(26, 26), Vector2(52, 52)), Color(0, 0, 0, 0.75))
			n.draw_rect(Rect2(c - Vector2(26, 26), Vector2(52, 52)), Color(1, 1, 0.6) if live else Color(1, 1, 1, 0.35), false, 3.0)
			if live:
				var dv: Vector2 = seq[i]
				var pts := PackedVector2Array([c + dv * 18.0, c - dv * 12.0 + dv.orthogonal() * 14.0, c - dv * 12.0 - dv.orthogonal() * 14.0])
				n.draw_colored_polygon(pts, Color(0.6, 1.0, 0.6) if st.phase == 1 else Color(1, 1, 0.6))
		if st.bad > 0.0:
			n.draw_rect(Rect2(-90, -34, 180, 68), Color(1, 0.2, 0.2, 0.7), false, 5.0)
	show.updater = func(n, dt):
		st.bad = maxf(0.0, st.bad - dt)
		if st.phase == 0:
			st.t += dt
			bot_dash_vec = Vector2.ZERO
			if st.t >= 3.0 * 0.8 + 0.4:
				st.phase = 1
				st.idx = 0
				st.t = 0.0
		else:
			var dashing: bool = target.is_dashing
			if dashing and not st.was:
				var dd: Vector2 = target._dash_direction
				var best: Vector2 = dirs[0]
				for c in dirs:
					if c.dot(dd) > best.dot(dd):
						best = c
				if best == seq[st.idx]:
					st.idx += 1
					Sound.play("pickup")
					_chan_prog = float(st.idx) / seq.size()
					if st.idx >= seq.size():
						_chan_ok = true
				else:
					st.idx = 0
					st.bad = 0.6
					Sound.play("puzzle_fail")
					st.phase = 0
					st.t = 0.0
			st.was = dashing
			bot_dash_vec = seq[st.idx] if st.idx < seq.size() else Vector2.ZERO
	await _ch_loop(17.0)
