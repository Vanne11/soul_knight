extends EnemyBoss

## SU PUDOROSIDAD, LA HOJA DE PARRA (piso 5, Palacio de la Censura; jefe final) - JEFE DINAMICO
## (Plan 3 / J2+): el mas dificil. Motor dinamico de enemy_boss.gd (dynamic = true): reposo corto,
## avisos acotados por fase, combos, defensa durante la cura, cuaderno del jugador y [boss-stats].
## DOS FORMAS, UNA SOLA PELEA:
##  1) LA HOJA: camina, censura la sala. Barras de censura, parches de PIXELES (esconden balas,
##     nunca al heroe: BossZone deja un hueco alrededor tuyo), escudo de hojas (invulnerable
##     hasta romperlas), REJA de barras (firma de la fase 3) y pantalla gris en fase 3. Al
##     morir NO termina: cae, suena la victoria falsa, caen corazones, y...
##  2) LA PARRA ENTERA ("¿Creiste que era solo una hoja?"): enorme y enraizada en el centro, barra
##     de vida NUEVA y mas grande. Latigazos de enredadera, raices bajo tus pies, censura de media
##     sala, brotes de hojitas y, en fase 3, enredaderas que ocupan los bordes y la achican.
##     Usa el cuaderno a fondo ("Ya te vi pelear, ahora te censuro mejor"). La victoria de verdad
##     llega solo al matarla.
## ESBIRROS: hojitas censoras (enemy_hojita_censora.gd), con parche de pixeles propio.
## CURAS (max 2 por forma): el jefe se defiende; error = castigo; cortada = aturdida + dano.

const LEAFG := Color(0.55, 0.9, 0.45)
const INK := Color(0.9, 0.9, 0.95)
const HOJITA := preload("res://src/enemies/enemy_hojita_censora.tscn")
const PARRA_FRAMES := preload("res://assets/sprites/enemies/palacio/hoja_de_parra/parra_sprite_frames.tres")
## Balance (sin medir con el bot, ver notas): la Hoja vale ~1.7 Cera y la Parra un 30% mas que la Hoja.
const HP_MULT := 0.5
const PARRA_HP_MULT := 1.3
const BIG := [&"atk_barras", &"atk_reja", &"atk_censura_mitad", &"atk_estrangula"]
const HOJITA_CAP := [2, 3, 4]
const BAND_W := 56.0

var form := 1
var notebook := BossNotebook.new()
var bot_safe: Variant = null
var _shield: BossZone = null
var _leaves: Array = []
var _leaf_angle := 0.0
var _leaves_total := 0
var _leaves_broken := 0
var _grey_layer: CanvasLayer = null
var _grey_mat: ShaderMaterial = null
var _bubble_up := false
var _lock_ang := 0.0
var _walk := 0.0
var _spit_t := 3.0
var _spit_warn := 0.0
var _threat_hold := 0.0
var _rage_t := 0.0
var _close_t := 0.0
var _punish := false
var _wave_t := 9.0
var _def_t := 1.0
var _trap_cd := 0.0
var _pat_text_t := {}
var _no_move_def := false
var _band_t := -1.0
var _band_sides: Array = []
var _band_zones := {}
var _hoja_hp := 0.0
var _reviving := false


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = LEAFG
	move_speed = 110.0
	keep_min = 190.0
	keep_max = 290.0
	rest_min = 0.45
	rest_max = 0.8
	bullet_speed = 290.0
	tele_caps = [0.8, 0.65, 0.55]
	max_health *= HP_MULT
	current_health = max_health
	_hoja_hp = max_health
	_emit_health()
	_channels_total = 2
	_channels_left = 2
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	notebook.pattern_detected.connect(_on_pattern)
	telegraph_started.connect(_on_telegraph)
	BossAnimator.attach(self)  # arte definitivo 156x180 (tools/gen_parra_art2.py): cuadros nuevos + animacion por codigo


func _attack_pool() -> Array:
	var pool: Array
	if form == 1:
		match current_phase:
			1:
				pool = [&"atk_abanico", &"atk_rafaga", &"atk_barras", &"atk_escudo", &"atk_brotes"]
			2:
				pool = [&"atk_abanico", &"atk_rafaga", &"atk_barras", &"atk_pixelado", &"atk_escudo", &"atk_brotes", &"atk_barras"]
			_:
				pool = [&"atk_reja", &"atk_pixelado", &"atk_barras", &"atk_rafaga", &"atk_escudo", &"atk_reja", &"atk_brotes"]
	else:
		match current_phase:
			1:
				pool = [&"atk_latigazo", &"atk_raices", &"atk_brotes", &"atk_latigazo", &"atk_abanico"]
			2:
				pool = [&"atk_latigazo", &"atk_raices", &"atk_censura_mitad", &"atk_brotes", &"atk_abanico", &"atk_raices"]
			_:
				pool = [&"atk_estrangula", &"atk_censura_mitad", &"atk_raices", &"atk_latigazo", &"atk_brotes", &"atk_estrangula"]
	if _leaves_alive() > 0:
		pool = pool.filter(func(x): return x != &"atk_escudo")
	if _hojitas() >= HOJITA_CAP[current_phase - 1]:
		pool = pool.filter(func(x): return x != &"atk_brotes")
	return pool


func _pick_attack() -> StringName:
	if _punish:
		_punish = false
		_close_t = 0.0
		_combo_left = 0
		return &"atk_tapar"
	var a := super()
	if a in BIG:
		_combo_left = 0
	return a


func _combo_len() -> int:
	if form == 2:
		return RNG.randi_range(0, 1 if current_phase < 3 else 2)
	return RNG.randi_range(0, 1) if current_phase >= 2 else 0


func _combo_next() -> StringName:
	var light: Array = [&"atk_abanico", &"atk_rafaga"] if form == 1 else [&"atk_latigazo", &"atk_raices", &"atk_abanico"]
	light = light.filter(func(x): return x != _last_attack)
	return light[RNG.randi_range(0, light.size() - 1)]


func _challenges() -> Array:
	if form == 2:
		return [&"ch_achica", &"ch_secuencia"]
	return [&"ch_burbuja", &"ch_clones_hojas", &"ch_apagon_censurado"]


func is_suck_immune() -> bool:
	return _bubble_up


func _channel_color() -> Color:
	return LEAFG


func _muzzle() -> Vector2:
	return global_position + Vector2(0, -170 if form == 2 else -50)


func _speed() -> float:
	return move_speed * (1.25 if _rage_t > 0.0 else 1.0)


func _ts(x: float) -> float:
	return minf(x, tele_caps[clampi(current_phase, 1, 3) - 1])


## En la forma 2 la planta lo dibuja todo como enredadera espinosa (estilo VINE).
func _add_hazard(z: BossZone) -> BossZone:
	if form == 2 and z.style == BossZone.Style.NORMAL:
		z.style = BossZone.Style.VINE
	return super(z)


## Donde estara el jugador cuando llegue una bala de velocidad `spd` (prediccion).
func _lead(spd: float, k := 0.9) -> Vector2:
	var p: Vector2 = target.global_position
	var v := Vector2.ZERO
	if target is CharacterBody2D:
		v = (target as CharacterBody2D).velocity
	var t := minf(p.distance_to(_muzzle()) / spd, 0.8)
	return p + v * t * k


