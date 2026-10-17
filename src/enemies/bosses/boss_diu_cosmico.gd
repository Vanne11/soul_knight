extends BossAltBase

## EL DIU COSMICO (alternativo de Vulvania, reino 3). Una T de cobre que orbita, con hilos
## y mucha paciencia: lleva anos alli arriba y nadie se atreve a moverlo.
## - BRAZOS DE COBRE: barras que giran en sentidos opuestos, entran de una en una;
## - HILOS: abanico de hilos que te siguen y se tensan de golpe;
## - METEOROS: circulos avisados por toda la sala (los primeros, sobre ti);
## - SUPERNOVA (fase 3): una explosion enorme en el centro; hay que irse al borde;
## - ABANICO. Agotado tras los brazos y la supernova.
## Cura (3 cargas): CONSTELACION, ECLIPSE (escudo con hueco que gira), COMETA (perseguirlo).

const COPPER := Color(1.0, 0.6, 0.3)
const VIOLET := Color(0.75, 0.5, 1.0)


func _ready() -> void:
	super()
	fan_tint = VIOLET
	move_speed = 75.0
	keep_min = 200.0
	keep_max = 330.0


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_hilos", &"atk_brazos", &"atk_meteoros"]
		2:
			return [&"atk_hilos", &"atk_brazos", &"atk_meteoros", &"atk_fan"]
	return [&"atk_hilos", &"atk_brazos", &"atk_meteoros", &"atk_supernova", &"atk_supernova", &"atk_fan"]


func _challenges() -> Array:
	return [&"ch_constelacion", &"ch_eclipse", &"ch_cometa"]


func _channel_color() -> Color:
	return COPPER


func _on_phase(n: int) -> void:
	move_speed = 75.0 + 15.0 * (n - 1)


# ---------------------------------------------------------------- ataques
## Barras de cobre que giran en sentidos opuestos; entran una cada 0.7 s.
func atk_brazos() -> void:
	if not await _walk_to(arena().get_center(), 1.4):
		return
	var reach := 290.0
	var c := _muzzle()
	var bars := 2 if current_phase < 3 else 3
	for k in bars:
		var z := BossZone.rect(c, Vector2(reach * 2.0, 38.0), k * PI / bars, 0.9 + k * 0.7, 2.4, damage * 0.5, COPPER)
		z.spin = 0.7 * (1.0 if k % 2 == 0 else -1.0) * (1.0 + current_phase * 0.12)
		z.one_hit = false
		z.fade = 0.4
		_add_hazard(z)
	if not await _tele(0.9 + (bars - 1) * 0.7, Color(2.2, 1.5, 0.8), 2.5):
		return
	if not await _wait(2.6):
		return
	_tire(1.6)


## Abanico de hilos que te siguen y se tensan de golpe.
func atk_hilos() -> void:
	var offs: Array = [-0.42, 0.0, 0.42] if current_phase < 3 else [-0.7, -0.35, 0.0, 0.35, 0.7]
	var st := {"base": (target.global_position - _muzzle()).angle()}
	var zs: Array = []
	for o in offs:
		zs.append(_add_hazard(BossZone.rect(_muzzle(), Vector2(500, 28), st.base + o, 1.1, 0.35, damage * 0.9, VIOLET)))
	var track := func(left: float):
		if left > 0.35:
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
	if not await _wait(0.6):
		return
	_tire(0.7)


## Meteoros avisados por toda la sala; los dos primeros caen sobre ti.
func atk_meteoros() -> void:
	if not await _tele(0.4, Color(2.2, 1.5, 0.8)):
		return
	var n := 5 + current_phase * 2
	for i in n:
		var p: Vector2 = arena_point(60.0)
		if i < 2:
			p = target.global_position + Vector2(RNG.randf_range(-25, 25), RNG.randf_range(-25, 25))
		_add_hazard(BossZone.circle(clamp_to_arena(p, 50.0), 72.0, 0.9, 0.3, damage * 0.8, COPPER))
		Sound.play("enemy_shoot")
		if not await _wait(0.3):
			return
	if not await _wait(1.0):
		return
	_tire(0.7)


## Explosion enorme en el centro: sal al borde. Despues, anillo lento y agotado.
func atk_supernova() -> void:
	if not await _walk_to(arena().get_center(), 1.4):
		return
	var r := minf(arena().size.x, arena().size.y) * 0.38
	_add_hazard(BossZone.circle(global_position, r, 1.5, 0.5, damage * 1.1, COPPER))
	if not await _tele(1.5, Color(2.4, 1.6, 0.8), 3.5):
		return
	Sound.play("crack")
	HitFx.shake(0.6)
	_fire_ring(18, 150.0, 0.0, 0.0, 0.0, 0.5, VIOLET)
	if not await _wait(0.7):
		return
	_tire(1.8)


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
