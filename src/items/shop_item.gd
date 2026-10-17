extends "res://src/items/interactable.gd"

## Articulo de la tienda: encima solo el precio; al acercarte, su cuadro (como el
## narrador) dice que es, y E lo compra.

## Encarece cada piso: lo que ganas sube con el piso, los precios tambien.
const FLOOR_MARKUP := 0.15
## Cada mejora repetida cuesta un 50% mas que la anterior.
const UPGRADE_MARKUP := 0.5

var item_id: String = ""
var price: int = 0
var _item: Item
var _sold := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready() -> void:
	super()
	_item = get_node("/root/ItemDatabase").get_item(item_id)
	if _item == null:
		queue_free()
		return
	price = price_for(_item, get_node("/root/RunManager"))
	sprite.texture = _item.sprite
	ActorFx.setup_object(self, sprite, false)
	label.text = "%d $" % price
	label.add_theme_font_size_override("font_size", 12)
	label.material = LightKit.unshaded_material()  # el precio se lee aunque la sala este en penumbra

## Precio en monedas. Estatico para poder comprobarlo sin instanciar la tienda.
static func price_for(item: Item, rm: Node) -> int:
	var base: float
	if item.custom_data.has("price"):
		base = item.custom_data.price
	elif "hormona" in item.tags:
		base = 15
	elif item.equip_slot == Item.EquipSlot.WEAPON:
		base = maxf(10, item.base_value / 10.0)
	elif item.consumable:
		base = maxf(5, item.base_value / 8.0)
	else:
		base = maxf(15, item.base_value / 10.0)
	if "mejora" in item.tags:
		base *= 1.0 + UPGRADE_MARKUP * rm.upgrades_bought.get(item.id, 0)
	return maxi(1, int(round(base * (1.0 + FLOOR_MARKUP * (RunManager.depth(rm.current_floor) - 1.0)) * Censura.mult("price") * FloorEvents.price_mult())))  # rebajas (src/run/floor_events.gd)

func _prompt_text() -> String:
	var rm = get_node("/root/RunManager")
	var action := tr("SHOP_BUY") % price
	if rm.coins < price:
		action = tr("SHOP_POOR") % [price, rm.coins]
	var aff := Loc.affinity_line(_item)
	return "[color=#ffd75a][b]%s[/b][/color]\n[font_size=13]%s[/font_size]%s%s\n[color=#b08d4a]%s[/color]" % [
		Loc.item_name(_item), Loc.item_desc(_item), "\n[font_size=12]%s[/font_size]" % aff if aff != "" else "", ItemSlots.hint_line(_item), action]


func _use(player: Node) -> void:
	var rm = get_node("/root/RunManager")
	if rm.coins < price:
		Sound.play("poor")
		return
	var block := ItemSlots.pickup_block(player, _item)
	if block != "":  # p. ej. con la jaula puesta no entran hormonas: no se cobra
		get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -46), tr(block), Color("c05a5a"))
		Sound.play("locked")
		return
	ItemSlots.of(player)
	rm.add_coins(-price)
	if "mejora" in _item.tags:
		rm.upgrades_bought[item_id] = rm.upgrades_bought.get(item_id, 0) + 1
	_sold = true
	finish()
	label.visible = false
	sprite.visible = false
	player.add_item_to_inventory(item_id)
	Sound.play("buy")
