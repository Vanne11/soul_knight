class_name CorridorBar
extends Control

## Indicador de progreso del pasillo entre reinos: arriba al centro, los dos reinos (disco de su color y
## nombre) unidos por una barra con una ficha que avanza. Lo crea y actualiza main.gd mientras dura el
## pasillo (corridor_active); el minimapa dibuja uno equivalente en su recuadro.

var from_name := ""
var to_name := ""
var color_a := Color.WHITE
var color_b := Color.WHITE
var value := 0.0

const W := 560.0
const H := 44.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -W * 0.5
	offset_right = W * 0.5
	offset_top = HUD.BAND + 10.0
	offset_bottom = HUD.BAND + 10.0 + H


func set_value(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	draw_bar(self, Rect2(Vector2.ZERO, Vector2(W, H)), from_name, to_name, color_a, color_b, value, true)


## Dibujo compartido con el minimapa. `r`: recuadro; `names`: con rotulos de reino.
static func draw_bar(ci: CanvasItem, r: Rect2, name_a: String, name_b: String, ca: Color, cb: Color, v: float, names: bool) -> void:
	var font := ThemeDB.fallback_font
	var ink := Color("0d0b0f")
	var rad := minf(r.size.y * 0.5 - 2.0, 14.0)
	var ya := r.position.y + (r.size.y * 0.5 if not names else rad + 4.0)
	var xa := r.position.x + rad + 4.0
	var xb := r.end.x - rad - 4.0
	# barra: degradado del color de origen al de destino
	var steps := 24
	for i in steps:
		var t0 := float(i) / steps
		var seg := Rect2(xa + (xb - xa) * t0, ya - 4.0, (xb - xa) / steps + 1.0, 8.0)
		ci.draw_rect(seg, ca.lerp(cb, t0).darkened(0.25))
	ci.draw_rect(Rect2(xa, ya - 4.0, xb - xa, 8.0), ink, false, 2.0)
	var fx := xa + (xb - xa) * v
	ci.draw_rect(Rect2(xa, ya - 2.0, fx - xa, 4.0), Color("f2ead6"))
	# los dos reinos
	for e in [[xa, ca], [xb, cb]]:
		ci.draw_circle(Vector2(e[0], ya), rad + 2.0, ink)
		ci.draw_circle(Vector2(e[0], ya), rad, e[1])
	# ficha del heroe
	ci.draw_circle(Vector2(fx, ya), 8.0, ink)
	ci.draw_circle(Vector2(fx, ya), 6.0, Color("ffc93c"))
	if names:
		var fs := 14
		ci.draw_string(font, Vector2(r.position.x, r.end.y - 4.0), name_a, HORIZONTAL_ALIGNMENT_LEFT, r.size.x * 0.5, fs, Color("f2ead6"))
		ci.draw_string(font, Vector2(r.position.x + r.size.x * 0.5, r.end.y - 4.0), name_b, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x * 0.5, fs, Color("f2ead6"))
