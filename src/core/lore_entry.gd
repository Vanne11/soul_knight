extends Resource
class_name LoreEntry

## Lore entry with unlock conditions

@export var id: String
@export var title: String
@export var text: String
@export var category: Category = 0
@export var unlock_condition: Variant = null
@export var sprite: Texture2D
@export var unlocked: bool = false
@export var flavor_text: String = ""

enum Category {
	WORLD = 0,
	CHARACTER = 1,
	ITEM = 2,
	ENEMY = 3,
	LOCATION = 4,
	MISC = 5,
	ENDING = 6
}