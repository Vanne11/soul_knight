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
## Murio con la Pastilla del Dia Despues activa: el jugador pone invulnerabilidad y aviso.
signal revived()
signal status_changed()

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
## Reliquias (Lubricante, Anticonceptivo, Higado): dash y botin, intoxicacion ganada.
var dash_speed_modifier: float = 1.0
var dash_cost_modifier: float = 1.0
var intox_gain_modifier: float = 1.0
var loot_chance_modifier: float = 1.0

## Estados temporales de objetos (ver apply_item_effect): regeneracion, reduccion de dano,
## mejoras de stat con duracion, golpes absorbidos y revivir.
var _regen_left: float = 0.0
var _regen_rate: float = 0.0
var _dr_left: float = 0.0
var _dr_mult: float = 1.0
var _temp_mods: Dictionary = {}  # stat -> {"left": s, "mult": m}
var guard_hits: int = 0
var revive_charges: int = 0
var revive_fraction: float = 0.4
const MAX_GUARD := 3
## Objetos de ranura (src/items/item_slots.gd): el tampon corta el dano por segundo (ardor) y el
## talco da inmunidad al contagio durante un rato.
var _dot_immune_left: float = 0.0
var _infect_immune_left: float = 0.0

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
	_handle_timed_effects(delta)

func reset_for_new_run() -> void:
	# Sin esto las mejoras (y el +25 de escudo de Pitocles) se acumulaban entre partidas.
	var rm := get_node("/root/RunManager")
	max_health = BASE_HEALTH + 5.0 * rm.meta_level("vida")
	max_shields = (BASE_SHIELDS + 5.0 * rm.meta_level("escudo")) * Censura.mult("shield")  # Censura: menos escudo
	max_stamina = BASE_STAMINA + 10.0 * rm.meta_level("estamina")
	current_health = max_health
	current_shields = max_shields
	current_stamina = max_stamina
	intoxication_level = 0.0
	intoxication_tier = 0
	damage_modifier = 1.0
	speed_modifier = 1.0
	if has_meta("sticky_on"):  # afijo Pegajoso a medias: que no divida la velocidad nueva
		remove_meta("sticky_on")
	accuracy_modifier = 1.0
	crit_chance_modifier = 0.0
	crit_damage_modifier = 1.5
	lifesteal = 0.0
	projectile_speed_modifier = 1.0
	fire_rate_modifier = 1.0
	dash_speed_modifier = 1.0
	dash_cost_modifier = 1.0
	intox_gain_modifier = 1.0
	loot_chance_modifier = 1.0
	shield_regen_rate = 15.0
	_shield_regen_timer = 0.0
	_last_damage_time = 0.0
	clear_contagion()
	stamina_regen_rate = 25.0
	_regen_left = 0.0
	_dr_left = 0.0
	_dr_mult = 1.0
	_temp_mods.clear()
	guard_hits = 0
	revive_charges = 0
	_dot_immune_left = 0.0
	_infect_immune_left = 0.0
	vph_vaccinated = false
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

## Efectos nuevos de objetos (tipos >= 10 de Item.effects). `boost` > 1 cuando el objeto es
## de la afinidad del heroe (ver Player.apply_item_effect, que escala antes de llamar aqui).
## 10 REGEN {rate, duration} | 11 TEMP_MOD {stat, magnitude, duration} |
## 12 REDUCE_DAMAGE {magnitude (multiplicador), duration} | 13 GUARD {hits} | 14 REVIVE {fraction}
## 17 DOT_IMMUNE {duration} (+ cura el ardor ya activo) | 18 INFECT_IMMUNE {duration} (+ cura el contagio)
func apply_item_effect(e: Dictionary) -> void:
	match int(e.type):
		10:
			_regen_rate = float(e.rate)
			_regen_left = float(e.duration)
		11:
			var stat: String = e.stat
			var m := float(e.magnitude)
			if _temp_mods.has(stat):
				_temp_mods[stat].left = float(e.duration)  # repetir solo renueva el tiempo
			else:
				_temp_mods[stat] = {"left": float(e.duration), "mult": m}
				apply_stat_mod(stat, m)
		12:
			_dr_mult = float(e.magnitude)
			_dr_left = float(e.duration)
		13:
			guard_hits = mini(MAX_GUARD, guard_hits + int(e.hits))
		14:
			revive_charges = 1  # solo una a la vez
			revive_fraction = float(e.get("fraction", 0.4))
		17:
			_dot_immune_left = float(e.duration)
			if contagion_kind == "ardor":
				clear_contagion()
		18:
			_infect_immune_left = float(e.duration)
			clear_contagion()
	status_changed.emit()

