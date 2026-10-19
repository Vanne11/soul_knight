extends EnemyBoss

## EL PACTO DE SILENCIO (jefe de Las Tierras del Silencio; diseno_E3_silencio.md, seccion 5) - usa el
## MOTOR DINAMICO (dynamic = true). No es una persona ni una caricatura: una asamblea de siluetas
## sentadas en circulo bajo una cortina pesada que absorbe el sonido. Es lo que pasa cuando todos saben y
## nadie dice. SIN dialogo, SIN humor y SIN musica (el reino no tiene).
##
## COMO SE LE VENCE (haciendo ruido):
## - Tipos de dano (assets/data/boss_damage.json, fila "pacto_silencio"): "sonido" x1,8 y TODO lo demas
##   x0,3 ("apagado": nunca cero, la pelea no se bloquea). Cuentan como "sonido" (a) los golpes que le das
##   al Pacto desde DENTRO del anillo de un objeto de ruido que suena, (b) el pulso de cada objeto de
##   ruido al golpearlo, (c) el grito de Vulvalquiria, el golpe de escudo de Pitocles y el "Ñic" del
##   Ornitorrinco (sound_hit, ver src/player/abilities) y (d) los pulsos de las Voces aliadas.
## - Los objetos de ruido (SilencioRuido, borde de la arena: 2 campanas, 2 ollas, 1 vidrio) los pone la
##   sala (src/silencio/silencio_jefe.gd). El jefe los escucha en el grupo "sil_ruido".
## - El MANTO (atk_manto) amortigua: mientras estas dentro de un manto tus golpes al Pacto hacen x0.
##
## FASES (66% / 33%): 1 "Nadie oyo" (manto, susurro, puerta; sin combos), 2 "Nadie vio" (suma oidos y
## mirar_otro_lado, combos de hasta 2, apagon de la sala: ves tu halo y las Voces como luces), 3 "Nadie
## dijo" (suma la firma atk_nadie_dijo, combos de hasta 3, mantos mas grandes y la sala se achica un poco).
## ATAQUES (todos avisan, minimo 0,55 s): manto, susurro, puerta, oidos (grande: queda AGOTADO 1,4 s),
## mirar_otro_lado, nadie_dijo (14 s sin audio; si aguantas sin golpe queda AGOTADO 2,5 s).
## CURA "El pacto se cierra" (maximo 2): se corta golpeando 3 objetos de ruido DISTINTOS (tocar uno que
## ya conto solo reinicia, sin dano); mientras canaliza se defiende con susurros. Completada: furia 7 s.
## Cortada: aturdido 5 s, -6% de vida y "Alguien hablo.".
##
## LAS 3 LUCES DEL CIRCULO (HUD) se encienden aqui (empiezan apagadas, tambien la 1 que dejo S6 B):
##  luz 1  dos objetos de ruido golpeados en 3 s -> el anillo sube de 120 a 160 px.
##  luz 2  cortar una cura -> 2 Voces aliadas con luz en el borde (pulso de sonido cada 6 s; el manto
##         puede cubrirlas, un anillo de ruido cerca las descubre).
##  luz 3  aguantar "Nadie dijo" sin recibir golpe -> coro: las aliadas hablan a la vez (pulsos x2, 8 s).
## Las luces no se apagan por tus errores.
##
## MUERTE: sin violencia. Emite `defeated`; la sala (silencio_jefe.gd) levanta el manto, las siluetas se
## ponen de pie y salen cada una con una luz. SIN botin (drop_table vacio), SIN logro, SIN sello: no emite
## enemy_killed (main._complete_floor daria recompensa a elegir) y no cuenta como muerte.

signal defeated(at: Vector2)

const DIR := "res://assets/sprites/silencio/"
const HP_MULT := 0.7
const MANTO_R := 92.0
const MANTO_SECS := 7.0
const HALF_SECS := 6.0
const PULSE_PCT := 0.014          ## pulso de un objeto de ruido: fraccion de la vida maxima (antes de x1,8)
const ALLY_PCT := 0.012
const CURE_NEED := 3
const COL_MANTO := Color(0.2, 0.19, 0.3)
const COL_WAVE := Color(0.55, 0.56, 0.72)
const COL_WALL := Color(0.3, 0.28, 0.42)