func _say(suffix: String) -> void:
	if form == 2 and suffix.begins_with("phase"):
		return  # las frases de fase son de la Hoja; la Parra tiene los suyos (rotulos)
	super(suffix)


func _on_phase(n: int) -> void:
	_drop_shield()
	_leaves.clear()
	_wave_t = 3.0
	if form == 1:
		move_speed = [110.0, 135.0, 160.0][n - 1]
		if n >= 3:
			_grey_screen(true)
	elif n == 3:
		_band_t = 3.0
		_float_text(tr("PARRA_BANDS_START"), Color("9ad85a"), Vector2(0, -230))


func _on_death() -> void:
	_drop_shield()
	_grey_screen(false)
	_clear_bands()


func _exit_tree() -> void:
	super()
	if is_instance_valid(_grey_layer):
		_grey_layer.queue_free()


func _hit_source() -> String:
	var tp: Vector2 = target.global_position
	for h in get_tree().get_nodes_in_group("hojita_censora"):
		if is_instance_valid(h) and h.global_position.distance_to(tp) < 400.0:
			return "bala_hojita"
	return "bala_suelta"


func _is_threatening() -> bool:
	return state == State.ATTACK or (state == State.IDLE and _threat_hold > 0.0)


func _idle_move(delta: float) -> void:
	if form == 2:
		velocity = Vector2.ZERO  # enraizada
		return
	if current_phase < 3:
		# presiona: rodea y se acerca; si siempre la rodeas igual, se adelanta para cortarte el paso
		var op := notebook.orbit_pattern()
		if not op.is_empty():
			var to_t: Vector2 = target.global_position - global_position
			var tang := to_t.orthogonal().normalized() * (-1.0 if op.dir == &"horario" else 1.0)
			if to_t.length() > 150.0:
				velocity = (to_t.normalized() + tang * 0.9).normalized() * _speed()
				return
		super(delta)
		velocity = velocity.normalized() * _speed()
		return
	# Fase final: no te suelta.
	var to_t2: Vector2 = target.global_position - global_position
	velocity = to_t2.normalized() * _speed() if to_t2.length() > 110.0 else Vector2.ZERO


# ---------------------------------------------------------------- pasivos y presion
func _tick(delta: float) -> void:
	if state in [State.INTRO, State.DEAD]:
		return
	notebook.update(delta, target, self, arena())
	_rage_t = maxf(0.0, _rage_t - delta)
	_threat_hold = maxf(0.0, _threat_hold - delta)
	_trap_cd = maxf(0.0, _trap_cd - delta)
	_leaves_tick(delta)
	if _hojitas() > 0:
		_threat_hold = maxf(_threat_hold, 0.3)
	if state == State.TRANSITION:
		return
	_wave_logic(delta)
	_band_logic(delta)
	# castigo si te pegas mucho rato
	var near := 210.0 if form == 2 else 115.0
	if state == State.IDLE and target.global_position.distance_to(global_position) < near:
		_close_t += delta
		if _close_t > 1.7 and not _punish:
			_punish = true
			_timer = minf(_timer, 0.05)
	else:
		_close_t = maxf(0.0, _close_t - delta * 0.7)
	# ataca mientras camina (solo la Hoja)
	if form == 1 and state == State.ATTACK and _walk > 0.0 and not _channeling:
		var to_t: Vector2 = _lead(300.0, 0.6) - global_position
		velocity = to_t.normalized() * _speed() * _walk if to_t.length() > 150.0 else to_t.orthogonal().normalized() * _speed() * _walk * 0.6
	# hojita suelta con aviso corto (solo en reposo: en ataque ya tiene sus avisos)
	if state == State.IDLE:
		_spit_t -= delta * (1.5 if _rage_t > 0.0 else 1.0)
		if _spit_warn > 0.0:
			_spit_warn -= delta
			animated_sprite.modulate = Color(1.8, 2.2, 1.4) if int(_spit_warn * 24.0) % 2 == 0 else Color.WHITE
			if _spit_warn <= 0.0:
				animated_sprite.modulate = Color.WHITE
				var spd: float = [230.0, 270.0, 300.0][RNG.randi_range(0, 2)]
				var ang := (_lead(spd) - _muzzle()).angle()
				for k in (1 if form == 1 else 2):
					_fire(ang + (k - (0.5 if form == 2 else 0.0)) * 0.16, spd, 0.5, LEAFG)
				_threat_hold = 1.5
				_spit_t = RNG.randf_range(4.0, 5.4) / (1.0 + 0.2 * (current_phase - 1))
		elif _spit_t <= 0.0:
			_spit_warn = 0.5


func _reset_idle() -> void:
	_walk = 0.0
	bot_safe = null


# ---------------------------------------------------------------- pantalla gris
func _grey_screen(on: bool) -> void:
	if on and not is_instance_valid(_grey_layer):
		_grey_layer = CanvasLayer.new()
		_grey_layer.layer = 1
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grey_mat = ShaderMaterial.new()
		_grey_mat.shader = load("res://src/shaders/screen_grey.gdshader")
		_grey_mat.set_shader_parameter("amount", 0.0)
		rect.material = _grey_mat
		_grey_layer.add_child(rect)
		var main := get_tree().get_first_node_in_group("main")
		var host: Node = main if main else get_tree().current_scene
		host.add_child(_grey_layer)
		host.move_child(_grey_layer, mini(1, host.get_child_count() - 1))  # tras el mundo, antes del HUD (la vida siempre se ve)
		create_tween().tween_property(_grey_mat, "shader_parameter/amount", 0.94, 1.2)
	elif not on and is_instance_valid(_grey_layer):
		var layer := _grey_layer
		var tw := layer.create_tween()
		tw.tween_property(_grey_mat, "shader_parameter/amount", 0.0, 0.5)
		tw.tween_callback(layer.queue_free)
		_grey_layer = null


# ---------------------------------------------------------------- la segunda forma
## La Hoja "muere": NO emite la muerte (la sala no se libera). Cae, victoria falsa, corazones y revive.
func die(killer: Node = null) -> void:
	if form == 1 and state != State.DEAD:
		_begin_revive()
		return
	super(killer)


func _begin_revive() -> void:
	_reviving = true
	_ge.game_event.emit("hoja_cae")  # medallas: la Hoja cae (la Parra entera viene despues)
	_cancel_attack()
	_gen += 1
	state = State.INTRO  # invulnerable y quieta mientras dura la secuencia (take_damage lo ignora)
	_timer = 999.0
	invuln = false
	current_health = 1.0  # > 0: la sala NO debe darlo por muerto (red de seguridad de room_director)
	_ge.boss_health_changed.emit(enemy_name, 0.0, max_health)  # la barra desaparece: "ganaste"
	_clear_bullets()
	_drop_shield()
	_leaves.clear()
	_grey_screen(false)
	_wave_t = 999.0
	for m in get_tree().get_nodes_in_group("boss_minion"):
		if is_instance_valid(m) and m.has_method("die"):
			m.die(null)
	HitFx.shake(0.9)
	HitFx.hitstop()
	animated_sprite.modulate = Color.WHITE
	animated_sprite.play("death")
	_revive_sequence()


