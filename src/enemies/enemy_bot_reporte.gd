extends EnemySwarmer
class_name EnemyBotReporte

## BOT DE REPORTE (esbirro del Algoritmo Moderador): un bichito de moderacion que ronda a distancia y
## MARCA tu posicion: se queda quieto y brilla 0,8 s con un reticulo en el sitio donde estas (se fija
## los ultimos 0,25 s) y recien entonces cae el reporte. Ayuda al algoritmo: mientras haya bots vivos
## sus REPORTADOS marcan un sitio extra. Reventarlo suelta un corazon chico a veces.

enum B { DRIFT, WINDUP, REST }

const ALERT := Color(1.0, 0.3, 0.3)
const GLASS := Color(0.7, 0.85, 1.0)

var b_state := B.DRIFT
var b_t := 1.5
var _dir := 1.0
var _zone: BossZone = null


func _init() -> void:
	personality = "none"


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.3}]
	super()
	animated_sprite.self_modulate = GLASS
	add_to_group("bot_reporte")
	_dir = 1.0 if RNG.randf() < 0.5 else -1.0
	b_t = RNG.randf_range(1.2, 2.2)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return
	b_t -= delta
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	match b_state:
		B.DRIFT:
			var radial := clampf((d - 260.0) / 80.0, -1.0, 1.0)
			velocity = (to_t.normalized() * radial + to_t.normalized().orthogonal() * _dir * 0.8).normalized() * move_speed
			if b_t <= 0.0 and d < 480.0:
				b_state = B.WINDUP
				b_t = 0.8
				_zone = BossZone.circle(target.global_position, 56.0, 0.8, 0.25, damage, ALERT)
				_zone.style = BossZone.Style.TOXIC
				_spawn_container().add_child(_zone)
		B.WINDUP:
			velocity = Vector2.ZERO
			if b_t > 0.25 and is_instance_valid(_zone):
				_zone.global_position = target.global_position  # el reticulo te sigue; los ultimos 0,25 s se fija
			animated_sprite.modulate = Color(2.2, 1.2, 1.2) if int(b_t * 20.0) % 2 == 0 else Color.WHITE
			if b_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				Sound.play("crack")
				b_state = B.REST
				b_t = 0.9
		B.REST:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			if b_t <= 0.0:
				b_state = B.DRIFT
				b_t = RNG.randf_range(2.4, 3.4)
				_dir = -_dir
	_update_animation(to_t)
	move_and_slide()
