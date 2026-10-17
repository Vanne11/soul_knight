class_name BeamFx
extends Node2D

## Destello del rayo de la Depiladora Laser (solo presentacion: el dano lo aplica SpecialShots).
## Se dibuja hacia +X y se rota; vive un par de frames.

var length := 300.0
var width := 12.0
var color := Color("ff5a4a")
const LIFE := 0.12
var _t := 0.0


func _ready() -> void:
	z_index = 4


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / LIFE
	var w := width * (0.5 + 0.5 * a)
	draw_rect(Rect2(0, -w * 0.5, length, w), Color(color.r, color.g, color.b, 0.4 * a))
	draw_rect(Rect2(0, -w * 0.28, length, w * 0.56), Color(color.r, color.g, color.b, 0.85 * a))
	draw_rect(Rect2(0, -1.0, length, 2.0), Color(1.0, 0.95, 0.85, a))
	draw_circle(Vector2(length, 0), w * 0.45, Color(1.0, 0.9, 0.7, 0.8 * a))
