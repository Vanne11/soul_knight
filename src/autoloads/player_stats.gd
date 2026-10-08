extends Node
class_name PlayerStats

## Player stats: health, shields, stamina, intoxication, modifiers

signal health_changed(current: float, max: float)
signal shields_changed(current: float, max: float)
signal stamina_changed(current: float, max: float)
signal intoxication_changed(level: float, tier: int)
signal stat_modified(stat: String, value: float)

enum IntoxicationTier { SOBER = 0, TIPSY = 1, DRUNK = 2, BLACKOUT = 3 }

## Valores de partida. La vida es baja a proposito: se sube con mejoras de la tienda.
const BASE_HEALTH := 50.0
const BASE_SHIELDS := 50.0
const BASE_STAMINA := 100.0

var max_health: float = BASE_HEALTH
var current_health: float = BASE_HEALTH
var max_shields: float = BASE_SHIELDS
var current_shields: float = BASE_SHIELDS
var max_stamina: float = BASE_STAMINA
var current_stamina: float = BASE_STAMINA
var stamina_regen_rate: float = 25.0
var shield_regen_delay: float = 3.0
var shield_regen_rate: float = 15.0
var _shield_regen_timer: float = 0.0

var intoxication_level: float = 0.0
var max_intoxication: float = 100.0
var intoxication_tier: int = 0
var intoxication_decay_rate: float = 2.0

var damage_modifier: float = 1.0
var speed_modifier: float = 1.0
var accuracy_modifier: float = 1.0
var crit_chance_modifier: float = 0.0
var crit_damage_modifier: float = 1.5
var lifesteal: float = 0.0
var projectile_speed_modifier: float = 1.0
var fire_rate_modifier: float = 1.0

var _last_damage_time: float = 0.0
var _ge = null

func _ready() -> void:
	_ge = get_node("/root/GlobalEvents")
	reset_for_new_run()

func _process(delta: float) -> void:
	_handle_stamina_regen(delta)
	_handle_shield_regen(delta)
	_handle_intoxication_decay(delta)

func reset_for_new_run() -> void:
	# Sin esto las mejoras (y el +25 de escudo de Pitocles) se acumulaban entre partidas.
	max_health = BASE_HEALTH
	max_shields = BASE_SHIELDS
	max_stamina = BASE_STAMINA
	current_health = max_health
	current_shields = max_shields
	current_stamina = max_stamina
	intoxication_level = 0.0
	intoxication_tier = 0
	damage_modifier = 1.0
	speed_modifier = 1.0
	accuracy_modifier = 1.0
	crit_chance_modifier = 0.0
	crit_damage_modifier = 1.5
	lifesteal = 0.0
	projectile_speed_modifier = 1.0
	fire_rate_modifier = 1.0
	_shield_regen_timer = 0.0
	_last_damage_time = 0.0
	emit_all_signals()

func _handle_stamina_regen(delta: float) -> void:
	if current_stamina < max_stamina:
		current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
		stamina_changed.emit(current_stamina, max_stamina)

func _handle_shield_regen(delta: float) -> void:
	if current_shields < max_shields:
		if Time.get_ticks_msec() / 1000.0 - _last_damage_time >= shield_regen_delay:
			current_shields = min(max_shields, current_shields + shield_regen_rate * delta)
			shields_changed.emit(current_shields, max_shields)

func _handle_intoxication_decay(delta: float) -> void:
	if intoxication_level > 0.0:
		intoxication_level = max(0.0, intoxication_level - intoxication_decay_rate * delta)
		_update_intoxication_tier()

func take_damage(amount: float) -> float:
	var actual_damage = amount
	
	if current_shields > 0.0:
		var shield_damage = min(current_shields, actual_damage)
		current_shields -= shield_damage
		actual_damage -= shield_damage
		shields_changed.emit(current_shields, max_shields)
	
	if actual_damage > 0.0:
		current_health = max(0.0, current_health - actual_damage)
		health_changed.emit(current_health, max_health)
		_ge.player_damaged.emit(actual_damage, null)
	
	_last_damage_time = Time.get_ticks_msec() / 1000.0
	
	if current_health <= 0.0:
		_ge.player_died.emit()
	
	return actual_damage

