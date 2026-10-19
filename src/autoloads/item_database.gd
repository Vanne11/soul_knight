extends Node
class_name ItemDatabase

## Data-driven item system. All items defined as Resources.

var _items: Dictionary = {}
var _items_by_tag: Dictionary = {}
var _items_by_rarity: Dictionary = {}

var _item_class: Script = null
var _ge = null

func _ready() -> void:
	_ge = get_node("/root/GlobalEvents")
	_item_class = preload("res://src/core/item.gd")
	_load_items()

func _load_items() -> void:
	# list_directory (no DirAccess) para que funcione tambien en builds exportadas (.remap)
	for file in ResourceLoader.list_directory("res://assets/data/items/"):
		if file.ends_with(".tres"):
			var item = ResourceLoader.load("res://assets/data/items/%s" % file)
			if item and item.get_script() == _item_class:
				var icon_path := "res://assets/sprites/items/%s.png" % item.id
				if not item.sprite and ResourceLoader.exists(icon_path):
					item.sprite = load(icon_path)
				_normalize_slot_item(item)
				_items[item.id] = item
				for tag in item.tags:
					if not _items_by_tag.has(tag):
						_items_by_tag[tag] = []
					_items_by_tag[tag].append(item)
				if not _items_by_rarity.has(item.rarity):
					_items_by_rarity[item.rarity] = []
				_items_by_rarity[item.rarity].append(item)
	print("Loaded %d items" % _items.size())

## Consumibles de ranura (ver src/items/item_slots.gd): se GUARDAN al recogerlos y se usan con
## 1-4. Aqui sus efectos pasan de `effects` (que Player aplica al recoger) a
## custom_data.use_effects; los .tres nuevos ya vienen asi. Siguen siendo instantaneos (se aplican
## al recogerlos) los orbes de vida, hormonas, mejoras, llaves y monedas.
const INSTANT_IDS := ["health_small", "health_large"]
const INSTANT_TAGS := ["moneda", "hormona", "mejora", "llave"]

static func is_slot_candidate(item: Item) -> bool:
	if not item.consumable or not ("consumible" in item.tags) or item.id in INSTANT_IDS:
		return false
	for t in INSTANT_TAGS:
		if t in item.tags:
			return false
	return item.custom_data.get("hormone", "") == ""

func _normalize_slot_item(item: Item) -> void:
	if not is_slot_candidate(item):
		return
	var cd := item.custom_data.duplicate()
	if not cd.has("use_effects"):
		cd["use_effects"] = item.effects.duplicate()
		item.effects = []
	cd["slot"] = true
	item.custom_data = cd

func get_item(item_id: String) -> Variant:
	return _items[item_id] if _items.has(item_id) else null

## Los objetos con tag "exclusivo" (p.ej. el Dildo Electrico, que solo suelta el enemigo de
## Vulvania) nunca salen de un sorteo: solo se consiguen por su via propia.
func get_random_item(rarity: int = -1, tags: Array[String] = []) -> Variant:
	var pool = []
	if rarity >= 0 and _items_by_rarity.has(rarity):
		pool = _items_by_rarity[rarity].duplicate()
	elif tags.size() > 0:
		for tag in tags:
			if _items_by_tag.has(tag):
				pool.append_array(_items_by_tag[tag])
	else:
		for arr in _items_by_rarity.values():
			pool.append_array(arr)
	
	pool = pool.filter(func(it): return not ("exclusivo" in it.tags))
	pool = _pt_weighted(pool)
	if pool.is_empty():
		return null
	
	return pool[RNG.randi_range(0, pool.size() - 1)]

## Armas de LA PUERTA TRASERA (tag "pt_arma"): dentro del reino salen el triple de veces; en el resto del juego son raras
## (cada una entra al sorteo solo ~1 de cada 5 veces que le toca).
func _pt_weighted(pool: Array) -> Array:
	var rm := get_node_or_null("/root/RunManager")
	var inside: bool = rm != null and String(rm.floor_data().get("region", "")) == "puerta_trasera"
	var out: Array = []
	for it in pool:
		if "pt_arma" in it.tags:
			if inside:
				out.append_array([it, it, it])
			elif RNG.randf() < 0.2:
				out.append(it)
		else:
			out.append(it)
	return out if not out.is_empty() else pool


func get_items_by_tag(tag: String) -> Array:
	return _items_by_tag[tag] if _items_by_tag.has(tag) else []

func apply_effects(item: Variant, target: Node) -> void:
	for effect in item.effects:
		_apply_single_effect(effect, target)

func _apply_single_effect(effect: Variant, target: Node) -> void:
	match effect.type:
		0: # STAT_MOD
			if target.has_method("apply_stat_mod"):
				target.apply_stat_mod(effect.stat, effect.magnitude)
		1: # INTOXICATION
			if target.has_method("add_intoxication"):
				target.add_intoxication(effect.intoxication_amount)
		2: # HEAL
			if target.has_method("heal"):
				target.heal(effect.magnitude)
		3: # SHIELD
			if target.has_method("restore_shields_full"):
				target.restore_shields_full()
		4: # STATUS
			if effect.status_effect and target.has_method("apply_status"):
				target.apply_status(effect.status_effect)
		5: # UNLOCK_LORE - emit signal instead of direct call
			if effect.lore_entry_id != "":
				get_node("/root/GlobalEvents").lore_unlock_requested.emit(effect.lore_entry_id)
		10, 11, 12, 13, 14, 15, 16: # efectos de consumibles (regeneracion, buffs, guardia...)
			if target.has_method("apply_item_effect"):
				target.apply_item_effect(effect)
		_:
			push_error("Unhandled effect type: %d" % effect.type)

func create_item_instance(item_id: String) -> Dictionary:
	var item = get_item(item_id)
	if not item:
		return {}
	return {
		"id": item.id,
		"quantity": 1,
		"durability": 100
	}