## true durante el "coro" (luz 3): las Voces aliadas pulsan x2.
var chorus_on := false

var _mantos: Array = []     # {pos, r, from, until}
var _halves: Array = []     # {rect, from, until}
var _allies: Array = []
var _lights := [false, false, false]
var _rung_times: Array = []
var _chorus_t := 0.0
var _fury_t := 0.0
var _dark_t := 0.0
var _def_t := 1.5
var _ch_used: Array = []
var _hooked := false
var _muted := false
var _force_sound := false  # el golpe viene de un grito / escudo / pico del heroe (sound_hit)
var _pulse_hit := false    # el golpe es un pulso interno (objeto de ruido o Voz aliada): ignora el manto
var _shrunk := false


func _ready() -> void:
	var spr: AnimatedSprite2D = $AnimatedSprite2D  # (el @onready de la base aun no corrio)
	spr.sprite_frames = _build_frames()
	spr.scale = Vector2.ONE
	spr.offset = Vector2(0, -84)
	super()
	dynamic = true
	fan_tint = COL_WAVE
	keep_min = 200.0
	keep_max = 330.0
	rest_min = 0.7
	rest_max = 1.2
	bullet_speed = 170.0
	tele_caps = [0.8, 0.7, 0.6]  # nunca menos de 0,55 s de aviso
	move_speed = 34.0
	max_health *= HP_MULT
	current_health = max_health
	_emit_health()
	_channels_total = 2
	_channels_left = 2
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	add_to_group("boss_pacto")
	# una luz fria y tenue sobre la asamblea: la sala esta casi a oscuras y el jefe tiene que leerse
	var glow := LightKit.make_light(Color(0.82, 0.86, 1.0), 0.5, 2.8, false)
	glow.remove_from_group(LightKit.GROUP_DARK)
	glow.enabled = true
	glow.position = Vector2(0, -70)
	add_child(glow)
	# La asamblea es ancha: cuerpo y zona de golpe a su medida (el .tscn es de un jefe de 100 px)
	var body := RectangleShape2D.new()  # (las formas del .tscn se comparten con los demas jefes: no tocarlas)
	body.size = Vector2(150, 96)
	$CollisionShape2D.shape = body
	$CollisionShape2D.position = Vector2(0, -52)
	var hurt := RectangleShape2D.new()
	hurt.size = Vector2(176, 120)
	$Hurtbox/CollisionShape2D.shape = hurt
	$Hurtbox.position = Vector2(0, -70)
	Silencio.cartel([tr("SIL_JEFE_F1")], 2.6)


func _say(_suffix: String) -> void:
	pass  # el Pacto no habla y el narrador calla en todo el reino


func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	_anim(sf, "idle", ["pacto_idle_0", "pacto_idle_1"], 1.6, true)
	_anim(sf, "walk", ["pacto_idle_0", "pacto_idle_1"], 2.0, true)
	_anim(sf, "attack", ["pacto_attack"], 1.0, true)
	_anim(sf, "tired", ["pacto_tired"], 1.0, true)
	_anim(sf, "hurt", ["pacto_hurt"], 1.0, false)
	_anim(sf, "death", ["pacto_death"], 1.0, false)
	return sf


func _anim(sf: SpriteFrames, anim: String, frames: Array, fps: float, loop: bool) -> void:
	sf.add_animation(anim)
	sf.set_animation_speed(anim, fps)
	sf.set_animation_loop(anim, loop)
	for f in frames:
		sf.add_frame(anim, load(DIR + str(f) + ".png"))


func _update_animation() -> void:
	var anim := "tired" if state == State.TIRED else "idle"
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)


