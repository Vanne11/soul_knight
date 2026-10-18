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


## Agrega el animador al jefe si su SpriteFrames tiene variantes por fase o animaciones nuevas.
static func attach(b: EnemyBoss) -> BossAnimator:
	var spr_: AnimatedSprite2D = b.get_node_or_null("AnimatedSprite2D")
	if spr_ == null or spr_.sprite_frames == null or not spr_.sprite_frames.has_animation("release"):
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
	_sets = [s.sprite_frames]
	var base := s.sprite_frames.resource_path
	for n in ["_p2", "_p3"]:
		var p := base.replace(".tres", n + ".tres")
		if base != "" and ResourceLoader.exists(p):
			_sets.append(load(p))
		else:
			_sets.append(_sets[-1])
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
		spr.play("intro")
		spr.frame = 0
	_find_shadow.call_deferred()


func _find_shadow() -> void:
	_shadow = boss.get_node_or_null("ContactShadow")
	if _shadow:
		_shadow_scale = _shadow.scale
		_shadow_pos = _shadow.position


func _on_telegraph(_secs: float = 0.0) -> void:
	_start_variant()


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


func _play(a: StringName) -> void:
	if spr.animation != a and spr.sprite_frames.has_animation(a):
		spr.play(a)
	elif spr.animation == a and not spr.is_playing() and spr.sprite_frames.get_animation_loop(a):
		spr.play(a)


## Elige la variante de aviso segun lo que el jefe marco con set_meta("atk", ...).
func _start_variant() -> void:
	var atk := str(boss.get_meta("atk", str(boss._last_attack).trim_prefix("atk_")))
	atk = {"charge": "embestida"}.get(atk, atk)
	var v := "attack_" + atk if atk != "" else "attack"
	if not spr.sprite_frames.has_animation(v):
		v = "attack"
	_variant = v
	_released = false
	_shaking = false
	_zero_frames = 0
	spr.play(v)


func _release() -> void:
	if _released or _variant == "":
		return
	_released = true
	var v := _variant
	_variant = ""
	_lean_v += 7.0  # latigazo hacia delante
	_squash_v -= 5.0
	if v == "attack_cruz":
		return  # la cruz sigue girando: se queda en su bucle
	var rel := "release_spit" if v == "attack_salpicadura" else "release"
	if v == "attack_embestida":
		rel = "charge"
	if spr.sprite_frames.has_animation(rel):
		spr.play(rel)
		_hold_until = _t + 0.25


func _pick_animation() -> void:
	var st := boss.state
	var speed := boss.velocity.length()
	if boss._channeling:
		_variant = ""
		_play(&"channel")
		return
	match st:
		EnemyBoss.State.INTRO:
			if spr.animation != &"intro":
				spr.play("intro")
		EnemyBoss.State.TRANSITION:
			_variant = ""
			_play(&"idle")
		EnemyBoss.State.TIRED:
			_variant = ""
			_play(&"tired")
		EnemyBoss.State.IDLE:
			_variant = ""
			if _t < _hold_until or (spr.animation == &"hurt" and spr.is_playing()):
				return
			_play(&"walk" if speed > 12.0 else &"idle")
		EnemyBoss.State.ATTACK:
			if spr.animation == &"attack":  # el jefe acaba de empezar un aviso
				_start_variant()
			if _variant != "" and not _released and not _sig_release:
				if absf(spr.offset.x) > 0.001:
					_shaking = true
					_zero_frames = 0
				elif _shaking:
					_zero_frames += 1
					if _zero_frames >= 2:
						_release()
			if _variant == "" and _t >= _hold_until:
				if speed > 250.0:
					_play(&"charge")
				elif not spr.animation.begins_with("attack") and spr.animation not in [&"release", &"release_spit", &"charge"]:
					_play(&"walk" if speed > 12.0 else &"idle")
				elif spr.animation == &"charge" and speed < 120.0:
					_play(&"idle")


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
		_lean_goal = 0.1  # cabeza gacha
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
		_squash_v += 2.5
		var away := Vector2.RIGHT if (boss.target == null or boss.target.global_position.x > boss.global_position.x) else Vector2.LEFT
		_recoil = -away * 3.0
		_lean_v -= 3.0
		var big := (_prev_hp - hp) > boss.max_health * 0.03
		if big and _hurt_cd <= 0.0 and boss.state == EnemyBoss.State.IDLE and not boss._channeling:
			_hurt_cd = 0.8
			spr.play("hurt")
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
