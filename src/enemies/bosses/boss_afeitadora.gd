extends BossAltBase

## LA AFEITADORA ELECTRICA (alternativo de la Selva Pubica, reino 1) - MOTOR DINAMICO (dynamic = true).
## Cabezal oscilante, cable al enchufe y cero paciencia con todo lo que crece.
## IDENTIDAD: ZIGZAG. Embiste en tramos que REBOTAN en los muros, cada tramo mas rapido que el
## anterior (y curvandose un poco hacia ti), y deja tras cada tramo una PASADA de cuchilla: una
## franja con borde rojo oscuro que sigue cortando unos segundos (maximo 5 vivas a la vez).
## - PRESION: se acerca y te corta el paso; chispa suelta con aviso (0,6 s) mientras camina.
## - ATAQUES: rapado a franjas, cuchillas (te persigue girando), recorte a presion (anillo de pelusa
##   con hueco), abanico, PELUSAS y ZIGZAG (la firma). Combos de 1-2 ataques ligeros en fase 2-3.
##   Agotada solo tras sus ataques grandes (zigzag y cuchillas).
## - ESBIRROS: pelusas estaticas (enemy_pelusa_estatica.gd): se erizan y descargan en anillo.
## - CURA (max 2): DESENCHUFAR. Tres enchufes en la sala, de uno en uno.

const STEEL := Color(0.62, 0.82, 1.0)
const PASS_COL := Color(0.72, 0.2, 0.2)
const PELUSA := preload("res://src/enemies/enemy_pelusa_estatica.tscn")
const BIG := [&"atk_zigzag", &"atk_cuchillas"]
const MAX_PASSES := 5
const HP_MULT := 0.7
const PELUSA_CAP := [2, 3, 5]

var _aim := Vector2.RIGHT
var _passes: Array = []
var _spark_t := 3.5
var _spark_warn := 0.0


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = STEEL
	rest_min = 0.4
	rest_max = 0.75
	bullet_speed = 290.0
	tele_caps = [0.85, 0.7, 0.6]
	move_speed = 100.0
	keep_min = 120.0
	keep_max = 190.0
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
			return [&"atk_fan", &"atk_barrido", &"atk_zigzag", &"atk_pelusas", &"atk_cuchillas"]
		2:
			return [&"atk_barrido", &"atk_cuchillas", &"atk_recorte", &"atk_zigzag", &"atk_pelusas", &"atk_fan"]
	return [&"atk_zigzag", &"atk_zigzag", &"atk_barrido", &"atk_cuchillas", &"atk_recorte", &"atk_pelusas", &"atk_fan"]


func _challenges() -> Array:
	return [&"ch_enchufes"]


func _channel_color() -> Color:
	return STEEL


func _on_phase(n: int) -> void:
	move_speed = [100.0, 120.0, 140.0][n - 1]


func _hit_source() -> String:
	for g in get_tree().get_nodes_in_group("pelusa_estatica"):
		if is_instance_valid(g) and g.global_position.distance_to(target.global_position) < EnemyPelusaEstatica.RING_R + 20.0:
			return "pelusa"
	for z in _passes:
		if is_instance_valid(z) and z.is_active() and z.contains(target.global_position):
			return "pasada"
	return "cuchilla"


## Todo peligro de la Afeitadora se dibuja como maquina (rayas oscuras, borde rojo; nunca blanco).
func _add_hazard(z: BossZone) -> BossZone:
	if z.style == BossZone.Style.NORMAL:
		z.style = BossZone.Style.TOXIC
	return super(z)


func _combo_len() -> int:
	match current_phase:
		2:
			return RNG.randi_range(0, 1)
		3:
			return RNG.randi_range(1, 2)
	return 0


func _combo_next() -> StringName:
	var light: Array = [&"atk_fan", &"atk_barrido", &"atk_pelusas"]
	if current_phase >= 2:
		light.append(&"atk_recorte")
	light = light.filter(func(x): return x != _last_attack)
	return light[RNG.randi_range(0, light.size() - 1)]


func _pick_attack() -> StringName:
	var a := super()
	if a in BIG:
		_combo_left = 0
	return a


func _reset_idle() -> void:
	_spark_warn = 0.0


func _cure_cut_stun() -> float:
	return 5.0


## Donde estara el heroe cuando llegue una bala de velocidad `spd` (prediccion corta).
func _lead(spd: float, k := 0.8) -> Vector2:
	var p: Vector2 = target.global_position
	var v := Vector2.ZERO
	if target is CharacterBody2D:
		v = (target as CharacterBody2D).velocity
	return p + v * minf(p.distance_to(_muzzle()) / spd, 0.8) * k


