extends Puzzle
class_name PuzzleMirrors

## Luz y espejos (acertijo creativo, cualquier reino). Una antorcha de pared lanza un rayo
## de luz por la sala; hay espejos en pie que se giran con E ("/" o "\"), y un cristal
## apagado en otro punto. Nadie lo explica: la luz, los espejos y el cristal se explican
## solos. Cuando el rayo da en el cristal, se enciende y el acertijo cede. Siempre tiene
## solucion: se coloca el rayo con espejos y luego se desordenan. Dificultad: 2 a 3 espejos
## y mas cuadricula.

const CELL := 48.0
const REFLECT := {  # direccion de entrada -> salida, para '/' (0) y '\' (1)
	0: {Vector2i(1, 0): Vector2i(0, -1), Vector2i(0, -1): Vector2i(1, 0), Vector2i(-1, 0): Vector2i(0, 1), Vector2i(0, 1): Vector2i(-1, 0)},
	1: {Vector2i(1, 0): Vector2i(0, 1), Vector2i(0, 1): Vector2i(1, 0), Vector2i(-1, 0): Vector2i(0, -1), Vector2i(0, -1): Vector2i(-1, 0)},
}
const MirrorPost := preload("res://src/puzzles/mirror_post.gd")

var cols := 5
var rows := 3
var _lamp_row := 0
var _sensor := Vector2i.ZERO
var _orient := {}   # Vector2i -> 0 | 1 (estado actual)
var _sol := {}      # Vector2i -> 0 | 1 (solucion)
var _posts := {}    # Vector2i -> MirrorPost
var _beam: Line2D
var _beam_glow: Line2D
var _sensor_spr: Sprite2D
var _turns := 0


func build() -> void:
	kind = "mirrors"
	cols = clampi(int(area.x / CELL), 4, 6)
	rows = clampi(int(area.y / CELL), 3, 4)
	var n_mirrors := 2 if depth < 4 else 3
	var tries := 0
	while true:
		tries += 1
		_lamp_row = rng.randi_range(0, rows - 1)
		_sol.clear()
		var cells: Array[Vector2i] = []
		for y in rows:
			for x in cols:
				cells.append(Vector2i(x, y))
		for i in range(cells.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := cells[i]
			cells[i] = cells[j]
			cells[j] = t
		for k in n_mirrors:
			_sol[cells[k]] = rng.randi_range(0, 1)
		var res := _trace(_sol, null)
		var last: Vector2i = res.last
		if res.hits < 2 or _sol.has(last) or last == Vector2i(0, _lamp_row) or res.cells.count(last) != 1:
			if tries < 400:
				continue
		_sensor = last
		# estados sin luz en el cristal (todos los de mas de la solucion): se elige uno al azar
		var keys := _sol.keys()
		var unlit: Array = []
		for mask in range(1, 1 << keys.size()):
			var st := _sol.duplicate()
			for i in keys.size():
				if (mask >> i) & 1:
					st[keys[i]] = 1 - st[keys[i]]
			if not _trace(st, _sensor).lit:
				unlit.append(st)
		if unlit.is_empty() and tries < 400:
			continue
		_orient = unlit[rng.randi_range(0, unlit.size() - 1)] if not unlit.is_empty() else _sol.duplicate()
		break
	_build_visuals()
	_update_beam()


func _cpos(c: Vector2i) -> Vector2:
	return Vector2((c.x - (cols - 1) * 0.5) * CELL, (c.y - (rows - 1) * 0.5) * CELL)


## Recorre el rayo. Devuelve {points, hits, last, lit}. `sensor` null = sin cristal.
func _trace(orient: Dictionary, sensor) -> Dictionary:
	var pts: Array[Vector2] = [_cpos(Vector2i(0, _lamp_row)) + Vector2(-CELL * 0.5 - 6.0, 0)]
	var seen_cells: Array[Vector2i] = []
	var cur := Vector2i(0, _lamp_row)
	var dir := Vector2i(1, 0)
	var hits := 0
	var lit := false
	for _i in 60:
		seen_cells.append(cur)
		if sensor != null and cur == sensor:
			pts.append(_cpos(cur))
			lit = true
			break
		if orient.has(cur):
			pts.append(_cpos(cur))
			dir = REFLECT[orient[cur]][dir]
			hits += 1
		var nxt := cur + dir
		if nxt.x < 0 or nxt.y < 0 or nxt.x >= cols or nxt.y >= rows:
			pts.append(_cpos(cur) + Vector2(dir) * CELL * 0.5)
			break
		cur = nxt
	return {"points": pts, "hits": hits, "last": cur, "lit": lit, "cells": seen_cells}


func _build_visuals() -> void:
	var lamp := Sprite2D.new()
	lamp.texture = PuzzlePlate.load_tex("lamp")
	lamp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lamp.position = _cpos(Vector2i(0, _lamp_row)) + Vector2(-CELL * 0.5 - 14.0, -6.0)
	add_child(lamp)
	ActorFx.add_glow(lamp, Color(1.0, 0.75, 0.3), 0.7, 0.9).position = Vector2(0, -14)
	_beam_glow = _make_beam(9.0, Color(1.0, 0.8, 0.3, 0.25))
	_beam = _make_beam(3.0, Color(1.0, 0.95, 0.6, 0.95))
	_sensor_spr = Sprite2D.new()
	_sensor_spr.texture = PuzzlePlate.load_tex("sensor_off")
	_sensor_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sensor_spr.position = _cpos(_sensor) + Vector2(0, -6)
	add_child(_sensor_spr)
	for c in _sol:
		var post = Area2D.new()
		post.set_script(MirrorPost)
		post.position = _cpos(c)
		post.cell = c
		post.prompt_text = tr("PZ_ROTATE")
		post.set_orientation(_orient[c])
		post.used.connect(_on_turn.bind(c))
		add_child(post)
		_posts[c] = post


func _make_beam(width: float, color: Color) -> Line2D:
	var l := Line2D.new()
	l.width = width
	l.default_color = color
	l.z_index = 1
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	l.material = m
	add_child(l)
	return l


func _update_beam() -> void:
	var r := _trace(_orient, _sensor)
	_beam.points = PackedVector2Array(r.points)
	_beam_glow.points = PackedVector2Array(r.points)
	if r.lit and not done:
		_sensor_spr.texture = PuzzlePlate.load_tex("sensor_on")
		ActorFx.add_glow(_sensor_spr, Color(1.0, 0.95, 0.5), 0.9, 1.0).position = Vector2(0, -8)
		solve()


func _on_turn(_player: Node, c: Vector2i) -> void:
	if done:
		return
	_orient[c] = 1 - _orient[c]
	_posts[c].set_orientation(_orient[c])
	_plan.clear()
	Sound.play("crack", 0.1)
	_turns += 1
	_update_beam()
	if not done and _turns % 8 == 0:
		var lv := mini(_turns / 8, 3)
		if lv > _hint_lvl:  # la misma pista no se repite si ya la dio el reloj (Puzzle._tick_hint)
			_give_hint(lv)


func _bot_plan(from: Vector2) -> Array:
	var todo: Array = []
	for c in _sol:
		if _orient[c] != _sol[c]:
			todo.append(c)
	if todo.is_empty():
		return []
	todo.sort_custom(func(a, b): return _cpos(a).distance_to(from) < _cpos(b).distance_to(from))
	return [_wp(_cpos(todo[0]), true)]
