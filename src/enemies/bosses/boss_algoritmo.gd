extends BossAltBase

## EL ALGORITMO MODERADOR (alternativo del Palacio de la Censura, reino 5). Un ojo sin
## parpadeo que lo revisa todo y aprende poco: confunde una lactancia con un delito.
## - ESCANEO: una linea de lectura cruza la sala con un hueco por el que pasar;
## - REPORTADO: marca tu posicion (el reticulo te sigue y se bloquea en el ultimo momento);
## - CONTENIDO SENSIBLE: bloques pixelados que se cierran en zonas de la sala;
## - BLOQUEO: barras negras de censura, escalonadas, con pasillos libres;
## - SPAM (abanico) y NOTIFICACIONES (anillo con hueco, fase 3). Agotado tras bloqueo y escaneo.
## Cura (5 cargas): MODO OSCURO, FALSO POSITIVO (clones), CAPTCHA, COOKIES, REVISION HUMANA.

const GLASS := Color(0.7, 0.85, 1.0)
const ALERT := Color(1.0, 0.3, 0.3)


func _ready() -> void:
	super()
	fan_tint = GLASS
	move_speed = 75.0
	keep_min = 220.0
	keep_max = 340.0


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_fan", &"atk_escaneo", &"atk_reportado"]
		2:
			return [&"atk_fan", &"atk_escaneo", &"atk_reportado", &"atk_pixelado", &"atk_bloqueo"]
	return [&"atk_escaneo", &"atk_reportado", &"atk_pixelado", &"atk_bloqueo", &"atk_notificaciones", &"atk_fan"]


func _challenges() -> Array:
	return [&"ch_modo_oscuro", &"ch_falso_positivo", &"ch_captcha", &"ch_cookies", &"ch_revision"]


func _channel_color() -> Color:
	return GLASS


func _on_phase(n: int) -> void:
	move_speed = 75.0 + 14.0 * (n - 1)


# ---------------------------------------------------------------- ataques
## Linea de lectura: cruza la sala de lado a lado con un hueco libre.
func atk_escaneo() -> void:
	var a := arena()
	var horiz := RNG.randf() < 0.5  # linea horizontal que sube/baja (o vertical que avanza)
	var up := RNG.randf() < 0.5
	var span := a.size.x if horiz else a.size.y
	var gap := 170.0
	var gap_c := RNG.randf_range(gap, maxf(span - gap, gap + 1.0))
	var warn := 1.2
	var sp := 210.0 + current_phase * 25.0
	var thick := 56.0
	var segs: Array = [[0.0, gap_c - gap * 0.5], [gap_c + gap * 0.5, span]]
	for s in segs:
		var seg_len: float = s[1] - s[0]
		if seg_len < 8.0:
			continue
		var mid: float = s[0] + seg_len * 0.5
		var z: BossZone
		if horiz:
			var y := a.end.y - thick * 0.5 - 4.0 if up else a.position.y + thick * 0.5 + 4.0
			z = BossZone.rect(Vector2(a.position.x + mid, y), Vector2(seg_len, thick), 0.0, warn, ((a.size.y if horiz else a.size.x) - thick) / sp + 0.2, damage * 0.9, GLASS)
			z.vel = Vector2(0.0, -sp if up else sp)
		else:
			var x := a.end.x - thick * 0.5 - 4.0 if up else a.position.x + thick * 0.5 + 4.0
			z = BossZone.rect(Vector2(x, a.position.y + mid), Vector2(thick, seg_len), 0.0, warn, ((a.size.y if horiz else a.size.x) - thick) / sp + 0.2, damage * 0.9, GLASS)
			z.vel = Vector2(-sp if up else sp, 0.0)
		z.fade = 0.2
		_add_hazard(z)
	if not await _tele(warn - 0.1, Color(1.4, 1.8, 2.4), 2.0):
		return
	Sound.play("suck")
	var travel := ((a.size.y if horiz else a.size.x) - thick) / sp + 0.3
	if not await _wait(travel):
		return
	_tire(1.0)


