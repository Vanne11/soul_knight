extends CanvasLayer

## El narrador: solo habla en momentos que importan al jugador (inicio de run y
## de piso, puertas que no se abren, mecanicas nuevas, el jefe, la muerte).
## Nunca durante un combate. Las frases viven en assets/data/narrator/*.json: lines.json
## (las de siempre) y un archivo por bloque (p.ej. tienda.json), fusionados al arrancar
## (ver _load_lines). Asi cada bloque agrega sus frases sin tocar lines.json.
##   Narrator.say("evento")         se encola; hay que pasarla con clic/espacio
##   Narrator.say_first("evento")   solo la primera vez en la run (cuenta como importante)
##   Narrator.say_hero("evento")    "<evento>_<heroe>" si existe; si no, "<evento>"
##   Narrator.get_line("evento")    la frase ya formateada, sin encolarla (pantallas de final)
##   Narrator.toast(titulo, texto)  aviso breve con el mismo estilo; se va solo
##   Narrator.prompt(dueño, texto)  cuadro de "[E] hacer algo" mientras estes cerca
##   Narrator.choose(titulo, opciones) + await Narrator.chosen   eleccion (pausa)
## Todas las cajas se apilan abajo al centro, sin pisarse.
##
## Frecuencia (historia.md, seccion 3). Hay dos prioridades:
##  - IMPORTANTE: jefes, muerte, victoria, entrada a region, eleccion de heroe y la primera vez de
##    cada mecanica (say_first). Salen siempre, tambien con combate (los de jefe/muerte/victoria se
##    ven en plena pelea y se cierran solos; el resto espera a que acabe).
##  - MENOR (todo lo demas, incluidos los eventos de otros bloques): en combate callan; entre una
##    frase y la siguiente pasan al menos MIN_GAP_MS; maximo una por sala; y solo salen el
##    MINOR_CHANCE de las veces.
## Ninguna frase se repite en la misma partida (_said). Para marcar un evento como importante:
## anadir su prefijo a MAJOR_PREFIXES, o pasar major = true en say().

signal chosen(index: int)

const LINES_DIR := "res://assets/data/narrator/"
## Archivo principal: se carga primero y sus claves de traduccion son las de siempre.
const MAIN_FILE := "lines.json"
const MEMORY_PATH := "user://narrator.json"
const CHARS_PER_SEC := 45.0
## Voz del narrador (el "bla-bla"): mas grave que la intro (1.0) y -4 dB, porque
## suena durante toda la frase y tapaba los efectos de la partida.
const VOICE_PITCH := 0.8
const VOICE_DB := -4.0
const TOAST_SECONDS := 4.0
const TOAST_SECONDS_SHORT := 1.8
## Frecuencia: milisegundos minimos entre dos frases y probabilidad de un evento menor.
const MIN_GAP_MS := 45000
const MINOR_CHANCE := 0.3
## Eventos que empiezan asi son importantes (ver arriba).
const MAJOR_PREFIXES := ["boss", "death", "victory", "floor_", "chosen_", "first_run", "run_start", "censura_up", "pz_", "taser_drop"]
## Subconjunto que se muestra aunque haya combate: se cierran solos pasados unos segundos.
const URGENT_PREFIXES := ["boss", "death", "victory"]
const COMBAT_LINGER := 3.5
const NAME_SMALL_WORDS := ["de", "la", "el", "del", "los", "las", "y", "of", "the", "and"]
const NAME_KEEP_UPPER := ["II", "DIU"]
const RARITY_COLORS := ["f2ead6", "7ad67a", "6aa8ff", "c08cff", "ffa64a", "9a9a9a"]

