extends RoomDynamic

## Persecucion: una ladilla ladrona se te acerca, te roba monedas y HUYE. Matala y las
## recuperas (con intereses). Si nadie la alcanza en ESCAPE_SECS se va por la puerta mas
## cercana hacia otra sala de pelea y alli te espera (el cartel de esa puerta lo avisa); si
## escapa de esa segunda sala, las monedas se pierden para siempre.
## Sin monedas que robar, trae un botin propio (el premio se mantiene).
## No toca enemy*.gd: es un enemigo normal ("melee") con la IA apagada y este cerebro
## (como key_fugitive.gd).
## Bot: es un enemigo mas (grupo "enemy"): lo persigue y, si escapa, sigue con el piso.

const FLEE_SPEED := 236.0
const DASH_SPEED := 430.0
const APPROACH_SPEED := 175.0
const ESCAPE_FIRST := 40.0
const ESCAPE_FINAL := 30.0
const STEAL_DIST := 30.0
const STEPS := 16
const LOOK := 70.0

var thief: CharacterBody2D
var stolen := 0
var own_purse := false
var final_chase := false
var phase := "approach"   # approach | flee | leaving | gone
var _t := 0.0
var _flee_t := 0.0
var _dash_t := 0.0
var _dash_dir := Vector2.ZERO
var _cool := 0.0
var _hud: DynHud
var _exit: Door = null
var _bag: Sprite2D


func gate() -> bool:
	return true


func debug() -> String:
	return "thief phase=%s stolen=%d flee_t=%.1f alive=%s" % [phase, stolen, _flee_t, is_instance_valid(thief)]


func start() -> void:
	var meta: Dictionary = room.get_meta("dyn_thief_loot", {})
	if not meta.is_empty():
		final_chase = true
		stolen = int(meta.coins)
		own_purse = bool(meta.get("own", false))
		room.remove_meta("dyn_thief_loot")
	_spawn()
	_hud = DynHud.make(self, tr("RM_THIEF_T"), Color("ffd75a"))
	if final_chase:
		phase = "flee"
		_show_bag()
		toast(tr("RM_THIEF_AGAIN_T"), tr("RM_THIEF_AGAIN") % stolen, "ffd75a")
		say_intro("rm_thief_again")
	else:
		toast(tr("RM_THIEF_T"), tr("RM_THIEF_D"), "ffd75a")
		say_intro("rm_thief")
	get_node("/root/GlobalEvents").enemy_killed.connect(_on_killed)


func _spawn() -> void:
	var e: Enemy = EnemyRegistry.scene("melee").instantiate()
	e.personality = "none"
	e.enemy_name = tr("RM_THIEF_NAME")
	e.max_health = 18.0 + 9.0 * depth()
	e.damage = 0.0
	e.move_speed = FLEE_SPEED
	var frames := "res://assets/sprites/enemies/ladilla_sprite_frames.tres"
	e.get_node("AnimatedSprite2D").sprite_frames = load(frames)
	e.get_node("AnimatedSprite2D").scale *= 1.3
	thief = e
	room.enemies_spawned.append(e)
	var pl := player()
	var spot := center()
	var best := -1.0
	for sp in room.spawn_points:
		var d := (sp - pl.global_position).length() if pl != null else 0.0
		if d > best:
			best = d
			spot = sp - room.global_position
	room._add_enemy_deferred(e, room.global_position + spot)


func _show_bag() -> void:
	if _bag != null or thief == null:
		return
	_bag = Sprite2D.new()
	_bag.texture = load("res://assets/sprites/items/coin.png")
	_bag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bag.position = Vector2(0, -50)
	_bag.scale = Vector2(1.5, 1.5)
	_bag.z_index = 2
	thief.add_child(_bag)
	ActorFx.add_glow(_bag, Color(1.0, 0.85, 0.3), 0.7, 0.6)


