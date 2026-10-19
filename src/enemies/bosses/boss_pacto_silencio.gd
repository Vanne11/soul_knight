extends EnemyBoss

## EL PACTO DE SILENCIO (jefe de Las Tierras del Silencio; diseno_E3_silencio.md, seccion 5) - usa el
## MOTOR DINAMICO (dynamic = true). No es una persona ni una caricatura: una asamblea de siluetas
## sentadas en circulo bajo una cortina pesada que absorbe el sonido. Es lo que pasa cuando todos saben y
## nadie dice. SIN dialogo, SIN humor y SIN musica (el reino no tiene).
##
## ESCENARIO Y CUERPOS (rediseno): la cortina, el haz de luz y el circulo de sillas son un ESCENARIO FIJO
## (SilencioEscenario, decorado centrado en la sala). Las 7 siluetas (SilencioCuerpo) son los CUERPOS del
## jefe: este nodo (EnemyBoss) conserva LA UNICA vida y barra, las fases, las curas y la muerte; los cuerpos
## reciben el golpe y se lo pasan (cuerpo_hit). Este nodo no recibe golpes directos ni se mueve.
## - SENTADAS: se RECARGAN (tiempo antes de volver a salir), se PROTEGEN (la cortina las cubre: dano x0,08,
##   se ve el velo) y se REPARAN (la cura "El pacto se cierra", solo con todas sentadas, asienten en bloque).
## - FUERA: salen DE A UNA O EN GRUPOS (fase 1: 1-2, fase 2: 2-3, fase 3: 3-4) y son VULNERABLES; luego
##   SIEMPRE vuelven a sentarse. Sus ataques son de SILENCIAR y AISLAR, nunca de golpear ni de contacto: ondas
##   de "shh", rodear al jugador para cerrarle el paso y cubrirlo con la cortina (zona que anula tus golpes).
##   El dano al jugador viene solo de las ondas.
## - EL RUIDO es la clave: un objeto de ruido que suena con las siluetas sentadas ABRE la cortina 3 s (quedan
##   vulnerables) y las FUERZA a salir antes de tiempo; si suena durante la cura, la corta.
##
## COMO SE LE VENCE (haciendo ruido):
## - Tipos de dano (assets/data/boss_damage.json, fila "pacto_silencio"): "sonido" x1,8 y TODO lo demas
##   x0,3 ("apagado": nunca cero, la pelea no se bloquea). Cuentan como "sonido" (a) los golpes que le das
##   a un cuerpo desde DENTRO del anillo de un objeto de ruido que suena, (b) el pulso de cada objeto de
##   ruido al golpearlo, (c) el grito de Vulvalquiria, el golpe de escudo de Pitocles y el "Ñic" del
##   Ornitorrinco (sound_hit) y (d) los pulsos de las Voces aliadas.
## - Los objetos de ruido (SilencioRuido, borde de la arena) los pone la sala (src/silencio/silencio_jefe.gd).
##
## FASES (66% / 33%): 1 "Nadie oyo" (salidas de 1-2), 2 "Nadie vio" (grupos de 2-3, combos de hasta 2, mirar
## otro lado: media sala a oscuras, apagon parcial), 3 "Nadie dijo" (grupos de 3-4, oleadas, combos de hasta 3, la
## firma atk_nadie_dijo: 14 s sin audio, y la sala se achica un poco). Todos los avisos duran >= 0,55 s.
## CURA "El pacto se cierra" (maximo 2): se corta golpeando 3 objetos de ruido DISTINTOS (tocar uno que
## ya conto solo reinicia, sin dano); mientras canaliza se defiende con susurros. Completada: furia 7 s.
## Cortada: aturdidas 5 s (de pie, vulnerables), -6% de vida y "Alguien hablo.".
##
## LAS 3 LUCES DEL CIRCULO (HUD) se encienden aqui (empiezan apagadas, tambien la 1 que dejo S6 B):
##  luz 1  dos objetos de ruido golpeados en 3 s -> el anillo sube de 120 a 160 px.
##  luz 2  cortar una cura -> 2 Voces aliadas con luz en el borde (pulso de sonido cada 6 s; el manto
##         puede cubrirlas, un anillo de ruido cerca las descubre).
##  luz 3  aguantar "Nadie dijo" sin recibir golpe -> coro: las aliadas hablan a la vez (pulsos x2, 8 s).
## Las luces no se apagan por tus errores.
##
## MUERTE: sin violencia. Emite `defeated`; las siluetas se levantan y salen cada una con su luz y se
## desvanecen (SilencioCuerpo.final_exit); la sala (silencio_jefe.gd) abre las puertas y dice "Se rompio el
## silencio.". SIN botin (drop_table vacio), SIN logro, SIN sello: no emite enemy_killed.

