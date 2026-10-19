extends Node
class_name BossAnimator

## Animador reutilizable de jefes (prototipo con Dona Cera, pensado para los 12).
## Lee el estado del jefe cada frame (state, velocity, current_phase, _channeling, vida) y:
##  - elige la animacion de cuadros (idle/walk/attack_*/release/charge/tired/channel/hurt/intro);
##  - cambia de SpriteFrames segun la fase: <base>.tres, <base>_p2.tres, <base>_p3.tres
##    (cera mas derretida y agrietada); si no hay variantes, el jefe sigue como siempre;
##  - anima por codigo: respiracion, estirar y aplastar al moverse y al frenar, inclinarse
##    hacia atras ANTES de atacar y hacia adelante al soltar, temblor de rabia al cambiar de
##    fase, retroceso al recibir golpes, sombra que acompana al cuerpo, estela en embestidas,
##    mirar hacia el jugador y caida con aterrizaje en la intro.
## Se agrega con BossAnimator.attach(self) desde el _ready del jefe. No toca modulate ni offset
## del sprite (los usa el aviso del jefe): mueve rotation, scale y position.
## Senales opcionales del jefe (se usan solo si existen): attack_released(name),
## telegraph_started(secs), channel_started, channel_ended. Sin ellas, detecta el aviso y el
## golpe mirando animated_sprite (el aviso hace temblar offset.x y al soltar lo deja en 0).
## Cada ataque busca su animacion por el nombre de la funcion (atk_tiron -> "attack_tiron";
## atk_charge -> "attack_embestida"); si no existe usa "attack". set_meta("atk", "x") lo fuerza.

const NAME := "BossAnimator"
const GHOST_EVERY := 0.045
const MAX_GHOSTS := 10
## Alto minimo (px) de un cuadro para considerarlo de alta densidad.
const HD_MIN_H := 150

var boss: EnemyBoss
var spr: AnimatedSprite2D
var _sets: Array[SpriteFrames] = []
var _level := -1
var _base_scale := Vector2.ONE
var _t := 0.0
# animacion por cuadros
var _variant := ""          # animacion de aviso en curso ("attack_tiron"...) o ""
var _released := false
var _shaking := false
var _zero_frames := 0
var _hold_until := 0.0      # tras soltar, no cambiar de animacion hasta este instante
var _sig_release := false   # el jefe emite attack_released: no hace falta adivinar
# movimiento por codigo (resortes)
var _lean := 0.0            # rad, + = hacia delante
var _lean_v := 0.0
var _lean_goal := 0.0
var _squash := 0.0          # + = aplastado (ancho y bajo), - = estirado
var _squash_v := 0.0
var _prev_speed := 0.0
var _prev_hp := -1.0
var _recoil := Vector2.ZERO
var _rage := 0.0
var _lift := 0.0            # altura de la caida de la intro
var _intro_t := 0.0
var _hurt_cd := 0.0
var _ghost_t := 0.0
var _ghosts := 0
var _shadow: Sprite2D = null
var _shadow_scale := Vector2.ONE
var _shadow_pos := Vector2.ZERO
var _landed := false
var _queue: Array[StringName] = []
var _prev_state := -1
var _tele_t := 0.0
var _tele_n := 0
var _rel_t := -99.0
var _rel_v := ""
var _next_blink := 2.0
var _next_gesture := 7.0
var _tele_est := {"attack_tiron": 0.9, "attack_salpicadura": 0.45, "attack_cruz": 0.95, "attack_embestida": 0.85, "attack": 0.65}


## Agrega el animador al jefe si su SpriteFrames tiene variantes por fase o animaciones nuevas.
## `legacy` = true: jefe con el arte de siempre (40x60: idle/walk/attack/hurt/death, sin "release" ni "intro"):
## solo pone la animacion por codigo (respirar, estirar, inclinarse, sombra, estela) sobre esos cuadros.
static func attach(b: EnemyBoss, legacy := false) -> BossAnimator:
	var spr_: AnimatedSprite2D = b.get_node_or_null("AnimatedSprite2D")
	if spr_ == null or spr_.sprite_frames == null or not (legacy or spr_.sprite_frames.has_animation("release")):
		return null  # sin cuadros nuevos: el jefe sigue con su animacion de siempre
	var a := BossAnimator.new()
	a.name = NAME
	b.add_child(a)
	a.setup(b, spr_)
	return a


