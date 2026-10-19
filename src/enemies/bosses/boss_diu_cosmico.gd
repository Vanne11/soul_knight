extends BossAltBase

## EL DIU COSMICO (alternativo de Vulvania, reino 3) - usa el MOTOR DINAMICO (dynamic = true).
## Una T de cobre que orbita, con hilos y mucha paciencia: lleva anos alli arriba y ahora, ademas,
## quiere que todo gire a su alrededor. IDENTIDAD (una sola mecanica propia): GRAVEDAD + ORBITAS.
## - GRAVEDAD: cada pocos segundos avisa (anillo violeta, "¡GRAVEDAD!"), y durante unos segundos
##   te ATRAE hacia el (mas despacio de lo que caminas: puedes avanzar contra ella, pero cuesta).
##   El campo se ve (anillos que se cierran hacia el); un DASH te deja salir de el, y fuera del
##   anillo no tira. Si te dejas arrastrar hasta el NUCLEO, te aplasta en goteo. No tira mientras
##   hace brazos o supernova (seria injusto) ni cuando esta agotado.
## - ORBITAS: bolas de cobre que giran a su alrededor mientras el camina hacia ti con ellas, y las
##   suelta de una en una hacia ti. En fase 3, dos anillos en sentidos opuestos. La gravedad te
##   mete en ellas: aprende a salirte antes.
## - SATELITES (esbirros): lunas de cobre que orbitan al jefe y se sueltan en picadas con aviso.
##   Mientras viven, su gravedad tira mas. Fase 1: pocos; fase 3: hasta 5. Matarlos suelta corazones.
## - AGOTADO tras brazos, supernova y orbitas. Avisos >= 0,55 s. Combos en fase 2-3.
## - Pasivo: chispa de cobre suelta con aviso corto (parpadeo 0,45 s) mientras camina.
## Cura (2 cargas): CONSTELACION, ECLIPSE (escudo con hueco que gira), COMETA. Mientras canaliza
## suelta satelites que la defienden.

const COPPER := Color(1.0, 0.6, 0.3)
const VIOLET := Color(0.75, 0.5, 1.0)
const SAT := preload("res://src/enemies/enemy_satelite_cobre.tscn")
const HP_MULT := 0.7
const FIELD_R := 380.0                 ## radio del campo de gravedad (anillo visible)
const PULL_SPEED := 175.0              ## px/s: menos que caminar (250), asi que se puede avanzar contra ella
const CYCLE := [7.5, 6.0, 5.0]         ## segundos entre gravedades, por fase
const PULL_SECS := [1.8, 2.2, 2.6]
const GRAV_WARN := 0.85
const CORE_R := 80.0
const SAT_CAP := [2, 3, 5]
const WAVE := [16.0, 12.0, 9.0]

var _g := 0                            ## 0 reposo, 1 aviso, 2 tira
var _g_t := 5.0
var _core_t := 0.0
var _field: GravityField = null
var _wave_t := 9.0
var _def_t := 1.5
var _spit_t := 3.5
var _spit_warn := 0.0
var _sat_hold := false                 ## el campo se apaga a ratos (ver _gravity_allowed)


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = VIOLET
	keep_min = 140.0
	keep_max = 230.0
	rest_min = 0.45
	rest_max = 0.8
	bullet_speed = 300.0
	tele_caps = [0.85, 0.7, 0.6]
	move_speed = 110.0
	max_health *= HP_MULT
	current_health = max_health
	_emit_health()
	_channels_total = 2
	_channels_left = 2
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	BossAnimator.attach(self, true)  # arte actual (40x60): animacion por codigo, sin cuadros nuevos


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_hilos", &"atk_orbitas", &"atk_meteoros", &"atk_fan"]
		2:
			return [&"atk_hilos", &"atk_brazos", &"atk_orbitas", &"atk_meteoros", &"atk_fan", &"atk_charge"]
	return [&"atk_hilos", &"atk_brazos", &"atk_orbitas", &"atk_orbitas", &"atk_supernova", &"atk_meteoros", &"atk_fan", &"atk_charge"]


func _combo_next() -> StringName:
	var light: Array = [&"atk_fan", &"atk_meteoros", &"atk_hilos"]
	if current_phase >= 2:
		light.append(&"atk_orbitas")
	light = light.filter(func(x): return x != _last_attack)
	return light[RNG.randi_range(0, light.size() - 1)]


func _challenges() -> Array:
	return [&"ch_constelacion", &"ch_eclipse", &"ch_cometa"]


func _channel_color() -> Color:
	return COPPER


