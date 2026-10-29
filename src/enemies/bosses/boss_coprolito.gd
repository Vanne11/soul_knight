extends BossAltBase

## EL COPROLITO (jefe de LA PUERTA TRASERA, reino secreto del Perineo; id "coprolito") - usa el MOTOR DINAMICO (dynamic = true).
## Un fosil enorme, solemne y ridiculo: "llevo aqui desde el Cretacico". Caca petrificada con monoculo y barba
## de musgo, hecha de dibujo animado (nada realista). Tema educativo: no aguantarse, fibra y agua, el estrenimiento.
## IDENTIDAD "ESTRATOS Y TAPON" (J2):
## - SE AGRIETA: cada fase se parte mas (arte _p2/_p3) y al cambiar de fase suelta un anillo de FRAGMENTOS FOSILES.
## - TAPON: una roca (CoprolitoTapon) que se atora en la sala, tapa el paso y las balas y se va hinchando; si no la
##   rompes a tiros antes de ~7 s revienta en esquirlas. Romperla da "¡Alivio!" y a veces un corazon.
## - TEMBLOR SISMICO: franjas de temblor que cruzan la sala (avisan 0,9 s); la primera cae sobre ti.
## Ataques (avisos >= 0,55 s):
## - FOSILES: lluvia de fragmentos (circulos avisados que al caer sueltan esquirlas en cruz);
## - TEMBLOR: franjas sismicas; TAPON: ver arriba; ESQUIRLAS (abanico); EMBESTIDA (fase 2+): rueda como roca;
## - GUIJARROS: llama esbirros (piedritas que avisan y revientan en cruz; enemy_guijarro.gd).
## - Pasivo: un fragmento cae donde vas (aviso 0,7 s) mientras camina.
## Cura (2 cargas): FIBRA (romper galletas integrales) y AGUA (tocar 4 vasos antes de que acabe el tiempo).
## Frases del narrador: bosscoprolito_<intro|phase2|phase3|death|after> (assets/data/narrator/puerta_trasera.json).

const STONE := Color(0.82, 0.66, 0.46)
const HP_MULT := 0.7
const GUIJARRO := preload("res://src/enemies/enemy_guijarro.tscn")
const BASE_SPEED := [100.0, 120.0, 140.0]
const BASE_CAPS := [0.85, 0.7, 0.6]
## Ataque -> animacion de cuadros (BossAnimator busca attack_<x> / release_<x>).
const ANIM := {
	&"atk_temblor": "temblor", &"atk_fosiles": "fosiles", &"atk_tapon": "tapon", &"atk_llamar": "llamar",
}

var _frag_t := 3.0


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = STONE
	move_speed = BASE_SPEED[0]
	keep_min = 110.0
	keep_max = 200.0
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
	BossAnimator.attach(self)  # arte definitivo 176x184 (tools/gen_coprolito_art.py): cuadros nuevos + animacion por codigo


## El golpe ocurre al terminar el aviso: el animador pasa de attack_<x> a release_<x> justo ahi.
func _tele(secs: float, col := Color(2.0, 2.0, 0.9), shake := 2.0, on_frame := Callable()) -> bool:
	var ok: bool = await super(secs, col, shake, on_frame)
	if ok:
		attack_released.emit(_last_attack)
	return ok


## Frases del narrador: bosscoprolito_<evento>.
func _say(suffix: String) -> void:
	var key := "bosscoprolito_" + suffix
	if Narrator.has_lines(key):
		Narrator.say(key)


func _pick_attack() -> StringName:
	var a := super()
	set_meta("atk", str(ANIM.get(a, String(a).trim_prefix("atk_"))))
	return a


func _attack_pool() -> Array:
	var pool: Array
	match current_phase:
		1:
			pool = [&"atk_fan", &"atk_fosiles", &"atk_temblor", &"atk_llamar"]
		2:
			pool = [&"atk_fan", &"atk_fosiles", &"atk_temblor", &"atk_tapon", &"atk_llamar", &"atk_charge"]
		_:
			pool = [&"atk_fosiles", &"atk_temblor", &"atk_temblor", &"atk_tapon", &"atk_tapon", &"atk_llamar", &"atk_charge"]
	if _guijarros() >= current_phase + 1:
		pool = pool.filter(func(x): return x != &"atk_llamar")
	if _tapones() > 0:  # uno a la vez: si no, la sala se tapa
		pool = pool.filter(func(x): return x != &"atk_tapon")
	return pool


func _guijarros() -> int:
	return get_tree().get_nodes_in_group("guijarro_coprolito").size()


