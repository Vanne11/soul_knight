extends EnemySwarmer
class_name EnemyTimbre

## TIMBRE DE TURNO (esbirro de La Ventanilla Unica). Un timbre de mostrador con patas: flota a
## distancia, AVISA (brilla 0.7 s con un anillo marcado a su alrededor) y hace "DING": el anillo pega
## y salen cuatro balitas en cruz. Ayuda al jefe: mientras haya timbres vivos, la cola de turnos
## avanza mas rapido (ver boss_prostata.gd). Reventarlo suelta un corazon chico a veces.

enum T { DRIFT, WINDUP, REST }

const BELL := Color(1.0, 0.8, 0.3)
const PROJECTILE := preload("res://src/enemies/projectile_enemy.tscn")

var t_state := T.DRIFT
var t_t := 1.5
var _dir := 1.0


func _init() -> void:
	personality = "none"


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.3}]
	super()
	add_to_group("timbre_ventanilla")
	_dir = 1.0 if RNG.randf() < 0.5 else -1.0
	t_t = RNG.randf_range(1.2, 2.2)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return
	t_t -= delta
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	match t_state:
		T.DRIFT:
			var radial := clampf((d - 200.0) / 80.0, -1.0, 1.0)
			velocity = (to_t.normalized() * radial + to_t.normalized().orthogonal() * _dir * 0.8).normalized() * move_speed
			if t_t <= 0.0 and d < 420.0:
				t_state = T.WINDUP
				t_t = 0.7
				var z := BossZone.circle(global_position, 115.0, 0.7, 0.2, damage, BELL)
				z.style = BossZone.Style.TOXIC
				z.follow = self
				_spawn_container().add_child(z)
		T.WINDUP:
			velocity = Vector2.ZERO
			animated_sprite.modulate = Color(2.4, 2.0, 1.0) if int(t_t * 20.0) % 2 == 0 else Color.WHITE
			if t_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				_ding()
				t_state = T.REST
				t_t = 0.9
		T.REST:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			if t_t <= 0.0:
				t_state = T.DRIFT
				t_t = RNG.randf_range(2.2, 3.2)
				_dir = -_dir
	_update_animation(to_t)
	move_and_slide()


## Poses propias (tools/gen_ventanilla_art.py): rondar (walk), aviso con anillo (attack) y DING (ding).
func _update_animation(dir: Vector2) -> void:
	var a := &"attack" if t_state == T.WINDUP else (&"ding" if t_state == T.REST and t_t > 0.55 else &"walk")
	if animated_sprite.animation != a and animated_sprite.sprite_frames.has_animation(a):
		animated_sprite.play(a)
	if absf(dir.x) > 1.0:
		animated_sprite.flip_h = dir.x < 0.0


func _ding() -> void:
	Sound.play("puzzle_fail")
	var base := RNG.randf_range(0.0, TAU)
	for i in 4:
		var p := PROJECTILE.instantiate()
		p.damage = damage * 0.8
		p.speed = 260.0
		p.projectile_owner = self
		p.lifetime = 4.0
		p.tint = BELL
		_spawn_container().add_child(p)
		var ang := base + i * TAU / 4.0
		p.global_rotation = ang
		p.global_position = global_position + Vector2.RIGHT.rotated(ang) * 18.0 + Vector2(0, -10)
