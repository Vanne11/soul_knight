extends Node
class_name LoreDatabase

## Lore entries with unlock conditions - signal-based communication

var _entries: Dictionary = {}
var _unlocked_ids: Array[String] = []
## Contadores persistentes entre runs: "kill:<nombre>", "boss:<nombre>", "item:<id>", "custom:<evento>"
## (con "*" = cualquiera). Piso y toxicidad son de la run actual.
var _counters: Dictionary = {}
var _floor_reached := 0
## Ids de region (reino) pisados esta partida: las entradas de lugar se abren al ENTRAR al reino, en el orden que toque.
var _regions_visited: Array = []
var _intox_tier := 0

var _lore_entry_class: Script = null

func _ready() -> void:
	var ge = get_node("/root/GlobalEvents")
	_lore_entry_class = preload("res://src/core/lore_entry.gd")
	_load_entries()
	_load_progress()
	ge.run_started.connect(_on_run_started)
	ge.player_died.connect(func(): custom_event("death"))

func _load_entries() -> void:
	for file in ResourceLoader.list_directory("res://assets/data/lore/"):
		if file.ends_with(".tres"):
			var entry = ResourceLoader.load("res://assets/data/lore/%s" % file)
			if entry and entry.get_script() == _lore_entry_class:
				_entries[entry.id] = entry
	print("Loaded %d lore entries" % _entries.size())

func _load_progress() -> void:
	var file = FileAccess.open("user://lore_progress.json", FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		if not data is Dictionary:  # archivo corrupto (cierre a medio guardar): se empieza de cero
			push_warning("lore_progress.json ilegible: se ignora")
			return
		var ids = data.get("unlocked", [])
		var counters = data.get("counters", {})
		for id in (ids if ids is Array else []):
			_unlocked_ids.append(str(id))
		_counters = counters if counters is Dictionary else {}
		for id in _unlocked_ids:
			if _entries.has(id):
				_entries[id].unlocked = true

func _save_progress() -> void:
	_save_queued = false
	var file = FileAccess.open("user://lore_progress.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"unlocked": _unlocked_ids, "counters": _counters}))
		file.close()


## Los contadores cambian con cada kill e item: se guardan como mucho cada 3 s (antes una
## escritura a disco por bicho muerto, con tirones en combate) y al cerrar el juego.
var _save_queued := false
func _queue_save() -> void:
	if _save_queued:
		return
	_save_queued = true
	get_tree().create_timer(3.0, true).timeout.connect(func(): if _save_queued: _save_progress())


func _exit_tree() -> void:
	if _save_queued:
		_save_progress()

func get_entry(entry_id: String) -> Variant:
	return _entries[entry_id] if _entries.has(entry_id) else null

func get_all_entries() -> Array:
	return _entries.values()

func get_unlocked_entries() -> Array:
	var result = []
	for entry in _entries.values():
		if entry.unlocked:
			result.append(entry)
	return result

func get_entries_by_category(category: int) -> Array:
	var result = []
	for entry in _entries.values():
		if entry.category == category:
			result.append(entry)
	return result

func unlock_entry(entry_id: String) -> bool:
	if not _entries.has(entry_id):
		return false
	if entry_id in _unlocked_ids:
		return false
	
	_entries[entry_id].unlocked = true
	_unlocked_ids.append(entry_id)
	_save_progress()
	get_node("/root/GlobalEvents").lore_unlocked.emit(entry_id)
	print("Lore unlocked: %s" % entry_id)
	return true

# ---------------------------------------------------------------- desbloqueos
## Antes cada rama dejaba met = false y no se desbloqueaba nada nunca.

func custom_event(event_id: String) -> void:
	_bump("custom", event_id)
	_check_all()
	get_node("/root/GlobalEvents").game_event.emit(event_id)  # medallas

func _on_run_started(_seed: int) -> void:
	_floor_reached = 1
	_regions_visited = [RunManager.floor_region(1)]
	_intox_tier = 0
	custom_event("play_" + get_node("/root/RunManager").character)

func _on_enemy_killed(enemy: Node, _killer: Node) -> void:
	var enemy_name: String = enemy.enemy_name if "enemy_name" in enemy else ""
	_bump("boss" if enemy.is_in_group("boss") else "kill", enemy_name)
	_check_all()

func _on_item_picked_up(item: Variant, qty: int) -> void:
	_bump("item", item.id, qty)
	_check_all()

func _on_floor_completed(floor: int) -> void:
	_floor_reached = maxi(_floor_reached, RunManager.region_index(floor) + 1)  # REACH_FLOOR cuenta reinos jugados (posicion en la ruta 1..5), no pisos 1..10
	var region := RunManager.floor_region(floor)
	if region not in _regions_visited:
		_regions_visited.append(region)
	_check_all()

func _on_player_intoxication_changed(_level: float, tier: int) -> void:
	_intox_tier = maxi(_intox_tier, tier)
	_check_all()

func _on_item_used(item: Variant) -> void:
	_bump("item", item.id)
	_check_all()

func _bump(kind: String, target: String, n: int = 1) -> void:
	for key in ["%s:%s" % [kind, target], "%s:*" % kind]:
		_counters[key] = int(_counters.get(key, 0)) + n
	_queue_save()

func _check_all() -> void:
	for entry in _entries.values():
		if entry.unlocked or not entry.unlock_condition is Dictionary:
			continue
		var c: Dictionary = entry.unlock_condition
		var target: String = c.get("target_id", "*")
		var need: int = int(c.get("count", 1))
		var met := false
		match int(c.get("type", -1)):
			0: met = int(_counters.get("kill:" + target, 0)) >= need
			1, 4: met = int(_counters.get("item:" + target, 0)) >= need
			# "region": id del reino (entrada de lugar, sirve para cualquier ruta); "floor": n-esimo reino jugado
			2: met = (str(c.region) in _regions_visited) if c.has("region") else _floor_reached >= int(c.get("floor", 1))
			3: met = _intox_tier >= int(c.get("intoxication_tier", 1))
			9: met = int(_counters.get("boss:" + target, 0)) >= need
			10: met = int(_counters.get("custom:" + target, 0)) >= need
		if met:
			unlock_entry(entry.id)

func get_completion_percentage() -> float:
	if _entries.is_empty():
		return 0.0
	return float(_unlocked_ids.size()) / float(_entries.size()) * 100.0

signal lore_unlocked(entry_id: String)