extends RoomDynamic

## Escolta: llevar un OVULO hasta la TROMPA defendiendolo.
##
## El ovulo camina solo hacia la trompa mientras estes cerca (o no quede nadie que lo asuste);
## si un enemigo se le acerca se paraliza de miedo. Un tercio de los enemigos va a por el
## (se les cambia el objetivo) y los que disparan le disparan a el. Al llegar la mitad del
## camino entra una segunda oleada. Si lo rompen, la sala se limpia como un combate normal,
## pero sin la recompensa anunciada en la puerta. Si llega: botin extra y limpieza inmediata.
## Bot: pelea de siempre; con la sala vacia el ovulo camina solo.

const WALK := 80.0
const NEAR := 210.0         # el ovulo avanza si estas a menos de esto
const SCARE_DIST := 85.0
const GOAL_R := 26.0
const HIT_COOLDOWN := 0.7
const STEPS := 16
const LOOK := 56.0

var egg: CharacterBody2D
var spr: AnimatedSprite2D
var bar: Node2D
var goal := Vector2.ZERO
var start_pos := Vector2.ZERO
var total := 1.0
var hp := 100.0
var max_hp := 100.0
var scared := false
var _hud: DynHud
var _wave2 := false
var _hit_cd: Dictionary = {}
var _dir := Vector2.ZERO
var _dir_t := 0.0
var _retarget := 0.0
var _trompa: Node2D
var _t := 0.0
var _dead := false


func gate() -> bool:
	return finished


func start() -> void:
	if not _place():
		finished = true
		room.clear_gate = Callable()
		return
	max_hp = 70.0 + 22.0 * depth()
	hp = max_hp
	_build_egg()
	_build_trompa()
	_hud = DynHud.make(self, tr("RM_ESCORT_T"), Color("ff9ad0"))
	say_intro("rm_escort")
	toast(tr("RM_ESCORT_T"), tr("RM_ESCORT_D"), "ff9ad0")
	_retarget = 0.2


## Busca dos sitios libres con linea recta entre ellos (el ovulo sale cerca de donde entras; la trompa, lejos).
func _place() -> bool:
	var s := rsize()
	var pl := player()
	var from_local: Vector2 = pl.global_position - room.global_position if pl != null else center()
	var pts: Array[Vector2] = []
	var cols := 5
	var rows := 4
	for ix in cols:
		for iy in rows:
			var p := Vector2(lerpf(120.0, s.x - 120.0, ix / float(cols - 1)), lerpf(110.0, s.y - 110.0, iy / float(rows - 1)))
			var q := RoomUtil.free_spot(main, room, p, 16.0)
			if q != Vector2.INF and q.distance_to(p) < 1.0:
				pts.append(q)
	var min_len := minf(260.0, maxf(s.x, s.y) * 0.5)
	var best_score := -INF
	var found := false
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			for flip in [false, true]:
				var a: Vector2 = pts[j] if flip else pts[i]
				var b: Vector2 = pts[i] if flip else pts[j]
				var len := a.distance_to(b)
				if len < min_len:
					continue
				var perp := (b - a).orthogonal().normalized() * 13.0
				if not (RoomUtil.line_clear(main, room, a, b) and RoomUtil.line_clear(main, room, a + perp, b + perp) and RoomUtil.line_clear(main, room, a - perp, b - perp)):
					continue
				var score := len - a.distance_to(from_local) * 0.7  # el ovulo sale cerca de ti y la trompa queda lejos
				if score > best_score:
					best_score = score
					start_pos = a
					goal = b
					found = true
	total = start_pos.distance_to(goal)
	return found