## Pausa de la secuencia. false = el jefe ya no esta (fin de partida).
func _seq_wait(secs: float) -> bool:
	if not is_inside_tree():
		return false
	await get_tree().create_timer(secs, true, true).timeout
	return is_inside_tree() and state != State.DEAD


func _revive_sequence() -> void:
	if not await _seq_wait(1.5):
		return
	_banner(tr("PARRA_FALSE_WIN"), Color("ffe08a"), 36, Vector2(0, -200))
	Sound.play("puzzle_solve")
	_drop_hearts()
	if not await _seq_wait(2.2):
		return
	_banner(tr("PARRA_NOT_A_LEAF"), Color("9ad85a"), 30, Vector2(0, -200))
	Sound.play("suck")
	HitFx.shake(0.6)
	if not await _seq_wait(1.9):
		return
	_become_parra()


## Cae un tanto de corazones entre formas: la pelea larga no te castiga por larga.
func _drop_hearts() -> void:
	for id in ["health_large", "health_small", "health_small"]:
		var pickup = ITEM_PICKUP_SCENE.instantiate()
		pickup.item_id = id
		var cont := _drop_container()
		pickup.position = RoomUtil.snap_drop(cont, cont.to_local(global_position + Vector2(RNG.randf_range(-110, 110), RNG.randf_range(10, 90))))
		cont.add_child.call_deferred(pickup)


func _update_animation() -> void:
	if not _reviving:
		super()


func _become_parra() -> void:
	_reviving = false
	form = 2
	current_phase = 1
	max_health = _hoja_hp * PARRA_HP_MULT
	current_health = max_health
	enemy_name = tr("BOSS_PARRA_NAME")
	tele_caps = [0.7, 0.6, 0.5]
	move_speed = 0.0
	animated_sprite.flip_h = false
	$CollisionShape2D.scale = Vector2(1.5, 1.0)
	$Hurtbox.position = Vector2(0, -120)
	$Hurtbox.scale = Vector2(1.7, 1.7)
	var shadow := get_node_or_null("ContactShadow") as Node2D
	if shadow != null:
		shadow.scale *= 1.7
	(get_node(BossAnimator.NAME) as BossAnimator).rebase(PARRA_FRAMES)  # arte de 240x264 a escala 1 (tools/gen_parra_art2.py)
	# enraizada en el centro de la sala
	var c := _on_floor(arena().get_center())
	create_tween().tween_property(self, "global_position", c, 0.9)
	# barra NUEVA (sorpresa) y curas nuevas
	_channels_total = 2
	_channels_left = 2
	_chan_idx = 0
	_chan_cd = 8.0
	_chan_pending = false
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	_emit_health()
	_banner(tr("PARRA_REVIVES"), Color("ff8ad8"), 34, Vector2(0, -260))
	HitFx.shake(0.8)
	Sound.play("crack")
	_wave_t = 6.0
	_spit_t = 4.0
	_close_t = 0.0
	_last_attack = &""
	_timer = 1.4
	get_tree().create_timer(1.4, true, true).timeout.connect(func():
		if is_instance_valid(self) and state != State.DEAD:
			_float_text(tr("PARRA_SEEN_YOU"), Color("ff5a8a"), Vector2(0, -240)))


## Rotulo grande (arriba del jefe, estilo "numero grande") para los momentos clave de la pelea.
func _banner(text: String, col: Color, size: int, offset: Vector2) -> void:
	var mgr = get_tree().get_first_node_in_group("floating_text_mgr")
	if mgr != null:
		mgr.spawn_styled(global_position + offset, text, col, size)


# ---------------------------------------------------------------- esbirros (hojitas censoras)
func _hojitas() -> int:
	return get_tree().get_nodes_in_group("hojita_censora").size()


func _wave_logic(delta: float) -> void:
	if state in [State.TRANSITION, State.INTRO]:
		return
	_wave_t -= delta
	if _wave_t > 0.0:
		return
	var n: int = ([1, 2, 2] if form == 1 else [2, 3, 3])[current_phase - 1]
	_wave_t = ([22.0, 18.0, 15.0] if form == 1 else [16.0, 14.0, 12.0])[current_phase - 1]
	if _channeling:
		_wave_t = 4.5
		n = mini(n, 2)
	n = mini(n, HOJITA_CAP[current_phase - 1] - _hojitas())
	if n > 0:
		_summon(n)


## Invoca `n` hojitas censoras con aviso (circulo verde 0.7 s) lejos de ti.
func _summon(n: int) -> void:
	var spots: Array = []
	for i in n:
		var p := arena_point(70.0)
		for _try in 8:
			if p.distance_to(target.global_position) > 240.0:
				break
			p = arena_point(70.0)
		spots.append(p)
		_add_hazard(BossZone.circle(p, 30.0, 0.7, 0.05, 0.0, LEAFG))
	await get_tree().create_timer(0.75, true, true).timeout
	if state == State.DEAD or not is_inside_tree():
		return
	_spawn_minions(spots, 10.0 + 3.0 * current_phase + (4.0 if form == 2 else 0.0), damage * 0.35, tr("HOJITA_NAME"), HOJITA)
	for m in get_tree().get_nodes_in_group("hojita_censora"):
		if is_instance_valid(m):
			m.move_speed = 130.0 + 10.0 * current_phase
			m.add_collision_exception_with(self)
	Sound.play("enemy_shoot")


# ---------------------------------------------------------------- cuaderno del jugador
func _on_pattern(kind: StringName, detail: Variant) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_pat_text_t.get(kind, -99.0)) < 14.0:
		return
	_pat_text_t[kind] = now
	var head := ""
	if kind == &"dash":
		head = tr("PARRA_PAT_DASH") % tr("CERA_DIR_" + String(detail.dir).to_upper())
	elif kind == &"orbit":
		head = tr("PARRA_PAT_ORBIT") % tr("CERA_DIR_" + String(detail.dir).to_upper())
	if head == "":
		return
	_float_text(head, Color("ff5a8a"), Vector2(0, -230 if form == 2 else -190))
	var quip := "PARRA_PAT_%s_Q%d" % [String(kind).to_upper(), RNG.randi_range(1, 2)]
	get_tree().create_timer(1.4).timeout.connect(func():
		if state != State.DEAD:
			_float_text(tr(quip), LEAFG, Vector2(0, -200 if form == 2 else -160)))


## Al avisar un ataque: si siempre esquivas al mismo lado te pone ahi una raiz (forma 2) o un parche (forma 1).
func _on_telegraph(_secs: float) -> void:
	if _trap_cd > 0.0 or state != State.ATTACK or _channeling:
		return
	var dp := notebook.dash_pattern()
	if dp.is_empty() or RNG.randf() > (0.8 if form == 2 else 0.5):
		return
	_trap_cd = 2.5 if form == 2 else 4.5
	var at: Vector2 = clamp_to_arena(target.global_position + BossNotebook.dir_vector(dp.dir) * 135.0, 60.0)
	if form == 2:
		_root_at(at, 0.9, 3.0)
	else:
		var z := BossZone.rect(at, Vector2(140, 140), 0.0, 0.9, 4.0, 0.0, INK)
		z.style = BossZone.Style.PIXEL
		_add_hazard(z)