func _on_phase(n: int) -> void:
	move_speed = [110.0, 130.0, 150.0][n - 1]
	_g = 0
	_g_t = 2.5
	_wave_t = 3.0
	if is_instance_valid(_field):
		_field.mode = 0
	if n >= 2:
		_float_text(tr("DIU_PHASE_%d" % n), VIOLET)


func _on_death() -> void:
	if is_instance_valid(_field):
		_field.queue_free()
	_kill_satellites()


func _hit_source() -> String:
	if _g == 2 and target != null and target.global_position.distance_to(global_position) < CORE_R + 20.0:
		return "nucleo"
	for s in get_tree().get_nodes_in_group("satelite_cobre"):
		if is_instance_valid(s) and s.global_position.distance_to(target.global_position) < 60.0:
			return "satelite"
	return "gravedad" if _g == 2 else "pasivo/reposo"


## Toda zona de peligro del DIU se dibuja como cobre/plasma fundido (estilo WAX con paleta propia).
func _add_hazard(z: BossZone) -> BossZone:
	if z.style == BossZone.Style.NORMAL:
		z.style = BossZone.Style.WAX
		z._hot = z.color
		z._core = z.color.lightened(0.4)
		z._edge = z.color.darkened(0.7)
	return super(z)


func _ts(x: float) -> float:
	return minf(x, tele_caps[clampi(current_phase, 1, 3) - 1])


func _sat_count() -> int:
	return get_tree().get_nodes_in_group("satelite_cobre").size()


func _kill_satellites() -> void:
	for s in get_tree().get_nodes_in_group("satelite_cobre"):
		if is_instance_valid(s) and s.has_method("take_damage"):
			s.take_damage(9999.0, self)


# ---------------------------------------------------------------- pasivos: gravedad, satelites, chispa
func _tick(delta: float) -> void:
	if state in [State.INTRO, State.DEAD] or target == null:
		return
	if state == State.TRANSITION:
		return
	_gravity(delta)
	_wave_logic(delta)
	_spit_logic(delta)


## Se permite tirar solo cuando no seria injusto: ni con brazos/supernova, ni agotado, ni canalizando.
func _gravity_allowed() -> bool:
	if _channeling or state == State.TIRED:
		return false
	if state == State.ATTACK and _last_attack in [&"atk_brazos", &"atk_supernova"]:
		return false
	return true


func _gravity(delta: float) -> void:
	if _field == null or not is_instance_valid(_field):
		_field = GravityField.new()
		_field.boss = self
		_field.show_behind_parent = true
		add_child(_field)
		_field.position = Vector2(0, -40)
	if not _gravity_allowed():
		if _g != 0:
			_g = 0
			_g_t = 2.0
			_field.mode = 0
		return
	var ph := clampi(current_phase, 1, 3) - 1
	_g_t -= delta
	var tp: Vector2 = target.global_position
	var center := _muzzle() + Vector2(0, 10)
	match _g:
		0:
			if _g_t <= 0.0:
				if tp.distance_to(center) < FIELD_R + 60.0:
					_g = 1
					_g_t = GRAV_WARN
					_field.mode = 1
					_float_text(tr("DIU_GRAVITY"), VIOLET)
					Sound.play("suck")
				else:
					_g_t = 1.0  # estas lejos: no gasta la gravedad en el aire
		1:
			if _g_t <= 0.0:
				_g = 2
				_g_t = PULL_SECS[ph]
				_field.mode = 2
				_core_t = 0.4
				_float_text(tr("DIU_GRAVITY_TIP"), Color("ffe08a"), Vector2(0, -135))
		2:
			var d := tp.distance_to(center)
			var dashing := bool(target.get("is_dashing"))
			if not dashing and d < FIELD_R and d > 30.0 and target is CharacterBody2D:
				var k := 1.0 + (0.25 if _sat_count() > 0 else 0.0) + 0.1 * (current_phase - 1)
				(target as CharacterBody2D).move_and_collide((center - tp).normalized() * PULL_SPEED * k * delta)
			if d < CORE_R and not dashing:
				_core_t -= delta
				if _core_t <= 0.0:
					_core_t = 0.8
					target.receive_hit(damage * 0.5)
					_float_text(tr("DIU_CORE_CRUSH"), COPPER, Vector2(0, -135))
					HitFx.shake(0.25)
			if _g_t <= 0.0:
				_g = 0
				_g_t = CYCLE[ph]
				_field.mode = 0