func _build_egg() -> void:
	egg = CharacterBody2D.new()
	egg.collision_layer = 0
	egg.collision_mask = 1
	egg.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 11.0
	cs.shape = sh
	egg.add_child(cs)
	spr = AnimatedSprite2D.new()
	spr.sprite_frames = load("res://assets/sprites/enemies/ovulo_sprite_frames.tres")
	spr.play("idle")
	spr.offset = Vector2(0, -22)
	spr.scale = Vector2(0.9, 0.9)
	egg.add_child(spr)
	var hb := Area2D.new()
	hb.collision_layer = 0
	hb.collision_mask = 16  # proyectiles enemigos
	var hs := CollisionShape2D.new()
	var hsh := CircleShape2D.new()
	hsh.radius = 14.0
	hs.shape = hsh
	hs.position = Vector2(0, -14)
	hb.add_child(hs)
	hb.area_entered.connect(_on_area)
	egg.add_child(hb)
	bar = _Bar.new()
	bar.set("owner_dyn", self)
	bar.position = Vector2(0, -56)
	bar.z_index = 6
	bar.material = LightKit.unshaded_material()
	egg.add_child(bar)
	egg.position = start_pos
	egg.add_to_group("escort_egg")
	add_child.call_deferred(egg)
	ActorFx.setup_actor(egg, spr)
	ActorFx.add_glow(egg, Color(1.0, 0.8, 0.9), 0.8, 0.7)


