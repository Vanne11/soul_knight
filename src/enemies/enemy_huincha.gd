extends Enemy3a
class_name EnemyHuincha

## Huincha de Medir: reacciona distinto segun TU heroe (siempre hace dano, cambia como te enfrenta).
##   Pitocles      te persigue para MEDIRTE: si te alcanza se te enrolla (te frena), te muestra un
##                 numero y la burbuja/narrador comentan con crueldad.
##   Vulvalquiria  te PICA con el gancho de metal como un estoque: avisa mas lejos, embiste
##                 rapidisimo y se queda agotada.
##   Ornitorrinco  no sabe que medir y HUYE... pero si te acercas mucho EMBISTE en panico.

const WRAP_TIME := 1.5
const PANIC_RANGE := 100.0
const CRUEL_MIN := 5.0
const CRUEL_MAX := 11.5   ## el numero (cm) siempre es mas bien... modesto (el humor es de la huincha)
var _confused_said := false


func _setup() -> void:
	personality = "medidor"
	move_speed = 135.0
	lunge_trigger = 78.0
	windup_time = 0.42
	lunge_time = 0.22
	lunge_speed = 500.0
	recover_time = 0.7
	match hero:
		"vulvalquiria":
			lunge_trigger = 180.0
			windup_time = 0.4
			lunge_time = 0.2
			lunge_speed = 800.0
			recover_time = 0.95
			damage *= 1.2
		"ornitorrinco":
			windup_time = 0.2
			lunge_speed = 640.0
			recover_time = 1.0


func _chase(delta: float) -> void:
	if hero != "ornitorrinco" or target == null:
		super._chase(delta)
		return
	var to: Vector2 = target.global_position - global_position
	var d := to.length()
	if d <= PANIC_RANGE and _attack_timer <= 0.0:
		_say("huincha_panic", 1.4)
		state = State.WINDUP
		_state_timer = windup_time
		_lunge_dir = to.normalized()
		animated_sprite.play("attack")
		return
	if d > detection_range * 1.2:
		velocity = Vector2.ZERO
		return
	if not _confused_said and d < 330.0:
		_confused_said = true
		_say("huincha_confused", 2.2)
		E3a.icon(self, "question", 1.4)
	velocity = -to.normalized() * move_speed * 0.9
	_update_animation(-to)


func _on_player_hit(p: Node) -> void:
	if hero != "pitocles":
		return
	var cm := snappedf(RNG.randf_range(CRUEL_MIN, CRUEL_MAX), 0.1)
	var st := StatusEffects.of(p)
	if st != null:
		st.apply("enrollado", WRAP_TIME, self)
	_say("huincha_measure", 2.6, str(cm))
	E3a.floating(p.global_position + Vector2(0, -52), "%s cm" % cm, Color("ffd23a"))
	E3a.note("e3a_huincha")
