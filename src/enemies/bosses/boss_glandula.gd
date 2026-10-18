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
## Cura (cargas = numero de jefe): TURNO, REVISTAS, SALA DE ESPERA, PUNTO DEBIL, CAFE.

const NUT := Color(1.0, 0.72, 0.6)
const DROP := Color(1.0, 0.92, 0.35)
const SIZES := [1.0, 1.22, 1.48]

var _base_scale := Vector2.ONE
var _grow_tween: Tween = null


func _ready() -> void:
	super()
	fan_tint = DROP
	move_speed = 55.0
	keep_min = 240.0
	keep_max = 380.0
	_base_scale = animated_sprite.scale
	_to_center()


## Nace en el centro de la sala (el punto de aparicion de jefes queda pegado al muro de arriba y
## la jefa, que crece, se saldria de pantalla).
func _to_center() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(self) and state == State.INTRO:
		global_position = arena().get_center() + Vector2(0, 95)


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_goteo", &"atk_empuje", &"atk_fan"]
		2:
			return [&"atk_goteo", &"atk_empuje", &"atk_borde", &"atk_fan", &"atk_charge"]
	return [&"atk_goteo", &"atk_empuje", &"atk_empuje", &"atk_borde", &"atk_borde", &"atk_charge", &"atk_fan"]


func _challenges() -> Array:
	return [&"ch_turno", &"ch_revistas", &"ch_sala", &"ch_punto", &"ch_cafe"]


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
	move_speed = 55.0 + 10.0 * (n - 1)
	_grow(SIZES[n - 1], 1.2)


func _on_death() -> void:
	if Prostata.hero() == "vulvalquiria":
		Prostata.codex("prostata_skene")  # las glandulas de Skene: la "prostata" de ella (codice)


## Crece (hiperplasia): sprite y formas de colision/golpe, con los pies en el mismo sitio.
func _grow(k: float, secs: float) -> void:
	if is_instance_valid(_grow_tween):
		_grow_tween.kill()
	_grow_tween = create_tween().set_parallel(true)
	_grow_tween.tween_property(animated_sprite, "scale", _base_scale * k, secs)
	for path in ["CollisionShape2D", "Hurtbox", "Hitbox"]:
		var n := get_node_or_null(path) as Node2D
		if n == null:
			continue
		if not n.has_meta("base_y"):
			n.set_meta("base_y", n.position.y)
		_grow_tween.tween_property(n, "scale", Vector2(k, k), secs)
		_grow_tween.tween_property(n, "position:y", float(n.get_meta("base_y")) * k, secs)


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
		_fire(a + i * 0.5 * sgn, 130.0 + current_phase * 12.0, 0.6, DROP)
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
	var z := BossZone.circle(global_position, r, 1.0, 0.3, damage * 0.8, NUT)
	z.went_active.connect(func():
		if is_instance_valid(target) and z.contains(target.global_position):
			var d: Vector2 = target.global_position - global_position
			_shove(d.normalized() if d.length() > 1.0 else Vector2.RIGHT, 520.0))
	_add_hazard(z)
	if not await _tele(0.95, Color(2.2, 1.6, 1.4), 3.0):
		return
	Sound.play("crack")
	HitFx.shake(0.45)
	if current_phase >= 2:
		_fire_ring(12 + current_phase * 2, 170.0, RNG.randf_range(0.0, TAU), 0.0, 0.0, 0.5, DROP)
	if not await _wait(0.6):
		return
	_tire(1.1)


## Franjas pegadas a los muros que se hinchan hacia dentro: quedate al centro.
func atk_borde() -> void:
	var a := arena().grow(-8.0)
	var t := 70.0 + 28.0 * current_phase
	var warn := 1.4
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
func ch_cafe() -> void:
	await _ch_chase("cup", {"speed": 340.0, "limit": 8.0})