func setup(b: EnemyBoss, s: AnimatedSprite2D) -> void:
	boss = b
	spr = s
	_base_scale = s.scale
	# Cuadros de alta densidad (1 pixel de arte = 1 unidad, como el heroe): el .tscn trae scale 1.5
	# y offset -60 pensados para 80x120; aqui el sprite vuelve a scale 1 y los pies siguen en y=0.
	var t0 := s.sprite_frames.get_frame_texture("idle", 0)
	if t0 != null and t0.get_height() >= HD_MIN_H:
		_base_scale = s.scale / 1.5
		s.scale = _base_scale
		s.offset = Vector2(0, -t0.get_height() * 0.5)
	_load_sets(s.sprite_frames)
	_level = 0
	_prev_hp = b.current_health
	for sig in ["attack_released", "telegraph_started", "channel_started", "channel_ended"]:
		if b.has_signal(sig):
			if sig == "attack_released":
				_sig_release = true
				b.connect(sig, _on_released)
			elif sig == "telegraph_started":
				b.connect(sig, _on_telegraph)
	if b.state == EnemyBoss.State.INTRO:
		_lift = 260.0
		if spr.sprite_frames.has_animation("intro"):
			spr.play("intro")
			spr.frame = 0
	_find_shadow.call_deferred()


## Reune el SpriteFrames y sus variantes por fase (<base>_p2.tres, <base>_p3.tres; sin ellas repite el anterior).
func _load_sets(sf: SpriteFrames) -> void:
	_sets = [sf]
	var base := sf.resource_path
	for n in ["_p2", "_p3"]:
		var p := base.replace(".tres", n + ".tres")
		if base != "" and ResourceLoader.exists(p):
			_sets.append(load(p))
		else:
			_sets.append(_sets[-1])


## Cambio de forma del jefe (la Hoja se vuelve la Parra): otro SpriteFrames de alta densidad, a escala 1 y con
## los pies en y=0. Llamar DESPUES de reescalar la sombra del jefe, porque el animador la recuerda.
func rebase(sf: SpriteFrames) -> void:
	_load_sets(sf)
	_level = 0
	_variant = ""
	_queue.clear()
	_base_scale = Vector2.ONE
	spr.sprite_frames = sf
	spr.offset = Vector2(0, -sf.get_frame_texture("idle", 0).get_height() * 0.5)
	spr.play("idle")
	_find_shadow()


func _find_shadow() -> void:
	_shadow = boss.get_node_or_null("ContactShadow")
	if _shadow:
		_shadow_scale = _shadow.scale
		_shadow_pos = _shadow.position


func _on_telegraph(secs: float = 0.0) -> void:
	_start_variant(secs)


func _on_released(_n = null) -> void:
	_release()


func _process(delta: float) -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var dt := minf(delta, 0.05)
	_t += dt
	_hurt_cd = maxf(0.0, _hurt_cd - dt)
	if boss.state == EnemyBoss.State.DEAD:
		_dead(dt)
		return
	_phase_look()
	_face()
	_pick_animation()
	_motion(dt)
	_hit_reaction()
	_trail(dt)
	_apply(dt)


# ---------------------------------------------------------------- cuadros
func _phase_look() -> void:
	var lv := clampi(boss.current_phase - 1, 0, _sets.size() - 1)
	if lv == _level:
		return
	_level = lv
	_rage = 1.0
	_squash = -0.18  # se infla de rabia
	_swap_frames(_sets[lv])


