extends BossAltBase

## DOÑA VENTANILLA (alternativa femenina del Perineo, reino 4, frente al Aduanero; id "prostata") - usa el MOTOR DINAMICO.
## Una casilla de atencion con patas (rulos, lentes de gato, chicle, cortina metalica de parpado); dice que
## "primero hay que hacerse el chequeo". La version nuez (masculina) quedo guardada en la rama nuez-ventanilla-guardada.
## IDENTIDAD "TOME SU NUMERO": bajo sus pies hay un marcador con el turno que atiende (N° 012) y la cola
## de los que vienen. Sus balas salen POR TURNOS: el numero que sigue parpadea y se llena (aviso >= 0,55 s,
## con una linea hacia ti) y recien entonces ese turno dispara. Lo ves venir, uno a uno.
## - PRESION: se pega al cuerpo y llama un turno suelto (aviso 0,55 s) mientras camina.
## - TURNOS (el ataque firma): cola de 4 / 5 / 6 turnos; fase 2: abanico de 3 por turno; fase 3: de 5.
## - TICKET (circulos numerados), HORA PUNTA (barras de gente), CUBICULOS (la sala en 9, se cierran),
##   PAPELEO (espiral) y EMBESTIDA. Agotada tras turnos, cubiculos y embestida.
## - ESBIRROS: timbres de turno (enemy_timbre.gd): hacen DING (anillo + 4 balitas en cruz) y mientras
##   viven la cola avanza mas rapido; revientalos y a veces sueltan corazon.
## Cura (2 cargas): TURNOS, CAFE (perseguirlo), TRITURADORA (romper papeles), VENTANILLA.

const PAPER := Color(1.0, 0.85, 0.45)
const HP_MULT := 0.7
const BELL := preload("res://src/enemies/enemy_timbre.tscn")
const BASE_SPEED := [120.0, 140.0, 160.0]
const BASE_CAPS := [0.85, 0.7, 0.6]

var _cola: TurnoCola = null
var _next_num := 1          ## proximo numero de ticket por repartir
var _call_t := 3.0
var _call_warn := 0.0


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = Color(1.0, 0.95, 0.8)
	move_speed = BASE_SPEED[0]
	keep_min = 80.0
	keep_max = 150.0
	rest_min = 0.45
	rest_max = 0.8
	bullet_speed = 320.0
	tele_caps = BASE_CAPS.duplicate()
	max_health *= HP_MULT
	current_health = max_health
	_emit_health()
	_channels_total = 2
	_channels_left = 2
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	_cola = TurnoCola.new()
	add_child(_cola)
	_cola.current = 0
	BossAnimator.attach(self)  # arte definitivo 176x184 (tools/gen_dona_ventanilla_art.py): cuadros nuevos + animacion por codigo


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
			pool = [&"atk_turnos", &"atk_papeleo", &"atk_ticket", &"atk_cola", &"atk_timbres"]
		2:
			pool = [&"atk_turnos", &"atk_papeleo", &"atk_ticket", &"atk_cola", &"atk_cubiculos", &"atk_charge", &"atk_timbres"]
		_:
			pool = [&"atk_turnos", &"atk_turnos", &"atk_ticket", &"atk_cola", &"atk_cubiculos", &"atk_cubiculos", &"atk_papeleo", &"atk_charge", &"atk_timbres", &"atk_timbres"]
	if _bells() >= current_phase + 1:
		pool = pool.filter(func(x): return x != &"atk_timbres")
	return pool


func _bells() -> int:
	return get_tree().get_nodes_in_group("timbre_ventanilla").size()


func _challenges() -> Array:
	return [&"ch_turnos", &"ch_cafe", &"ch_triturar", &"ch_ventanilla"]


func _channel_color() -> Color:
	return PAPER


func _on_phase(n: int) -> void:
	_float_text(tr("VENT_PHASE_%d" % n), PAPER)
	_cola.queue = []
	_cola.prog = 0.0


func _on_death() -> void:
	if is_instance_valid(_cola):
		_cola.queue_free()


## Todo peligro de la Ventanilla se ve como peligro (borde rojo oscuro, franjas).
func _add_hazard(z: BossZone) -> BossZone:
	if z.style == BossZone.Style.NORMAL:
		z.style = BossZone.Style.TOXIC
	return super(z)


## Velocidad de la cola: mas rapida con la fase y con timbres vivos (los timbres ayudan al jefe).
func _turn_gap() -> float:
	return maxf(0.55, 0.78 - 0.06 * current_phase - 0.05 * mini(_bells(), 3))


func _tick(delta: float) -> void:
	if state in [State.INTRO, State.TRANSITION, State.DEAD] or target == null:
		return
	var ph := clampi(current_phase, 1, 3) - 1
	move_speed = BASE_SPEED[ph] * (1.35 if _furia else 1.0)
	_passive_call(delta)


