extends BossAltBase

## LA GLANDULA CALLADA (jefa UNICA de La Prostata). No dice nada. Nunca. Presentacion: el narrador
## la susurra en la pantalla de presentacion ("No dice nada. Nunca dice nada. Hasta que es tarde.").
## En la fase 3, y solo ahi, dice "Debiste venir antes.".
## HIPERPLASIA: crece en cada fase (x1, x1.22, x1.48): mas cuerpo, mas alcance, mas sala ocupada.
## Ataques (todos avisan antes de pegar):
## - GOTEO: espiral de gotas lentas que se corta y retoma (el ritmo es el aviso);
## - EMPUJE: el aviso es un circulo que se llena alrededor de ella; al activarse te empuja fuera
##   (dano + empujon) y, de la fase 2 en adelante, suelta un anillo de gotas;
## - BORDE (fase 2+): franjas pegadas a los muros se "hinchan" hacia dentro: quedate al centro;
## - EMBESTIDA lenta (fase 2+) y ABANICO. Agotada tras el empuje, el borde y la embestida.
## Cura (2 cargas): TURNO, REVISTAS, SALA DE ESPERA, PUNTO DEBIL, CAFE.
## MOTOR DINAMICO (J1) + identidad J2 "PRESION CONSTANTE": un aro visible a su alrededor (crece con ella)
## te empuja sin parar hacia afuera, contra los muros; el empuje es menor que tu paso (un dash o caminar
## en contra lo vence) pero no te deja quedarte quieto cerca. Los SINTOMAS (enemy_sintoma.gd) la ayudan:
## cada uno vivo aprieta mas el aro. Pocos en fase 1, mas en fase 3; reventarlos suelta corazon a veces.

const NUT := Color(1.0, 0.72, 0.6)
const DROP := Color(1.0, 0.92, 0.35)
const SIZES := [1.0, 1.22, 1.48]
const SINTOMA := preload("res://src/enemies/enemy_sintoma.tscn")
const BASE_SPEED := [95.0, 115.0, 135.0]
const BASE_CAPS := [0.9, 0.75, 0.65]
const PUSH_BASE := 62.0         ## px/s del aro (tu paso es 250)
const PUSH_PHASE := 22.0
const PUSH_SINTOMA := 14.0

var _base_scale := Vector2.ONE
var _grow_tween: Tween = null
var _anim: BossAnimator = null
var _k := 1.0                   ## factor de crecimiento actual
var _ring: PressureRing = null
var _press_hint := false


## Aro de presion: se ve siempre (peligro suave, nunca blanco): chevrones que salen hacia afuera.
class PressureRing extends Node2D:
	var radius := 160.0
	var strength := 0.5
	var t := 0.0
	var color := Color(1.0, 0.72, 0.6)

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 72, Color(color, 0.55 + 0.3 * pulse), 4.0)
		draw_circle(Vector2.ZERO, radius, Color(color, 0.12 + 0.06 * strength))
		for i in 12:
			var a := i * TAU / 12.0 + t * 0.15
			var f := fposmod(t * 0.9 + i * 0.37, 1.0)
			var r := radius * (0.55 + 0.45 * f)
			var d := Vector2.RIGHT.rotated(a)
			var o := d.orthogonal()
			var tip := d * (r + 14.0)
			var al := (1.0 - f) * 0.7
			draw_line(tip, d * r + o * 9.0, Color(color, al), 2.5)
			draw_line(tip, d * r - o * 9.0, Color(color, al), 2.5)


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = DROP
	move_speed = BASE_SPEED[0]
	keep_min = 90.0
	keep_max = 190.0
	rest_min = 0.5
	rest_max = 0.9
	bullet_speed = 300.0
	tele_caps = BASE_CAPS.duplicate()
	# max 2 curas por pelea
	_channels_total = 2
	_channels_left = 2
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)
	_anim = BossAnimator.attach(self, true)  # arte de siempre, animacion por codigo
	_base_scale = animated_sprite.scale
	_ring = PressureRing.new()
	_ring.show_behind_parent = true
	_ring.color = NUT
	add_child(_ring)
	_to_center()


## Nace en el centro de la sala (el punto de aparicion de jefes queda pegado al muro de arriba y
## la jefa, que crece, se saldria de pantalla).
func _to_center() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(self) and state == State.INTRO:
		global_position = arena().get_center() + Vector2(0, 95)


