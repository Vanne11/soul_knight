extends Control
class_name ItemSlot

## Casilla de la franja: solo muestra lo que guarda ItemSlots (teclas 1-4 / cruceta).

var item_id: String = ""
var quantity: int = 0
var slot_index: int = 0

@onready var icon: TextureRect = $Background/Icon
@onready var count_label: Label = $Background/Count
@onready var key_label: Label = $Background/KeyLabel

func setup(index: int, key_text: String) -> void:
	slot_index = index
	key_label.text = key_text
	HudStyle.style_label(key_label, 16, HudStyle.GOLD, true)
	HudStyle.style_label(count_label, 16, HudStyle.CREAM)
	clear()

func set_item(item_id_new: String, qty: int, cursed := false) -> void:
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
	icon.modulate = Color(1.0, 0.55, 0.55) if cursed else Color.WHITE
	if item:
		tooltip_text = "%s\n%s" % [Loc.item_name(item), Loc.item_desc(item)]
		mouse_filter = Control.MOUSE_FILTER_PASS

func clear() -> void:
	item_id = ""
	quantity = 0
	icon.texture = preload("res://assets/sprites/ui/placeholder.png")
	icon.visible = false
	count_label.text = ""
	icon.modulate = Color.WHITE
	tooltip_text = ""
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Destello al usar la casilla.
func flash() -> void:
	var tw := create_tween()
	tw.tween_property($Background, "modulate", Color(1.8, 1.8, 1.8), 0.05)
	tw.tween_property($Background, "modulate", Color.WHITE, 0.25)