## Chispa suelta mientras camina: parpadea 0,6 s y sale rapida hacia donde vas.
func _tick(delta: float) -> void:
	if state != State.IDLE or _channeling or target == null:
		return
	if _spark_warn > 0.0:
		_spark_warn -= delta
		animated_sprite.modulate = Color(1.6, 1.9, 2.3) if int(_spark_warn * 24.0) % 2 == 0 else Color.WHITE
		if _spark_warn <= 0.0:
			animated_sprite.modulate = Color.WHITE
			_fire((_lead(340.0) - _muzzle()).angle(), 340.0, 0.5, STEEL)
			Sound.play("enemy_shoot")
			_spark_t = RNG.randf_range(3.8, 5.2) / (1.0 + 0.2 * (current_phase - 1))
	else:
		_spark_t -= delta
		if _spark_t <= 0.0:
			_spark_warn = 0.6


# ---------------------------------------------------------------- ZIGZAG (identidad)
## Tramos de embestida que rebotan en los muros, cada uno mas rapido. El primero te apunta (0,8 s de
## aviso con franja roja); cada rebote fija el siguiente tramo y lo muestra 0,55 s antes de salir.
## Tras cada tramo deja una pasada de cuchilla. Agotada al final.
func atk_zigzag() -> void:
	var legs := 2 + current_phase
	_aim = (_lead(400.0) - global_position).normalized()
	for s in legs:
		var first := s == 0
		var body := global_position + Vector2(0, -50)
		var len := _ray_len(body, _aim, 900.0)
		var lane := BossZone.rect(body + _aim * len * 0.5, Vector2(len, 70.0), _aim.angle(), 3.0, 0.05, 0.0, Color(0.95, 0.3, 0.25))
		_add_hazard(lane)
		var track := func(left: float):
			if first and left > 0.25:
				_aim = (target.global_position - global_position).normalized()
			var b := global_position + Vector2(0, -50)
			var l := _ray_len(b, _aim, 900.0)
			if is_instance_valid(lane):
				lane.size.x = maxf(l, 40.0)
				lane.global_position = b + _aim * lane.size.x * 0.5
				lane.rotation = _aim.angle()
		if not await _tele(0.8 if first else 0.55, Color(1.0, 1.6, 2.2), 3.0, track):
			return
		if is_instance_valid(lane):
			lane.dismiss()
		Sound.play("dash")
		_hit_done = false
		var start := global_position
		var spd := minf(380.0 + s * 75.0 + current_phase * 25.0, 660.0)
		var t := 0.0
		var bounced := false
		while t < 1.5:
			velocity = _aim * spd
			if not await _frame():
				return
			_strike()
			t += 1.0 / 60.0
			if get_slide_collision_count() > 0:
				var n := get_last_slide_collision().get_normal()
				_aim = _aim.bounce(n).normalized()
				var mixed := _aim.slerp((target.global_position - global_position).normalized(), 0.3).normalized()
				if mixed.dot(n) > 0.25:
					_aim = mixed
				bounced = true
				break
		velocity = Vector2.ZERO
		_leave_pass(start, global_position)
		HitFx.shake(0.25)
		Sound.play("crack")
		if not bounced:
			break
	_tire(1.6)


## Pasada de cuchilla: franja con aviso (0,5 s) que luego corta ~2,4 s. Maximo MAX_PASSES vivas.
func _leave_pass(a: Vector2, b: Vector2) -> void:
	var len := a.distance_to(b)
	if len < 40.0:
		return
	_passes = _passes.filter(func(z): return is_instance_valid(z))
	while _passes.size() >= MAX_PASSES:
		var old: BossZone = _passes.pop_front()
		old.dismiss()
	var dir := (b - a).normalized()
	var z := BossZone.rect((a + b) * 0.5 + Vector2(0, -50), Vector2(len, 28.0), dir.angle(), 0.5, 2.4, damage * 0.5, PASS_COL)
	z.one_hit = false
	z.fade = 0.5
	_add_hazard(z)
	_passes.append(z)


## PELUSAS: invoca mechones estaticos (pocos en fase 1, mas en la 3). Con el tope lleno, tira abanico.
func atk_pelusas() -> void:
	var room_left: int = PELUSA_CAP[current_phase - 1] - get_tree().get_nodes_in_group("pelusa_estatica").size()
	var n := mini(current_phase + (1 if current_phase == 3 else 0), room_left)
	if n <= 0:
		await atk_fan()
		return
	var spots: Array = []
	for i in n:
		spots.append(clamp_to_arena(global_position + Vector2.RIGHT.rotated(RNG.randf() * TAU) * RNG.randf_range(110.0, 220.0), 70.0))
	for p in spots:
		_add_hazard(BossZone.circle(p, 34.0, 0.6, 0.05, 0.0, STEEL))
	if not await _tele(0.6, Color(1.0, 1.6, 2.2), 2.0):
		return
	_spawn_minions(spots, 14.0, damage * 0.5, tr("ENEMY_PELUSA_NAME"), PELUSA)
	_float_text(tr("AFEI_PELUSAS"), STEEL)
	Sound.play("suck")
	await _wait(0.4)