func _attack_pool() -> Array:
	var pool: Array
	match current_phase:
		1:
			pool = [&"atk_goteo", &"atk_empuje", &"atk_fan", &"atk_sintomas"]
		2:
			pool = [&"atk_goteo", &"atk_empuje", &"atk_borde", &"atk_fan", &"atk_charge", &"atk_sintomas"]
		_:
			pool = [&"atk_goteo", &"atk_empuje", &"atk_empuje", &"atk_borde", &"atk_borde", &"atk_charge", &"atk_fan", &"atk_sintomas", &"atk_sintomas"]
	if _sintomas() >= current_phase + 1:
		pool = pool.filter(func(x): return x != &"atk_sintomas")
	return pool


func _sintomas() -> int:
	return get_tree().get_nodes_in_group("sintoma_glandula").size()


func _challenges() -> Array:
	return [&"ch_turno", &"ch_revistas", &"ch_sala", &"ch_punto", &"ch_maquina"]


func _channel_color() -> Color:
	return NUT


## Frases del narrador: bossglandula_<evento> (lines.json); al final, ademas, la del heroe.
## La jefa no habla: lo unico suyo es "Debiste venir antes." en la fase 3 (bossglandula_phase3).
func _say(suffix: String) -> void:
	var key := "bossglandula_" + suffix
	if suffix == "after":
		Narrator.say_hero(key)
	elif Narrator.has_lines(key):
		Narrator.say(key)


func _on_phase(n: int) -> void:
	_grow(SIZES[n - 1], 1.2)
	if n >= 2:
		_float_text(tr("GLAN_GROW_%d" % n), NUT, Vector2(0, 70))


## Todo peligro de la Glandula se ve como peligro (borde oscuro, franjas); el aro de presion es aparte.
func _add_hazard(z: BossZone) -> BossZone:
	if z.style == BossZone.Style.NORMAL:
		z.style = BossZone.Style.TOXIC
	return super(z)


func _tick(delta: float) -> void:
	if state in [State.INTRO, State.TRANSITION, State.DEAD] or target == null:
		return
	var ph := clampi(current_phase, 1, 3) - 1
	move_speed = BASE_SPEED[ph] * (1.3 if _furia else 1.0)
	_pressure(delta)


## PRESION CONSTANTE: dentro del aro te va empujando hacia afuera (mas fuerte cuanto mas cerca del
## cuerpo). Mueve al heroe con move_and_collide: respeta los muros y no le quita el control.
func _pressure(delta: float) -> void:
	var r := _body_radius() * 1.55 + 40.0
	var push := PUSH_BASE + PUSH_PHASE * (current_phase - 1) + PUSH_SINTOMA * mini(_sintomas(), 3)
	_ring.radius = r
	_ring.strength = push / 140.0
	_ring.visible = not _channeling
	if _channeling or not (target is CharacterBody2D):
		return
	var d: Vector2 = target.global_position - global_position
	var dist := d.length()
	if dist >= r or dist < 1.0:
		return
	if not _press_hint:
		_press_hint = true
		_float_text(tr("GLAN_PRESS"), NUT, Vector2(0, 70))
	var near := 1.0 - clampf(dist / r, 0.0, 1.0) * 0.5
	(target as CharacterBody2D).move_and_collide(d / dist * push * near * delta)


func _on_death() -> void:
	if Prostata.hero() == "vulvalquiria":
		Prostata.codex("prostata_skene")  # las glandulas de Skene: la "prostata" de ella (codice)


## Crece (hiperplasia): sprite y formas de colision/golpe, con los pies en el mismo sitio.
func _grow(k: float, secs: float) -> void:
	if is_instance_valid(_grow_tween):
		_grow_tween.kill()
	_grow_tween = create_tween().set_parallel(true)
	_grow_tween.tween_method(_set_k, _k, k, secs)
	for path in ["CollisionShape2D", "Hurtbox", "Hitbox"]:
		var n := get_node_or_null(path) as Node2D
		if n == null:
			continue
		if not n.has_meta("base_y"):
			n.set_meta("base_y", n.position.y)
		_grow_tween.tween_property(n, "scale", Vector2(k, k), secs)
		_grow_tween.tween_property(n, "position:y", float(n.get_meta("base_y")) * k, secs)


## Escala del sprite (y la base del animador, para que el "respirar" no deshaga el crecimiento).
func _set_k(k: float) -> void:
	_k = k
	animated_sprite.scale = _base_scale * k
	if _anim != null:
		_anim.set("_base_scale", _base_scale * k)


## Radio del cuerpo ahora (para las zonas de aviso).
func _body_radius() -> float:
	return 78.0 * (animated_sprite.scale.x / maxf(_base_scale.x, 0.01))


func _shove(dir: Vector2, force: float) -> void:
	var p := target as CharacterBody2D
	if p == null:
		return
	p.velocity = dir * force
	if "_sneeze_push" in p:
		p.set("_sneeze_push", 0.2)