## evento -> frases en espanol (todas las de todos los archivos, en orden de carga)
var _lines: Dictionary = {}
## evento -> claves de traduccion, paralelas a _lines (ver Loc.narr_key)
var _keys: Dictionary = {}
var _memory := {"runs": 0, "deaths": 0, "deaths_by_floor": {}}
var _queue: Array[String] = []
var _showing := false
## cuando una pulsacion paso la frase: el jugador no debe dashear/atacar con ella
var _ate_input_ms := -1000
var _seen: Dictionary = {}  # eventos ya dichos esta run
var _said: Dictionary = {}  # claves de frase ya dichas esta run (jamas se repiten)
var _urgent: Dictionary = {}  # frases (texto encolado) que salen aunque haya combate
var _showing_urgent := false
var _auto_close := 0.0
var _last_say_ms := -MIN_GAP_MS
var _last_say_room: Object = null
var _streak := 0  # muertes seguidas sin que te toquen
## Frase en pantalla tal cual se encolo, y la sala donde salio: si te vas sin
## leerla, el narrador se queja y la vuelve a poner.
var _line_raw := ""
var _line_room: Object = null
var _complaining := false
## Frases que dejaste sin leer esta run. Tiene memoria: con pistas sera rencoroso.
var ignored_count := 0

var _panel: PanelContainer
var _label: RichTextLabel
var _hint: Label
var _tween: Tween
## Voz: texto visible sin bbcode, letras ya procesadas, donde acaba el nombre y tono del hablante
var _plain := ""
var _voiced := 0
var _voice_from := 0
var _voice_pitch := VOICE_PITCH
var _toast: PanelContainer
var _toast_label: RichTextLabel
var _toast_queue: Array = []  # [texto bbcode, segundos]
var _toast_time := 0.0
var _stack: VBoxContainer
var _codex_toast: CodexToast
var _prompt: PanelContainer
var _prompt_label: RichTextLabel
## Quien muestra el cuadro de interaccion ahora: solo el responde a E.
var prompt_owner: Object = null
var _choice: PanelContainer
var _choice_label: RichTextLabel
var _choice_row: VBoxContainer


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	Loc.load_unregistered_translations()  # locale/<bloque>.csv sin registrar en project.godot
	_load_lines()
	_load_memory()
	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_stack.offset_bottom = -16
	_stack.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stack.grow_vertical = Control.GROW_DIRECTION_BEGIN  # crece hacia arriba
	_stack.alignment = BoxContainer.ALIGNMENT_END
	add_child(_stack)
	_toast = _make_box(300)
	_toast_label = _toast.get_child(0).get_child(0)
	_toast_label.add_theme_font_size_override("normal_font_size", 15)
	_prompt = _make_box(300)
	_prompt_label = _prompt.get_child(0).get_child(0)
	_prompt_label.add_theme_font_size_override("normal_font_size", 15)
	_choice = _make_box(360)
	_choice_label = _choice.get_child(0).get_child(0)
	# en columna: las bendiciones traen descripcion y no caben en fila
	_choice_row = VBoxContainer.new()
	_choice_row.add_theme_constant_override("separation", 6)
	_choice.get_child(0).add_child(_choice_row)
	_panel = _make_box(460)
	_label = _panel.get_child(0).get_child(0)
	_hint = Label.new()
	_hint.text = "NARRATOR_HINT"  # clave: el Label la traduce solo y sigue el idioma en vivo
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Color("b08d4a"))
	_panel.get_child(0).add_child(_hint)
	_codex_toast = CodexToast.new()
	add_child(_codex_toast)
	var ge := get_node("/root/GlobalEvents")
	ge.run_started.connect(_on_run_started)
	ge.player_died.connect(_on_player_died)
	ge.item_picked_up.connect(_on_item_picked_up)
	ge.player_intoxication_changed.connect(_on_intox)
	ge.lore_unlocked.connect(_on_lore_unlocked)
	ge.player_damaged.connect(_on_player_damaged)
	ge.enemy_killed.connect(_on_enemy_killed)


