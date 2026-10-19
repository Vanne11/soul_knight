extends EnemySwarmer
class_name EnemyPastilla

## PASTILLITA AZUL (esbirro de Don Viagra). Va rodando despacio, AVISA (se clava al piso y brilla
## 0.6 s con una franja de peligro) y sale rodando en linea recta: REBOTA en los muros hasta 2 veces.
## No pega si no la tocas rodando. Ayuda al jefe: mientras hay pastillas vivas, su subidon sube
## mas rapido; si la revientas, se lo bajas un poco. Suelta un corazon chico a veces.

enum P { DRIFT, WINDUP, ROLL, REST }

const BLUE := Color(0.35, 0.65, 1.0)
const ROLL_SPEED := 400.0
const MAX_BOUNCES := 2

var p_state := P.DRIFT
var p_t := 1.6
var p_dir := Vector2.RIGHT
var p_bounces := 0
var _lane: BossZone = null


func _init() -> void:
	personality = "none"


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.25}]
	super()
	animated_sprite.self_modulate = BLUE
	add_to_group("pastilla_viagra")
	p_t = RNG.randf_range(1.2, 2.2)  # que no rueden todas a la vez


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return
	p_t -= delta
	var to_t: Vector2 = target.global_position - global_position
	match p_state:
		P.DRIFT:
			velocity = (to_t.normalized() + to_t.normalized().orthogonal() * sin(_wiggle) * 0.4).normalized() * move_speed
			_wiggle += delta * 4.0
			if p_t <= 0.0 and to_t.length() < 420.0:
				_windup(to_t)
		P.WINDUP:
			velocity = Vector2.ZERO
			animated_sprite.modulate = Color(1.8, 2.0, 2.4) if int(p_t * 20.0) % 2 == 0 else Color.WHITE
			if p_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				p_state = P.ROLL
				p_t = 1.0
				p_bounces = 0
				_hit_done = false
				Sound.play("dash")
		P.ROLL:
			velocity = p_dir * ROLL_SPEED
			animated_sprite.rotation += delta * 14.0
			if not _hit_done and to_t.length() < 30.0 and target.has_method("receive_hit"):
				_hit_done = true
				target.receive_hit(damage)
			if p_t <= 0.0 or p_bounces > MAX_BOUNCES:
				_end_roll()
		P.REST:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			if p_t <= 0.0:
				p_state = P.DRIFT
				p_t = RNG.randf_range(2.4, 3.6)
	_update_animation(to_t)
	move_and_slide()
	if p_state == P.ROLL and get_slide_collision_count() > 0:
		p_dir = p_dir.bounce(get_slide_collision(0).get_normal()).normalized()
		p_bounces += 1
		Sound.play("crack")


func _windup(to_t: Vector2) -> void:
	p_state = P.WINDUP
	p_t = 0.6
	p_dir = to_t.normalized()
	_lane = BossZone.rect(global_position + p_dir * 110.0, Vector2(220, 40), p_dir.angle(), 0.6, 0.05, 0.0, BLUE)
	_lane.style = BossZone.Style.TOXIC
	_spawn_container().add_child(_lane)
	_lane.global_position = global_position + p_dir * 110.0


func _end_roll() -> void:
	p_state = P.REST
	p_t = 0.9
	animated_sprite.rotation = 0.0


func _update_animation(dir: Vector2) -> void:
	if p_state == P.ROLL:
		return
	super(dir)


func die(killer: Node = null) -> void:
	if state != State.DEAD:
		var b := get_tree().get_first_node_in_group("boss")
		if b != null and b.has_method("pill_killed"):
			b.pill_killed()
	super(killer)
