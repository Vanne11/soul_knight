extends Node2D
class_name KeyFollower

## La llave que llevas: flota detras del jugador para que se vea (y se note cuando se
## rompe, se escurre o se seca). Solo presentacion.

var _spr: Sprite2D
var _t := 0.0
var kind := "crystal"
var target: Node2D


func _ready() -> void:
	_spr = Sprite2D.new()
	_spr.texture = KeyQuests.key_tex(kind)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(1.2, 1.2)
	add_child(_spr)
	ActorFx.add_glow(self, KeyQuests.key_color(kind), 0.45, 0.5)
	z_index = 2
	if target:
		global_position = target.global_position + Vector2(-22, -34)


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_t += delta
	var want := target.global_position + Vector2(-22, -36 + sin(_t * 3.0) * 3.0)
	global_position = global_position.lerp(want, minf(1.0, delta * 9.0))
	if kind == "crystal":
		_spr.modulate = Color(1.0, 1.0, 1.0, 0.8 + 0.2 * sin(_t * 9.0))  # fragil: tiembla
	elif kind == "drunk":
		_spr.rotation = sin(_t * 4.0) * 0.5  # se bambolea
