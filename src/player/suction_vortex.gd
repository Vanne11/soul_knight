extends Node2D
class_name SuctionVortex

## Satisfyer: un pulso que vuela corto, se planta y succiona a los enemigos
## cercanos hacia su centro mientras les hace dano a tics (poco) y los aturde
## con cada tic. Es un arma de control: junta grupos y los inmoviliza para
## rematarlos con otra arma (o con el mismo vortice).

var damage: float = 5.0  ## por tic
var speed: float = 380.0
var travel_time: float = 0.3
var duration: float = 1.5
var radius: float = 120.0
var pull: float = 300.0
var tick: float = 0.25
var _t := 0.0
var _tick_t := 0.0
var _anchored := false

func _physics_process(delta: float) -> void:
	_t += delta
	if not _anchored:
		var step := Vector2.RIGHT.rotated(rotation) * speed * delta
		# se planta antes de meterse en una pared (capa 1)
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step * 2.0, 1)
		if _t >= travel_time or get_world_2d().direct_space_state.intersect_ray(q):
			_anchored = true
			_t = 0.0
			get_node("/root/Sound").play("suck")
		else:
			global_position += step
	else:
		_suck(delta)
		if _t >= duration:
			queue_free()
	queue_redraw()

func _suck(delta: float) -> void:
	_tick_t -= delta
	var hit := _tick_t <= 0.0
	if hit:
		_tick_t = tick
	var player := get_tree().get_first_node_in_group("player")
	var ps := get_node("/root/PlayerStats")
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e is CharacterBody2D or float(e.get("current_health")) <= 0.0:
			continue
		if e.has_method("is_suck_immune") and e.is_suck_immune():
			continue
		var to_c: Vector2 = global_position - e.global_position
		var d := to_c.length()
		if d > radius:
			continue
		# a los jefes les cuesta mas dejarse llevar
		var f := 0.3 if e.is_in_group("boss") else 1.0
		if d > 4.0:
			# mas fuerte cuanto mas cerca del centro; move_and_collide respeta paredes
			var strength := pull * f * (0.5 + 0.5 * (1.0 - d / radius))
			e.move_and_collide(to_c / d * minf(strength * delta, d))
		if hit and e.has_method("take_damage"):
			# el empujoncito hacia el centro aturde un instante a cada tic (los jefes no lo notan)
			e.take_damage(damage, player, to_c.normalized() * 50.0 if d > 4.0 else Vector2.ZERO)
			if ps.lifesteal > 0.0:
				ps.heal(damage * ps.lifesteal)

func _draw() -> void:
	if not _anchored:
		draw_circle(Vector2.ZERO, 5.0, Color("ff6ec7"))
		draw_circle(Vector2.ZERO, 2.5, Color.WHITE)
		return
	var a := clampf((duration - _t) / 0.3, 0.0, 1.0) * clampf(_t / 0.1, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.43, 0.78, 0.07 * a))
	# anillos que se cierran hacia el centro = succion
	for i in 4:
		var k := fmod(_t * 1.6 + i / 4.0, 1.0)
		draw_arc(Vector2.ZERO, radius * (1.0 - k), 0.0, TAU, 40, Color(1.0, 0.55, 0.85, a * k * 0.8), 2.0)
	draw_circle(Vector2.ZERO, 8.0, Color(0.24, 0.08, 0.16, a))
	draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 20, Color("ff96d6", a), 2.0)
