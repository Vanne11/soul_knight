extends BossAltBase

## DON VIAGRA (alternativo de Penelandia, reino 2). Pastilla azul con cuatro horas de
## aguante y cero sentido de la medida:
## - SUBIDON: 2-3 embestidas seguidas, cada una avisada con su franja;
## - LLUVIA AZUL: pastillas que caen en circulos avisados (las primeras, sobre ti);
## - SOBREDOSIS (fase 2+): salta, cae con onda de choque y suelta un anillo de pastillas;
## - ABANICO. Agotado tras el subidon y la sobredosis.
## Cura (2 cargas): ROMPE LAS PASTILLAS (5 que vagan) y TOMAR CON AGUA (mantente en el vaso).

const BLUE := Color(0.35, 0.65, 1.0)


func _ready() -> void:
	super()
	fan_tint = BLUE
	move_speed = 85.0
	keep_min = 180.0
	keep_max = 320.0


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_fan", &"atk_subidon", &"atk_lluvia"]
		2:
			return [&"atk_fan", &"atk_subidon", &"atk_lluvia", &"atk_sobredosis"]
	return [&"atk_subidon", &"atk_lluvia", &"atk_sobredosis", &"atk_sobredosis", &"atk_fan"]


func _challenges() -> Array:
	return [&"ch_pastillas", &"ch_agua"]


func _channel_color() -> Color:
	return BLUE


func _on_phase(n: int) -> void:
	move_speed = 85.0 + 18.0 * (n - 1)


func _reset_fx() -> void:
	super()
	animated_sprite.visible = true


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
		var r := await _dash_once(0.72 - 0.08 * current_phase, 440.0 + 50.0 * current_phase)
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
	_fire_ring(12 + (current_phase - 2) * 5, 210.0, RNG.randf_range(0.0, TAU), 0.0, 0.0, 0.6, BLUE)
	if not await _wait(0.5):
		return
	_tire(1.5)


# ---------------------------------------------------------------- desafios de la cura
## PASTILLAS: cinco pastillas vagan por la sala. Rompelas todas a tiros.
func ch_pastillas() -> void:
	await _ch_break(5, "pill", {"hp": 14.0, "speed": 60.0, "limit": 12.0})


## AGUA: tomar con agua. Quedate dentro del vaso mientras recorre la sala.
func ch_agua() -> void:
	await _ch_hold("drop", {"need": 4.0, "limit": 12.0, "radius": 95.0})
