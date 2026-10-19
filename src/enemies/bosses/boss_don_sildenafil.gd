extends BossAltBase

## DON SILDENAFIL (alternativo de Penelandia, reino 2) - usa el MOTOR DINAMICO (dynamic = true).
## Pastilla azul con cuatro horas de aguante y cero sentido de la medida.
## IDENTIDAD "SUBIDON": un medidor visible sobre su cabeza sube solo mientras no le pegas
## (~16 s hasta el tope; el doble de rapido con pastillas vivas). Mas subidon = camina mas rapido,
## descansa menos, avisa mas corto (nunca bajo 0,55 s), dispara mas rapido y encadena un ataque
## mas. TU GOLPE LO BAJA (mas cuanto mas fuerte) y la sobredosis lo descarga a medias.
## - PRESION: se te pega al cuerpo y ademas suelta un "pastillazo" suelto (aviso 0,55 s) mientras camina.
## - ATAQUES: abanico, SUBIDON (2-3 embestidas avisadas), LLUVIA AZUL (circulos avisados),
##   SOBREDOSIS (fase 2+: salta, cae con onda y anillo de pastillas) y BLISTER (suelta pastillitas).
## - ESBIRROS: pastillitas azules (enemy_pastilla.gd): ruedan en linea y rebotan; ayudan a subir el
##   subidon; reventarlas lo baja y a veces sueltan corazon. 1 en fase 1, hasta 3 por tanda en la 3.
## Cura (2 cargas): ROMPE LAS PASTILLAS (5 que vagan) y TOMAR CON AGUA (mantente en el vaso).

const BLUE := Color(0.35, 0.65, 1.0)
const HP_MULT := 0.7
const PILL := preload("res://src/enemies/enemy_pastilla.tscn")
const RUSH_RISE := 1.0 / 16.0     ## subidon por segundo sin que le pegues
const BASE_SPEED := [120.0, 140.0, 160.0]
const BASE_CAPS := [0.85, 0.7, 0.6]
const TELE_FLOOR := 0.55

var _rush := 0.0          ## 0..1: el subidon
var _meter: SildenafilMeter = null
var _spit_t := 3.0
var _spit_warn := 0.0


func _ready() -> void:
	super()
	TemploAnubis.met_sildenafil()  # guiño del Frasquito Magico (templo_anubis.gd)
	dynamic = true
	fan_tint = BLUE
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
	_meter = SildenafilMeter.new()
	add_child(_meter)
	BossAnimator.attach(self)  # arte definitivo 176x184 (tools/gen_sildenafil_art.py): cuadros nuevos + animacion por codigo


## El golpe del ataque ocurre cuando termina el aviso: se avisa al animador para que pase de la pose de carga
## (attack_<x>) a la de golpe (release_<x>) justo en ese momento.
func _tele(secs: float, col := Color(2.0, 2.0, 0.9), shake := 2.0, on_frame := Callable()) -> bool:
	var ok: bool = await super(secs, col, shake, on_frame)
	if ok:
		attack_released.emit(_last_attack)
	return ok


func _attack_pool() -> Array:
	var pool: Array
	match current_phase:
		1:
			pool = [&"atk_fan", &"atk_subidon", &"atk_lluvia", &"atk_blister"]
		2:
			pool = [&"atk_fan", &"atk_subidon", &"atk_lluvia", &"atk_sobredosis", &"atk_blister", &"atk_subidon"]
		_:
			pool = [&"atk_subidon", &"atk_lluvia", &"atk_sobredosis", &"atk_sobredosis", &"atk_fan", &"atk_blister", &"atk_blister"]
	if _pills() >= current_phase + 1:
		pool = pool.filter(func(x): return x != &"atk_blister")
	return pool


func _challenges() -> Array:
	return [&"ch_pastillas", &"ch_agua"]


func _channel_color() -> Color:
	return BLUE


func _combo_len() -> int:
	var n := super()
	if _rush >= 0.7:
		n += 1  # con el subidon alto encadena uno mas, incluso en fase 1
	return n


