class_name ArcSlash
extends Node2D

## Estela del chancletazo (solo presentacion). Abanico de `arc` radianes y radio `reach`,
## rotado hacia donde apuntas; el tercer golpe (heavy) es mas ancho y brillante.

var reach := 66.0
var arc := 2.0
var heavy := false
var flip := false
const LIFE := 0.18
var _t := 0.0


func _ready() -> void:
	z_index = 4


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var a := 1.0 - k
	var col := Color(1.0, 0.82, 0.45) if heavy else Color(1.0, 1.0, 1.0)
	# el barrido avanza de un extremo al otro (se alterna en cada golpe del combo)
	var from := -arc * 0.5
	var to := lerpf(from, arc * 0.5, clampf(k * 2.2, 0.0, 1.0))
	if flip:
		from = arc * 0.5
		to = lerpf(from, -arc * 0.5, clampf(k * 2.2, 0.0, 1.0))
	var steps := 18
	for i in 3:
		var r := reach * (1.0 - 0.12 * i)
		draw_arc(Vector2.ZERO, r, from, to, steps, Color(col.r, col.g, col.b, a * (0.9 - 0.25 * i)), 5.0 - i * 1.5 + (2.0 if heavy else 0.0))
