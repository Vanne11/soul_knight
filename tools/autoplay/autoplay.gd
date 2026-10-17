extends Node

## Bot de pruebas: juega una partida completa (5 pisos) para ver si el juego es jugable.
## Uso: godot --path . res://tools/autoplay/autoplay.tscn  [-- --hero=pitocles --seed=123 --fast]
## Se mueve con las acciones reales (move_*, attack, dash, interact), apunta con
## Player.aim_override, navega cada sala con una grilla sobre las colisiones reales y
## recorre el piso sala por sala hasta el jefe. Lo que lo traba queda en el registro
## (.claude/autoplay.log) como posible problema de jugabilidad. Modo dios activo: el
## objetivo es recorrer el juego, no medir la dificultad (se cuentan los golpes recibidos).

const LOG_PATH := "res://.claude/autoplay.log"
const CELL := 16.0
const BODY_R := 11.0
const KEEP_NEAR := 130.0
const KEEP_FAR := 230.0
const STUCK_S := 25.0
const FLOOR_LIMIT_S := 600.0

var main: Node
var player: CharacterBody2D
var _log: FileAccess
var _label: Label
var _room: Room
var _room_t := 0.0
var _floor_t := 0.0
var _visited := {}
var _used := {}  # instance_id -> true (interactuables ya usados)
var _grid := {}  # Vector2i -> true si se puede pisar
var _grid_t := 0.0
var _path: Array[Vector2] = []
var _path_goal := Vector2.INF
var _path_t := 0.0
var _goal_text := ""
var _last_pos := Vector2.ZERO
var _still_t := 0.0
var _interact_t := 0.0
var _dash_cd := 0.0
var _strafe := 1.0
var _strafe_t := 0.0
var _hits := 0
var _done := false
var _floor_n := 0
var _issues: Array[String] = []
var _t0 := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	_t0 = Time.get_ticks_msec() / 1000.0
	var hero := _arg("--hero=", "vulvalquiria")
	var seed_v := int(_arg("--seed=", "0"))
	if _arg("--fast", "") != "" or "--fast" in OS.get_cmdline_user_args():
		Engine.time_scale = 1.6
	DebugMenu.god_mode = true
	var rm := get_node("/root/RunManager")
	rm.character = hero
	rm.start_new_run(seed_v) if seed_v != 0 else rm.start_new_run()
	_say("Partida nueva: heroe=%s semilla=%d" % [hero, rm.current_seed])
	main = load("res://src/scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	_build_overlay()
	await get_tree().process_frame
	await get_tree().process_frame
	player = main.player
	get_node("/root/PlayerStats").health_changed.connect(func(_c, _m): pass)
	player.get_node("Hurtbox").area_entered.connect(func(a): if a.is_in_group("enemy_attack"): _hits += 1)


func _arg(prefix: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return def


func _say(msg: String) -> void:
	var t := Time.get_ticks_msec() / 1000.0 - _t0
	var line := "[%6.1fs] %s" % [t, msg]
	print("[bot] ", line)
	if _log:
		_log.store_line(line)
		_log.flush()


func _issue(msg: String) -> void:
	if msg in _issues:
		return
	_issues.append(msg)
	_say("PROBLEMA: " + msg)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12, 600)
	_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_font_size_override("font_size", 14)
	layer.add_child(_label)


# ------------------------------------------------------------------ bucle
func _physics_process(delta: float) -> void:
	if _done or main == null or not is_instance_valid(main) or player == null:
		return
	_release_all()
	if Narrator._choice.visible:
		_say("Eleccion: \"%s\" -> opcion 1" % Narrator._choice_label.text.left(60))
		Narrator._pick_choice(0)
		return
	if get_tree().paused:
		return
	var rm := get_node("/root/RunManager")
	if not rm.run_active:
		_finish(rm.last_run_victory)
		return
	if rm.current_floor != _floor_n:
		_floor_n = rm.current_floor
		_floor_t = 0.0
		_visited.clear()
		_say("=== PISO %d: %s ===" % [_floor_n, rm.floor_data().name])
	_floor_t += delta
	if _floor_t > FLOOR_LIMIT_S:
		_issue("Piso %d sin terminar tras %d s" % [_floor_n, FLOOR_LIMIT_S])
		_floor_t = -1e9
	var room: Room = main.current_room
	if room == null:
		return
	if room != _room:
		_on_room(room)
	_room_t += delta
	_dash_cd -= delta
	_interact_t -= delta
	_grid_t -= delta
	if _grid_t <= 0.0:
		_build_grid(room)
	var enemies := _alive_enemies(room)
	if not enemies.is_empty():
		_fight(enemies, delta)
	else:
		player.aim_override = Vector2.ZERO
		_explore(room)
	_watch_stuck(delta, room)
	_label.text = "BOT · piso %d · %s · %s\n%s · golpes recibidos: %d" % [
		_floor_n, Room.RoomType.keys()[room.room_type], "limpia" if room.cleared else "sin limpiar",
		_goal_text, _hits]


func _on_room(room: Room) -> void:
	_room = room
	_room_t = 0.0
	_visited[room.grid_pos] = true
	_path.clear()
	_path_goal = Vector2.INF
	_grid_t = 0.0
	_say("Sala %s %s (%s)" % [Room.RoomType.keys()[room.room_type], room.grid_pos, "oscura" if room.is_dark else "clara"])


func _finish(victory: bool) -> void:
	_done = true
	_release_all()
	_say("FIN: %s. Pisos liberados: %s. Golpes recibidos: %d. Problemas: %d" % [
		"VICTORIA" if victory else "derrota", get_node("/root/RunManager").liberated, _hits, _issues.size()])
	for i in _issues:
		_say("  - " + i)
	_label.text = "BOT · FIN: %s · problemas: %d" % ["VICTORIA" if victory else "derrota", _issues.size()]


# ------------------------------------------------------------------ pelea
func _alive_enemies(room: Room) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e is Node2D and e.is_visible_in_tree() and room.is_ancestor_of(e):
			if e.get("current_health") == null or e.current_health > 0.0:
				out.append(e)
	return out


func _fight(enemies: Array, delta: float) -> void:
	var pp := player.global_position
	enemies.sort_custom(func(a, b): return a.global_position.distance_to(pp) < b.global_position.distance_to(pp))
	var t: Node2D = enemies[0]
	var to_t := t.global_position - pp
	var dist := to_t.length()
	_goal_text = "pelea contra %s (%d vivos)" % [t.get("enemy_name") if t.get("enemy_name") else t.name, enemies.size()]
	if player.current_weapon == null:
		_goal_text = "sin arma: huye a buscar una"
		player.aim_override = Vector2.ZERO
		_explore(main.current_room)
		return
	player.aim_override = to_t
	if _line_clear(pp, t.global_position):
		Input.action_press("attack")
	# distancia comoda + vaiven lateral
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe = -_strafe
		_strafe_t = randf_range(0.8, 1.6)
	var dir := to_t.normalized()
	var move := dir.orthogonal() * _strafe * 0.8
	if dist < KEEP_NEAR:
		move -= dir
	elif dist > KEEP_FAR or not _line_clear(pp, t.global_position):
		_steer_to(t.global_position)
		return
	_press_move(_avoid_walls(move.normalized()))
	_dodge()


func _dodge() -> void:
	if _dash_cd > 0.0:
		return
	for b in get_tree().get_nodes_in_group("enemy_attack"):
		if not (b is Node2D) or not is_instance_valid(b):
			continue
		var rel: Vector2 = player.global_position - b.global_position
		if rel.length() < 70.0:
			var vel := Vector2.RIGHT.rotated(b.global_rotation)
			if vel.dot(rel.normalized()) > 0.6:
				var side := vel.orthogonal()
				_press_move(_avoid_walls(side))
				Input.action_press("dash")
				_dash_cd = 1.2
				return


func _line_clear(a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	q.exclude = [player.get_rid()]
	return player.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


# ------------------------------------------------------------------ explorar
func _explore(room: Room) -> void:
	# 1) cosas para recoger o usar en esta sala
	var target := _next_thing(room)
	if target:
		_goal_text = "recoger/usar: %s" % _thing_name(target)
		var tp: Vector2 = target.global_position
		if player.global_position.distance_to(tp) < 26.0:
			if _interact_t <= 0.0:
				Input.action_press("interact")
				_interact_t = 0.35
				var n := int(target.get_meta("bot_tries", 0)) + 1
				target.set_meta("bot_tries", n)
				if n > 6:
					_used[target.get_instance_id()] = true
					_issue("No se pudo usar/recoger %s en sala %s" % [_thing_name(target), Room.RoomType.keys()[room.room_type]])
		else:
			_steer_to(tp)
		return
	# 2) siguiente sala
	var next := _next_room(room)
	if next == null:
		_goal_text = "sin destino"
		return
	var door: Door = room.door_to(next.grid_pos)
	if door == null:
		_goal_text = "sin puerta hacia %s" % next.grid_pos
		return
	_goal_text = "ir a %s %s" % [Room.RoomType.keys()[next.room_type], next.grid_pos]
	var dp := door.global_position
	if player.global_position.distance_to(dp) < 70.0:
		_press_move((dp - player.global_position).normalized())
	else:
		_steer_to(dp)


func _thing_name(n: Node) -> String:
	if n.get("item_id"):
		return str(n.item_id)
	if n.get("prompt_text"):
		return str(n.prompt_text).left(30)
	return n.name


func _next_thing(room: Room) -> Node2D:
	var best: Node2D = null
	var bd := INF
	var pp := player.global_position
	for n in _things(room):
		if _used.has(n.get_instance_id()):
			continue
		var d: float = n.global_position.distance_to(pp)
		if d < bd:
			bd = d
			best = n
	return best


func _things(room: Room) -> Array:
	var out := []
	var rm := get_node("/root/RunManager")
	var missing: Array = main._missing_hormones()
	for c in room.pickups_node.get_children() + room.props_node.get_children() + room.get_children():
		if not (c is Node2D) or not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		if c.get_script() == null:
			continue
		var path: String = c.get_script().resource_path
		if path.ends_with("item_pickup.gd"):
			out.append(c)
		elif path.ends_with("chest.gd") and not c.get("_opened"):
			out.append(c)
		elif path.ends_with("shop_item.gd"):
			# solo lo que hace falta para pasar la Puerta Hormonal (o un arma si no hay)
			var it = c.get("_item")
			if it == null or c.get("price") == null or rm.coins < c.price:
				continue
			var h: String = str(it.custom_data.get("hormone", ""))
			if (h != "" and h in missing) or (player.current_weapon == null and it.type == 0):
				out.append(c)
		elif path.ends_with("interactable.gd"):
			# escotilla al piso siguiente: solo cuando ya no queda nada mas
			out.append(c)
	return out.filter(func(n): return n.get_parent() != null)


## Plan de piso: la sala sin visitar mas cercana (por el grafo); despues el jefe.
func _next_room(room: Room) -> Room:
	var gen = main.dungeon_generator
	var rooms: Dictionary = gen.rooms
	var graph: Dictionary = gen.room_graph
	var can_boss: bool = main._has_real_weapon() and main._missing_hormones().is_empty()
	# BFS
	var prev := {room.grid_pos: null}
	var queue := [room.grid_pos]
	var order := []
	while not queue.is_empty():
		var cur = queue.pop_front()
		order.append(cur)
		var cr: Room = rooms[cur]
		for nb in graph.get(cur, []):
			if prev.has(nb):
				continue
			var d: Door = cr.door_to(nb)
			if d == null or d.state == Door.State.LOCKED:
				continue
			var nr: Room = rooms[nb]
			if nr.room_type == Room.RoomType.BOSS and not can_boss:
				continue
			prev[nb] = cur
			queue.append(nb)
	var goal = null
	for pos in order:
		var r: Room = rooms[pos]
		if pos != room.grid_pos and not _visited.has(pos) and r.room_type != Room.RoomType.BOSS:
			goal = pos
			break
	if goal == null:
		for pos in order:
			if rooms[pos].room_type == Room.RoomType.BOSS:
				goal = pos
				break
	if goal == null:
		if not can_boss:
			_issue("Piso %d: todo explorado y no se puede entrar al jefe (arma=%s, faltan hormonas=%s)" % [
				_floor_n, main._has_real_weapon(), main._missing_hormones()])
		return null
	var step = goal
	while prev[step] != room.grid_pos:
		step = prev[step]
	return rooms[step]


# ------------------------------------------------------------------ navegacion
func _build_grid(room: Room) -> void:
	_grid_t = 2.0
	_grid.clear()
	var rect := room.floor_tilemap.get_used_rect()
	var origin := room.global_position
	var space := player.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = BODY_R
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	var w := int(rect.size.x * 64 / CELL)
	var h := int(rect.size.y * 64 / CELL)
	for x in w:
		for y in h:
			var p := origin + Vector2(x + 0.5, y + 0.5) * CELL
			q.transform = Transform2D(0, p)
			if space.intersect_shape(q, 1).is_empty():
				_grid[Vector2i(x, y)] = true


func _cell(p: Vector2) -> Vector2i:
	var o: Vector2 = main.current_room.global_position
	return Vector2i(floor((p.x - o.x) / CELL), floor((p.y - o.y) / CELL))


func _center(c: Vector2i) -> Vector2:
	return main.current_room.global_position + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func _nearest_free(c: Vector2i) -> Vector2i:
	if _grid.has(c):
		return c
	for r in range(1, 12):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var k := c + Vector2i(dx, dy)
				if _grid.has(k):
					return k
	return c


func _steer_to(goal: Vector2) -> void:
	_path_t -= get_physics_process_delta_time()
	if _path.is_empty() or _path_goal.distance_to(goal) > 24.0 or _path_t <= 0.0:
		_path = _find_path(player.global_position, goal)
		_path_goal = goal
		_path_t = 0.5
	while _path.size() > 1 and player.global_position.distance_to(_path[0]) < 10.0:
		_path.pop_front()
	var wp: Vector2 = _path[0] if not _path.is_empty() else goal
	_press_move((wp - player.global_position).normalized())


func _find_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var a := _nearest_free(_cell(from))
	var b := _nearest_free(_cell(to))
	var prev := {a: a}
	var queue := [a]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == b:
			break
		for d in dirs:
			var n: Vector2i = c + d
			if prev.has(n) or not _grid.has(n):
				continue
			if d.x != 0 and d.y != 0 and not (_grid.has(c + Vector2i(d.x, 0)) and _grid.has(c + Vector2i(0, d.y))):
				continue
			prev[n] = c
			queue.append(n)
	var out: Array[Vector2] = []
	if not prev.has(b):
		out.append(to)
		return out
	var k := b
	while k != a:
		out.push_front(_center(k))
		k = prev[k]
	out.append(to)
	return out


func _avoid_walls(dir: Vector2) -> Vector2:
	var p := player.global_position + dir * 24.0
	if _grid.has(_cell(p)):
		return dir
	for ang in [0.6, -0.6, 1.2, -1.2, PI]:
		var d := dir.rotated(ang)
		if _grid.has(_cell(player.global_position + d * 24.0)):
			return d
	return dir


# ------------------------------------------------------------------ entrada
func _press_move(dir: Vector2) -> void:
	if dir.x > 0.15:
		Input.action_press("move_right", minf(1.0, dir.x * 1.4))
	elif dir.x < -0.15:
		Input.action_press("move_left", minf(1.0, -dir.x * 1.4))
	if dir.y > 0.15:
		Input.action_press("move_down", minf(1.0, dir.y * 1.4))
	elif dir.y < -0.15:
		Input.action_press("move_up", minf(1.0, -dir.y * 1.4))


func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "attack", "dash", "interact"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


func _watch_stuck(delta: float, room: Room) -> void:
	if player.global_position.distance_to(_last_pos) > 2.0:
		_last_pos = player.global_position
		_still_t = 0.0
		return
	_still_t += delta
	if _still_t > 6.0 and _alive_enemies(room).is_empty():
		_issue("El bot quedo quieto 6 s en %s %s (objetivo: %s)" % [Room.RoomType.keys()[room.room_type], room.grid_pos, _goal_text])
		_still_t = -STUCK_S
		_path.clear()
	if _room_t > 120.0 and not room.cleared and room.room_type not in [Room.RoomType.PUZZLE, Room.RoomType.START, Room.RoomType.SHOP]:
		_issue("Sala %s %s sin limpiar tras 2 min" % [Room.RoomType.keys()[room.room_type], room.grid_pos])
		_room_t = -1e9
