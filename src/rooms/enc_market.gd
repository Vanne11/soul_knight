extends RoomDynamic

## Mercado negro (salas secretas y de tesoro): objetos raros a cambio de VIDA, no de monedas.
## Tres puestos: una reliquia rara, un arma y una mejora permanente. Cada uno cuesta sangre
## (puntos de vida); por seguridad no vende si te dejaria por debajo del 40% de tu vida maxima
## (nadie se suicida comprando: lo avisa el cartel). Un puesto vendido no se repone.

const INTERACTABLE := preload("res://src/items/interactable.gd")
const MIN_LEFT := 0.4   # fraccion de la vida maxima que debe quedar tras pagar

var stands: Array[Dictionary] = []   # {it, item_id, price, sold}


func start() -> void:
	var maxhp: float = ps().max_health
	var rare := _rare_id()
	var weapon: String = main._random_weapon_id()
	var up: String = main.UPGRADE_IDS[randi() % main.UPGRADE_IDS.size()]
	var offers := [
		{"id": rare, "price": maxi(3, roundi(maxhp * 0.22))},
		{"id": weapon, "price": maxi(4, roundi(maxhp * 0.28))},
		{"id": up, "price": maxi(5, roundi(maxhp * 0.34))},
	]
	var taken: Array = []
	for i in 3:
		var p := RoomUtil.free_spot(main, room, center() + Vector2((i - 1) * 110.0, 50.0), 22.0, true, taken)
		if p == Vector2.INF:
			continue
		taken.append(p)
		_stand(p, offers[i])
	if stands.is_empty():
		return
	Narrator.say_first("rm_market")
	toast(tr("RM_MARKET_T"), tr("RM_MARKET_D"), "c0283a")


func _rare_id() -> String:
	var db = get_node("/root/ItemDatabase")
	for _i in 60:
		var it = db.get_random_item(Item.Rarity.RARE if randf() < 0.7 else Item.Rarity.EPIC)
		if it != null and it.equip_slot != Item.EquipSlot.WEAPON and not ("especial" in it.tags or "único" in it.tags or "moneda" in it.tags or "hormona" in it.tags or "mejora" in it.tags):
			return it.id
	return main._random_loot_id()


func _stand(pos: Vector2, offer: Dictionary) -> void:
	var item: Item = get_node("/root/ItemDatabase").get_item(offer.id)
	if item == null:
		return
	var it: Node2D = INTERACTABLE.new()
	it.position = pos
	it.set("prompt_text", "[color=#ff7a7a][b]%s[/b][/color]\n[font_size=13]%s[/font_size]\n[color=#b08d4a]%s[/color]" % [
		Loc.item_name(item), Loc.item_desc(item), tr("RM_MARKET_BUY") % int(offer.price)])
	var table := Polygon2D.new()
	table.polygon = PackedVector2Array([Vector2(-20, -4), Vector2(20, -4), Vector2(24, 10), Vector2(-24, 10)])
	table.color = Color(0.3, 0.12, 0.14)
	it.add_child(table)
	var spr := Sprite2D.new()
	spr.texture = item.sprite
	spr.position = Vector2(0, -16)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	it.add_child(spr)
	var label := HudStyle.pixel_label("-%d" % int(offer.price), 12, Color("ff7a7a"), true)
	label.position = Vector2(-20, 12)
	label.size = Vector2(40, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.material = LightKit.unshaded_material()
	it.add_child(label)
	ActorFx.add_glow(it, Color(1.0, 0.25, 0.3), 0.7, 0.7).position = Vector2(0, -14)
	var rec := {"it": it, "item_id": offer.id, "price": int(offer.price), "sold": false, "spr": spr, "label": label}
	it.connect("used", _buy.bind(rec))
	stands.append(rec)
	room.props_node.add_child.call_deferred(it)


func _buy(pl: Node, rec: Dictionary) -> void:
	if rec.sold:
		return
	var price: int = rec.price
	var hp: float = ps().current_health
	if hp - price < ps().max_health * MIN_LEFT:
		Sound.play("poor")
		RoomUtil.popup(pl.global_position + Vector2(0, -40), tr("RM_MARKET_NO_BLOOD"), Color("ff6b6b"))
		Narrator.say("rm_market_poor")
		return
	rec.sold = true
	ps().current_health = hp - price
	ps().health_changed.emit(ps().current_health, ps().max_health)
	Sound.play("hurt")
	var psp = pl.get("animated_sprite")
	if psp != null:
		HitFx.flash(psp)
	if str(rec.item_id).begins_with("upgrade_"):
		rm().upgrades_bought[rec.item_id] = rm().upgrades_bought.get(rec.item_id, 0) + 1
	pl.add_item_to_inventory(rec.item_id)
	rec.it.call("finish")
	rec.spr.visible = false
	rec.label.visible = false
	rec.it.set("prompt_text", "")
	RoomUtil.popup(pl.global_position + Vector2(0, -40), "-%d" % price, Color("ff3b4a"))
	Narrator.say("rm_market_buy")
	if stands.all(func(s): return s.sold):
		finished = true
		room.set_meta("dyn_done", true)