# ---------------------------------------------------------------- ataques
## Espiral de gotas lentas que se corta y retoma: el ritmo irregular es parte del aviso.
func atk_goteo() -> void:
	if not await _tele(0.7, Color(2.2, 2.0, 1.0), 2.0):
		return
	var n := 14 + current_phase * 5
	var a := (target.global_position - _muzzle()).angle()
	var sgn := 1.0 if RNG.randf() < 0.5 else -1.0
	for i in n:
		_fire(a + i * 0.5 * sgn, 255.0 + current_phase * 15.0, 0.6, DROP)
		var gap := 0.08
		if i % 6 == 5:
			gap = 0.4  # se corta... y retoma
		if not await _wait(gap):
			return
	await _wait(0.4)
	_tire(0.8)


## Empujon: el circulo avisa el alcance; al activarse hace dano y te saca de ahi.
func atk_empuje() -> void:
	var r := _body_radius() * 1.9
	var w := minf(1.0, float(tele_caps[clampi(current_phase, 1, 3) - 1]))
	var z := BossZone.circle(global_position, r, w, 0.3, damage * 0.8, NUT)
	z.went_active.connect(func():
		if is_instance_valid(target) and z.contains(target.global_position):
			var d: Vector2 = target.global_position - global_position
			_shove(d.normalized() if d.length() > 1.0 else Vector2.RIGHT, 520.0))
	_add_hazard(z)
	if not await _tele(w, Color(2.2, 1.6, 1.4), 3.0):
		return
	Sound.play("crack")
	HitFx.shake(0.45)
	if current_phase >= 2:
		_fire_ring(12 + current_phase * 2, 260.0, RNG.randf_range(0.0, TAU), 0.0, 0.0, 0.5, DROP)
	if not await _wait(0.6):
		return
	_tire(1.1)


## Franjas pegadas a los muros que se hinchan hacia dentro: quedate al centro.
func atk_borde() -> void:
	var a := arena().grow(-8.0)
	var t := 70.0 + 28.0 * current_phase
	var warn := 1.2
	var act := 2.2
	var dmg := damage * 0.55
	var bands := [
		Rect2(a.position, Vector2(a.size.x, t)),
		Rect2(Vector2(a.position.x, a.end.y - t), Vector2(a.size.x, t)),
		Rect2(a.position + Vector2(0, t), Vector2(t, a.size.y - 2.0 * t)),
		Rect2(Vector2(a.end.x - t, a.position.y + t), Vector2(t, a.size.y - 2.0 * t)),
	]
	for r in bands:
		var z := BossZone.rect(r.get_center(), r.size, 0.0, warn, act, dmg, NUT)
		z.one_hit = false
		z.fade = 0.4
		_add_hazard(z)
	if not await _tele(warn - 0.1, Color(2.2, 1.6, 1.4), 2.5):
		return
	Sound.play("suck")
	if not await _wait(act + 0.2):
		return
	_tire(1.0)


## SINTOMAS: aparecen gotitas que la ayudan (1 / 2 / 3 segun la fase).
func atk_sintomas() -> void:
	if not await _tele(0.8, Color(2.2, 2.0, 1.0), 2.0):
		return
	var pts: Array = []
	for i in current_phase:
		var a := RNG.randf_range(0.0, TAU)
		pts.append(clamp_to_arena(global_position + Vector2.RIGHT.rotated(a) * (_body_radius() + 60.0), 50.0))
	_spawn_minions(pts, 12.0 + _floor * 2.0, 6.0 + _floor * 1.5, tr("SINTOMA_NAME"), SINTOMA)
	Sound.play("crack")
	HitFx.shake(0.15)
	await _wait(0.4)


# ---------------------------------------------------------------- desafios de la cura
## TURNO: cuatro fichas numeradas; espera tu turno (en orden).
func ch_turno() -> void:
	await _ch_touch(_spread_points(4, 160.0), "ticket", {"ordered": true, "numbered": true, "limit": 13.0})


## REVISTAS: revistas de 2009 vagan por la sala. Rompelas a tiros.
func ch_revistas() -> void:
	await _ch_break(5, "paper", {"hp": 12.0, "speed": 55.0, "limit": 13.0})


## SALA DE ESPERA: un circulo recorre la sala; quedate dentro hasta que te llamen.
func ch_sala() -> void:
	await _ch_hold("ticket", {"need": 4.5, "limit": 13.0, "radius": 90.0, "speed": 0.45})


## PUNTO DEBIL: un escudo con hueco que gira; dispara por el hueco.
func ch_punto() -> void:
	await _ch_weak({"hits": 4, "limit": 13.0, "radius": 120.0})


## CAFE: la taza de la maquina huye por la sala. Alcanzala.
func ch_maquina() -> void:
	await _ch_chase("cup", {"speed": 340.0, "limit": 8.0})