# ---------------------------------------------------------------- ataques
## Franjas de lado a lado: todas pegan menos 1-2 pasillos (los que no se tiñen).
func atk_barrido() -> void:
	var a := arena()
	var horiz := RNG.randf() < 0.5
	var span := a.size.y if horiz else a.size.x
	var n := maxi(int(span / 96.0), 4)
	var w := span / n
	var safe: Array = [RNG.randi_range(0, n - 1)]
	if current_phase == 1:
		safe.append(clampi(safe[0] + (1 if safe[0] < n - 1 else -1), 0, n - 1))
	else:
		var other := RNG.randi_range(0, n - 1)
		if absi(other - safe[0]) > 1:
			safe.append(other)
		else:
			safe.append(clampi(safe[0] + (3 if safe[0] < n - 3 else -3), 0, n - 1))
	var warn := 1.2 - 0.1 * current_phase
	for i in n:
		if i in safe:
			continue
		var lane: BossZone
		if horiz:
			lane = BossZone.rect(Vector2(a.get_center().x, a.position.y + (i + 0.5) * w), Vector2(a.size.x, w - 6.0), 0.0, warn, 0.45, damage * 0.9, Color(0.5, 0.8, 1.0))
		else:
			lane = BossZone.rect(Vector2(a.position.x + (i + 0.5) * w, a.get_center().y), Vector2(a.size.y, w - 6.0), PI * 0.5, warn, 0.45, damage * 0.9, Color(0.5, 0.8, 1.0))
		_add_hazard(lane)
	if not await _tele(warn - 0.1, Color(1.0, 1.6, 2.2), 2.5):
		return
	Sound.play("crack")
	await _wait(0.6)


## Se enciende y te persigue con dos cuchillas que giran a su alrededor.
func atk_cuchillas() -> void:
	var reach := 210.0
	var ring := BossZone.circle(global_position, reach, 0.9, 0.05, 0.0, STEEL)
	ring.follow = self
	_add_hazard(ring)
	if not await _tele(0.9, Color(1.0, 1.6, 2.2), 3.0):
		return
	var sp := 2.7 * (1.0 if RNG.randf() < 0.5 else -1.0)
	for k in 2:
		var z := BossZone.rect(global_position, Vector2(reach * 2.0, 34.0), k * PI * 0.5, 0.0, 2.5, damage * 0.5, Color(0.7, 0.9, 1.0))
		z.spin = sp
		z.follow = self
		z.follow_offset = Vector2(0, -50)
		z.one_hit = false
		z.fade = 0.3
		_add_hazard(z)
	Sound.play("suck")
	var t := 0.0
	while t < 2.5:
		velocity = (target.global_position - global_position).normalized() * move_speed * 1.5
		if not await _frame():
			return
		t += 1.0 / 60.0
	velocity = Vector2.ZERO
	_tire(1.5)


## Anillo de pelusa. Fase 1: el hueco esta justo hacia ti; despues, desplazado.
func atk_recorte() -> void:
	var warn := BossZone.circle(global_position, 120.0, 0.7, 0.05, 0.0, STEEL)
	warn.follow = self
	_add_hazard(warn)
	if not await _tele(0.7, Color(1.0, 1.6, 2.2), 2.0):
		return
	var rings := current_phase
	for r in rings:
		var to_t: float = (target.global_position - _muzzle()).angle()
		var gap_at := to_t if current_phase == 1 else to_t + RNG.randf_range(0.9, 2.2) * (1.0 if RNG.randf() < 0.5 else -1.0)
		_fire_ring(16 + current_phase * 3, 250.0 + r * 40.0, r * 0.2, gap_at, 0.9, 0.6, STEEL)
		Sound.play("enemy_shoot")
		if r < rings - 1 and not await _wait(0.7):
			return
	await _wait(0.4)


# ---------------------------------------------------------------- desafio de la cura
## ENCHUFES: tres enchufes en la sala, de uno en uno. Tocalos todos para cortarle la corriente.
func ch_enchufes() -> void:
	await _ch_touch(_spread_points(3), "plug", {"ordered": true, "reveal_one": true, "limit": 11.0})
