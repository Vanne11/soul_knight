extends CanvasLayer

## El narrador: subtitulos constantes que comentan todo lo que haces.
## Molesto a proposito. Las frases viven en assets/data/narrator/lines.json.
## Uso desde cualquier script:
##   Narrator.say("evento")               charla normal (se descarta si ya esta hablando)
##   Narrator.say("evento", {...}, true)  frase importante (se encola, nunca se pierde)
##   Narrator.notify("miss"|"hit_enemy"|"dash"|"no_stamina")  contadores de conducta

const LINES_PATH := "res://assets/data/narrator/lines.json"
const MEMORY_PATH := "user://narrator.json"
const CHARS_PER_SEC := 45.0
## Habla poco: momentos clave siempre; el resto, como mucho una vez cada 45 s.
const CHATTER_COOLDOWN := 45.0
const IDLE_SECONDS := 30.0

var _lines: Dictionary = {}
var _bags: Dictionary = {}
var _memory := {"runs": 0, "deaths": 0, "deaths_by_floor": {}}
var _queue: Array[String] = []
var _cooldown := 0.0
var _hide_timer := 0.0
var _interrupt_in := 0.0
var _last_line := ""
var _idle := 0.0
var _miss_streak := 0
var _dash_times: Array[float] = []
var _kills_clean := 0
var _low_health_said := false
var _last_shields := 0.0
var _intox_tier := 0
var _seen: Dictionary = {}  # eventos ya comentados esta run

var _panel: PanelContainer
var _label: RichTextLabel
var _tween: Tween


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lines = load(LINES_PATH).data
	_load_memory()
	_build_ui()
	var ge := get_node("/root/GlobalEvents")
	ge.run_started.connect(_on_run_started)
	ge.player_damaged.connect(func(_a, _s): _on_player_hit())
	ge.player_died.connect(_on_player_died)
	ge.enemy_killed.connect(_on_enemy_killed)
	ge.item_picked_up.connect(_on_item_picked_up)
	ge.player_intoxication_changed.connect(_on_intox)
	ge.lore_unlocked.connect(_on_lore_unlocked)
	var ps := get_node("/root/PlayerStats")
	ps.shields_changed.connect(_on_shields_changed)
	ps.health_changed.connect(_on_health_changed)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -460
	_panel.offset_right = 460
	_panel.offset_top = -110
	_panel.offset_bottom = -16
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.04, 0.06, 0.88)
	box.border_color = Color("b08d4a")
	box.set_border_width_all(2)
	box.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", box)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("normal_font_size", 18)
	_label.add_theme_color_override("default_color", Color("f2ead6"))
	_panel.add_child(_label)
	_panel.visible = false
	add_child(_panel)


func say(event: String, args: Dictionary = {}, important := false) -> void:
	if not important and (_cooldown > 0.0 or _hide_timer > 0.0):
		return
	var line := _pick(event)
	if line == "":
		return
	args.merge({"deaths": _memory.deaths, "runs": _memory.runs}, false)
	# Molesto a proposito: a veces repite lo ultimo en vez de decir algo nuevo.
	args.merge({"hero": get_node("/root/RunManager").character_data().name}, false)
	line = line.format(args)
	if not important and _last_line != "" and randf() < 0.03:
		line = _pick("repeat_prefix") + _last_line
	_queue.append(line)
	if _queue.size() > 4:
		_queue.pop_front()
	_cooldown = CHATTER_COOLDOWN


## La primera vez en la run es importante (se dice seguro); las siguientes, charla.
func say_first(event: String, args: Dictionary = {}) -> void:
	say(event, args, not _seen.has(event))
	_seen[event] = true


func get_lines(event: String) -> Array:
	return _lines.get(event, [])


func notify(kind: String) -> void:
	match kind:
		"miss":
			_miss_streak += 1
			if _miss_streak >= 3:
				_miss_streak = 0
				say("miss")
		"hit_enemy":
			_miss_streak = 0
		"dash":
			var now := Time.get_ticks_msec() / 1000.0
			_dash_times.append(now)
			_dash_times = _dash_times.filter(func(t): return now - t < 2.5)
			if _dash_times.size() >= 4:
				_dash_times.clear()
				say("dash_spam")
		"no_stamina":
			say("no_stamina")


func has_lines(event: String) -> bool:
	return _lines.has(event)


func is_talking() -> bool:
	return _hide_timer > 0.0 or not _queue.is_empty()


func _pick(event: String) -> String:
	if not _lines.has(event):
		push_warning("Narrator: no hay frases para '%s'" % event)
		return ""
	var bag: Array = _bags.get(event, [])
	if bag.is_empty():
		bag = _lines[event].duplicate()
		bag.shuffle()
		_bags[event] = bag
	return bag.pop_back()


