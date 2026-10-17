extends BossAltBase

## LA PROSTATA BUROCRATICA (alternativo del Perineo, reino 4). Del tamano de una nuez y con
## ventanilla propia; dice que "primero hay que hacerse el chequeo" y tiene razon:
## - FICHA NUMERO: circulos que saltan en orden de turno, uno tras otro, alrededor de ti;
## - HORA PUNTA: barras de gente que cruzan la sala (hay huecos entre ellas);
## - CUBICULOS: la sala se divide en 9 y algunos cubiculos se cierran de golpe;
## - PAPELEO: espiral de papeles; EMBESTIDA (la de siempre). Agotada tras cubiculos y embestida.
## Cura (4 cargas): TURNOS, CAFE (perseguirlo), TRITURADORA (romper papeles), VENTANILLA.

const PAPER := Color(1.0, 0.85, 0.45)


func _ready() -> void:
	super()
	fan_tint = Color(1.0, 0.95, 0.8)
	move_speed = 70.0
	keep_min = 200.0
	keep_max = 320.0


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_papeleo", &"atk_ticket", &"atk_cola"]
		2:
			return [&"atk_papeleo", &"atk_ticket", &"atk_cola", &"atk_cubiculos", &"atk_charge"]
	return [&"atk_ticket", &"atk_cola", &"atk_cubiculos", &"atk_cubiculos", &"atk_papeleo", &"atk_charge"]


func _challenges() -> Array:
	return [&"ch_turnos", &"ch_cafe", &"ch_triturar", &"ch_ventanilla"]


func _channel_color() -> Color:
	return PAPER


func _on_phase(n: int) -> void:
	move_speed = 70.0 + 16.0 * (n - 1)


# ---------------------------------------------------------------- ataques
## Circulos que saltan por turno (1, 2, 3...) alrededor de ti.
func atk_ticket() -> void:
	var n := 3 + current_phase
	if not await _tele(0.4, Color(2.2, 1.9, 1.0)):
		return
	for i in n:
		var p := clamp_to_arena(target.global_position + Vector2(RNG.randf_range(-150, 150), RNG.randf_range(-150, 150)), 50.0)
		_add_hazard(BossZone.circle(p, 60.0, 0.7 + i * 0.4, 0.25, damage * 0.8, PAPER))
		_float_text(str(i + 1), PAPER, p - global_position + Vector2(0, -20))
	if not await _wait(0.7 + n * 0.4 + 0.5):
		return
	_tire(0.7)


## Columnas de gente que cruzan la sala de lado a lado: entre columna y columna hay hueco.
func atk_cola() -> void:
	var a := arena()
	var horiz := RNG.randf() < 0.5  # true: avanzan en x (columnas verticales)
	var n := 3 + (1 if current_phase == 3 else 0)
	var warn := 1.2
	var sp := 270.0 + current_phase * 20.0
	var dir := 1.0 if RNG.randf() < 0.5 else -1.0
	var spacing := 240.0
	var span := a.size.x if horiz else a.size.y
	for i in n:
		var off := 50.0 + i * spacing
		var z: BossZone
		if horiz:
			var x := a.position.x + off if dir > 0.0 else a.end.x - off
			z = BossZone.rect(Vector2(x, a.get_center().y), Vector2(70.0, a.size.y), 0.0, warn, span / sp + 0.4, damage * 0.8, PAPER)
			z.vel = Vector2(dir * sp, 0.0)
		else:
			var y := a.position.y + off if dir > 0.0 else a.end.y - off
			z = BossZone.rect(Vector2(a.get_center().x, y), Vector2(a.size.x, 70.0), 0.0, warn, span / sp + 0.4, damage * 0.8, PAPER)
			z.vel = Vector2(0.0, dir * sp)
		z.fade = 0.3
		_add_hazard(z)
	if not await _tele(warn - 0.1, Color(2.2, 1.9, 1.0), 2.0):
		return
	Sound.play("suck")
	if not await _wait(span / sp + 0.4):
		return
	_tire(0.6)


## La sala se divide en 9 cubiculos; algunos se cierran de golpe.
func atk_cubiculos() -> void:
	var a := arena().grow(-30.0)
	var cw := a.size.x / 3.0
	var ch := a.size.y / 3.0
	var cells: Array = range(9)
	cells.shuffle()
	var k := 3 + current_phase
	var warn := 1.35 - 0.1 * current_phase
	for i in k:
		var c: int = cells[i]
		var p := a.position + Vector2((c % 3 + 0.5) * cw, (c / 3 + 0.5) * ch)
		_add_hazard(BossZone.rect(p, Vector2(cw - 8.0, ch - 8.0), 0.0, warn, 0.4, damage * 0.9, PAPER))
	if not await _tele(warn - 0.1, Color(2.2, 1.9, 1.0), 2.5):
		return
	Sound.play("crack")
	if not await _wait(0.8):
		return
	_tire(1.1)


## Espiral de papeles.
func atk_papeleo() -> void:
	if not await _tele(0.5, Color(2.2, 1.9, 1.0), 2.0):
		return
	var a := (target.global_position - _muzzle()).angle()
	var n := 12 + current_phase * 3
	var s := 0.5 if RNG.randf() < 0.5 else -0.5
	for i in n:
		_fire(a + i * s, 200.0, 0.6)
		_fire(a + i * s + PI, 200.0, 0.6)
		if not await _wait(0.1):
			return
	await _wait(0.3)


# ---------------------------------------------------------------- desafios de la cura
## TURNOS: cuatro fichas numeradas; atiendete en orden.
func ch_turnos() -> void:
	await _ch_touch(_spread_points(4, 160.0), "ticket", {"ordered": true, "numbered": true, "limit": 13.0})


## CAFE: la taza de cafe huye por la sala. Alcanzala.
func ch_cafe() -> void:
	await _ch_chase("cup", {"speed": 350.0, "limit": 8.0})


## TRITURADORA: seis papeles vagan por la sala. Rompelos a tiros.
func ch_triturar() -> void:
	await _ch_break(6, "paper", {"hp": 12.0, "speed": 60.0, "limit": 13.0})


## VENTANILLA: la ventanilla de turno se mueve. Quedate dentro hasta que te atiendan.
func ch_ventanilla() -> void:
	await _ch_hold("ticket", {"need": 4.5, "limit": 13.0, "radius": 90.0, "speed": 0.48})
