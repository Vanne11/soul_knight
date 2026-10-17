extends BossAltBase

## LA AFEITADORA ELECTRICA (alternativo de la Selva Pubica, reino 1). Cabezal oscilante,
## cable al enchufe y cero paciencia con todo lo que crece:
## - RAPADO A FRANJAS: franjas de lado a lado de la sala con uno o dos pasillos libres;
## - CUCHILLAS: se enciende y te persigue con dos cuchillas giratorias a su alrededor;
## - RECORTE A PRESION: anillo de pelusa con hueco (fase 1: justo hacia ti; luego, al azar);
## - EMBESTIDA y ABANICO (los de siempre). Agotada tras cuchillas, franjas y embestida.
## Cura (1 carga): DESENCHUFAR. Tres enchufes en la sala, de uno en uno.

const STEEL := Color(0.62, 0.82, 1.0)


func _ready() -> void:
	super()
	fan_tint = STEEL
	move_speed = 80.0
	keep_min = 190.0
	keep_max = 310.0


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_fan", &"atk_barrido", &"atk_cuchillas"]
		2:
			return [&"atk_barrido", &"atk_cuchillas", &"atk_recorte", &"atk_charge"]
	return [&"atk_barrido", &"atk_cuchillas", &"atk_recorte", &"atk_charge", &"atk_fan"]


func _challenges() -> Array:
	return [&"ch_enchufes"]


func _channel_color() -> Color:
	return STEEL


func _on_phase(n: int) -> void:
	move_speed = 80.0 + 16.0 * (n - 1)


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
	var warn := 1.35 - 0.1 * current_phase
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
	if not await _wait(0.8):
		return
	_tire(0.9)


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
		_fire_ring(16 + current_phase * 3, 190.0 + r * 30.0, r * 0.2, gap_at, 0.9, 0.6, STEEL)
		Sound.play("enemy_shoot")
		if r < rings - 1 and not await _wait(0.7):
			return
	await _wait(0.4)


# ---------------------------------------------------------------- desafio de la cura
## ENCHUFES: tres enchufes en la sala, de uno en uno. Tocalos todos para cortarle la corriente.
func ch_enchufes() -> void:
	await _ch_touch(_spread_points(3), "plug", {"ordered": true, "reveal_one": true, "limit": 11.0})