func _physics_process(delta: float) -> void:
	if not started or finished:
		return
	if thief == null or not is_instance_valid(thief) or thief.is_queued_for_deletion() or thief.get("state") == Enemy.State.DEAD:
		return
	if not thief.is_inside_tree():
		return
	if thief.is_physics_processing():
		thief.set_physics_process(false)  # la sala los reactiva al entrar: el cerebro es este
	var pl := player()
	if pl == null:
		return
	_t += delta
	var dir := Vector2.ZERO
	var spd := FLEE_SPEED
	match phase:
		"approach":
			var to := pl.global_position - thief.global_position
			dir = to.normalized()
			spd = APPROACH_SPEED
			_hud.set_value(1.0, tr("RM_THIEF_APPROACH"))
			if to.length() < STEAL_DIST:
				_steal()
			elif _t > 14.0:
				_steal()  # que no se quede esperando
		"flee":
			_flee_t += delta
			var limit := ESCAPE_FINAL if final_chase else ESCAPE_FIRST
			_hud.set_value(1.0 - _flee_t / limit, tr("RM_THIEF_BAR") % [int(ceil(maxf(limit - _flee_t, 0.0))), stolen])
			if _flee_t >= limit:
				_start_leaving()
			dir = _flee_dir(pl, delta)
			if _dash_t > 0.0:
				_dash_t -= delta
				dir = _dash_dir
				spd = DASH_SPEED
		"leaving":
			var to_exit: Vector2 = _exit.global_position - thief.global_position
			if to_exit.length() < 46.0:
				_leave()
				return
			dir = _steer(to_exit.normalized(), true)
			spd = DASH_SPEED * 0.8
	thief.velocity = dir * spd
	thief.move_and_slide()
	thief._update_animation(dir)


func _steal() -> void:
	phase = "flee"
	var coins: int = rm().coins
	if coins >= 3:
		stolen = clampi(int(coins * 0.4), 3, coins)
		rm().add_coins(-stolen)
	else:
		stolen = 4 + 2 * RunManager.depth_i(rm().current_floor)
		own_purse = true
	_show_bag()
	Sound.play("poor")
	RoomUtil.popup(thief.global_position + Vector2(0, -60), ("-%d $" % stolen) if not own_purse else "$ $ $", RoomUtil.GOLD)
	if own_purse:
		toast(tr("RM_THIEF_OWN_T"), tr("RM_THIEF_OWN"), "ffd75a")
	else:
		toast(tr("RM_THIEF_STOLE_T"), tr("RM_THIEF_STOLE") % stolen, "ff6b6b")
	say_when_calm("rm_thief_stole")


## Huir: lejos del jugador, esquivando muros, con arranques cuando lo acorralan.
func _flee_dir(pl: Node2D, delta: float) -> Vector2:
	var away := thief.global_position - pl.global_position
	var d := away.length()
	_cool -= delta
	if d > 330.0:
		return Vector2.ZERO  # tranquila: espera a que te acerques
	if _dash_t <= 0.0 and d < 90.0 and _cool <= 0.0 and thief.get_slide_collision_count() > 0:
		_dash_dir = (-away.normalized()).orthogonal() * (1.0 if randf() < 0.5 else -1.0)
		_dash_t = 0.28
		_cool = 1.4
	return _steer(away.normalized(), false, pl.global_position)


func _steer(want: Vector2, toward: bool, from_player := Vector2.ZERO) -> Vector2:
	var space := thief.get_world_2d().direct_space_state
	var best := want
	var best_score := -INF
	for i in STEPS:
		var dir := Vector2.RIGHT.rotated(TAU * i / STEPS)
		var q := PhysicsRayQueryParameters2D.create(thief.global_position, thief.global_position + dir * LOOK, 65)
		q.exclude = [thief.get_rid()]
		var hit := space.intersect_ray(q)
		var free_len := LOOK if hit.is_empty() else thief.global_position.distance_to(hit.position)
		var score: float
		if toward:
			score = dir.dot(want) * 2.0 + free_len / LOOK
		else:
			var after := thief.global_position + dir * minf(free_len, 40.0)
			score = after.distance_to(from_player) + free_len * 0.8
		if free_len < 30.0:
			score -= 200.0
		if score > best_score:
			best_score = score
			best = dir
	return best