## Turno suelto mientras camina: el marcador muestra el numero, se llena 0,55 s y sale una bala rapida.
func _passive_call(delta: float) -> void:
	if state != State.IDLE or _channeling:
		if _call_warn > 0.0:
			_call_warn = 0.0
			_cola.prog = 0.0
		return
	if _call_warn > 0.0:
		_call_warn -= delta
		_cola.prog = 1.0 - _call_warn / 0.55
		if _call_warn <= 0.0:
			_cola.prog = 0.0
			var lead: Vector2 = target.global_position + (target.velocity * 0.35 if "velocity" in target else Vector2.ZERO)
			_fire((lead - _muzzle()).angle(), bullet_speed * 1.1, 0.6, PAPER)
			Sound.play("enemy_shoot")
			_call_t = [3.6, 3.0, 2.4][clampi(current_phase, 1, 3) - 1]
		return
	_call_t -= delta
	if _call_t <= 0.0:
		_cola.current = _next_num
		_next_num += 1
		_call_warn = 0.55


# ---------------------------------------------------------------- ataques
## Circulos que saltan por turno (1, 2, 3...) alrededor de ti.
func atk_ticket() -> void:
	var n := 3 + current_phase
	if not await _tele(0.8, Color(2.2, 1.9, 1.0)):
		return
	for i in n:
		var p := clamp_to_arena(target.global_position + Vector2(RNG.randf_range(-150, 150), RNG.randf_range(-150, 150)), 50.0)
		_add_hazard(BossZone.circle(p, 60.0, 0.7 + i * 0.4, 0.25, damage * 0.8, PAPER))
		_float_text(str(i + 1), PAPER, p - global_position + Vector2(0, -20))
	if not await _wait(0.7 + n * 0.4 + 0.5):
		return


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
	if not await _tele(0.8, Color(2.2, 1.9, 1.0), 2.0):
		return
	var a := (target.global_position - _muzzle()).angle()
	var n := 12 + current_phase * 3
	var s := 0.5 if RNG.randf() < 0.5 else -0.5
	for i in n:
		_fire(a + i * s, 300.0, 0.6, PAPER)
		_fire(a + i * s + PI, 300.0, 0.6, PAPER)
		if not await _wait(0.1):
			return
	await _wait(0.3)


## "TOME SU NUMERO" (ataque firma): una cola de turnos que ves venir. El marcador muestra el numero
## que atiende y los que siguen; el que sigue parpadea y se llena 0,55 s con una linea hacia ti, y
## recien entonces ese turno dispara. Fase 1: bala sola; fase 2: abanico de 3; fase 3: abanico de 5.
func atk_turnos() -> void:
	var n := 3 + current_phase
	var nums: Array = []
	for i in n:
		nums.append(_next_num + i)
	_cola.queue = nums.duplicate()
	if not await _tele(0.8, Color(2.2, 1.9, 1.0), 2.0):
		_cola.queue = []
		return
	for i in n:
		_cola.current = nums[i]
		_next_num = nums[i] + 1
		_cola.queue = nums.slice(i + 1)
		var line := BossZone.rect(_muzzle(), Vector2(380, 6), 0.0, 0.6, 0.05, 0.0, PAPER)
		_add_hazard(line)
		var ang := (target.global_position - _muzzle()).angle()
		var t := 0.0
		while t < 0.55:
			if not await _frame():
				_cola.queue = []
				_cola.prog = 0.0
				return
			t += 1.0 / 60.0
			_cola.prog = t / 0.55
			if t < 0.4:  # sigue tu posicion; los ultimos 0,15 s queda fija
				ang = (target.global_position - _muzzle()).angle()
			if is_instance_valid(line):
				var d := Vector2.RIGHT.rotated(ang)
				line.global_position = _muzzle() + d * 190.0
				line.rotation = ang
		_cola.prog = 0.0
		if is_instance_valid(line):
			line.dismiss()
		Sound.play("enemy_shoot")
		var shots := 1 if current_phase == 1 else (3 if current_phase == 2 else 5)
		for k in shots:
			_fire(ang + (k - (shots - 1) / 2.0) * 0.19, bullet_speed * 1.1, 0.7, PAPER)
		var rest := maxf(0.0, _turn_gap() - 0.55)
		if rest > 0.0 and not await _wait(rest):
			_cola.queue = []
			return
	_cola.queue = []
	_tire(1.3)


## TIMBRES: apoya un timbre de turno en el mostrador y salen timbres rondando (1 / 2 / 3 segun la fase).
func atk_timbres() -> void:
	if not await _tele(0.8, Color(2.2, 1.9, 1.0), 2.0):
		return
	var pts: Array = []
	for i in current_phase:
		pts.append(clamp_to_arena(global_position + Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * 90.0, 50.0))
	_float_text(tr("VENT_CALL"), PAPER)
	_spawn_minions(pts, 12.0 + _floor * 2.0, 6.0 + _floor * 1.5, tr("TIMBRE_NAME"), BELL)
	Sound.play("crack")
	HitFx.shake(0.15)
	await _wait(0.4)


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