## Caja con el estilo del narrador, apilada en orden de creacion; ancho 2*half_width.
func _make_box(half_width: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size.x = half_width * 2
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_theme_stylebox_override("panel", HudStyle.panel_box(16))
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("normal_font_size", 18)
	label.add_theme_color_override("default_color", Color("f2ead6"))
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(label)
	panel.add_child(vb)
	panel.visible = false
	_stack.add_child(panel)
	return panel


func say(event: String, args: Dictionary = {}, major := false) -> void:
	major = major or is_major(event)
	var urgent := _has_prefix(event, URGENT_PREFIXES)
	if not major:
		if _in_combat() or not _minor_allowed():
			return
	var line := _pick(event)
	if line == "":
		return
	_last_say_ms = Time.get_ticks_msec()
	_last_say_room = _current_room()
	_enqueue(_format(line, args), urgent)


## Frase de "<evento>_<heroe>" y, si ese heroe no tiene, la general "<evento>".
func say_hero(event: String, args: Dictionary = {}) -> void:
	var ev := "%s_%s" % [event, get_node("/root/RunManager").character]
	say(ev if has_lines(ev) else event, args)


## La frase ya formateada (con {boss}, {hero}...), sin encolarla ni gastarla: pantallas de final.
func get_line(event: String, args: Dictionary = {}) -> String:
	var lines := get_lines(event)
	return _format(lines[0], args) if not lines.is_empty() else ""


static func _has_prefix(event: String, prefixes: Array) -> bool:
	for p in prefixes:
		if event.begins_with(p):
			return true
	return false


static func is_major(event: String) -> bool:
	return _has_prefix(event, MAJOR_PREFIXES)


## Un evento menor puede salir ahora: pasaron 45 s, no hubo otra frase en esta sala y sale el 30%.
func _minor_allowed() -> bool:
	if Time.get_ticks_msec() - _last_say_ms < MIN_GAP_MS:
		return false
	var room := _current_room()
	if room != null and room == _last_say_room:
		return false
	return randf() < MINOR_CHANCE


func _format(line: String, args: Dictionary) -> String:
	args = args.duplicate()
	args.merge({"deaths": _memory.deaths, "runs": _memory.runs}, false)
	var rm := get_node("/root/RunManager")
	args.merge({"hero": Loc.char_field(rm.character, "name")}, false)
	if "{boss" in line:
		args.merge({"boss": _boss_name(false), "boss_final": _boss_name(true)}, false)
	return line.format(args)


## Nombre del jefe de la region actual (o del ultimo piso) tal como sale en esta partida
## (original o alternativo), con mayusculas normales: "Doña Cera Caliente".
func _boss_name(final: bool) -> String:
	var rm := get_node("/root/RunManager")
	var total := RunManager.route_size()  # la ruta del heroe (el ultimo piso NO es el ultimo archivo)
	var n: int = rm.current_floor
	var fd: Dictionary = rm.floor_data()
	if final:
		n = total
		fd = RunManager.floor_at(n)
	elif not RunManager.floor_has_boss(n):
		# 1a etapa: el jefe del reino es el del piso siguiente de la misma region
		for i in range(n + 1, total + 1):
			var nf := RunManager.floor_at(i)
			if nf.region == fd.region and str(nf.boss) != "":
				fd = nf
				n = i
				break
	if str(fd.get("boss", "")) == "":
		return ""
	return _nice_name(Loc.enemy_name(BossPicker.pick(fd, rm.current_seed, n).name))


## "SU PUDOROSIDAD, LA HOJA DE PARRA" -> "Su Pudorosidad, la Hoja de Parra".
static func _nice_name(boss_name: String) -> String:
	var out: PackedStringArray = []
	for w in boss_name.split(" "):
		var bare := w.trim_suffix(",")
		var tail := w.substr(bare.length())
		if bare in NAME_KEEP_UPPER:
			out.append(w)
		elif out.size() > 0 and bare.to_lower() in NAME_SMALL_WORDS:
			out.append(bare.to_lower() + tail)
		else:
			out.append(bare.substr(0, 1).to_upper() + bare.substr(1).to_lower() + tail)
	return " ".join(out)


## Mete la frase en la cola (maximo 3). Las de combate van delante de las demas y cortan la que
## este en pantalla si esa no lo es.
func _enqueue(text: String, urgent := false) -> void:
	if urgent:
		_urgent[text] = true
		var at := 0
		while at < _queue.size() and _urgent.has(_queue[at]):
			at += 1
		_queue.insert(at, text)
		if _showing and not _showing_urgent:
			_showing = false
	else:
		_queue.append(text)
	while _queue.size() > 3:
		var drop := 0
		while drop < _queue.size() - 1 and _urgent.has(_queue[drop]):
			drop += 1
		_queue.remove_at(drop)


## Texto ya escrito (inscripciones de lore). "HABLANTE: texto" pone el nombre.
func say_raw(line: String) -> void:
	if not _in_combat():
		_queue.append(line)


func say_first(event: String, args: Dictionary = {}, major := true) -> void:
	if not _seen.has(event):
		_seen[event] = true
		say(event, args, major)


func toast(title: String, text: String = "", color := "b08d4a") -> void:
	var bb := "[color=#%s][b]%s[/b][/color]" % [color, title]
	if text != "":
		bb += "\n[font_size=13]%s[/font_size]" % text
	_toast_queue.append([bb, TOAST_SECONDS if text != "" else TOAST_SECONDS_SHORT])
	if _toast_queue.size() > 3:
		_toast_queue.pop_front()


func prompt(owner: Object, text: String) -> void:
	prompt_owner = owner
	_prompt_label.text = text
	_prompt.visible = true


func clear_prompt(owner: Object) -> void:
	if prompt_owner == owner:
		prompt_owner = null
		_prompt.visible = false


## Pausa el juego hasta elegir (clic o teclas 1..n). El resultado llega por chosen.
func choose(title: String, options: Array) -> void:
	_choice_label.text = title
	for b in _choice_row.get_children():
		b.queue_free()
	for i in options.size():
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, options[i]]
		b.add_theme_font_size_override("font_size", 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_pick_choice.bind(i))
		_choice_row.add_child(b)
	_choice.visible = true
	get_tree().paused = true


