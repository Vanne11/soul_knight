extends StaticBody2D
class_name DestineOrb

## Orbe de color de la pelea contra La Censura que destine: lo revientas DISPARANDOLE o PISANDOLO y
## recolorea las zonas grises que tiene alrededor (DestineFloor.recolor_radius). Si no lo revientas
## a tiempo se apaga solo. Esta en los grupos "enemy" (las balas del jugador lo tratan como un
## enemigo, como los huevos de Ovaria) y "boss_breakable" (el jefe lo limpia al cambiar de fase),
## pero no cuenta para limpiar la sala.

signal popped(orb: DestineOrb)

const RADIUS := 15.0
const TOUCH := 30.0
const RECOLOR_RADIUS := 190.0

var color := Color("ff9630")
var life := 11.0
var floor_ref: DestineFloor = null
var max_health := 1.0
var current_health := 1.0
var enemy_name := "Orbe"

var _t := 0.0
var _dead := false
var _flash := 0.0


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss_breakable")
	collision_layer = 0
	set_collision_layer_value(2, true)
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = RADIUS + 4.0
	cs.shape = sh
	add_child(cs)
	z_index = 2
	ActorFx.add_glow(self, color, 0.55, 0.5)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	var tg := get_tree().get_first_node_in_group("player")
	if tg != null and tg.global_position.distance_to(global_position) < TOUCH:
		_pop()  # pisarlo tambien vale
		return
	if _t >= life:
		_dead = true
		queue_free()
		return
	queue_redraw()


func is_alive() -> bool:
	return not _dead


func take_damage(amount: float, _source: Node = null, _kb: Vector2 = Vector2.ZERO) -> float:
	if _dead:
		return 0.0
	_pop()
	return amount


func die(_killer: Node = null) -> void:
	if not _dead:
		_dead = true
		queue_free()


func _pop() -> void:
	if _dead:
		return
	_dead = true
	current_health = 0.0
	set_deferred("collision_layer", 0)
	var n := 0
	if floor_ref != null and is_instance_valid(floor_ref):
		n = floor_ref.recolor_radius(global_position, RECOLOR_RADIUS)
	Arcoiria.ring(global_position, color, RECOLOR_RADIUS, 0.55)
	Sound.play("puzzle_solve")
	if n > 0:
		(Engine.get_main_loop() as SceneTree).root.get_node("GlobalEvents").show_floating_text.emit(
			global_position + Vector2(0, -30), Loc.tr_or("ARC_RECOLOR", "¡COLOR!"), color)
	popped.emit(self)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.6, 1.6), 0.15)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	var left := maxf(life - _t, 0.0)
	var urgent := left < 2.0
	var wob := Vector2(sin(_t * 50.0) * 2.0, 0.0) if urgent else Vector2.ZERO
	var bob := Vector2(0.0, sin(_t * 3.0) * 3.0)
	var c := wob + bob
	draw_circle(c, RADIUS + 5.0, Color(color, 0.22))
	draw_circle(c, RADIUS, color.darkened(0.25))
	draw_circle(c + Vector2(-2, -2), RADIUS - 3.0, color)
	draw_circle(c + Vector2(-5, -6), 4.0, Color(1, 1, 1, 0.85))
	draw_arc(c, RADIUS + 3.0, 0.0, TAU, 24, Color(0.1, 0.08, 0.14, 0.9), 2.0)
	draw_arc(c, RADIUS + 8.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(left / life, 0.0, 1.0), 28, Color(1, 1, 1, 0.8), 3.0)