func _wave_logic(delta: float) -> void:
	_wave_t -= delta
	if _wave_t > 0.0:
		return
	var ph := clampi(current_phase, 1, 3) - 1
	_wave_t = WAVE[ph]
	if _channeling:
		_wave_t = 5.0
	var n := mini(2, SAT_CAP[ph] - _sat_count())
	if n > 0:
		_summon(n)


func _summon(n: int) -> void:
	var spots: Array = []
	var a0 := RNG.randf_range(0.0, TAU)
	for i in n:
		var p := clamp_to_arena(global_position + Vector2.RIGHT.rotated(a0 + i * TAU / n) * 120.0, 60.0)
		spots.append(p)
		_add_hazard(BossZone.circle(p, 26.0, 0.7, 0.05, 0.0, COPPER))
	await get_tree().create_timer(0.75, true, true).timeout
	if state == State.DEAD or not is_inside_tree():
		return
	var made := _spawn_minions(spots, 12.0 + 3.0 * current_phase, damage * 0.45, tr("DIU_SATELLITE"), SAT)
	for m in get_tree().get_nodes_in_group("satelite_cobre"):
		if is_instance_valid(m):
			m.move_speed = 140.0 + 10.0 * current_phase
			m.add_collision_exception_with(self)
	if made > 0:
		Sound.play("enemy_shoot")


## Chispa suelta con aviso corto, solo en reposo (en ataque ya tiene sus avisos).
func _spit_logic(delta: float) -> void:
	if state != State.IDLE or _channeling:
		_spit_warn = 0.0
		return
	if _spit_warn > 0.0:
		_spit_warn -= delta
		animated_sprite.modulate = Color(2.2, 1.6, 0.9) if int(_spit_warn * 24.0) % 2 == 0 else Color.WHITE
		if _spit_warn <= 0.0:
			animated_sprite.modulate = Color.WHITE
			var spd := 310.0 + 20.0 * current_phase
			var tv := Vector2.ZERO
			if target is CharacterBody2D:
				tv = (target as CharacterBody2D).velocity
			var aim: Vector2 = target.global_position + tv * minf(target.global_position.distance_to(_muzzle()) / spd, 0.7) * 0.8
			_fire((aim - _muzzle()).angle(), spd, 0.5, COPPER)
			_spit_t = RNG.randf_range(4.0, 5.5) / (1.0 + 0.2 * (current_phase - 1))
		return
	_spit_t -= delta
	if _spit_t <= 0.0:
		_spit_warn = 0.45


## Defensa de la cura: suelta satelites (con tope) y se mueve despacio por el centro.
func _defend(dt: float) -> void:
	_def_t -= dt
	var a := arena()
	var c := a.get_center() + Vector2(sin(_chan_t * 0.7) * a.size.x * 0.2, cos(_chan_t * 0.5) * a.size.y * 0.16)
	velocity = (c - global_position).limit_length(55.0)
	if _def_t > 0.0:
		return
	_def_t = [3.4, 3.0, 2.6][clampi(current_phase, 1, 3) - 1]
	if _sat_count() < 3:
		_summon(1)
	else:
		var base := (target.global_position - _muzzle()).angle()
		for i in 3:
			_fire(base + (i - 1) * 0.22, 270.0, 0.5, VIOLET)


func _on_cure_cut() -> void:
	_kill_satellites()  # pierden la orbita
	_g = 0
	_g_t = CYCLE[clampi(current_phase, 1, 3) - 1]


func _on_cure_done() -> void:
	_g = 0
	_g_t = 1.0  # sube la gravedad: se curo y quiere cobrarse


# ---------------------------------------------------------------- ataques
## Barras de cobre que giran en sentidos opuestos; entran una cada 0.7 s.
func atk_brazos() -> void:
	if not await _walk_to(arena().get_center(), 1.0):
		return
	var reach := 290.0
	var c := _muzzle()
	var bars := 2 if current_phase < 3 else 3
	var w0 := _ts(0.9)
	for k in bars:
		var z := BossZone.rect(c, Vector2(reach * 2.0, 38.0), k * PI / bars, w0 + k * 0.6, 2.2, damage * 0.5, COPPER)
		z.spin = 0.7 * (1.0 if k % 2 == 0 else -1.0) * (1.0 + current_phase * 0.12)
		z.one_hit = false
		z.fade = 0.4
		_add_hazard(z)
	if not await _tele(0.9, Color(2.2, 1.5, 0.8), 2.5):
		return
	if not await _wait(2.2 + (bars - 1) * 0.6):
		return
	_tire(1.5)