## Raiz que revienta bajo el suelo: aviso, estalla y deja una zona que quema un rato.
func _root_at(pos: Vector2, warn: float, burn: float) -> BossZone:
	var z := BossZone.circle(clamp_to_arena(pos, 40.0), 52.0, warn, burn, damage * 0.33, LEAFG)
	z.one_hit = false
	z.fade = 0.4
	return _add_hazard(z)


# ---------------------------------------------------------------- tiro con prediccion
func atk_abanico() -> void:
	_walk = 0.5
	var line := BossZone.rect(global_position, Vector2(300, 8), 0.0, _ts(0.65) + 0.05, 0.05, 0.0, LEAFG)
	_add_hazard(line)
	var track := func(left: float):
		if left > 0.2:
			_lock_ang = (_lead(300.0) - _muzzle()).angle()
		if is_instance_valid(line):
			line.global_position = _muzzle() + Vector2.RIGHT.rotated(_lock_ang) * 150.0
			line.rotation = _lock_ang
	if not await _tele(0.65, Color(1.8, 2.2, 1.2), 2.0, track):
		return
	_walk = 0.3
	var volleys := 1 + current_phase / 2
	for v in volleys:
		var shots := 3 + current_phase / 2 + (1 if current_phase == 3 else 0) + (2 if form == 2 else 0)
		for i in shots:
			_fire(_lock_ang + (i - (shots - 1) / 2.0) * 0.2, 380.0 if i % 2 == 0 else 300.0, 0.5, LEAFG)
		if v < volleys - 1 and not await _wait(0.4):
			return
	await _wait(0.2)


## Rafaga con prediccion: tiros rapidos y lentos hacia donde VAS a estar.
func atk_rafaga() -> void:
	_walk = 0.4
	var line := BossZone.rect(global_position, Vector2(300, 8), 0.0, _ts(0.5) + 0.05, 0.05, 0.0, LEAFG)
	_add_hazard(line)
	var track := func(left: float):
		if left > 0.2:
			_lock_ang = (_lead(320.0) - _muzzle()).angle()
		if is_instance_valid(line):
			line.global_position = _muzzle() + Vector2.RIGHT.rotated(_lock_ang) * 150.0
			line.rotation = _lock_ang
	if not await _tele(0.5, Color(1.8, 2.2, 1.2), 2.0, track):
		return
	_walk = 0.2
	for i in 3 + current_phase / 3:
		_fire(_lock_ang + RNG.randf_range(-0.04, 0.04), 320.0 if i % 2 == 0 else 260.0, 0.5, LEAFG)
		if not await _wait(0.2):
			return
	await _wait(0.15)


# ---------------------------------------------------------------- LA HOJA: barras de censura
func atk_barras() -> void:
	_walk = 0.0
	var n := 1 + current_phase
	if not await _tele(0.5, Color(0.5, 0.5, 0.7), 2.0):
		return
	var a := arena()
	var reach := a.size.length() * 1.1
	var used: Array[Vector2] = []
	for i in n:
		var kind := RNG.randi_range(0, 2 if current_phase >= 3 else 1)  # 0 horizontal, 1 vertical, 2 diagonal
		var rot := 0.0
		match kind:
			1:
				rot = PI * 0.5
			2:
				rot = PI * 0.25 * (1.0 if RNG.randf() < 0.5 else -1.0)
		var c: Vector2 = _lead(300.0, 0.7) if i == 0 else arena_point(60.0)
		for tries in 8:  # que las barras no se amontonen
			if used.all(func(u): return u.distance_to(c) > 170.0):
				break
			c = arena_point(60.0)
		used.append(c)
		var z := BossZone.rect(c, Vector2(reach, BAND_W), rot, _ts(0.9) + 0.05, 0.35, damage, INK)
		z.style = BossZone.Style.BAR
		z.one_hit = true
		z.fade = 0.3
		z.went_active.connect(func():
			HitFx.shake(0.2)
			Sound.play("crack"))
		_add_hazard(z)
		Sound.play("locked")
		if not await _wait(0.4):
			return
	if not await _wait(0.9):
		return
	_float_text(tr("BOSS_HOJA_BLUSH"), Color("ff9ec4"))
	_tire(1.1)


## FIRMA DE LA FASE 3 (Hoja): CENSURA TOTAL. Una reja de barras horizontales y luego otra de
## verticales, con huecos entre ellas: hay que dashear a un hueco. Despues se ruboriza (agotada).
func atk_reja() -> void:
	_walk = 0.0
	_float_text(tr("HOJA_FIRMA"), Color("ff9ec4"), Vector2(0, -190))
	if not await _tele(0.8, Color(0.5, 0.5, 0.7), 3.0):
		return
	var a := arena()
	for pass_n in 2:
		var horiz := pass_n == 0
		var span := a.size.y if horiz else a.size.x
		var warn := _ts(0.9) + 0.05
		var bars := 3
		var off := RNG.randf_range(-0.12, 0.12) * span
		for k in bars:
			var along := span * (k + 1.0) / (bars + 1.0) + off
			var z: BossZone
			if horiz:
				z = BossZone.rect(Vector2(a.get_center().x, a.position.y + along), Vector2(a.size.x * 1.05, BAND_W), 0.0, warn, 0.35, damage, INK)
			else:
				z = BossZone.rect(Vector2(a.position.x + along, a.get_center().y), Vector2(a.size.y * 1.05, BAND_W), PI * 0.5, warn, 0.35, damage, INK)
			z.style = BossZone.Style.BAR
			z.one_hit = true
			z.fade = 0.3
			z.went_active.connect(func():
				HitFx.shake(0.2)
				Sound.play("crack"))
			_add_hazard(z)
		Sound.play("locked")
		if not await _wait(warn + 0.45):
			return
	_float_text(tr("BOSS_HOJA_BLUSH"), Color("ff9ec4"))
	_tire(1.1)


# ---------------------------------------------------------------- pixelado (parches que esconden balas, no al heroe)
func atk_pixelado() -> void:
	_walk = 0.0
	var n := current_phase  # 2 en fase 2, 3 en fase 3
	var side := 190.0 + 20.0 * (current_phase - 2)
	# Se aparta al lado contrario de la sala para disparar a traves de los parches.
	var a := arena()
	var far := a.get_center() - (target.global_position - a.get_center()) * 0.6
	if not await _walk_to(clamp_to_arena(far, 110.0), 1.0):
		return
	if not await _tele(0.5, Color(0.7, 0.7, 0.9), 2.0):
		return
	for i in n:
		var c: Vector2 = clamp_to_arena(target.global_position + Vector2(RNG.randf_range(-130, 130), RNG.randf_range(-130, 130)), 80.0) if i == 0 else arena_point(100.0)
		var z := BossZone.rect(c, Vector2(side, side), 0.0, 0.9, 5.0, 0.0, INK)
		z.style = BossZone.Style.PIXEL
		z.fade = 0.5
		_add_hazard(z)
	Sound.play("locked")
	if not await _wait(1.0):
		return
	for k in 3:
		animated_sprite.play("attack")
		var base := (_lead(175.0, 0.6) - _muzzle()).angle()
		var shots := 7
		for j in shots:
			_fire(base + (j - (shots - 1) / 2.0) * 0.22, 175.0, 0.65, LEAFG)
		Sound.play("enemy_shoot")
		if not await _wait(0.8):
			return
	await _wait(0.3)


