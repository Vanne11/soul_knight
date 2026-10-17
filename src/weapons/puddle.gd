class_name Puddle
extends Node2D

## Charco que deja un globo de agua: frena a los enemigos que lo pisan (a `slow` de su
## velocidad) y, con la sinergia Spa Improvisado, cura al jugador que se queda dentro.
## Un enemigo en varios charcos solo se frena una vez (cuenta de charcos en `_users`).

static var _users: Dictionary = {}  # enemigo -> [charcos que lo frenan, velocidad original]

var radius := 62.0
var time := 4.0
var slow := 0.5
var _t := 0.0
var _mine: Array = []
var _heal_acc := 0.0
var _jitter := 0.0


static func spawn(parent: Node, pos: Vector2, cfg: Dictionary) -> Puddle:
	var p := Puddle.new()
	p.radius = float(cfg.get("radius", 62.0))
	p.time = float(cfg.get("time", 4.0))
	p.slow = float(cfg.get("slow", 0.5))
	parent.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	z_index = -1
	add_to_group("puddle")


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= time:
		queue_free()
		return
	var inside: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not ("move_speed" in e) or float(e.get("current_health")) <= 0.0:
			continue
		if e.global_position.distance_to(global_position) <= radius:
			inside.append(e)
			if e not in _mine:
				_mine.append(e)
				_grab(e)
	for e in _mine.duplicate():
		if not is_instance_valid(e) or e not in inside:
			_mine.erase(e)
			_drop(e)
	if Synergies.has("spa_improvisado"):
		var pl := get_tree().get_first_node_in_group("player")
		if pl != null and pl.global_position.distance_to(global_position) <= radius:
			_heal_acc += delta * 1.5
			if _heal_acc >= 1.0:
				_heal_acc -= 1.0
				get_node("/root/PlayerStats").heal(1.0)
	queue_redraw()


func _grab(e: Variant) -> void:
	if _users.has(e):
		_users[e][0] += 1
		return
	var orig := float(e.get("move_speed"))
	var applied := orig * (0.75 if e.is_in_group("boss") else slow)
	_users[e] = [1, orig, applied]
	e.set("move_speed", applied)


func _drop(e: Variant) -> void:
	if not _users.has(e):
		return
	_users[e][0] -= 1
	if _users[e][0] <= 0:
		# si la IA recalculo la velocidad mientras estaba en el charco, no se pisa
		if is_instance_valid(e) and is_equal_approx(float(e.get("move_speed")), _users[e][2]):
			e.set("move_speed", _users[e][1])
		_users.erase(e)


func _exit_tree() -> void:
	for e in _mine:
		_drop(e)
	_mine.clear()


func _draw() -> void:
	var fade := clampf((time - _t) / 0.6, 0.0, 1.0) * clampf(_t / 0.12, 0.0, 1.0)
	var r := radius * minf(1.0, 0.4 + _t * 6.0)
	var sq := 0.62  # perspectiva: charco aplastado
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, sq))
	draw_circle(Vector2.ZERO, r, Color(0.3, 0.6, 1.0, 0.28 * fade))
	draw_circle(Vector2.ZERO, r * 0.82, Color(0.45, 0.75, 1.0, 0.22 * fade))
	for i in 2:
		var k := fmod(_t * 0.9 + i * 0.5, 1.0)
		draw_arc(Vector2.ZERO, r * (0.25 + 0.7 * k), 0.0, TAU, 32, Color(0.85, 0.95, 1.0, (1.0 - k) * 0.7 * fade), 1.5)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.7, 0.9, 1.0, 0.6 * fade), 2.0)
