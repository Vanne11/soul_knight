extends EnemyPtBase
class_name EnemyPujon

## PUJON (PT-06/07: "no pujes de mas", "no te quedes horas con el celular"). Lento, se acerca y AVISA inflandose
## durante 1,1 s (se pone rojo, tiembla y marca en el suelo el radio del estallido). Al reventar empuja y pega a todo
## lo que este dentro del circulo; fuera de el no pasa nada: moverte es la respuesta. Despues queda desinflado y
## "aliviado" 1,6 s (ahi es vulnerable de verdad: recibe un 50 % mas). Quedarte parado cerca mientras se infla
## tambien te empuja suave: nadie ha ganado nada pujando.

enum S { CHASE, INFLATE, BURST, DEFLATED }

const BURST_R := 120.0
const RED := Color(1.0, 0.35, 0.3)

var st := S.CHASE
var st_t := 0.0
var _zone: BossZone = null
var _base_scale := Vector2.ONE


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.3}]
	move_speed = 95.0
	super()
	add_to_group("pujon")
	_base_scale = animated_sprite.scale
	st_t = RNG.randf_range(0.8, 1.6)


func _physics_process(delta: float) -> void:
	if state == State.DEAD or not _has_target():
		return
	st_t -= delta
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	match st:
		S.CHASE:
			velocity = to_t.normalized() * move_speed if d > 150.0 else velocity.lerp(Vector2.ZERO, 6.0 * delta)
			_play(&"walk")
			if st_t <= 0.0 and d < 230.0:
				st = S.INFLATE
				st_t = 1.1
				_zone = BossZone.circle(global_position, BURST_R, 1.1, 0.12, damage * 1.1, RED)
				_zone.style = BossZone.Style.TOXIC
				_zone.follow = self
				_zone.margin = 4.0
				_spawn_container().add_child(_zone)
				Sound.play("aviso_zona")
		S.INFLATE:
			velocity = Vector2.ZERO
			var k := 1.0 - clampf(st_t / 1.1, 0.0, 1.0)
			animated_sprite.scale = _base_scale * (1.0 + 0.7 * k)
			animated_sprite.modulate = Color(1.0 + 0.9 * k, 1.0 - 0.3 * k, 1.0 - 0.3 * k) if int(st_t * 24.0) % 2 == 0 else Color.WHITE
			animated_sprite.offset.x = sin(st_t * 70.0) * 1.5 * k  # temblor
			_play(&"attack")
			if d < BURST_R:
				shove_player(-to_t, 70.0, 0.05)  # presion: te va sacando de su area
			if st_t <= 0.0:
				_burst()
		S.BURST:
			velocity = Vector2.ZERO
			_play(&"strike")
			if st_t <= 0.0:
				st = S.DEFLATED
				st_t = 1.6
				say("PT_PUJON_RELIEF", Color("9be37a"))
		S.DEFLATED:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			_play(&"idle")
			animated_sprite.scale = animated_sprite.scale.lerp(_base_scale, 6.0 * delta)
			if st_t <= 0.0:
				st = S.CHASE
				st_t = RNG.randf_range(1.6, 2.6)
	_face(to_t.x)
	move_and_slide()


func _burst() -> void:
	animated_sprite.modulate = Color.WHITE
	animated_sprite.offset.x = 0.0
	animated_sprite.scale = _base_scale * 0.75
	st = S.BURST
	st_t = 0.45
	Sound.play("crack")
	HitFx.shake(0.4)
	var to_t: Vector2 = target.global_position - global_position
	if to_t.length() < BURST_R + 10.0:
		shove_player(to_t, 560.0, 0.22)
	var ring := BossZone.circle(global_position, BURST_R, 0.0, 0.15, 0.0, RED)  # el estallido que se ve (el dano ya lo da la zona)
	ring.style = BossZone.Style.TOXIC
	_spawn_container().add_child(ring)


func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if st == S.DEFLATED:
		amount *= 1.5
	return super.take_damage(amount, source, kb)


func die(killer: Node = null) -> void:
	if is_instance_valid(_zone):
		_zone.dismiss()
	super.die(killer)