func _handle_timed_effects(delta: float) -> void:
	_flush_hero_numbers(delta)
	if _regen_left > 0.0:
		_regen_left -= delta
		if current_health > 0.0 and current_health < max_health:
			var before_r := current_health
			current_health = minf(max_health, current_health + _regen_rate * delta)
			health_changed.emit(current_health, max_health)
			_heal_acc += current_health - before_r
		if _regen_left <= 0.0:
			status_changed.emit()
	if _dr_left > 0.0:
		_dr_left -= delta
		if _dr_left <= 0.0:
			_dr_mult = 1.0
			status_changed.emit()
	if _dot_immune_left > 0.0:
		_dot_immune_left -= delta
		if _dot_immune_left <= 0.0:
			status_changed.emit()
	if _infect_immune_left > 0.0:
		_infect_immune_left -= delta
		if _infect_immune_left <= 0.0:
			status_changed.emit()
	for stat in _temp_mods.keys():
		var t: Dictionary = _temp_mods[stat]
		t.left -= delta
		if t.left <= 0.0:
			apply_stat_mod(stat, 1.0 / t.mult)
			_temp_mods.erase(stat)
			status_changed.emit()

## Lista para el HUD: [{"key": clave de traduccion, "left": segundos o -1, "count": n}]
func active_statuses() -> Array:
	var out: Array = []
	if _regen_left > 0.0:
		out.append({"key": "STATUS_REGEN", "left": _regen_left})
	if _dr_left > 0.0:
		out.append({"key": "STATUS_DEFENSE", "left": _dr_left})
	for stat in _temp_mods:
		out.append({"key": "STATUS_MOD_" + String(stat).to_upper(), "left": _temp_mods[stat].left})
	if _dot_immune_left > 0.0:
		out.append({"key": "STATUS_DOT_IMMUNE", "left": _dot_immune_left})
	if _infect_immune_left > 0.0:
		out.append({"key": "STATUS_INFECT_IMMUNE", "left": _infect_immune_left})
	if guard_hits > 0:
		out.append({"key": "STATUS_GUARD", "left": -1.0, "count": guard_hits})
	if revive_charges > 0:
		out.append({"key": "STATUS_REVIVE", "left": -1.0})
	return out

func take_damage(amount: float) -> float:
	if DebugMenu.god_mode:
		return 0.0
	if current_health <= 0.0:
		return 0.0  # ya muerto: un tic de ardor o un charco repetia player_died (muertes fantasma en el menu)
	if guard_hits > 0 and amount > 0.0:
		guard_hits -= 1
		status_changed.emit()
		_ge.show_floating_text.emit(_player_pos(), tr("FX_GUARD"), Color("9be8ff"))
		return 0.0
	var actual_damage = amount * (_dr_mult if _dr_left > 0.0 else 1.0) * Censura.mult("damage_taken")  # Censura 0: dano a 1/3
	
	var shield_lost := 0.0
	if current_shields > 0.0:
		var shield_damage = min(current_shields, actual_damage)
		current_shields -= shield_damage
		actual_damage -= shield_damage
		shield_lost = shield_damage
		shields_changed.emit(current_shields, max_shields)
	
	if actual_damage > 0.0:
		current_health = max(0.0, current_health - actual_damage)
		health_changed.emit(current_health, max_health)
		hero_number("-%d" % maxi(1, roundi(actual_damage)), HERO_NUM_DAMAGE, true)
		_ge.player_damaged.emit(actual_damage, null)
	elif shield_lost >= 1.0:
		hero_number("-%d" % roundi(shield_lost), HERO_NUM_SHIELD, false)  # el escudo se comio el golpe
	
	_last_damage_time = Time.get_ticks_msec() / 1000.0
	
	if current_health <= 0.0:
		if revive_charges > 0:
			revive_charges = 0
			current_health = maxf(1.0, max_health * revive_fraction)
			health_changed.emit(current_health, max_health)
			status_changed.emit()
			revived.emit()
		else:
			_ge.player_died.emit()
	
	return actual_damage

## --- Numeros sobre el heroe (J0b): vida perdida en rojo, curada en verde, escudo en azul. ---
## Se apagan en Ajustes (Settings.hero_numbers). Las curas chicas y seguidas (robo de vida,
## regeneracion) se juntan y salen cada HEAL_FLUSH_S para no llenar la pantalla.
const HERO_NUM_DAMAGE := Color("ff3b3b")
const HERO_NUM_HEAL := Color("5df07a")
const HERO_NUM_SHIELD := Color("6ec8ff")
const HEAL_FLUSH_S := 0.5
var _heal_acc := 0.0
var _heal_t := 0.0


func hero_number(text: String, color: Color, big: bool) -> void:
	if not Settings.hero_numbers:
		return
	_ge.show_hero_number.emit(_player_pos(), text, color, big)


func _flush_hero_numbers(delta: float) -> void:
	_heal_t -= delta
	if _heal_t > 0.0:
		return
	if _heal_acc >= 1.0:
		hero_number("+%d" % roundi(_heal_acc), HERO_NUM_HEAL, false)
		_heal_acc = 0.0
		_heal_t = HEAL_FLUSH_S
	elif _heal_acc <= 0.0:
		_heal_acc = 0.0


func _player_pos() -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	return p.global_position + Vector2(0, -30) if p else Vector2.ZERO

