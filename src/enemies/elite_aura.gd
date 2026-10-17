extends Node2D
class_name EliteAura

## Aura roja bajo los pies de los enemigos reforzados (elites y guardianes): un anillo que
## late, dibujado en codigo (sin arte). Se cuelga como hijo del enemigo desde Room.spawn_enemies.

const RADIUS := Vector2(30.0, 13.0)

var _t := 0.0


func _ready() -> void:
	z_index = -1
	position = Vector2(0, 14)
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta * 3.0
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t)
	var k := 1.0 + 0.12 * pulse
	var pts := PackedVector2Array()
	for i in 25:
		var a := TAU * float(i) / 24.0
		pts.append(Vector2(cos(a) * RADIUS.x * k, sin(a) * RADIUS.y * k))
	draw_colored_polygon(pts, Color(1.0, 0.15, 0.2, 0.18 + 0.12 * pulse))
	draw_polyline(pts, Color(1.0, 0.3, 0.3, 0.7 + 0.3 * pulse), 2.0)
