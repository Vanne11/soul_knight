class_name ArcoiriaRing
extends Node2D

## Anillo de color que se expande y se desvanece (espinas, etiquetas rotas, fuego fatuo...). Es solo
## efecto: el dano lo hace quien lo pide (Arcoiria.burst). Se borra solo.

var color := Color.WHITE
var radius := 80.0
var secs := 0.45
var _t := 0.0


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	_t += delta
	if _t >= secs:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / secs, 0.0, 1.0)
	var r := radius * (0.25 + 0.75 * k)
	var a := 1.0 - k
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(color, 0.85 * a), 4.0)
	draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 28, Color(color.lightened(0.5), 0.5 * a), 2.0)
	draw_circle(Vector2.ZERO, r * 0.9, Color(color, 0.12 * a))