func heal(amount: float) -> void:
	amount *= Censura.mult("heal")  # Censura: curacion escasa (orbes, fuente, robo de vida...)
	var before := current_health
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	_heal_acc += current_health - before
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
	if amount > 0.0:
		amount *= intox_gain_modifier
	intoxication_level = clampf(intoxication_level + amount, 0.0, max_intoxication)
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
		"stamina_regen": stamina_regen_rate *= value
		"dash_speed": dash_speed_modifier *= value
		"dash_stamina_cost": dash_cost_modifier *= value
		"intoxication_resistance": intox_gain_modifier *= value  # 0.7 = 30% menos intoxicacion ganada
		"loot_chance": loot_chance_modifier *= value
		"shield_regen_rate": shield_regen_rate += value  # suma puntos/s a la regeneracion de escudo
		"stamina": # restaura estamina (cafe, bebida energetica...), no es un multiplicador
			current_stamina = minf(max_stamina, current_stamina + value)
			stamina_changed.emit(current_stamina, max_stamina)
		"max_health": 
			var old_max = max_health
			max_health *= value
			if old_max > 0.0:
				current_health = current_health * (max_health / old_max)
			health_changed.emit(current_health, max_health)
		"max_shields":
			var old_max = max_shields
			max_shields *= value
			if old_max > 0.0:  # escudo base 0 (Vulvalquiria, Ornitorrinco): 0/0 dejaba NaN para siempre
				current_shields = current_shields * (max_shields / old_max)
			shields_changed.emit(current_shields, max_shields)
		"max_stamina":
			var old_max = max_stamina
			max_stamina *= value
			if old_max > 0.0:
				current_stamina = current_stamina * (max_stamina / old_max)
			stamina_changed.emit(current_stamina, max_stamina)
		# Mejoras de la tienda: suman (no multiplican) y rellenan lo ganado.
		"max_health_flat":
			max_health += value
			current_health += value
			health_changed.emit(current_health, max_health)
		"max_shields_flat":
			var sv := value * (Censura.mult("shield") if value > 0.0 else 1.0)  # Censura: el escudo ganado vale menos
			max_shields += sv
			current_shields += sv
			shields_changed.emit(current_shields, max_shields)
			if sv >= 1.0:
				hero_number("+%d" % roundi(sv), HERO_NUM_SHIELD, false)
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
## Vacuna VPH del consultorio (src/edu): inmune al contagio del VPH Verrugon y sus verruguitas
## durante la partida. Se borra al empezar otra.
var vph_vaccinated: bool = false

## True si llevas algo con efecto de inmunidad "its". Las armas solo valen en la mano.
func is_protected() -> bool:
	return has_item_immunity(CONTAGION_IMMUNITY_ID)

## True si llevas algo con inmunidad `id` ("its", "slow", "root"...). Las armas solo valen en la mano.
func has_item_immunity(immunity: String) -> bool:
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
			if fx is Dictionary and int(fx.get("type", -1)) == 4 and immunity in fx.get("custom_data", {}).get("immunity", []):
				return true
	return false

## Intenta contagiar. Devuelve true si te contagia; false si el preservativo te protege.
func infect(kind: String, seconds: float, source: String = "") -> bool:
	if not CONTAGION.has(kind) or DebugMenu.god_mode:
		return false
	if vph_vaccinated and _from_vph(source):
		return false
	var pl := get_tree().get_first_node_in_group("player")
	var df = pl.get("defense") if pl != null else null
	if df != null and df.blocks_contagion():  # burbuja de condon / vacuna VPH (src/player/defenses/)
		contagion_blocked_count += 1
		_ge.show_floating_text.emit(pl.global_position + Vector2(0, -34), tr("FX_PROTECTED"), Color("7fe0a0"))
		return false
	if _infect_immune_left > 0.0 or (_dot_immune_left > 0.0 and CONTAGION[kind].dot > 0.0):
		contagion_blocked_count += 1
		_ge.show_floating_text.emit(get_tree().get_first_node_in_group("player").global_position + Vector2(0, -34), tr("FX_PROTECTED"), Color("7fe0a0"))
		return false
	if is_protected():
		contagion_blocked_count += 1
		_ge.show_floating_text.emit(get_tree().get_first_node_in_group("player").global_position + Vector2(0, -34), tr("FX_PROTECTED"), Color("7fe0a0"))
		_narrate_later("its_protected")
		return false
	var first := contagion_time <= 0.0
	contagion_kind = kind
	contagion_time = maxf(contagion_time, seconds * Censura.mult("contagion_time"))  # Censura: contagio mas largo
	_contagion_tick_t = CONTAGION[kind].tick
	contagion_changed.emit(contagion_kind, contagion_time)
	if first:
		_ge.show_floating_text.emit(get_tree().get_first_node_in_group("player").global_position + Vector2(0, -34), tr("FX_CONTAGION_" + kind.to_upper()), Color("c8e04a"))
		_narrate_later("its_contagion")
	return true

## True si el contagio viene del VPH. enemy_its aun no dice quien contagia (source vacio):
## entonces se mira si hay un VPH o una verruguita pegado al jugador.
func _from_vph(source: String) -> bool:
	if source != "":
		return source in ["vph", "verruguita"]
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.get("its_kind") in ["vph", "verruguita"] \
				and (e as Node2D).global_position.distance_to(player.global_position) < 110.0:
			return true
	return false

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
