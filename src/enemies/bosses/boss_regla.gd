extends EnemyBoss

## DOÑA REGLA (El Utero, nivel secreto de Vulvania). Regla de medir de 2 metros; "la regla es
## la regla": llega puntual, cuando nadie la espera.
## - GOLPES DE REGLA: lineas rojas (verticales u horizontales) que avisan ~1 s en el suelo y
##   caen una tras otra; la primera sobre ti, las demas escalonadas. Cada fase suma lineas;
## - TE MIDE: una regla que te sigue (franja de aviso) y se clava donde estabas; si fallas
##   queda AGOTADA con la regla clavada;
## - LLEGA PUNTUAL (fase 2+): desaparece y marca dos o tres circulos en el suelo; reaparece en
##   uno de ellos con un porrazo. Los circulos avisan 1,3 s: puntual, pero no por sorpresa;
## - CALENDARIO (fase 2+): una rejilla de "dias" del suelo, seis por cuatro; los marcados en
##   rojo revientan, el resto es seguro;
## - BARRIDO (fase 3): la regla entera (2 m) gira sobre ella; luego queda AGOTADA.
## Curacion interrumpible: tres reglas (la real tiene sombra), como los clones de Ovaria.
## Frases: bossutero_<intro|phase2|phase3|death|after> (narrator/lines.json).

const RED := Color(1.0, 0.3, 0.38)
const CAL_COLS := 6
const CAL_ROWS := 4

var _last_cm := 0
var _aim := Vector2.RIGHT
var _aim_len := 560.0


func _ready() -> void:
	super()
	fan_tint = RED
	keep_min = 200.0
	keep_max = 320.0


func _say(suffix: String) -> void:
	var key := "bossutero_%s" % suffix  # propias (lines.json): boss<piso>_* son las de la jefa de Vulvania
	if Narrator.has_lines(key):
		Narrator.say(key)


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_fan", &"atk_golpes", &"atk_mide"]
		2:
			return [&"atk_golpes", &"atk_mide", &"atk_puntual", &"atk_fan", &"atk_calendario", &"atk_charge"]
	return [&"atk_golpes", &"atk_calendario", &"atk_puntual", &"atk_barrido", &"atk_mide", &"atk_calendario"]


func _challenges() -> Array:
	return [&"ch_reglas"]


func _channel_color() -> Color:
	return RED


func _on_phase(n: int) -> void:
	move_speed = 70.0 + 16.0 * (n - 1)


# ---------------------------------------------------------------- golpes de regla
## Lineas en el suelo (todas del ancho de la sala): la 1a sobre ti, las demas desplazadas.
func atk_golpes() -> void:
	var a := arena()
	var vertical := RNG.randf() < 0.5
	var n := 2 + current_phase
	var warn := 1.0 - 0.1 * current_phase
	if not await _tele(0.5, Color(2.2, 0.8, 0.8), 2.5):
		return
	var base: Vector2 = target.global_position
	var gap := 110.0
	var dir := 1.0 if RNG.randf() < 0.5 else -1.0
	for i in n:
		# la primera cae sobre ti; las demas se van desplazando en un sentido y otro
		var off := 0.0 if i == 0 else gap * ceil(i / 2.0) * (dir if i % 2 == 1 else -dir)
		var z: BossZone
		if vertical:
			var x := clampf(base.x + off, a.position.x + 20.0, a.end.x - 20.0)
			z = BossZone.rect(Vector2(x, a.get_center().y), Vector2(a.size.y, 56.0), PI * 0.5, warn, 0.25, damage * 0.9, RED)
		else:
			var y := clampf(base.y + off, a.position.y + 20.0, a.end.y - 20.0)
			z = BossZone.rect(Vector2(a.get_center().x, y), Vector2(a.size.x, 56.0), 0.0, warn, 0.25, damage * 0.9, RED)
		_add_hazard(z)
		Sound.play("enemy_shoot")
		if not await _wait(0.42 - 0.04 * current_phase):
			return
	if not await _wait(warn + 0.35):
		return
	_tire(0.9)


