class_name MedalToast
extends Control

## Aviso "Medalla ganada": panel discreto con el icono y el nivel (color del nivel) que entra desde
## el borde izquierdo, se queda unos segundos y sale. Uno a la vez (cola). Va bajo el aviso del
## codice y lejos del centro y de las barras: no tapa la pelea. Lo crea el autoload Medallas.

const THUMB := 48
const STAY := 3.2
const SLIDE := 0.35
const Y := 392.0
const MARGIN := 10.0

var _queue: Array = []  # [Texture2D, nivel_txt, nombre, color]
var _busy := false
var _panel: PanelContainer
var _pic: TextureRect
var _head: Label
var _title: Label
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", HudStyle.panel_box(10))
	_panel.visible = false
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_pic = TextureRect.new()
	_pic.custom_minimum_size = Vector2(THUMB, THUMB)
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	_head = HudStyle.pixel_label("", 8, HudStyle.GOLD, true)
	col.add_child(_head)
	_title = HudStyle.pixel_label("", 16)
	_title.custom_minimum_size.x = 230
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)


## Encola el aviso (icono, texto del nivel, nombre de la medalla, color del nivel).
func show_medal(icon: Texture2D, level_text: String, medal_name: String, color: Color) -> void:
	_queue.append([icon, level_text, medal_name, color])
	if not _busy:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		_panel.visible = false
		return
	_busy = true
	var item: Array = _queue.pop_front()
	_pic.texture = item[0]
	_head.text = tr("MEDAL_TOAST_HEAD") % item[1]
	_head.add_theme_color_override("font_color", item[3])
	_title.text = item[2]
	_panel.reset_size()
	var w := roundf(_panel.size.x)
	_panel.position = Vector2(-w, Y)
	_panel.visible = true
	Sound.play("puzzle_solve")
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_x, -w, MARGIN, SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(STAY)
	_tween.tween_method(_set_x, MARGIN, -w, SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_next)


func _set_x(x: float) -> void:
	_panel.position = Vector2(roundf(x), Y)
