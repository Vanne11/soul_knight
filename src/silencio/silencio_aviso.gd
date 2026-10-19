class_name SilencioAviso
extends CanvasLayer

## Aviso de contenido de Las Tierras del Silencio (diseno_E3, seccion 2) y panel "Como buscar ayuda".
##
## El aviso sale CADA VEZ que se cruza al reino (Silencio.setup_floor, tambien al cargar el piso) y NO se
## puede saltar: ni "Saltar", ni "No mostrar mas", ni se cierra con Esc. Solo "Continuar" o "Como buscar
## ayuda". Fondo gris, sin musica, sin espera artificial. Pausa el juego mientras esta abierto.
## (Con --bot, el bot de pruebas, que no tiene a nadie que lo lea, lo continua solo a los 0.3 s.)
##
## "Como buscar ayuda" abre la entrada de codice como_buscar_ayuda (LoreEntry, siempre desbloqueada):
## sin numeros de telefono ni selector de pais. Tambien se abre suelto (open_ayuda) desde el boton del
## HUD, el menu de pausa y la sala S4.

const GROUP := "sil_aviso"
const HELP_ID := "como_buscar_ayuda"
const BG := Color("4b4846")
const TEXT := Color("e4e0d8")

var only_help := false
var _was_paused := false
var _holder: VBoxContainer
var _first: Button


static func open_aviso(host: Node) -> SilencioAviso:
	return _open(host, false)


static func open_ayuda(host: Node) -> SilencioAviso:
	return _open(host, true)


static func _open(host: Node, help: bool) -> SilencioAviso:
	for old in host.get_tree().get_nodes_in_group(GROUP):
		if help:
			return old  # ya hay una pantalla del reino abierta
		old.queue_free()
	var a := SilencioAviso.new()
	a.only_help = help
	host.add_child(a)
	return a


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(GROUP)
	_was_paused = get_tree().paused
	get_tree().paused = true
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_holder = VBoxContainer.new()
	_holder.add_theme_constant_override("separation", 18)
	_holder.custom_minimum_size.x = 620
	center.add_child(_holder)
	if only_help:
		_show_ayuda()
	else:
		_show_aviso()
		if "--bot" in OS.get_cmdline_user_args():
			get_tree().create_timer(0.3, true, false, true).timeout.connect(_close)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo():
		return
	get_viewport().set_input_as_handled()  # Esc no salta el aviso (y no abre la pausa debajo)
	if only_help:
		_close()


func _clear() -> void:
	for c in _holder.get_children():
		_holder.remove_child(c)
		c.queue_free()


func _label(text: String, size := 16, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := HudStyle.pixel_label(text, size, TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = align
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	_holder.add_child(l)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(230, 46)
	b.add_theme_font_override("font", HudStyle.FONT)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("2b2a2c") if state != "hover" else Color("3a383a")
		sb.border_color = Color("e4e0d8") if state == "focus" else Color("8d8984")
		sb.set_border_width_all(2 if state == "focus" else 1)
		sb.set_content_margin_all(8)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(cb)
	return b


func _show_aviso() -> void:
	_clear()
	_label(tr("SIL_AVISO_TITULO"), 32)
	_label(tr("SIL_AVISO_1"))
	_label(tr("SIL_AVISO_2"))
	_label(tr("SIL_AVISO_3"))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_holder.add_child(row)
	_first = _button(tr("SIL_CONTINUAR"), _close)
	row.add_child(_first)
	row.add_child(_button(tr("SIL_AYUDA_BOTON"), _show_ayuda))
	_first.grab_focus.call_deferred()


## Entrada del codice como_buscar_ayuda (titulo y texto traducidos con Loc, como el resto del codice).
func _show_ayuda() -> void:
	_clear()
	var entry = get_node("/root/LoreDatabase").get_entry(HELP_ID)
	_label(Loc.lore_title(entry) if entry else tr("SIL_AYUDA_BOTON"), 32)
	if entry:
		_label(Loc.lore_text(entry), 16, HORIZONTAL_ALIGNMENT_LEFT)
		_label(Loc.lore_flavor(entry), 16)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_holder.add_child(row)
	_first = _button(tr("SIL_VOLVER") if not only_help else tr("SIL_CERRAR"), _close if only_help else _show_aviso)
	row.add_child(_first)
	_first.grab_focus.call_deferred()


func _close() -> void:
	get_tree().paused = _was_paused
	queue_free()