func _pick_choice(i: int) -> void:
	if not _choice.visible:
		return
	_choice.visible = false
	get_tree().paused = false
	_ate_input_ms = Time.get_ticks_msec()  # el clic no dispara
	chosen.emit(i)


func get_lines(event: String) -> Array:
	var out := []
	var raw: Array = _lines.get(event, [])
	for i in raw.size():
		out.append(Loc.narr_line(_keys[event][i], raw[i]))
	return out


func has_lines(event: String) -> bool:
	return _lines.has(event)


## Sala con enemigos vivos y jugador vivo (la frase de muerte si debe salir).
func _in_combat() -> bool:
	var main := get_tree().get_first_node_in_group("main")
	if main == null or main.current_room == null or get_node("/root/PlayerStats").current_health <= 0.0:
		return false
	return main.current_room.enemies_spawned.any(func(e): return is_instance_valid(e) and e.current_health > 0.0)


func is_talking() -> bool:
	return _showing or not _queue.is_empty()


func _current_room() -> Object:
	var main := get_tree().get_first_node_in_group("main")
	return main.current_room if main else null


## Te fuiste de la sala con una frase sin leer: queja, y la frase vuelve detras.
## Si tambien pasas de la queja, no insiste: queda la frase pendiente y ya.
func _left_unread() -> void:
	if _complaining:
		_showing = false
		return
	var complaint := _pick("ignored")
	if complaint == "":
		_showing = false
		return
	ignored_count += 1
	_queue.push_front(_line_raw)
	_show(complaint)
	_complaining = true


## true si la pulsacion de este frame se uso para pasar dialogo.
func ate_input() -> bool:
	return Time.get_ticks_msec() - _ate_input_ms < 150


func _advance() -> void:
	if _label.visible_ratio < 1.0:
		if _tween:
			_tween.kill()
		_label.visible_ratio = 1.0
		_voiced = _plain.length()  # completado de golpe: la voz calla
		return
	_showing = false
	_panel.visible = false


