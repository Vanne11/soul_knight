extends Node

## Bot de pruebas: juega una partida completa (5 pisos) para ver si el juego es jugable.
## Uso: godot --path . res://tools/autoplay/autoplay.tscn  [-- --hero=pitocles --seed=123 --fast]
## Dinamicas de sala (src/rooms): --force-dyn=<escort|hold|thief|stealth|clock|challenge|celo|lubricado|
## aduanera|apagon|censurada|barriles|antorchas|trampas|pacto|ruleta|mercado> las fuerza en toda sala donde
## quepan; --no-god=1 juega sin modo dios (para medir los peligros de sala); --armed=1 empieza con pistola.
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
var _used := {}
var _thing_cur: Node = null
var _thing_t := 0.0  # instance_id -> true (interactuables ya usados)
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
var _hits_real := 0  # golpes que de verdad llegan (zonas de jefe incluidas, que no son Areas)
var _iframes_prev := 0.0
var _boss_t0 := -1.0
var _boss_hits0 := 0
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
	if _arg("--fast", "") != "" or "--fast" in OS.get_cmdline_user_args():
		Engine.time_scale = 1.6
	# La escena tools/autoplay solo lanza: el bot de verdad cuelga de la raiz (asi
	# sobrevive a los cambios de escena) y la escena pasa al menu principal.
	if get_tree().current_scene == self or get_parent() != get_tree().root:
		var bot := Node.new()
		bot.name = "AutoplayBot"
		bot.set_script(get_script())
		get_tree().root.add_child.call_deferred(bot)
		get_tree().change_scene_to_file.call_deferred("res://src/scenes/main_menu.tscn")
		set_physics_process(false)
		set_process(false)
		return
	DebugMenu.god_mode = _arg("--no-god=", "") == ""  # --no-god=1: sin modo dios (mide dificultad y peligros de sala)
	RoomDirector.force_kind = _arg("--force-dyn=", "")  # prueba: fuerza esa dinamica de sala en todas las salas donde quepa
	# para alargar los jefes y ver todos sus desafios: --boss-hp=1,1,12,12,12 (multiplicador por piso)
	EnemyBoss.test_hp_mults = Array(_arg("--boss-hp=", "1").split(",", false)).map(func(x): return float(x))
	_build_overlay()
	await _wait_s(2.5)
	# Menu principal: "Nueva partida", como lo haria una persona.
	_label.text = "BOT · menu: Nueva partida"
	var menu := get_tree().current_scene
	_say("Menu principal -> Nueva partida")
	menu.start_btn.pressed.emit()
	# Intro: leer cada lamina y seguir con una tecla hasta llegar a elegir heroe.
	await _wait_s(1.5)
	var intro := get_tree().current_scene
	var slides := 0
	while intro and is_instance_valid(intro) and not intro._select.visible:
		_label.text = "BOT · intro: lamina %d" % (slides + 1)
		await _wait_s(1.6)
		if intro._select.visible:
			break
		_tap_key(KEY_SPACE)  # termina de escribir
		await _wait_s(1.4)
		# ojo: con la eleccion ya visible, Espacio pulsaria el boton enfocado (Pitocles)
		if intro._select.visible:
			break
		_tap_key(KEY_SPACE)  # siguiente lamina
		slides += 1
		if slides > 20:
			_issue("La intro no llega a la eleccion de heroe")
			break
	_say("Intro vista (%d laminas) -> eleccion de heroe" % slides)
	_label.text = "BOT · eligiendo heroe: %s" % hero
	await _wait_s(2.5)
	var btn: Button = intro.find_child("Choose_" + hero, true, false)
	if btn == null:
		_issue("No encuentro el boton de elegir a " + hero)
		return
	btn.pressed.emit()
	_say("Heroe elegido: %s" % hero)
	# Partida
	while get_tree().get_first_node_in_group("main") == null:
		await get_tree().process_frame
	main = get_tree().get_first_node_in_group("main")
	await _wait_s(0.5)
	player = main.player
	if _arg("--armed=", "") != "":
		player.equip_weapon(get_node("/root/ItemDatabase").get_item("pistol_basic"))  # prueba: sin la busqueda inicial del arma
	_say("Partida nueva: semilla=%d" % get_node("/root/RunManager").current_seed)
	player.get_node("Hurtbox").area_entered.connect(func(a): if a.is_in_group("enemy_attack"): _hits += 1)


