class_name PtHazard
extends Node2D

## Peligros de suelo de LA PUERTA TRASERA, dibujados por codigo (sin fisica: el dano se mide por geometria).
##  GRIETA (Fisura Fina): una raja en el suelo. AVISA 0,45 s (trazo tenue) y luego daña un rato a quien la pise.
##  ACEITE (Aceite Traicionero): un charco brillante. Mientras estas dentro se te "rompe el condon": pierdes escudo
##   (los aceites rompen el latex; PT-21). Un lubricante a base de agua (LubePatch) o la Ducha Anal lo disipan.
## Aviso siempre antes de hacer dano. Maximo MAX_PER_KIND vivos por tipo (el mas viejo se borra).

enum Kind { GRIETA, ACEITE }

const GROUP := "pt_hazard"
const MAX_PER_KIND := 7
const GRIETA_COL := Color(0.36, 0.22, 0.12)
const ACEITE_COL := Color(0.93, 0.7, 0.16)

var kind := Kind.GRIETA
var damage := 6.0
var radius := 44.0
var length := 40.0
var warn := 0.45
var life := 5.0
var _t := 0.0
var _tick := 0.0
var _pts := PackedVector2Array()
var _seed := 0.0


static func spawn(parent: Node, pos: Vector2, k: Kind, dmg: float, rot := 0.0) -> PtHazard:
	var h := PtHazard.new()
	h.kind = k
	h.damage = dmg
	if k == Kind.GRIETA:
		h.life = 4.5
		h.warn = 0.45
	else:
		h.life = 8.0
		h.warn = 0.5
	h.rotation = rot
	# tope por tipo: borra el mas viejo
	var same: Array = []
	for n in parent.get_tree().get_nodes_in_group(GROUP):
		if is_instance_valid(n) and n is PtHazard and n.kind == k:
			same.append(n)
	if same.size() >= MAX_PER_KIND:
		same[0].queue_free()
	parent.add_child(h)
	h.global_position = pos
	return h


## Borra los peligros dentro de `r` px de `pos` (Ducha Anal, Lubricante). Devuelve cuantos limpio.
static func clean(tree: SceneTree, pos: Vector2, r: float, only_kind := -1) -> int:
	var n := 0
	for h in tree.get_nodes_in_group(GROUP):
		if is_instance_valid(h) and h is PtHazard and (only_kind < 0 or h.kind == only_kind):
			if h.global_position.distance_to(pos) <= r + h.radius * 0.5:
				h.dissolve()
				n += 1
	return n


func _ready() -> void:
	z_index = -1
	add_to_group(GROUP)
	_seed = randf() * TAU
	if kind == Kind.GRIETA:
		var p := Vector2(-length * 0.5, 0.0)
		_pts.append(p)
		var steps := 5
		for i in steps:
			p += Vector2(length / steps, RNG.randf_range(-6.0, 6.0))
			_pts.append(p)


func dissolve() -> void:
	life = minf(life, _t + 0.25)


func is_active() -> bool:
	return _t >= warn


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	if _t >= warn:
		_tick -= delta
		if _tick <= 0.0:
			var pl := get_tree().get_first_node_in_group("player")
			if pl != null and _contains(pl.global_position):
				_tick = 0.5 if kind == Kind.ACEITE else 0.6
				_hurt(pl)
	queue_redraw()


func _contains(p: Vector2) -> bool:
	if kind == Kind.ACEITE:
		var d := p - global_position
		return Vector2(d.x / radius, d.y / (radius * 0.62)).length() <= 1.0
	var a := global_position + _pts[0].rotated(rotation)
	var best := 1e9
	for i in range(1, _pts.size()):
		var b := global_position + _pts[i].rotated(rotation)
		var cp := Geometry2D.get_closest_point_to_segment(p, a, b)
		best = minf(best, cp.distance_to(p))
		a = b
	return best <= 13.0


func _hurt(pl: Node) -> void:
	if kind == Kind.GRIETA:
		if pl.has_method("receive_hit"):
			pl.receive_hit(damage)
		return
	# aceite: se rompe el condon (escudo). Sin escudo, solo un resbalon que pica un poco.
	var ps := get_node_or_null("/root/PlayerStats")
	if ps == null:
		return
	if float(ps.current_shields) > 0.0:
		ps.current_shields = maxf(0.0, float(ps.current_shields) - maxf(4.0, damage * 1.2))
		ps.shields_changed.emit(ps.current_shields, ps.max_shields)
		var ge := get_node_or_null("/root/GlobalEvents")
		if ge != null and Engine.get_physics_frames() % 3 == 0:
			ge.show_floating_text.emit(pl.global_position + Vector2(0, -34), tr("PT_OIL_BREAK"), Color("f2c14e"))
	elif pl.has_method("receive_hit"):
		pl.receive_hit(damage * 0.5)


func _draw() -> void:
	var live := clampf((life - _t) / 0.6, 0.0, 1.0)
	var armed := _t >= warn
	if kind == Kind.GRIETA:
		var col := GRIETA_COL if armed else Color(GRIETA_COL, 0.45 + 0.3 * sin(_t * 30.0))
		col.a *= live
		draw_polyline(_pts, Color(0.1, 0.05, 0.03, col.a), 6.0)
		draw_polyline(_pts, col, 3.0)
		if armed:
			draw_polyline(_pts, Color(1.0, 0.55, 0.2, 0.55 * live), 1.0)  # brasa del fondo de la grieta
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	var r := radius * minf(1.0, 0.4 + _t * 4.0)
	var out := PackedVector2Array()
	for i in 26:
		var a := TAU * float(i) / 26.0
		out.append(Vector2(cos(a), sin(a)) * r * (0.9 + 0.08 * sin(3.0 * a + _seed)))
	if armed:
		draw_colored_polygon(out, Color(ACEITE_COL, 0.78 * live))
		var inner := PackedVector2Array()
		for p in out:
			inner.append(p * 0.7)
		draw_colored_polygon(inner, Color(1.0, 0.86, 0.38, 0.8 * live))
		draw_circle(Vector2(-r * 0.3, -r * 0.2), 4.0, Color(1, 1, 0.85, 0.9 * live))
	else:
		var line := out.duplicate()
		line.append(out[0])
		draw_polyline(line, Color(ACEITE_COL, 0.9 if int(_t * 12.0) % 2 == 0 else 0.4), 2.0)  # aviso: contorno que parpadea
	var edge := out.duplicate()
	edge.append(out[0])
	draw_polyline(edge, Color(0.45, 0.3, 0.05, live), 2.0)
