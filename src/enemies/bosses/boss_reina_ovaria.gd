extends EnemyBoss

## SU MAJESTAD OVARIA II (piso 3, Vulvania) - usa el MOTOR DINAMICO (dynamic = true). Reina del ciclo.
## IDENTIDAD J2: los huevos ECLOSIONAN si no los rompes a tiempo. En el ultimo segundo cada huevo
## avisa (se enciende un circulo de peligro rojizo con "ECLOSIONA" y el huevo tiembla) y revienta:
## golpea a quien este cerca y suelta Crias ovaricas (2 por huevo en la fase 3). Las crias lloran
## lagrimones lentos y, si las dejas vivas ~9 s, vuelven con mama y la curan. Desde la fase 2 ademas
## pone un huevo suelto de vez en cuando mientras camina (presion constante).
## - Esbirros: pocas crias en fase 1 (2 huevos) y mas en la 3 (4 huevos x 2 crias; tope 6).
## - OVULOS: pone huevos marcados en el suelo; si no los rompes a tiempo eclosionan en
##   bichos. Desde la fase 2 un escudo de ciclo la hace invulnerable mientras quede alguno;
##   romper el ultimo la deja AGOTADA;
## - ONDAS: anillos concentricos rosados, lentos, con dos huecos que se desplazan;
## - FOLICULOS (fase 2+): globos que caen donde estas; cada uno avisa su circulo;
##   despues del ataque de ondas queda AGOTADA.

const PINK := Color(1.0, 0.45, 0.7)
const HP_MULT := 0.75
const CRIA := preload("res://src/enemies/enemy_cria_ovarica.tscn")
const HATCH_WARN := 1.2     ## segundos de aviso de eclosion
const BASE_SPEED := [90.0, 110.0, 130.0]

var _shield: BossZone = null
var _eggs_open := 0       # huevos por resolver
var _eggs_hatched := 0
var _eggs_broken := 0
var _egg_t := 9.0         ## enfriamiento del huevo suelto (fase 2+)


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = PINK
	move_speed = BASE_SPEED[0]
	keep_min = 150.0
	keep_max = 240.0
	rest_min = 0.45
	rest_max = 0.8
	bullet_speed = 280.0
	tele_caps = [0.85, 0.7, 0.6]
	max_health *= HP_MULT
	current_health = max_health
	_emit_health()
	_channels_total = 2
	_channels_left = 2
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	BossAnimator.attach(self)  # solo actua si el SpriteFrames trae cuadros nuevos


func _attack_pool() -> Array:
	var pool: Array
	match current_phase:
		1:
			pool = [&"atk_fan", &"atk_ondas", &"atk_huevos"]
		2:
			pool = [&"atk_ondas", &"atk_foliculos", &"atk_huevos", &"atk_fan"]
		_:
			pool = [&"atk_ondas", &"atk_foliculos", &"atk_huevos", &"atk_foliculos"]
	if _eggs_open > 0:
		pool = pool.filter(func(x): return x != &"atk_huevos")
	return pool


func _challenges() -> Array:
	return [&"ch_guardian", &"ch_clones", &"ch_velas"]


func _channel_color() -> Color:
	return PINK


func _on_phase(n: int) -> void:
	_drop_shield()
	_eggs_open = 0
	move_speed = BASE_SPEED[n - 1]
	_egg_t = 6.0


func _on_death() -> void:
	_drop_shield()


func _drop_shield() -> void:
	invuln = false
	if is_instance_valid(_shield):
		_shield.queue_free()
	_shield = null


## Toda zona que hace dano se ve como peligro (borde rojo oscuro), no como las marcas inofensivas.
func _add_hazard(z: BossZone) -> BossZone:
	if z.style == BossZone.Style.NORMAL and z.damage > 0.0:
		z.style = BossZone.Style.TOXIC
	return super(z)


func _tick(delta: float) -> void:
	if invuln and _eggs_open <= 0:
		_drop_shield()
	if state in [State.INTRO, State.TRANSITION, State.DEAD] or target == null:
		return
	_hatch_warnings()
	# huevo suelto mientras camina (fase 2+): presion sin pausa
	if current_phase >= 2 and state == State.IDLE and not _channeling and _eggs_open == 0:
		_egg_t -= delta
		if _egg_t <= 0.0:
			_egg_t = 11.0 - current_phase * 1.5
			var pts := _pick_egg_points(1)
			if not pts.is_empty():
				_place_eggs(pts, false)
				Sound.play("enemy_shoot")


