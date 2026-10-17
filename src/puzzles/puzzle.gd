extends Node2D
class_name Puzzle

## Base de los acertijos de sala. NINGUNO se explica: sin carteles ni instrucciones; el
## jugador descubre las condiciones probando. A lo mas, pistas del entorno (el formulario
## del Perineo, la secuencia que brilla) o del narrador DESPUES de fallar (hint()).
##
## Contrato con main.gd (via PuzzleFactory): `solved` al resolverse, `replay()` al volver a
## entrar. Contrato con el bot (tools/autoplay): bot_step(pos) -> {"go": Vector2 global,
## "interact": bool} o {} si no hay nada que hacer; cada acertijo implementa _bot_plan().
## Los mismos waypoints los usan las pruebas, con el mismo solver.

signal solved

## Espacio libre de la sala (sin la franja de puertas) y datos del piso.
var area := Vector2(256, 160)
var kingdom := "neutral"
var depth := 1
var rng := RandomNumberGenerator.new()
var done := false
var fails := 0
## Evento del narrador (puzzles.json): pz_<kind>_1, _2, _3 segun los fallos.
var kind := ""
var _plan: Array = []  # [{"p": Vector2 local, "act": bool}]


func _ready() -> void:
	build()


## Los hijos arman su sala aqui (area/kingdom/depth/rng ya los puso la fabrica).
func build() -> void:
	pass


## Al volver a entrar en la sala sin resolver.
func replay() -> void:
	pass


func solve() -> void:
	if done:
		return
	done = true
	Sound.play("puzzle_solve")
	solved.emit()


## Tras fallar: cada dos fallos el narrador da una pista mas clara (si le caes bien).
func note_fail(every := 2) -> void:
	fails += 1
	if fails % every != 0:
		return
	hint(mini(fails / every, 3))


func hint(level: int, args := {}) -> void:
	if Narrator.ignored_count >= 2 and not Narrator._seen.has("puzzle_hint_refused"):
		Narrator.say_first("puzzle_hint_refused", {"n": Narrator.ignored_count})
	else:
		Narrator.say("pz_%s_%d" % [kind, level], args)


func player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


# ------------------------------------------------------------------ bot
func bot_step(pos: Vector2) -> Dictionary:
	if done or not is_inside_tree():
		return {}
	if _plan.is_empty():
		_plan = _bot_plan(pos - global_position)
	if _plan.is_empty():
		return {}
	var s: Dictionary = _plan[0]
	var g: Vector2 = global_position + s.p
	if pos.distance_to(g) < 8.0:
		_plan.pop_front()
		return {"go": g, "interact": bool(s.get("act", false))}
	return {"go": g, "interact": false}


## Pasos para llegar a la solucion desde `from` (local). Cada puzzle lo reescribe.
func _bot_plan(_from: Vector2) -> Array:
	return []


func bot_replan() -> void:
	_plan.clear()


func _wp(p: Vector2, act := false) -> Dictionary:
	return {"p": p, "act": act}


# ------------------------------------------------------------------ rejilla de placas con pasillos
## Placas en rejilla con pasillos entre ellas (para no pisar las que no toca al andar).
var g_cols := 3
var g_rows := 3
var g_space := 62.0


func cell_pos(c: Vector2i) -> Vector2:
	return Vector2((c.x - (g_cols - 1) * 0.5) * g_space, (c.y - (g_rows - 1) * 0.5) * g_space)


func _lane_pos(i: int, j: int) -> Vector2:
	return Vector2((i - g_cols * 0.5) * g_space, (j - g_rows * 0.5) * g_space)


## Waypoints desde `from` (local) hasta el centro de la placa c, siguiendo los pasillos.
## Si ya estas en una placa, sale por la esquina mas cercana.
func lane_route(from: Vector2, c: Vector2i) -> Array:
	var nodes := {}
	for i in g_cols + 1:
		for j in g_rows + 1:
			nodes[Vector2i(i, j)] = _lane_pos(i, j)
	var start := Vector2i.ZERO
	var best := INF
	for k in nodes:
		var d: float = nodes[k].distance_to(from)
		if d < best:
			best = d
			start = k
	var goals := [Vector2i(c.x, c.y), Vector2i(c.x + 1, c.y), Vector2i(c.x, c.y + 1), Vector2i(c.x + 1, c.y + 1)]
	var goal: Vector2i = goals[0]
	best = INF
	for gk in goals:
		var d: float = nodes[start].distance_to(nodes[gk])
		if d < best:
			best = d
			goal = gk
	var prev := {start: start}
	var queue := [start]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == goal:
			break
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + dv
			if nodes.has(n) and not prev.has(n):
				prev[n] = cur
				queue.append(n)
	var route: Array = []
	var k := goal
	while k != start:
		route.push_front(_wp(nodes[k]))
		k = prev[k]
	route.push_front(_wp(nodes[start]))
	route.append(_wp(cell_pos(c)))
	return route


# ------------------------------------------------------------------ ayudas comunes
func make_label(text: String, size := 8, color := Color("f2ead6")) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(120, 16)
	l.position = -l.size / 2
	HudStyle.style_label(l, size, color)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	l.material = LightKit.unshaded_material()
	return l