signal defeated(at: Vector2)

const MANTO_R := 92.0
const MANTO_SECS := 7.0
const HALF_SECS := 6.0
const HP_MULT := 0.7
const PULSE_PCT := 0.014          ## pulso de un objeto de ruido: fraccion de la vida maxima (antes de x1,8)
const ALLY_PCT := 0.012
const CURE_NEED := 3
const PROTECT_MULT := 0.08        ## dano a una silueta sentada y cubierta por la cortina
const RECHARGE := [3.0, 2.4, 1.8]
const COL_MANTO := Color(0.2, 0.19, 0.3)
const COL_WAVE := Color(0.42, 0.44, 0.74)   ## frio y oscuro: el peligro nunca es blanco (los anillos blancos son del ruido)

## true durante el "coro" (luz 3): las Voces aliadas pulsan x2.
var chorus_on := false

var _mantos: Array = []     # {pos, r, from, until}
var _halves: Array = []     # {rect, from, until}
var _allies: Array = []
var _lights := [false, false, false]
var _rung_times: Array = []
var _chorus_t := 0.0
var _fury_t := 0.0
var _def_t := 1.5
var _ch_used: Array = []
var _hooked := false
var _muted := false
var _force_sound := false  # el golpe viene de un grito / escudo / pico del heroe (sound_hit)
var _inner := false        # el golpe llega por un cuerpo, un pulso o una Voz (el nodo no recibe golpes directos)
var _shrunk := false
var _cuerpos: Array = []
var _esc: SilencioEscenario = null
var _pending := 0          # siluetas de la salida en curso que aun no vuelven a su silla
var _nod := 0.0


func _ready() -> void:
	var spr: AnimatedSprite2D = $AnimatedSprite2D  # (el @onready de la base aun no corrio)
	spr.sprite_frames = load("res://assets/sprites/silencio/pacto/pacto_sprite_frames.tres")
	super()
	dynamic = true
	fan_tint = COL_WAVE
	keep_min = 200.0
	keep_max = 330.0
	rest_min = 1.2
	rest_max = 1.8
	bullet_speed = 170.0
	tele_caps = [0.8, 0.7, 0.6]  # nunca menos de 0,55 s de aviso
	move_speed = 0.0
	max_health *= HP_MULT
	current_health = max_health
	_emit_health()
	_channels_total = 2
	_channels_left = 2
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	add_to_group("boss_pacto")
	# Este nodo es solo la vida, la barra y el cerebro: no se ve, no choca y no recibe golpes (los reciben los cuerpos).
	remove_from_group("enemy")
	animated_sprite.visible = false
	collision_layer = 0
	$CollisionShape2D.set_deferred("disabled", true)
	$Hurtbox.set_deferred("monitoring", false)
	$Hurtbox.set_deferred("monitorable", false)
	$Hitbox.set_deferred("monitoring", false)
	var sh := get_node_or_null("ContactShadow")
	if sh != null:
		sh.visible = false
	Silencio.cartel([tr("SIL_JEFE_F1")], 2.6)


func _say(_suffix: String) -> void:
	pass  # el Pacto no habla y el narrador calla en todo el reino


