extends EnemySwarmer
class_name EnemySateliteCobre

## SATELITE DE COBRE (esbirro del DIU Cosmico). Orbita al jefe como una luna. Cada pocos segundos
## AVISA (se frena y brilla 0.6 s con una linea hacia ti), se suelta de la orbita en una picada
## recta y vuelve a su sitio. No pega por contacto mientras orbita. Ayuda al jefe: mientras hay
## satelites vivos su gravedad tira mas fuerte. Matarlo suelta a veces un corazon chico.

enum S { ORBIT, AIM, DIVE, RETURN }

const COPPER := Color(1.0, 0.6, 0.3)

var s_state := S.ORBIT
var s_t := 0.0
var s_cd := 2.0
var s_ang := 0.0
var s_r := 110.0
var s_w := 1.4
var _dir := Vector2.RIGHT
var _line: BossZone = null


func _init() -> void:
	personality = "none"


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.3}]
	super()
	animated_sprite.self_modulate = COPPER
	add_to_group("satelite_cobre")
	s_ang = RNG.randf_range(0.0, TAU)
	s_r = RNG.randf_range(95.0, 135.0)
	s_w = RNG.randf_range(1.1, 1.7) * (1.0 if RNG.randf() < 0.5 else -1.0)
	s_cd = RNG.randf_range(1.8, 3.8)  # que no piquen todos a la vez


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return
	s_t -= delta
	s_cd = maxf(0.0, s_cd - delta)
	var b := get_tree().get_first_node_in_group("boss")
	var center := global_position
	if b != null and is_instance_valid(b):
		center = b.global_position + Vector2(0, -40)
	var to_t: Vector2 = target.global_position - global_position
	match s_state:
		S.ORBIT:
			s_ang += s_w * delta
			var slot := center + Vector2.RIGHT.rotated(s_ang) * s_r
			velocity = ((slot - global_position) * 7.0).limit_length(move_speed * 2.2)
			if s_cd <= 0.0 and to_t.length() < 460.0:
				_start_aim(to_t)
		S.AIM:
			velocity = Vector2.ZERO
			if s_t > 0.15:
				_dir = to_t.normalized()
				_place_line()
			animated_sprite.modulate = Color(2.2, 1.6, 1.0) if int(s_t * 20.0) % 2 == 0 else Color.WHITE
			if s_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				if is_instance_valid(_line):
					_line.dismiss()
				s_state = S.DIVE
				s_t = 0.7
				_hit_done = false
				Sound.play("dash")
		S.DIVE:
			velocity = _dir * 400.0
			_strike()
			if s_t <= 0.0 or get_slide_collision_count() > 0:
				s_state = S.RETURN
				s_t = 1.6
		S.RETURN:
			s_ang = (global_position - center).angle()
			var slot2 := center + Vector2.RIGHT.rotated(s_ang) * s_r
			velocity = (center - global_position).normalized() * move_speed * 1.6 if global_position.distance_to(center) > s_r * 1.4 else (slot2 - global_position) * 4.0
			if s_t <= 0.0 or global_position.distance_to(center) < s_r * 1.5:
				s_state = S.ORBIT
				s_cd = RNG.randf_range(3.2, 4.8)
	_update_animation(to_t)
	move_and_slide()


func _start_aim(to_t: Vector2) -> void:
	s_state = S.AIM
	s_t = 0.6
	_dir = to_t.normalized()
	_line = BossZone.rect(global_position, Vector2(300, 8), 0.0, 0.6, 0.05, 0.0, COPPER)
	_line.style = BossZone.Style.WAX  # linea fina de punteria (cobre/naranja, sin blanco)
	_spawn_container().add_child(_line)
	_place_line()


func _place_line() -> void:
	if is_instance_valid(_line):
		_line.global_position = global_position + _dir * 150.0
		_line.rotation = _dir.angle()


func die(killer: Node = null) -> void:
	if state != State.DEAD and is_instance_valid(_line):
		_line.dismiss()
	super(killer)
