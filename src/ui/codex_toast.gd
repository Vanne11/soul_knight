class_name CodexToast
extends Control

## Aviso "Nueva entrada en el codice": panel dorado con la imagen de la entrada
## que entra deslizandose desde la izquierda, se queda un rato y sale.
## Nodo aparte del sistema de toasts del narrador: ese es una caja de texto
## apilada abajo (cola de 3, texto bbcode); este lleva imagen y su propia
## animacion en el lateral, asi que no se mezclan ni se pisan.
## Varios seguidos van en cola, de uno en uno.

const THUMB := 48
const STAY := 3.0
const SLIDE := 0.35
const Y := 300.0  # bajo la franja del HUD y las bendiciones, lejos del minimapa y del narrador
const MARGIN := 10.0

var _queue: Array = []  # [Texture2D|null, titulo]
var _busy := false
var _panel: PanelContainer
var _pic: TextureRect
var _title: Label
var _head: Label
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # sigue aunque el narrador pause
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", HudStyle.panel_box(12))
	_panel.visible = false
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)
	_pic = TextureRect.new()
	_pic.custom_minimum_size = Vector2(THUMB, THUMB)
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_pic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var head := HudStyle.pixel_label(tr("CODEX_TOAST_NEW"), 8, HudStyle.GOLD, true)
	_head = head
	col.add_child(head)
	_title = HudStyle.pixel_label("", 16)
	_title.custom_minimum_size.x = 260
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_title)


## Encola el aviso de una entrada ya desbloqueada.
func show_entry(entry) -> void:
	var img: Texture2D = null
	var tex: Texture2D = CodexArt.image(entry)
	if tex:
		img = CodexArt.thumb(tex, THUMB, false, true)
	_queue.append([img, Loc.lore_title(entry)])
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
	_pic.visible = item[0] != null
	_title.text = item[1]
	_head.text = tr("CODEX_TOAST_NEW")  # idioma actual
	_panel.reset_size()
	var w := roundf(_panel.size.x)
	_panel.position = Vector2(-w, Y)
	_panel.visible = true
	Sound.play("puzzle_solve")
	if _tween:
		_tween.kill()
	_tween = create_tween()
	# posiciones enteras: tween por pasos de 1 px para que el pixel art no tiemble
	_tween.tween_method(_set_x, -w, MARGIN, SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(STAY)
	_tween.tween_method(_set_x, MARGIN, -w, SLIDE).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_next)


func _set_x(x: float) -> void:
	_panel.position = Vector2(roundf(x), Y)