# ---------------------------------------------------------------- escenario y cuerpos
## Pone el escenario (si la sala no lo puso) y las 7 siluetas sentadas. Se hace en el primer _tick: la posicion
## del jefe (el centro del escenario) ya es la definitiva.
func _make_cuerpos() -> void:
	if not _cuerpos.is_empty():
		return
	_esc = get_tree().get_first_node_in_group(SilencioEscenario.GROUP) as SilencioEscenario
	if _esc == null:
		_esc = SilencioEscenario.new()
		_spawn_container().add_child(_esc)
		_esc.global_position = global_position
	for i in SilencioEnte.SEATS.size():
		var c := SilencioCuerpo.new()
		c.boss = self
		c.idx = i
		_spawn_container().add_child(c)
		c.global_position = seat_of(i)
		c.recharge = 1.0 + 0.4 * i
		_cuerpos.append(c)


func seat_of(i: int) -> Vector2:
	return global_position + (SilencioEnte.SEATS[i] as Vector2)


func recharge_secs() -> float:
	return RECHARGE[clampi(current_phase, 1, 3) - 1]


## Las siluetas listas para salir: sentadas, primero las mas recargadas.
func _libres(n: int) -> Array:
	var l := _cuerpos.filter(func(c): return is_instance_valid(c) and c.mode == SilencioCuerpo.Mode.SEATED)
	RNG.shuffle(l)
	l.sort_custom(func(a, b): return a.recharge < b.recharge)
	return l.slice(0, n)


## Todas vuelven a su silla (si se cancela el ataque, cambia la fase o empieza la cura).
func _sentar_todos(speed := 150.0) -> void:
	for c in _cuerpos:
		if is_instance_valid(c) and c.mode in [SilencioCuerpo.Mode.OUT, SilencioCuerpo.Mode.STUN]:
			c.volver(speed)


func _all_seated() -> bool:
	for c in _cuerpos:
		if is_instance_valid(c) and c.mode != SilencioCuerpo.Mode.SEATED:
			return false
	return true


# ---------------------------------------------------------------- ganchos del motor
func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_salida"]
		2:
			return [&"atk_salida", &"atk_salida", &"atk_mirar_otro_lado"]
	return [&"atk_salida", &"atk_oleada", &"atk_mirar_otro_lado", &"atk_nadie_dijo"]


## Los combos solo encadenan salidas (nunca la firma): salen otras siluetas, sin pausa para recargar.
func _combo_next() -> StringName:
	return &"atk_salida"


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
	for c in _cuerpos:  # aturdidas: de pie, fuera de la silla y vulnerables
		if is_instance_valid(c):
			c.aturdir(4.4)


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
	_sentar_todos()
	_audio(false)
	for o in get_tree().get_nodes_in_group(SilencioRuido.GROUP):
		o.loud = false
	super()


func _exit_tree() -> void:
	_audio(false)
	super()


## Sin muerte violenta: no suelta botin, no emite enemy_killed (sin logro, sin recompensa a elegir). Las siluetas
## se levantan y salen cada una con su luz.
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
	velocity = Vector2.ZERO
	var a := arena()
	var n := _cuerpos.size()
	for i in n:
		var c: SilencioCuerpo = _cuerpos[i]
		if is_instance_valid(c):
			c.final_exit(Vector2(a.end.x - 40.0 - (i % 2) * 24.0, a.get_center().y + (i - n / 2.0) * 34.0), 0.8 + i * 0.5)
	defeated.emit(global_position)
	get_tree().create_timer(0.3).timeout.connect(queue_free)


# ---------------------------------------------------------------- reposo y pasivos
## El nodo no se mueve: es el escenario.
func _idle_move(_delta: float) -> void:
	velocity = Vector2.ZERO


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
	_make_cuerpos()
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
		rest_min = 0.4
		rest_max = 0.8
	else:
		rest_min = 1.2
		rest_max = 1.8
	# Fase 2+: apagon de la sala (tu halo y las siluetas/Voces como luces). Parcial: la pelea se tiene que poder leer.
	if current_phase >= 2 and not _channeling:
		if not is_instance_valid(_blackout):
			_blackout_start(210.0, Color(0.02, 0.02, 0.06), 0.62)
		_blackout_update(_light_focus(), 120.0)