func _swap_frames(sf: SpriteFrames) -> void:
	if spr.sprite_frames == sf:
		return
	var a := spr.animation
	var f := spr.frame
	var playing := spr.is_playing()
	spr.sprite_frames = sf
	if sf.has_animation(a):
		spr.animation = a
		spr.frame = mini(f, sf.get_frame_count(a) - 1)
		if playing:
			spr.play(a)
			spr.frame = mini(f, sf.get_frame_count(a) - 1)


## Jefes con medidor de subidon (Don Sildenafil: boss._rush 0..1): idle/walk se cambian por idle_rush/walk_rush
## (medidor medio) o idle_max/walk_max (al tope) si el SpriteFrames las trae, asi el subidon se lee en el cuerpo.
func _rush_variant(a: StringName) -> StringName:
	if a != &"idle" and a != &"walk":
		return a
	var r = boss.get("_rush")
	if r == null:
		return a
	var v := StringName(String(a) + ("_max" if float(r) >= 0.8 else "_rush")) if float(r) >= 0.4 else a
	return v if spr.sprite_frames.has_animation(v) else a


func _play(a: StringName, scale := 1.0) -> void:
	a = _rush_variant(a)
	if not spr.sprite_frames.has_animation(a):
		return
	if spr.animation != a:
		spr.speed_scale = scale
		spr.play(a)
	elif not spr.is_playing() and spr.sprite_frames.get_animation_loop(a):
		spr.play(a)


## Reproduce una secuencia: la primera ahora y el resto al terminar cada una.
func _play_seq(list: Array) -> void:
	_queue.clear()
	if list.is_empty():
		return
	list = list.filter(func(a): return spr.sprite_frames.has_animation(a))  # arte de siempre: sin cuadros nuevos
	if list.is_empty():
		return
	spr.speed_scale = 1.0
	spr.play(list[0])
	for i in range(1, list.size()):
		_queue.append(StringName(list[i]))


func _advance_queue() -> void:
	if not _queue.is_empty() and not spr.is_playing():
		var a: StringName = _queue.pop_front()
		spr.speed_scale = 1.0
		spr.play(a)


## Elige la animacion de aviso segun el ataque en curso y la estira para que dure lo que dura el aviso:
## con la senal telegraph_started(secs) usa secs; sin ella, la duracion medida en los avisos anteriores
## del mismo ataque (arranca con el valor de Cera y se corrige sola). Nunca en bucle: queda en el ultimo
## cuadro de carga hasta soltar.
func _start_variant(secs := 0.0) -> void:
	var atk := str(boss.get_meta("atk", str(boss._last_attack).trim_prefix("atk_")))
	atk = {"charge": "embestida"}.get(atk, atk)
	var v := "attack_" + atk if atk != "" else "attack"
	if not spr.sprite_frames.has_animation(v) or (atk == "tiron" and _tele_n >= 1):
		v = "attack"  # el manotazo final del tiron usa la carga generica
	_tele_n += 1
	_variant = v
	_released = false
	_shaking = false
	_zero_frames = 0
	_queue.clear()
	var est: float = secs if secs > 0.05 else float(_tele_est.get(v, 0.65))
	var frames := spr.sprite_frames.get_frame_count(v)
	var fps := spr.sprite_frames.get_animation_speed(v)
	spr.speed_scale = clampf(float(frames) / (fps * est), 0.25, 3.0)
	spr.play(v)
	_tele_t = _t


func _release() -> void:
	if _released or _variant == "":
		return
	_released = true
	var v := _variant
	_variant = ""
	var measured := _t - _tele_t
	if measured > 0.15 and measured < 2.0:
		_tele_est[v] = lerpf(float(_tele_est.get(v, measured)), measured, 0.7)
	_rel_t = _t
	_rel_v = v
	_lean_v += 7.0  # latigazo hacia delante
	_squash_v -= 5.0
	match v:
		"attack_cruz":
			_play_seq([&"cross_spin"])
		"attack_embestida":
			_play_seq([&"charge"])
		"attack_salpicadura":
			_play_seq([&"release_spit", &"spitting"])
		"attack_tiron":
			_play_seq([&"release", &"drag"])  # si falla, el estado TIRED lo cambia por "stuck"
		_:
			var own := StringName("release_" + v.trim_prefix("attack_"))  # cada ataque puede traer su propio golpe
			_play_seq([own if spr.sprite_frames.has_animation(own) else &"release"])


