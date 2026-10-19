extends Defense
class_name DefTalco

## TALCO (defensa). PULSAR "guard": sacudes el talco y queda una NUBE (radio RADIUS, dura CLOUD_TIME s) donde
## estas parado. Los enemigos que respiran la nube se CONFUNDEN: huyen sin rumbo (scare) y pierden el hilo.
## A los jefes no les hace nada. Recarga larga.

const RADIUS := 115.0
const CLOUD_TIME := 4.0
const COOLDOWN := 16.0
const TICK := 0.5
const CONFUSE := 1.4

var puffs := 0
var _cloud := 0.0
var _cd := 0.0
var _pos := Vector2.ZERO
var _tick := 0.0
var _t := 0.0
var _motes: Array[Vector3] = []


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("c8dcff")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf())
		_motes.append(Vector3(cos(a) * d, sin(a) * d, rng.randf_range(3.0, 8.0)))


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	cooling = _cd > 0.0 and _cloud <= 0.0
	if guard_pressed() and _cd <= 0.0 and _cloud <= 0.0:
		_cloud = CLOUD_TIME
		_cd = COOLDOWN
		_pos = player.global_position
		puffs += 1
		_tick = 0.0
		text("DEF_TALC_PUFF", Color("e8f0ff"))
		Sound.play("room_clear", 0.1)
	if _cloud > 0.0:
		_cloud -= delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK
			_confuse()
	gauge_visible = _cd > 0.0
	gauge_value = 1.0 - _cd / COOLDOWN


func _confuse() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_in_group("boss") or float(e.get("current_health")) <= 0.0:
			continue
		if (e as Node2D).global_position.distance_to(_pos) <= RADIUS and e.has_method("scare"):
			e.scare(CONFUSE, _pos)


func _draw_tick() -> void:
	_t += get_process_delta_time()
	if _cloud > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if _cloud <= 0.0:
		return
	var fade := clampf(_cloud / 0.8, 0.0, 1.0)
	var c: Vector2 = _pos - global_position
	var grow := clampf((CLOUD_TIME - _cloud) / 0.4, 0.2, 1.0)
	draw_circle(c, RADIUS * grow, Color(0.9, 0.93, 1.0, 0.16 * fade))
	for m in _motes:
		var p := c + Vector2(m.x, m.y) * RADIUS * grow * 0.95 + Vector2(sin(_t * 1.5 + m.z), cos(_t * 1.2 + m.z)) * 4.0
		draw_circle(p, m.z * 1.6, Color(0.96, 0.97, 1.0, 0.35 * fade))