func heal(amount: float) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	_ge.player_healed.emit(amount)

func restore_shields_full() -> void:
	current_shields = max_shields
	shields_changed.emit(current_shields, max_shields)

func use_stamina(amount: float) -> bool:
	if current_stamina >= amount:
		current_stamina -= amount
		stamina_changed.emit(current_stamina, max_stamina)
		return true
	return false

func add_intoxication(amount: float) -> void:
	intoxication_level = min(max_intoxication, intoxication_level + amount)
	_update_intoxication_tier()
	intoxication_changed.emit(intoxication_level, intoxication_tier)
	_ge.player_intoxication_changed.emit(intoxication_level, intoxication_tier)

func reduce_intoxication(amount: float) -> void:
	intoxication_level = max(0.0, intoxication_level - amount)
	_update_intoxication_tier()
	intoxication_changed.emit(intoxication_level, intoxication_tier)

func _update_intoxication_tier() -> void:
	var old_tier = intoxication_tier
	var pct = intoxication_level / max_intoxication
	
	if pct >= 0.9:
		intoxication_tier = 3
	elif pct >= 0.6:
		intoxication_tier = 2
	elif pct >= 0.3:
		intoxication_tier = 1
	else:
		intoxication_tier = 0
	
	if intoxication_tier != old_tier:
		print("Intoxication tier: %d" % intoxication_tier)

func apply_stat_mod(stat: String, value: float) -> void:
	match stat:
		"damage": damage_modifier *= value
		"speed": speed_modifier *= value
		"accuracy": accuracy_modifier *= value
		"crit_chance": crit_chance_modifier += value
		"crit_damage": crit_damage_modifier *= value
		"lifesteal": lifesteal += value
		"projectile_speed": projectile_speed_modifier *= value
		"fire_rate": fire_rate_modifier *= value
		"max_health": 
			var old_max = max_health
			max_health *= value
			current_health = current_health * (max_health / old_max)
			health_changed.emit(current_health, max_health)
		"max_shields":
			var old_max = max_shields
			max_shields *= value
			current_shields = current_shields * (max_shields / old_max)
			shields_changed.emit(current_shields, max_shields)
		"max_stamina":
			var old_max = max_stamina
			max_stamina *= value
			current_stamina = current_stamina * (max_stamina / old_max)
			stamina_changed.emit(current_stamina, max_stamina)
		# Mejoras de la tienda: suman (no multiplican) y rellenan lo ganado.
		"max_health_flat":
			max_health += value
			current_health += value
			health_changed.emit(current_health, max_health)
		"max_shields_flat":
			max_shields += value
			current_shields += value
			shields_changed.emit(current_shields, max_shields)
		"max_stamina_flat":
			max_stamina += value
			current_stamina += value
			stamina_changed.emit(current_stamina, max_stamina)
		_:
			push_error("Unknown stat: %s" % stat)
	
	stat_modified.emit(stat, value)

func get_intoxication_tier_name() -> String:
	match intoxication_tier:
		0: return "Sober"
		1: return "Tipsy"
		2: return "Drunk"
		3: return "Blackout"
		_: return "Unknown"

func get_intoxication_effects() -> Dictionary:
	match intoxication_tier:
		0: return {"damage": 1.0, "speed": 1.0, "accuracy": 1.0, "chaos": 0.0}
		1: return {"damage": 1.1, "speed": 1.05, "accuracy": 0.95, "chaos": 0.1}
		2: return {"damage": 1.25, "speed": 1.15, "accuracy": 0.8, "chaos": 0.3}
		3: return {"damage": 1.5, "speed": 1.3, "accuracy": 0.5, "chaos": 0.6}
		_: return {}

func emit_all_signals() -> void:
	health_changed.emit(current_health, max_health)
	shields_changed.emit(current_shields, max_shields)
	stamina_changed.emit(current_stamina, max_stamina)
	intoxication_changed.emit(intoxication_level, intoxication_tier)