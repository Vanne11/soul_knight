extends Resource
class_name UnlockCondition

## Condition to unlock a lore entry

@export var type: ConditionType = 0
@export var target_id: String = ""
@export var count: int = 1
@export var floor: int = 0
@export var intoxication_tier: int = 0

enum ConditionType {
	KILL_ENEMY = 0,
	FIND_ITEM = 1,
	REACH_FLOOR = 2,
	GET_INTOXICATED = 3,
	USE_ITEM = 4,
	TAKE_DAMAGE = 5,
	HEAL = 6,
	DASH_COUNT = 7,
	SECRET_ROOM = 8,
	BOSS_KILL = 9,
	CUSTOM = 10
}