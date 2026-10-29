class_name Masilla
extends Node2D

## Mancha de masilla (Tarro de Masilla): al pisarla los enemigos quedan PEGADOS `stick` s
## (velocidad ~0); pasado ese tiempo se despegan, y mientras sigan dentro solo van lentos
## (no se vuelven a pegar con la misma mancha). Los jefes nunca se pegan: van a `boss_slow`.
## Cada enemigo pegado cuenta para la medalla "Con cariño". Guiño personal a Vanessa.

const STUCK_SPEED := 0.04
const FREE_SLOW := 0.6

static var _users: Dictionary = {}  # enemigo -> [manchas que lo afectan] (el frenado va por SlowStack)

var radius := 58.0
var time := 5.0
var stick := 2.5
var boss_slow := 0.75
## false: no suma a la medalla "Con carino" (lo usa CondomBubble, que hereda de Masilla).
var counts_medal := true
var _t := 0.0
var _state: Dictionary = {}  # enemigo -> segundos pegado (>= stick = ya liberado)
var _seed := 0.0


static func spawn(parent: Node, pos: Vector2, cfg: Dictionary) -> Masilla:
	var m := Masilla.new()
	m.radius = float(cfg.get("radius", 58.0))
	m.time = float(cfg.get("time", 5.0))
	m.stick = float(cfg.get("stick", 2.5))
	m.boss_slow = float(cfg.get("boss_slow", 0.75))
	parent.add_child(m)
	m.global_position = pos
	return m


func _ready() -> void:
	z_index = -1
	_seed = randf() * TAU
	add_to_group("masilla")


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= time:
		queue_free()
		return
	var inside: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not ("move_speed" in e) or float(e.get("current_health")) <= 0.0:
			continue
		if e.global_position.distance_to(global_position) > radius:
			continue
		inside.append(e)
		if not _state.has(e):
			_state[e] = 0.0
			if not e.is_in_group("boss"):
				var m := get_node_or_null("/root/Medallas")
				if counts_medal and m != null and m.has_method("contar_masilla"):
					m.contar_masilla()
		else:
			_state[e] += delta
		var f := boss_slow if e.is_in_group("boss") else (STUCK_SPEED if _state[e] < stick else FREE_SLOW)
		_apply(e, f)
	for e in _state.keys():
		if not is_instance_valid(e) or e not in inside:
			_release(e)
			_state.erase(e)
	queue_redraw()


func _apply(e: Variant, factor: float) -> void:
	if not _users.has(e):
		_users[e] = [1]
	elif not _mine_counted(e):
		_users[e][0] += 1
	SlowStack.set_factor(e, "masilla", factor)
	if not e.has_meta("masilla_" + str(get_instance_id())):
		e.set_meta("masilla_" + str(get_instance_id()), true)


func _mine_counted(e: Variant) -> bool:
	return e.has_meta("masilla_" + str(get_instance_id()))


func _release(e: Variant) -> void:
	if not is_instance_valid(e) or not _users.has(e):
		return
	e.remove_meta("masilla_" + str(get_instance_id()))
	_users[e][0] -= 1
	if _users[e][0] <= 0:
		SlowStack.clear(e, "masilla")
		_users.erase(e)


func _exit_tree() -> void:
	for e in _state.keys():
		_release(e)
	_state.clear()


func _draw() -> void:
	var fade := clampf((time - _t) / 0.8, 0.0, 1.0) * clampf(_t / 0.1, 0.0, 1.0)
	var r := radius * minf(1.0, 0.35 + _t * 7.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(Vector2(cos(a), sin(a)) * r * (0.88 + 0.1 * sin(3.0 * a + _seed) + 0.05 * sin(5.0 * a + _seed * 2.0)))
	draw_colored_polygon(pts, Color(0.5, 0.58, 0.46, 0.92 * fade))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.78)
	draw_colored_polygon(inner, Color(0.62, 0.7, 0.56, 0.9 * fade))
	var line := pts.duplicate()
	line.append(pts[0])
	draw_polyline(line, Color(0.27, 0.32, 0.26, fade), 2.0)
	# brillo humedo + espatulazos
	draw_arc(Vector2(-r * 0.2, -r * 0.1), r * 0.5, PI * 1.05, PI * 1.55, 12, Color(0.88, 0.95, 0.8, 0.85 * fade), 2.0)
	draw_circle(Vector2(r * 0.3, -r * 0.18), 3.0, Color(0.92, 0.98, 0.85, 0.9 * fade))
	draw_circle(Vector2(-r * 0.45, r * 0.2), 2.0, Color(0.92, 0.98, 0.85, 0.7 * fade))
	for k in 3:
		var y := -r * 0.25 + k * r * 0.22
		draw_line(Vector2(-r * 0.5, y), Vector2(r * 0.4, y + 3.0), Color(0.42, 0.5, 0.4, 0.55 * fade), 1.5)
	# pegados: hilitos de masilla hacia arriba
	for e in _state.keys():
		if is_instance_valid(e) and _state[e] < stick:
			var p: Vector2 = (e.global_position - global_position)
			draw_line(Vector2(p.x, p.y / 0.62), Vector2(p.x, p.y / 0.62 - 6.0), Color(0.6, 0.68, 0.54, fade), 3.0)
