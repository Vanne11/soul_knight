extends "res://src/items/interactable.gd"

## Espejo en pie del acertijo de luz: E lo gira entre "/" y "\". Sin colision (no estorba
## al andar ni al bot); solo se responde a E estando encima.

var cell := Vector2i.ZERO
var _spr: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # el jugador
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 22.0
	add_child(shape)
	_spr = Sprite2D.new()
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.position = Vector2(0, -6)
	add_child(_spr)
	super()
	set_orientation(int(get_meta("orient", 0)))


func set_orientation(o: int) -> void:
	set_meta("orient", o)
	if _spr:
		_spr.texture = load("res://assets/sprites/environment/puzzles/mirror_%s.png" % ("a" if o == 0 else "b"))
		_spr.scale = Vector2(1.2, 0.85)
		_spr.create_tween().tween_property(_spr, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