## Frase al azar del evento que no haya salido ya esta partida ("" si no queda ninguna).
func _pick(event: String) -> String:
	if not _lines.has(event):
		push_warning("Narrator: no hay frases para '%s'" % event)
		return ""
	var free: Array = []
	for i in _lines[event].size():
		if not _said.has(_keys[event][i]):
			free.append(i)
	if free.is_empty():
		return ""
	var idx: int = free[randi() % free.size()]
	_said[_keys[event][idx]] = true
	return Loc.narr_line(_keys[event][idx], _lines[event][idx])


func _show(line: String, urgent := false) -> void:
	_showing_urgent = urgent
	_auto_close = 0.0
	if urgent and _in_combat():
		_auto_close = line.length() / CHARS_PER_SEC + COMBAT_LINGER
	var speaker := "NARRADOR"
	var color := "b08d4a"
	var colon := line.find(": ")
	if colon > 0 and colon < 36 and line.substr(0, colon) == line.substr(0, colon).to_upper():
		speaker = line.substr(0, colon)
		line = line.substr(colon + 2)
		color = "c84a4a"
	_line_raw = line if speaker == "NARRADOR" else "%s: %s" % [speaker, line]
	_line_room = _current_room()
	_complaining = false
	_label.text = "[color=#%s][b]%s:[/b][/color] %s" % [color, tr("NARRATOR_NAME") if speaker == "NARRADOR" else speaker, line]
	_label.visible_ratio = 0.0
	# Voz: el nombre del hablante no suena, solo el texto. Su pitch sale de un hash
	# estable del nombre (0.65-1.35); sin hablante, el tono grave del narrador.
	_plain = _label.get_parsed_text()
	_voice_from = _plain.length() - _plain_len(line)
	_voiced = 0
	_voice_pitch = VOICE_PITCH if speaker == "NARRADOR" else 0.65 + float(absi(speaker.hash()) % 71) / 100.0
	if speaker != "NARRADOR" and absf(_voice_pitch - VOICE_PITCH) < 0.08:
		_voice_pitch += 0.25  # que ningun personaje suene igual que el narrador
	_panel.visible = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "visible_ratio", 1.0, line.length() / CHARS_PER_SEC)
	_showing = true


## Largo del texto visible de una frase (sin bbcode).
func _plain_len(line: String) -> int:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.text = line
	var n := l.get_parsed_text().length()
	l.free()
	return n


## Una silaba cada 2 letras nuevas (no en espacios ni puntuacion), como en la intro.
## Con el menu de pausa abierto no suena, pero el avance se descuenta para que
## no suene de golpe al volver. Si pausa el propio narrador (elecciones) si suena.
func _voice_tick() -> void:
	var total := _plain.length()
	var now := int(roundf(_label.visible_ratio * total))
	if now <= _voiced:
		return
	var mute := not _panel.visible or get_tree().get_first_node_in_group("pause_menu") != null
	for i in range(_voiced, now):
		if mute or i < _voice_from or i % 2 != 0:
			continue
		var ch := _plain[i]
		if ch.strip_edges() != "" and not ch in ".,;:!?¡¿…-—()\"'":
			Sound.voice(ch, _voice_pitch, VOICE_DB)
	_voiced = now


func _process(delta: float) -> void:
	_voice_tick()
	_fade_near_player(delta)
	_hint.visible = _label.visible_ratio >= 1.0
	var room := _current_room()
	if _showing and room != null and _line_room != null and room != _line_room:
		_left_unread()
	# En combate no se ve ni avanza nada; lo pendiente espera a que acabe.
	var combat := _in_combat()
	_panel.visible = _showing and (not combat or _showing_urgent)
	if _showing and _auto_close > 0.0:
		_auto_close -= delta
		if _auto_close <= 0.0:
			_showing = false
			_panel.visible = false
	if not _showing and not _queue.is_empty() and (not combat or _urgent.has(_queue[0])):
		var text: String = _queue.pop_front()
		_show(text, _urgent.has(text))
		_urgent.erase(text)
	if prompt_owner != null and not is_instance_valid(prompt_owner):
		clear_prompt(prompt_owner)
	_toast_time -= delta
	if _toast_time <= 0.0:
		_toast.visible = false
		if not _toast_queue.is_empty():
			var t: Array = _toast_queue.pop_front()
			_toast_label.text = t[0]
			_toast_time = t[1]
			_toast.visible = true


