extends EnemyPrejuicio
class_name EnemyFase

## "ES UNA FASE": una lunita que cambia de fase. Persigue y embiste como cualquiera; cada pocos
## segundos pasa a LUNA NUEVA: se vuelve fantasma, INVULNERABLE (atraviesa tus balas, no ataca y
## solo se arrastra hacia ti) y hay que ESPERARLA. Al volver sale con la luna LLENA: expuesta, recibe
## +50% de dano un rato. Es la mecanica de la paciencia: gastar balas contra la fase no sirve.
## Verdad: orientacion e identidad no son una moda de la adolescencia (ARC_VERDAD_ES_UNA_FASE).

enum Phase { ACTIVE, GHOST, EXPOSED }

const ACTIVE_TIME := Vector2(3.8, 5.2)
const GHOST_TIME := 2.4
const EXPOSED_TIME := 2.2
const EXPOSED_MULT := 1.5
const GHOST_DRIFT := 0.35   ## fraccion de su velocidad con la que se arrastra de fantasma

var _phase := Phase.ACTIVE
var _phase_t := 4.0
var _msg_cd := 0.0


func _setup_prejuicio() -> void:
	prej_id = "es_una_fase"
	move_speed = 125.0
	lunge_trigger = 100.0
	windup_time = 0.5
	lunge_time = 0.22
	lunge_speed = 470.0
	recover_time = 0.7
	_phase_t = RNG.randf_range(ACTIVE_TIME.x, ACTIVE_TIME.y)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_phase_t -= delta
	_msg_cd = maxf(0.0, _msg_cd - delta)
	match _phase:
		Phase.ACTIVE:
			# no corta un ataque a medias: cambia de fase cuando esta persiguiendo o quieta
			if _phase_t <= 0.0 and state in [State.IDLE, State.CHASE]:
				_to_ghost()
		Phase.GHOST:
			if _phase_t <= 0.0:
				_to_exposed()
		Phase.EXPOSED:
			if _phase_t <= 0.0:
				_to_active()
	if _phase == Phase.GHOST:
		_drift()
		return
	super(delta)


## Luna nueva: invulnerable, translucida, sin atacar.
func _to_ghost() -> void:
	_phase = Phase.GHOST
	_phase_t = GHOST_TIME
	state = State.CHASE
	animated_sprite.offset.x = 0.0
	animated_sprite.modulate = Color(0.75, 0.82, 1.0, 0.55)
	if animated_sprite.sprite_frames.has_animation("ghost"):
		animated_sprite.play("ghost")
	Arcoiria.say(self, "fase_nueva", 1.8)


## Luna llena: expuesta un momento.
func _to_exposed() -> void:
	_phase = Phase.EXPOSED
	_phase_t = EXPOSED_TIME
	animated_sprite.modulate = Color(1.35, 1.2, 0.85, 1.0)
	animated_sprite.play("idle")
	_attack_timer = 0.0
	Arcoiria.say(self, "fase_llena", 1.6)


func _to_active() -> void:
	_phase = Phase.ACTIVE
	_phase_t = RNG.randf_range(ACTIVE_TIME.x, ACTIVE_TIME.y)
	animated_sprite.modulate = Color.WHITE


func _drift() -> void:
	if not target or not is_instance_valid(target):
		_find_target()
	if target:
		var to: Vector2 = target.global_position - global_position
		velocity = to.normalized() * move_speed * GHOST_DRIFT if to.length() > 70.0 else Vector2.ZERO
		if absf(to.x) > 1.0:
			animated_sprite.flip_h = to.x < 0.0
	move_and_slide()


func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if state == State.DEAD:
		return 0.0
	if _phase == Phase.GHOST:
		if _msg_cd <= 0.0:
			_msg_cd = 1.2
			Arcoiria.say(self, "fase_espera", 1.2)
		HitFx.flash(animated_sprite, 0.04)
		return 0.0
	if _phase == Phase.EXPOSED:
		amount *= EXPOSED_MULT
	return super(amount, source, kb)