# ---------------------------------------------------------------- te mide
## La regla te sigue y se clava donde estabas. "Mide" una cifra cada vez.
func atk_mide() -> void:
	_aim = (target.global_position - _muzzle()).normalized()
	_aim_len = 560.0
	var lane := BossZone.rect(_muzzle(), Vector2(_aim_len, 64.0), 0.0, 1.6, 0.05, 0.0, RED)
	_add_hazard(lane)
	var track := func(left: float):
		if left > 0.3:
			_aim = (target.global_position - _muzzle()).normalized()
		_aim_len = _ray_len(_muzzle(), _aim, 620.0)
		if is_instance_valid(lane):
			lane.size.x = _aim_len
			lane.global_position = _muzzle() + _aim * _aim_len * 0.5
			lane.rotation = _aim.angle()
	_last_cm = 150 + RNG.randi_range(0, 45)
	_float_text(tr("UTERO_REGLA_MIDE") % [_last_cm / 100.0], Color("ffe08a"))
	if not await _tele(0.95, Color(2.2, 0.7, 0.7), 2.5, track):
		return
	var hit: bool = is_instance_valid(lane) and lane.contains(target.global_position)
	var strike := BossZone.rect(_muzzle() + _aim * _aim_len * 0.5, Vector2(_aim_len, 64.0), _aim.angle(), 0.0, 0.22, damage, Color.WHITE)
	_add_hazard(strike)
	if is_instance_valid(lane):
		lane.dismiss()
	Sound.play("crack")
	HitFx.shake(0.28)
	if not await _wait(0.3):
		return
	_tire(1.1 if hit else 1.7)  # si fallas, la regla queda clavada: tu ventana


# ---------------------------------------------------------------- llega puntual
## Desaparece, marca circulos y llega a uno: nadie la espera, pero avisa.
func atk_puntual() -> void:
	if not await _tele(0.4, Color(2.0, 1.2, 1.2), 1.5):
		return
	var spots: Array[Vector2] = [clamp_to_arena(target.global_position, 90.0)]
	for i in current_phase:
		spots.append(arena_point(100.0))
	invuln = true
	animated_sprite.modulate.a = 0.0
	hitbox.set_deferred("monitoring", false)
	_float_text(tr("UTERO_REGLA_PUNTUAL"), Color("ffe08a"))
	for p in spots:
		_add_hazard(BossZone.circle(p, 118.0, 1.3, 0.22, damage * 1.1, RED))
	if not await _wait(1.3):
		_reappear()
		return
	var at: Vector2 = spots[RNG.randi_range(0, spots.size() - 1)]
	global_position = at
	_reappear()
	Sound.play("crack")
	HitFx.shake(0.45)
	if not await _wait(0.35):
		return
	_tire(1.5)


func _reappear() -> void:
	invuln = false
	animated_sprite.modulate = Color.WHITE
	hitbox.set_deferred("monitoring", true)


func _cancel_attack() -> void:
	super()
	_reappear()  # si la cortan desaparecida (cambio de fase), que no se quede invisible


# ---------------------------------------------------------------- calendario
## Rejilla de dias: los marcados revientan, los demas son seguros.
func atk_calendario() -> void:
	var a := arena().grow(-40.0)
	var cw := a.size.x / CAL_COLS
	var ch := a.size.y / CAL_ROWS
	var cells: Array[Vector2i] = []
	for cx in CAL_COLS:
		for cy in CAL_ROWS:
			cells.append(Vector2i(cx, cy))
	RNG.shuffle(cells)
	var marked := 6 + 3 * current_phase
	# siempre uno bajo ti, para que el aviso se lea
	var under := Vector2i(clampi(int((target.global_position.x - a.position.x) / cw), 0, CAL_COLS - 1), clampi(int((target.global_position.y - a.position.y) / ch), 0, CAL_ROWS - 1))
	cells.erase(under)
	cells.push_front(under)
	if not await _tele(0.55, Color(2.0, 0.9, 0.9), 2.0):
		return
	for i in marked:
		var c: Vector2i = cells[i]
		var centre := a.position + Vector2((c.x + 0.5) * cw, (c.y + 0.5) * ch)
		_add_hazard(BossZone.rect(centre, Vector2(cw - 8.0, ch - 8.0), 0.0, 1.25, 0.3, damage * 0.85, Color(1.0, 0.35, 0.5)))
	Sound.play("enemy_shoot")
	if not await _wait(1.9):
		return
	_tire(0.8)


# ---------------------------------------------------------------- barrido
## La regla entera (2 m) gira sobre ella.
func atk_barrido() -> void:
	var ang := RNG.randf_range(0.0, PI)
	var sp := 0.55 * (1.0 if RNG.randf() < 0.5 else -1.0)
	var reach := arena().size.length() * 1.05
	if not await _walk_to(arena().get_center(), 1.4):
		return
	var z := BossZone.rect(_muzzle(), Vector2(reach, 50.0), ang, 1.0, 2.8, damage, RED)
	z.spin = sp
	z.one_hit = false
	z.fade = 0.4
	z.follow = self
	z.follow_offset = Vector2(0, -50)
	_add_hazard(z)
	if not await _tele(0.95, Color(2.2, 0.8, 0.8), 2.5):
		return
	if not await _wait(2.8):
		return
	_tire(1.8)


# ---------------------------------------------------------------- desafio de la cura
## TRES REGLAS: como los clones de la reina; la real es la que proyecta sombra.
func ch_reglas() -> void:
	await _ch_clones(3)