## Rectangulo en pantalla que ocupan ahora las cajas visibles (narrador, aviso, eleccion...);
## tamano 0 si no hay ninguna. Lo usa el panel de manos para subir en vez de quedar tapado.
func occupied_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for c in _stack.get_children():
		if c is Control and c.visible:
			var cr: Rect2 = c.get_global_rect()
			r = cr if first else r.merge(cr)
			first = false
	return r


## Como los matorrales: si el jugador baja hasta las cajas, se vuelven transparentes para
## no taparlo (y lo que tenga cerca). Con una eleccion abierta no: hay que leerla.
const FADE_ALPHA := 0.3
const FADE_MARGIN := 24.0

func _fade_near_player(delta: float) -> void:
	var target := 1.0
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player and not _choice.visible:
		# Rectangulo del heroe en pantalla (cuerpo de ~32x48 por el zoom de la camara).
		var xf := player.get_global_transform_with_canvas()
		var half := Vector2(16, 24) * xf.get_scale()
		var body := Rect2(xf.origin - half, half * 2.0)
		if _stack.get_global_rect().grow(FADE_MARGIN).intersects(body):
			target = FADE_ALPHA
	_stack.modulate.a = move_toward(_stack.modulate.a, target, delta * 4.0)


func _input(event: InputEvent) -> void:
	if _choice.visible and event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.physical_keycode - KEY_1
		if n >= 0 and n < _choice_row.get_child_count():
			_pick_choice(n)
		return
	if not _panel.visible or not event.is_pressed() or event.is_echo():
		return
	# Jugando, el texto se pasa con Enter (o Select en el mando): espacio y clic son dash y disparo
	# y no deben comerse. Fuera de la partida (menus, sin heroe) tambien sirven clic y espacio.
	var enter: bool = event is InputEventKey and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]
	var pad: bool = event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK
	var playing := get_tree().get_first_node_in_group("player") != null
	var click: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	var space: bool = event is InputEventKey and event.physical_keycode == KEY_SPACE
	# Con controles tactiles se avanza tocando la caja del narrador.
	var tap: bool = click and playing and TouchControls.is_active() and _panel.get_global_rect().has_point(event.position)
	if enter or pad or tap or (not playing and (click or space)):
		# Sin set_input_as_handled: en menus el mismo clic debe pulsar el boton.
		_advance()
		if not playing:
			_ate_input_ms = Time.get_ticks_msec()


# ---------------------------------------------------------------- eventos
func _on_run_started(_seed: int) -> void:
	_memory.runs += 1
	_save_memory()
	_seen.clear()
	_said.clear()
	_urgent.clear()
	_streak = 0
	ignored_count = 0
	var freed: int = get_node("/root/RunManager").liberated.size()
	if _memory.runs == 1:
		say("first_run")  # despues basta con la presentacion del piso
	elif freed > 0 and freed < RunManager.regions().size():
		say("run_start_progress", {"n": freed, "left": RunManager.regions().size() - freed})


## Poca vida: la primera vez de la run. Y se corta la racha de muertes sin que te toquen.
func _on_player_damaged(_amount: float, _source: Node) -> void:
	_streak = 0
	var ps := get_node("/root/PlayerStats")
	if ps.current_health > 0.0 and ps.current_health <= ps.max_health * 0.25:
		say_first("low_health", {}, false)


func _on_enemy_killed(_enemy: Node, _killer: Node) -> void:
	_streak += 1
	if _streak == 5:
		say("kill_streak")


