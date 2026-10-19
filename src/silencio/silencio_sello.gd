class_name SilencioSello
extends CanvasLayer

## El sello "Si" de S5 (diseno_E3, 4.2 B): aparece en el HUD cuando alguien dice que si a algo concreto,
## con una barra que se consume mientras dura (el si vale para una cosa y un rato). Se puede quebrar
## (el "Para" de la estacion Reversible), agrietar (si dijeron si sin saber para que) o desaparecer (el si
## no incluia otra cosa). No es un premio: no da nada, no cuenta, no se guarda.

const GROUP := "sil_sello"
const INK := Color("e4e0d8")

var _box: Control
var _t := 0.0
var _secs := 5.0
var _state := "idle"     # idle | live | broken
var _crack := false
var _shake := 0.0
var _label_text := ""


static func create(main: Node, label: String) -> SilencioSello:
	for old in main.get_tree().get_nodes_in_group(GROUP):
		old.queue_free()
	var s := SilencioSello.new()
	s._label_text = label
	main.add_child(s)
	return s


func _ready() -> void:
	layer = 6
	add_to_group(GROUP)
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.position = Vector2(40, HUD.BAND + 130)
	_box.custom_minimum_size = Vector2(96, 44)
	_box.draw.connect(_draw_box)
	add_child(_box)
	visible = false


## Empieza a consumirse (secs segundos). grieta: el si se dio sin saber para que.
func start(secs: float, cracked := false) -> void:
	_secs = secs
	_t = 0.0
	_crack = cracked
	_state = "live"
	visible = true
	_box.queue_redraw()


## Se rompe de golpe ("Para.").
func shatter() -> void:
	if _state != "live":
		return
	_state = "broken"
	_shake = 0.5
	get_tree().create_timer(0.9).timeout.connect(vanish)


func vanish() -> void:
	_state = "idle"
	visible = false


func is_live() -> bool:
	return _state == "live"


func _process(delta: float) -> void:
	if _state == "live":
		_t += delta
		if _t >= _secs:
			vanish()
	_shake = maxf(0.0, _shake - delta)
	_box.queue_redraw()


func _draw_box() -> void:
	var off := Vector2(randf_range(-2.0, 2.0), 0.0) if _shake > 0.0 else Vector2.ZERO
	var a := 1.0
	var r := Rect2(off, Vector2(96, 44))
	_box.draw_rect(r, Color(0.17, 0.165, 0.17, 0.92))
	_box.draw_rect(r, Color(0.55, 0.53, 0.5), false, 1.0)
	_box.draw_string(HudStyle.FONT_BOLD, off + Vector2(0, 20), _label_text, HORIZONTAL_ALIGNMENT_CENTER, 96, 18, INK)
	var left := 1.0 - clampf(_t / _secs, 0.0, 1.0)
	var bar := Rect2(off + Vector2(8, 30), Vector2(80, 6))
	_box.draw_rect(bar, Color(0.1, 0.1, 0.11))
	if _state == "live":
		_box.draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Color(0.92, 0.85, 0.62, a))
	if _crack or _state == "broken":
		var c := INK.darkened(0.2)
		_box.draw_polyline(PackedVector2Array([off + Vector2(46, 2), off + Vector2(40, 14), off + Vector2(52, 22), off + Vector2(44, 42)]), c, 1.5)
	if _state == "broken":
		_box.draw_line(off + Vector2(0, 2), off + Vector2(96, 42), Color(0.1, 0.1, 0.11), 2.0)