func _on_phase(n: int) -> void:
	_rush = maxf(_rush, 0.3)  # cada fase arranca con un buen subidon
	_float_text(tr("SILDENAFIL_PHASE_%d" % n), BLUE)


func _on_death() -> void:
	if is_instance_valid(_meter):
		_meter.queue_free()


func _reset_fx() -> void:
	super()
	animated_sprite.visible = true


## Toda zona de peligro de Don Sildenafil se ve como peligro (borde rojo oscuro, franjas).
func _add_hazard(z: BossZone) -> BossZone:
	if z.style == BossZone.Style.NORMAL:
		z.style = BossZone.Style.TOXIC
	return super(z)


func _pills() -> int:
	return get_tree().get_nodes_in_group("pastilla_sildenafil").size()


## Una pastillita reventada: te regala subidon que bajar.
func pill_killed() -> void:
	_rush = maxf(0.0, _rush - 0.1)


func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	var dealt := super(amount, source, kb)
	if dealt > 0.0 and state != State.DEAD:
		# tu golpe lo baja: base + proporcional a lo fuerte que pegaste
		_rush = maxf(0.0, _rush - (0.04 + dealt / max_health * 3.0))
	return dealt


# ---------------------------------------------------------------- subidon
func _tick(delta: float) -> void:
	if state in [State.INTRO, State.TRANSITION, State.DEAD] or target == null:
		return
	if not _channeling:
		var boost := 1.0 + 0.5 * mini(_pills(), 3)
		_rush = minf(1.0, _rush + RUSH_RISE * boost * delta)
	var ph := clampi(current_phase, 1, 3) - 1
	move_speed = BASE_SPEED[ph] * (1.0 + 0.5 * _rush) * (1.35 if _furia else 1.0)
	bullet_speed = 300.0 * (1.0 + 0.3 * _rush)
	rest_min = lerpf(0.45, 0.2, _rush)
	rest_max = lerpf(0.8, 0.4, _rush)
	var caps: Array = []
	for c in BASE_CAPS:
		caps.append(maxf(TELE_FLOOR, c - 0.25 * _rush))
	tele_caps = caps
	if is_instance_valid(_meter):
		_meter.level = _rush
	_passive_spit(delta)


## Pastillazo suelto mientras camina: aviso de 0,55 s (parpadea azul) y una bala rapida a donde vas.
func _passive_spit(delta: float) -> void:
	if state != State.IDLE or _channeling:
		if _spit_warn > 0.0:
			_spit_warn = 0.0
			animated_sprite.modulate = Color.WHITE
		return
	if _spit_warn > 0.0:
		_spit_warn -= delta
		animated_sprite.modulate = Color(0.8, 1.4, 2.4) if int(_spit_warn * 16.0) % 2 == 0 else Color.WHITE
		if _spit_warn <= 0.0:
			animated_sprite.modulate = Color.WHITE
			var lead: Vector2 = target.global_position + target.velocity * 0.35 if "velocity" in target else target.global_position
			_fire((lead - _muzzle()).angle(), bullet_speed * 1.1, 0.6, BLUE)
			Sound.play("enemy_shoot")
			_spit_t = lerpf(3.4, 1.8, _rush)
		return
	_spit_t -= delta
	if _spit_t <= 0.0:
		_spit_warn = 0.55


# ---------------------------------------------------------------- ataques
## Una embestida avisada. Devuelve -1 cancelada, 0 normal, 1 choco con un muro.
func _dash_once(tele_t: float, speed: float) -> int:
	var lane := BossZone.rect(global_position, Vector2(600, 90), 0.0, tele_t + 0.1, 0.05, 0.0, Color(0.4, 0.7, 1.0))
	_add_hazard(lane)
	_charge_dir = (target.global_position - global_position).normalized()
	var track := func(left: float):
		if left > 0.2:
			_charge_dir = (target.global_position - global_position).normalized()
		if is_instance_valid(lane):
			var ln := _ray_len(global_position + Vector2(0, -50), _charge_dir, 700.0)
			lane.size.x = ln
			lane.global_position = global_position + _charge_dir * ln * 0.5
			lane.rotation = _charge_dir.angle()
	if not await _tele(tele_t, Color(0.8, 1.4, 2.4), 3.0, track):
		return -1
	Sound.play("dash")
	_hit_done = false
	var t := 0.0
	while t < 0.5:
		velocity = _charge_dir * speed
		if not await _frame():
			return -1
		_strike()
		t += 1.0 / 60.0
		if get_slide_collision_count() > 0:
			return 1
	return 0


