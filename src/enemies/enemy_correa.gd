extends Enemy3a
class_name EnemyCorrea

## La Correa (bondage; idea de Vanessa): te engancha desde lejos y te ARRASTRA hacia su dueno,
## que te espera con una embestida. El aviso es un tiron visible; el DASH te suelta (y la
## correa tarda en volver a lanzarse). Si te atrapa y llegas a el, te pega.

const HOOK_RANGE := 430.0
const HOOK_TIME := 1.7
const HOOK_CD := 4.0
const HOOK_WINDUP := 0.55
var _hook_cd := 1.5
var _casting := false


func _setup() -> void:
	personality = "bondage"
	move_speed = 105.0
	lunge_trigger = 85.0
	windup_time = 0.4
	lunge_time = 0.22
	lunge_speed = 540.0
	recover_time = 0.8


func _physics_process(delta: float) -> void:
	_hook_cd = maxf(0.0, _hook_cd - delta)
	super._physics_process(delta)


func _hooked() -> bool:
	if target == null:
		return false
	var st := target.get_node_or_null("StatusEffects")
	return st is StatusEffects and st.active("enganchado")


func _chase(delta: float) -> void:
	if target == null:
		return
	var to: Vector2 = target.global_position - global_position
	var d := to.length()
	if _hooked():
		# la presa viene sola: esperala y dale cuando llegue
		velocity = Vector2.ZERO
		_update_animation(to)
		if d <= lunge_trigger and _attack_timer <= 0.0:
			super._chase(delta)
		return
	if _hook_cd <= 0.0 and d <= HOOK_RANGE and d > 120.0:
		_casting = true
		state = State.WINDUP
		_state_timer = HOOK_WINDUP
		_lunge_dir = to.normalized()
		animated_sprite.play("attack")
		_say("correa_cast", 1.2)
		return
	if d < 110.0:
		super._chase(delta)  # demasiado cerca: a golpes
		return
	velocity = to.normalized() * move_speed
	_update_animation(to)


## Fin del aviso: si estaba lanzando la correa, la suelta en vez de embestir.
func _start_lunge() -> void:
	if not _casting:
		super._start_lunge()
		return
	_casting = false
	state = State.CHASE
	_hook_cd = HOOK_CD
	animated_sprite.offset.x = 0.0
	animated_sprite.modulate = Color.WHITE
	if target == null:
		return
	if (target.global_position - global_position).length() > HOOK_RANGE * 1.15:
		return
	var st := StatusEffects.of(target)
	if st != null and st.apply("enganchado", HOOK_TIME, self):
		_say("correa_hooked", 2.0)
		E3a.note("e3a_correa")
