class_name PauseMenu
extends CanvasLayer

## Menu de pausa de la partida. Lo abre main.gd con la accion "pause" (Esc);
## Esc otra vez o CONTINUAR reanudan. Pausa el arbol mientras existe.
## VOLVER AL MENU abandona la run SIN contarla (no se llama a end_run: ni huesos
## ni partida jugada), igual que cerrar el juego a mitad de partida.

const MENU_SCENE := "res://src/scenes/main_menu.tscn"

var _root: Control
var _holder: Control  # contenedor centrado donde vive la lista o los ajustes
var _first_btn: Button


static func open(host: Node) -> PauseMenu:
	var m := PauseMenu.new()
	host.add_child(m)
	return m


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	get_tree().paused = true

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = HudStyle.menu_theme()
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.06, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_holder = VBoxContainer.new()
	center.add_child(_holder)
	_show_main()


func _show_main() -> void:
	_clear_holder()
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	_holder.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := HudStyle.pixel_label(tr("PAUSE_TITLE"), 32, Color("ff4f9a"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_first_btn = _button(v, tr("PAUSE_RESUME"), close)
	_button(v, tr("BTREE_TAB"), _show_blessings)
	if Silencio.active():
		_button(v, tr("SIL_AYUDA_BOTON"), Silencio.ayuda)  # siempre a mano en el Silencio
	_button(v, tr("PAUSE_SETTINGS"), _show_settings)
	_button(v, tr("PAUSE_MENU"), _to_menu)
	_button(v, tr("PAUSE_QUIT"), func(): get_tree().quit())
	_add_rules(v)
	var note := Label.new()
	note.text = tr("PAUSE_NOTE")
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 340
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", Color(0.8, 0.72, 0.78))
	v.add_child(note)
	_first_btn.grab_focus.call_deferred()


## Reglas activas de la partida: nivel de Censura y maldiciones de pactos mayores.
func _add_rules(v: Control) -> void:
	var lines: Array[String] = []
	for id in Censura.rule_ids():
		lines.append("• " + Censura.rule_name(id))
	for id in Censura.pact_curses:
		lines.append("• %s: %s" % [Censura.curse_name(id), Censura.curse_curse(id)])
	if lines.is_empty():
		return
	var head := tr("CENSURA_BADGE") % Censura.level if Censura.level > 0 else tr("PAUSE_PACTS")
	var l := Label.new()
	l.text = head + "\n" + "\n".join(lines)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 340
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(1.0, 0.55, 0.65))
	v.add_child(l)


func _show_settings() -> void:
	_clear_holder()
	var sp := SettingsPanel.new()
	_holder.add_child(sp)
	sp.closed.connect(_show_main)
	sp.focus_first.call_deferred()


func _show_blessings() -> void:
	_clear_holder()
	var bt := BlessingTree.new()
	_holder.add_child(bt)
	bt.closed.connect(_show_main)
	bt.focus_first.call_deferred()


func _clear_holder() -> void:
	for c in _holder.get_children():
		_holder.remove_child(c)
		c.queue_free()


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text  # texto final antes de juice_button
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(cb)
	HudStyle.juice_button(b)
	parent.add_child(b)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if _holder.get_child_count() > 0 and (_holder.get_child(0) is SettingsPanel or _holder.get_child(0) is BlessingTree):
			_show_main()
		else:
			close()


func close() -> void:
	PauseMenu.release(get_tree(), self)
	queue_free()


## Despausa solo si no queda otra pantalla que pausa: los timers de recompensa (bendicion, eleccion
## del jefe) corren aunque este pausado y podian abrirse sobre este menu; al cerrarse una, el juego
## seguia corriendo detras de la otra.
static func release(tree: SceneTree, closing: Node = null) -> void:
	for g in ["pause_menu", "blessing_picker"]:
		for n in tree.get_nodes_in_group(g):
			if n != closing and not n.is_queued_for_deletion():
				return
	if closing != Narrator and Narrator.choice_open():
		return
	tree.paused = false


func _to_menu() -> void:
	get_tree().paused = false
	Transition.change_scene(MENU_SCENE)
