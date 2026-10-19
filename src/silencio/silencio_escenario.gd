class_name SilencioEscenario
extends Node2D

## ESCENARIO FIJO de la pelea contra "El Pacto de Silencio": la cortina pesada, el haz de luz y el circulo de
## sillas vacias. Es decorado de la arena: no se mueve nunca, no choca y no daña. Va centrado en la sala, detras
## de todo. Las siluetas (SilencioCuerpo) salen de sus sillas y vuelven a sentarse en ellas. El nodo esta en
## los PIES del escenario (el mismo punto donde esta el jefe). Lo crea la sala (silencio_jefe.gd) y, si falta
## (pelea directa de pruebas), el propio jefe.

const GROUP := "sil_escenario"
const FRAMES := "res://assets/sprites/silencio/pacto/pacto_sprite_frames.tres"

var _sprite := Sprite2D.new()


func _ready() -> void:
	add_to_group(GROUP)
	z_index = 0
	var sf: SpriteFrames = load(FRAMES)
	var tex: Texture2D = sf.get_frame_texture("vacia", 0)
	_sprite.texture = tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -tex.get_height() * 0.5)
	add_child(_sprite)
	# una luz fria y tenue sobre el escenario: la sala esta casi a oscuras y la cortina tiene que leerse
	var glow := LightKit.make_light(Color(0.82, 0.86, 1.0), 0.5, 2.8, false)
	glow.remove_from_group(LightKit.GROUP_DARK)
	glow.enabled = true
	glow.position = Vector2(0, -70)
	add_child(glow)
