class_name AffixMarker
extends Node2D

## Aro de aviso en el suelo (destino del Saltarin): se cierra hasta desaparecer.

var color := Color("4de8e0")
var life := 1.0
var _t := 0.0


func _ready() -> void:
	z_index = -1


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / life, 0.0, 1.0)
	var r := lerpf(34.0, 14.0, k)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, Color(color.r, color.g, color.b, 0.9), 2.0)
	draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.12 + 0.18 * k))
