extends Node
class_name GlobalEvents

## Central signal bus for decoupled communication between systems

# Player signals
signal player_damaged(amount: float, source: Node)
signal player_healed(amount: float)
signal player_shield_changed(current: float, max: float)
signal player_stamina_changed(current: float, max: float)
signal player_intoxication_changed(level: float, tier: int)
signal player_died()
signal player_leveled_up(level: int)

# Player control signals (requests from other systems)
signal player_stats_reset_requested()
signal player_shields_restore_requested()

# Combat signals
signal enemy_damaged(enemy: Node, amount: float, source: Node)
signal enemy_killed(enemy: Node, killer: Node)
signal entity_hit(entity: Node, damage: float, knockback: Vector2)

# Item signals
signal item_picked_up(item: Variant, quantity: int)
signal item_used(item: Variant)
signal item_dropped(item: Variant, position: Vector2)
signal inventory_changed()

# Dungeon signals
signal room_cleared(room: Node)
signal floor_completed(floor: int)
signal run_started(seed: int)
signal run_ended(victory: bool, floor: int, stats: Dictionary)

# UI signals
signal show_damage_number(position: Vector2, amount: float, is_crit: bool)
signal show_floating_text(position: Vector2, text: String, color: Color)
signal boss_health_changed(boss_name: String, current: float, max: float)
signal coins_changed(coins: int)
signal hormones_changed()
signal log_message(message: String, log_type: int)

# Lore signals
signal lore_unlocked(entry_id: String)
signal lore_unlock_requested(entry_id: String)

# System signals
signal game_paused(paused: bool)
signal settings_changed()