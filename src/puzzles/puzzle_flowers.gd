extends Puzzle
class_name PuzzleFlowers

## Vulvania: flores tipo Lights Out 3x3. Cada flor sobre su placa; al pisar una, se abre
## o se cierra ella y las cuatro vecinas. Nadie dice que hay que abrirlas todas: pisar una
## ya lo ensena, y "todo en flor" es la meta evidente. Entre placas hay pasillos para andar
## sin pisar las que no toca. Siempre tiene solucion: se desordena desde "todo abierto"
## con pisadas reales. Dificultad: cuantas pisadas de desorden (3 a 7).

var _open: Array[bool] = []
var _plates: Array[PuzzlePlate] = []
var _toggles := 0


func build() -> void:
	kind = "flowers"
	g_cols = 3
	g_rows = 3
	g_space = clampf((area.y - 36.0) * 0.5, 54.0, 70.0)
	var n := g_cols * g_rows
	_open.resize(n)
	_open.fill(true)
	var steps := clampi(2 + depth, 3, 7)
	var tries := 0
	while true:
		tries += 1
		var cells: Array[int] = []
		for i in n:
			cells.append(i)
		for i in range(n - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := cells[i]
			cells[i] = cells[j]
			cells[j] = t
		_open.fill(true)
		for k in steps:
			_apply(cells[k])
		if (not _open.all(func(v): return v) and solution().size() >= clampi(1 + depth / 2 + 1, 2, 4)) or tries > 40:
			break
	for i in n:
		var c := Vector2i(i % g_cols, i / g_cols)
		var p := PuzzlePlate.new().setup(kingdom, true, 11.0)
		p.position = cell_pos(c)
		p.cell = c
		p.tag = i
		p.set_glyph("flower_open" if _open[i] else "flower_closed", -7.0)
		p.stepped.connect(_on_step)
		add_child(p)
		_plates.append(p)


func _apply(i: int) -> void:
	var c := Vector2i(i % g_cols, i / g_cols)
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if n.x >= 0 and n.y >= 0 and n.x < g_cols and n.y < g_rows:
			_open[n.y * g_cols + n.x] = not _open[n.y * g_cols + n.x]


func _on_step(plate: PuzzlePlate) -> void:
	if done:
		return
	_apply(plate.tag)
	_toggles += 1
	_plan.clear()
	Sound.play("tone_%d" % (plate.tag % 4), 0.0)
	for i in _plates.size():
		var g := _plates[i].glyph()
		var tex := PuzzlePlate.load_tex("flower_open" if _open[i] else "flower_closed")
		if g.texture != tex:
			g.texture = tex
			g.scale = Vector2(1.3, 0.75)
			g.create_tween().tween_property(g, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _open.all(func(v): return v):
		for p in _plates:
			p.flash(Color(1.8, 1.6, 1.8), 1.0)
		solve()
	elif _toggles % 10 == 0:
		var lv := mini(_toggles / 10, 3)
		if lv > _hint_lvl:  # la misma pista no se repite si ya la dio el reloj (Puzzle._tick_hint)
			_give_hint(lv)


## Subconjunto minimo de pisadas (fuerza bruta sobre 2^9) que deja todo abierto.
func solution() -> Array:
	var n := g_cols * g_rows
	var best_mask := -1
	var best_bits := 99
	for mask in 1 << n:
		var st := _open.duplicate()
		for i in n:
			if (mask >> i) & 1:
				var c := Vector2i(i % g_cols, i / g_cols)
				for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var m: Vector2i = c + d
					if m.x >= 0 and m.y >= 0 and m.x < g_cols and m.y < g_rows:
						st[m.y * g_cols + m.x] = not st[m.y * g_cols + m.x]
		if st.all(func(v): return v):
			var bits := 0
			for i in n:
				bits += (mask >> i) & 1
			if bits < best_bits:
				best_bits = bits
				best_mask = mask
	var out: Array = []
	for i in n:
		if best_mask >= 0 and (best_mask >> i) & 1:
			out.append(i)
	return out


func _bot_plan(from: Vector2) -> Array:
	var todo := solution()
	if todo.is_empty():
		return []
	# la mas cercana primero
	todo.sort_custom(func(a, b): return cell_pos(Vector2i(a % g_cols, a / g_cols)).distance_to(from) < cell_pos(Vector2i(b % g_cols, b / g_cols)).distance_to(from))
	var route := lane_route(from, Vector2i(todo[0] % g_cols, todo[0] / g_cols))
	return route