func _on_state_change(from: int, to: int) -> void:
	if to == EnemyBoss.State.ATTACK:
		_tele_n = 0
		_variant = ""
	if to == EnemyBoss.State.TIRED:
		_variant = ""
		var stunned := bool(boss.get_meta("stunned", false))
		if stunned:
			_play_seq([&"stun_in", &"tired"])
			_squash_v += 4.0
		elif _rel_v == "attack_tiron" and _t - _rel_t < 0.6:
			_play_seq([&"stuck"])  # la tira quedo pegada y forcejea
		elif spr.animation == &"charge" or boss.velocity.length() > 150.0:
			_play_seq([&"brake", &"recover"])
		else:
			_play_seq([&"recover_in", &"recover"])
	elif from == EnemyBoss.State.TIRED or to == EnemyBoss.State.IDLE:
		_queue.clear()
		spr.speed_scale = 1.0


const SPECIAL_ATTACK_ANIMS := [&"release", &"release_spit", &"spitting", &"cross_spin", &"charge", &"drag"]


func _pick_animation() -> void:
	var st := boss.state
	var speed := boss.velocity.length()
	if st != _prev_state:
		_on_state_change(_prev_state, st)
		_prev_state = st
	if boss._channeling:
		_variant = ""
		_play(&"channel")
		return
	_advance_queue()
	match st:
		EnemyBoss.State.INTRO:
			if spr.animation != &"intro" and spr.animation != &"death" and spr.sprite_frames.has_animation("intro"):  # la Hoja cae ("death") mientras el jefe sigue en INTRO
				spr.play("intro")
		EnemyBoss.State.TRANSITION:
			_variant = ""
			_play(&"idle")
		EnemyBoss.State.TIRED:
			if _queue.is_empty() and not spr.is_playing():
				_play(&"recover" if not bool(boss.get_meta("stunned", false)) else &"tired")
		EnemyBoss.State.IDLE:
			_variant = ""
			_idle_life(speed)
		EnemyBoss.State.ATTACK:
			if spr.animation == &"attack" and _variant != "attack":  # el jefe acaba de empezar un aviso
				_start_variant()
			if _variant != "" and not _released and not _sig_release:
				if absf(spr.offset.x) > 0.001:
					_shaking = true
					_zero_frames = 0
				elif _shaking:
					_zero_frames += 1
					if _zero_frames >= 2:
						_release()
			# tras soltar, la animacion de golpe se queda en su ultimo cuadro hasta que acabe el ataque
			if _variant == "" and spr.animation not in SPECIAL_ATTACK_ANIMS and not spr.animation.begins_with("attack") and not spr.animation.begins_with("release"):
				spr.speed_scale = clampf(speed / 90.0, 0.6, 1.7) if speed > 12.0 else 1.0
				_play(&"walk" if speed > 12.0 else &"idle")


var _gesture_playing := false


## Reposo con vida: parpadeo al azar, gestos (revolver la cera, impaciencia si la haces correr),
## velocidad de idle que respira y walk que sigue la velocidad real.
func _idle_life(speed: float) -> void:
	if _t < _hold_until or (spr.animation == &"hurt" and spr.is_playing()):
		return
	if speed > 12.0:
		_queue.clear()
		_play(&"walk")
		spr.speed_scale = clampf(speed / 90.0, 0.6, 1.7)
		return
	var a := spr.animation
	if a in [&"blink", &"idle_stir", &"idle_impatient"] and spr.is_playing():
		return
	if a == &"idle" or a == &"idle_rush" or a == &"idle_max":
		var want := _rush_variant(&"idle")  # el medidor cambio de tramo: se cambia de variante
		if a != want:
			spr.play(want)
		a = &"idle"  # idle_rush / idle_max cuentan como idle (se sigue respirando y parpadeando)
	if a != &"idle":
		if not _queue.is_empty() and not spr.is_playing():
			return
		_queue.clear()
		_play(&"idle")
		_next_blink = _t + randf_range(1.2, 3.0)
		return
	spr.speed_scale = 0.85 + 0.2 * sin(_t * 0.7 + 1.3) + 0.05 * sin(_t * 2.3)
	if _t >= _next_gesture:
		_next_gesture = _t + randf_range(6.0, 12.0)
		var far := boss.target != null and is_instance_valid(boss.target) and boss.global_position.distance_to(boss.target.global_position) > 330.0
		var g: StringName = &"idle_impatient" if (far or randf() < 0.4) else &"idle_stir"
		_play_seq([g, &"idle"])
	elif _t >= _next_blink:
		_next_blink = _t + randf_range(2.2, 5.0)
		_play_seq([&"blink", &"idle"])


