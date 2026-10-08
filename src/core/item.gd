extends Resource
class_name Item

## Data-driven item definition

@export var id: String
@export var display_name: String
@export var description: String
@export var sprite: Texture2D
@export var rarity: Rarity = 0
@export var tags: Array[String] = []
@export var effects: Array = []
@export var max_stack: int = 1
@export var consumable: bool = false
@export var equip_slot: EquipSlot = 0
@export var base_value: int = 10
@export var custom_data: Dictionary = {}

enum Rarity { COMMON = 0, UNCOMMON = 1, RARE = 2, EPIC = 3, LEGENDARY = 4, JUNK = 5 }
enum EquipSlot { NONE = 0, WEAPON = 1, RELIC = 2, ACCESSORY = 3 }