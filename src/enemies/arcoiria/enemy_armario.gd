extends EnemyPrejuicio
class_name EnemyArmario

## "EL ARMARIO": un ropero que se esconde. Cerrado es casi invulnerable (la madera aguanta: solo te
## pasa el 10% del dano) y avanza hacia ti a saltitos; cuando esta cerca AVISA (la puerta cruje), sale
## a EMPUJAR (una embestida que te lanza hacia atras) y, al abrirse la puerta, queda EXPUESTO: ahi
## recibe dano completo (x1.5) hasta que vuelve a cerrarse. La puerta abierta es tu ventana.
## Verdad: nadie debe su orientacion a los demas; salir del closet es decision propia.

const CLOSED_MULT := 0.1
const OPEN_MULT := 1.5
const PUSH_SPEED := 640.0

var _open := false
var _knock_cd := 0.0
var _told_open := false


func _setup_prejuicio() -> void:
	prej_id = "el_armario"
	move_speed = 88.0
	lunge_trigger = 130.0
	windup_time = 0.7
	lunge_time = 0.26
	lunge_speed = 610.0
	recover_time = 1.9
	max_health *= 1.35  # es de madera


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_knock_cd = maxf(0.0, _knock_cd - delta)
	super(delta)
	_sync_door()


## La puerta esta abierta mientras recupera el aliento tras empujar (o si lo aturdes).
func _sync_door() -> void:
	var now_open := state in [State.RECOVER, State.STUNNED]
	if now_open == _open:
		return
	_open = now_open
	if _open:
		animated_sprite.play("open")
		if not _told_open:
			_told_open = true
			Arcoiria.say(self, "armario_abierto", 1.6)
	else:
		animated_sprite.play("idle")


func _on_player_hit(p: Node) -> void:
	var st := StatusEffects.of(p)
	if st != null:
		st.push((p.global_position - global_position).normalized() * PUSH_SPEED)
	Arcoiria.say(self, "armario_empuja", 1.4)


func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if state == State.DEAD:
		return 0.0
	if _open:
		return super(amount * OPEN_MULT, source, kb)
	# cerrado: la madera aguanta
	if _knock_cd <= 0.0:
		_knock_cd = 1.4
		Arcoiria.say(self, "armario_toc", 1.0)
	HitFx.flash(animated_sprite, 0.04)
	return super(amount * CLOSED_MULT, source, Vector2.ZERO)