func _build_trompa() -> void:
	_trompa = _Goal.new()
	_trompa.position = goal
	var t := AnimatedSprite2D.new()
	t.sprite_frames = load("res://assets/sprites/enemies/trompa_sprite_frames.tres")
	t.play("idle")
	t.offset = Vector2(0, -22)
	t.flip_h = goal.x < start_pos.x
	_trompa.add_child(t)
	var l := HudStyle.pixel_label(tr("RM_ESCORT_GOAL"), 8, Color("ffd0e8"))
	l.position = Vector2(-40, 8)
	l.size = Vector2(80, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.material = LightKit.unshaded_material()
	_trompa.add_child(l)
	_trompa.z_index = -1
	add_child(_trompa)
	ActorFx.add_glow(_trompa, Color(1.0, 0.7, 0.9), 0.7, 0.8)


func debug() -> String:
	return "egg=%s hp=%d goal=%s fin=%s wave2=%s" % [egg.position if egg else null, hp, goal, finished, _wave2]


func _on_area(a: Area2D) -> void:
	if _dead or finished or not a.is_in_group("enemy_attack") or not ("damage" in a):
		return
	if a.has_method("on_hit"):
		a.on_hit()
	hurt(float(a.damage) * 0.6)


func hurt(dmg: float) -> void:
	if _dead or finished:
		return
	hp -= dmg
	spr.modulate = Color(1.7, 0.6, 0.6)
	get_tree().create_timer(0.1).timeout.connect(func(): if is_instance_valid(spr): spr.modulate = Color.WHITE)
	Sound.play("hurt")
	RoomUtil.popup(egg.global_position + Vector2(0, -50), "-%d" % int(dmg), Color("ff6b9a"))
	if hp <= 0.0:
		_break_egg()


func _break_egg() -> void:
	_dead = true
	RoomUtil.burst(room, egg.global_position + Vector2(0, -14), Color("fff0b0"), 22)
	Sound.play("crack")
	finish(false)
	egg.visible = false
	room.reward = ""
	room.reward_kingdom = ""
	toast(tr("RM_ESCORT_FAIL_T"), tr("RM_ESCORT_FAIL"), "ff6b6b")
	say_when_calm("rm_escort_fail")
	if _hud:
		_hud.queue_free()
	if RoomUtil.alive(room).is_empty():
		clear_room()


func _physics_process(delta: float) -> void:
	if not started:
		return
	if finished or _dead or egg == null or not egg.is_inside_tree():
		return
	_t += delta
	var pl := player()
	var enemies := RoomUtil.alive(room)
	# objetivos: un tercio de los enemigos va a por el ovulo
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.6
		for i in enemies.size():
			var e = enemies[i]
			if e.get("target") != null and i % 3 == 0 and e.target != egg:
				e.target = egg
	# dano por contacto (los cuerpo a cuerpo que lo alcanzan)
	var nearest := INF
	for e in enemies:
		var d: float = e.global_position.distance_to(egg.global_position)
		nearest = minf(nearest, d)
		if d < 34.0:
			var id: int = e.get_instance_id()
			if float(_hit_cd.get(id, 0.0)) <= _t:
				_hit_cd[id] = _t + HIT_COOLDOWN
				hurt(float(e.get("damage")) * 0.5)
				if _dead:
					return
	scared = nearest < SCARE_DIST
	var near_player: bool = pl != null and pl.global_position.distance_to(egg.global_position) < NEAR
	var walk: bool = (not scared) and (enemies.is_empty() or near_player)
	if walk:
		_move(delta)
		spr.play("walk")
		spr.speed_scale = 1.0
	else:
		egg.velocity = Vector2.ZERO
		spr.play("idle")
		spr.offset.x = randf_range(-1.2, 1.2) if scared else 0.0
	# avance, segunda oleada, llegada
	var dist := egg.position.distance_to(goal)
	var prog := clampf(1.0 - dist / total, 0.0, 1.0)
	if _hud:
		_hud.set_value(hp / max_hp, tr("RM_ESCORT_BAR") % [int(prog * 100.0), int(maxf(hp, 0.0))])
	if not _wave2 and prog >= 0.5:
		_wave2 = true
		RoomUtil.spawn_wave(main, room, 2 + int(depth() / 2.0), true)
		toast(tr("RM_ESCORT_WAVE"), "", "ffa64a")
	if dist < GOAL_R:
		_arrive()


func _move(delta: float) -> void:
	_dir_t -= delta
	if _dir_t <= 0.0 or _dir == Vector2.ZERO:
		_dir_t = 0.25
		_dir = _best_dir()
	egg.velocity = _dir * WALK
	egg.move_and_slide()
	if _dir.x != 0.0:
		spr.flip_h = _dir.x < 0.0


func _best_dir() -> Vector2:
	var to_goal := (goal - egg.position).normalized()
	var space := egg.get_world_2d().direct_space_state
	var best := to_goal
	var best_score := -INF
	for i in STEPS:
		var dir := Vector2.RIGHT.rotated(TAU * i / STEPS)
		var q := PhysicsRayQueryParameters2D.create(egg.global_position, egg.global_position + dir * LOOK, 1)
		var hit := space.intersect_ray(q)
		var free_len := LOOK if hit.is_empty() else egg.global_position.distance_to(hit.position)
		if free_len < 24.0:
			continue
		var score := dir.dot(to_goal) * 1.0 + free_len / LOOK * 0.25
		if score > best_score:
			best_score = score
			best = dir
	return best


func _arrive() -> void:
	finish(true)
	_dead = true
	Sound.play("puzzle_solve")
	toast(tr("RM_ESCORT_OK_T"), tr("RM_ESCORT_OK"), "9be88a")
	say_when_calm("rm_escort_ok")
	RoomUtil.burst(room, egg.global_position + Vector2(0, -14), Color("ffe08a"), 24)
	var tw := egg.create_tween()
	tw.tween_property(spr, "scale", Vector2(0.1, 0.1), 0.5)
	tw.parallel().tween_property(egg, "modulate:a", 0.0, 0.5)
	if _hud:
		_hud.queue_free()
	bonus(5 + 2 * RunManager.depth_i(rm().current_floor), 0.5)
	clear_room()


## Barra de vida sobre el ovulo.
class _Bar extends Node2D:
	var owner_dyn

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if owner_dyn == null or not is_instance_valid(owner_dyn):
			return
		var f := clampf(owner_dyn.hp / owner_dyn.max_hp, 0.0, 1.0)
		draw_rect(Rect2(-16, 0, 32, 5), Color(0.05, 0.03, 0.06, 0.85))
		draw_rect(Rect2(-15, 1, 30.0 * f, 3), Color(1.0, 0.5, 0.7).lerp(Color(0.55, 0.95, 0.5), f))


## Trompa de destino: anillo que late.
class _Goal extends Node2D:
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var r := 30.0 + sin(_t * 3.0) * 3.0
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.82, 0.5, 0.75), 2.0)
		draw_arc(Vector2.ZERO, r - 8.0, 0.0, TAU, 32, Color(1.0, 0.82, 0.5, 0.3), 1.0)