# ---------------------------------------------------------------- movimiento por codigo
func _face() -> void:
	if boss.target == null or not is_instance_valid(boss.target):
		return
	if spr.animation == &"charge" and absf(boss.velocity.x) > 5.0:
		spr.flip_h = boss.velocity.x < 0.0
		return
	var dx := boss.target.global_position.x - boss.global_position.x
	if absf(dx) > 6.0:
		spr.flip_h = dx < 0.0


func _facing() -> float:
	return -1.0 if spr.flip_h else 1.0


func _motion(dt: float) -> void:
	var speed := boss.velocity.length()
	_lean_goal = 0.0
	if _variant != "" and not _released:
		_lean_goal = -0.17  # anticipacion: echarse hacia atras
		if _variant == "attack_embestida":
			_lean_goal = -0.26
	elif boss.state == EnemyBoss.State.TIRED:
		_lean_goal = 0.12 if bool(boss.get_meta("stunned", false)) else 0.15 + 0.03 * sin(_t * 6.0)  # cabeza gacha / jadeando
	elif spr.animation == &"charge":
		_lean_goal = 0.28
	elif speed > 12.0:
		_lean_goal = 0.05 * clampf(speed / 150.0, 0.0, 1.0)
	# resorte de inclinacion
	_lean_v += ((_lean_goal - _lean) * 160.0 - _lean_v * 14.0) * dt
	_lean += _lean_v * dt
	# frenazo: aplasta; arranque: estira
	var ds := speed - _prev_speed
	if _prev_speed > 40.0 and speed < _prev_speed * 0.5:
		_squash_v += 3.5
	elif ds > 120.0 * dt * 6.0 and speed > 30.0:
		_squash_v -= 2.0
	_prev_speed = speed
	_squash_v += (-_squash * 120.0 - _squash_v * 12.0) * dt
	_squash += _squash_v * dt
	_rage = maxf(0.0, _rage - dt * 0.55)
	if boss.state == EnemyBoss.State.TRANSITION:
		_rage = maxf(_rage, 0.6)
	_recoil = _recoil.move_toward(Vector2.ZERO, 90.0 * dt)
	# intro: cae del cielo y aterriza con golpe
	if boss.state == EnemyBoss.State.INTRO:
		_intro_t += dt
		if _intro_t > 0.35 and _lift > 0.0:
			_lift = maxf(0.0, _lift - 900.0 * dt)
			if _lift <= 0.0 and not _landed:
				_landed = true
				_squash_v += 7.0
				HitFx.shake(0.5)
				_burst()
		elif _lift > 0.0 and _intro_t <= 0.35:
			_squash = -0.22
	else:
		_lift = 0.0


