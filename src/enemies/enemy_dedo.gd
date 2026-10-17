extends Enemy3a
class_name EnemyDedo

## Dedo del Urologo: dedo gigante con guante de latex que SOLO ataca POR LA ESPALDA. Te rodea
## para ponerse detras; si lo mantienes al frente (tu punteria hacia el) no te puede hacer nada
## y cuando se lanza de frente se choca, se avergüenza y se queda aturdido.
## "Frente" = hacia donde apuntas (player._aim). Detras = el lado opuesto.

const ORBIT_RADIUS := 130.0
const BEHIND_MIN_DOT := 0.25     ## cuan "detras" debe estar al conectar (1 = justo detras)
const READY_ANGLE := 0.55        ## rad de tolerancia para lanzarse
const FRONT_STUN := 1.1
var _orbit_dir := 1.0
var _front_said := false


func _setup() -> void:
	personality = "urologo"
	move_speed = 150.0
	lunge_trigger = 150.0
	windup_time = 0.5
	lunge_time = 0.26
	lunge_speed = 560.0
	recover_time = 0.8
	attack_cooldown = 0.5
	detection_range = 520.0
	_orbit_dir = 1.0 if RNG.randf() < 0.5 else -1.0


func _aim_of(p: Node) -> Vector2:
	var a = p.get("_aim")
	return (a as Vector2).normalized() if a is Vector2 and a != Vector2.ZERO else Vector2.RIGHT


## > 0 cuando estoy detras del jugador (1 = justo detras de donde mira).
func behind_dot() -> float:
	if target == null:
		return 0.0
	var to_me: Vector2 = (global_position - target.global_position).normalized()
	return to_me.dot(-_aim_of(target))


func _chase(_delta: float) -> void:
	if target == null:
		return
	var rel: Vector2 = global_position - target.global_position
	var dist := rel.length()
	var back_dir := -_aim_of(target)
	var diff := wrapf(back_dir.angle() - rel.angle(), -PI, PI)
	if dist > ORBIT_RADIUS * 2.4:
		# lejos: acercate dando un rodeo hacia su espalda
		var goal: Vector2 = target.global_position + back_dir * ORBIT_RADIUS
		var v := (goal - global_position).normalized()
		velocity = v * move_speed
		_update_animation(v)
		return
	if absf(diff) <= READY_ANGLE and dist <= lunge_trigger * 1.7 and _attack_timer <= 0.0 and behind_dot() > BEHIND_MIN_DOT:
		state = State.WINDUP
		_state_timer = windup_time
		_lunge_dir = (target.global_position - global_position).normalized()
		animated_sprite.play("attack")
		return
	# orbita por el lado mas corto hacia su espalda, ajustando el radio
	# justo de frente (diff ~ +-PI) el signo oscila: se mantiene el lado elegido hasta salir de ahi
	var side := _orbit_dir
	if absf(diff) <= 2.6:
		side = signf(diff) if absf(diff) > 0.05 else _orbit_dir
		_orbit_dir = side
	var tangent := Vector2(-rel.y, rel.x).normalized() * side  # +1 = sentido antihorario (angulo creciente)
	var radial := rel.normalized() * clampf((ORBIT_RADIUS - dist) / ORBIT_RADIUS, -1.0, 1.0) * 0.8
	velocity = (tangent + radial).normalized() * move_speed
	_update_animation(velocity)


func _strike() -> void:
	if _hit_done:
		return
	for b in hitbox.get_overlapping_bodies():
		if not b.has_method("receive_hit"):
			continue
		_hit_done = true
		if behind_dot() > BEHIND_MIN_DOT:
			if b.receive_hit(damage):
				_on_player_hit(b)
		else:
			_front_fail()
		return


## Te toco de frente: no puede. Se choca, se sonroja y se queda aturdido.
func _front_fail() -> void:
	state = State.STUNNED
	_state_timer = FRONT_STUN
	velocity = Vector2.ZERO
	animated_sprite.offset.x = 0.0
	animated_sprite.modulate = Color(1.3, 0.8, 0.9)
	_say("dedo_front", 2.2)
	E3a.icon(self, "sweat", 1.2)
	if not _front_said:
		_front_said = true
		E3a.note("e3a_dedo")