## Reportado: el reticulo te sigue y se bloquea justo antes de caer.
func atk_reportado() -> void:
	for k in current_phase:
		var z := BossZone.circle(target.global_position, 78.0, 1.1, 0.3, damage * 0.9, ALERT)
		_add_hazard(z)
		var track := func(left: float):
			if left > 0.4 and is_instance_valid(z):
				z.global_position = target.global_position
		if not await _tele(1.1, Color(2.4, 1.0, 1.0), 2.0, track):
			return
		Sound.play("crack")
		if not await _wait(0.2):
			return
	_tire(0.8)


## Bloques de pixelado que se cierran en varias zonas (la primera, sobre ti).
func atk_pixelado() -> void:
	var n := 2 + current_phase
	for i in n:
		var p := target.global_position if i == 0 else arena_point(110.0)
		var z := BossZone.rect(clamp_to_arena(p, 100.0), Vector2(200, 200), 0.0, 1.1 + i * 0.2, 0.5, damage * 0.9, Color.WHITE)
		z.style = BossZone.Style.PIXEL
		_add_hazard(z)
	if not await _tele(1.0, Color(1.4, 1.8, 2.4), 2.0):
		return
	if not await _wait(0.4 + n * 0.2 + 0.6):
		return
	_tire(0.7)


## Barras de censura escalonadas, con pasillos libres.
func atk_bloqueo() -> void:
	var a := arena()
	var horiz := RNG.randf() < 0.5
	var span := a.size.y if horiz else a.size.x
	var n := maxi(int(span / 115.0), 4)
	var w := span / n
	var lanes: Array = range(n)
	lanes.shuffle()
	var bars := mini(n - 2, 3)
	for i in bars:
		var l: int = lanes[i]
		var z: BossZone
		if horiz:
			z = BossZone.rect(Vector2(a.get_center().x, a.position.y + (l + 0.5) * w), Vector2(a.size.x, w - 8.0), 0.0, 1.1 + i * 0.45, 0.4, damage * 0.9, Color.WHITE)
		else:
			z = BossZone.rect(Vector2(a.position.x + (l + 0.5) * w, a.get_center().y), Vector2(w - 8.0, a.size.y), 0.0, 1.1 + i * 0.45, 0.4, damage * 0.9, Color.WHITE)
		z.style = BossZone.Style.BAR
		_add_hazard(z)
	if not await _tele(1.0, Color(1.4, 1.8, 2.4), 2.0):
		return
	if not await _wait(0.2 + bars * 0.45 + 0.8):
		return
	_tire(1.0)


## Anillos de notificaciones con hueco (fase 3).
func atk_notificaciones() -> void:
	var warn := BossZone.circle(global_position, 120.0, 0.7, 0.05, 0.0, GLASS)
	warn.follow = self
	_add_hazard(warn)
	if not await _tele(0.7, Color(1.4, 1.8, 2.4), 2.0):
		return
	for r in 3:
		var gap_at := RNG.randf_range(-PI, PI)
		_fire_ring(20, 200.0, 0.0, gap_at, 0.9, 0.55, GLASS)
		Sound.play("enemy_shoot")
		if r < 2 and not await _wait(0.6):
			return
	await _wait(0.4)


# ---------------------------------------------------------------- desafios de la cura
## MODO OSCURO: se apaga la pantalla. Encuentralo por su brillo y golpealo.
func ch_modo_oscuro() -> void:
	await _ch_blackout(130.0, Color(0.02, 0.02, 0.05), 5, 50.0, 12.0)


## FALSO POSITIVO: tres copias del algoritmo. Solo una es real.
func ch_falso_positivo() -> void:
	await _ch_clones(3)


## CAPTCHA: pisa solo los semaforos; los demas cuadros restan.
func ch_captcha() -> void:
	var pts := _spread_points(3, 150.0, 100.0)
	var decoys: Array = []
	for p in _spread_points(5, 110.0, 100.0):
		if not pts.any(func(q): return q.distance_to(p) < 100.0):
			decoys.append(p)
	await _ch_touch(pts, "light", {"decoys": decoys, "decoy_kind": "tile", "limit": 14.0})


## COOKIES: seis cookies de seguimiento. Rompelas todas.
func ch_cookies() -> void:
	await _ch_break(6, "cookie", {"hp": 12.0, "speed": 65.0, "limit": 13.0})


## REVISION HUMANA: el filtro tiene un hueco que gira. Dispara desde el lado del hueco.
func ch_revision() -> void:
	await _ch_weak({"hits": 5, "limit": 14.0})
