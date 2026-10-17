extends CanvasLayer
## Transiciones entre escenas: cortinilla de rombos pixelados (morado/rosa/oro).
## API: Transition.change_scene(path) y Transition.reload().
## Cubre (~0.25 s) -> cambia la escena -> descubre (~0.25 s). Bloquea input
## mientras dura y ignora llamadas repetidas. Funciona con el árbol en pausa.

const SHADER := preload("res://src/shaders/transition.gdshader")
const COVER_TIME := 0.25
const REVEAL_TIME := 0.25

var _rect: ColorRect
var _mat: ShaderMaterial
var _busy := false

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)
	get_viewport().size_changed.connect(_update_size)
	_update_size()
	# Arranque del juego: empieza cubierto y solo "descubre".
	_busy = true
	_set_progress(1.0)
	_reveal.call_deferred()

func _update_size() -> void:
	_mat.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)

func _set_progress(v: float) -> void:
	_mat.set_shader_parameter("progress", v)

func _tween_progress(from: float, to: float, time: float) -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(_set_progress, from, to, time)
	await tw.finished

func _reveal() -> void:
	# Un par de frames para que la escena nueva ya esté dibujada debajo.
	await get_tree().process_frame
	await get_tree().process_frame
	await _tween_progress(1.0, 0.0, REVEAL_TIME)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

func change_scene(path: String) -> void:
	await _run(func(): get_tree().change_scene_to_file(path))

func reload() -> void:
	await _run(func(): get_tree().reload_current_scene())

func _run(swap: Callable) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	await _tween_progress(0.0, 1.0, COVER_TIME)
	swap.call()
	await _reveal()
