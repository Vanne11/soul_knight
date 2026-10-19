extends EnemyPtBase
class_name EnemyAceite

## ACEITE TRAICIONERO (PT-21: con condones de latex, nunca aceites; rompen el latex). Resbala por la sala (movimiento
## con inercia, rodea a unos 210 px) dejando CHARCOS de aceite que AVISAN (contorno amarillo parpadeando 0,5 s) y luego
## te rompen el escudo ("condon") mientras estes dentro. Cada ~4 s AVISA inclinandose 0,6 s y vierte un charco GRANDE
## donde estas tu. El agua lo disipa: la Ducha Anal y el Lubricante a base de agua limpian los charcos. No pega nunca
## directamente: su gracia es el suelo.

enum S { SLIDE, POUR }

var st := S.SLIDE
var st_t := 3.0
var _drip_t := 0.8
var _side := 1.0
var _pour_pos := Vector2.ZERO


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.25}]
	move_speed = 150.0
	super()
	add_to_group("aceite_traicionero")
	_side = 1.0 if RNG.randf() < 0.5 else -1.0
	st_t = RNG.randf_range(2.5, 4.0)


func _physics_process(delta: float) -> void:
	if state == State.DEAD or not _has_target():
		return
	st_t -= delta
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	match st:
		S.SLIDE:
			var radial := clampf((d - 210.0) / 90.0, -1.0, 1.0)
			var want := (to_t.normalized() * radial + to_t.normalized().orthogonal() * _side * 0.9).normalized() * move_speed
			velocity = velocity.lerp(want, 1.6 * delta)  # patina: poca friccion, mucha inercia
			_play(&"walk")
			_drip_t -= delta
			if _drip_t <= 0.0 and velocity.length() > 40.0:
				_drip_t = 0.55
				_puddle(global_position + Vector2(0, 6), 30.0)
			if st_t <= 0.0:
				st = S.POUR
				st_t = 0.6
				_pour_pos = target.global_position
				Sound.play("aviso_zona")
		S.POUR:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			animated_sprite.modulate = Color(1.9, 1.6, 0.8) if int(st_t * 20.0) % 2 == 0 else Color.WHITE
			_play(&"attack")
			if st_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				_puddle(_pour_pos, 52.0)
				st = S.SLIDE
				st_t = RNG.randf_range(3.2, 4.6)
				_side = -_side
	_face(to_t.x)
	move_and_slide()


func _puddle(pos: Vector2, r: float) -> void:
	var h := PtHazard.spawn(_spawn_container(), pos, PtHazard.Kind.ACEITE, damage * 0.4)
	h.radius = r