## El punto que brilla ademas del halo del heroe: la Voz aliada mas cercana, la silueta que esta fuera o el escenario.
func _light_focus() -> Vector2:
	var best := global_position + Vector2(0, -70)
	var bd := INF
	for c in _cuerpos:
		if is_instance_valid(c) and c.is_out():
			var d: float = c.global_position.distance_to(target.global_position)
			if d < bd:
				bd = d
				best = c.global_position + Vector2(0, -34)
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
## El nodo no recibe golpes directos: solo los que llegan por un cuerpo, un pulso o una Voz.
func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if not _inner:
		return 0.0
	return super(amount, source, kb)


## Un cuerpo recibio un golpe: se lo pasa al jefe (una sola vida). Sentada y cubierta casi no hace dano; dentro de
## un manto, nada; fuera, normal ("sonido" x1,8 o "apagado" x0,3).
func cuerpo_hit(c: SilencioCuerpo, amount: float, source: Node, forced_sound: bool) -> float:
	if state in [State.DEAD, State.INTRO, State.TRANSITION]:
		return 0.0
	HitFx.flash(c.sprite, 0.05)
	if _channeling:
		_on_channel_hit(amount, source)
		return 0.0
	var off := c.global_position - global_position + Vector2(0, -90)
	if _in_manto(target.global_position):
		if _shield_msg_cd <= 0.0:
			_shield_msg_cd = 0.9
			_float_text("…", Color("9a9aa6"), off)
		return 0.0
	var sound := forced_sound or _force_sound or _near_ring(target.global_position)
	if c.protected():
		amount *= PROTECT_MULT
		if _shield_msg_cd <= 0.0:
			_shield_msg_cd = 0.9
			_float_text("…", Color("9a9aa6"), off)
	return _hit(amount, source, sound)


func _hit(amount: float, source: Node, sound: bool) -> float:
	BossDamage.tag("", 1.0, "sonido" if sound else "apagado")
	_inner = true
	var r := take_damage(amount, source)
	_inner = false
	return r


func _pulse(amount: float) -> void:
	if state in [State.DEAD, State.INTRO, State.TRANSITION] or _channeling:
		return
	_hit(amount, null, true)


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
	if state == State.IDLE:
		# el ruido abre la cortina (3 s vulnerables) y las fuerza a salir antes de tiempo
		for c in _cuerpos:
			if is_instance_valid(c) and c.mode == SilencioCuerpo.Mode.SEATED:
				c.exposed = 3.0
				c.recharge = 0.0
		_timer = minf(_timer, 0.5)


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


# ---------------------------------------------------------------- salidas de las siluetas
func _warn_secs() -> float:
	return [0.75, 0.68, 0.62][clampi(current_phase, 1, 3) - 1]


func _walk_speed() -> float:
	return [78.0, 88.0, 98.0][clampi(current_phase, 1, 3) - 1]


func _group_size() -> int:
	match current_phase:
		1:
			return RNG.randi_range(1, 2)
		2:
			return RNG.randi_range(2, 3)
	return RNG.randi_range(3, 4)


## SALIDA: una silueta o un grupo se levanta de sus sillas, sale hacia ti a silenciarte y aislarte, y vuelve a sentarse.
func atk_salida() -> void:
	await _enviar(_libres(_group_size()), 0.7)


## OLEADA (fase 3): cuatro siluetas salen una tras otra.
func atk_oleada() -> void:
	await _enviar(_libres(4), 0.9)


## MIRAR OTRO LADO (fase 2+): se apaga una mitad de la sala (las Voces de esa mitad quedan cubiertas hasta que un
## objeto de ruido cercano suene) y sale un grupo de 2.
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
	if not await _tele_wait(warn):
		return
	await _enviar(_libres(2), 0.7)


## Aviso sin animacion de sprite (el nodo no se ve): la senal da el sonido de aviso.
func _tele_wait(secs: float) -> bool:
	telegraph_started.emit(secs)
	return await _wait(secs)


