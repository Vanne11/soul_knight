extends Area2D

## Cofre: se abre al tocarlo y suelta un arma o botin. contents="weapon" fuerza arma.

const ITEM_PICKUP_SCENE := preload("res://src/items/item_pickup.tscn")
var contents: String = ""
var _opened := false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if ResourceLoader.exists("res://assets/sprites/environment/chest_closed.png"):
		sprite.texture = load("res://assets/sprites/environment/chest_closed.png")

func _on_body_entered(body: Node) -> void:
	if _opened or not body.is_in_group("player"):
		return
	_opened = true
	var tex := "res://assets/sprites/environment/chest_open.png"
	if ResourceLoader.exists(tex):
		sprite.texture = load(tex)
	var main := get_tree().get_first_node_in_group("main")
	var id: String = main._random_weapon_id() if contents == "weapon" or RNG.randf() < 0.5 else main._random_loot_id()
	var p := ITEM_PICKUP_SCENE.instantiate()
	p.item_id = id
	p.position = position + Vector2(0, 40)
	get_parent().add_child.call_deferred(p)
	Sound.play("chest")