func _on_player_died() -> void:
	var floor_n: int = get_node("/root/RunManager").current_floor
	var key := str(floor_n)
	_memory.deaths += 1
	_memory.deaths_by_floor[key] = int(_memory.deaths_by_floor.get(key, 0)) + 1
	_save_memory()
	_queue.clear()
	_urgent.clear()
	_showing = false  # la frase de muerte no espera a que pases la anterior
	var n: int = _memory.deaths_by_floor[key]
	var main := get_tree().get_first_node_in_group("main")
	if main and main.current_room and main.current_room.room_type == Room.RoomType.BOSS \
			and RunManager.floor_has_boss(get_node("/root/RunManager").current_floor):
		say("death_boss")  # {boss} lo pone _format
	elif n >= 3 and randf() < 0.5:
		say("death_same_floor", {"floor": floor_n, "n": n})
	else:
		say("death")


## Confirmacion corta: la descripcion ya salio en el cuadro de [E] antes de cogerlo.
func _on_item_picked_up(item: Variant, _qty: int) -> void:
	if "moneda" in item.tags:
		return  # el contador del HUD ya lo dice
	toast("+" + Loc.item_name(item), "", RARITY_COLORS[clampi(item.rarity, 0, RARITY_COLORS.size() - 1)])


## Cada nivel de borrachera se explica una vez por run, al alcanzarlo.
func _on_intox(_level: float, tier: int) -> void:
	if tier > 0:
		say_first("intox_%d" % tier)


func _on_lore_unlocked(entry_id: String) -> void:
	var entry = get_node("/root/LoreDatabase").get_entry(entry_id)
	if entry:
		_codex_toast.show_entry(entry)  # panel con imagen (antes: toast de una linea)


# ---------------------------------------------------------------- frases
## Archivos de frases: lines.json primero y luego el resto de *.json en orden
## alfabetico (determinista). ResourceLoader.list_directory lista igual en el editor
## que en un export (ya resuelve .import/.remap dentro del .pck).
static func narrator_files() -> PackedStringArray:
	var extra: Array[String] = []
	for f in ResourceLoader.list_directory(LINES_DIR):
		if f.get_extension() == "json" and f != MAIN_FILE:
			extra.append(f)
	extra.sort()
	var out := PackedStringArray()
	if ResourceLoader.exists(LINES_DIR + MAIN_FILE):
		out.append(MAIN_FILE)
	out.append_array(extra)
	return out


## Fusiona todos los archivos. Si dos traen el mismo evento, sus frases se concatenan
## (las de lines.json primero). Cada frase guarda su clave de traduccion, que depende
## solo de su archivo, evento e indice dentro de ese archivo: agregar o quitar otro
## archivo no mueve las traducciones. Las claves "_algo" son comentarios, no eventos.
func _load_lines() -> void:
	_lines.clear()
	_keys.clear()
	var used := {}  # clave -> archivo, para avisar si dos frases chocan
	for file in narrator_files():
		var res = load(LINES_DIR + file)
		if not (res is JSON) or not (res.data is Dictionary):
			push_warning("Narrator: %s no es un diccionario JSON valido" % file)
			continue
		var stem := file.get_basename()
		for event in res.data:
			var lines = res.data[event]
			if String(event).begins_with("_"):
				continue
			if not (lines is Array):
				push_warning("Narrator: %s: '%s' debe ser una lista de frases" % [file, event])
				continue
			if not _lines.has(event):
				_lines[event] = []
				_keys[event] = []
			for i in lines.size():
				var key := Loc.narr_key(stem, event, i)
				if used.has(key):
					push_warning("Narrator: la clave %s (%s) choca con otra de %s" % [key, file, used[key]])
				used[key] = file
				_lines[event].append(String(lines[i]))
				_keys[event].append(key)


# ---------------------------------------------------------------- memoria
func _load_memory() -> void:
	if not FileAccess.file_exists(MEMORY_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(MEMORY_PATH))
	if data is Dictionary:
		_memory.merge(data, true)
		_memory.runs = int(_memory.runs)  # JSON devuelve floats: "Run 3.0" queda fatal
		_memory.deaths = int(_memory.deaths)


func _save_memory() -> void:
	var f := FileAccess.open(MEMORY_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_memory))