func _enviar(members: Array, stagger: float) -> void:
	if members.is_empty():
		return
	var n := members.size()
	var rodear := n >= 2 and RNG.randf() < 0.5
	telegraph_started.emit(_warn_secs())
	_pending = n
	var g := _gen
	for i in n:
		var kind: String = "rodear" if rodear else ["shh", "cubrir"][RNG.randi_range(0, 1)]
		if kind == "cubrir" and current_phase < 2 and RNG.randf() < 0.5:
			kind = "shh"
		_rutina(members[i], kind, i * stagger, i, n, g)
	var t := 0.0
	while _pending > 0:
		if not await _frame():
			return
		t += 1.0 / 60.0
		if t > 30.0:
			return


## Lo que hace una silueta desde que se levanta hasta que vuelve a sentarse.
func _rutina(c: SilencioCuerpo, kind: String, delay: float, slot: int, count: int, g: int) -> void:
	if delay > 0.0 and not await _wait(delay):
		return
	c.salir()
	if not await _wait(0.45):
		return
	match kind:
		"shh":
			if not await _r_shh(c):
				return
		"cubrir":
			if not await _r_cubrir(c):
				return
		"rodear":
			if not await _r_rodear(c, slot, count):
				return
	# se queda un momento fuera (vulnerable) y vuelve a su silla
	if not await _wait(RNG.randf_range(0.8, 1.4)):
		return
	c.volver(_walk_speed() + 15.0)
	var t := 0.0
	while c.mode != SilencioCuerpo.Mode.SEATED:
		if not await _frame():
			return
		t += 1.0 / 60.0
		if t > 8.0:
			break
	if g == _gen:
		_pending -= 1


## Camina hacia ti hasta quedar a `dist` (o hasta `max_t` s). false = ataque cancelado.
func _approach(c: SilencioCuerpo, dist: float, max_t: float) -> bool:
	var t := 0.0
	while t < max_t:
		var away := c.global_position - target.global_position
		if away.length() <= dist + 12.0:
			break
		c.go(clamp_to_arena(target.global_position + away.normalized() * dist, 40.0), _walk_speed())
		if not await _frame():
			return false
		t += 1.0 / 60.0
	c.stop()
	return true


## SHH: se detiene a distancia, avisa con lineas finas y lanza ondas de "shh" cortas y lentas que apagan.
func _r_shh(c: SilencioCuerpo) -> bool:
	if not await _approach(c, 240.0, 3.2):
		return false
	var volleys := 2 if current_phase == 3 else 1
	var shots := 3 if current_phase == 1 else 5
	for v in volleys:
		c.face(target.global_position)
		c.pose(&"lean")
		var from := c.global_position + Vector2(0, -40)
		var base := (target.global_position - from).angle()
		var warn := _warn_secs()
		for k in shots:
			var ang := base + (k - (shots - 1) / 2.0) * 0.3
			_add_hazard(BossZone.rect(from + Vector2.RIGHT.rotated(ang) * 130.0, Vector2(260.0, 5.0), ang, warn, 0.05, 0.0, COL_WAVE))
		if not await _wait(warn):
			return false
		for k in shots:
			_fire_from(from, base + (k - (shots - 1) / 2.0) * 0.3, 140.0 + 15.0 * current_phase, 0.5, COL_WAVE, 2.8)
		c.pose(&"idle")
		if v < volleys - 1 and not await _wait(0.5):
			return false
	return true


## CUBRIR: se acerca y la cortina cae sobre ti: una zona oscura que anula tus golpes a las siluetas. No daña.
func _r_cubrir(c: SilencioCuerpo) -> bool:
	if not await _approach(c, 170.0, 3.2):
		return false
	c.face(target.global_position)
	c.pose(&"bow")
	var warn := _warn_secs()
	var r := MANTO_R * (1.25 if current_phase == 3 else 1.0)
	var p := clamp_to_arena(target.global_position, 90.0)
	var now := _now()
	_add_hazard(BossZone.circle(p, r, warn, MANTO_SECS, 0.0, COL_MANTO))
	_mantos.append({"pos": p, "r": r, "from": now + warn, "until": now + warn + MANTO_SECS})
	if not await _wait(warn + 0.3):
		return false
	c.pose(&"idle")
	return true


