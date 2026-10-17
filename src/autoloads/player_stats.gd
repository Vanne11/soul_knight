extends Node
class_name PlayerStats

## Player stats: health, shields, stamina, intoxication, modifiers

signal health_changed(current: float, max: float)
signal shields_changed(current: float, max: float)
signal stamina_changed(current: float, max: float)
signal intoxication_changed(level: float, tier: int)
signal stat_modified(stat: String, value: float)
## Contagio de ITS: kind "" = sano. El HUD lo muestra; el preservativo lo evita.
signal contagion_changed(kind: String, seconds: float)

enum IntoxicationTier { SOBER = 0, TIPSY = 1, DRUNK = 2, BLACKOUT = 3 }

## Valores de partida. La vida es baja a proposito: se sube con mejoras de la tienda.
## Se empieza flojo: lo demas se gana (mejora tras cada jefe, tienda, huesos).
const BASE_HEALTH := 25.0
const BASE_SHIELDS := 0.0
const BASE_STAMINA := 30.0

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
	_handle_contagion(delta)

func reset_for_new_run() -> void:
	# Sin esto las mejoras (y el +25 de escudo de Pitocles) se acumulaban entre partidas.
	var rm := get_node("/root/RunManager")
	max_health = BASE_HEALTH + 5.0 * rm.meta_level("vida")
	max_shields = BASE_SHIELDS + 5.0 * rm.meta_level("escudo")
	max_stamina = BASE_STAMINA + 10.0 * rm.meta_level("estamina")
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
	clear_contagion()
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
	if DebugMenu.god_mode:
		return 0.0
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
		0, 1, 2, 3: return tr("INTOX_TIER_%d" % intoxication_tier)  # solo para mostrar: la logica usa el numero
		_: return "?"

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

# ------------------------------------------------------------------ contagio (ITS)
## Efectos leves y temporales de los golpes de las ITS. No acumulan: reinfectar
## solo renueva el tiempo (y cambia de tipo si es otro). Lo evita cualquier objeto
## con inmunidad "its" (Preservativo de Titanio, Lanzapreservativos...): ver is_protected().
## speed: multiplicador de velocidad; dot: dano cada tick segundos (directo, sin iframes).
const CONTAGION := {
	"picazon": {"speed": 0.88, "dot": 0.0, "tick": 0.0},
	"ardor": {"speed": 1.0, "dot": 1.0, "tick": 2.0},
}
const CONTAGION_IMMUNITY_ID := "its"
var contagion_kind: String = ""
var contagion_time: float = 0.0
var _contagion_tick_t: float = 0.0
var contagion_blocked_count: int = 0  # veces que el preservativo te salvo (para pruebas)

## True si llevas algo con efecto de inmunidad "its". Las armas solo valen en la mano.
func is_protected() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not ("collected_items" in player):
		return false
	var db := get_node("/root/ItemDatabase")
	for id in player.collected_items:
		var item = db.get_item(id)
		if item == null:
			continue
		if item.equip_slot == Item.EquipSlot.WEAPON and not ("current_weapon" in player and player.current_weapon == item):
			continue
		for fx in item.effects:
			if fx is Dictionary and int(fx.get("type", -1)) == 4 and CONTAGION_IMMUNITY_ID in fx.get("custom_data", {}).get("immunity", []):
				return true
	return false

## Intenta contagiar. Devuelve true si te contagia; false si el preservativo te protege.
func infect(kind: String, seconds: float) -> bool:
	if not CONTAGION.has(kind) or DebugMenu.god_mode:
		return false
	if is_protected():
		contagion_blocked_count += 1
		_ge.show_floating_text.emit(get_tree().get_first_node_in_group("player").global_position + Vector2(0, -34), tr("FX_PROTECTED"), Color("7fe0a0"))
		_narrate_later("its_protected")
		return false
	var first := contagion_time <= 0.0
	contagion_kind = kind
	contagion_time = maxf(contagion_time, seconds)
	_contagion_tick_t = CONTAGION[kind].tick
	contagion_changed.emit(contagion_kind, contagion_time)
	if first:
		_ge.show_floating_text.emit(get_tree().get_first_node_in_group("player").global_position + Vector2(0, -34), tr("FX_CONTAGION_" + kind.to_upper()), Color("c8e04a"))
		_narrate_later("its_contagion")
	return true

func clear_contagion() -> void:
	contagion_kind = ""
	contagion_time = 0.0
	contagion_changed.emit("", 0.0)

func contagion_speed_mult() -> float:
	return CONTAGION[contagion_kind].speed if contagion_time > 0.0 else 1.0

## El narrador calla en pleno combate (y say_first gastaria el evento): espera a que acabe.
var _narr_pending: Array[String] = []

func _narrate_later(event: String) -> void:
	if event not in _narr_pending:
		_narr_pending.append(event)

func _handle_contagion(delta: float) -> void:
	if not _narr_pending.is_empty() and not Narrator._in_combat():
		Narrator.say_first(_narr_pending.pop_front())
	if contagion_time <= 0.0:
		return
	contagion_time -= delta
	var c: Dictionary = CONTAGION[contagion_kind]
	if c.dot > 0.0:
		_contagion_tick_t -= delta
		if _contagion_tick_t <= 0.0:
			_contagion_tick_t = c.tick
			take_damage(c.dot)
	if contagion_time <= 0.0:
		clear_contagion()
	else:
		contagion_changed.emit(contagion_kind, contagion_time)
