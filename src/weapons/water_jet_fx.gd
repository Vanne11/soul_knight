class_name WaterJetFx
extends Node2D

## Chorro de la Ducha Anal: gotas y rayitas azules a lo largo del cono, dura un instante (0,16 s).
## Se crea en cada tic del arma; es solo dibujo (el dano lo hace SpecialShots._ducha).

var length := 170.0
var spread := 0.28
var _t := 0.0
var _drops: Array = []


func _ready() -> void:
	z_index = 4
	for i in 14:
		_drops.append([RNG.randf_range(0.15, 1.0), RNG.randf_range(-1.0, 1.0), RNG.randf_range(2.0, 4.0)])


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= 0.16:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var f := 1.0 - _t / 0.16
	draw_line(Vector2(6, 0), Vector2(length * 0.55, 0), Color(0.55, 0.85, 1.0, 0.6 * f), 3.0)
	draw_line(Vector2(6, 0), Vector2(length * 0.4, 0), Color(0.9, 1.0, 1.0, 0.8 * f), 1.0)
	for d in _drops:
		var x: float = length * d[0] * (0.5 + _t * 5.0)
		var y: float = d[1] * x * tan(spread) * 0.8
		draw_circle(Vector2(x, y), d[2] * f, Color(0.6, 0.88, 1.0, 0.85 * f))
