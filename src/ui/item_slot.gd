extends PanelContainer
class_name ItemSlot

## UI slot for consumable items

var item_id: String = ""
var quantity: int = 0
var slot_index: int = 0

@onready var icon: TextureRect = $Background/Icon
@onready var count_label: Label = $Background/Count
@onready var key_label: Label = $Background/KeyLabel

func setup(index: int, key_text: String) -> void:
	slot_index = index
	key_label.text = key_text
	clear()

func set_item(item_id_new: String, qty: int) -> void:
	item_id = item_id_new
	quantity = qty
	
	var item = get_node("/root/ItemDatabase").get_item(item_id)
	if item and item.sprite:
		icon.texture = item.sprite
	else:
		icon.texture = preload("res://assets/sprites/items/placeholder.png")
	
	if quantity > 1:
		count_label.text = str(quantity)
	else:
		count_label.text = ""
	
	icon.visible = true

func clear() -> void:
	item_id = ""
	quantity = 0
	icon.texture = preload("res://assets/sprites/ui/placeholder.png")
	icon.visible = false
	count_label.text = ""

func use_item() -> bool:
	if item_id == "":
		return false
	
	var item = get_node("/root/ItemDatabase").get_item(item_id)
	if not item or not item.consumable:
		return false
	
	get_node("/root/ItemDatabase").apply_effects(item, get_tree().get_nodes_in_group("player")[0])
	
	quantity -= 1
	if quantity <= 0:
		clear()
	else:
		count_label.text = str(quantity)
	
	get_node("/root/GlobalEvents").inventory_changed.emit()
	return true

func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_map = {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3}
		if key_map.has(event.keycode) and key_map[event.keycode] == slot_index:
			use_item()