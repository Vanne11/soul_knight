class_name SealCounter
extends Control

## Contador de sellos del HUD: un circulo por sello necesario, relleno al ganarlo.

const R := 7.0
const GOLD := Color("ffd75a")
var _have := 0
var _need := 2


func set_seals(have: int, need: int) -> void:
	_have = have
	_need = need
	custom_minimum_size = Vector2(need * (R * 2 + 4) + 2, R * 2 + 4)
	tooltip_text = tr("SEAL_HUD_TIP") % [have, need]
	queue_redraw()


func _draw() -> void:
	for i in _need:
		var c := Vector2(R + 2 + i * (R * 2 + 4), R + 2)
		draw_circle(c, R, Color(0, 0, 0, 0.45))
		if i < _have:
			draw_circle(c, R - 1.0, GOLD)
			draw_circle(c, R - 4.0, GOLD.lightened(0.45))
		draw_arc(c, R, 0.0, TAU, 20, GOLD if i < _have else Color(0.55, 0.5, 0.4), 2.0)