# ---------------------------------------------------------------- escudo de hojas
func atk_escudo() -> void:
	_walk = 0.0
	if not await _tele(0.7, Color(0.6, 2.0, 0.7), 2.0):
		return
	var n := 3 + current_phase
	_leaves.clear()
	_leaves_total = n
	_leaves_broken = 0
	_leaf_angle = RNG.randf_range(0.0, TAU)
	for i in n:
		var l := BossBreakable.new()
		l.kind = BossBreakable.Kind.LEAF
		l.enemy_name = "Hoja"
		l.max_health = 14.0 + _floor * 2.0
		l.life = 13.0
		l.contact_damage = damage * 0.4
		l.color = LEAFG
		_spawn_container().add_child(l)
		l.global_position = _muzzle()
		l.broken.connect(_on_leaf_broken)
		l.expired.connect(_on_leaf_expired)
		_leaves.append(l)
	invuln = true
	_drop_shield_zone()
	_shield = BossZone.circle(global_position, 80.0, 0.0, -1.0, 0.0, LEAFG)
	_shield.style = BossZone.Style.SHIELD
	_shield.follow = self
	_shield.follow_offset = Vector2(0, -60)
	_add_hazard(_shield)
	_float_text(tr("BOSS_HOJA_SHIELD"), LEAFG)
	Sound.play("enemy_shoot")


func _leaves_alive() -> int:
	var c := 0
	for l in _leaves:
		if is_instance_valid(l) and l.is_alive():
			c += 1
	return c


func _leaves_tick(delta: float) -> void:
	if _leaves.is_empty():
		return
	var alive := _leaves.filter(func(l): return is_instance_valid(l) and l.is_alive())
	if alive.is_empty():
		_leaves.clear()
		_drop_shield()
		return
	_leaf_angle += delta * (1.4 + 0.35 * current_phase)
	var r := 112.0 + 8.0 * current_phase
	var center := _muzzle()
	var room := find_owning_room()
	for i in alive.size():
		var ang: float = _leaf_angle + i * TAU / alive.size()
		var at := center + Vector2.RIGHT.rotated(ang) * r
		if room != null:
			at = room.clamp_global(at, 30.0)  # con la jefa junto a un muro las hojas salian del suelo
		alive[i].global_position = at


func _on_leaf_broken(_l: BossBreakable) -> void:
	_leaves_broken += 1
	_check_leaves_done(true)


func _on_leaf_expired(_l: BossBreakable) -> void:
	_check_leaves_done(false)


func _check_leaves_done(by_player: bool) -> void:
	await get_tree().process_frame  # que la hoja que cae salga ya del conteo
	if not is_instance_valid(self) or state == State.DEAD:
		return
	if _leaves_alive() > 0:
		return
	var had := invuln
	_drop_shield()
	if had and by_player and _leaves_broken >= _leaves_total and state != State.TRANSITION:
		_float_text(tr("BOSS_HOJA_BARE"), Color("ffe08a"))
		_stun(2.4)


func _drop_shield_zone() -> void:
	if is_instance_valid(_shield):
		_shield.queue_free()
	_shield = null


func _drop_shield() -> void:
	invuln = false
	_drop_shield_zone()


# ---------------------------------------------------------------- castigo al que se pega
func atk_tapar() -> void:
	_walk = 0.0
	var r := 205.0 if form == 2 else 135.0
	var w := _ts(0.55)
	var z := BossZone.circle(global_position, r, w + 0.05, 0.2, damage, INK)
	z.follow = self
	_add_hazard(z)
	if not await _tele(0.55, Color(0.6, 0.6, 0.9), 3.0):
		return
	HitFx.shake(0.25)
	if form == 2:
		var n := 10 + 2 * current_phase
		for i in n:
			_fire_from(_muzzle(), TAU * i / n, 230.0, 0.45, LEAFG, 3.0)
	await _wait(0.3)


# ---------------------------------------------------------------- LA PARRA: ataques de la forma 2
## Latigazos de enredadera: 2-3 lanes con prediccion (fijadas al avisar: justo), una tras otra.
func atk_latigazo() -> void:
	var n := 2 + (1 if current_phase == 3 else 0)
	for i in n:
		var ang := (_lead(500.0, 0.6) - _muzzle()).angle()
		var dirv := Vector2.RIGHT.rotated(ang)
		var ln := _ray_len(_muzzle(), dirv, 760.0)
		var warn := _ts(0.7) + 0.05
		var z := BossZone.rect(_muzzle() + dirv * ln * 0.5, Vector2(ln, 70.0), ang, warn, 0.25, damage, LEAFG)
		z.one_hit = true
		z.fade = 0.3
		_add_hazard(z)
		if not await _tele(0.7, Color(0.6, 2.0, 0.7), 2.0):
			return
		HitFx.shake(0.2)
		Sound.play("crack")
		if not await _wait(0.35):
			return
	await _wait(0.1)


## Raices que revientan bajo tus pies (y donde sueles caer tras un dash, si el cuaderno lo sabe).
func atk_raices() -> void:
	var n := 3 + current_phase
	var spot := notebook.dash_spot()
	if not await _tele(0.5, Color(0.6, 2.0, 0.7), 2.0):
		return
	for i in n:
		var p: Vector2 = _lead(250.0)
		if i == 1 and spot != Vector2.INF:
			p = spot
		elif i > 1:
			p = target.global_position + Vector2(RNG.randf_range(-170, 170), RNG.randf_range(-170, 170))
		_root_at(p, _ts(0.8), 0.3)
		Sound.play("enemy_shoot")
		if not await _wait(0.3):
			return
	await _wait(0.5)


## Brotes: invoca hojitas censoras (con aviso) y aprieta el hueco.
func atk_brotes() -> void:
	_walk = 0.0
	if not await _tele(0.6, Color(0.6, 2.0, 0.7), 2.0):
		return
	var n := mini(1 + current_phase, HOJITA_CAP[current_phase - 1] - _hojitas())
	if n > 0:
		_float_text(tr("PARRA_BROTES"), LEAFG, Vector2(0, -230 if form == 2 else -190))
		_summon(n)
	await _wait(0.9)


## CENSURA DE MEDIA SALA: la mitad donde estas (o donde sueles quedarte) se pixela; ella dispara
## abanicos lentos a traves. Los pixeles dejan un hueco grande alrededor del heroe y no tapan del todo.
func atk_censura_mitad() -> void:
	var a := arena()
	var horiz := a.size.x >= a.size.y
	var tp: Vector2 = target.global_position
	var zone := notebook.favorite_zone()
	if zone != "":
		var parts := zone.split(",")
		tp = a.position + Vector2((int(parts[0]) + 0.5) / 3.0 * a.size.x, (int(parts[1]) + 0.5) / 3.0 * a.size.y)
	var first := (tp.x < a.get_center().x) if horiz else (tp.y < a.get_center().y)
	var rect_size := Vector2(a.size.x * 0.5, a.size.y) if horiz else Vector2(a.size.x, a.size.y * 0.5)
	var c: Vector2
	if horiz:
		c = Vector2(a.position.x + rect_size.x * (0.5 if first else 1.5), a.get_center().y)
	else:
		c = Vector2(a.get_center().x, a.position.y + rect_size.y * (0.5 if first else 1.5))
	if zone != "":
		_float_text(tr("PARRA_CENSOR_ZONE"), Color("ff5a8a"), Vector2(0, -230))
	if not await _tele(0.7, Color(0.7, 0.7, 0.9), 2.0):
		return
	var z := BossZone.rect(c, rect_size, 0.0, 1.0, 5.5, 0.0, INK)
	z.style = BossZone.Style.PIXEL
	z.hero_clear = 95.0  # media sala censurada, pero te ves y ves lo cercano
	z.opacity = 0.72
	z.fade = 0.5
	_add_hazard(z)
	Sound.play("locked")
	if not await _wait(1.1):
		return
	for k in 3:
		animated_sprite.play("attack")
		var base := (_lead(190.0, 0.6) - _muzzle()).angle()
		var shots := 7 + current_phase
		for j in shots:
			_fire(base + (j - (shots - 1) / 2.0) * 0.2, 190.0, 0.6, LEAFG)
		Sound.play("enemy_shoot")
		if not await _wait(0.85):
			return
	await _wait(0.3)