## Abanico de hilos que te siguen y se tensan de golpe.
func atk_hilos() -> void:
	var offs: Array = [-0.42, 0.0, 0.42] if current_phase < 3 else [-0.7, -0.35, 0.0, 0.35, 0.7]
	var st := {"base": (target.global_position - _muzzle()).angle()}
	var warn := _ts(1.0) + 0.05
	var zs: Array = []
	for o in offs:
		zs.append(_add_hazard(BossZone.rect(_muzzle(), Vector2(500, 28), st.base + o, warn, 0.35, damage * 0.9, VIOLET)))
	var track := func(left: float):
		if left > 0.3:
			st.base = (target.global_position - _muzzle()).angle()
		for i in zs.size():
			var z = zs[i]
			if is_instance_valid(z):
				var d := Vector2.RIGHT.rotated(st.base + offs[i])
				var ln := _ray_len(_muzzle(), d, 640.0)
				z.size.x = ln
				z.global_position = _muzzle() + d * ln * 0.5
				z.rotation = d.angle()
	if not await _tele(1.0, Color(1.8, 1.2, 2.4), 2.0, track):
		return
	Sound.play("crack")
	if not await _wait(0.55):
		return
	_tire(0.5)


## Meteoros avisados por toda la sala; los dos primeros caen sobre ti.
func atk_meteoros() -> void:
	if not await _tele(0.4, Color(2.2, 1.5, 0.8)):
		return
	var n := 5 + current_phase * 2
	for i in n:
		var p: Vector2 = arena_point(60.0)
		if i < 2:
			p = target.global_position + Vector2(RNG.randf_range(-25, 25), RNG.randf_range(-25, 25))
		_add_hazard(BossZone.circle(clamp_to_arena(p, 50.0), 72.0, 0.8, 0.3, damage * 0.8, COPPER))
		Sound.play("enemy_shoot")
		if not await _wait(0.24):
			return
	if not await _wait(0.9):
		return
	_tire(0.5)


## Explosion enorme en el centro: sal al borde. Despues, anillo lento y agotado.
func atk_supernova() -> void:
	if not await _walk_to(arena().get_center(), 1.0):
		return
	var r := minf(arena().size.x, arena().size.y) * 0.38
	var warn := 1.3
	_add_hazard(BossZone.circle(global_position, r, warn, 0.5, damage * 1.1, COPPER))
	var tl := _ts(1.5)
	if not await _tele(1.5, Color(2.4, 1.6, 0.8), 3.5):
		return
	if not await _wait(maxf(0.05, warn - tl)):
		return
	Sound.play("crack")
	HitFx.shake(0.6)
	_fire_ring(18, 160.0, 0.0, 0.0, 0.0, 0.5, VIOLET)
	if not await _wait(0.6):
		return
	_tire(1.6)


## ORBITAS: bolas de cobre giran alrededor del jefe (que camina hacia ti con ellas) y las suelta de
## una en una hacia ti. Fase 3: dos anillos en sentidos opuestos.
func atk_orbitas() -> void:
	if not await _tele(0.6, Color(1.8, 1.2, 2.4), 2.0):
		return
	_float_text(tr("DIU_ORBITS"), VIOLET)
	var rings := 1 if current_phase < 3 else 2
	var per := 6 if current_phase == 1 else 7
	var spin := 2.4 + 0.25 * current_phase
	var bullets: Array = []  # cada uno: {p, ring, i, free}
	for rg in rings:
		for i in per:
			var p := _fire_from(_muzzle(), 0.0, 0.0, 0.45, COPPER if (i + rg) % 2 == 0 else VIOLET, 10.0)
			bullets.append({"p": p, "ring": rg, "i": i, "out": false})
	var ang := RNG.randf_range(0.0, TAU)
	var t := 0.0
	var hold := 1.6 + 0.1 * current_phase     # tiempo orbitando antes de empezar a soltar
	var gap := 0.13
	var total := hold + bullets.size() * gap + 0.2
	var dir := 1.0 if RNG.randf() < 0.5 else -1.0
	var next_i := 0
	while t < total:
		if not await _frame():
			_orbit_drop(bullets)
			return
		var dt := 1.0 / 60.0
		t += dt
		ang += spin * dt * dir
		var c := _muzzle()
		var grow := clampf(t / 0.5, 0.0, 1.0)
		for b in bullets:
			if b.out or not is_instance_valid(b.p):
				continue
			var rad: float = (112.0 if b.ring == 0 else 165.0) * grow
			var a2: float = (ang if b.ring == 0 else -ang * 0.8) + b.i * TAU / per
			b.p.global_position = c + Vector2.RIGHT.rotated(a2) * rad
		# camina hacia ti llevando las orbitas (presiona), sin llegar a pisarte
		var to_t: Vector2 = target.global_position - global_position
		velocity = to_t.normalized() * move_speed * 0.85 if to_t.length() > 150.0 else Vector2.ZERO
		# suelta una cada `gap` s, apuntando a ti con un poco de prediccion
		if t >= hold and next_i < bullets.size() and t >= hold + next_i * gap:
			var b = bullets[next_i]
			next_i += 1
			if is_instance_valid(b.p):
				b.out = true
				var spd := 330.0
				var tv := Vector2.ZERO
				if target is CharacterBody2D:
					tv = (target as CharacterBody2D).velocity
				var aim: Vector2 = target.global_position + tv * minf(target.global_position.distance_to(b.p.global_position) / spd, 0.6) * 0.7
				b.p.global_rotation = (aim - b.p.global_position).angle()
				b.p.speed = spd
				b.p._timer = 0.0
				b.p.lifetime = 4.0
	velocity = Vector2.ZERO
	_tire(0.9)


