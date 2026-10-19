class_name MedalFinale
extends CanvasLayer

## Pantalla especial de DESNUDO INTEGRAL ("¡Desnudaste el juego!"): velo oscuro, rayos que giran,
## la medalla de cristal entra con rebote y destellos. Pausa el juego mientras dura; se cierra con
## cualquier tecla o clic (tras 1,5 s) o sola a los 25 s. Lo lanza el autoload Medallas.

const MIN_SHOW := 1.5
const AUTO_CLOSE := 25.0
const ICON_SCALE := 9.0

var _t := 0.0
var _was_paused := false
var _closing := false
var _rays: Control
var _pic: TextureRect
var _dim: ColorRect


## Dibuja los rayos y los destellos (Control con _draw propio).
class Rays extends Control:
	var spin := 0.0
	var life := 0.0
	var sparks: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 77
		for i in 36:
			sparks.append([rng.randf(), rng.randf(), rng.randf_range(0.0, TAU), rng.randf_range(0.6, 1.6)])

	func _process(delta: float) -> void:
		spin += delta * 0.35
		life += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0 + Vector2(0, -40)
		var a := clampf(life / 0.8, 0.0, 1.0)
		var n := 14
		for i in n:
			var ang := spin + float(i) * TAU / float(n)
			var w := TAU / float(n) * 0.32
			var r := maxf(size.x, size.y)
			var col := Color(0.62, 0.9, 1.0, 0.16 * a) if i % 2 == 0 else Color(1.0, 0.55, 0.85, 0.12 * a)
			draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(ang - w) * r, c + Vector2.from_angle(ang + w) * r]), col)
		for s in sparks:
			var tw: float = 0.5 + 0.5 * sin(life * 3.0 * float(s[3]) + float(s[2]))
			var p := Vector2(float(s[0]) * size.x, float(s[1]) * size.y)
			var k := 2.0 + 3.0 * tw
			var sc := Color(1, 1, 1, 0.8 * tw * a)
			draw_rect(Rect2(p - Vector2(k, 1), Vector2(k * 2, 2)), sc)
			draw_rect(Rect2(p - Vector2(1, k), Vector2(2, k * 2)), sc)


func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(root)
	_dim = ColorRect.new()
	_dim.color = Color(0.03, 0.01, 0.06, 0.0)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dim)
	_rays = Rays.new()
	_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_rays)
	var center := Vector2(640, 320)
	_pic = TextureRect.new()
	_pic.texture = Medallas.icono(Medallas.FINAL_ID)
	_pic.custom_minimum_size = Vector2(32, 32)
	_pic.size = Vector2(32, 32)
	_pic.pivot_offset = Vector2(16, 16)
	_pic.scale = Vector2.ZERO
	_pic.position = center - Vector2(16, 16) + Vector2(0, -40)
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pic)
	var title := HudStyle.pixel_label(tr("MEDAL_FINALE_TITLE"), 48, Color("9be8ff"), true)
	var sub := HudStyle.pixel_label(tr("MEDAL_FINALE_SUB"), 24, Color("ff8ad8"), true)
	var cont := HudStyle.pixel_label(tr("MEDAL_FINALE_CONT"), 16, HudStyle.CREAM)
	for l in [title, sub, cont]:
		l.set_anchors_preset(Control.PRESET_TOP_WIDE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.modulate.a = 0.0
		root.add_child(l)
	title.position.y = 468
	sub.position.y = 540
	cont.position.y = 620
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_dim, "color:a", 0.88, 0.7)
	tw.tween_property(_pic, "scale", Vector2(ICON_SCALE, ICON_SCALE), 1.0).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title, "modulate:a", 1.0, 0.6).set_delay(1.1)
	tw.tween_property(sub, "modulate:a", 1.0, 0.6).set_delay(1.6)
	tw.tween_property(cont, "modulate:a", 1.0, 0.6).set_delay(2.6)
	Sound.play("floor_complete")


func _process(delta: float) -> void:
	_t += delta
	if _pic != null and not _closing:
		_pic.position.y = (320.0 - 16.0 - 40.0) + sin(_t * 2.2) * 6.0
	if _t > AUTO_CLOSE:
		_close()


func _input(event: InputEvent) -> void:
	if _t < MIN_SHOW or _closing:
		return
	if (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventJoypadButton and event.pressed):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(_dim, "color:a", 0.0, 0.4)
	tw.parallel().tween_property(_pic, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		get_tree().paused = _was_paused
		queue_free())
