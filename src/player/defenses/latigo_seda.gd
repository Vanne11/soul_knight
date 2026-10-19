extends Defense
class_name DefLatigoSeda

## LATIGO DE SEDA (defensa). PULSAR "guard": chasquea la seda hacia donde apuntas. Si engancha a un enemigo
## (no jefe) lo ATRAE hacia ti y lo deja aturdido un instante. Si no hay enemigo al alcance, o es un jefe
## (los jefes no se dejan), la seda se prende de la pared / del jefe y TE JALA a ti hacia ese punto.
## Siempre con consentimiento y palabra de seguridad. Recarga corta (COOLDOWN), mas corta si falla.

const RANGE := 280.0
const MIN_DOT := 0.55
const PULL_TIME := 0.28
const STUN := 0.8
const COOLDOWN := 4.0
const MISS_COOLDOWN := 1.2
const SELF_SPEED := 760.0
const STOP_DIST := 40.0
const WALL_MASK := 1

var cracks := 0
var _cd := 0.0
var _cd_total := COOLDOWN
var _line := 0.0
var _to := Vector2.ZERO
var _victim: CharacterBody2D = null
var _pull_left := 0.0
var _pull_speed := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("ff4fa8")


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	_line = maxf(0.0, _line - delta)
	cooling = _cd > 0.0
	gauge_visible = _cd > 0.0
	gauge_value = 1.0 - _cd / _cd_total
	if _pull_left > 0.0:
		_pull_left -= delta
		if _victim != null and is_instance_valid(_victim):
			var want: Vector2 = player.global_position + player._aim * STOP_DIST
			var to: Vector2 = want - _victim.global_position
			if to.length() > 6.0:
				_victim.move_and_collide(to.normalized() * minf(_pull_speed * delta, to.length()))
			_to = _victim.global_position
		if _pull_left <= 0.0 and _victim != null and is_instance_valid(_victim) and _victim.has_method("stun"):
			_victim.stun(STUN)
	if guard_pressed() and _cd <= 0.0:
		_crack()


func _crack() -> void:
	cracks += 1
	var origin: Vector2 = player.global_position
	var e := nearest_enemy(RANGE, MIN_DOT)
	Sound.play("locked", 0.1)
	if e != null and not e.is_in_group("boss") and e is CharacterBody2D and origin.distance_to(e.global_position) > STOP_DIST + 8.0:
		_victim = e as CharacterBody2D
		_pull_left = PULL_TIME
		_pull_speed = origin.distance_to(e.global_position) / PULL_TIME
		_to = e.global_position
		_line = 0.3
		_start(COOLDOWN)
		text("DEF_WHIP_PULL", Color("ff7ac0"))
		return
	# sin victima: la seda se prende de un jefe o de la pared y te jala
	var target := origin + player._aim * RANGE
	var anchored_on_boss := false
	if e != null and e.is_in_group("boss"):
		target = e.global_position
		anchored_on_boss = true
	else:
		var q := PhysicsRayQueryParameters2D.create(origin, origin + player._aim * RANGE, WALL_MASK)
		var hit := player.get_world_2d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			_to = target
			_line = 0.15
			_start(MISS_COOLDOWN)
			text("DEF_WHIP_MISS", Color("c88aa8"))
			return
		target = hit.position
	var gap: float = origin.distance_to(target) - STOP_DIST
	if gap < 20.0:
		_start(MISS_COOLDOWN)
		return
	_to = target
	_line = 0.25
	player.shove((target - origin).normalized() * SELF_SPEED, minf(gap / SELF_SPEED, 0.35))
	_start(COOLDOWN)
	text("DEF_WHIP_SELF" if not anchored_on_boss else "DEF_WHIP_BOSS", Color("ff7ac0"))


func _start(cd: float) -> void:
	_cd = cd
	_cd_total = cd


func _draw_tick() -> void:
	if _line > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if _line <= 0.0:
		return
	var end: Vector2 = _to - global_position
	var n := 14
	var perp := end.normalized().rotated(PI * 0.5)
	var prev := Vector2.ZERO
	for i in range(1, n + 1):
		var k := float(i) / n
		var p := end * k + perp * sin(k * PI * 3.0 + _line * 30.0) * 6.0 * (1.0 - k)
		draw_line(prev, p, Color(0.25, 0.0, 0.15, 0.9), 4.0)
		draw_line(prev, p, Color("ff4fa8"), 2.0)
		prev = p
	draw_circle(end, 4.0, Color("ffd0e8"))