## Aviso de eclosion: en el ultimo segundo el huevo marca el estallido y avisa con texto.
func _hatch_warnings() -> void:
	for n in get_tree().get_nodes_in_group("boss_breakable"):
		if not (n is BossBreakable) or n.kind != BossBreakable.Kind.EGG or n.life < 0.0 or not n.is_alive():
			continue
		if n.has_meta("hatch_warned") or n.remaining() > HATCH_WARN:
			continue
		n.set_meta("hatch_warned", true)
		var z := BossZone.circle(n.global_position, 62.0, maxf(n.remaining(), 0.1), 0.2, damage * 0.5, PINK)
		_add_hazard(z)
		_float_text(tr("OVA_HATCH"), Color("ff6a8a"), n.global_position - global_position + Vector2(0, -50))


# ---------------------------------------------------------------- huevos
func _pick_egg_points(n: int) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var tries := 0
	while pts.size() < n and tries < 60:
		tries += 1
		var p := arena_point(90.0)
		if p.distance_to(global_position) < 150.0 or p.distance_to(target.global_position) < 90.0:
			continue
		if pts.any(func(q): return q.distance_to(p) < 130.0):
			continue
		pts.append(p)
	return pts


func _place_eggs(pts: Array[Vector2], with_shield: bool) -> void:
	_eggs_hatched = 0
	_eggs_broken = 0
	for p in pts:
		var e := BossBreakable.new()
		e.kind = BossBreakable.Kind.EGG
		e.enemy_name = "Huevo"
		e.max_health = 14.0 + _floor * 3.0
		e.life = 8.0 - current_phase * 0.7
		e.color = PINK
		_spawn_container().add_child(e)
		e.global_position = p
		e.broken.connect(_on_egg_broken)
		e.expired.connect(_on_egg_expired)
		_eggs_open += 1
	if with_shield and _eggs_open > 0:
		_raise_shield()


func atk_huevos() -> void:
	var pts := _pick_egg_points(1 + current_phase)
	for p in pts:
		_add_hazard(BossZone.circle(p, 36.0, 0.8, 0.05, 0.0, PINK))
	if not await _tele(0.8, Color(2.0, 1.2, 1.6), 2.0):
		return
	Sound.play("enemy_shoot")
	var shielded := current_phase >= 2
	_place_eggs(pts, shielded)
	# Con escudo no hay ventana: la ventana la abres tu rompiendo los huevos.
	if not shielded:
		_tire(0.9)


func _raise_shield() -> void:
	invuln = true
	if is_instance_valid(_shield):
		_shield.queue_free()
	_shield = BossZone.circle(global_position, 100.0, 0.0, -1.0, 0.0, Color(1.0, 0.6, 0.85))
	_shield.style = BossZone.Style.SHIELD
	_shield.follow = self
	_shield.follow_offset = Vector2(0, -60)
	_add_hazard(_shield)
	_float_text(tr("BOSS_OVA_CYCLE"), PINK)


func _on_egg_broken(_e: BossBreakable) -> void:
	_eggs_open -= 1
	_eggs_broken += 1
	if _eggs_open <= 0:
		var had_shield := invuln
		_drop_shield()
		if had_shield and state != State.DEAD and state != State.TRANSITION:
			_float_text(tr("BOSS_OVA_STUN"), Color("ffe08a"))
			_stun(2.3)


func _on_egg_expired(e: BossBreakable) -> void:
	_eggs_open -= 1
	_eggs_hatched += 1
	# Eclosiona: una cria por huevo que no rompiste (dos en la fase 3), con tope.
	var spots: Array = [e.global_position]
	if current_phase >= 3:
		spots.append(e.global_position + Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * 36.0)
	_spawn_minions(spots, 12.0 + _floor * 2.0, 5.0 + _floor * 1.5, tr("CRIA_NAME"), CRIA)
	HitFx.shake(0.25)
	Sound.play("crack")
	if _eggs_open <= 0:
		_drop_shield()


# ---------------------------------------------------------------- ondas
func atk_ondas() -> void:
	if not await _walk_to(arena().get_center(), 1.2):
		return
	var rings := 2 + mini(current_phase, 2)
	var halo := BossZone.circle(global_position, 170.0, 0.8, 0.05, 0.0, PINK)
	halo.follow = self
	_add_hazard(halo)
	if not await _tele(0.8, Color(2.0, 1.2, 1.6), 2.5):
		return
	var gap_a := (target.global_position - global_position).angle()
	var shift := 0.45 * (1.0 if RNG.randf() < 0.5 else -1.0)
	for i in rings:
		var n := 40
		for k in n:
			var a := k * TAU / n
			if absf(angle_difference(a, gap_a)) < 0.34 or absf(angle_difference(a, gap_a + PI)) < 0.34:
				continue
			var b := _fire(a, 190.0, 0.6, PINK)
			b.scale = Vector2(1.2, 1.2)
		Sound.play("enemy_shoot")
		gap_a += shift
		if not await _wait(0.8):
			return
	if not await _wait(1.0):
		return
	_tire(1.3)


