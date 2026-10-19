class_name SilencioVoz
extends Node2D

## Barra de VOZ bajo el heroe (S1 Turno). Se llena mientras mantienes "hablar"; si te interrumpen se
## corta en seco. Sin color de peligro ni de premio: gris claro y ya. Sigue al heroe.

const W := 44.0
const H := 5.0

var target: Node2D
var value := 0.0
var cut := 0.0  # 1 justo despues de una interrupcion: la barra se queda partida un instante


func _ready() -> void:
	z_index = 4
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material = LightKit.unshaded_material()


func _process(delta: float) -> void:
	var sala := get_parent() as SilencioSala
	visible = sala == null or sala.inside  # la barra no te sigue a otras salas (S1 Turno, Plaza de la Palabra)
	if target != null:
		global_position = target.global_position + Vector2(0, 30)
	cut = maxf(0.0, cut - delta * 1.4)
	queue_redraw()


func _draw() -> void:
	var x := -W * 0.5
	draw_string(HudStyle.FONT, Vector2(x, -3), tr("SIL_VOZ"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("e4e0d8"))
	draw_rect(Rect2(x, 0, W, H), Color("1c1b1f"))
	var col := Color("d8d4cc") if cut <= 0.0 else Color("a8a49c")
	draw_rect(Rect2(x + 1, 1, (W - 2) * clampf(value, 0.0, 1.0), H - 2), col)
	if cut > 0.0:  # el corte: una marca vertical oscura donde se partio la voz
		draw_rect(Rect2(x + 1 + (W - 2) * value, 0, 2, H), Color("0d0b0f"))
	draw_rect(Rect2(x, 0, W, H), Color("0d0b0f"), false, 1.0)
