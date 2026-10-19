extends Puzzle
class_name PuzzleStatues

## Penelandia: Sokoban corto. Idolos de piedra y pedestales hundidos en el suelo. Nadie
## dice que se empujan: al apoyarte contra uno con la intencion de avanzar, se desliza una
## celda (como cualquier caja). Cuando todos los pedestales tienen idolo, se hunden y el
## acertijo cede. Si te quedas sin solucion (idolo contra una esquina...), las estatuas
## se desmoronan con estrepito y vuelven a su sitio, sin que haga falta ningun boton.
## El mismo BFS que valida el reinicio es el solver del bot. Dificultad: 1 a 3 estatuas y
## mas jugadas desde la solucion.
##
## Modelo: rejilla interior cols x rows (celdas de 48 px) mas un anillo libre alrededor
## (el jugador camina por fuera de la rejilla, asi que toda celda del borde es alcanzable y
## se puede empujar desde fuera). Las celdas se numeran en la rejilla extendida.

const CELL := 48.0
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var cols := 5
var rows := 3
var _pedestals: Array[PuzzlePlate] = []
var _ped_cells: Array[int] = []
var _statues: Array[int] = []      # celda (id extendido) de cada idolo
var _initial: Array[int] = []
var _nodes: Array[AnimatableBody2D] = []
var _moving := false
var _push_t := 0.0
var _push_cand := -1
var _push_dir := Vector2i.ZERO
var _resetting := false


func build() -> void:
	kind = "statues"
	cols = clampi(int(area.x / CELL), 4, 6)
	rows = clampi(int(area.y / CELL), 3, 4)
	var n_stat := 1 if depth <= 1 else (2 if depth <= 4 else 3)
	var want := 2 + mini(depth, 5)
	var tries := 0
	while true:
		tries += 1
		_generate(n_stat, 5 + depth * 2)
		var sol: Variant = _solve(_statues, _id(Vector2i(-1, -1)))
		if (sol != null and sol.size() >= want) or tries > 12:
			break
	_initial = _statues.duplicate()
	for c in _ped_cells:
		var p := PuzzlePlate.new().setup(kingdom, false)
		p.position = _cpos(c)
		p.set_glyph("")  # sin glifo; el aro de la losa marca el pedestal
		add_child(p)
		_pedestals.append(p)
	for c in _statues:
		var body := AnimatableBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(38, 38)
		body.add_child(shape)
		var spr := Sprite2D.new()
		spr.texture = PuzzlePlate.load_tex("statue")
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.position = Vector2(0, -9)
		body.add_child(spr)
		TallProp.attach(body, TallProp.box_of(spr))  # el heroe pasa por detras de la estatua
		body.position = _cpos(c)
		add_child(body)
		_nodes.append(body)
	_refresh_pedestals(false)


# ------------------------------------------------------------------ rejilla extendida
func _w() -> int:
	return cols + 2


func _id(v: Vector2i) -> int:
	return (v.y + 1) * _w() + (v.x + 1)


func _vc(id: int) -> Vector2i:
	return Vector2i(id % _w() - 1, id / _w() - 1)


func _inner(v: Vector2i) -> bool:
	return v.x >= 0 and v.y >= 0 and v.x < cols and v.y < rows


func _ext(v: Vector2i) -> bool:
	return v.x >= -1 and v.y >= -1 and v.x <= cols and v.y <= rows


func _cpos(id: int) -> Vector2:
	var v := _vc(id)
	return Vector2((v.x - (cols - 1) * 0.5) * CELL, (v.y - (rows - 1) * 0.5) * CELL)


func _mask(cells: Array) -> int:
	var m := 0
	for c in cells:
		m |= 1 << int(c)
	return m


## Celdas que el jugador alcanza desde `from` sin cruzar idolos (mask), como mascara de bits
## sobre la rejilla extendida (inundacion con desplazamientos: rapida, la usa el BFS).
func _flood(mask: int, from: int) -> int:
	var w := _w()
	var n := w * (rows + 2)
	var all := (1 << n) - 1
	var col0 := 0
	var col_last := 0
	for y in rows + 2:
		col0 |= 1 << (y * w)
		col_last |= 1 << (y * w + w - 1)
	var free := all & ~mask
	var reach := 1 << from
	while true:
		var nxt := reach | (((reach << 1) & ~col0) | ((reach >> 1) & ~col_last) | (reach << w) | (reach >> w))
		nxt &= free
		if nxt == reach:
			return reach
		reach = nxt
	return reach


