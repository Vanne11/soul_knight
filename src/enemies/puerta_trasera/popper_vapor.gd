class_name PopperVapor
extends Node2D

## VAPORES del Frasquito Magico (templo de Anubis): una nube palida que avanza lenta y se ensancha. No hace daño:
## quien la respira se MAREA (StatusEffects "mareado": la pantalla ondula y el control se vuelve torpe un rato).
## Dibujada por codigo (circulos translucidos que giran); sin fisica: se mide por distancia. Se esquiva rodeandola.

const COL := Color(0.78, 0.9, 0.4)

var velocity := Vector2.ZERO
var life := 1.8
var start_r := 20.0
var end_r := 54.0
var dizzy_secs := 4.5
var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	z_index = 3
	_seed = randf() * 6.28
	add_to_group("popper_vapor")


func _radius() -> float:
	return lerpf(start_r, end_r, clampf(_t / life, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	_t += delta
	position += velocity * delta
	velocity = velocity.lerp(Vector2.ZERO, 0.9 * delta)
	if _t >= life:
		queue_free()
		return
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl != null and pl.global_position.distance_to(global_position) < _radius() + 8.0:
		StatusEffects.of(pl).apply("mareado", dizzy_secs)
	queue_redraw()


func _draw() -> void:
	var k := 1.0 - clampf(_t / life, 0.0, 1.0)
	var r := _radius()
	for i in 5:
		var a := _seed + _t * 1.6 + TAU * float(i) / 5.0
		var c := Vector2.from_angle(a) * r * 0.45
		var col := COL
		col.a = 0.34 * minf(1.0, k * 2.2)
		draw_circle(c, r * 0.58, col)
	var core := COL
	core.a = 0.3 * minf(1.0, k * 2.2)
	draw_circle(Vector2.ZERO, r * 0.7, core)
