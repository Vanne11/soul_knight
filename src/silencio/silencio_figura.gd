class_name SilencioFigura
extends Node2D

## Silueta del Silencio: figura humana plana, sin cara, sin genero marcado ni caricatura (diseno_E3,
## convenciones de estilo). Arte provisorio de tools/gen_silencio_art.py. El nodo esta en los PIES
## (o en la silla, si esta sentada): se coloca por donde pisa, no por el centro del dibujo.
## Es solo imagen: no choca, no daña, no se puede atacar.

const DIR := "res://assets/sprites/silencio/"
const POSES := {
	"pie_a": "figura_pie_a", "pie_b": "figura_pie_b", "pie_c": "figura_pie_c",
	"sentada": "figura_sentada", "espalda": "figura_espalda",
	"dormida": "figura_dormida", "encogida": "figura_encogida", "brazo": "figura_brazo",
}

var sprite := Sprite2D.new()
var pose := "pie_a"


static func tex(name: String) -> Texture2D:
	return load(DIR + name + ".png")


static func make(pose_: String, pos: Vector2, tint := Color.WHITE) -> SilencioFigura:
	var f := SilencioFigura.new()
	f.pose = pose_
	f.position = pos
	var t := tex(POSES.get(pose_, "figura_pie_a"))
	f.sprite.texture = t
	f.sprite.offset = Vector2(0, -t.get_height() * 0.5 + 2.0)  # los pies (o la silla) en el origen
	f.sprite.modulate = tint
	f.sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	f.add_child(f.sprite)
	return f


## Asentir: un cabeceo corto y sutil (no es una animacion simpatica: es lo que hace la mesa).
func nod(times := 2) -> void:
	var tw := create_tween()
	for i in times:
		tw.tween_property(sprite, "position:y", 2.0, 0.22).set_trans(Tween.TRANS_SINE)
		tw.tween_property(sprite, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_SINE)


## Camina en linea recta hasta `to` (posicion de mundo local al padre) a `speed` px/s; avisa al llegar.
func walk_to(to: Vector2, speed: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", to, position.distance_to(to) / speed)
	await tw.finished
