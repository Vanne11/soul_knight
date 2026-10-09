extends Area2D

## Articulo de la tienda: el precio se ve siempre; encima ves que es y compras con "interactuar" (E).

## Encarece cada piso: lo que ganas sube con el piso, los precios tambien.
const FLOOR_MARKUP := 0.15
## Cada mejora repetida cuesta un 50% mas que la anterior.
const UPGRADE_MARKUP := 0.5

static var _BG := _make_bg()

static func _make_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.06, 0.9)
	sb.set_content_margin_all(4)
	return sb

var item_id: String = ""
var price: int = 0
var _item: Item
var _player: Node = null
var _sold := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready() -> void:
	_item = get_node("/root/ItemDatabase").get_item(item_id)
	if _item == null:
		queue_free()
		return
	price = price_for(_item, get_node("/root/RunManager"))
	sprite.texture = _item.sprite
	_refresh_label()
	body_entered.connect(func(b): if b.is_in_group("player"): _player = b; _refresh_label())
	body_exited.connect(func(b): if b == _player: _player = null; _refresh_label())

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
	return int(round(base * (1.0 + FLOOR_MARKUP * (rm.current_floor - 1))))

func _refresh_label() -> void:
	if _sold:
		label.visible = false
		return
	label.visible = true
	# El que miras va encima de los demas y con fondo, para que no se mezclen los textos.
	z_index = 5 if _player else 1
	if _player:
		label.text = "%s\n%s\n[E] %d monedas" % [_item.display_name, _item.description, price]
		label.add_theme_font_size_override("font_size", 10)
		label.add_theme_stylebox_override("normal", _BG)
	else:
		label.text = "%d $" % price
		label.add_theme_font_size_override("font_size", 12)
		label.remove_theme_stylebox_override("normal")

func _process(_delta: float) -> void:
	if _sold or _player == null or not Input.is_action_just_pressed("interact"):
		return
	var rm = get_node("/root/RunManager")
	if rm.coins < price:
		get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -30), "Pobre. Faltan %d." % (price - rm.coins), Color("ff7ac0"))
		Narrator.say("shop_poor")
		Sound.play("poor")
		return
	rm.add_coins(-price)
	if "mejora" in _item.tags:
		rm.upgrades_bought[item_id] = rm.upgrades_bought.get(item_id, 0) + 1
	_sold = true
	_refresh_label()
	sprite.visible = false
	_player.add_item_to_inventory(item_id)
	Narrator.say("shop_buy")
	Sound.play("buy")