func _tapones() -> int:
	return get_tree().get_nodes_in_group("coprolito_tapon").size()


func _challenges() -> Array:
	return [&"ch_fibra", &"ch_vasos"]


func _channel_color() -> Color:
	return STONE


func _on_phase(n: int) -> void:
	_float_text(tr("COPRO_PHASE_%d" % n), STONE)
	if n >= 2:  # se agrieta: suelta un anillo de fragmentos fosiles (lento: se ve venir)
		_crack_ring.call_deferred(n)  # esto corre dentro de una colision de bala: las balas nuevas van diferidas


func _crack_ring(n: int) -> void:
	if state == State.DEAD or not is_inside_tree():
		return
	_fire_ring(8 + 2 * n, 150.0, RNG.randf_range(0.0, TAU), 0.0, 0.0, 0.4, STONE)
	Sound.play("crack")


func _on_death() -> void:
	_free_tapones()


func _reset_idle() -> void:
	pass


func _reset_fx() -> void:
	super()
	animated_sprite.visible = true


func _free_tapones() -> void:
	for t in get_tree().get_nodes_in_group("coprolito_tapon"):
		if is_instance_valid(t):
			t.queue_free()


## Todo peligro del Coprolito se ve como peligro (borde rojo oscuro, franjas).
func _add_hazard(z: BossZone) -> BossZone:
	if z.style == BossZone.Style.NORMAL:
		z.style = BossZone.Style.TOXIC
	return super(z)


func _tick(delta: float) -> void:
	if state in [State.INTRO, State.TRANSITION, State.DEAD] or target == null:
		return
	var ph := clampi(current_phase, 1, 3) - 1
	move_speed = BASE_SPEED[ph] * (1.35 if _furia else 1.0)
	if state != State.IDLE or _channeling:
		return
	_frag_t -= delta
	if _frag_t <= 0.0:  # fragmento suelto mientras camina: circulo avisado 0,7 s donde vas a estar
		_frag_t = [3.8, 3.2, 2.6][ph]
		var lead: Vector2 = target.global_position + (target.velocity * 0.5 if "velocity" in target else Vector2.ZERO)
		var z := BossZone.circle(clamp_to_arena(lead, 40.0), 46.0, 0.7, 0.2, damage * 0.7, STONE)
		z.went_active.connect(func(): Sound.play("crack"))
		_add_hazard(z)


# ---------------------------------------------------------------- FOSILES
## Lluvia de fragmentos: circulos avisados (el primero sobre ti); al caer sueltan esquirlas en cruz.
func atk_fosiles() -> void:
	var n := 2 + current_phase
	if not await _tele(0.8, Color(2.2, 1.8, 1.2), 2.0):
		return
	_float_text(tr("COPRO_FOSILES"), STONE)
	for i in n:
		var p: Vector2 = target.global_position + (Vector2.ZERO if i == 0 else Vector2(RNG.randf_range(-110, 110), RNG.randf_range(-110, 110)))
		p = clamp_to_arena(p, 40.0)
		var z := BossZone.circle(p, 58.0, 0.9, 0.22, damage * 1.0, STONE)
		z.went_active.connect(func():
			HitFx.shake(0.2)
			Sound.play("crack")
			var base := RNG.randf_range(0.0, TAU)
			for k in 4:
				_fire_from(p, base + k * TAU / 4.0, 190.0, 0.4, STONE, 3.0))
		_add_hazard(z)
		if not await _wait(0.4):
			return
	if not await _wait(1.1):
		return
	_tire(0.9)


# ---------------------------------------------------------------- TEMBLOR SISMICO
## Franjas de temblor que cruzan la sala, una tras otra (la primera sobre ti). Sal de la franja.
func atk_temblor() -> void:
	var a := arena().grow(-10.0)
	var horizontal := RNG.randf() < 0.5  # franjas horizontales (varian en y) o verticales
	var n := 2 + current_phase
	var thick := 62.0
	if not await _tele(0.8, Color(2.2, 1.8, 1.2), 3.0):
		return
	_float_text(tr("COPRO_TEMBLOR"), STONE)
	var lo := (a.position.y if horizontal else a.position.x) + thick * 0.5
	var hi := (a.end.y if horizontal else a.end.x) - thick * 0.5
	var used: Array = []
	for i in n:
		var c: float
		if i == 0:
			c = clampf(target.global_position.y if horizontal else target.global_position.x, lo, hi)
		else:
			c = RNG.randf_range(lo, hi)
			for tries in 6:
				if used.all(func(u): return absf(u - c) > thick * 1.3):
					break
				c = RNG.randf_range(lo, hi)
		used.append(c)
		var z: BossZone
		if horizontal:
			z = BossZone.rect(Vector2(a.get_center().x, c), Vector2(a.size.x, thick), 0.0, 0.9, 0.35, damage * 0.9, STONE)
		else:
			z = BossZone.rect(Vector2(c, a.get_center().y), Vector2(thick, a.size.y), 0.0, 0.9, 0.35, damage * 0.9, STONE)
		z.one_hit = true
		z.fade = 0.25
		z.went_active.connect(func():
			HitFx.shake(0.25)
			Sound.play("crack"))
		_add_hazard(z)
		if not await _wait(0.5):
			return
	if not await _wait(1.2):
		return
	_tire(1.0)


