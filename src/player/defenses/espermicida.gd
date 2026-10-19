extends Defense
class_name DefEspermicida

## ESPERMICIDA (defensa). PULSAR "guard": dejas una ZONA de gel en el suelo (radio RADIUS, dura ZONE_TIME s).
## Los enemigos que la pisan se FRENAN (SLOW x de velocidad) y quedan DEBILES (reciben WEAK_MULT x de dano).
## Los jefes no la sienten. Sola es poco eficaz (corta, recarga larga): "mejor combinado con condon".

const RADIUS := 85.0
const ZONE_TIME := 9.0
const COOLDOWN := 15.0
const SLOW := 0.5
const WEAK_MULT := 1.25
const TICK := 0.1

var uses := 0
var _zone := 0.0
var _cd := 0.0
var _pos := Vector2.ZERO
var _tick := 0.0
var _in: Dictionary = {}   # id -> enemigo frenado ahora
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("f0d060")


func on_removed() -> void:
	_release_all()


func _release(e) -> void:
	if not is_instance_valid(e):
		return
	if e.has_meta("dmg_taken_mult"):
		e.remove_meta("dmg_taken_mult")
	e.set("move_speed", float(e.get("move_speed")) / SLOW)
	e.set("lunge_speed", float(e.get("lunge_speed")) / SLOW)


func _release_all() -> void:
	for id in _in:
		_release(_in[id])
	_in.clear()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	cooling = _cd > 0.0 and _zone <= 0.0
	if guard_pressed() and _cd <= 0.0 and _zone <= 0.0:
		_zone = ZONE_TIME
		_cd = COOLDOWN
		_pos = player.global_position
		uses += 1
		text("DEF_SPERM_ZONE", Color("fff0a0"))
		Sound.play("room_clear", 0.1)
	if _zone > 0.0:
		_zone -= delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = TICK
			_apply()
		if _zone <= 0.0:
			_release_all()
	gauge_visible = _cd > 0.0
	gauge_value = 1.0 - _cd / COOLDOWN


func _apply() -> void:
	var now := {}
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D) or e.is_in_group("boss") or float(e.get("current_health")) <= 0.0:
			continue
		if not ("move_speed" in e and "lunge_speed" in e) or (e as Node2D).global_position.distance_to(_pos) > RADIUS:
			continue
		var id: int = e.get_instance_id()
		now[id] = e
		if not _in.has(id):
			e.set("move_speed", float(e.get("move_speed")) * SLOW)
			e.set("lunge_speed", float(e.get("lunge_speed")) * SLOW)
		e.set_meta("dmg_taken_mult", WEAK_MULT)
	for id in _in:
		if not now.has(id):
			_release(_in[id])
	_in = now


func _draw_tick() -> void:
	_t += get_process_delta_time()
	if _zone > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if _zone <= 0.0:
		return
	var fade := clampf(_zone / 1.0, 0.0, 1.0)
	var c := to_local(_pos)
	var grow := clampf((ZONE_TIME - _zone) / 0.3, 0.3, 1.0)
	draw_circle(c, RADIUS * grow, Color(1.0, 0.92, 0.45, 0.20 * fade))
	draw_arc(c, RADIUS * grow, 0.0, TAU, 40, Color(0.95, 0.8, 0.25, 0.7 * fade), 2.5)
	for i in 9:
		var a := i * 2.4 + 0.5
		var d := RADIUS * 0.7 * fposmod(i * 0.37, 1.0)
		var bub := 2.0 + 1.5 * sin(_t * 3.0 + i)
		draw_circle(c + Vector2(cos(a), sin(a)) * d, bub, Color(1.0, 0.98, 0.7, 0.45 * fade))