func _wait_s(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _tap_key(code: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	var u := e.duplicate()
	u.pressed = false
	Input.parse_input_event(u)


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
	if _done or player == null:
		return
	if main == null or not is_instance_valid(main):
		_finish(get_node("/root/RunManager").last_run_victory)
		return
	var ifr: float = float(player.get("_iframes"))
	if ifr > _iframes_prev + 0.3:
		_hits_real += 1
	_iframes_prev = ifr
	_release_all()
	var picker := get_tree().get_first_node_in_group("blessing_picker") as BlessingPicker
	if picker:
		_say("Eleccion de bendicion (cartas) -> carta 1")
		picker.bot_pick(0)
		return
	if Narrator._choice.visible:
		_say("Eleccion: \"%s\" -> opcion 1" % Narrator._choice_label.text.left(60))
		Narrator._pick_choice(0)
		return
	if get_tree().paused:
		_heartbeat_t -= delta
		if _heartbeat_t <= 0.0:
			_heartbeat_t = 10.0
			_say("  latido: juego en PAUSA (narrador/menu); prompt=%s eleccion=%s" % [Narrator.prompt_owner, Narrator._choice.visible])
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
	_use_slots(not enemies.is_empty(), delta)
	if not enemies.is_empty():
		_fight(enemies, delta)
	elif _unstick_t > 0.0:
		# Desatascar: si el jugador lleva 3 s sin moverse (encajado contra algo que la
		# rejilla del bot no ve) prueba una direccion al azar y un dash.
		player.aim_override = Vector2.ZERO
		_unstick_t -= delta
		_press_move(_unstick_dir)
		if _unstick_t < 1.0 and _dash_cd <= 0.0:
			Input.action_press("dash")
			_dash_cd = 1.0
	else:
		player.aim_override = Vector2.ZERO
		_explore(room)
	_watch_stuck(delta, room)
	_heartbeat_t -= delta
	if _heartbeat_t <= 0.0:
		_heartbeat_t = 10.0
		var en := _alive_enemies(room)
		_say("  latido: sala %s %s limpia=%s pos=%s enemigos=%d %s objetivo=%s arma=%s intox=%d pausa=%s" % [
			Room.RoomType.keys()[room.room_type], room.grid_pos, room.cleared, player.global_position - room.global_position,
			en.size(), en.map(func(e): return e.global_position - room.global_position).slice(0, 3), _goal_text,
			player.current_weapon != null, get_node("/root/PlayerStats").intoxication_tier, get_tree().paused])
	_label.text = "BOT · piso %d · %s · %s\n%s · golpes recibidos: %d" % [
		_floor_n, Room.RoomType.keys()[room.room_type], "limpia" if room.cleared else "sin limpiar",
		_goal_text, _hits]


var _slot_t := 0.0


## Ranuras 1-4: el bot cura con lo que lleve cuando le queda poca vida y se protege (toallas,
## calzoncillos...) al entrar en pelea. Asi tambien se prueba el uso real de las ranuras.
func _use_slots(fighting: bool, delta: float) -> void:
	_slot_t -= delta
	if _slot_t > 0.0:
		return
	var slots := ItemSlots.find(player)
	if slots == null:
		return
	var st := get_node("/root/PlayerStats")
	_slot_t = 1.5
	if st.current_health < st.max_health * 0.5 and slots.use_first_with_tag("curación"):
		_say("  usa una ranura: curacion")
	elif fighting and st.guard_hits <= 0 and slots.use_first_with_tag("defensa"):
		_say("  usa una ranura: defensa")


func _on_room(room: Room) -> void:
	_room = room
	_room_t = 0.0
	_visited[room.grid_pos] = true
	_path.clear()
	_path_goal = Vector2.INF
	_grid_t = 0.0
	if room.room_type == Room.RoomType.BOSS and not room.cleared:
		_boss_t0 = Time.get_ticks_msec() / 1000.0
		_boss_hits0 = _hits_real
		if not get_node("/root/GlobalEvents").enemy_killed.is_connected(_on_boss_killed):
			get_node("/root/GlobalEvents").enemy_killed.connect(_on_boss_killed)
	_say("Sala %s %s (%s)" % [Room.RoomType.keys()[room.room_type], room.grid_pos, "oscura" if room.is_dark else "clara"])


func _on_boss_killed(e: Node, _k: Node) -> void:
	if e.is_in_group("boss") and _boss_t0 >= 0.0:
		var secs := Time.get_ticks_msec() / 1000.0 - _boss_t0
		_say("JEFE %s derrotado en %.0f s (reloj real, --fast=1.6x), golpes recibidos en la pelea: %d" % [e.enemy_name, secs, _hits_real - _boss_hits0])
		_boss_t0 = -1.0


func _finish(victory: bool) -> void:
	_done = true
	_release_all()
	_say("FIN: %s. Pisos liberados: %s. Golpes recibidos: %d. Problemas: %d" % [
		"VICTORIA" if victory else "derrota", get_node("/root/RunManager").liberated, _hits, _issues.size()])
	for i in _issues:
		_say("  - " + i)
	_label.text = "BOT · FIN: %s · problemas: %d" % ["VICTORIA" if victory else "derrota", _issues.size()]
	if "--quit-on-end" in OS.get_cmdline_user_args():
		await _wait_s(12.0)  # que se vea la pantalla final
		get_tree().quit()


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
	for e in enemies:
		if e.get("_channeling") == true and player.current_weapon != null:
			_boss_challenge(e, delta)  # el jefe se esta curando: cumplir su desafio
			return
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
	# cuerpo a cuerpo (Chancleta): se pega al enemigo en vez de mantener la distancia de tirador
	var melee_reach := float(player.current_weapon.custom_data.get("reach", 0.0))
	var near := KEEP_NEAR if melee_reach <= 0.0 else melee_reach * 0.3
	var far := KEEP_FAR if melee_reach <= 0.0 else melee_reach * 0.75
	if dist < near:
		move -= dir
	elif dist > far or not _line_clear(pp, t.global_position):
		_steer_to(t.global_position)
		return
	_press_move(_avoid_walls(move.normalized()))
	_dodge()


## Desafio de canalizacion de un jefe. El jefe publica ayudas para el bot (bot_goal_pos: a donde
## ir; bot_aim_pos / bot_target_node: a donde disparar; bot_dash_vec: dash en esa direccion;
## bot_dash_now: dash ya). El bot dispara siempre y se mueve segun esas ayudas.
var _dash_pre := 0

func _boss_challenge(b: Node2D, _delta: float) -> void:
	_goal_text = "desafio del jefe"
	var pp := player.global_position
	var aim: Vector2 = b.global_position + Vector2(0, -50)
	var bt = b.get("bot_target_node")
	if bt != null and is_instance_valid(bt):
		aim = bt.global_position + Vector2(0, -40)
	var ap = b.get("bot_aim_pos")
	if ap != null:
		aim = ap
	player.aim_override = aim - pp
	Input.action_press("attack")
	var dv: Vector2 = b.get("bot_dash_vec")
	var goal = b.get("bot_goal_pos")
	if b.get("bot_dash_now") == true and _dash_cd <= 0.0:
		Input.action_press("dash")
		_dash_cd = 1.0
		return
	if dv != Vector2.ZERO and _dash_cd <= 0.0:
		_press_move(dv.normalized())
		_dash_pre += 1
		if _dash_pre >= 3:
			Input.action_press("dash")
			_dash_cd = 1.0
			_dash_pre = 0
		return
	_dash_pre = 0
	if goal != null:
		var g: Vector2 = goal
		if pp.distance_to(g) > 14.0:
			_press_move(_avoid_walls((g - pp).normalized()))
		return
	# sin destino: distancia comoda al jefe con vaiven lateral
	var to_b := aim - pp
	var d := to_b.length()
	var dir := to_b.normalized()
	var mv := dir.orthogonal() * _strafe * 0.7
	if d < KEEP_NEAR:
		mv -= dir
	elif d > KEEP_FAR:
		mv += dir
	_press_move(_avoid_walls(mv.normalized()))


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
	if room.room_type == Room.RoomType.PUZZLE and room.has_meta("puzzle") and _solve_puzzle(room.get_meta("puzzle")):
		return
	if _quest_step(room):
		return
	# 1) cosas para recoger o usar en esta sala
	var target := _next_thing(room)
	if target and target != _thing_cur:
		_thing_cur = target
		_thing_t = 0.0
	if target:
		_thing_t += get_physics_process_delta_time()
		if _thing_t > 12.0:
			_used[target.get_instance_id()] = true
			_issue("No se alcanza %s en sala %s (pos relativa %s)" % [_thing_name(target), Room.RoomType.keys()[room.room_type], target.global_position - room.global_position])
			return
		_goal_text = "recoger/usar: %s" % _thing_name(target)
		var tp: Vector2 = target.global_position
		if player.global_position.distance_to(tp) < 26.0:
			if _interact_t <= 0.0:
				Input.action_press("interact")
				_interact_t = 0.35
				if target.get_script().resource_path.ends_with("interactable.gd"):
					_used[target.get_instance_id()] = true  # inscripcion, fuente, escotilla: una vez
				var n := int(target.get_meta("bot_tries", 0)) + 1
				target.set_meta("bot_tries", n)
				if n > 6:
					_used[target.get_instance_id()] = true
					_issue("No se pudo usar/recoger %s en sala %s" % [_thing_name(target), Room.RoomType.keys()[room.room_type]])
		# hasta quedar encima: a 26 px el cuerpo todavia no toca el area del objeto
		if player.global_position.distance_to(tp) > 4.0:
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


## Acertijos de sala (src/puzzles/): cada Puzzle sabe resolverse y publica bot_step(pos)
## -> {"go": punto global, "interact": bool}. Aqui solo se camina hacia ese punto (recto: en
## las salas de acertijo no hay obstaculos) y se pulsa E si lo pide.
func _solve_puzzle(pz: Node2D) -> bool:
	if not pz.has_method("bot_step"):
		return false
	if pz.get("done"):
		if not pz.has_meta("bot_logged"):
			pz.set_meta("bot_logged", true)
			_say("Acertijo %s resuelto (fallos: %d, reino %s)" % [pz.get("kind"), pz.get("fails"), pz.get("kingdom")])
		return false
	if not pz.has_meta("bot_seen"):
		pz.set_meta("bot_seen", true)
		_say("Acertijo %s: a resolverlo (reino %s, profundidad %d)" % [pz.get("kind"), pz.get("kingdom"), pz.get("depth")])
	var st: Dictionary = pz.bot_step(player.global_position)
	if st.is_empty():
		_goal_text = "acertijo %s: esperando" % pz.get("kind")
		return true  # mirando el acertijo (secuencia que suena, estatua que se desmorona...)
	_goal_text = "acertijo %s" % pz.get("kind")
	var d: Vector2 = st.go - player.global_position
	if d.length() > 3.0:
		_press_move(d.normalized())
	if st.interact and _interact_t <= 0.0:
		Input.action_press("interact")
		_interact_t = 0.35
	return true


## Misiones de llave (src/items/key_quests.gd): el bot las hace igual que un jugador. Con
## enemigos vivos pelea (custodios, ladron que huye); aqui solo lo demas. Devuelve true si
## se ocupo de la sala este fotograma. `_quest_room` empuja a _next_room hacia otra sala.
var _quest_room: Room = null
var _kq_state := ""

func _quest_step(room: Room) -> bool:
	_quest_room = null
	var kq = main.get_node_or_null("KeyQuests")
	if kq == null or not kq.ready_ok or player.current_weapon == null:
		return false  # sin arma no hay custodios que valgan: primero el arma
	if kq.state != _kq_state:
		_kq_state = kq.state
		_say("Mision de llave %s: %s (llave en %s, cofre en %s)" % [kq.kind, kq.state, kq.home.grid_pos, kq.vault.grid_pos])
	var g: Dictionary = kq.bot_goal(room)
	if g.is_empty():
		return false
	if g.has("room"):
		_quest_room = g.room
		return false  # _next_room elige el camino
	_goal_text = "llave %s (%s)" % [kq.kind, kq.state]
	var d: Vector2 = g.go - player.global_position
	if d.length() > 4.0:
		_steer_to(g.go)
	if g.interact and d.length() < 28.0 and _interact_t <= 0.0:
		Input.action_press("interact")
		_interact_t = 0.35
	return true


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
	var generic := []
	var rm := get_node("/root/RunManager")
	var missing: Array = main._missing_hormones()
	for c in room.pickups_node.get_children() + room.props_node.get_children() + room.get_children():
		if not (c is Node2D) or not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		if c.get_script() == null:
			continue
		var path: String = c.get_script().resource_path
		if path.ends_with("item_pickup.gd"):
			# Con arma ya en la mano no recoge otra: el juego suelta la vieja al cambiarla
			# y el bot se quedaba intercambiandolas sin fin.
			var it = c.get("_item")
			if it != null and it.equip_slot == Item.EquipSlot.WEAPON and player.current_weapon != null:
				continue
			if it != null and "maldito" in it.tags:
				continue  # la jaula maldita no deja pasar hormonas: el bot no la coge
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
			generic.append(c)
	out = out.filter(func(n): return n.get_parent() != null and not _used.has(n.get_instance_id()))
	if out.is_empty():
		out = generic  # inscripciones, fuente y la escotilla al piso siguiente: al final
	return out


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
	if _quest_room != null and _quest_room != room and _quest_room.grid_pos in order:
		goal = _quest_room.grid_pos  # mision de llave: ir a la sala de la llave / del cofre
	# Sin arma: primero la sala del cofre con el arma (el juego la esconde lejos).
	var wr = main.get("_weapon_room")
	if goal == null and player.current_weapon == null and wr != null and is_instance_valid(wr) and wr.grid_pos in order and wr.grid_pos != room.grid_pos:
		goal = wr.grid_pos
	for pos in order:
		if goal != null:
			break
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
	if goal == room.grid_pos:
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
	q.collision_mask = 65  # muros + huecos
	q.exclude = [player.get_rid()]
	var w := int(rect.size.x * 64 / CELL)
	var h := int(rect.size.y * 64 / CELL)
	for x in w:
		for y in h:
			var p := origin + Vector2(x + 0.5, y + 0.5) * CELL
			q.transform = Transform2D(0, p)
			if space.intersect_shape(q, 1).is_empty():
				_grid[Vector2i(x, y)] = true
	_avoid_hazards(room)


## Peligros de las dinamicas de sala (RoomUtil.hazard_zones, grupo "rooms_hazard"): pinchos, cera, fuego de
## antorchas... Sus zonas (hazard_zones(): [{c: centro global, r: radio}]) salen de la rejilla
## para que el bot las rodee; el viento de los ventiladores no mata, se ignora. La rejilla se
## rehace cada 0,4 s mientras haya peligros (los fuegos y charcos aparecen y se van).
func _avoid_hazards(room: Room) -> void:
	var any := false
	for z in RoomUtil.hazard_zones(get_tree()):
		if not Rect2(room.global_position, RoomUtil.size_of(room)).has_point(z.c):
			continue
		any = true
		var c: Vector2 = z.c
		var r: float = z.r
		var c0 := _cell(c)
		var span := int(r / CELL) + 1
		for dx in range(-span, span + 1):
			for dy in range(-span, span + 1):
				var k := c0 + Vector2i(dx, dy)
				if _center(k).distance_to(c) <= r:
					_grid.erase(k)
	if any:
		_grid_t = 0.4


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
	for a in ["move_left", "move_right", "move_up", "move_down", "attack", "dash"]:
		if Input.is_action_pressed(a):
			Input.action_release(a)


var _interact_frames := 0
var _heartbeat_t := 10.0

## E se suelta en el bucle de dibujo (no en el de fisica): asi el juego alcanza a leerla.
func _process(_delta: float) -> void:
	if Input.is_action_pressed("interact"):
		_interact_frames += 1
		if _interact_frames > 2:
			Input.action_release("interact")
			_interact_frames = 0


var _unstick_t := 0.0
var _unstick_dir := Vector2.RIGHT
var _unstick_n := 0

func _watch_stuck(delta: float, room: Room) -> void:
	if player.global_position.distance_to(_last_pos) > 2.0:
		_last_pos = player.global_position
		_still_t = 0.0
		if _unstick_t <= 0.0:
			_unstick_n = 0
		return
	_still_t += delta
	if _still_t > 3.0 and _unstick_t <= 0.0 and _unstick_n < 8 and _alive_enemies(room).is_empty():
		_unstick_n += 1
		_unstick_t = 1.6
		_unstick_dir = Vector2.RIGHT.rotated(randf() * TAU)
		_still_t = 0.0
		_path.clear()
	if _still_t > 6.0 and _alive_enemies(room).is_empty():
		_issue("El bot quedo quieto 6 s en %s %s (objetivo: %s)" % [Room.RoomType.keys()[room.room_type], room.grid_pos, _goal_text])
		_say("  jugador: dash=%s sneeze_push=%s allergy=%s time_scale=%s paused=%s fisica=%s proceso=%s modo=%s iframes=%s capa=%s mascara=%s" % [
			player.get("is_dashing"), player.get("_sneeze_push"), player.get("_allergy"), Engine.time_scale, get_tree().paused,
			player.is_physics_processing(), player.is_processing(), player.process_mode, player.get("_iframes"),
			player.collision_layer, player.collision_mask])
		_say("  depuracion: pos=%s vel=%s celda_libre=%s ruta=%s goal=%s celdas=%d input=(%s,%s,%s,%s) choice=%s pausa=%s" % [
			player.global_position - room.global_position, player.velocity, _grid.has(_cell(player.global_position)),
			_path.slice(0, 3).map(func(v): return v - room.global_position), _path_goal - room.global_position, _grid.size(),
			Input.get_action_strength("move_left"), Input.get_action_strength("move_right"),
			Input.get_action_strength("move_up"), Input.get_action_strength("move_down"),
			Narrator._choice.visible, get_tree().paused])
		_still_t = -STUCK_S
		_path.clear()
	if _room_t > 120.0 and not room.cleared and room.room_type not in [Room.RoomType.PUZZLE, Room.RoomType.START, Room.RoomType.SHOP]:
		_issue("Sala %s %s sin limpiar tras 2 min" % [Room.RoomType.keys()[room.room_type], room.grid_pos])
		_room_t = -1e9
