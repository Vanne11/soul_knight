class_name UteroOvulo
extends RoomDynamic

## Fase de OVULACION del Utero: "el ovulo se suelta, alcanzalo". Un ovulo dorado corre por la
## sala huyendo de ti (mismo esquema que la ladilla de obj_thief.gd: va esquivando muros y a
## veces arranca). Tocarlo lo atrapa: premio (monedas, vida y un destello). Si pasan SECS se
## desvanece sin castigo: es un extra opcional, no bloquea la sala (gate por defecto). Corre a
## la vez que los enemigos normales y el modificador "celo" de la fase.

const SECS := 32.0
const SPEED := 205.0
const DASH := 400.0
const CATCH_DIST := 36.0
const STEPS := 16
const LOOK := 70.0
const FRAMES := "res://assets/sprites/enemies/ovulo_sprite_frames.tres"

var egg: CharacterBody2D
var _spr: AnimatedSprite2D
var _t := 0.0
var _cool := 0.0
var _dash_t := 0.0
var _dash_dir := Vector2.ZERO
var _hud: DynHud


func start() -> void:
	egg = CharacterBody2D.new()
	egg.collision_layer = 0
	egg.collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 12.0
	cs.shape = sh
	egg.add_child(cs)
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = load(FRAMES)
	_spr.scale = Vector2(1.5, 1.5)
	_spr.offset = Vector2(0, -14)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.play("walk")
	_spr.modulate = Color(1.5, 1.35, 0.7)
	egg.add_child(_spr)
	ActorFx.add_glow(egg, Color(1.0, 0.85, 0.35), 0.9, 0.7).position = Vector2(0, -14)
	var pl := player()
	var best := -1.0
	var spot := center()
	for sp in room.spawn_points:
		var d := (sp - pl.global_position).length() if pl != null else 0.0
		if d > best:
			best = d
			spot = sp - room.global_position
	var q := RoomUtil.free_spot(main, room, spot, 18.0, true, [])
	egg.position = q if q != Vector2.INF else spot
	room.props_node.add_child(egg)
	_hud = DynHud.make(self, tr("UTERO_OVULO_T"), Color("ffd75a"))
	toast(tr("UTERO_OVULO_T"), tr("UTERO_OVULO_D"), "ffd75a")
	say_intro("utero_ovulo")


func debug() -> String:
	return "ovulo t=%.1f finished=%s" % [_t, finished]


func _physics_process(delta: float) -> void:
	if not started or finished or egg == null or not is_instance_valid(egg):
		return
	var pl := player()
	if pl == null:
		return
	if main.current_room != room:
		return  # solo corre mientras estas en la sala
	_t += delta
	_hud.set_value(1.0 - _t / SECS, tr("UTERO_OVULO_BAR") % int(ceil(maxf(SECS - _t, 0.0))))
	if _t >= SECS:
		_vanish()
		return
	var away: Vector2 = egg.global_position - pl.global_position
	if away.length() < CATCH_DIST:
		_catch()
		return
	var dir := Vector2.ZERO
	var spd := SPEED
	_cool -= delta
	if away.length() < 340.0:
		if _dash_t <= 0.0 and away.length() < 95.0 and _cool <= 0.0 and egg.get_slide_collision_count() > 0:
			_dash_dir = (-away.normalized()).orthogonal() * (1.0 if randf() < 0.5 else -1.0)
			_dash_t = 0.3
			_cool = 1.3
		dir = _steer(away.normalized(), pl.global_position)
		if _dash_t > 0.0:
			_dash_t -= delta
			dir = _dash_dir
			spd = DASH
	egg.velocity = dir * spd
	egg.move_and_slide()
	if absf(dir.x) > 0.1:
		_spr.flip_h = dir.x < 0.0


func _steer(want: Vector2, from_player: Vector2) -> Vector2:
	var space := egg.get_world_2d().direct_space_state
	var best := want
	var best_score := -INF
	for i in STEPS:
		var dir := Vector2.RIGHT.rotated(TAU * i / STEPS)
		var q := PhysicsRayQueryParameters2D.create(egg.global_position, egg.global_position + dir * LOOK, 65)
		q.exclude = [egg.get_rid()]
		var hit := space.intersect_ray(q)
		var free_len := LOOK if hit.is_empty() else egg.global_position.distance_to(hit.position)
		var after := egg.global_position + dir * minf(free_len, 40.0)
		var score := after.distance_to(from_player) + free_len * 0.8
		if free_len < 30.0:
			score -= 200.0
		if score > best_score:
			best_score = score
			best = dir
	return best


func _catch() -> void:
	finished = true
	var at := egg.global_position
	Sound.play("puzzle_solve")
	RoomUtil.burst(room, at, Color(1.0, 0.85, 0.35), 24)
	RoomUtil.popup(at + Vector2(0, -50), tr("UTERO_OVULO_CAUGHT"), Color("ffd75a"))
	egg.queue_free()
	egg = null
	if _hud:
		_hud.queue_free()
	bonus(5 + 2 * RunManager.depth_i(rm().current_floor), 0.0, "health_large")
	get_node("/root/LoreDatabase").custom_event("utero_ovulo")
	room.set_meta("dyn_done", true)


func _vanish() -> void:
	finished = true
	RoomUtil.burst(room, egg.global_position, Color(1.0, 0.85, 0.35), 10)
	RoomUtil.popup(egg.global_position + Vector2(0, -50), tr("UTERO_OVULO_LOST"), Color("c9c2b0"))
	egg.queue_free()
	egg = null
	if _hud:
		_hud.queue_free()
	room.set_meta("dyn_done", true)


func _exit_tree() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
