extends CPUParticles2D

## Dash effect particles

func _ready() -> void:
	amount = 20
	lifetime = 0.3
	one_shot = true
	explosiveness = 1.0
	spread = PI * 2
	scale = Vector2(0.5, 0.5)
	
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	# scale_curve not available directly on CPUParticles2D in Godot 4
	
	var color_ramp = Gradient.new()
	color_ramp.add_point(0.0, Color(1.0, 0.5, 0.2, 1.0))
	color_ramp.add_point(1.0, Color(1.0, 0.2, 0.0, 0.0))
	
func emit_at(position: Vector2, direction: Vector2) -> void:
	global_position = position
	# direction handled by gravity/direction properties
	emitting = true