## FIRMA DE LA FASE 3 (Parra): ESTRANGULAMIENTO. Dos muros de enredadera cruzan la sala de lado a
## lado, cada uno con un hueco lejos de ti: hay que dashear. Despues queda agotada.
func atk_estrangula() -> void:
	_float_text(tr("PARRA_FIRMA"), Color("ff5a8a"), Vector2(0, -260))
	if not await _tele(0.9, Color(0.6, 2.0, 0.7), 3.0):
		return
	var a := arena()
	var horiz := a.size.x >= a.size.y
	var spd := 260.0
	for k in 2:
		var tp: Vector2 = target.global_position
		var from_start := (tp.x > a.get_center().x) if horiz else (tp.y > a.get_center().y)
		if k == 1:
			from_start = not from_start
		var cross_lo := a.position.y if horiz else a.position.x
		var cross_hi := a.end.y if horiz else a.end.x
		var gap_half := 95.0
		var pc := tp.y if horiz else tp.x
		var gap_c := clampf(pc + (1.0 if RNG.randf() < 0.5 else -1.0) * RNG.randf_range(130.0, 210.0), cross_lo + gap_half + 20.0, cross_hi - gap_half - 20.0)
		bot_safe = Vector2(tp.x, gap_c) if horiz else Vector2(gap_c, tp.y)
		var travel := (a.size.x if horiz else a.size.y) - 70.0
		var secs := travel / spd
		var thick := 70.0
		for part in 2:
			var lo := cross_lo if part == 0 else gap_c + gap_half
			var hi := gap_c - gap_half if part == 0 else cross_hi
			if hi - lo < 10.0:
				continue
			var mid := (lo + hi) * 0.5
			var sgn := 1.0 if from_start else -1.0
			var z: BossZone
			if horiz:
				var x0 := (a.position.x + thick * 0.5) if from_start else (a.end.x - thick * 0.5)
				z = BossZone.rect(Vector2(x0, mid), Vector2(thick, hi - lo), 0.0, 0.95, secs, damage * 0.8, LEAFG)
				z.vel = Vector2(spd * sgn, 0.0)
			else:
				var y0 := (a.position.y + thick * 0.5) if from_start else (a.end.y - thick * 0.5)
				z = BossZone.rect(Vector2(mid, y0), Vector2(hi - lo, thick), 0.0, 0.95, secs, damage * 0.8, LEAFG)
				z.vel = Vector2(0.0, spd * sgn)
			z.fade = 0.3
			_add_hazard(z)
		if not await _wait(0.95 + secs + 0.2):
			bot_safe = null
			return
		bot_safe = null
	_tire(1.1)


# ---------------------------------------------------------------- enredaderas en los bordes (forma 2, fase 3)
## Una banda de enredadera por lado cada ~8 s (hasta 3): la sala se achica. Si una cura o un cambio de
## fase las borra, vuelven a brotar con aviso.
func _band_logic(delta: float) -> void:
	if form != 2 or current_phase < 3 or _band_t < 0.0:
		return
	_band_t -= delta
	if _band_t <= 0.0 and _band_sides.size() < 3:
		_band_t = 8.0
		var a := arena()
		var sides: Array = ["T", "B", "L", "R"]
		if a.size.x < 700.0:
			sides.erase("L")
			sides.erase("R")
		if a.size.y < 520.0:
			sides.erase("T")
			sides.erase("B")
		sides = sides.filter(func(s): return not _band_sides.has(s))
		if not sides.is_empty():
			_band_sides.append(sides[RNG.randi_range(0, sides.size() - 1)])
			_float_text(tr("PARRA_BANDS"), Color("9ad85a"), Vector2(0, -260))
	if state in [State.TRANSITION, State.INTRO]:
		return
	for s in _band_sides:
		if not is_instance_valid(_band_zones.get(s)):
			_band_zones[s] = _make_band(s)


func _make_band(side: String) -> BossZone:
	var a := arena()
	var pos: Vector2
	var sz: Vector2
	match side:
		"T":
			pos = Vector2(a.get_center().x, a.position.y + BAND_W * 0.5)
			sz = Vector2(a.size.x, BAND_W)
		"B":
			pos = Vector2(a.get_center().x, a.end.y - BAND_W * 0.5)
			sz = Vector2(a.size.x, BAND_W)
		"L":
			pos = Vector2(a.position.x + BAND_W * 0.5, a.get_center().y)
			sz = Vector2(BAND_W, a.size.y)
		_:
			pos = Vector2(a.end.x - BAND_W * 0.5, a.get_center().y)
			sz = Vector2(BAND_W, a.size.y)
	var z := BossZone.rect(pos, sz, 0.0, 1.2, -1.0, damage * 0.3, LEAFG)
	z.one_hit = false
	return _add_hazard(z)


func _clear_bands() -> void:
	for s in _band_zones:
		if is_instance_valid(_band_zones[s]):
			_band_zones[s].queue_free()
	_band_zones.clear()
	_band_sides.clear()
	_band_t = -1.0


# ---------------------------------------------------------------- la cura
func _cure_cut_stun() -> float:
	return 5.0


func _on_cure_cut() -> void:
	# premio: un buen mordisco de vida (sin saltarse de fase) ademas del aturdimiento largo
	var floor_hp := max_health * (PHASE2_AT if current_phase == 1 else (PHASE3_AT if current_phase == 2 else 0.02)) + 1.0
	var chunk := minf(max_health * 0.06, maxf(0.0, current_health - floor_hp))
	if chunk > 0.0:
		current_health -= chunk
		_emit_health()
		_ge.show_damage_number.emit(global_position + Vector2(0, -150), chunk, true)
	_float_text(tr("PARRA_CUT_BONUS"), Color("ffe08a"), Vector2(0, -230 if form == 2 else -190))


func _on_cure_done() -> void:
	_rage_t = 7.0
	_wave_t = minf(_wave_t, 2.0)
	_float_text(tr("PARRA_RAGE"), Color("ff5a8a"), Vector2(0, -230 if form == 2 else -190))


