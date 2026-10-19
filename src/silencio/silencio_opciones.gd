class_name SilencioOpciones
extends CanvasLayer

## Opciones de una situacion del Silencio (S5 Cinco puertas, S6 El pasillo): una fila de botones planos
## abajo en el centro, sin puntaje ni "mejor opcion" (diseno_E3, secciones 3 y 4). No pausa el juego ni
## frena al heroe: la sala las muestra mientras estes cerca de lo que corresponde y las quita al irte.
## Se elige con el raton, con [E] (el boton enfocado) o con Tab / ui_accept. Si cambian las opciones,
## el foco vuelve al primer boton. Una opcion "off" se ve apagada y no hace nada.

const TEXT := Color("e4e0d8")
const GROUP := "sil_opciones"

var _row: HBoxContainer
var _sig := ""


static func create(main: Node) -> SilencioOpciones:
	var o := SilencioOpciones.new()
	main.add_child(o)
	return o


func _ready() -> void:
	layer = 8
	add_to_group(GROUP)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 10)
	_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_row.offset_bottom = -190
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_row)
	visible = false


## items: [{text, cb: Callable, off?: bool}]. Si son las mismas de antes no toca nada (ni el foco).
func set_items(items: Array) -> void:
	var sig := "|".join(items.map(func(i): return str(i.text) + ("!" if i.get("off", false) else "")))
	if sig == _sig and visible:
		return
	_sig = sig
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	if items.is_empty():
		visible = false
		return
	for it in items:
		_row.add_child(_button(it))
	visible = true
	if _row.get_child_count() > 0:
		(_row.get_child(0) as Button).grab_focus.call_deferred()
	Silencio.hint(tr("SIL_OPCIONES_HINT"))


func clear() -> void:
	if visible:
		set_items([])
		Silencio.hint("")


func _button(it: Dictionary) -> Button:
	var b := Button.new()
	b.text = str(it.text)
	b.custom_minimum_size = Vector2(150, 40)
	b.add_theme_font_override("font", HudStyle.FONT)
	b.add_theme_font_size_override("font_size", 16)
	var off: bool = it.get("off", false)
	b.add_theme_color_override("font_color", TEXT if not off else Color(0.6, 0.58, 0.56))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("2b2a2c") if state != "hover" else Color("3a383a")
		sb.border_color = Color("e4e0d8") if state == "focus" else Color("8d8984")
		sb.set_border_width_all(2 if state == "focus" else 1)
		sb.set_content_margin_all(8)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(it.cb)
	return b


## [E] pulsa el boton enfocado (la tecla de interactuar es la de todo el juego).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("interact") or event.is_echo():
		return
	var f := get_viewport().gui_get_focus_owner()
	if f is Button and f.get_parent() == _row:
		(f as Button).pressed.emit()
		get_viewport().set_input_as_handled()
