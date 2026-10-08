extends Area2D

## Articulo de la tienda: te pones encima, ves el precio y compras con "interactuar" (E).

var item_id: String = ""
var price: int = 0
var _player: Node = null
var _sold := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready() -> void:
	var item = get_node("/root/ItemDatabase").get_item(item_id)
	if item == null:
		queue_free()
		return
	price = maxi(5, item.base_value / 12)
	sprite.texture = item.sprite
	label.text = "%s\n%d monedas" % [item.display_name, price]
	label.visible = false
	body_entered.connect(func(b): if b.is_in_group("player"): _player = b; label.visible = not _sold)
	body_exited.connect(func(b): if b == _player: _player = null; label.visible = false)

func _process(_delta: float) -> void:
	if _sold or _player == null or not Input.is_action_just_pressed("interact"):
		return
	var rm = get_node("/root/RunManager")
	if rm.coins < price:
		get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -30), "Pobre.", Color("ff7ac0"))
		Narrator.say("shop_poor")
		return
	rm.add_coins(-price)
	_sold = true
	label.visible = false
	sprite.visible = false
	_player.add_item_to_inventory(item_id)
	Narrator.say("shop_buy")
