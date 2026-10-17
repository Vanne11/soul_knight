extends Area2D
class_name DrunkBottle

## Botella para la llave borracha: se bebe al pisarla (sin menus). Da +50 de intoxicacion
## (dos botellas llenan la barra: unos 35 s de poder girar la llave). La llave solo se deja coger y girar estando intoxicado.

const AMOUNT := 50.0
var _spr: Sprite2D
var _used := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 14.0
	add_child(shape)
	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/sprites/items/whiskey.png")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(1.3, 1.3)
	add_child(_spr)
	ActorFx.setup_object(self, _spr, false)
	ActorFx.add_item_glow(self, _spr, Color(0.86, 0.52, 0.14), 0.5, 0.4)
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if _used or not body.is_in_group("player"):
		return
	_used = true
	get_node("/root/PlayerStats").add_intoxication(AMOUNT)
	Sound.play("pickup")
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -30), tr("PZ_BOTTLE_DRUNK"), Color("e0a93a"))
	queue_free()
