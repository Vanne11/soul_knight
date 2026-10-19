extends EnemyPtBase
class_name EnemyCartel

## CARTEL FALSO "¡DEBE DOLER!" (PT-32: mito, NO tiene que doler; si duele, se para). Un letrero que se acerca a paso
## de oficinista y se anuncia con su mentira. Antes de cada "embestida" AVISA 0,6 s inclinandose; la embestida
## VERDADERA marca un carril naranja en el suelo, el FARSANTE no (tose, dice "¡Mentira!" y queda expuesto 1,3 s
## recibiendo un 60 % mas). Al romperlo el cartel se da vuelta y dice la verdad ("Si duele, se para") y suelta un corazon.

enum S { WALK, TELL, CHARGE, EXPOSED }

const LANE_W := 46.0

var st := S.WALK
var st_t := 1.4
var _real := true
var _dir := Vector2.RIGHT
var _lane: BossZone = null
var _lie_t := 2.0
var _hit_done_c := false


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.2}]
	move_speed = 105.0
	super()
	add_to_group("cartel_falso")
	st_t = RNG.randf_range(1.2, 2.0)


func _physics_process(delta: float) -> void:
	if state == State.DEAD or not _has_target():
		return
	st_t -= delta
	_lie_t -= delta
	var to_t: Vector2 = target.global_position - global_position
	match st:
		S.WALK:
			velocity = to_t.normalized() * move_speed if to_t.length() > 130.0 else Vector2.ZERO
			_play(&"walk")
			if _lie_t <= 0.0:
				_lie_t = RNG.randf_range(3.5, 5.0)
				say("PT_CARTEL_LIE", Color("ff6a5a"))
			if st_t <= 0.0 and to_t.length() < 400.0:
				st = S.TELL
				st_t = 0.6
				_real = RNG.randf() < 0.55
				_dir = to_t.normalized()
				if _real:
					_lane = BossZone.rect(global_position + _dir * 120.0, Vector2(300.0, LANE_W), _dir.angle(), 0.6, 0.55, 0.0, Color(1.0, 0.5, 0.15))
					_lane.style = BossZone.Style.TOXIC
					_spawn_container().add_child(_lane)
					Sound.play("aviso_embestida")
		S.TELL:
			velocity = Vector2.ZERO
			_play(&"attack")
			if _real:
				animated_sprite.modulate = Color(2.2, 1.4, 0.8) if int(st_t * 20.0) % 2 == 0 else Color.WHITE
			if st_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				if _real:
					st = S.CHARGE
					st_t = 0.5
					_hit_done = false
				else:
					st = S.EXPOSED
					st_t = 1.3
					say("PT_CARTEL_FAKE", Color("ffe08a"))
		S.CHARGE:
			velocity = _dir * 470.0
			_play(&"strike")
			if not _hit_done and contact(damage):
				_hit_done = true
			if st_t <= 0.0:
				st = S.EXPOSED
				st_t = 0.7
		S.EXPOSED:
			velocity = velocity.lerp(Vector2.ZERO, 9.0 * delta)
			_play(&"idle")
			animated_sprite.modulate = Color(1.0, 0.95, 0.7)
			if st_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				st = S.WALK
				st_t = RNG.randf_range(1.5, 2.4)
	_face(velocity.x if st == S.CHARGE else to_t.x)
	move_and_slide()


func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if st == S.EXPOSED:
		amount *= 1.6
	return super.take_damage(amount, source, kb)


func die(killer: Node = null) -> void:
	if is_instance_valid(_lane):
		_lane.dismiss()
	say("PT_CARTEL_TRUTH", Color("9be37a"))
	if RNG.randf() < 0.5:
		drop_table = [{"item_id": "health_small", "chance": 1.0}]
	super.die(killer)