## Se defiende mientras canaliza: tiros a tu ruta, parches de pixeles sobre ti, hojitas y (forma 2)
## raices bajo tus pies. Siempre con aviso.
func _defend(dt: float) -> void:
	_def_t -= dt
	if form == 2:
		velocity = Vector2.ZERO
	elif not _no_move_def:
		var a := arena()
		var c := a.get_center() + Vector2(sin(_chan_t * 0.7) * a.size.x * 0.22, cos(_chan_t * 0.5) * a.size.y * 0.18)
		velocity = (c - global_position).limit_length(60.0)
	if _def_t > 0.0:
		return
	_def_t = [3.0, 2.6, 2.2][current_phase - 1]
	match RNG.randi_range(0, 2):
		0:
			var base := (_lead(280.0) - _muzzle()).angle()
			for i in 3:
				_fire(base + (i - 1) * 0.2, [260.0, 290.0, 310.0][current_phase - 1], 0.5, LEAFG)
		1:
			var z := BossZone.rect(clamp_to_arena(target.global_position, 70.0), Vector2(130, 130), 0.0, 0.9, 3.5, 0.0, INK)
			z.style = BossZone.Style.PIXEL
			_add_hazard(z)
		_:
			if form == 2:
				_root_at(_lead(250.0), 0.8, 2.5)
			elif _hojitas() < 3:
				_summon(1)


# ---------------------------------------------------------------- desafios de la cura
## BURBUJA: una burbuja de hojas la envuelve: refleja tus balas hacia ti y el vortice del
## Succionador no la arrastra. Tiene una abertura que gira; mete balas por ahi.
func ch_burbuja() -> void:
	var R := 125.0
	var need := 5
	var st := {"open": RNG.randf_range(0.0, TAU), "pass": 0, "omega": 1.9, "flip": 2.5}
	var half := 0.22
	_bubble_up = true
	var bub := _make_prop(_body_center(), Callable(), Callable(), st)
	bub.drawer = func(n):
		var o: float = st.open
		var segs := 36
		for k in segs:
			var a0 := o + half + (TAU - 2.0 * half) * k / segs
			var a1 := o + half + (TAU - 2.0 * half) * (k + 1) / segs
			var col := Color(0.45, 0.85, 0.4, 0.95) if k % 2 == 0 else Color(0.3, 0.7, 0.3, 0.95)
			n.draw_arc(Vector2.ZERO, R, a0, a1, 4, col, 14.0)
		n.draw_circle(Vector2.ZERO, R, Color(0.5, 1.0, 0.5, 0.08))
		# la abertura bien marcada
		var p0 := Vector2.RIGHT.rotated(o - half) * R
		var p1 := Vector2.RIGHT.rotated(o + half) * R
		n.draw_line(p0, p0 * 0.8, Color(1, 1, 1, 0.9), 4.0)
		n.draw_line(p1, p1 * 0.8, Color(1, 1, 1, 0.9), 4.0)
		n.draw_arc(Vector2.ZERO, R + 12.0, o - half, o + half, 8, Color(1, 1, 0.6, 0.9), 4.0)
	bub.updater = func(n, dt):
		n.global_position = _body_center()
		st.flip -= dt
		if st.flip <= 0.0:
			st.flip = RNG.randf_range(1.8, 3.4)
			st.omega = -st.omega
		st.open += st.omega * dt
		for c in target.get_parent().get_children():
			if not (c is PlayerBullet) or c.has_meta("hoja"):
				continue
			var d: Vector2 = c.global_position - n.global_position
			var r := d.length()
			if r < R + 12.0 and r > R - 40.0:
				c.set_meta("hoja", true)
				var heading := Vector2.RIGHT.rotated(c.rotation)
				if heading.dot(d) > 0.0:
					continue  # sale de la burbuja, no entra
				if absf(angle_difference(d.angle(), st.open)) < half:
					st.pass += 1
					_chan_prog = float(st.pass) / need
					Sound.play("pickup")
					if st.pass >= need:
						_chan_ok = true
				else:
					# bala que rebota en la burbuja: te la devuelve y le da tiempo a la cura
					var pos: Vector2 = c.global_position
					c.queue_free()
					_ch_extra += 0.4
					_fire_from(pos, (target.global_position - pos).angle(), 290.0, 0.35, Color(1, 1, 1), 4.0)
					Sound.play("enemy_hit")
	await _ch_loop(16.0, func(dt):
		# desesperada: huye de ti por la sala
		_flee(150.0, dt)
		# ayuda del bot: apuntar a donde estara la abertura cuando llegue la bala
		var flight: float = target.global_position.distance_to(_body_center()) / 500.0
		var oang: float = st.open + st.omega * flight
		var oc: Vector2 = _body_center() + Vector2.RIGHT.rotated(oang) * R
		var facing: bool = (oc - _body_center()).dot(target.global_position - _body_center()) > 0.0
		bot_aim_pos = oc if facing else null)
	_bubble_up = false
	velocity = Vector2.ZERO


func ch_apagon_censurado() -> void:
	await _ch_blackout(130.0, Color(0.02, 0.02, 0.04), 7, 52.0, 13.0)


## SALA QUE SE ACHICA: barras de censura cierran la sala hacia un boton. Llega a el antes de
## quedar encerrado (si te encierran no te mata: falla el desafio).
func ch_achica() -> void:
	var a := arena()
	var btn := a.get_center()
	var best_d := -1.0
	for k in 40:
		var p := arena_point(90.0)
		var dd := p.distance_to(target.global_position)
		if dd > best_d:
			best_d = dd
			btn = p
	var t_close := 4.2 if form == 2 else 4.4
	var warn := 1.0
	var bars := _make_prop(a.position, Callable(), Callable(), {"k": 0.0})
	bars.drawer = func(n):
		var k: float = n.data.k
		var sz := a.size
		var L := (btn.x - a.position.x) * k
		var T := (btn.y - a.position.y) * k
		var Rr := sz.x - (a.end.x - btn.x) * k
		var B := sz.y - (a.end.y - btn.y) * k
		var ink := Color(0.02, 0.02, 0.03, 0.93)
		if n.t < warn:
			# aviso: parpadea el recuadro al que se va a reducir la sala
			var pulse := 0.5 + 0.5 * sin(n.t * 20.0)
			var fx := (btn - a.position)
			n.draw_rect(Rect2(fx - Vector2(80, 80), Vector2(160, 160)), Color(1, 1, 1, 0.5 + 0.5 * pulse), false, 4.0)
			return
		n.draw_rect(Rect2(-60, -60, sz.x + 120, T + 60), ink)
		n.draw_rect(Rect2(-60, B, sz.x + 120, sz.y - B + 60), ink)
		n.draw_rect(Rect2(-60, T, L + 60, B - T), ink)
		n.draw_rect(Rect2(Rr, T, sz.x - Rr + 60, B - T), ink)
		n.draw_rect(Rect2(L, T, Rr - L, B - T), Color(1, 1, 1, 0.9), false, 4.0)
	bars.updater = func(n, dt):
		var k := clampf((n.t - warn) / t_close, 0.0, 1.0)
		n.data.k = k
		if n.t >= warn:
			var pp: Vector2 = target.global_position - a.position
			var L := (btn.x - a.position.x) * k
			var T := (btn.y - a.position.y) * k
			var Rr := a.size.x - (a.end.x - btn.x) * k
			var B := a.size.y - (a.end.y - btn.y) * k
			if not Rect2(L, T, Rr - L, B - T).grow(-2.0).has_point(pp):
				_chan_fail = true
				Sound.play("puzzle_fail")
	var button := _make_prop(btn, Callable(), Callable(), {})
	button.drawer = func(n):
		var pulse := 0.5 + 0.5 * sin(n.t * 9.0)
		n.draw_circle(Vector2(0, -6), 36.0 + 5.0 * pulse, Color(1, 1, 0.5, 0.2))
		n.draw_circle(Vector2(0, -6), 22.0, Color(0.85, 0.15, 0.15))
		n.draw_arc(Vector2(0, -6), 22.0, 0.0, TAU, 20, Color.WHITE, 4.0)
		n.draw_circle(Vector2(0, -10), 14.0, Color(1, 0.4, 0.4))
	button.updater = func(n, dt):
		if target.global_position.distance_to(n.global_position) < 38.0:
			_chan_ok = true
		bot_goal_pos = n.global_position
		bot_dash_vec = (n.global_position - target.global_position).normalized() if target.global_position.distance_to(n.global_position) > 200.0 and n.t > 1.0 else Vector2.ZERO
	bot_goal_pos = btn
	await _ch_loop(warn + t_close + 1.0)


