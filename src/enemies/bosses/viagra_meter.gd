extends Node2D
class_name ViagraMeter

## Medidor visible del SUBIDON de Don Viagra: barra sobre su cabeza que va de azul a rojo.
## `level` 0..1 lo escribe el jefe. Con el nivel alto la barra tiembla y se tinta de rojo.

var level := 0.0
var _t := 0.0


func _ready() -> void:
	position = Vector2(0, -150)
	z_index = 20


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := 84.0
	var shake := Vector2(sin(_t * 70.0) * 1.6, 0.0) if level > 0.85 else Vector2.ZERO
	var col := Color(0.35, 0.65, 1.0).lerp(Color(1.0, 0.2, 0.25), clampf(level, 0.0, 1.0))
	draw_set_transform(shake, 0.0, Vector2.ONE)
	draw_rect(Rect2(-w * 0.5 - 2, -7, w + 4, 14), Color(0.05, 0.03, 0.08, 0.9))
	draw_rect(Rect2(-w * 0.5, -5, w * clampf(level, 0.0, 1.0), 10), col)
	draw_rect(Rect2(-w * 0.5 - 2, -7, w + 4, 14), Color(0.62, 0.06, 0.1), false, 2.0)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(-w * 0.5, -11), tr("VIAGRA_METER"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.9, 0.95, 1.0))
	if level >= 0.99:
		draw_string(f, Vector2(-w * 0.5, 26), "!!!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.3, 0.3))