# ---------------------------------------------------------------- TAPON
## "El tapon": se atora una roca (2 / 3 / 3 segun la fase) que tapa el paso y revienta si no la rompes.
func atk_tapon() -> void:
	if not await _tele(1.0, Color(2.2, 1.7, 1.1), 3.0):
		return
	var n := 2 if current_phase < 3 else 3
	var pts: Array[Vector2] = []
	var tries := 0
	while pts.size() < n and tries < 80:
		tries += 1
		var p := arena_point(110.0)
		if p.distance_to(target.global_position) < 130.0 or p.distance_to(global_position) < 110.0 \
				or pts.any(func(q): return q.distance_to(p) < 160.0):
			continue
		pts.append(p)
	_float_text(tr("COPRO_TAPON"), STONE)
	Sound.play("crack")
	HitFx.shake(0.2)
	for p in pts:
		var t := CoprolitoTapon.new()
		t.max_health = 22.0 + _floor * 2.0
		t.life = 7.5
		t.show_bar = true
		t.enemy_name = tr("COPRO_TAPON_NAME")
		t.broken.connect(_on_tapon_broken)
		t.expired.connect(_on_tapon_expired)
		_spawn_container().add_child(t)
		t.global_position = _on_floor(p)
	if not await _wait(0.6):
		return
	_tire(1.2)


func _on_tapon_broken(t: BossBreakable) -> void:
	if not is_instance_valid(t) or state == State.DEAD:
		return
	_float_text(tr("COPRO_ALIVIO"), Color("a8e6a1"), t.global_position - global_position + Vector2(0, -60))
	Sound.play("pickup")
	if RNG.randf() < 0.3:
		var drop := ITEM_PICKUP_SCENE.instantiate()
		drop.item_id = "health_small"
		var dc := _drop_container()
		drop.position = RoomUtil.snap_drop(dc, dc.to_local(t.global_position))
		dc.add_child.call_deferred(drop)


## Reventon: anillo de esquirlas + un circulo avisado debajo. (Con la sala ya cambiando: se avisa 0,4 s.)
func _on_tapon_expired(t: BossBreakable) -> void:
	if not is_instance_valid(t) or state == State.DEAD:
		return
	var pos := t.global_position
	var z := BossZone.circle(pos, 84.0, 0.4, 0.25, damage * 1.0, STONE)
	z.went_active.connect(func():
		HitFx.shake(0.25)
		Sound.play("crack")
		var base := RNG.randf_range(0.0, TAU)
		for k in 8:
			_fire_from(pos, base + k * TAU / 8.0, 170.0, 0.45, STONE, 3.0))
	_add_hazard(z)


# ---------------------------------------------------------------- GUIJARROS
## Llama guijarros (1 / 2 / 3 segun la fase).
func atk_llamar() -> void:
	if not await _tele(0.8, Color(2.2, 1.8, 1.2), 2.0):
		return
	var pts: Array = []
	for i in current_phase:
		pts.append(clamp_to_arena(global_position + Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * 90.0, 50.0))
	_float_text(tr("COPRO_CALL"), STONE)
	_spawn_minions(pts, 12.0 + _floor * 2.0, 6.0 + _floor * 1.5, tr("GUIJARRO_NAME"), GUIJARRO)
	Sound.play("crack")
	HitFx.shake(0.15)
	await _wait(0.4)


# ---------------------------------------------------------------- desafios de la cura
## FIBRA: cinco galletas integrales vagan por la sala. Rompelas a tiros ("a comer fibra").
func ch_fibra() -> void:
	await _ch_break(5, "cookie", {"hp": 12.0, "speed": 60.0, "limit": 13.0})


## AGUA: cuatro vasos de agua repartidos; tocalos todos antes de que se acabe el tiempo.
func ch_vasos() -> void:
	await _ch_touch(_spread_points(4, 160.0), "cup", {"limit": 12.0})