func _low_bit(x: int) -> int:
	return int(log(float(x & -x)) / log(2.0) + 0.5)


func _rep(mask: int, from: int) -> int:
	return _low_bit(_flood(mask, from))


func _generate(n_stat: int, steps: int) -> void:
	var inner: Array[int] = []
	for y in rows:
		for x in range(1, cols - 1):  # pedestales fuera de las columnas de los bordes: mas juego
			inner.append(_id(Vector2i(x, y)))
	for i in range(inner.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := inner[i]
		inner[i] = inner[j]
		inner[j] = t
	_ped_cells = []
	for k in n_stat:
		_ped_cells.append(inner[k])
	_statues = _ped_cells.duplicate()
	var player_cell := _id(Vector2i(-1, -1))
	for _s in steps:
		var m := _mask(_statues)
		var reach := _flood(m, player_cell)
		var cands := []
		for si in _statues.size():
			var b := _vc(_statues[si])
			for d in DIRS:
				var a: Vector2i = b - d
				var a2: Vector2i = a - d
				# jugada inversa de un empuje: el idolo pasa de b a a (que ha de ser de la rejilla
				# y estar libre), y el jugador queda en a2 (puede estar fuera)
				if _inner(a) and _ext(a2) and (reach >> _id(a)) & 1 and not (m >> _id(a)) & 1 and not (m >> _id(a2)) & 1:
					cands.append([si, _id(a), _id(a2)])
		if cands.is_empty():
			break
		var pick: Array = cands[rng.randi_range(0, cands.size() - 1)]
		_statues[pick[0]] = pick[1]
		player_cell = pick[2]


## BFS sobre empujes. Devuelve [[celda_idolo, Vector2i dir], ...] hasta cubrir todos los
## pedestales, [] si ya esta resuelto, o null si no tiene solucion.
func _solve(stat: Array, player_cell: int) -> Variant:
	var target := _mask(_ped_cells)
	var m0 := _mask(stat)
	if m0 == target:
		return []
	var start := m0 * 64 + _rep(m0, player_cell)
	var prev := {start: null}
	var queue := [start]
	var head := 0
	while head < queue.size() and prev.size() < 40000:
		var key: int = queue[head]
		head += 1
		var mask: int = key / 64
		var rep: int = key % 64
		var reach := _flood(mask, rep)
		for s in _w() * (rows + 2):
			if not (mask >> s) & 1:
				continue
			for di in 4:
				var d: Vector2i = DIRS[di]
				var a := _vc(s) - d
				var t := _vc(s) + d
				if not _ext(a) or not _inner(t) or not (reach >> _id(a)) & 1:
					continue
				var ti := _id(t)
				if (mask >> ti) & 1:
					continue
				var nm := (mask & ~(1 << s)) | (1 << ti)
				var nk := nm * 64 + _rep(nm, s)
				if prev.has(nk):
					continue
				prev[nk] = [key, s, di]
				if nm == target:
					return _unwind(prev, nk)
				queue.append(nk)
	return null


func _unwind(prev: Dictionary, key: int) -> Array:
	var out: Array = []
	while prev[key] != null:
		var p: Array = prev[key]
		out.push_front([p[1], DIRS[p[2]]])
		key = p[0]
	return out


# ------------------------------------------------------------------ juego
## Celda extendida bajo un punto del mundo (se pega al anillo si estas lejos).
func _cell_of(p: Vector2) -> int:
	var l := p - global_position
	var cx := clampi(roundi(l.x / CELL + (cols - 1) * 0.5), -1, cols)
	var cy := clampi(roundi(l.y / CELL + (rows - 1) * 0.5), -1, rows)
	var id := _id(Vector2i(cx, cy))
	if (_mask(_statues) >> id) & 1:  # dentro de un idolo (no deberia): la celda libre mas cercana
		for d in DIRS:
			var n: Vector2i = Vector2i(cx, cy) + d
			if _ext(n) and not (_mask(_statues) >> _id(n)) & 1:
				return _id(n)
	return id


func _physics_process(delta: float) -> void:
	if done or _moving or _resetting:
		return
	var pl := player()
	if pl == null:
		return
	var iv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector2i.ZERO
	if absf(iv.x) > absf(iv.y) * 1.5 and absf(iv.x) > 0.4:
		dir = Vector2i(int(signf(iv.x)), 0)
	elif absf(iv.y) > absf(iv.x) * 1.5 and absf(iv.y) > 0.4:
		dir = Vector2i(0, int(signf(iv.y)))
	var cand := -1
	if dir != Vector2i.ZERO:
		var dv := Vector2(dir)
		for i in _nodes.size():
			var rel := _nodes[i].global_position - pl.global_position
			var along := rel.dot(dv)
			var perp := absf(rel.x * dv.y - rel.y * dv.x)
			if along > 18.0 and along < 44.0 and perp < 22.0:
				cand = i
				break
	if cand < 0 or cand != _push_cand or dir != _push_dir:
		_push_cand = cand
		_push_dir = dir
		_push_t = 0.0
		return
	_push_t += delta
	if _push_t >= 0.12:
		_push_t = 0.0
		_try_push(cand, dir)


func _try_push(i: int, dir: Vector2i) -> void:
	var t := _vc(_statues[i]) + dir
	if not _inner(t) or _statues.has(_id(t)):
		return
	_moving = true
	_plan.clear()
	_statues[i] = _id(t)
	Sound.play("door", 0.1)
	var tw := _nodes[i].create_tween()
	tw.tween_property(_nodes[i], "position", _cpos(_statues[i]), 0.2)
	await tw.finished
	_moving = false
	_refresh_pedestals(true)
	if _ped_cells.all(func(c): return _statues.has(c)):
		for p in _pedestals:
			p.flash(Color(1.8, 1.8, 1.8), 1.0)
		solve()
		return
	var pl := player()
	var sol: Variant = _solve(_statues, _cell_of(pl.global_position) if pl else _id(Vector2i(-1, -1)))
	if sol == null:
		_crumble()


func _refresh_pedestals(sound: bool) -> void:
	for k in _pedestals.size():
		var on := _statues.has(_ped_cells[k])
		if sound and on and not _pedestals[k].pressed:
			Sound.play("tone_%d" % (k % 4), 0.0)
		_pedestals[k].set_pressed(on)


## Sin solucion: los idolos se desmoronan y vuelven a su sitio.
func _crumble() -> void:
	_resetting = true
	_plan.clear()
	await get_tree().create_timer(0.9).timeout
	if not is_inside_tree():
		return
	Sound.play("crack")
	Sound.play("puzzle_fail")
	for i in _nodes.size():
		_statues[i] = _initial[i]
		var tw := _nodes[i].create_tween()
		tw.tween_property(_nodes[i], "modulate", Color(2.0, 2.0, 2.0, 0.0), 0.25)
		tw.tween_callback(func(): _nodes[i].position = _cpos(_initial[i]))
		tw.tween_property(_nodes[i], "modulate", Color.WHITE, 0.3)
	await get_tree().create_timer(0.6).timeout
	_resetting = false
	_refresh_pedestals(false)
	note_fail(1)


func _bot_plan(from: Vector2) -> Array:
	if _moving or _resetting:
		return [_wp(from)]
	var pl := player()
	if pl == null:
		return []
	var pc := _cell_of(pl.global_position)
	var sol: Variant = _solve(_statues, pc)
	if sol == null or sol.is_empty():
		return []
	var s: int = sol[0][0]
	var d: Vector2i = sol[0][1]
	var a := _id(_vc(s) - d)
	var route: Array = []
	for c in _cell_path(pc, a, _mask(_statues)):
		route.append(_wp(_cpos(c)))
	route.append(_wp(_cpos(s)))  # avanzar contra el idolo
	return route


func _cell_path(from: int, to: int, mask: int) -> Array:
	var prev := {from: -1}
	var queue := [from]
	while not queue.is_empty():
		var c: int = queue.pop_front()
		if c == to:
			break
		for d in DIRS:
			var n: Vector2i = _vc(c) + d
			if not _ext(n):
				continue
			var ni := _id(n)
			if prev.has(ni) or (mask >> ni) & 1:
				continue
			prev[ni] = c
			queue.append(ni)
	var out: Array = []
	var k := to
	while prev.has(k) and k != from:
		out.push_front(k)
		k = prev[k]
	return out