# ---------------------------------------------------------------- ganchos del motor
func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_manto", &"atk_susurro", &"atk_puerta"]
		2:
			return [&"atk_manto", &"atk_susurro", &"atk_puerta", &"atk_oidos", &"atk_mirar_otro_lado"]
	return [&"atk_manto", &"atk_susurro", &"atk_puerta", &"atk_oidos", &"atk_mirar_otro_lado", &"atk_nadie_dijo"]


## Los combos solo encadenan ataques cortos (nunca la firma ni el ataque grande).
func _combo_next() -> StringName:
	var options := [&"atk_manto", &"atk_susurro", &"atk_puerta"]
	if current_phase >= 2:
		options.append(&"atk_mirar_otro_lado")
	return options[RNG.randi_range(0, options.size() - 1)]


func _combo_len() -> int:
	return 0 if current_phase < 2 else RNG.randi_range(0, current_phase - 1)


func _challenges() -> Array:
	return [&"ch_ruido"]


func _channel_color() -> Color:
	return Color(0.82, 0.84, 0.95)


func _hit_source() -> String:
	return "pasivo/reposo"


## Textos de la cura sin signos de admiracion ni humor (ver locale/silencio.csv).
func _chan_label(kind: String) -> String:
	return tr("SIL_JEFE_CORTE") if kind == "BREAK" else tr("SIL_JEFE_COMPLETA")


func _cure_cut_stun() -> float:
	return 5.0


func _on_cure_cut() -> void:
	current_health = maxf(1.0, current_health - max_health * 0.06)
	_emit_health()
	_light(1)


func _on_cure_done() -> void:
	_fury_t = 7.0


func _on_phase(n: int) -> void:
	_mantos.clear()
	_halves.clear()
	if n >= 2:
		Silencio.cartel([tr("SIL_JEFE_F%d" % n)], 2.6)
	if n == 3 and not _shrunk:
		_shrunk = true
		_arena = arena().grow(-40.0)  # la sala se achica un poco


func _clear_hazards() -> void:
	super()
	_mantos.clear()
	_halves.clear()


func _cancel_attack() -> void:
	_audio(false)
	for o in get_tree().get_nodes_in_group(SilencioRuido.GROUP):
		o.loud = false
	super()


func _exit_tree() -> void:
	_audio(false)
	super()


