class_name EduBadge
extends Node2D

## Iconito discreto "aqui hay un dato": una chapa dorada con una "i" que flota despacio sobre
## los objetos educativos (doctora, poster, placa de Mito o Verdad). No bloquea ni interrumpe.

const R := 7.0
var _t := 0.0


func _ready() -> void:
	z_index = 20
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta * 2.0
	queue_redraw()


func _draw() -> void:
	var bob := roundf(sin(_t) * 2.0)
	var c := Vector2(0, bob)
	draw_circle(c + Vector2(1, 1), R + 1.0, Color(0, 0, 0, 0.35))
	draw_circle(c, R + 1.0, Color("5a3d12"))
	draw_circle(c, R, Color("ffd75a"))
	var f := ThemeDB.fallback_font
	draw_string(f, c + Vector2(-3, 5), "i", HORIZONTAL_ALIGNMENT_CENTER, 6, 14, Color("4a2f08"))