func _hit_reaction() -> void:
	var hp := boss.current_health
	if _prev_hp >= 0.0 and hp < _prev_hp - 0.01:
		var bd: Dictionary = boss.get_meta("bd", {})
		var weak := str(bd.get("kind", "")) == "weak"
		var match_now := bool(bd.get("match_now", false))
		var away := Vector2.RIGHT if (boss.target == null or boss.target.global_position.x > boss.global_position.x) else Vector2.LEFT
		var k := 1.0
		if match_now:
			k = 4.0  # MATCH: reaccion enorme
		elif weak:
			k = 2.2  # "LE DUELE": se nota mas
		_squash_v += 2.5 * k
		_recoil = -away * 3.0 * k
		_lean_v -= 3.0 * k
		# el retroceso de cuadros no corta ataques ni la recuperacion: solo en reposo
		var big := (_prev_hp - hp) > boss.max_health * 0.03
		if (big or weak) and _hurt_cd <= 0.0 and boss.state == EnemyBoss.State.IDLE and not boss._channeling:
			_hurt_cd = 0.5
			_play_seq([&"hurt"])
	_prev_hp = hp


func _apply(dt: float) -> void:
	var f := _facing()
	var breathe := sin(_t * 2.6) * 0.012
	var rage_j := _rage * 0.07
	var sx := 1.0 + _squash * 0.55 - breathe * 0.5
	var sy := 1.0 - _squash * 0.55 + breathe + _rage * 0.04 * sin(_t * 30.0)
	spr.scale = Vector2(_base_scale.x * sx, _base_scale.y * sy)
	spr.rotation = _lean * f + rage_j * sin(_t * 47.0)
	var bob := -1.2 * (0.5 + 0.5 * sin(_t * 3.0)) if boss.state == EnemyBoss.State.IDLE and boss.velocity.length() < 12.0 else 0.0
	spr.position = Vector2(_recoil.x + _rage * 2.5 * sin(_t * 61.0), bob - _lift)
	# sombra: acompana el cuerpo, se achica con la altura
	if _shadow == null or not is_instance_valid(_shadow):
		return
	var h := clampf(-spr.position.y / 80.0, 0.0, 3.0)
	var k := 1.0 / (1.0 + h) * (1.0 + _squash * 0.5)
	_shadow.scale = _shadow_scale * Vector2(k, k)
	_shadow.position = _shadow_pos + Vector2(sin(spr.rotation) * -28.0, 0.0)
	_shadow.modulate.a = clampf(1.0 - h * 0.35, 0.25, 1.0)


# ---------------------------------------------------------------- efectos
func _trail(dt: float) -> void:
	if spr.animation != &"charge" or boss.velocity.length() < 200.0:
		return
	_ghost_t -= dt
	if _ghost_t > 0.0 or _ghosts >= MAX_GHOSTS:
		return
	_ghost_t = GHOST_EVERY
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	g.centered = true
	g.offset = spr.offset
	g.flip_h = spr.flip_h
	g.scale = spr.scale
	g.rotation = spr.rotation
	g.modulate = Color(1.0, 0.8, 0.35, 0.5)
	g.z_index = -1
	var host := boss.get_parent()
	host.add_child(g)
	g.global_position = boss.global_position + spr.position
	_ghosts += 1
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func():
		_ghosts -= 1
		g.queue_free())


## Salpicon dorado al aterrizar en la intro.
func _burst() -> void:
	var host := boss.get_parent()
	for i in 10:
		var p := ColorRect.new()
		p.size = Vector2(5, 5)
		p.color = Color(1.0, 0.8, 0.3)
		p.z_index = 5
		host.add_child(p)
		p.global_position = boss.global_position + Vector2(RNG.randf_range(-30, 30), -6)
		var ang := RNG.randf_range(-PI * 0.95, -PI * 0.05)
		var to := p.global_position + Vector2.RIGHT.rotated(ang) * RNG.randf_range(40.0, 90.0)
		var tw := p.create_tween().set_parallel(true)
		tw.tween_property(p, "global_position", to, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, 0.4)
		tw.chain().tween_callback(p.queue_free)


func _dead(dt: float) -> void:
	spr.rotation = lerpf(spr.rotation, 0.0, dt * 8.0)
	spr.scale = spr.scale.lerp(_base_scale, dt * 8.0)
	spr.position = spr.position.lerp(Vector2.ZERO, dt * 8.0)
	if _shadow and is_instance_valid(_shadow):
		_shadow.scale = _shadow.scale.lerp(_shadow_scale * 1.3, dt * 3.0)
