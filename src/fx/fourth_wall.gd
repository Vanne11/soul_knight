extends Node

## Cuarta pared: los heroes te hablan a su manera y el juego "sabe de ti".
## SOLO usa: la hora local (jugar de madrugada), el foco de LA VENTANA DEL JUEGO
## (NOTIFICATION_APPLICATION_FOCUS_OUT/IN) y su propio historial en user://fourth_wall.json
## (partidas/muertes por heroe, jefe que mas te mata, nombre opcional). Nada de otras apps,
## archivos ni datos del sistema.
##
## Las frases estan en assets/data/narrator/cuarta_pared.json (las fusiona el Narrator; las
## de los heroes empiezan por "NOMBRE: " y salen con su voz) y salen por Narrator.say_raw:
## nunca en combate (el Narrator las descarta), nunca con otra frase en pantalla, nunca
## bloquean. Frecuencia baja: GAP_S de enfriamiento entre comentarios ambientales.
##
## Enganches (ninguno pisa archivos de otros): GlobalEvents (run_started, player_died,
## room_cleared, enemy_killed), Settings.changed, y desde la interfaz:
##   main_menu.gd -> menu_opened() al abrir, `await farewell()` al salir
##   intro.gd     -> select_shown() al mostrar la eleccion de heroe
## Los heroes miran a camara con Player.look_at_camera() cuando hablan.

const SAVE_PATH := "user://fourth_wall.json"
## segundos entre dos comentarios ambientales (idle, pausa, discusion, arranque, madrugada)
const GAP_S := 150.0
const IDLE_S := 20.0           # sin tocar nada
const PAUSE_COUNT := 4         # pausas en la run para el comentario
const AWAY_MIN_S := 8.0        # ventana perdida al menos esto para comentarlo al volver
const AWAY_MAX_S := 7200.0
const FOCUS_COOL_S := 240.0
const ARGUE_CHANCE := 0.06     # por sala limpiada
const ARGUE_COOL_S := 420.0
const START_CHANCE := 0.4      # comentario de historial/chispa al empezar una run
const NIGHT_CHANCE := 0.7      # una vez por sesion, de 0:00 a 5:59
const BOSS_LINE_CHANCE := 0.7
const HEROES := ["pitocles", "vulvalquiria", "ornitorrinco"]

var data := {"name": "", "asked": false, "runs": {}, "deaths": {}, "boss_deaths": {}, "runs_total": 0, "last_seen": 0}
## Para pruebas: hora fingida (-1 = la real) y modo bot forzado.
var test_hour := -1
var test_bot := false

var _bags: Dictionary = {}
var _last_pick: Dictionary = {}
var _cool_until := 0.0
var _focus_last := -1e9
var _argue_last := -1e9
var _last_input := 0.0
var _tick_t := 0.0
var _away_at := -1.0
var _back_pending := -1.0      # instante en que se pidio el comentario (o -1)
var _pauses := 0
var _pause_open := false
var _start_pending := -1.0
var _main_seen := -1.0
var _night_done := false
var _in_menu := false
var _menu_seen := false
var _lang_changed := false
var _music_joked := false
var _last_music := 100
var _last_locale := "es"
var _prompt: NamePrompt = null
var _farewell_skip := false
var _farewell_open := false

