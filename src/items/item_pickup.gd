extends Area2D
class_name ItemPickup

## World item pickup with bob animation and pickup logic

@export var item_id: String = ""
var collected: bool = false
var _bob_tween: Tween
var _bob_height: float = 8.0
var _bob_duration: float = 1.2

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	if item_id != "":
		var item = get_node("/root/ItemDatabase").get_item(item_id)
		if item and item.sprite:
			sprite.texture = item.sprite
	
	_start_bob_animation()
	
	body_entered.connect(_on_body_entered)

func _start_bob_animation() -> void:
	_bob_tween = create_tween()
	_bob_tween.set_loops()
	# se anima el sprite, no el Area2D: position:y es absoluto y mandaba el pickup a y=±8
	_bob_tween.tween_property(sprite, "position:y", -_bob_height, _bob_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(sprite, "position:y", 0.0, _bob_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_body_entered(body: Node) -> void:
	if collected:
		return
	
	if body.is_in_group("player"):
		collected = true
		_pickup(body)

func _pickup(player: Node) -> void:
	if not item_id:
		queue_free()
		return
	
	player.add_item_to_inventory(item_id)
	
	var item = get_node("/root/ItemDatabase").get_item(item_id)
	if item:
		var rarity_colors = {
			0: Color.WHITE,
			1: Color.GREEN,
			2: Color.BLUE,
			3: Color.PURPLE,
			4: Color.ORANGE,
			5: Color.GRAY
		}
		var color = rarity_colors[item.rarity] if rarity_colors.has(item.rarity) else Color.WHITE
		get_node("/root/GlobalEvents").show_floating_text.emit(global_position, item.display_name, color)
	
	queue_free()