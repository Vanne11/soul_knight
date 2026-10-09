extends "res://src/items/interactable.gd"
class_name ItemPickup

## Objeto en el suelo. Las monedas se recogen al pasar; lo demas lo decides tu:
## al acercarte sale que es, y E lo recoge.

const RARITY_COLORS := ["f2ead6", "7ad67a", "6aa8ff", "c08cff", "ffa64a", "9a9a9a"]

@export var item_id: String = ""
var _item: Item
var _bob_tween: Tween

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	super()
	_item = get_node("/root/ItemDatabase").get_item(item_id)
	if _item == null:
		queue_free()
		return
	if _item.sprite:
		sprite.texture = _item.sprite
	_bob_tween = create_tween().set_loops()
	# se anima el sprite, no el Area2D: position:y es absoluto y mandaba el pickup a y=±8
	_bob_tween.tween_property(sprite, "position:y", -8.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(sprite, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_enter(body: Node) -> void:
	if body.is_in_group("player") and "moneda" in _item.tags:
		_use(body)
		return
	super(body)


func _prompt_text() -> String:
	var color: String = RARITY_COLORS[clampi(_item.rarity, 0, RARITY_COLORS.size() - 1)]
	var action := "[E] Recoger"
	if _item.equip_slot == Item.EquipSlot.WEAPON and _player.current_weapon:
		action = "[E] Cambiar por tu %s (la dejas aquí)" % _player.current_weapon.display_name
	elif _item.equip_slot == Item.EquipSlot.WEAPON:
		action = "[E] Empuñar"
	return "[color=#%s][b]%s[/b][/color]\n[font_size=13]%s[/font_size]\n[color=#b08d4a]%s[/color]" % [
		color, _item.display_name, _item.description, action]


func _use(player: Node) -> void:
	finish()
	player.add_item_to_inventory(item_id)
	queue_free()