## CLONES: cuatro hojas, solo una real (la del jefe). Hay que acertarle VARIAS veces (2-3) y cada
## acierto, y cada pocos segundos, las hojas se BARAJAN de sitio. Romper una falsa te quema y le da tiempo.
func ch_clones_hojas() -> void:
	var n := 4
	var need := 2 if current_phase == 1 else 3
	var c := arena().get_center()
	var ang0 := RNG.randf_range(0.0, TAU)
	var spots: Array[Vector2] = []
	for i in n:
		spots.append(clamp_to_arena(c + Vector2.RIGHT.rotated(ang0 + i * TAU / n) * 210.0, 110.0))
	for p in spots:
		_add_hazard(BossZone.circle(p, 48.0, 0.7, 0.05, 0.0, LEAFG))
	if not await _wait(0.7):
		return
	global_position = spots[RNG.randi_range(0, n - 1)]
	velocity = Vector2.ZERO
	_no_move_def = true
	var tex := animated_sprite.sprite_frames.get_frame_texture("idle", 0)
	var fakes: Array = []
	var taken := false
	for p in spots:
		if not taken and p.is_equal_approx(global_position):
			taken = true  # el sitio de la real
			continue
		var f := BossBreakable.new()
		f.kind = BossBreakable.Kind.FAKE
		f.enemy_name = "Falsa"
		f.max_health = 6.0
		f.life = -1.0
		f.tex = tex
		f.tex_scale = animated_sprite.scale
		f.tex_flip = animated_sprite.flip_h
		f.color = LEAFG
		_spawn_container().add_child(f)
		f.global_position = p
		f.broken.connect(func(b):
			_ch_extra += 1.5
			_fake_pop(b.global_position))
		fakes.append(f)
	var st := {"hits": 0, "shuffle": 3.0}
	_ch_hit_cb = func(_a, _s):
		st.hits += 1
		_chan_prog = float(st.hits) / need
		Sound.play("enemy_hit")
		if st.hits >= need:
			_chan_ok = true
		else:
			_clones_shuffle(fakes)
			st.shuffle = 3.0
	bot_target_node = self
	await _ch_loop(13.0, func(dt):
		st.shuffle -= dt
		if st.shuffle <= 0.0:
			st.shuffle = 3.0
			_clones_shuffle(fakes))
	_no_move_def = false


## Baraja a la real y a las falsas vivas entre sus sitios (con un destello de aviso en cada uno).
func _clones_shuffle(fakes: Array) -> void:
	var alive := fakes.filter(func(f): return is_instance_valid(f) and f.is_alive())
	var slots: Array[Vector2] = [global_position]
	for f in alive:
		slots.append(f.global_position)
	slots.shuffle()
	global_position = slots[0]
	for i in alive.size():
		alive[i].global_position = slots[i + 1]
	for s in slots:
		_add_hazard(BossZone.circle(s, 40.0, 0.0, 0.2, 0.0, LEAFG))
	Sound.play("dash")


## SECUENCIA: ella muestra flechas; repitelas con dashes en esas direcciones. Equivocarse reinicia la
## secuencia, te quema y le da tiempo extra a la cura.
func ch_secuencia() -> void:
	_refill_stamina()
	var dirs: Array[Vector2] = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var count := 3 if current_phase < 3 else 4
	var seq: Array[Vector2] = []
	for i in count:
		var d: Vector2 = dirs[RNG.randi_range(0, 3)]
		if not seq.is_empty() and seq[-1] == d:
			d = dirs[(dirs.find(d) + 2) % 4]
		seq.append(d)
	var st := {"phase": 0, "t": 0.0, "idx": 0, "was": false, "bad": 0.0}
	var show := _make_prop(global_position + Vector2(210, -30), Callable(), Callable(), st)
	show.drawer = func(n):
		for i in count:
			var c := Vector2(i * 62.0 - 31.0 * (count - 1), 0)
			var live: bool = (st.phase == 0 and int(st.t / 0.8) == i) or (st.phase == 1 and i < st.idx)
			n.draw_rect(Rect2(c - Vector2(26, 26), Vector2(52, 52)), Color(0, 0, 0, 0.75))
			n.draw_rect(Rect2(c - Vector2(26, 26), Vector2(52, 52)), Color(1, 1, 0.6) if live else Color(1, 1, 1, 0.35), false, 3.0)
			if live:
				var dv: Vector2 = seq[i]
				var pts := PackedVector2Array([c + dv * 18.0, c - dv * 12.0 + dv.orthogonal() * 14.0, c - dv * 12.0 - dv.orthogonal() * 14.0])
				n.draw_colored_polygon(pts, Color(0.6, 1.0, 0.6) if st.phase == 1 else Color(1, 1, 0.6))
		if st.bad > 0.0:
			n.draw_rect(Rect2(-31.0 * count - 6, -34, 62.0 * count + 12, 68), Color(1, 0.2, 0.2, 0.7), false, 5.0)
	show.updater = func(n, dt):
		st.bad = maxf(0.0, st.bad - dt)
		if st.phase == 0:
			st.t += dt
			bot_dash_vec = Vector2.ZERO
			if st.t >= count * 0.8 + 0.4:
				st.phase = 1
				st.idx = 0
				st.t = 0.0
		else:
			var dashing: bool = target.is_dashing
			if dashing and not st.was:
				var dd: Vector2 = target._dash_direction
				var best: Vector2 = dirs[0]
				for c in dirs:
					if c.dot(dd) > best.dot(dd):
						best = c
				if best == seq[st.idx]:
					st.idx += 1
					Sound.play("pickup")
					_chan_prog = float(st.idx) / seq.size()
					if st.idx >= seq.size():
						_chan_ok = true
				else:
					st.idx = 0
					st.bad = 0.6
					_ch_extra += 1.5
					if target.has_method("receive_hit"):
						target.receive_hit(damage * 0.2)
					Sound.play("puzzle_fail")
					st.phase = 0
					st.t = 0.0
			st.was = dashing
			bot_dash_vec = seq[st.idx] if st.idx < seq.size() else Vector2.ZERO
	await _ch_loop(17.0)