# ---------------------------------------------------------------- foliculos
func atk_foliculos() -> void:
	var n := 1 + current_phase
	if not await _tele(0.55, Color(2.0, 1.2, 1.6)):
		return
	for i in n:
		var z := BossZone.circle(clamp_to_arena(target.global_position, 40.0), 72.0, 0.85, 0.25, damage, PINK)
		z.went_active.connect(func():
			HitFx.shake(0.2)
			Sound.play("crack"))
		_add_hazard(z)
		if not await _wait(0.48 - 0.04 * current_phase):
			return
	if not await _wait(1.0):
		return


# ---------------------------------------------------------------- desafios de la cura
## GUARDIAN: un Ovulo Real grande, con su propia barra, la cubre mientras se regenera.
## Matarlo corta la cura.
func ch_guardian() -> void:
	var dirv: Vector2 = (target.global_position - global_position).normalized()
	var e := BossBreakable.new()
	e.kind = BossBreakable.Kind.EGG
	e.enemy_name = "Óvulo Real"
	e.max_health = max_health * 0.09
	e.life = -1.0
	e.show_bar = true
	e.color = PINK
	e.scale = Vector2(2.3, 2.3)
	var st := {"shoot": 1.2}
	e.tick_cb = func(n, dt):
		var dv: Vector2 = (target.global_position - global_position).normalized()
		n.global_position = n.global_position.move_toward(global_position + dv * 160.0, 90.0 * dt)
		st.shoot -= dt
		if st.shoot <= 0.0:
			st.shoot = 2.0
			for k in 8:
				_fire_from(n.global_position + Vector2(0, -24), k * TAU / 8.0 + n.get_instance_id() % 5, 180.0, 0.45, PINK, 5.0)
			Sound.play("enemy_shoot")
	e.broken.connect(func(_b): _chan_ok = true)
	_spawn_container().add_child(e)
	e.global_position = global_position + dirv * 160.0
	bot_target_node = e
	await _ch_loop(12.0, func(dt):
		_flee(75.0, dt)
		if is_instance_valid(e):
			_chan_prog = 1.0 - clampf(e.current_health / e.max_health, 0.0, 1.0))


func ch_clones() -> void:
	await _ch_clones(3)


## VELAS: tres braseros apagados; hay que quedarse sobre cada uno hasta que prenda.
func ch_velas() -> void:
	var pts: Array[Vector2] = []
	var tries := 0
	while pts.size() < 3 and tries < 80:
		tries += 1
		var p := arena_point(100.0)
		if p.distance_to(global_position) < 150.0 or pts.any(func(q): return q.distance_to(p) < 190.0):
			continue
		pts.append(p)
	var braziers: Array = []
	for p in pts:
		var b := _make_prop(p, Callable(), Callable(), {"lit": 0.0, "on": false})
		b.drawer = func(n):
			var lit: float = n.data.lit
			n.draw_circle(Vector2(0, -4), 30.0, Color(1, 1, 1, 0.14))
			n.draw_arc(Vector2(0, -4), 30.0, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 2.0)
			n.draw_circle(Vector2(0, -8), 20.0, Color(0.25, 0.2, 0.2))
			n.draw_arc(Vector2(0, -8), 20.0, 0.0, TAU, 24, Color(0.8, 0.8, 0.8), 3.0)
			if n.data.on:
				var fl := 0.8 + 0.2 * sin(n.t * 18.0)
				n.draw_colored_polygon(PackedVector2Array([Vector2(-12, -10), Vector2(0, -44 * fl), Vector2(12, -10)]), Color(1.0, 0.8, 0.25))
				n.draw_colored_polygon(PackedVector2Array([Vector2(-6, -10), Vector2(0, -28 * fl), Vector2(6, -10)]), Color(1.0, 0.98, 0.7))
			else:
				n.draw_arc(Vector2(0, -8), 30.0, -PI * 0.5, -PI * 0.5 + TAU * lit, 32, Color(1.0, 0.85, 0.3), 5.0)
		b.updater = func(n, dt):
			if n.data.on:
				return
			var near := target.global_position.distance_to(n.global_position) < 54.0
			n.data.lit = clampf(n.data.lit + (dt if near else -dt * 0.6), 0.0, 1.0)
			if n.data.lit >= 1.0:
				n.data.on = true
				var l := LightKit.make_light(Color(1.0, 0.7, 0.3), 1.1, 1.6, false)
				n.add_child(l)
				Sound.play("pickup")
		braziers.append(b)
	await _ch_loop(11.0, func(_dt):
		var total := 0.0
		var best: Variant = null
		var best_d := 1.0e9
		var all_on := true
		for b in braziers:
			if not is_instance_valid(b):
				continue
			total += 1.0 if b.data.on else b.data.lit
			if not b.data.on:
				all_on = false
				var dd: float = b.global_position.distance_to(target.global_position)
				if dd < best_d:
					best_d = dd
					best = b.global_position
		_chan_prog = total / maxf(braziers.size(), 1)
		bot_goal_pos = best
		if all_on:
			_chan_ok = true)
