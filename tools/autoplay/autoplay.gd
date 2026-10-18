extends Node

## Bot de pruebas: juega una partida completa (11 pisos, 12 con El Utero) para ver si el juego es jugable.
## Uso: godot --path . res://tools/autoplay/autoplay.tscn  [-- --hero=pitocles --seed=123 --fast --floor=9]
##   --hero=pitocles|vulvalquiria|ornitorrinco   --seed=N (fija la semilla; RunManager.test_seed)
##   --fast / --fast=2.5   Engine.time_scale (1.6x por defecto). OJO: HitFx lo devuelve a 1.0 en cada golpe, casi no acelera.
##       Para correr una partida entera en minutos (headless): godot --headless --audio-driver Dummy --fixed-fps 60 ...
##       (sin esperar al reloj: unas 10 veces mas rapido que el tiempo real; los tiempos del registro son de JUEGO).
##   --collect=all   modo "recoger todo" (para el video final): recorre TODAS las salas, abre todos los cofres
##       (tambien los de llave y los secretos: acertijos y misiones de llave), recoge objetos y monedas, compra en la
##       tienda lo que pueda (primero el Turno de Vulvania para entrar al Utero), toma bendiciones y solo despues va
##       al jefe. Al final de cada piso y de la partida registra un RESUMEN (objetos, cofres, salas, codice).
##   --log=<ruta>   registro propio (varias partidas en paralelo; por defecto .claude/autoplay.log)
##   --overlay=0    oculta el rotulo verde del bot (para grabar)
##   --max-secs=N   termina solo tras N s de juego (tiempo de juego, no de reloj; para grabaciones de prueba)
##   --quit-on-end  cierra Godot al terminar la partida
## VARIAS PARTIDAS A LA VEZ: el juego guarda progreso, codice y narrador en user://; aislalas con
##   XDG_DATA_HOME=<carpeta> godot ...  (asi no hace falta respaldar ~/.local/share/godot/app_userdata/).
##
## GRABAR EL VIDEO FINAL (ventana en la pantalla del notebook, sin sonido, tiempo real a 30 fps, SIN --fast:
## el movie maker fija el paso de tiempo, asi que el video sale a velocidad normal, no acelerado).
## Formato .ogv (Theora, ~0,65 MB/s: una hora ~2,3 GB). NO usar .avi (MJPEG, ~3,5 MB/s) ni escribir en /tmp (tmpfs chico):
##   mkdir -p /home/nick/Escritorio/Proyectos/soul_knight/.claude/video
##   XDG_DATA_HOME=/home/nick/rr_video_userdata godot --audio-driver Dummy --screen 2 --path . \
##     --write-movie /home/nick/Escritorio/Proyectos/soul_knight/.claude/video/partida.ogv --fixed-fps 30 \
##     res://tools/autoplay/autoplay.tscn -- --hero=pitocles --seed=21 --collect=all --overlay=0 --quit-on-end
## (prueba corta: agregar --max-secs=60 tras los flags del bot. Para mp4: ffmpeg -i partida.ogv -c:v libx264 -crf 23 partida.mp4)
## (XDG_DATA_HOME aparte: asi la grabacion no toca el progreso/codice/narrador reales de ~/.local/share/godot)
##
## PELEA DIRECTA CONTRA UN JEFE (prototipo de balance, plan J0): salta al piso del jefe, equipa lo pedido y entra a
## su sala sin recorrer el piso. Al terminar escribe "[J0] jefe=... heroe=... semilla=..." (una linea facil de parsear)
## y el bot cierra Godot. Varias peleas en paralelo con --log= y XDG_DATA_HOME distintos; tools/autoplay/tabla_jefes.py
## junta los registros (y las lineas "[boss-stats]"/"[boss-dmg]" del jefe, si se guarda la salida: > ruta.out).
##   --boss=<variante>   cera | boss_cera | afeitadora ... (cualquiera de las dos variantes del piso: original o alternativo)
##   --boss-alt=0|1      fuerza original (0) o alternativo (1) de ese piso (BossPicker); sin esto, el de la variante pedida
##   --loadout=a,b,c     ids de objetos: el arma que sea (equip_slot de arma) se equipa y el resto va al inventario
##                       (sin arma pedida, pistola basica). Ej: --loadout=boomerang_silicona
##   --hp-bonus=N        +N de vida maxima al saltar al jefe (el salto se salta las mejoras de los pisos previos: con la vida base
##                       25 los heroes caen en segundos; ~40 se parece a llegar con 2-3 recompensas de jefe y corazones)
##   --manual=1          JUGARLO A MANO: mismo arranque pero el bot no toma el control (solo mide y anota). Sin modo dios
##                       (salvo --god=1) y no cierra solo. Ej. ventana en la pantalla del notebook, sin sonido:
##   godot --path . --screen 2 --audio-driver Dummy res://tools/autoplay/autoplay.tscn -- --boss=cera --manual=1
##   (el bot aun pasa el menu y la intro y elige --hero; cambialo con --hero=pitocles|vulvalquiria|ornitorrinco)
## Bot, sin sonido ni ventana, una pelea (varias en paralelo: --log= y XDG_DATA_HOME distintos):
##   XDG_DATA_HOME=.claude_tmp/xdg1 godot --headless --audio-driver Dummy --fixed-fps 60 res://tools/autoplay/autoplay.tscn -- \
##     --hero=pitocles --seed=1 --boss=cera --no-god=1 --log=.claude_tmp/cera_pitocles_1.log > .claude_tmp/cera_pitocles_1.out
##
## Dinamicas de sala (src/rooms): --force-dyn=<escort|hold|thief|stealth|clock|challenge|celo|lubricado|
## aduanera|apagon|censurada|barriles|antorchas|trampas|pacto|ruleta|mercado> las fuerza en toda sala donde
## quepan; --force-utero=1 abre El Utero (nivel secreto de Vulvania) al pisar Trompas sin comprar el Turno; --no-god=1 juega sin modo dios (para medir los peligros de sala); --armed=1 empieza con pistola.
## PERRO GUARDIAN: si no hay progreso (nada muere ni se recoge, ni salas nuevas, ni dano) durante 90 s abandona el
## objetivo y lo anota como PROBLEMA; si una sala no se limpia en 3 min se aleja y vuelve; si el piso pasa de 10 min va
## directo al jefe; y como ultimo recurso fuerza la salida (siempre termina). Los PROBLEMA: del registro son cosas a arreglar.
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
const COLLECT_FLOOR_LIMIT_S := 1500.0
const STALL_S := 90.0  # sin progreso tanto tiempo: abandona el objetivo
const BOSS_STALL_S := 240.0
const ROOM_LIMIT_S := 180.0  # sala sin limpiar: se aleja y vuelve

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
var _in_fallback := false
var _grid_open := {}  # la rejilla sin las zonas de peligro: si ellas parten la sala, se cruza igual (el bot juega en modo dios)
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
var _collect := false
var _max_secs := 0.0
var _hero := ""
# perro guardian
var _prog_sig := ""
var _prog_t := 0.0
var _sig_t := 0.0
var _stall_n := 0
var _goal_kind := ""  # thing | quest | puzzle | room | fight | ""
var _goal_ref = null
var _skip_rooms := {}  # grid_pos -> true (salas abandonadas como destino)
var _rush := false  # piso demasiado largo: directo al jefe
var _evade_t := 0.0
var _evade_n := 0
var _flee_goal := Vector2.INF
var _flee_t := 0.0
var _pause_t := 0.0
var _narr_t := 0.0
var _win_pos := Vector2.ZERO
var _win_t := 0.0
var _moved := false  # este fotograma se pidio un movimiento
var _move_dir := Vector2.DOWN
var _face := Vector2.DOWN
# resumen del modo recoger-todo
var _fl := {}  # piso -> {name, rooms_total, rooms_visited, unvisited, seen, chests, t}
var _wpn_taken := {}  # id de arma -> true (recoger-todo: cada arma una vez, sin intercambiarlas sin fin)
var _scan_t := 0.0
var _coins_gained := {}  # piso -> monedas recogidas
var _coins_prev := -1
var _codex0 := 0
var _game_f0 := -1  # fotograma de fisica en que empezo la partida
# pelea directa contra un jefe + medidor J0
var _boss_arg := ""
var _loadout: Array = []
var _manual := false
var _bm := {}  # medidor de la pelea (ver _boss_meter)
var _bm_reported := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	var log_path := _arg("--log=", ProjectSettings.globalize_path(LOG_PATH))  # --log=<ruta>: registro propio (partidas en paralelo)
	DirAccess.make_dir_recursive_absolute(log_path.get_base_dir())
	_log = FileAccess.open(log_path, FileAccess.WRITE)
	_t0 = Time.get_ticks_msec() / 1000.0
	var hero := _arg("--hero=", "vulvalquiria")
	_hero = hero
	RunManager.test_seed = int(_arg("--seed=", "0"))
	_collect = _arg("--collect=", "") == "all"
	_max_secs = float(_arg("--max-secs=", "0"))
	var fast := _arg("--fast=", "")
	if fast != "":
		Engine.time_scale = clampf(float(fast), 1.0, 6.0)
	elif "--fast" in OS.get_cmdline_user_args():
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
	_boss_arg = _arg("--boss=", "")
	_manual = _arg("--manual=", "") not in ["", "0"]
	for id in _arg("--loadout=", "").split(",", false):
		_loadout.append(id.strip_edges())
	DebugMenu.god_mode = _arg("--no-god=", "") == ""  # --no-god=1: sin modo dios (mide dificultad y peligros de sala)
	Utero.force = _arg("--force-utero=", "") != ""  # prueba: El Utero se abre solo al pisar Trompas (sin comprar el Turno)
	RoomDirector.force_kind = _arg("--force-dyn=", "")  # prueba: fuerza esa dinamica de sala en todas las salas donde quepa
	# para alargar los jefes y ver todos sus desafios: --boss-hp=1,1,12,12,12 (multiplicador por piso)
	EnemyBoss.test_hp_mults = Array(_arg("--boss-hp=", "1").split(",", false)).map(func(x): return float(x))
	if _manual:
		DebugMenu.god_mode = _arg("--god=", "") not in ["", "0"]  # a mano se juega en serio
	_build_overlay()
	_codex0 = get_node("/root/LoreDatabase").get_unlocked_entries().size()
	if _max_secs > 0.0:
		_watch_max_secs()
	await _wait_real(2.5)
	# Menu principal: "Nueva partida", como lo haria una persona.
	_label.text = "BOT · menu: Nueva partida"
	var menu := get_tree().current_scene
	_say("Menu principal -> Nueva partida")
	menu.start_btn.pressed.emit()
	# Intro: leer cada lamina y seguir con una tecla hasta llegar a elegir heroe.
	await _wait_real(1.5)
	var intro := get_tree().current_scene
	var slides := 0
	while intro and is_instance_valid(intro) and not intro._select.visible:
		_label.text = "BOT · intro: lamina %d" % (slides + 1)
		await _wait_real(1.6)
		if intro._select.visible:
			break
		_tap_key(KEY_SPACE)  # termina de escribir
		await _wait_real(1.4)
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
	await _wait_real(2.5)
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
	var jump := int(_arg("--floor=", "0"))  # prueba corta: salta (como el menu de depuracion) al piso N de la ruta (p.ej. 9 = La Prostata con Vulvalquiria)
	if jump > 1:
		var rm0 := get_node("/root/RunManager")
		rm0.current_floor = jump - 1
		main._advance_to_next_floor()
		await _wait_s(1.0)
		_say("Salto al piso %d (%s)" % [jump, rm0.floor_data().id])
	if _arg("--armed=", "") != "":
		player.equip_weapon(get_node("/root/ItemDatabase").get_item("pistol_basic"))  # prueba: sin la busqueda inicial del arma
	_game_f0 = Engine.get_physics_frames()
	_say("Partida nueva: semilla=%d" % get_node("/root/RunManager").current_seed)
	player.get_node("Hurtbox").area_entered.connect(func(a): if a.is_in_group("enemy_attack"): _hits += 1)
	_say("Modo: %s%s, tiempo x%.1f" % ["RECOGER TODO" if _collect else "recorrido normal", "" if DebugMenu.god_mode else " SIN modo dios", Engine.time_scale])
	if _boss_arg != "":
		await _setup_boss_fight()


