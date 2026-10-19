class_name SilencioBurbuja
extends PanelContainer

## Burbuja de texto del Silencio: una caja plana blanca con texto oscuro, sin cola ni avatar ni adorno
## (diseno_E3, S1 y S4). Vive en el mundo (sobre una figura o el heroe) o, para los mensajes de S4,
## en la pantalla. Tachar() la deja como una idea que ya no cuenta.

const INK := Color("1c1b1f")
const PAPER := Color("e9e6df")
const WIDTH := 132.0

var label: Label
var struck := false


static func create(text: String, paper := PAPER, ink := INK, width := WIDTH) -> SilencioBurbuja:
	var b := SilencioBurbuja.new()
	b.setup(text, paper, ink, width)
	return b


func setup(text: String, paper: Color, ink: Color, width: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = LightKit.unshaded_material()  # se lee igual con la luz baja
	var sb := StyleBoxFlat.new()
	sb.bg_color = paper
	sb.border_color = Color("0d0b0f")
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", sb)
	label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.use_parent_material = true
	HudStyle.style_label(label, 8, ink)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = width
	label.text = text
	add_child(label)


func set_text(text: String) -> void:
	label.text = text
	reset_size()


## Linea sobre el texto: la idea sigue ahi, pero ya no vale.
func strike() -> void:
	struck = true
	modulate = Color(1, 1, 1, 0.7)
	queue_redraw()


func _draw() -> void:
	if struck:
		draw_line(Vector2(5.0, size.y * 0.5), Vector2(size.x - 5.0, size.y * 0.5), Color("a02830"), 2.0)


## Cuelga la burbuja sobre un punto (la base de la caja queda `lift` px por encima).
func hang_over(pos: Vector2, lift := 6.0) -> void:
	reset_size()
	position = pos - Vector2(size.x * 0.5, size.y + lift)
