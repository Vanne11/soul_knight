extends EnemySwarmer
class_name EnemyFuncionario

## MINI-FUNCIONARIO (esbirro del Aduanero Hormonal). Un trabajador con corbata y un sello de goma:
## no pega por contacto. Da vueltas a distancia, AVISA (se queda quieto y brilla 0.7 s con un circulo
## marcado donde vas a estar) y estampa ese sitio. Ayuda al jefe: si lo dejas vivo ~10 s vuelve
## CORRIENDO a entregarle un tramite aprobado (cura 1 % de su vida). Si lo revientas antes, suelta un
## corazon chico a veces.

enum F { WANDER, WINDUP, REST, HOME }

const PAPER := Color(1.0, 0.85, 0.25)
const HOME_AFTER := 10.0
const HEAL_PCT := 0.01

var f_state := F.WANDER
var f_t := 1.5
var _age := 0.0
var _dir := 1.0
var _spot := Vector2.ZERO


func _init() -> void:
	personality = "none"


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.3}]
	super()
	add_to_group("funcionario_aduana")
	_dir = 1.0 if RNG.randf() < 0.5 else -1.0
	f_t = RNG.randf_range(1.0, 2.0)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return
	_age += delta
	f_t -= delta
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	if _age >= HOME_AFTER and f_state != F.HOME:
		f_state = F.HOME
		animated_sprite.modulate = Color.WHITE
		_float(tr("FUNC_HOME"))
	match f_state:
		F.WANDER:
			var radial := clampf((d - 240.0) / 80.0, -1.0, 1.0)
			velocity = (to_t.normalized() * radial + to_t.normalized().orthogonal() * _dir * 0.7).normalized() * move_speed
			if f_t <= 0.0 and d < 480.0:
				f_state = F.WINDUP
				f_t = 0.7
				_spot = target.global_position + (target.velocity * 0.3 if "velocity" in target else Vector2.ZERO)
				var z := BossZone.circle(_spot, 52.0, 0.7, 0.2, damage, PAPER)
				z.style = BossZone.Style.TOXIC
				_spawn_container().add_child(z)
				z.global_position = _spot
		F.WINDUP:
			velocity = Vector2.ZERO
			animated_sprite.modulate = Color(2.2, 1.9, 0.9) if int(f_t * 20.0) % 2 == 0 else Color.WHITE
			if f_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				Sound.play("crack")
				f_state = F.REST
				f_t = 0.8
		F.REST:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			if f_t <= 0.0:
				f_state = F.WANDER
				f_t = RNG.randf_range(2.0, 3.0)
				_dir = -_dir
		F.HOME:
			var b := get_tree().get_first_node_in_group("boss")
			if b == null or not is_instance_valid(b):
				f_state = F.WANDER
			else:
				var to_b: Vector2 = b.global_position - global_position
				velocity = to_b.normalized() * move_speed * 1.9
				if to_b.length() < 40.0:
					_deliver(b)
	_update_animation(to_t)
	move_and_slide()


## Poses propias (tools/gen_aduanero_art.py): orbita (walk), aviso (attack, brilla), estampa (stamp) y entrega corriendo (walk).
func _update_animation(dir: Vector2) -> void:
	var a := &"walk"
	match f_state:
		F.WINDUP:
			a = &"attack"
		F.REST:
			a = &"stamp" if f_t > 0.35 else &"idle"
	if animated_sprite.animation != a and animated_sprite.sprite_frames.has_animation(a):
		animated_sprite.play(a)
	if absf(dir.x) > 1.0:
		animated_sprite.flip_h = dir.x < 0.0


func _deliver(b: Node) -> void:
	if state == State.DEAD:
		return
	if b is EnemyBoss and b.state != EnemyBoss.State.DEAD and not b._channeling:
		b.current_health = minf(b.max_health, b.current_health + b.max_health * HEAL_PCT)
		b._emit_health()
		b._float_text(tr("FUNC_HEAL"), Color("8fe08f"), Vector2(0, -150))
	state = State.DEAD
	queue_free()


func _float(text: String) -> void:
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -40), text, PAPER)