var player_name: String:
	get:
		return String(data.name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_last_input = _now()
	var ge := get_node("/root/GlobalEvents")
	ge.run_started.connect(_on_run_started)
	ge.player_died.connect(_on_player_died)
	ge.room_cleared.connect(_on_room_cleared)
	ge.enemy_killed.connect(_on_enemy_killed)
	var st := get_node_or_null("/root/Settings")
	if st:
		_last_music = st.music_volume
		_last_locale = st.locale
		st.changed.connect(_on_settings_changed)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _notification(what: int) -> void:
	# SOLO el foco de la ventana del juego: no se lee nada mas de nada.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_away_at = _now()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if _away_at < 0.0:
			return
		var away := _now() - _away_at
		_away_at = -1.0
		if away >= AWAY_MIN_S and away <= AWAY_MAX_S and _in_run() and _now() - _focus_last > FOCUS_COOL_S:
			_back_pending = _now()


# ------------------------------------------------------------------ estado
func _main() -> Node:
	return get_tree().get_first_node_in_group("main")


func _player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _in_run() -> bool:
	return _main() != null and _player() != null


## El bot (tools/autoplay) no debe recibir dialogos ni comentarios.
func _is_bot() -> bool:
	if test_bot:
		return true
	var cs := get_tree().current_scene
	return (cs != null and "autoplay" in cs.scene_file_path) or "--bot" in OS.get_cmdline_user_args()


func _hero() -> String:
	return String(get_node("/root/RunManager").character)


func _hour() -> int:
	return test_hour if test_hour >= 0 else int(Time.get_datetime_dict_from_system().hour)


func _is_night() -> bool:
	return _hour() < 6


func _time_text() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%d:%02d" % [_hour(), int(t.minute)]


## Se puede hablar ahora: sin otra frase en pantalla, sin combate, jugador vivo, sin pausa.
func _can_talk(menu := false, queue_ok := false) -> bool:
	var nar := get_node("/root/Narrator")
	if nar.is_talking() and not queue_ok:
		return false
	if menu:
		return true
	if get_tree().paused or nar._in_combat():
		return false
	return get_node("/root/PlayerStats").current_health > 0.0


func _ambient_ok() -> bool:
	return _now() >= _cool_until


# ------------------------------------------------------------------ frases
func _args(extra := {}) -> Dictionary:
	var h := _hero()
	var a := {"name": player_name, "time": _time_text(), "runs": int(data.runs_total),
		"hero_runs": int(data.runs.get(h, 0)), "hero_deaths": int(data.deaths.get(h, 0))}
	a.merge(extra, true)
	return a


## Frase del evento (traducida), con {name} solo si hay nombre y, aun asi, poco: el nombre
## se usa con moderacion (20% de las veces que el evento tiene frases con nombre).
func _pick(event: String, args: Dictionary) -> String:
	var pool: Array = get_node("/root/Narrator").get_lines(event)
	if pool.is_empty():
		return ""
	var named := pool.filter(func(l): return "{name}" in l)
	var plain := pool.filter(func(l): return not ("{name}" in l))
	if player_name == "" or named.is_empty():
		pool = plain
	elif plain.is_empty() or randf() < 0.2:
		pool = named
	else:
		pool = plain
	if pool.is_empty():
		return ""
	var bag: Array = _bags.get(event, []).filter(func(l): return l in pool)
	if bag.is_empty():
		bag = pool.duplicate()
		bag.shuffle()
		if bag.size() > 1 and bag.back() == _last_pick.get(event, ""):
			bag.reverse()  # que no repita la misma dos veces seguidas
	var line: String = bag.pop_back()
	_bags[event] = bag
	_last_pick[event] = line
	return line.format(args)


## Dice un evento ("a || b" = dos intervenciones seguidas). Devuelve si salio.
func _speak(event: String, args := {}, look := false, menu := false, queue_ok := false) -> bool:
	var nar := get_node("/root/Narrator")
	if not nar.has_lines(event) or not _can_talk(menu, queue_ok):
		return false
	var line := _pick(event, _args(args))
	if line == "":
		return false
	for part in line.split(" || "):
		nar.say_raw(part)
	if look:
		_look()
	return true


## Evento propio del heroe actual: "base_<heroe>"; si no existe, el general "base".
func _speak_hero(base: String, args := {}) -> bool:
	var ev := "%s_%s" % [base, _hero()]
	if not get_node("/root/Narrator").has_lines(ev):
		return _speak(base, args)
	return _speak(ev, args, true)


func _ambient(ok: bool) -> bool:
	if ok:
		_cool_until = _now() + GAP_S
	return ok


func _look() -> void:
	var p := _player()
	if p and p.has_method("look_at_camera"):
		p.look_at_camera(3.0)


# ------------------------------------------------------------------ bucle
func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		_last_input = _now()
		if _farewell_open:
			_farewell_skip = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		_last_input = _now()


func _process(delta: float) -> void:
	_tick_t += delta
	if _tick_t < 0.5:
		return
	_tick_t = 0.0
	tick()


func tick() -> void:
	var t := _now()
	var player := _player()
	var main := _main()
	if Input.is_anything_pressed() or (player is CharacterBody2D and player.velocity.length() > 5.0):
		_last_input = t
	if main == null:
		_main_seen = -1.0
		_pause_open = false
		return
	if _main_seen < 0.0:
		_main_seen = t
	# pausa abierta -> cerrada: si ya llevas muchas, comenta
	var paused_menu := get_tree().get_first_node_in_group("pause_menu") != null
	if paused_menu and not _pause_open:
		_pauses += 1
	elif not paused_menu and _pause_open and _pauses >= PAUSE_COUNT and _ambient_ok() and not _is_bot():
		if _ambient(_speak_hero("pause")):
			_pauses = 0
	_pause_open = paused_menu
	if paused_menu or player == null or _is_bot():
		return
	# volver de otra ventana (prioridad: ignora el enfriamiento ambiental)
	if _back_pending >= 0.0:
		if t - _back_pending > 90.0:
			_back_pending = -1.0
		elif _can_talk():
			_back_pending = -1.0
			_focus_last = t
			var ok := false
			if randf() < 0.3:
				ok = _speak("back")
			else:
				ok = _speak_hero("back")
			if ok:
				_cool_until = maxf(_cool_until, t + GAP_S * 0.5)
			return
	# comentario al empezar la run, unos segundos despues de entrar al piso
	if _start_pending >= 0.0:
		if t - _start_pending > 90.0:
			_start_pending = -1.0
		elif t - _main_seen > 7.0 and _can_talk():
			_start_pending = -1.0
			_run_start_comment()
			return
	# quieto
	if t - _last_input > IDLE_S and _ambient_ok() and _can_talk():
		_last_input = t  # no repite hasta otros 20 s de quietud
		_ambient(_speak_hero("idle"))


func _run_start_comment() -> void:
	var h := _hero()
	if _is_night() and not _night_done:
		_night_done = true
		if randf() < NIGHT_CHANCE and _ambient(_speak_hero("night")):
			return
	if int(data.runs_total) <= 1 or not _ambient_ok() or randf() > START_CHANCE:
		return
	var opts := ["start"]
	if int(data.deaths.get(h, 0)) >= 3:
		opts.append("hist")
	var fav := favorite()
	if fav == h:
		opts.append("fav")
	elif fav != "" and int(data.runs.get(fav, 0)) >= int(data.runs.get(h, 0)) + 3:
		opts.append("jealous")
	var boss := top_boss()
	if boss.n >= 3:
		opts.append("boss_killer")
	var pick: String = opts[randi() % opts.size()]
	if pick == "boss_killer":
		_ambient(_speak("boss_killer", {"boss": Loc.enemy_name(boss.name), "n": boss.n}))
	else:
		var extra := {}
		if fav != "":
			extra["fav"] = Loc.char_field(fav, "name")
		_ambient(_speak_hero(pick, extra))


# ------------------------------------------------------------------ historial
## Heroe con mas partidas, solo si es claro (>=4 y estrictamente mas que los otros).
func favorite() -> String:
	var best := ""
	var best_n := 0
	var tie := false
	for h in HEROES:
		var n := int(data.runs.get(h, 0))
		if n > best_n:
			best = h
			best_n = n
			tie = false
		elif n == best_n and n > 0:
			tie = true
	return best if best_n >= 4 and not tie else ""


## {name: nombre en espanol del jefe, n: veces que te mato} del que mas te mata.
func top_boss() -> Dictionary:
	var best := {"name": "", "n": 0}
	for b in data.boss_deaths:
		if int(data.boss_deaths[b]) > best.n:
			best = {"name": String(b), "n": int(data.boss_deaths[b])}
	return best


func _bump(dict_name: String, key: String) -> void:
	data[dict_name][key] = int(data[dict_name].get(key, 0)) + 1


func _on_run_started(_seed: int) -> void:
	_in_menu = false
	_bump("runs", _hero())
	data.runs_total = int(data.runs_total) + 1
	data.last_seen = int(Time.get_unix_time_from_system())
	_save()
	_pauses = 0
	_start_pending = _now()
	_main_seen = -1.0
	_last_input = _now()


func _on_player_died() -> void:
	_bump("deaths", _hero())
	var main := _main()
	var rm := get_node("/root/RunManager")
	if main and main.current_room and main.current_room.room_type == Room.RoomType.BOSS \
			and RunManager.floor_has_boss(rm.current_floor):
		_bump("boss_deaths", String(rm.floor_data().boss_name))
	_start_pending = -1.0
	_back_pending = -1.0
	_save()


func _on_room_cleared(_room: Node) -> void:
	if _is_bot() or _now() - _argue_last < ARGUE_COOL_S or randf() > ARGUE_CHANCE:
		return
	await get_tree().create_timer(1.5).timeout
	if _ambient_ok() and _speak_hero("argue"):
		_argue_last = _now()
		_ambient(true)


func _on_enemy_killed(enemy: Node, _killer: Node) -> void:
	if not (enemy is EnemyBoss) or _is_bot() or randf() > BOSS_LINE_CHANCE:
		return
	var rm := get_node("/root/RunManager")
	var boss_es := String(rm.floor_data().get("boss_name", ""))
	if boss_es == "" or enemy.enemy_name != boss_es:
		return  # clones y esbirros no
	await get_tree().create_timer(1.8).timeout
	var ev := "boss_dead_first" if rm.current_floor <= 2 else "boss_dead"
	var nm := Loc.enemy_name(boss_es)
	if _speak(ev, {"boss_up": nm.to_upper()}, false, false, true):
		_ambient(true)


# ------------------------------------------------------------------ menu, eleccion, cierre
## main_menu.gd lo llama al abrir el menu principal.
func menu_opened() -> void:
	_in_menu = true
	if _is_bot():
		return
	var first := not _menu_seen
	_menu_seen = true
	var last := int(data.last_seen)
	var days := int((Time.get_unix_time_from_system() - last) / 86400.0) if last > 0 else 0
	data.last_seen = int(Time.get_unix_time_from_system())
	_save()
	await get_tree().create_timer(1.2).timeout
	if not _in_menu:
		return
	if not bool(data.asked):
		ask_name()
	elif _lang_changed:
		_lang_changed = false
		_speak("menu_lang", {}, false, true)
	elif first and int(data.runs_total) >= 1 and randf() < 0.5:
		if days >= 3:
			_speak("menu_days", {"days": days, "deaths": _total_deaths()}, false, true)
		else:
			_speak("menu_return", {"deaths": _total_deaths()}, false, true)


func _total_deaths() -> int:
	var n := 0
	for h in data.deaths:
		n += int(data.deaths[h])
	return n


## intro.gd lo llama al mostrar la eleccion de heroe: uno de los tres opina desde las sombras.
func select_shown() -> void:
	if _is_bot() or randf() > 0.6:
		return
	await get_tree().create_timer(1.0).timeout
	var h: String = HEROES[randi() % HEROES.size()]
	_speak("select_" + h, {}, false, true)


## Pide el nombre (UNA vez: pase lo que pase queda marcado como preguntado).
func ask_name() -> void:
	if _prompt != null or _is_bot():
		return
	_prompt = NamePrompt.new()
	_prompt.finished.connect(_on_name_done)
	add_child(_prompt)


func _on_name_done(text: String) -> void:
	_prompt = null
	set_player_name(text)


func set_player_name(text: String) -> void:
	data.name = NamePrompt.clean(text)
	data.asked = true
	_save()


## main_menu.gd: `await FourthWall.farewell()` antes de cerrar. Dura ~2.4 s y se salta con
## cualquier tecla o clic.
func farewell() -> void:
	if _is_bot() or DisplayServer.get_name() == "headless":
		return
	var nar := get_node("/root/Narrator")
	var ev := "farewell"
	if int(data.runs_total) > 0 and randf() < 0.5:
		ev = "farewell_" + _hero()
		if not nar.has_lines(ev):
			ev = "farewell"
	var line := _pick(ev, _args())
	if line == "":
		return
	var speaker: String = tr("NARRATOR_NAME")
	var color := "b08d4a"
	var colon := line.find(": ")
	if colon > 0 and colon < 30 and line.substr(0, colon) == line.substr(0, colon).to_upper():
		speaker = line.substr(0, colon)
		line = line.substr(colon + 2)
		color = "c84a4a"
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HudStyle.panel_box(16))
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.custom_minimum_size.x = 640
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -110
	panel.offset_bottom = -30
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.add_theme_font_size_override("normal_font_size", 18)
	rt.text = "[color=#%s][b]%s:[/b][/color] %s" % [color, speaker, line]
	panel.add_child(rt)
	layer.add_child(panel)
	_farewell_skip = false
	_farewell_open = true
	var t := _now()
	while _now() - t < 2.4 and not _farewell_skip:
		await get_tree().process_frame
	_farewell_open = false
	layer.queue_free()


func _on_settings_changed() -> void:
	var st := get_node("/root/Settings")
	if _in_menu and not _music_joked and _last_music > 0 and st.music_volume == 0 and not _is_bot():
		_music_joked = true
		_speak("menu_music_off", {}, false, true)
	_last_music = st.music_volume
	if st.locale != _last_locale:
		_last_locale = st.locale
		_lang_changed = _in_menu


# ------------------------------------------------------------------ guardado
func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if d is Dictionary:
		data.merge(d, true)


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