func _show(line: String) -> void:
	var speaker := "NARRADOR"
	var color := "b08d4a"
	var colon := line.find(": ")
	if colon > 0 and colon < 30 and line.substr(0, colon) == line.substr(0, colon).to_upper():
		speaker = line.substr(0, colon)
		line = line.substr(colon + 2)
		color = "c84a4a"
	_label.text = "[color=#%s][b]%s:[/b][/color] %s" % [color, speaker, line]
	_label.visible_ratio = 0.0
	_panel.visible = true
	var type_time := line.length() / CHARS_PER_SEC
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "visible_ratio", 1.0, type_time)
	_hide_timer = type_time + 1.8 + line.length() * 0.025
	_last_line = line
	if speaker == "NARRADOR" and randf() < 0.04:
		_interrupt_in = _hide_timer - 0.6


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	if _interrupt_in > 0.0:
		_interrupt_in -= delta
		if _interrupt_in <= 0.0:
			say("interrupt", {}, true)
	if _hide_timer > 0.0:
		_hide_timer -= delta
		if _hide_timer <= 0.0:
			_panel.visible = false
	elif not _queue.is_empty():
		_show(_queue.pop_front())
	# Inactividad: solo cuenta durante el juego, no en menus.
	if get_tree().paused or get_tree().get_first_node_in_group("player") == null:
		_idle = 0.0
		return
	_idle += delta
	if _idle >= IDLE_SECONDS:
		_idle = -10.0  # la siguiente queja tarda mas
		say("idle")


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if _idle > 0.0:
			_idle = 0.0


# ---------------------------------------------------------------- eventos
func _on_run_started(_seed: int) -> void:
	_memory.runs += 1
	_save_memory()
	_kills_clean = 0
	_intox_tier = 0
	_low_health_said = false
	_seen.clear()
	_cooldown = 0.0
	say("first_run" if _memory.runs == 1 else "run_start", {}, true)


func _on_player_hit() -> void:
	_kills_clean = 0
	if not _seen.has("player_hit") or randf() < 0.15:
		say_first("player_hit")


func _on_shields_changed(current: float, _max: float) -> void:
	if current < _last_shields:
		_on_player_hit()
		if current <= 0.0 and randf() < 0.5:
			say("shield_broken")
	_last_shields = current


func _on_health_changed(current: float, max_hp: float) -> void:
	if max_hp <= 0.0:
		return
	if current / max_hp < 0.25 and current > 0.0 and not _low_health_said:
		_low_health_said = true
		say("low_health", {}, true)
	elif current / max_hp > 0.5:
		_low_health_said = false


func _on_player_died() -> void:
	var floor_n: int = get_node("/root/RunManager").current_floor
	var key := str(floor_n)
	_memory.deaths += 1
	_memory.deaths_by_floor[key] = int(_memory.deaths_by_floor.get(key, 0)) + 1
	_save_memory()
	_queue.clear()
	var n: int = _memory.deaths_by_floor[key]
	if n >= 3 and randf() < 0.5:
		say("death_same_floor", {"floor": floor_n, "n": n}, true)
	else:
		say("death", {}, true)


func _on_enemy_killed(enemy: Node, _killer: Node) -> void:
	if enemy.is_in_group("boss"):
		return  # el jefe tiene sus propias frases
	_kills_clean += 1
	if not _seen.has("kill_first"):
		say_first("kill_first")
	elif _kills_clean == 5:
		say("kill_streak")
	elif randf() < 0.1:
		say("kill")


func _on_item_picked_up(item: Variant, _qty: int) -> void:
	var tags: Array = item.tags
	var event := "pickup_generic"
	if "intoxicante" in tags:
		event = "pickup_alcohol"
	elif "arma" in tags:
		event = "pickup_weapon"
	elif "curación" in tags:
		event = "pickup_heal"
	elif "reliquia" in tags:
		event = "pickup_relic"
	elif "llave" in tags:
		event = "pickup_key"
	if "moneda" in tags or "hormona" in tags:
		return  # las hormonas tienen sus propias frases (alergia / ornitorrinco)
	say_first(event, {"item": item.display_name})


func _on_intox(_level: float, tier: int) -> void:
	if tier > _intox_tier:
		say("intox_%d" % tier, {}, true)
	elif tier == 0 and _intox_tier > 0:
		say("intox_sober")
	_intox_tier = tier


func _on_lore_unlocked(entry_id: String) -> void:
	var entry = get_node("/root/LoreDatabase").get_entry(entry_id)
	if entry:
		say("lore_unlocked", {"name": entry.title})


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