# ------------------------------------------------------------------ escapar / morir
func _start_leaving() -> void:
	var gen: DungeonGenerator = main.dungeon_generator
	var best: Door = null
	var best_d := INF
	var fallback: Door = null
	for door: Door in room.doors.values():
		var tr_: Room = gen.rooms.get(door.target_pos)
		if tr_ == null:
			continue
		var d := door.global_position.distance_to(thief.global_position)
		if d < best_d and not final_chase and tr_.room_type in RoomDirector.COMBATISH and not tr_.cleared and tr_ != main._hormone_room and not tr_.has_meta("dyn_thief_loot") and str(RoomDirector.of(get_tree()).plan.get(tr_.grid_pos, "")) in ["", "thief", "celo", "lubricado", "apagon", "censurada", "barriles", "antorchas", "trampas"]:
			best = door
			best_d = d
		if fallback == null or d < fallback.global_position.distance_to(thief.global_position):
			fallback = door
	_exit = best if best != null else fallback
	if _exit == null:
		_leave()
		return
	phase = "leaving"
	_hud.set_value(0.0, tr("RM_THIEF_RUNS"))


func _leave() -> void:
	var gen: DungeonGenerator = main.dungeon_generator
	var target: Room = gen.rooms.get(_exit.target_pos) if _exit != null else null
	RoomUtil.burst(room, thief.global_position, Color("ffd75a"), 14)
	room.enemies_spawned.erase(thief)
	var gone_pos := thief.global_position
	thief.queue_free()
	thief = null
	finished = true
	print("[salas] thief %s: escapa (monedas %d, vecina %s)" % [room.grid_pos, stolen, target.grid_pos if target != null else "-"])
	if _hud:
		_hud.queue_free()
	if target != null and not final_chase and target.room_type in RoomDirector.COMBATISH and not target.cleared:
		target.set_meta("dyn_thief_loot", {"coins": stolen, "own": own_purse})
		toast(tr("RM_THIEF_ESCAPED_T"), tr("RM_THIEF_ESCAPED_DOOR") % tr("RM_DIR_" + _exit.get_direction_name().to_upper()), "ffd75a")
		say_when_calm("rm_thief_escaped")
	else:
		toast(tr("RM_THIEF_LOST_T"), (tr("RM_THIEF_LOST") % stolen) if not own_purse else tr("RM_THIEF_LOST_OWN"), "ff6b6b")
		say_when_calm("rm_thief_lost")
	room.set_meta("dyn_done", true)
	# si era lo unico que quedaba, la sala ya se puede limpiar
	var left := RoomUtil.alive(room)
	if left.is_empty() and not room.cleared and gone_pos != Vector2.INF:
		room.room_cleared()


func _on_killed(e: Node, _killer: Node) -> void:
	if e != thief or finished:
		return
	finished = true
	print("[salas] thief %s: atrapada (monedas %d)" % [room.grid_pos, stolen])
	var at: Vector2 = e.global_position
	if not own_purse and stolen > 0:
		rm().add_coins(stolen)
		RoomUtil.popup(at + Vector2(0, -40), "+%d $" % stolen, RoomUtil.GOLD)
	var extra := 3 + RunManager.depth_i(rm().current_floor)
	RoomUtil.coins(main, room, extra, room.to_local(at))
	Sound.play("room_clear")
	toast(tr("RM_THIEF_CAUGHT_T"), (tr("RM_THIEF_CAUGHT") % stolen) if not own_purse else tr("RM_THIEF_CAUGHT_OWN"), "9be88a")
	say_when_calm("rm_thief_caught")
	if _hud:
		_hud.queue_free()
	room.set_meta("dyn_done", true)


func _exit_tree() -> void:
	var ge := get_node_or_null("/root/GlobalEvents")
	if ge != null and ge.enemy_killed.is_connected(_on_killed):
		ge.enemy_killed.disconnect(_on_killed)