## Efecto de cuatro horas: varias embestidas encadenadas, cada una con su aviso.
func atk_subidon() -> void:
	var n := 2 if current_phase == 1 else 3
	var wall := false
	for k in n:
		var r := await _dash_once(0.82 - 0.08 * current_phase, (440.0 + 50.0 * current_phase) * (1.0 + 0.2 * _rush))
		if r < 0:
			return
		wall = wall or r == 1
		velocity = Vector2.ZERO
		if k < n - 1 and not await _wait(0.12):
			return
	HitFx.shake(0.3 if wall else 0.1)
	_tire(1.8 if wall else 1.2)


## Pastillas que caen en circulos avisados; las dos primeras, donde estas ahora.
func atk_lluvia() -> void:
	if not await _tele(0.45, Color(0.8, 1.4, 2.4)):
		return
	var n := 4 + current_phase * 2
	for i in n:
		var p: Vector2
		if i < 2:
			p = target.global_position + Vector2(RNG.randf_range(-30, 30), RNG.randf_range(-30, 30))
		else:
			p = target.global_position + Vector2(RNG.randf_range(-190, 190), RNG.randf_range(-190, 190))
		_add_hazard(BossZone.circle(clamp_to_arena(p, 50.0), 62.0, 0.85, 0.25, damage * 0.8, BLUE))
		Sound.play("enemy_shoot")
		if not await _wait(0.24):
			return
	if not await _wait(1.0):
		return
	_tire(0.6)


## Salta (desaparece), cae donde estabas con onda de choque y suelta un anillo de pastillas.
func atk_sobredosis() -> void:
	var pos := clamp_to_arena(target.global_position, 90.0)
	var z := BossZone.circle(pos, 150.0, 1.0, 0.3, damage, BLUE)
	_add_hazard(z)
	if not await _tele(0.7, Color(0.8, 1.4, 2.4), 3.0):
		return
	animated_sprite.visible = false
	if not await _wait(0.3):
		return
	global_position = pos
	animated_sprite.visible = true
	Sound.play("crack")
	HitFx.shake(0.5)
	_fire_ring(12 + (current_phase - 2) * 5, 280.0, RNG.randf_range(0.0, TAU), 0.0, 0.0, 0.6, BLUE)
	_rush = maxf(0.0, _rush - 0.35)  # la sobredosis lo descarga a medias
	if not await _wait(0.5):
		return
	_tire(1.5)


## BLISTER: se abre un blister y salen pastillitas rodantes (1 / 2 / 3 segun la fase).
func atk_blister() -> void:
	if not await _tele(0.6, Color(0.8, 1.4, 2.4), 2.0):
		return
	var pts: Array = []
	for i in current_phase:
		pts.append(clamp_to_arena(global_position + Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * 80.0, 50.0))
	_spawn_minions(pts, 12.0 + _floor * 2.0, 8.0 + _floor * 1.0, tr("PASTILLA_NAME"), PILL)
	Sound.play("crack")
	HitFx.shake(0.15)
	if not await _wait(0.4):
		return


# ---------------------------------------------------------------- desafios de la cura
## PASTILLAS: cinco pastillas vagan por la sala. Rompelas todas a tiros.
func ch_pastillas() -> void:
	await _ch_break(5, "pill", {"hp": 14.0, "speed": 60.0, "limit": 12.0})


## AGUA: tomar con agua. Quedate dentro del vaso mientras recorre la sala.
func ch_agua() -> void:
	await _ch_hold("drop", {"need": 4.0, "limit": 12.0, "radius": 95.0})
