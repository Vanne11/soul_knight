extends Resource
class_name StatusEffect

## Status effect applied to entities

@export var id: String
@export var display_name: String
@export var icon: Texture2D
@export var duration: float = 5.0
@export var tick_interval: float = 1.0
@export var damage_per_tick: float = 0.0
@export var stat_mods: Dictionary = {}
@export var visual_effect: String = ""