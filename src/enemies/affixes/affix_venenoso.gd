extends Affix

## Venenoso: va dejando charquitos verdes (los mismos de la Gonorrea: escuecen poco y pueden dar
## Ardor; se secan solos a los 7 s) cada 36 px que recorre, hasta 6 a la vez. Visibles desde que
## caen: se pisan por elegir.

const STEP := 36.0
const MAX_PUDDLES := 6
const PUDDLE := preload("res://src/enemies/its_puddle.gd")

var _last := Vector2.INF
var _puddles: Array = []


func tick(_delta: float) -> void:
	if _last == Vector2.INF:
		_last = host.global_position
		return
	if host.global_position.distance_to(_last) < STEP:
		return
	_last = host.global_position
	_puddles = _puddles.filter(func(q): return is_instance_valid(q))
	if _puddles.size() >= MAX_PUDDLES:
		return
	var q: Node2D = PUDDLE.new()
	q.set("tick_damage", 1.5)
	container().add_child(q)
	q.global_position = host.global_position + Vector2(0, 12)
	_puddles.append(q)
