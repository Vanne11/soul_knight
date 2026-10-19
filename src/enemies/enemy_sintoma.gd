extends EnemySwarmer
class_name EnemySintoma

## SINTOMA (esbirro de La Glandula Callada): una gotita inquieta que ronda, AVISA (brilla 0.75 s con
## un circulo marcado a su alrededor) y suelta tres gotas en abanico hacia ti. Ayuda a la jefa: cada
## sintoma vivo aprieta mas la presion que te empuja contra los bordes (ver boss_glandula.gd).
## Reventarlo suelta un corazon chico a veces: atender los sintomas a tiempo ayuda.

enum S { DRIFT, WINDUP, REST }

const DROP := Color(1.0, 0.92, 0.35)
const PROJECTILE := preload("res://src/enemies/projectile_enemy.tscn")

var s_state := S.DRIFT
var s_t := 1.5
var _dir := 1.0
var _aim := 0.0


func _init() -> void:
	personality = "none"


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.35}]
	super()
	add_to_group("sintoma_glandula")
	_dir = 1.0 if RNG.randf() < 0.5 else -1.0
	s_t = RNG.randf_range(1.3, 2.3)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return
	s_t -= delta
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	match s_state:
		S.DRIFT:
			var radial := clampf((d - 210.0) / 80.0, -1.0, 1.0)
			velocity = (to_t.normalized() * radial + to_t.normalized().orthogonal() * _dir * 0.8).normalized() * move_speed
			if s_t <= 0.0 and d < 440.0:
				s_state = S.WINDUP
				s_t = 0.75
				var z := BossZone.circle(global_position, 100.0, 0.75, 0.2, damage * 0.8, DROP)
				z.style = BossZone.Style.TOXIC
				z.follow = self
				_spawn_container().add_child(z)
		S.WINDUP:
			velocity = Vector2.ZERO
			if s_t > 0.2:
				_aim = to_t.angle()  # los ultimos 0,2 s queda fija: se puede leer
			animated_sprite.modulate = Color(2.4, 2.2, 1.0) if int(s_t * 20.0) % 2 == 0 else Color.WHITE
			if s_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				_gotas()
				s_state = S.REST
				s_t = 0.9
		S.REST:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			if s_t <= 0.0:
				s_state = S.DRIFT
				s_t = RNG.randf_range(2.2, 3.2)
				_dir = -_dir
	_sintoma_anim(to_t)
	move_and_slide()


## Cuadros propios (tools/gen_glandula_art.py): ronda, avisa hinchandose y brilla, escupe las gotas.
func _sintoma_anim(to_t: Vector2) -> void:
	var anim := &"walk"
	if s_state == S.WINDUP:
		anim = &"attack"
	elif s_state == S.REST and s_t > 0.55:
		anim = &"shoot"
	elif velocity.length() < 10.0:
		anim = &"idle"
	if animated_sprite.animation != anim or not animated_sprite.is_playing():
		animated_sprite.play(anim)
	if absf(to_t.x) > 1.0:
		animated_sprite.flip_h = to_t.x < 0.0


func _gotas() -> void:
	Sound.play("enemy_shoot")
	for i in 3:
		var p := PROJECTILE.instantiate()
		p.damage = damage * 0.8
		p.speed = 270.0
		p.projectile_owner = self
		p.lifetime = 4.0
		p.tint = DROP
		_spawn_container().add_child(p)
		var ang := _aim + (i - 1) * 0.28
		p.global_rotation = ang
		p.global_position = global_position + Vector2.RIGHT.rotated(ang) * 18.0 + Vector2(0, -10)
