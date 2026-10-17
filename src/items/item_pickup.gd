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
	ActorFx.setup_object(self, sprite, false, 0.3)
	ActorFx.add_item_glow(self, sprite, _glow_color(), 0.4, 0.4)
	_bob_tween = create_tween().set_loops()
	# se anima el sprite, no el Area2D: position:y es absoluto y mandaba el pickup a y=±8
	_bob_tween.tween_property(sprite, "position:y", -8.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(sprite, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _glow_color() -> Color:
	if "moneda" in _item.tags:
		return Color("ffd75a")
	if _item.custom_data.get("hormone", "") != "" or "hormona" in _item.tags:
		return Color("c08cff")
	var aff: String = _item.custom_data.get("affinity", "")
	if aff == "pene":
		return Color("6ec6ff")
	if aff == "vulva":
		return Color("ff7ac0")
	if _item.consumable:
		return Color("ff7aa0")
	return Color(RARITY_COLORS[clampi(_item.rarity, 0, RARITY_COLORS.size() - 1)])


func _on_enter(body: Node) -> void:
	if body.is_in_group("player") and "moneda" in _item.tags:
		_use(body)
		return
	super(body)


func _prompt_text() -> String:
	var color: String = RARITY_COLORS[clampi(_item.rarity, 0, RARITY_COLORS.size() - 1)]
	var action := tr("PICKUP_TAKE")
	if _item.equip_slot == Item.EquipSlot.WEAPON and _player.current_weapon:
		action = tr("PICKUP_SWAP") % Loc.item_name(_player.current_weapon)
	elif _item.equip_slot == Item.EquipSlot.WEAPON:
		action = tr("PICKUP_WIELD")
	return "[color=#%s][b]%s[/b][/color]\n[font_size=13]%s[/font_size]%s%s\n[color=#b08d4a]%s[/color]" % [
		color, Loc.item_name(_item), Loc.item_desc(_item), _affinity_suffix() + ItemSlots.hint_line(_item), "", action]


func _affinity_suffix() -> String:
	var l := Loc.affinity_line(_item)
	return "\n[font_size=12]%s[/font_size]" % l if l != "" else ""


func _use(player: Node) -> void:
	var block := ItemSlots.pickup_block(player, _item)
	if block != "":
		get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -46), tr(block), Color("c05a5a"))
		Sound.play("locked")
		return
	ItemSlots.of(player)  # las ranuras tienen que existir antes de recoger (guardan el objeto)
	finish()
	player.add_item_to_inventory(item_id)
	queue_free()
