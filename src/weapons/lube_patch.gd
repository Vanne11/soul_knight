class_name LubePatch
extends Node2D

## Lubricante a base de agua: una mancha RESBALOSA ("piso resbaloso", como el letrero de la farmacia). Cada ~1,6 s los enemigos
## que la pisan se RESBALAN: casi se quedan sin velocidad 0,7 s y se llevan un golpe por el tropezon (los jefes solo patinan
## un 40 % mas lento y un golpe chico). Ademas DISIPA los charcos de aceite (PtHazard.ACEITE) que toque.
## Dato educativo: con condones de latex nunca uses aceite; el lubricante a base de agua o de silicona si es compatible (PT-21).

var radius := 64.0
var time := 6.0
var slip_every := 1.6
var slip_time := 0.7
var slip_damage := 12.0
var weapon_id := ""
var _t := 0.0
var _clean_t := 0.0
var _seed := 0.0
var _en: Dictionary = {}  # enemigo -> {orig, applied, next, slip}


static func make(parent: Node, pos: Vector2, cfg: Dictionary) -> LubePatch:
	var l := LubePatch.new()
	l.radius = float(cfg.get("radius", 64.0))
	l.time = float(cfg.get("time", 6.0))
	l.slip_every = float(cfg.get("slip_every", 1.6))
	l.slip_time = float(cfg.get("slip_time", 0.7))
	l.slip_damage = float(cfg.get("slip_damage", 12.0))
	l.weapon_id = String(cfg.get("weapon_id", ""))
	parent.add_child(l)
	l.global_position = pos
	return l


func _ready() -> void:
	z_index = -1
	_seed = randf() * TAU
	add_to_group("lube_patch")


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= time:
		queue_free()
		return
	_clean_t -= delta
	if _clean_t <= 0.0:
		_clean_t = 0.4
		PtHazard.clean(get_tree(), global_position, radius, PtHazard.Kind.ACEITE)
	var inside: Array = []
	var player := get_tree().get_first_node_in_group("player")
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not ("move_speed" in e) or float(e.get("current_health")) <= 0.0:
			continue
		if e.global_position.distance_to(global_position) > radius:
			continue
		inside.append(e)
		if not _en.has(e):
			_en[e] = {"orig": 0.0, "applied": -1.0, "next": RNG.randf_range(0.15, 0.6), "slip": 0.0}
		var d: Dictionary = _en[e]
		if d.slip > 0.0:
			d.slip -= delta
			if d.slip <= 0.0:
				_restore(e)
		else:
			d.next -= delta
			if d.next <= 0.0:
				d.next = slip_every
				d.slip = slip_time
				d.applied = 1.0
				SlowStack.set_factor(e, _slow_key(), 0.6 if e.is_in_group("boss") else 0.1)
				BossDamage.tag(weapon_id, 1.0)
				e.take_damage(slip_damage * (0.4 if e.is_in_group("boss") else 1.0), player, Vector2.ZERO)
				get_node("/root/GlobalEvents").show_floating_text.emit(e.global_position + Vector2(0, -40), tr("PT_LUBE_SLIP"), Color("9fe3ff"))
	for e in _en.keys():
		if not is_instance_valid(e) or e not in inside:
			_restore(e)
			_en.erase(e)
	queue_redraw()


func _restore(e: Variant) -> void:
	if not is_instance_valid(e) or not _en.has(e):
		return
	var d: Dictionary = _en[e]
	if d.applied >= 0.0:
		SlowStack.clear(e, _slow_key())
	d.applied = -1.0
	d.slip = 0.0


func _slow_key() -> String:
	return "lube_%d" % get_instance_id()


func _exit_tree() -> void:
	for e in _en.keys():
		_restore(e)
	_en.clear()


func _draw() -> void:
	var fade := clampf((time - _t) / 0.8, 0.0, 1.0) * clampf(_t / 0.1, 0.0, 1.0)
	var r := radius * minf(1.0, 0.35 + _t * 7.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(Vector2(cos(a), sin(a)) * r * (0.9 + 0.08 * sin(3.0 * a + _seed)))
	draw_colored_polygon(pts, Color(0.55, 0.82, 1.0, 0.55 * fade))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.72)
	draw_colored_polygon(inner, Color(0.78, 0.93, 1.0, 0.55 * fade))
	var line := pts.duplicate()
	line.append(pts[0])
	draw_polyline(line, Color(0.3, 0.6, 0.95, fade), 2.0)
	# brillos que se mueven ("resbaloso")
	for k in 4:
		var a2 := _t * 1.5 + k * 1.6 + _seed
		draw_circle(Vector2(cos(a2), sin(a2)) * r * 0.5, 2.5, Color(1, 1, 1, 0.8 * fade))