## Termina solo tras N s de juego (fotogramas de fisica / 60: sirve igual con el movie maker, que fija el paso).
func _watch_max_secs() -> void:
	while player == null:  # el reloj arranca con la partida (no con el menu ni la intro)
		await get_tree().process_frame
	var f0 := Engine.get_physics_frames()
	while (Engine.get_physics_frames() - f0) / float(Engine.physics_ticks_per_second) < _max_secs:
		await get_tree().process_frame
	_say("--max-secs=%d alcanzado: fin de la prueba" % int(_max_secs))
	if _boss_arg != "":
		_boss_report("tiempo")
		if not _bm_reported:
			_say("[J0] jefe=%s heroe=%s resultado=sin_pelea" % [_boss_arg, _hero])
	_log_summary("RESUMEN PARCIAL")
	get_tree().quit()


func _wait_s(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


## Espera de RELOJ real (la maquina de escribir de la intro va por reloj, no por fotogramas: con --fixed-fps los
## temporizadores del motor correrian mucho mas rapido que ella).
func _wait_real(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame


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
	# tiempo de JUEGO desde que empieza la partida (con --fixed-fps pasa mas rapido que el reloj)
	var t := 0.0 if _game_f0 < 0 else (Engine.get_physics_frames() - _game_f0) / float(Engine.physics_ticks_per_second)
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
	layer.visible = _arg("--overlay=", "1") != "0"
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
	_boss_meter(delta)
	if _manual:
		return  # a mano: el bot solo mide
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
	# Los dialogos del narrador esperan Enter (como un jugador que los lee): se pasan tras unos segundos de lectura.
	if Narrator._panel.visible:
		_narr_t += delta
		if _narr_t > 4.0:
			_narr_t = 0.0
			_tap_key(KEY_ENTER)
	else:
		_narr_t = 0.0
	if get_tree().paused:
		_pause_t += delta
		if _pause_t > 45.0 and fmod(_pause_t, 15.0) < delta:
			_issue("Juego en pausa %d s (prompt=%s): se intenta cerrar con Espacio/Esc" % [int(_pause_t), Narrator.prompt_owner])
			_tap_key(KEY_SPACE if int(_pause_t / 15.0) % 2 == 1 else KEY_ESCAPE)
		_heartbeat_t -= delta
		if _heartbeat_t <= 0.0:
			_heartbeat_t = 10.0
			_say("  latido: juego en PAUSA (narrador/menu); prompt=%s eleccion=%s" % [Narrator.prompt_owner, Narrator._choice.visible])
		return
	_pause_t = 0.0
	var rm := get_node("/root/RunManager")
	if not rm.run_active:
		_finish(rm.last_run_victory)
		return
	if rm.current_floor != _floor_n:
		if _floor_n > 0:
			_log_floor_summary(_floor_n)
		_floor_n = rm.current_floor
		_floor_t = 0.0
		_visited.clear()
		_kq_lost = 0
		_consulta_giveup = false
		_skip_rooms.clear()
		_rush = false
		_stall_n = 0
		_prog_t = 0.0
		_evade_t = 0.0
		_evade_n = 0
		_fl[_floor_n] = {"name": str(rm.floor_data().name), "rooms_total": 0, "rooms_visited": 0, "unvisited": [], "seen": {}, "chests": {}, "t0": Time.get_ticks_msec() / 1000.0 - _t0}
		_say("=== PISO %d: %s ===" % [_floor_n, rm.floor_data().name])
	_floor_t += delta
	var floor_limit := COLLECT_FLOOR_LIMIT_S if _collect else FLOOR_LIMIT_S
	if _floor_t > floor_limit and not _rush:
		_issue("Piso %d pasa de %d min: va directo al jefe" % [_floor_n, int(floor_limit / 60.0)])
		_rush = true
	if _floor_t > floor_limit * 2.0:
		_issue("Piso %d pasa de %d min: se fuerza la entrada al jefe" % [_floor_n, int(floor_limit / 30.0)])
		_floor_t = 0.0
		_force_boss()
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
	_moved = false
	var coins_now: int = rm.coins
	if _coins_prev >= 0 and coins_now > _coins_prev:
		_coins_gained[_floor_n] = int(_coins_gained.get(_floor_n, 0)) + coins_now - _coins_prev
	_coins_prev = coins_now
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 1.0
		_scan_floor()
	_watch_progress(delta, room, enemies)
	_track_exits(room, enemies)
	if _evade_t > 0.0 and not enemies.is_empty():
		_evade_t -= delta
		_goal_text = "alejarse de %d enemigos y volver (sala sin limpiar)" % enemies.size()
		_goal_kind = "fight"
		player.aim_override = Vector2.ZERO
		_flee(enemies, delta)
	elif not enemies.is_empty():
		_goal_kind = "fight"
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
	_watch_stuck(delta, room, enemies)
	# mira hacia donde va (sin enemigos): el arma y el cuerpo siguen el rumbo, nada de apuntar al raton
	if enemies.is_empty() and _moved:
		_face = _face.lerp(_move_dir, 0.25).normalized() if _face.dot(_move_dir) > -0.9 else _move_dir
	if enemies.is_empty() and _unstick_t <= 0.0:
		player.aim_override = _face
	_heartbeat_t -= delta
	if _heartbeat_t <= 0.0:
		_heartbeat_t = 10.0
		var en := _alive_enemies(room)
		_say("  latido: sala %s %s limpia=%s pos=%s enemigos=%d %s objetivo=%s arma=%s intox=%d pausa=%s" % [
			Room.RoomType.keys()[room.room_type], room.grid_pos, room.cleared, player.global_position - room.global_position,
			en.size(), en.map(func(e): return e.global_position - room.global_position).slice(0, 3), _goal_text,
			player.current_weapon != null, get_node("/root/PlayerStats").intoxication_tier, get_tree().paused])
		if not en.is_empty() and _room_t > 60.0:
			# la pelea se alarga: datos del primer enemigo para saber por que no cae
			var e0: Node2D = en[0]
			_say("    enemigo[0] %s: estado=%s vida=%s/%s dist=%.0f vista_libre=%s visible=%s invulnerable=%s abierto=%s capa=%d mask=%d" % [
				e0.get("enemy_name"), e0.get("state"), e0.get("current_health"), e0.get("max_health"),
				e0.global_position.distance_to(player.global_position), _line_clear(player.global_position, e0.global_position), e0.visible,
				e0.get("invulnerable"), e0.get("open"), e0.get("collision_layer"), e0.get("collision_mask")])
	_label.text = "BOT · piso %d · %s · %s\n%s · golpes recibidos: %d" % [
		_floor_n, Room.RoomType.keys()[room.room_type], "limpia" if room.cleared else "sin limpiar",
		_goal_text, _hits]


var _slot_t := 0.0
var _drink_t := 0.0


## Ranuras 1-4: el bot cura con lo que lleve cuando le queda poca vida y se protege (toallas,
## calzoncillos...) al entrar en pelea. Asi tambien se prueba el uso real de las ranuras.
func _use_slots(fighting: bool, delta: float) -> void:
	_drink_t -= delta
	# llave borracha en la mano: la intoxicacion baja 2 por segundo y el camino al cofre es largo -> bebe lo que lleve
	# (tambien peleando: antes solo bebia al explorar y la llave se escurria en medio de una pelea)
	var kq = main.get_node_or_null("KeyQuests")
	if _drink_t <= 0.0 and kq != null and kq.kind == "drunk" and kq.state == "carried" and get_node("/root/PlayerStats").intoxication_level < 55.0:
		var dslots := ItemSlots.find(player)
		if dslots != null and dslots.use_first_with_tag("intoxicante"):
			_drink_t = 0.6
			_say("  bebe un intoxicante de las ranuras para no soltar la llave borracha")
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
	if not _bm.is_empty() and e == _bm.get("boss"):
		_bm.victory = true
		_boss_report("victoria")
	if e.is_in_group("boss") and _boss_t0 >= 0.0:
		var secs := Time.get_ticks_msec() / 1000.0 - _boss_t0
		_say("JEFE %s derrotado en %.0f s (reloj real, --fast=1.6x), golpes recibidos en la pelea: %d" % [e.enemy_name, secs, _hits_real - _boss_hits0])
		_boss_t0 = -1.0


func _finish(victory: bool) -> void:
	_done = true
	_release_all()
	_boss_report("victoria" if victory else "derrota")
	if not get_node("/root/RunManager").last_run_victory:
		_say("MUERTE/FIN en el piso %d (%s), sala %s" % [_floor_n, get_node("/root/RunManager").floor_data().get("name", "?"), _room.grid_pos if _room else "?"])
	_log_summary("RESUMEN FINAL")
	_say("FIN: %s. Pisos liberados: %s. Golpes recibidos: %d. Problemas: %d" % [
		"VICTORIA" if victory else "derrota", get_node("/root/RunManager").liberated, _hits, _issues.size()])
	for i in _issues:
		_say("  - " + i)
	_label.text = "BOT · FIN: %s · problemas: %d" % ["VICTORIA" if victory else "derrota", _issues.size()]
	if "--quit-on-end" in OS.get_cmdline_user_args():
		await _wait_s(12.0)  # que se vea la pantalla final
		get_tree().quit()


# ------------------------------------------------------------------ pelea directa contra un jefe (J0)
## Busca el piso del jefe (cualquiera de sus dos variantes). Si su reino no esta en la ruta del heroe, lo agrega.
func _find_boss_floor(arg: String) -> Dictionary:
	var want := arg.trim_prefix("boss_")
	for f in RunManager.FLOORS:
		var b := str(f.get("boss", "")).trim_prefix("boss_")
		var a := str(f.get("boss_alt", "")).trim_prefix("boss_")
		if want != "" and (want == b or (a != "" and want == a)):
			return f
	return {}


func _setup_boss_fight() -> void:
	var rm := get_node("/root/RunManager")
	var f := _find_boss_floor(_boss_arg)
	if f.is_empty():
		_issue("--boss=%s: no hay ningun piso con ese jefe" % _boss_arg)
		return
	if not RunManager.route_floors.has(f):
		RunManager.set_route(RunManager.route_regions + [f.region])
	var idx := RunManager.route_floors.find(f) + 1
	var want := _boss_arg.trim_prefix("boss_")
	var alt_flag := _arg("--boss-alt=", "")
	if alt_flag != "":
		BossPicker.force = "alt" if alt_flag != "0" else "main"
	else:
		var is_alt: bool = str(f.get("boss_alt", "")) != "" and want == str(f.boss_alt).trim_prefix("boss_") and want != str(f.boss).trim_prefix("boss_")
		BossPicker.force = "alt" if is_alt else "main"
	rm.current_floor = idx - 1
	main._advance_to_next_floor()
	await _wait_s(1.0)
	var db := get_node("/root/ItemDatabase")
	var has_weapon := false
	for id in _loadout:
		var it = db.get_item(id)
		if it == null:
			_issue("--loadout: no existe el objeto %s" % id)
			continue
		if it.equip_slot == Item.EquipSlot.WEAPON:
			player.equip_weapon(it)
			has_weapon = true
		else:
			player.add_item_to_inventory(id)
	if not has_weapon:
		player.equip_weapon(db.get_item("pistol_basic"))
	var hp_bonus := float(_arg("--hp-bonus=", "0"))
	if hp_bonus > 0.0:
		get_node("/root/PlayerStats").apply_stat_mod("max_health_flat", hp_bonus)
	_bm = {"variant": _boss_arg, "floor": idx, "alt": BossPicker.force == "alt"}
	_say("PELEA DIRECTA: jefe=%s piso=%d (%s) %s equipo=%s%s" % [_boss_arg, idx, rm.floor_data().name, "ALTERNATIVO" if BossPicker.force == "alt" else "original", _loadout, " MANUAL" if _manual else ""])
	_force_boss()
	if _max_secs <= 0.0 and not _manual:
		_max_secs = 600.0  # tope de la pelea del bot (tiempo de juego)
		_watch_max_secs()


## Medidor J0. Corre cada fotograma de fisica (tambien a mano). Empieza cuando el jefe sale de INTRO; todo en tiempo de juego.
func _boss_meter(delta: float) -> void:
	if _boss_arg == "" or get_tree().paused or _bm_reported:
		return
	var b = _bm.get("boss")
	if b == null or not is_instance_valid(b):
		var cand = get_tree().get_first_node_in_group("boss")
		if cand == null or not is_instance_valid(cand) or cand.get("state") == null or int(cand.state) == 0 or float(cand.current_health) <= 0.0:
			return
		_bm.boss = cand
		_bm.t = 0.0
		_bm.atk = 0.0
		_bm.tired = 0.0
		_bm.chan = 0.0
		_bm.idle = 0.0
		_bm.dmg_taken = 0.0
		_bm.hits0 = _hits_real
		_bm.dealt = 0.0
		_bm.max_hit = 0.0
		_bm.max_hit_weapon = "-"
		_bm.heals = 0
		_bm.cuts = 0
		_bm.was_chan = false
		_bm.victory = false
		_bm.hp_max = float(cand.max_health)
		_bm.name = str(cand.get("enemy_name"))
		var ge := get_node("/root/GlobalEvents")
		_bm.pool = _pool_now()
		ge.enemy_damaged.connect(_bm_on_enemy_damaged)
		_say("MEDIDOR: pelea contra %s (vida %.0f)" % [_bm.name, _bm.hp_max])
		return
	if int(b.state) == 5:  # DEAD
		return
	_bm.t += delta
	_bm.hp_last = float(b.current_health)
	var pool_now := _pool_now()  # vida + escudo: lo que baja es dano recibido (el escudo que regenera solo sube)
	if pool_now < _bm.pool:
		_bm.dmg_taken += _bm.pool - pool_now
	_bm.pool = pool_now
	match int(b.state):
		2: _bm.atk += delta     # ATTACK
		3: _bm.tired += delta   # TIRED
		1: _bm.idle += delta    # IDLE
	var ch: bool = b.get("_channeling") == true
	if ch:
		_bm.chan += delta
	if _bm.was_chan and not ch:
		if b.get("_chan_ok") == true:
			_bm.cuts += 1
		_bm.heals += 1
	_bm.was_chan = ch


func _pool_now() -> float:
	var st := get_node("/root/PlayerStats")
	return float(st.current_health) + float(st.current_shields)


func _bm_on_enemy_damaged(e: Node, amount: float, _src: Node) -> void:
	if _bm_reported or not _bm.has("t") or e != _bm.boss:
		return
	_bm.dealt += amount
	if amount > _bm.max_hit:
		_bm.max_hit = amount
		_bm.max_hit_weapon = str(player.current_weapon.id) if player and player.current_weapon else "puno"


## Escribe el resumen de la pelea: lineas legibles y la linea final "[J0] ..." (una vez). En modo bot cierra Godot.
func _boss_report(result: String) -> void:
	if _bm_reported or not _bm.has("t"):
		return
	_bm_reported = true
	var b = _bm.boss
	var hp_left := 0.0
	if not _bm.victory:
		hp_left = maxf(0.0, float(b.current_health) if is_instance_valid(b) else float(_bm.get("hp_last", 0.0)))
	var t: float = maxf(_bm.t, 0.001)
	var rm := get_node("/root/RunManager")
	var weapon := str(player.current_weapon.id) if player and is_instance_valid(player) and player.current_weapon else "-"
	var hits: int = _hits_real - _bm.hits0
	_say("RESUMEN JEFE %s: %s en %.1f s de juego; golpes recibidos %d, dano recibido %.0f; vida del jefe restante %.0f/%.0f (%.0f%%); dano al jefe %.0f (%.1f/s); ataque activo %.0f%% / agotado %.0f%% / reposo %.0f%% / curandose %.0f%%; curas %d (cortadas %d); golpe mas fuerte %.0f con %s" % [
		_bm.name, result, t, hits, _bm.dmg_taken, hp_left, _bm.hp_max, 100.0 * hp_left / _bm.hp_max, _bm.dealt, _bm.dealt / t,
		100.0 * _bm.atk / t, 100.0 * _bm.tired / t, 100.0 * _bm.idle / t, 100.0 * _bm.chan / t, _bm.heals, _bm.cuts, _bm.max_hit, _bm.max_hit_weapon])
	_say("[J0] jefe=%s%s heroe=%s semilla=%d arma=%s resultado=%s dur=%.1f golpes=%d dano_rec=%.0f vida_restante=%.0f vida_max=%.0f dps=%.1f pct_ataque=%.0f pct_agotado=%.0f pct_reposo=%.0f pct_cura=%.0f curas=%d cortadas=%d golpe_max=%.0f arma_golpe_max=%s god=%d" % [
		str(_bm.variant).trim_prefix("boss_"), "(alt)" if _bm.alt else "", _hero, rm.current_seed, weapon, result, t, hits, _bm.dmg_taken,
		hp_left, _bm.hp_max, _bm.dealt / t, 100.0 * _bm.atk / t, 100.0 * _bm.tired / t, 100.0 * _bm.idle / t, 100.0 * _bm.chan / t,
		_bm.heals, _bm.cuts, _bm.max_hit, _bm.max_hit_weapon, 1 if DebugMenu.god_mode else 0])
	if not _manual:
		_done = true
		_release_all()
		await get_tree().create_timer(0.3, true, false, true).timeout
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
	_dodge(enemies)


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


func _dodge(enemies: Array) -> void:
	if _dash_cd > 0.0:
		return
	# embestidas de cuerpo a cuerpo (estado 3 = LUNGE en la base de los enemigos): dash de costado cuando ya vienen
	# (el Gran Candado, por ejemplo, enjaula si lo comes y su ventana de ataque dura menos que la jaula)
	for e in enemies:
		if e.get("state") == 3 and e is CharacterBody2D:
			var rel: Vector2 = player.global_position - e.global_position
			if rel.length() < 150.0 and e.velocity.length() > 80.0 and e.velocity.normalized().dot(rel.normalized()) > 0.6:
				var side: Vector2 = e.velocity.normalized().orthogonal() * _strafe
				_press_move(_avoid_walls(side))
				Input.action_press("dash")
				_dash_cd = 1.2
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
	if room.room_type == Room.RoomType.PUZZLE and room.has_meta("puzzle") and not room.has_meta("bot_skip_puzzle") and _solve_puzzle(room.get_meta("puzzle")):
		_goal_kind = "puzzle"
		return
	if _quest_step(room):
		_goal_kind = "quest"
		return
	# 1) cosas para recoger o usar en esta sala
	var target := _next_thing(room)
	if target and _quest_room != null and _kq_state == "carried" \
			and main.get_node_or_null("KeyQuests") != null and main.get_node("KeyQuests").kind == "drunk":
		target = null  # la llave borracha se suelta a los segundos de estar sobrio: sin detenerse a recoger nada, a la sala del cofre
	if target and target != _thing_cur:
		_thing_cur = target
		_thing_t = 0.0
	if target:
		_goal_kind = "thing"
		_goal_ref = target
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
				if target.get_script().resource_path.ends_with("interactable.gd") and not room.has_meta("consulta"):
					_used[target.get_instance_id()] = true  # inscripcion, fuente, escotilla: una vez (la puerta del Utero se reintenta)
				var it = target.get("_item")
				if it != null and it.equip_slot == Item.EquipSlot.WEAPON:
					_wpn_taken[it.id] = true  # recoger-todo: cada arma una vez (la que se suelta al cambiar no se vuelve a coger)
				var n := int(target.get_meta("bot_tries", 0)) + 1
				target.set_meta("bot_tries", n)
				if n > 6:
					_used[target.get_instance_id()] = true
					if room.has_meta("consulta"):
						_consulta_giveup = true
					_issue("No se pudo usar/recoger %s en sala %s" % [_thing_name(target), Room.RoomType.keys()[room.room_type]])
		# hasta quedar encima: a 26 px el cuerpo todavia no toca el area del objeto
		if player.global_position.distance_to(tp) > 4.0:
			_steer_to(tp)
		return
	# 2) siguiente sala
	var next := _next_room(room)
	if next == null:
		_goal_text = "sin destino"
		_goal_kind = ""
		return
	var door: Door = room.door_to(next.grid_pos)
	if door == null:
		_goal_text = "sin puerta hacia %s" % next.grid_pos
		return
	_goal_kind = "room"
	_goal_ref = _room_goal
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
var _kq_lost := 0
var _consulta_giveup := false

func _quest_step(room: Room) -> bool:
	_quest_room = null
	var kq = main.get_node_or_null("KeyQuests")
	if kq == null or not kq.ready_ok or player.current_weapon == null:
		return false  # sin arma no hay custodios que valgan: primero el arma
	if kq.state != _kq_state:
		if _kq_state == "carried" and kq.state == "home":
			_kq_lost += 1
			_say("  llave %s perdida: intoxicacion %.0f (nivel %d), sala %s, ranuras %s" % [kq.kind, get_node("/root/PlayerStats").intoxication_level, get_node("/root/PlayerStats").intoxication_tier, room.grid_pos, str(ItemSlots.find(player).slots) if ItemSlots.find(player) != null else "-"])
			if _kq_lost >= 3 and not kq.bot_gave_up:
				kq.bot_gave_up = true
				_issue("Piso %d: la llave %s se perdio %d veces (la mision no se puede hacer con lo que lleva el bot): abandonada" % [_floor_n, kq.kind, _kq_lost])
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


## Lo mas urgente primero (solo cuenta en la tienda: el Turno del Utero, la hormona que falta, objetos nuevos...).
func _thing_prio(n: Node2D) -> float:
	var path: String = n.get_script().resource_path
	if not path.ends_with("shop_item.gd"):
		return 0.0
	var it = n.get("_item")
	if it == null:
		return 0.0
	if it.id == Utero.TURNO:
		return 100.0
	var h: String = str(it.custom_data.get("hormone", ""))
	if h != "" and h in main._missing_hormones():
		return 90.0
	var base := 20.0 if it.consumable else (30.0 if "mejora" in it.tags else 40.0)
	var rm := get_node("/root/RunManager")
	for c in rm.items_collected:
		if c.id == it.id:
			return base  # ya lo tuve: no es novedad
	return base + 10.0


func _next_thing(room: Room) -> Node2D:
	var best: Node2D = null
	var bd := INF
	var bp := -1.0
	var pp := player.global_position
	for n in _things(room):
		if _used.has(n.get_instance_id()):
			continue
		var d: float = n.global_position.distance_to(pp)
		var pr := _thing_prio(n)
		if pr > bp or (pr == bp and d < bd):
			bp = pr
			bd = d
			best = n
	return best


func _things(room: Room) -> Array:
	var out := []
	var generic := []
	var rm := get_node("/root/RunManager")
	var missing: Array = main._missing_hormones()
	var armed: bool = player.current_weapon != null
	if armed:
		_wpn_taken[player.current_weapon.id] = true
	var nodes: Array = room.pickups_node.get_children() + room.props_node.get_children() + room.get_children()
	# el Turno hay que poder pagarlo: las demas compras dejan esa reserva
	var reserve := 0
	if _collect and Utero.turno_obtainable(main):
		for c in nodes:
			if c is Node2D and is_instance_valid(c) and c.get_script() != null and c.get_script().resource_path.ends_with("shop_item.gd") and c.get("item_id") == Utero.TURNO and c.visible:
				reserve = int(c.price)
	for c in nodes:
		if not (c is Node2D) or not is_instance_valid(c) or not c.is_visible_in_tree():
			continue
		if c.get_script() == null:
			continue
		var path: String = c.get_script().resource_path
		if path.ends_with("item_pickup.gd"):
			# Con arma ya en la mano no recoge otra: el juego suelta la vieja al cambiarla
			# y el bot se quedaba intercambiandolas sin fin. (Recoger-todo: cada arma nueva una vez.)
			var it = c.get("_item")
			if it != null and it.equip_slot == Item.EquipSlot.WEAPON and armed and (not _collect or _wpn_taken.has(it.id)):
				continue
			if it != null and "maldito" in it.tags:
				continue  # la jaula maldita no deja pasar hormonas: el bot no la coge
			out.append(c)
		elif path.ends_with("chest.gd") and not c.get("_opened"):
			out.append(c)
		elif path.ends_with("shop_item.gd"):
			var it = c.get("_item")
			if it == null or c.get("price") == null or c.get("_sold") == true:
				continue  # (vendido: el nodo sigue visible aunque su sprite no)
			var h: String = str(it.custom_data.get("hormone", ""))
			var need: bool = (h != "" and h in missing) or (not armed and it.equip_slot == Item.EquipSlot.WEAPON)
			if need and rm.coins >= c.price:
				out.append(c)
			elif _collect and not need and it.id != Utero.TURNO and rm.coins - reserve >= c.price and not (it.equip_slot == Item.EquipSlot.WEAPON and armed) and "maldito" not in it.tags:
				out.append(c)
			elif _collect and it.id == Utero.TURNO and rm.coins >= c.price:
				out.append(c)
		elif path.ends_with("interactable.gd"):
			# La puerta del Utero (Consulta de la Doctora V.): solo vale la pena con el Turno en la mano.
			if room.has_meta("consulta") and (not Utero.owns_turno(main) or RunManager.utero_inserted or _consulta_giveup):
				continue
			generic.append(c)
	out = out.filter(func(n): return n.get_parent() != null and not _used.has(n.get_instance_id()))
	if out.is_empty():
		out = generic  # inscripciones, fuente y la escotilla al piso siguiente: al final
	return out


## Plan de piso: la sala sin visitar mas cercana (por el grafo); despues el jefe.
## Recoger-todo: todas las salas (la tienda al final, con el dinero reunido), las secretas y de puerta con candado
## que se puedan abrir; el jefe solo cuando no queda nada. `_room_goal` = la sala destino final del camino.
var _room_goal := Vector2i.ZERO

func _door_passable(d: Door) -> bool:
	if d.state != Door.State.LOCKED:
		return true
	if not _collect:
		return false
	return (d.required_key != "" and player.has_item(d.required_key)) or player.has_item("key_master") \
		or (d.required_intoxication_tier > 0 and get_node("/root/PlayerStats").intoxication_tier >= d.required_intoxication_tier)


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
			if d == null or not _door_passable(d):
				continue
			var nr: Room = rooms[nb]
			if nr.room_type == Room.RoomType.BOSS and not can_boss:
				continue
			prev[nb] = cur
			queue.append(nb)
	var goal = null
	if _quest_room != null and _quest_room != room and _quest_room.grid_pos in order:
		goal = _quest_room.grid_pos  # mision de llave: ir a la sala de la llave / del cofre
	# Con el Turno en la mano: a la Consulta de la Doctora V. (la puerta del Utero)
	if goal == null and Utero.owns_turno(main) and not RunManager.utero_inserted and not _consulta_giveup:
		for pos in order:
			if rooms[pos].has_meta("consulta") and pos != room.grid_pos:
				goal = pos
				break
	# Sin arma: primero la sala del cofre con el arma (el juego la esconde lejos).
	var wr = main.get("_weapon_room")
	if goal == null and player.current_weapon == null and wr != null and is_instance_valid(wr) and wr.grid_pos in order and wr.grid_pos != room.grid_pos:
		goal = wr.grid_pos
	if goal == null and not (_rush and can_boss):
		var shop = null
		for pos in order:
			var r: Room = rooms[pos]
			if pos == room.grid_pos or _visited.has(pos) or _skip_rooms.has(pos) or r.room_type == Room.RoomType.BOSS:
				continue
			if _collect and r.room_type == Room.RoomType.SHOP:
				if shop == null:
					shop = pos
				continue
			goal = pos
			break
		if goal == null and shop != null:
			goal = shop
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
	_room_goal = goal
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
	_grid_open = _grid.duplicate()
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
		if not _grid_open.is_empty() and _grid_open.size() != _grid.size() and not _in_fallback:
			# los peligros (fuego, pinchos...) cortan la sala en dos: el camino cruza por encima, como haria un jugador
			var keep := _grid
			_grid = _grid_open
			_in_fallback = true
			var alt := _find_path(from, to)
			_in_fallback = false
			_grid = keep
			return alt
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
	if dir.length() > 0.1:
		_moved = true
		_move_dir = dir.normalized()
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

var _win_intent := false

func _watch_stuck(delta: float, room: Room, enemies: Array) -> void:
	# Clavado por enemigos pegados (o empujando una puerta sin que ceda): 1,2 s queriendo avanzar sin moverse
	# 24 px -> dash en esa direccion (con dash se cruza la puerta y se sale de entre los enemigos).
	_win_t += delta
	_win_intent = _win_intent or _moved
	if _win_t >= 1.2:
		if _win_intent and not enemies.is_empty() and player.global_position.distance_to(_win_pos) < 24.0 and _dash_cd <= 0.0:
			Input.action_press("dash")
			_dash_cd = 1.0
		_win_t = 0.0
		_win_pos = player.global_position
		_win_intent = false
	if player.global_position.distance_to(_last_pos) > 2.0:
		_last_pos = player.global_position
		_still_t = 0.0
		if _unstick_t <= 0.0:
			_unstick_n = 0
		return
	_still_t += delta
	# con enemigos vivos tambien: quieto 5 s empujando una pared no es esquivar (el Granito Rencoroso de una sala en L
	# se quedo atras de una esquina y el bot, pegado a la otra pared, 3 min sin moverse)
	var free_to_move := _alive_enemies(room).is_empty() or (_still_t > 5.0 and room.room_type != Room.RoomType.BOSS)
	if _still_t > 3.0 and _unstick_t <= 0.0 and _unstick_n < 8 and free_to_move:
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


# ------------------------------------------------------------------ perro guardian
## Firma de "algo avanza": cosas recogidas, monedas, muertes, salas nuevas, vida total de los enemigos de la
## sala (el dano cuenta), mision de llave... Si no cambia en STALL_S el objetivo se abandona.
func _watch_progress(delta: float, room: Room, enemies: Array) -> void:
	_prog_t += delta
	_sig_t -= delta
	if _sig_t > 0.0:
		return
	_sig_t = 1.0
	var rm := get_node("/root/RunManager")
	var hp := 0.0
	for e in enemies:
		var h = e.get("current_health")
		hp += float(h) if h != null else 0.0
	var kq = main.get_node_or_null("KeyQuests")
	var sig := "%d|%d|%d|%d|%d|%s|%d|%s|%d|%d" % [rm.items_collected.size(), rm.coins, rm.total_enemies_killed, _visited.size(),
		int(hp / 12.0), room.cleared, player.collected_items.size(), kq.state if kq else "", rm.blessings.size(), enemies.size()]
	var puz = room.get_meta("puzzle") if room.has_meta("puzzle") else null
	if puz != null:
		sig += "|%s|%s" % [puz.get("done"), puz.get("fails")]
	if sig != _prog_sig:
		_prog_sig = sig
		_prog_t = 0.0
		_stall_n = 0
		return
	var limit := BOSS_STALL_S if room.room_type == Room.RoomType.BOSS else STALL_S
	if _prog_t > limit:
		_on_stall(room, enemies)
	# sala sin limpiar tras 3 min: se aleja y vuelve (una vez cada 3 min)
	if not room.cleared and not enemies.is_empty() and room.room_type != Room.RoomType.BOSS and _room_t > ROOM_LIMIT_S:
		_evade_n += 1
		_evade_t = 10.0
		_room_t = 0.0
		_flee_goal = Vector2.INF
		_issue("Sala %s %s sin limpiar tras %d min (%d enemigos): se aleja y vuelve (vez %d)" % [
			Room.RoomType.keys()[room.room_type], room.grid_pos, int(ROOM_LIMIT_S / 60.0), enemies.size(), _evade_n])


func _on_stall(room: Room, enemies: Array) -> void:
	_stall_n += 1
	_prog_t = 0.0
	var where := "%s %s" % [Room.RoomType.keys()[room.room_type], room.grid_pos]
	_issue("Piso %d: sin progreso en %s (objetivo \"%s\", %s) -> nivel %d" % [_floor_n, where, _goal_text, _goal_kind, _stall_n])
	if _stall_n == 1 and _goal_kind == "thing" and _goal_ref != null and is_instance_valid(_goal_ref) and _goal_ref is Node2D:
		var gp: Vector2 = (_goal_ref as Node2D).global_position
		var zs: Array = RoomUtil.hazard_zones(get_tree())
		_say("    diag: objeto %s en %s (local %s) celda_libre=%s distancia=%.0f zonas_peligro=%d clase=%s monitorable=%s jugador=%s" % [
			_thing_name(_goal_ref), gp, gp - room.global_position, _grid.has(_cell(gp)), gp.distance_to(player.global_position), zs.size(),
			_goal_ref.get_class(), _goal_ref.get("monitorable"), player.global_position])
	if _stall_n == 1 and not enemies.is_empty():
		_say("    diag: sala dinamica=%s zonas_peligro=%d celdas=%d (sin peligros %d) camino_al_enemigo=%d puntos sendero_actual=%s meta=%s inmovil=%.0f s" % [room.get_meta("dynamic") if room.has_meta("dynamic") else "-", RoomUtil.hazard_zones(get_tree()).size(), _grid.size(), _grid_open.size(), _find_path(player.global_position, enemies[0].global_position).size(), _path.slice(0, 3), _path_goal, _still_t])
	if _stall_n == 1:
		for e in enemies:
			_say("    diag: " + _diag_enemy(room, e))
	match _stall_n:
		1:
			_abandon_goal(room)
		2:
			_rush = true
			_abandon_goal(room)
			if not enemies.is_empty():
				_evade_t = 10.0
				_flee_goal = Vector2.INF
		3:
			if not enemies.is_empty():
				_force_clear(room, enemies)
			else:
				_force_boss()
		_:
			_force_boss()


## Suelta lo que se estaba intentando para que el bot siga con otra cosa.
func _abandon_goal(room: Room) -> void:
	match _goal_kind:
		"thing":
			if _goal_ref != null and is_instance_valid(_goal_ref):
				_used[_goal_ref.get_instance_id()] = true
		"quest":
			var kq = main.get_node_or_null("KeyQuests")
			if kq:
				kq.bot_gave_up = true
		"puzzle":
			room.set_meta("bot_skip_puzzle", true)
		"room":
			if _goal_ref is Vector2i:
				_skip_rooms[_goal_ref] = true
	_thing_cur = null
	_path.clear()
	_unstick_n = 0


## Una linea con todo lo que puede explicar que un enemigo no muera (para el PROBLEMA de "sin progreso").
func _diag_enemy(room: Room, e: Node) -> String:
	var p: Vector2 = e.global_position - room.global_position
	var ai = e.get("ai")
	var cell := room.cell_kind(Vector2i(int(floor(p.x / 64.0)), int(floor(p.y / 64.0))))
	var q := PhysicsRayQueryParameters2D.create(player.global_position, e.global_position, 1)
	q.exclude = [player.get_rid()]
	var blocked := not player.get_world_2d().direct_space_state.intersect_ray(q).is_empty()
	return "%s (%s) pos_local=%s celda=%d hp=%.0f/%.0f invuln=%s estado=%s modo=%s vel=%s layer=%d mask=%d forma=%s linea_bloqueada=%s jugador_local=%s" % [
		e.get("enemy_name"), e.get_script().resource_path.get_file(), p, cell, float(e.get("current_health")), float(e.get("max_health")),
		e.get("invuln"), e.get("state"), ai.mode if ai != null else "-", e.get("velocity"), e.collision_layer, e.collision_mask,
		room.shape_id, blocked, player.global_position - room.global_position]


## Ultimo recurso con enemigos que no mueren: les baja la vida (queda anotado como PROBLEMA).
func _force_clear(room: Room, enemies: Array) -> void:
	_issue("Piso %d: se fuerza la muerte de %d enemigos de %s %s (no avanzaba)" % [_floor_n, enemies.size(), Room.RoomType.keys()[room.room_type], room.grid_pos])
	for e in enemies:
		if is_instance_valid(e) and e.has_method("take_damage"):
			e.take_damage(1.0e9, player)


## Ultimo recurso: arma y hormonas si faltan (anotado) y entra al jefe saltandose el camino.
func _force_boss() -> void:
	var boss: Room = null
	for r in main.dungeon_generator.rooms.values():
		if r.room_type == Room.RoomType.BOSS:
			boss = r
	if boss == null or main.current_room == boss:
		return
	if not main._has_real_weapon():
		_issue("Piso %d: sin arma al forzar el jefe; se equipa una pistola" % _floor_n)
		player.equip_weapon(get_node("/root/ItemDatabase").get_item("pistol_basic"))
	var rm := get_node("/root/RunManager")
	for h in main._missing_hormones():
		_issue("Piso %d: falta la hormona %s al forzar el jefe; se da" % [_floor_n, h])
		rm.hormones[h] = true
	_say("  FUERZA la entrada a la sala del jefe %s" % boss.grid_pos)
	main.call_deferred("_enter_room", boss, null)


## Aleja al jugador de los enemigos dentro de la sala (el punto mas lejano de todos), para que se les reinicie la IA.
func _flee(enemies: Array, delta: float) -> void:
	_flee_t -= delta
	if _flee_goal == Vector2.INF or _flee_t <= 0.0 or player.global_position.distance_to(_flee_goal) < 20.0:
		_flee_t = 2.0
		var best := Vector2.INF
		var bs := -1.0e9
		var keys := _grid.keys()
		for i in 60:
			if keys.is_empty():
				break
			var c: Vector2i = keys[randi() % keys.size()]
			var p := _center(c)
			var d := INF
			for e in enemies:
				d = minf(d, e.global_position.distance_to(p))
			# lejos de ellos pero no demasiado lejos de mi (ruta corta)
			var sc := d - 0.25 * p.distance_to(player.global_position)
			if sc > bs:
				bs = sc
				best = p
		_flee_goal = best
	if _flee_goal != Vector2.INF:
		_steer_to(_flee_goal)
		if _dash_cd <= 0.0 and enemies.any(func(e): return e.global_position.distance_to(player.global_position) < 60.0):
			Input.action_press("dash")
			_dash_cd = 1.2


# ------------------------------------------------------------------ resumen (recoger todo)
## Una vez por segundo: anota cofres y objetos vistos de los pisos que va recorriendo.
func _scan_floor() -> void:
	if not is_instance_valid(main) or main.dungeon_generator == null or not _fl.has(_floor_n):
		return
	var f: Dictionary = _fl[_floor_n]
	var rooms: Dictionary = main.dungeon_generator.rooms
	_watch_outsiders()
	f.rooms_total = rooms.size()
	f["coins"] = _coins_gained.get(_floor_n, 0)
	f.rooms_visited = _visited.size()
	var un := []
	for pos in rooms:
		if not _visited.has(pos):
			var ds := []
			for nb in main.dungeon_generator.room_graph.get(pos, []):
				var d: Door = rooms[nb].door_to(pos)
				if d != null:
					ds.append("desde %s %s" % [Room.RoomType.keys()[rooms[nb].room_type], Door.State.keys()[d.state]] + ("(llave %s)" % d.required_key if d.required_key != "" else "") + ("(intox %d)" % d.required_intoxication_tier if d.required_intoxication_tier > 0 else ""))
			un.append("%s%s [%s]" % [Room.RoomType.keys()[rooms[pos].room_type], pos, "; ".join(ds)])
	f.unvisited = un
	for pos in rooms:
		var r: Room = rooms[pos]
		var seen_room: bool = _visited.has(pos)
		for c in r.pickups_node.get_children() + r.props_node.get_children():
			if not is_instance_valid(c) or c.get_script() == null:
				continue
			var path: String = c.get_script().resource_path
			if path.ends_with("chest.gd") or path.ends_with("chest_locked.gd"):
				var id := c.get_instance_id()
				var opened: bool = c.get("_opened") == true or c.get("opened") == true
				if not f.chests.has(id):
					f.chests[id] = {"kind": "normal" if path.ends_with("/chest.gd") else "llave:" + str(c.get("kind")), "opened": false, "room": "%s%s" % [Room.RoomType.keys()[r.room_type], pos]}
				if opened:
					f.chests[id].opened = true
			elif seen_room and (path.ends_with("item_pickup.gd") or path.ends_with("shop_item.gd")):
				var iid = c.get("item_id")
				if iid != null and str(iid) != "" and str(iid) != "coin":
					f.seen[str(iid)] = true


func _floor_items(n: int) -> Array:
	var out := []
	for it in get_node("/root/RunManager").items_collected:
		if int(it.floor) == n and str(it.id) != "coin" and str(it.id) not in out:
			out.append(str(it.id))
	return out


func _log_floor_summary(n: int) -> void:
	if not _fl.has(n):
		return
	var f: Dictionary = _fl[n]
	var taken := _floor_items(n)
	var coins: int = int(f.get("coins", 0))
	var opened := 0
	var closed := []
	for id in f.chests:
		if f.chests[id].opened:
			opened += 1
		else:
			closed.append("%s en %s" % [f.chests[id].kind, f.chests[id].room])
	var not_taken := []
	for id in f.seen:
		if id not in taken:
			not_taken.append(id)
	_say("  RESUMEN piso %d (%s): salas %d/%d visitadas; cofres abiertos %d/%d; objetos recogidos %d (%s) + %d monedas ganadas; vistos y NO recogidos %d (%s)" % [
		n, f.name, f.rooms_visited, f.rooms_total, opened, f.chests.size(), taken.size(), ", ".join(taken), coins, not_taken.size(), ", ".join(not_taken)])
	if not f.unvisited.is_empty():
		_say("    salas sin visitar: %s" % ", ".join(f.unvisited))
	if not closed.is_empty():
		_say("    cofres sin abrir: %s" % "; ".join(closed))


func _log_summary(title: String) -> void:
	_scan_floor()
	_say("=== %s ===" % title)
	var keys := _fl.keys()
	keys.sort()
	for n in keys:
		_log_floor_summary(n)
	var lore = get_node("/root/LoreDatabase")
	var now: int = lore.get_unlocked_entries().size()
	_say("  CODICE: %d de %d entradas desbloqueadas (%d nuevas en esta partida)" % [now, lore.get_all_entries().size(), now - _codex0])
	var rm := get_node("/root/RunManager")
	_say("  Objetos totales recogidos: %d; monedas ahora: %d; bendiciones: %s" % [rm.items_collected.size(), rm.coins, rm.blessings])


## Enemigos fuera de la sala (nacieron o fueron a parar fuera de los muros): inalcanzables, la sala no se limpia nunca.
## Se anotan con todos los detalles (es un fallo del juego) y, pasados 20 s, se les baja la vida para seguir.
var _outside := {}  # instance_id -> segundos fuera

func _watch_outsiders() -> void:
	var room: Room = main.current_room
	if room == null:
		return
	var size := RoomUtil.size_of(room)
	var alive := {}
	for e in _alive_enemies(room):
		var rel: Vector2 = e.global_position - room.global_position
		if rel.x > -40.0 and rel.y > -40.0 and rel.x < size.x + 40.0 and rel.y < size.y + 40.0:
			continue
		var id: int = e.get_instance_id()
		alive[id] = true
		_outside[id] = float(_outside.get(id, 0.0)) + 1.0
		if _outside[id] == 1.0:
			_issue("Enemigo FUERA de la sala %s %s: %s en %s (sala de %s); script=%s estado=%s vel=%s meta=%s" % [
				Room.RoomType.keys()[room.room_type], room.grid_pos, e.get("enemy_name"), rel, size, e.get_script().resource_path,
				e.get("state"), e.get("velocity"), room.get_meta_list()])
		if _outside[id] >= 20.0 and e.has_method("take_damage"):
			_issue("Enemigo fuera de la sala %s %s sin poder alcanzarlo: se le baja la vida" % [Room.RoomType.keys()[room.room_type], room.grid_pos])
			e.take_damage(1.0e9, player)
	for id in _outside.keys():
		if not alive.has(id):
			_outside.erase(id)


## Diagnostico: el instante en que un enemigo cruza el limite de su sala (de donde viene, a que velocidad, en que estado).
var _last_rel := {}  # instance_id -> posicion relativa del fotograma anterior
var _exit_logged := {}

var _last_pf := 0  # paso de fisica del ultimo _track_exits
var _launch_ms := {}  # instance_id -> ultimo aviso de lanzamiento
var _hist := {}  # instance_id -> ultimas posiciones relativas (una cada 6 fotogramas)

func _track_exits(room: Room, enemies: Array) -> void:
	var size := RoomUtil.size_of(room)
	var now := {}
	for e in enemies:
		var id: int = e.get_instance_id()
		var rel: Vector2 = e.global_position - room.global_position
		now[id] = rel
		# lanzamiento: mas de 16 px por paso de fisica (~1000 px/s) sin ser un dash conocido; anota el contexto
		var pv = _last_rel.get(id)
		if pv != null and pv.distance_to(rel) / float(maxi(1, Engine.get_physics_frames() - _last_pf)) > 16.0 and Time.get_ticks_msec() - int(_launch_ms.get(id, -9999)) > 1500:
			_launch_ms[id] = Time.get_ticks_msec()
			var ai = e.get("ai")
			_say("  LANZADO %s (%s) en %s %s: salto %.0f px en 1 fotograma, de %s a %s; vel=%s estado=%s modo=%s empujado_hace=%d ms capa64_mask=%s sala_forma=%s" % [
				e.get("enemy_name"), e.get_script().resource_path.get_file(), Room.RoomType.keys()[room.room_type], room.grid_pos, pv.distance_to(rel), pv.round(), rel.round(),
				e.get("velocity"), e.get("state"), ai.mode if ai != null else "-", Time.get_ticks_msec() - int(e.get_meta("pushed_ms", -99999)),
				e.get_collision_mask_value(7) if e is CollisionObject2D else "-", room.shape_id])
		if Engine.get_physics_frames() % 6 == 0:
			var h: Array = _hist.get(id, [])
			h.append(rel.round())
			if h.size() > 14:
				h.pop_front()
			_hist[id] = h
		var out := rel.x < -20.0 or rel.y < -20.0 or rel.x > size.x + 20.0 or rel.y > size.y + 20.0
		if out and not _exit_logged.has(id):
			_exit_logged[id] = true
			var prev = _last_rel.get(id)
			_say("  SALE %s de %s %s: antes=%s ahora=%s (salto %s px) vel=%s estado=%s mask=%d capa=%d sala=%s puertas=%s" % [
				e.get("enemy_name"), Room.RoomType.keys()[room.room_type], room.grid_pos, prev, rel,
				"%.0f" % prev.distance_to(rel) if prev != null else "primer fotograma", e.get("velocity"), e.get("state"),
				e.collision_mask, e.collision_layer, size, room.doors.values().map(func(d): return "%s:%d" % [d.get_direction_name(), d.state])])
			_say("    trayectoria (cada 0,1 s): %s" % [_hist.get(id, [])])
			# que hay bajo el enemigo y en el muro por donde salio
			var q := PhysicsPointQueryParameters2D.new()
			q.collide_with_areas = true
			q.collision_mask = 0xFFFFF
			for pt in [e.global_position, e.global_position - Vector2(rel.x, 0).normalized() * 0.0]:
				q.position = pt
				var hits := player.get_world_2d().direct_space_state.intersect_point(q, 8)
				_say("    colisionadores en %s: %s" % [pt - room.global_position, hits.map(func(h): return "%s(capa %d)" % [h.collider.name, h.collider.get("collision_layer") if h.collider.get("collision_layer") != null else -1])])
			var wc: Vector2i = room.walls_tilemap.local_to_map(room.walls_tilemap.to_local(e.global_position))
			_say("    muro: celda %s source=%d | sala shape=%s rect_suelo=%s pos_sala=%s" % [wc, room.walls_tilemap.get_cell_source_id(0, wc), room.shape_id, room.floor_tilemap.get_used_rect(), room.global_position])
	_last_rel = now
	_last_pf = Engine.get_physics_frames()