## RODEAR: forman un circulo alrededor de ti para aislarte (cierran el paso) y, juntas, lanzan una onda lenta hacia el centro.
func _r_rodear(c: SilencioCuerpo, slot: int, count: int) -> bool:
	var base := TAU * float(slot) / float(count) + RNG.randf_range(-0.2, 0.2)
	var t := 0.0
	while t < 2.2:
		var a := base + t * 0.5
		c.go(clamp_to_arena(target.global_position + Vector2.RIGHT.rotated(a) * 190.0, 40.0), _walk_speed() + 10.0)
		if not await _frame():
			return false
		t += 1.0 / 60.0
	c.stop()
	c.face(target.global_position)
	c.pose(&"lean")
	var from := c.global_position + Vector2(0, -40)
	var aim := target.global_position
	var warn := _warn_secs()
	_add_hazard(BossZone.rect(from.lerp(aim, 0.5), Vector2(from.distance_to(aim), 5.0), (aim - from).angle(), warn, 0.05, 0.0, COL_WAVE))
	if not await _wait(warn):
		return false
	_fire_from(from, (aim - from).angle(), 125.0, 0.5, COL_WAVE, 3.0)
	c.pose(&"idle")
	return true


## NADIE DIJO (FIRMA, fase 3): el audio del juego va a cero (subtitulo "..."). Cuatro siluetas salen y quedan de
## espaldas, quietas (nadie dice nada), mientras cuatro oleadas de ondas lentas llegan desde cuatro lados; solo "suena"
## lo que tu golpeas. 14 s. Si aguantas sin recibir golpe, el Pacto queda AGOTADO 2,5 s y se enciende la luz 3.
func atk_nadie_dijo() -> void:
	var h0 := _st_hits
	_audio(true)
	Silencio.cartel(["..."], 3.0)
	for o in _noise():
		o.loud = true
	if not await _tele_wait(0.85):
		return
	var c0 := arena().get_center()
	var libres := _libres(4)
	for i in libres.size():
		var c: SilencioCuerpo = libres[i]
		c.salir()
		c.go(clamp_to_arena(c0 + Vector2((i - (libres.size() - 1) / 2.0) * 80.0, 120.0), 60.0), _walk_speed())
		c.pose(&"away")
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
	_sentar_todos(_walk_speed() + 15.0)
	var w := 0.0
	while not _all_seated() and w < 6.0:
		if not await _frame():
			return
		w += 1.0 / 60.0
	if not await _wait(0.6):
		return
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
## La cura solo empieza con todas sentadas (y protegidas por la cortina).
func atk_canalizar() -> void:
	_sentar_todos()
	var w := 0.0
	while not _all_seated() and w < 4.0:
		if not await _frame():
			return
		w += 1.0 / 60.0
	await super()


## EL PACTO SE CIERRA: sentadas y cubiertas, las siluetas asienten en bloque y repiten un "shh" bajo. Se corta
## golpeando 3 objetos de ruido (eso las aturde y las deja de pie, vulnerables).
func ch_ruido() -> void:
	_ch_used.clear()
	_def_t = 1.2
	_nod = 0.0
	await _ch_loop(12.5, func(dt: float):
		_nod += dt
		var bow := int(_nod / 0.9) % 2 == 1
		for c in _cuerpos:
			if is_instance_valid(c) and c.mode == SilencioCuerpo.Mode.SEATED:
				c.pose(&"bow" if bow else &"idle"))
	for c in _cuerpos:
		if is_instance_valid(c) and c.mode == SilencioCuerpo.Mode.SEATED:
			c.pose(&"idle")


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
			_fire_from(p, (aim - p).angle(), 130.0, 0.4, COL_WAVE, 3.0))


func _susurro_spots(aim: Vector2, n: int) -> Array[Vector2]:
	var base := (global_position - aim).angle()
	var out: Array[Vector2] = []
	for i in n:
		out.append(clamp_to_arena(aim + Vector2.RIGHT.rotated(base + (i - (n - 1) / 2.0) * 0.36) * 280.0, 30.0))
	return out
