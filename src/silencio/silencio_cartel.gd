class_name SilencioCartel
extends CanvasLayer

## Cartel de Las Tierras del Silencio: texto en pantalla "con tono de acta" (diseno_E3, convenciones de
## estilo). Es lo unico que "habla" en el reino: el narrador calla. Una caja gris sobria abajo, sin
## sonido, sin icono y sin ironia; cada frase entra despues de la anterior. Se va sola. Si llega otro
## cartel, reemplaza al que estaba.

const GROUP := "sil_cartel"
const READ_BASE := 2.5     # s minimos de lectura
const READ_PER_CHAR := 0.06
const LINE_GAP := 0.7      # s entre una frase y la siguiente
const FADE := 0.8

var lines: Array = []
var secs := 0.0


static func show_lines(lines_: Array, secs_ := 0.0) -> SilencioCartel:
	var tree := Engine.get_main_loop() as SceneTree
	for old in tree.get_nodes_in_group(GROUP):
		old.queue_free()
	var main := tree.get_first_node_in_group("main")
	if main == null or lines_.is_empty():
		return null
	var c := SilencioCartel.new()
	c.lines = lines_.map(func(l): return str(l))
	c.secs = secs_
	main.add_child(c)
	return c


func _ready() -> void:
	layer = 45
	add_to_group(GROUP)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.11, 0.86)
	sb.border_color = Color(0.52, 0.5, 0.47)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -64
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var total := 0.0
	var labels: Array = []
	for i in lines.size():
		var l := HudStyle.pixel_label(lines[i], 16, Color("e4e0d8"))
		l.custom_minimum_size.x = 560
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 0)
		l.modulate.a = 0.0
		l.visible = false  # la caja crece frase a frase
		box.add_child(l)
		labels.append(l)
		total += READ_BASE * 0.5 + str(lines[i]).length() * READ_PER_CHAR
	var hold := secs if secs > 0.0 else total
	var tw := create_tween()
	for l in labels:
		tw.tween_callback(l.set_visible.bind(true))
		tw.tween_property(l, "modulate:a", 1.0, 0.5)
		tw.tween_interval(LINE_GAP)
	tw.tween_interval(maxf(hold - LINE_GAP * labels.size(), 1.0))
	tw.tween_property(root, "modulate:a", 0.0, FADE)
	tw.tween_callback(queue_free)
