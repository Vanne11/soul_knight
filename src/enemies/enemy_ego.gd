extends Enemy3a
class_name EnemyEgo

## Ego Inflado (mito del tamano, idea de Vanessa): se agranda hablando de tamano y se desinfla
## con la verdad. Se HINCHA solo con el tiempo (mas grande = pega mas fuerte, pero mas lento) y
## cada golpe tuyo es "la verdad": lo desinfla. Si lo dejas hincharse del todo, REVIENTA en un
## chasquido de aire caliente que empuja y hace dano cerca (y vuelve pequenito, aturdido).
## Rapidez de hinchazon segun heroe (se nota con quien se compara):
##   Pitocles      se hincha el doble ("¡entre colegas!").
##   Vulvalquiria  se hincha poquito: a ella no le impresiona.
##   Ornitorrinco  se hincha algo menos: no sabe ni con que compararse.

const MAX_INFLATE := 2.4
const GROW_RATE := 0.17          ## por segundo
const HIT_DEFLATE := 0.3         ## lo que baja con cada golpe (la verdad)
const POP_RADIUS := 120.0
const POP_WARN := 0.7            ## aviso antes de reventar (un golpe tuyo lo desinfla y lo cancela)
const HERO_GROW := {"pitocles": 1.8, "vulvalquiria": 0.55, "ornitorrinco": 0.8}
var inflate := 1.0
var _base_scale := Vector2.ONE
var _base_speed := 120.0
var _stage_said := 0
var _grow_mult := 1.0
var _pop_t := -1.0
var _pop_zone: BossZone = null


func _setup() -> void:
	personality = "ego"
	move_speed = 120.0
	lunge_trigger = 100.0
	windup_time = 0.5
	lunge_time = 0.24
	lunge_speed = 480.0
	recover_time = 0.7
	_grow_mult = float(HERO_GROW.get(hero, 1.0))


func _ready() -> void:
	super._ready()
	_base_scale = animated_sprite.scale
	_base_speed = move_speed


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if target != null and global_position.distance_to(target.global_position) < detection_range * 1.4:
		inflate = minf(MAX_INFLATE, inflate + GROW_RATE * _grow_mult * delta)
	_apply_inflate()
	_update_pop_warning(delta)
	super._physics_process(delta)


## Al llegar al maximo no revienta de golpe: tiembla, parpadea y marca su radio durante POP_WARN.
func _update_pop_warning(delta: float) -> void:
	if _pop_t < 0.0:
		if inflate >= MAX_INFLATE and state not in [State.WINDUP, State.LUNGE]:
			_pop_t = POP_WARN
			E3a.icon(self, "alert", POP_WARN)
			_pop_zone = BossZone.circle(global_position, POP_RADIUS, POP_WARN, 0.01, 0.0)
			_pop_zone.follow = self
			_pop_zone.fade = 0.1
			get_parent().add_child(_pop_zone)
		return
	if inflate < MAX_INFLATE:  # la verdad lo desinfla: aviso cancelado
		_cancel_pop_warning()
		return
	_pop_t -= delta
	animated_sprite.modulate = Color(2, 2, 2) if int(_pop_t * 16.0) % 2 == 0 else Color(1.6, 0.4, 0.4)
	animated_sprite.offset.x = RNG.randf_range(-1.5, 1.5)
	if _pop_t <= 0.0:
		_cancel_pop_warning()
		_pop()


func _cancel_pop_warning() -> void:
	_pop_t = -1.0
	animated_sprite.offset.x = 0.0
	animated_sprite.modulate = Color.WHITE
	if is_instance_valid(_pop_zone):
		_pop_zone.dismiss()
	_pop_zone = null


func _apply_inflate() -> void:
	var k := 1.0 + (inflate - 1.0) * 0.65
	animated_sprite.scale = _base_scale * k
	damage = base_damage * inflate
	if state not in [State.WINDUP, State.LUNGE]:
		move_speed = _base_speed * clampf(1.25 - (inflate - 1.0) * 0.3, 0.6, 1.2)
	# fanfarronadas por tramos
	if inflate >= 1.55 and _stage_said < 1:
		_stage_said = 1
		_say("ego_boast1", 2.2)
	elif inflate >= 2.05 and _stage_said < 2:
		_stage_said = 2
		_say("ego_boast2", 2.2)
		E3a.icon(self, "vein", 1.2)


func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	var was := inflate
	var dealt := super.take_damage(amount, source, kb)
	if state != State.DEAD and was > 1.0:
		inflate = maxf(1.0, inflate - HIT_DEFLATE)
		if _stage_said > 0 and inflate < 1.4:
			_stage_said = 0
			_say("ego_truth", 2.0)
	return dealt


## Revienta (no muere): aire caliente que empuja y quema un poco, y vuelve a ser pequenito.
func _pop() -> void:
	E3a.floating(global_position + Vector2(0, -40), Loc.tr_or("E3A_FX_PFFT", "¡PFFFFFT!"), Color("ffb0c8"))
	_say("ego_pop", 2.4)
	E3a.note("e3a_ego")
	var p := _player()
	if p != null and global_position.distance_to(p.global_position) <= POP_RADIUS and p.has_method("receive_hit"):
		p.receive_hit(base_damage * 0.9)
		var v = p.get("velocity")
		if v != null:
			p.velocity = (p.global_position - global_position).normalized() * 420.0
	HitFx.shake(0.3)
	inflate = 1.0
	_stage_said = 0
	state = State.STUNNED
	_state_timer = 1.6
	velocity = Vector2.ZERO
	animated_sprite.modulate = Color(1.2, 0.8, 0.9)