## Si cortan las orbitas (fase nueva), que las bolas salgan volando hacia fuera en vez de quedarse quietas.
func _orbit_drop(bullets: Array) -> void:
	for b in bullets:
		if not b.out and is_instance_valid(b.p):
			b.p.global_rotation = (b.p.global_position - _muzzle()).angle()
			b.p.speed = 220.0
			b.p.lifetime = 3.0
			b.p._timer = 0.0


# ---------------------------------------------------------------- desafios de la cura
## CONSTELACION: las estrellas se encienden de una en una; tocalas en orden.
func ch_constelacion() -> void:
	await _ch_touch(_spread_points(4, 150.0), "star", {"ordered": true, "reveal_one": true, "limit": 12.0})


## ECLIPSE: un escudo lo rodea con un hueco que gira. Dispara desde el lado del hueco.
func ch_eclipse() -> void:
	await _ch_weak({"hits": 4, "limit": 13.0})


## COMETA: un cometa cruza la sala. Alcanzalo.
func ch_cometa() -> void:
	await _ch_chase("comet", {"speed": 400.0, "limit": 8.0})


# ---------------------------------------------------------------- el campo de gravedad (se ve)
## Anillos violeta que se cierran hacia el jefe mientras tira; aviso = contorno que parpadea.
## Borde oscuro (peligro), nunca blanco.
class GravityField extends Node2D:
	var boss: Node2D = null
	var mode := 0  # 0 apagado, 1 aviso, 2 tirando
	var _t := 0.0
	var _fade := 0.0

	func _process(delta: float) -> void:
		_t += delta
		_fade = move_toward(_fade, 0.0 if mode == 0 else 1.0, delta * 3.0)
		queue_redraw()

	func _draw() -> void:
		if _fade <= 0.01:
			return
		var R: float = FIELD_R
		var edge := Color(0.28, 0.08, 0.5)
		var vio := Color(0.75, 0.5, 1.0)
		if mode == 1:
			var pulse := 0.5 + 0.5 * sin(_t * 20.0)
			draw_arc(Vector2.ZERO, R, 0.0, TAU, 72, Color(edge, (0.55 + 0.4 * pulse) * _fade), 4.0)
			draw_circle(Vector2.ZERO, R, Color(vio, 0.05 * _fade))
			return
		draw_circle(Vector2.ZERO, R, Color(vio, 0.07 * _fade))
		draw_arc(Vector2.ZERO, R, 0.0, TAU, 72, Color(edge, 0.9 * _fade), 4.0)
		for i in 4:
			var k := 1.0 - fposmod(_t * 0.9 + i * 0.25, 1.0)  # se cierran hacia el centro
			draw_arc(Vector2.ZERO, R * k, 0.0, TAU, 64, Color(vio, 0.45 * k * _fade), 3.0)
		for i in 10:
			var a := i * TAU / 10.0 + _t * 0.5
			var k2 := 1.0 - fposmod(_t * 0.9 + i * 0.1, 1.0)
			var p0 := Vector2.RIGHT.rotated(a) * R * k2
			var p1 := Vector2.RIGHT.rotated(a) * R * maxf(k2 - 0.08, 0.0)
			draw_line(p0, p1, Color(vio, 0.7 * _fade), 3.0)
		draw_arc(Vector2.ZERO, CORE_R, 0.0, TAU, 32, Color(0.5, 0.2, 0.1, 0.8 * _fade), 3.0)  # nucleo: aqui aplasta
