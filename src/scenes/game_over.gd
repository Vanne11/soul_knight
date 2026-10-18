extends CanvasLayer

## Pantalla de muerte (o de victoria): ilustracion a pantalla completa, el insulto
## cae rebotando, las cifras suben contando y los botones esperan abajo.

@onready var _game_controller: GameController = get_node("/root/GameController")

const INSULTS := [
	"GAMEOVER_INSULT_1",
	"GAMEOVER_INSULT_2",
	"GAMEOVER_INSULT_3",
	"GAMEOVER_INSULT_4",
	"GAMEOVER_INSULT_5",
	"GAMEOVER_INSULT_6",
	"GAMEOVER_INSULT_7",
]

var _root: Control


func _ready() -> void:
	var rm = _game_controller.get_run_manager()
	var run_data = rm.get_run_data()
	var victory: bool = rm.last_run_victory
	var floor_n: int = run_data.get("floor", 1)
	var kills: int = run_data.get("enemies_killed", 0)
	var time_sec := int(run_data.get("time", 0))

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = HudStyle.menu_theme()
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root)

	var art := TextureRect.new()
	art.texture = load("res://assets/sprites/ui/screens/%s.png" % ("victory" if victory else "gameover"))
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(art)

	# titulo: dos capas (sombra dura + color) que caen desde arriba y rebotan
	var title_text: String = tr("GAMEOVER_VICTORY_TITLE") if victory else tr(INSULTS[RNG.randi_range(0, INSULTS.size() - 1)])
	var title := Control.new()
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(title)
	for l in [[Vector2(6, 6), Color("1a0b26")], [Vector2.ZERO, Color("7fe0a0") if victory else Color("ff3b4a")]]:
		var t := HudStyle.pixel_label(title_text, 48, l[1], true)
		t.add_theme_constant_override("shadow_offset_x", 0)
		t.add_theme_constant_override("shadow_offset_y", 0)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.position = Vector2(-640, 0) + l[0]
		t.size = Vector2(1280, 64)
		title.add_child(t)
	title.position.y = -90
	var drop := create_tween()
	drop.tween_property(title, "position:y", 28.0, 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	drop.tween_callback(func(): Sound.play("crack"))

	if victory:  # final propio del heroe (historia.md, seccion 7), bajo el titulo
		var ending: String = Narrator.get_line("ending_" + str(rm.character))
		if ending != "":
			var sub := HudStyle.pixel_label(ending, 18, HudStyle.CREAM, true)
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
			sub.offset_left = -520
			sub.offset_right = 520
			sub.offset_top = 96
			sub.modulate.a = 0.0
			_root.add_child(sub)
			create_tween().tween_property(sub, "modulate:a", 1.0, 0.8).set_delay(1.0)

	# cifras de la partida en un panel dorado (izquierda: el centro es de la ilustracion)
	var panel := PanelContainer.new()
	panel.position = Vector2(36, 150)
	panel.custom_minimum_size = Vector2(320, 0)
	_root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(HudStyle.pixel_label(tr("GAMEOVER_RUN"), 16, HudStyle.GOLD, true))
	var rows := [
		["stairs", tr("GAMEOVER_FLOOR"), floor_n, ""],
		["skull", tr("GAMEOVER_ENEMIES"), kills, ""],
		["clock", tr("GAMEOVER_TIME"), time_sec, "time"],
		["bone", tr("GAMEOVER_BONES"), rm.last_huesos, "+"],
	]
	var delay := 0.6
	for r in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.add_child(HudStyle.icon(r[0]))
		var name_l := HudStyle.pixel_label(r[1], 16)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var val := HudStyle.pixel_label("0", 16, HudStyle.GOLD if r[0] == "bone" else HudStyle.CREAM, true)
		row.add_child(val)
		box.add_child(row)
		_count_up(val, int(r[2]), r[3], delay)
		delay += 0.25
	var hint := Label.new()
	hint.text = tr("GAMEOVER_BONES_TOTAL") % rm.meta_currency
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 280
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.8, 0.72, 0.78))
	box.add_child(hint)

	# botones abajo, centrados
	var buttons := HBoxContainer.new()
	buttons.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	buttons.offset_top = -86
	buttons.offset_bottom = -36
	buttons.offset_left = -400
	buttons.offset_right = 400
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	_root.add_child(buttons)
	var retry := _button(buttons, tr("GAMEOVER_RETRY"), _on_retry)
	_button(buttons, tr("GAMEOVER_MENU"), _on_menu)
	_button(buttons, tr("GAMEOVER_QUIT"), _on_quit)
	retry.grab_focus.call_deferred()
	_add_fact()


## Un "¿Sabias que...?" breve sobre los botones: aparece despues de las cifras, sin
## pedir nada y distinto cada vez (Edu no repite dentro de la sesion).
func _add_fact() -> void:
	var fact := Edu.next_fact()
	if fact == "":
		return
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -380
	box.offset_right = 380
	box.offset_top = -236
	box.offset_bottom = -132
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := HudStyle.pixel_label(tr("EDU_FACT_LABEL"), 14, HudStyle.GOLD, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	var body := HudStyle.pixel_label(fact, 15, HudStyle.CREAM, true)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	box.modulate.a = 0.0
	_root.add_child(box)
	create_tween().tween_property(box, "modulate:a", 1.0, 0.6).set_delay(1.8)


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 48)
	b.pressed.connect(cb)
	HudStyle.juice_button(b)
	parent.add_child(b)
	return b


## Numero que sube de 0 a su valor con un tic por paso.
func _count_up(label: Label, target: int, suffix: String, delay: float) -> void:
	var show := func(v: int) -> String:
		if suffix == "time":
			return "%d:%02d" % [v / 60, v % 60]
		return ("+%d" if suffix == "+" else "%d") % v
	label.text = show.call(0)
	var t := create_tween()
	t.tween_interval(delay)
	t.tween_method(func(v: float): label.text = show.call(int(v)), 0.0, float(target), 0.6)
	t.tween_callback(func(): Sound.voice("o", 1.4))


func _on_retry() -> void:
	_game_controller.get_run_manager().start_new_run()
	Transition.change_scene("res://src/scenes/main.tscn")

func _on_menu() -> void:
	Transition.change_scene("res://src/scenes/main_menu.tscn")

func _on_quit() -> void:
	get_tree().quit()
