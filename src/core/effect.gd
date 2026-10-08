extends Resource
class_name Effect

## Effect applied by items

@export var type: EffectType = 0
@export var magnitude: float = 1.0
@export var duration: float = 0.0
@export var stat: String = ""
@export var intoxication_amount: float = 0.0
@export var status_effect: StatusEffect = null
@export var lore_entry_id: String = ""
@export var custom_data: Dictionary = {}

enum EffectType {
	STAT_MOD = 0,
	INTOXICATION = 1,
	HEAL = 2,
	SHIELD = 3,
	STATUS = 4,
	UNLOCK_LORE = 5,
	TELEPORT = 6,
	TRANSFORM = 7,
	SPAWN_ENEMY = 8,
	REVEAL_MAP = 9
}