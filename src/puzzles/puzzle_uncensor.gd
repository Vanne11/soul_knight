extends Puzzle
class_name PuzzleUncensor

## Palacio de la Censura: descensurar. Baldosas cubiertas por un mosaico gris; al pisarlas
## el color vuelve. Nadie dice la regla: el camino tiene que ser UNA sola linea que pase por
## todas, sin repetir ninguna y siempre a la baldosa de al lado. Pisar una ya descensurada, o
## saltar a una que no esta pegada, vuelve a censurarlo todo (un fogonazo rojo). Siempre hay
## camino: se elige la forma (con huecos) comprobando que existe. Dificultad: tamano y huecos.

const HUES := [0.0, 0.08, 0.15, 0.33, 0.5, 0.58, 0.72, 0.85]

var _cells: Array[Vector2i] = []        # baldosas existentes
var _plates := {}                        # Vector2i -> PuzzlePlate
var _visited := {}
var _last := Vector2i(-9, -9)
var _locked := false


func build() -> void:
	kind = "uncensor"
	g_space = clampf((area.y - 36.0) * 0.5, 54.0, 70.0)
	g_cols = clampi(3 + depth / 4, 3, 4)
	g_rows = 3
	var tries := 0
	while true:
		tries += 1
		_cells.clear()
		var holes := clampi(depth / 2, 0, 3) if g_cols * g_rows > 9 else clampi((depth - 1) / 3, 0, 1)
		var all: Array[Vector2i] = []
		for y in g_rows:
			for x in g_cols:
				all.append(Vector2i(x, y))
		for i in range(all.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := all[i]
			all[i] = all[j]
			all[j] = t
		var removed := all.slice(0, holes)
		for c in all:
			if not removed.has(c):
				_cells.append(c)
		_cells.sort()
		if _hamilton_from_any() != null or tries > 60:
			break
	var k := 0
	for c in _cells:
		var p := PuzzlePlate.new().setup(kingdom, true, 11.0)
		p.position = cell_pos(c)
		p.cell = c
		p.set_overlay("censor_mosaic")
		p.base().modulate = Color(0.55, 0.55, 0.6)
		p.stepped.connect(_on_step)
		add_child(p)
		_plates[c] = p
		k += 1


## Camino hamiltoniano (DFS) que empieza en `start`, o null.
func _hamilton(start: Vector2i, remaining: Dictionary) -> Variant:
	var path: Array[Vector2i] = [start]
	var left := remaining.duplicate()
	left.erase(start)
	return path if _dfs(path, left) else null


func _dfs(path: Array[Vector2i], left: Dictionary) -> bool:
	if left.is_empty():
		return true
	var cur: Vector2i = path[path.size() - 1]
	if not _can_finish(cur, left):
		return false
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var n: Vector2i = cur + d
		if left.has(n):
			left.erase(n)
			path.append(n)
			if _dfs(path, left):
				return true
			path.pop_back()
			left[n] = true
	return false


## Poda: lo que queda ha de ser un solo bloque unido a la baldosa actual y con a lo sumo un
## callejon sin salida (el final del camino); si no, no hay camino hamiltoniano.
func _can_finish(cur: Vector2i, left: Dictionary) -> bool:
	var seen := {cur: true}
	var queue := [cur]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if left.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	if seen.size() != left.size() + 1:
		return false
	var dead_ends := 0
	for c in left:
		var deg := 0
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if left.has(n) or n == cur:
				deg += 1
		if deg <= 1:
			dead_ends += 1
	return dead_ends <= 1


func _hamilton_from_any(prefer := Vector2.ZERO) -> Variant:
	var rem := {}
	for c in _cells:
		if not _visited.has(c):
			rem[c] = true
	var starts := _cells.filter(func(c): return rem.has(c))
	starts.sort_custom(func(a, b): return cell_pos(a).distance_to(prefer) < cell_pos(b).distance_to(prefer))
	for s in starts:
		var p = _hamilton(s, rem)
		if p != null:
			return p
	return null


func _on_step(plate: PuzzlePlate) -> void:
	if done or _locked:
		return
	_plan.clear()
	var c := plate.cell
	var adjacent := _last.x < -5 or absi(c.x - _last.x) + absi(c.y - _last.y) == 1
	if _visited.has(c) or not adjacent:
		_fail()
		return
	_visited[c] = true
	_last = c
	_reveal(plate, _visited.size() - 1)
	Sound.play("tone_%d" % (_visited.size() % 4), 0.0)
	if _visited.size() == _cells.size():
		for p in _plates.values():
			p.flash(Color(1.8, 1.8, 1.8), 1.0)
		solve()


func _reveal(plate: PuzzlePlate, n: int) -> void:
	# la placa del Palacio es casi negra: se sobreexpone para que el color se note al volver
	var col := Color.from_hsv(HUES[n % HUES.size()], 0.5, 1.0) * 2.6
	col.a = 1.0
	plate.base().modulate = col
	var ov := plate.overlay()
	if ov:
		ov.create_tween().tween_property(ov, "modulate:a", 0.0, 0.25)


func _fail() -> void:
	_locked = true
	Sound.play("puzzle_fail")
	for p in _plates.values():
		p.create_tween().tween_property(p, "modulate", Color.WHITE, 0.5).from(Color(1.0, 0.3, 0.3))
		p.base().modulate = Color(0.55, 0.55, 0.6)
		if p.overlay():
			p.overlay().modulate.a = 1.0
	_visited.clear()
	_last = Vector2i(-9, -9)
	await get_tree().create_timer(0.5).timeout
	_locked = false
	note_fail()


func _bot_plan(from: Vector2) -> Array:
	if _locked:
		return [_wp(from)]
	var path = _hamilton_from_any(from) if _visited.is_empty() else _continue_path()
	if path == null or path.is_empty():
		return []
	var route: Array = []
	if _visited.is_empty():
		route = lane_route(from, path[0])
	for i in range(1 if _visited.is_empty() else 0, path.size()):
		route.append(_wp(cell_pos(path[i])))
	return route


## Resto del camino desde la baldosa donde estas (el recorrido ya hecho no se repite).
func _continue_path() -> Variant:
	var rem := {}
	for c in _cells:
		if not _visited.has(c):
			rem[c] = true
	var p: Array[Vector2i] = [_last]
	if rem.is_empty():
		return []
	if _dfs(p, rem):
		return p.slice(1)
	return null
