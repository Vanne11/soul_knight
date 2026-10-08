extends Node
class_name GameController

## Central controller that manages all game systems (now autoloads)

var player_stats
var item_database
var lore_database
var run_manager

signal systems_ready

func _ready() -> void:
	# Autoloads are declared before GameController in project.godot, so they
	# already exist here. Godot calls their _ready() automatically.
	player_stats = get_node("/root/PlayerStats")
	item_database = get_node("/root/ItemDatabase")
	lore_database = get_node("/root/LoreDatabase")
	run_manager = get_node("/root/RunManager")
	
	if not (player_stats and item_database and lore_database and run_manager):
		push_error("GameController: missing one or more game systems")
		return
	
	# Connect signal bus
	_setup_signal_connections()
	
	systems_ready.emit()
	print("GameController: All systems initialized")

func _setup_signal_connections() -> void:
	var ge = get_node("/root/GlobalEvents")
	
	# PlayerStats signals -> GlobalEvents
	player_stats.shields_changed.connect(func(c, m): ge.player_shield_changed.emit(c, m))
	player_stats.stamina_changed.connect(func(c, m): ge.player_stamina_changed.emit(c, m))
	player_stats.intoxication_changed.connect(func(l, t): ge.player_intoxication_changed.emit(l, t))
	
	# RunManager signals -> GlobalEvents
	run_manager.room_cleared_signal.connect(ge.room_cleared.emit)
	run_manager.floor_advanced.connect(func(f): ge.floor_completed.emit(f))
	
	# LoreDatabase signals -> GlobalEvents
	lore_database.lore_unlocked.connect(ge.lore_unlocked.emit)
	
	# Connect GlobalEvents requests to systems
	ge.player_stats_reset_requested.connect(player_stats.reset_for_new_run)
	ge.player_shields_restore_requested.connect(player_stats.restore_shields_full)
	ge.run_started.connect(run_manager._on_run_started)
	ge.run_ended.connect(run_manager._on_run_ended)
	ge.floor_completed.connect(run_manager._on_floor_completed)
	ge.room_cleared.connect(run_manager._on_room_cleared)
	
	# Lore condition checking
	ge.enemy_killed.connect(lore_database._on_enemy_killed)
	ge.item_picked_up.connect(lore_database._on_item_picked_up)
	ge.floor_completed.connect(lore_database._on_floor_completed)
	ge.player_intoxication_changed.connect(lore_database._on_player_intoxication_changed)
	ge.item_used.connect(lore_database._on_item_used)
	ge.lore_unlock_requested.connect(lore_database.unlock_entry)

func get_player_stats():
	return player_stats

func get_item_database():
	return item_database

func get_lore_database():
	return lore_database

func get_run_manager():
	return run_manager