## Sin muerte violenta: no suelta botin, no emite enemy_killed (sin logro, sin recompensa a elegir).
func die(_killer: Node = null) -> void:
	if state == State.DEAD:
		return
	_cancel_attack()
	state = State.DEAD
	BossDamage.on_death(self)
	current_health = 0.0
	invuln = false
	_emit_health()
	_clear_bullets()
	_print_stats("jefe derrotado")
	set_collision_layer_value(2, false)
	velocity = Vector2.ZERO
	defeated.emit(global_position)
	var tw := create_tween()
	tw.tween_property(animated_sprite, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


# ---------------------------------------------------------------- reposo y pasivos
## La asamblea no persigue: se queda en el centro de la arena (con un balanceo apenas).
func _idle_move(_delta: float) -> void:
	var to_c := arena().get_center() - global_position
	velocity = to_c.limit_length(move_speed) if to_c.length() > 12.0 else Vector2.ZERO


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _noise() -> Array:
	return get_tree().get_nodes_in_group(SilencioRuido.GROUP)


func _hook_noise() -> void:
	if _hooked:
		return
	_hooked = true
	for o in _noise():
		o.rung.connect(_on_rung)


func _tick(delta: float) -> void:
	if state == State.DEAD or target == null:
		return
	_hook_noise()
	if state in [State.INTRO, State.TRANSITION]:
		return
	var now := _now()
	_mantos = _mantos.filter(func(m): return float(m.until) > now)
	_halves = _halves.filter(func(h): return float(h.until) > now)
	if _chorus_t > 0.0:
		_chorus_t -= delta
		if _chorus_t <= 0.0:
			chorus_on = false
	if _fury_t > 0.0:
		_fury_t -= delta
		rest_min = 0.2
		rest_max = 0.45
	else:
		rest_min = 0.7
		rest_max = 1.2
	# Fase 2+: apagon de la sala (tu halo y las Voces como luces). Parcial: la pelea se tiene que poder leer.
	if current_phase >= 2 and not _channeling:
		if not is_instance_valid(_blackout):
			_blackout_start(210.0, Color(0.02, 0.02, 0.06), 0.62)
		_blackout_update(_light_focus(), 120.0)


## El punto que brilla ademas del halo del heroe: la Voz aliada mas cercana, o el propio Pacto.
func _light_focus() -> Vector2:
	var best := _body_center()
	var bd := INF
	for a in _allies:
		if is_instance_valid(a):
			var d: float = (a.global_position + Vector2(0, -26)).distance_to(target.global_position)
			if d < bd:
				bd = d
				best = a.global_position + Vector2(0, -26)
	return best


# ---------------------------------------------------------------- mantos y mitades cubiertas
func _in_manto(p: Vector2) -> bool:
	var now := _now()
	for m in _mantos:
		if now >= float(m.from) and now < float(m.until) and p.distance_to(m.pos) <= float(m.r):
			return true
	return false


## Una Voz (o el heroe) en este punto esta cubierta por el manto o por la mitad apagada.
func is_covered(p: Vector2) -> bool:
	var now := _now()
	for h in _halves:
		if now >= float(h.from) and now < float(h.until) and (h.rect as Rect2).has_point(p):
			return true
	return _in_manto(p)


func _near_ring(p: Vector2) -> bool:
	for o in _noise():
		if o.covers(p):
			return true
	return false


# ---------------------------------------------------------------- dano
func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if state in [State.DEAD, State.INTRO, State.TRANSITION] or _channeling:
		return super(amount, source, kb)
	var sound := _force_sound or _pulse_hit
	if not _pulse_hit:
		if _in_manto(target.global_position):
			if _shield_msg_cd <= 0.0:
				_shield_msg_cd = 0.9
				_float_text("…", Color("9a9aa6"))
			HitFx.flash(animated_sprite, 0.05)
			return 0.0
		if not sound and _near_ring(target.global_position):
			sound = true
	BossDamage.tag("", 1.0, "sonido" if sound else "apagado")
	return super(amount, source, kb)


## Golpe de SONIDO de una habilidad del heroe (grito, escudo, pico). Respeta el manto.
func sound_hit(amount: float, source: Node = null) -> void:
	_force_sound = true
	take_damage(amount, source)
	_force_sound = false


func _pulse(amount: float) -> void:
	_pulse_hit = true
	take_damage(amount)
	_pulse_hit = false


## Pulso de una Voz aliada.
func ally_pulse(_ally: Node, mult := 1.0) -> void:
	_pulse(max_health * ALLY_PCT * mult)


# ---------------------------------------------------------------- objetos de ruido y luces del circulo
func _on_rung(obj: SilencioRuido) -> void:
	if state in [State.DEAD, State.INTRO]:
		return
	var now := _now()
	_rung_times.append(now)
	_rung_times = _rung_times.filter(func(t): return now - float(t) <= 3.0)
	if _rung_times.size() >= 2:
		_light(0)
	for a in _allies:
		if is_instance_valid(a):
			a.note_ring(obj.global_position)
	if _channeling:
		_cure_ring(obj)
		return
	_pulse(max_health * PULSE_PCT)  # el ruido le llega


## Cura: 3 objetos distintos; uno que ya conto, tras rearmarse, solo reinicia (sin dano).
func _cure_ring(obj: SilencioRuido) -> void:
	if obj in _ch_used:
		_ch_used = [obj]
	else:
		_ch_used.append(obj)
	_chan_prog = float(_ch_used.size()) / CURE_NEED
	if _ch_used.size() >= CURE_NEED:
		_chan_ok = true


## Enciende la luz i (0..2) del circulo y aplica lo que gana el jugador.
func _light(i: int) -> void:
	if _lights[i]:
		return
	_lights[i] = true
	Silencio.circle_set(i, true)
	match i:
		0:
			for o in _noise():
				o.ring_r = 160.0
		1:
			_spawn_allies()
		2:
			_spawn_allies()
			chorus_on = true
			_chorus_t = 8.0


func _spawn_allies() -> void:
	if not _allies.is_empty():
		return
	var a := arena()
	var c := a.get_center()
	for x in [a.position.x + 120.0, a.end.x - 120.0]:
		var v := SilencioAliada.new()
		v.boss = self
		_spawn_container().add_child(v)
		v.global_position = _on_floor(Vector2(x, c.y + 20.0))
		_allies.append(v)


# ---------------------------------------------------------------- ataques
func _warn_secs() -> float:
	return [0.75, 0.68, 0.62][clampi(current_phase, 1, 3) - 1]


## MANTO: tres zonas de tela caen (aviso: circulo oscuro que crece). Dentro, tus golpes hacen x0. No daña.
func atk_manto() -> void:
	var warn := _warn_secs()
	var r := MANTO_R * (1.3 if current_phase == 3 else 1.0)
	var spots: Array[Vector2] = [clamp_to_arena(target.global_position, 100.0)]
	for _i in (2 if current_phase < 3 else 3):
		spots.append(arena_point(100.0))
	var now := _now()
	for p in spots:
		_add_hazard(BossZone.circle(p, r, warn, MANTO_SECS, 0.0, COL_MANTO))
		_mantos.append({"pos": p, "r": r, "from": now + warn, "until": now + warn + MANTO_SECS})
	if not await _tele(warn, Color(1.3, 1.3, 1.7), 2.0):
		return
	await _wait(0.2)


## SUSURRO: abanico de 7 ondas oscuras lentas que se cierran hacia donde estabas. Dano leve.
func atk_susurro() -> void:
	var aim := target.global_position
	var warn := _warn_secs()
	var volleys := 1 if current_phase == 1 else 2
	for v in volleys:
		var spots := _susurro_spots(aim, 7)
		for p in spots:
			_add_hazard(BossZone.rect(p.lerp(aim, 0.5), Vector2(p.distance_to(aim), 5.0), (aim - p).angle(), warn, 0.05, 0.0, COL_WAVE))
		if not await _tele(warn, Color(1.3, 1.3, 1.7), 2.0):
			return
		for p in spots:
			_fire_from(p, (aim - p).angle(), 140.0 + 20.0 * current_phase, 0.5, COL_WAVE, 4.5)
		if v < volleys - 1:
			if not await _wait(0.4):
				return
			aim = target.global_position
	await _wait(0.3)


func _susurro_spots(aim: Vector2, n: int) -> Array[Vector2]:
	var base := (global_position - aim).angle()
	var out: Array[Vector2] = []
	for i in n:
		out.append(clamp_to_arena(aim + Vector2.RIGHT.rotated(base + (i - (n - 1) / 2.0) * 0.36) * 280.0, 30.0))
	return out


## PUERTA: dos muros de tela caen desde los bordes con un hueco de 90 px (flechas en el hueco).
func atk_puerta() -> void:
	var a := arena()
	var warn := _warn_secs()
	var vertical := RNG.randf() < 0.5
	var along := a.size.x if vertical else a.size.y
	var lo := a.position.x if vertical else a.position.y
	var gap_axis := a.position.y if vertical else a.position.x
	var gap_len := a.size.y if vertical else a.size.x
	var player_gap := (target.global_position.y if vertical else target.global_position.x) - gap_axis
	for k in 2:
		var pos := lo + along * (0.34 if k == 0 else 0.66)
		var gap := clampf(player_gap + RNG.randf_range(-70.0, 70.0), 90.0, gap_len - 90.0) if k == 0 else RNG.randf_range(110.0, gap_len - 110.0)
		_wall(vertical, pos, gap_axis, gap_len, gap, warn)
	if not await _tele(warn, Color(1.3, 1.3, 1.7), 2.0):
		return
	await _wait(0.55)


func _wall(vertical: bool, pos: float, gap_axis: float, gap_len: float, gap: float, warn: float) -> void:
	var half := 45.0  # medio hueco: 90 px
	var thick := 44.0
	var segs := [[0.0, gap - half], [gap + half, gap_len]]
	for s in segs:
		var l: float = float(s[1]) - float(s[0])
		if l <= 4.0:
			continue
		var mid := gap_axis + float(s[0]) + l * 0.5
		var z: BossZone
		if vertical:
			z = BossZone.rect(Vector2(pos, mid), Vector2(thick, l), 0.0, warn, 0.5, damage * 0.8, COL_WALL)
		else:
			z = BossZone.rect(Vector2(mid, pos), Vector2(l, thick), 0.0, warn, 0.5, damage * 0.8, COL_WALL)
		_add_hazard(z)
	# flechas que cruzan el hueco
	var at := Vector2(pos, gap_axis + gap) if vertical else Vector2(gap_axis + gap, pos)
	var pr := _make_prop(at, func(p):
		var col := Color(1, 1, 1, 0.55 + 0.35 * sin(p.t * 16.0))
		for k in 3:
			var o := Vector2(float(k - 1) * 14.0, 0.0) if not vertical else Vector2(0.0, float(k - 1) * 14.0)
			var tip := Vector2(7, 0) if vertical else Vector2(0, 7)
			var a1 := Vector2(-7, -11) if vertical else Vector2(-11, -7)
			var a2 := Vector2(-7, 11) if vertical else Vector2(11, -7)
			p.draw_polyline(PackedVector2Array([o + a1, o + tip, o + a2]), col, 3.0))
	get_tree().create_timer(warn + 0.9).timeout.connect(func():
		if is_instance_valid(pr):
			pr.queue_free())


## OIDOS (fase 2+): las siluetas bajan la cabeza y lanzan 3 anillos desde el centro (se saltan con dash,
## cada uno con un hueco). Ataque GRANDE: despues queda AGOTADO 1,4 s (ventana x1,5).
func atk_oidos() -> void:
	var c := _body_center()
	_add_hazard(BossZone.circle(c, 90.0, 0.85, 0.05, 0.0, COL_WAVE))
	if not await _tele(0.85, Color(0.9, 0.9, 1.4), 1.5):
		return
	var n := 22
	for k in 3:
		var skip := (k * 7) % n
		for i in n:
			if i == skip or i == (skip + 1) % n:
				continue
			_fire_from(c, TAU * i / n, 165.0, 0.55, COL_WAVE, 5.0)
		if not await _wait(0.6):
			return
	if not await _wait(0.3):
		return
	_tire(1.4)


## MIRAR OTRO LADO (fase 2+): se apaga una mitad de la sala; las Voces de esa mitad quedan cubiertas hasta
## que un objeto de ruido cercano suene.
func atk_mirar_otro_lado() -> void:
	var a := arena()
	var left := RNG.randf() < 0.5
	for v in _allies:
		if is_instance_valid(v):
			left = v.global_position.x < a.get_center().x
			break
	var rect := Rect2(a.position if left else Vector2(a.get_center().x, a.position.y), Vector2(a.size.x * 0.5, a.size.y))
	var warn := 0.8
	_add_hazard(BossZone.rect(rect.get_center(), rect.size, 0.0, warn, HALF_SECS, 0.0, Color(0.08, 0.08, 0.14)))
	var now := _now()
	_halves.append({"rect": rect, "from": now + warn, "until": now + warn + HALF_SECS})
	if not await _tele(warn, Color(0.9, 0.9, 1.4), 1.5):
		return
	await _wait(0.2)


## NADIE DIJO (FIRMA, fase 3): el audio del juego va a cero (subtitulo "..."). Cuatro oleadas de ondas
## lentas desde cuatro lados; solo "suena" lo que tu golpeas. 14 s. Si aguantas sin recibir golpe, el Pacto
## queda AGOTADO 2,5 s y se enciende la luz 3.
func atk_nadie_dijo() -> void:
	var h0 := _st_hits
	_audio(true)
	Silencio.cartel(["..."], 3.0)
	for o in _noise():
		o.loud = true
	if not await _tele(0.85, Color(0.8, 0.8, 1.3), 1.5):
		return
	var order := [0, 1, 2, 3]
	RNG.shuffle(order)
	var wave := 0
	var next := 0.0
	var t := 0.0
	var g := _gen
	while t < 14.0:
		if wave < 4 and t >= next:
			_wave(order[wave], g)
			wave += 1
			next += 3.2
		if not await _frame():
			return
		t += 1.0 / 60.0
	_audio(false)
	for o in _noise():
		o.loud = false
	if _st_hits == h0:
		_light(2)
		_tire(2.5)


## Una oleada de ondas lentas desde un lado (0 arriba, 1 derecha, 2 abajo, 3 izquierda) con un hueco de
## ~140 px. Aviso: una linea fina en ese borde 0,7 s antes.
func _wave(side: int, g: int) -> void:
	var a := arena().grow(-24.0)
	var dir := [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT][side] as Vector2
	var horizontal := side == 0 or side == 2
	var length := a.size.x if horizontal else a.size.y
	var origin: Vector2 = [a.position, Vector2(a.end.x, a.position.y), Vector2(a.position.x, a.end.y), a.position][side]
	var step := 46.0
	var count := int(length / step)
	var gap := RNG.randi_range(1, maxi(2, count - 4))
	var spots: Array[Vector2] = []
	for i in count:
		if i >= gap and i < gap + 3:
			continue
		var off := Vector2(i * step + step * 0.5, 0.0) if horizontal else Vector2(0.0, i * step + step * 0.5)
		spots.append(_on_floor(origin + off))
	var speed := 115.0
	var cross := (a.size.y if horizontal else a.size.x) / speed + 0.6
	var line_pos := origin + (Vector2(length * 0.5, 0.0) if horizontal else Vector2(0.0, length * 0.5))
	_add_hazard(BossZone.rect(line_pos, Vector2(length, 5.0) if horizontal else Vector2(5.0, length), 0.0, 0.7, 0.05, 0.0, COL_WAVE))
	get_tree().create_timer(0.7).timeout.connect(func():
		if g != _gen or state != State.ATTACK:
			return
		for p in spots:
			_fire_from(p, dir.angle(), speed, 0.45, COL_WAVE, cross))


## Silencia (o devuelve) la musica y los efectos del juego.
func _audio(mute: bool) -> void:
	if _muted == mute:
		return
	_muted = mute
	for n in ["SFX", "Music"]:
		var i := AudioServer.get_bus_index(n)
		if i >= 0:
			AudioServer.set_bus_mute(i, mute)


# ---------------------------------------------------------------- cura
## EL PACTO SE CIERRA: las siluetas asienten y repiten un "shh" bajo. Se corta golpeando 3 objetos de ruido.
func ch_ruido() -> void:
	_ch_used.clear()
	_def_t = 1.2
	await _ch_loop(12.5)


## Mientras canaliza se defiende con susurros (cada ~2,6 s, con linea de aviso de 0,6 s).
func _defend(dt: float) -> void:
	_def_t -= dt
	if _def_t > 0.0 or target == null:
		return
	_def_t = 2.6
	var aim := target.global_position
	var spots := _susurro_spots(aim, 5)
	for p in spots:
		_add_hazard(BossZone.rect(p.lerp(aim, 0.5), Vector2(p.distance_to(aim), 4.0), (aim - p).angle(), 0.6, 0.05, 0.0, COL_WAVE))
	var g := _gen
	get_tree().create_timer(0.6).timeout.connect(func():
		if g != _gen or not _channeling:
			return
		for p in spots:
			_fire_from(p, (aim - p).angle(), 130.0, 0.4, COL_WAVE, 4.0))
