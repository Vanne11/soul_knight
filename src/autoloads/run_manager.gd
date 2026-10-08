extends Node
class_name RunManager

## Manages run state: seed, floor, meta-progression, persistence

## Historia "La Gran Censura": cruzas los dos reinos hasta el palacio de la
## Hoja de Parra. Ganar = matar al jefe del ultimo piso.
## roster: [melee, ranged, swarmer] -> variante de sprite (assets/sprites/enemies/<v>_sprite_frames.tres)
## needs: hormonas que exige la Puerta Hormonal de la sala del jefe.
## tint: color de la sala cuando la liberas (antes de eso esta gris: censurada).
const FLOORS := [
	{"name": "LA SELVA PÚBICA", "kingdom": "neutral", "tint": Color("7fe0a0"),
		"roster": ["pelo_encarnado", "granito", "ladilla"], "names": ["Pelo Encarnado", "Granito Rencoroso", "Ladilla"],
		"weights": [0.40, 0.25, 0.35], "boss": "boss_cera", "boss_name": "DOÑA CERA CALIENTE", "needs": []},
	{"name": "PENELANDIA", "kingdom": "pene", "tint": Color("6ec6ff"),
		"roster": ["testiculo", "vesicula", "espermatozoide"], "names": ["Testículo Errante", "Vesícula Resentida", "Espermatozoide"],
		"weights": [0.45, 0.20, 0.35], "boss": "testiculo_primordial", "boss_name": "TESTÍCULO PRIMORDIAL", "needs": ["testosterona"]},
	{"name": "VULVANIA", "kingdom": "vulva", "tint": Color("ff7ac0"),
		"roster": ["ovulo", "trompa", "calambre"], "names": ["Óvulo Rodante", "Trompa Escupidora", "Calambre"],
		"weights": [0.40, 0.30, 0.30], "boss": "reina_ovaria", "boss_name": "SU MAJESTAD OVARIA II", "needs": ["estrogeno"]},
	{"name": "EL PERINEO", "kingdom": "mixto", "tint": Color("ffc93c"),
		"roster": ["testiculo", "trompa", "calambre"], "names": ["Testículo Errante", "Trompa Escupidora", "Calambre"],
		"alt_roster": ["ovulo", "vesicula", "espermatozoide"], "alt_names": ["Óvulo Rodante", "Vesícula Resentida", "Espermatozoide"],
		"weights": [0.35, 0.35, 0.30], "boss": "aduanero", "boss_name": "EL ADUANERO HORMONAL", "needs": ["testosterona", "estrogeno"]},
	{"name": "EL PALACIO DE LA CENSURA", "kingdom": "censura", "tint": Color("b48cff"),
		"roster": ["barra_negra", "sello", "pixel_censura"], "names": ["Barra Negra", "Sello Censor", "Píxel de Censura"],
		"weights": [0.35, 0.30, 0.35], "boss": "hoja_de_parra", "boss_name": "SU PUDOROSIDAD, LA HOJA DE PARRA", "needs": []},
]

## Personajes. Mismas stats base: cada uno tiene un perk distinto, ninguno es "el debil".
## hormone: la que llevas de serie. La del reino contrario te da alergia (salvo al ornitorrinco).
const CHARACTERS := {
	"pitocles": {"name": "PITOCLES", "title": "Héroe de Penelandia", "kingdom": "pene", "hormone": "testosterona",
		"perk": "Escudo +25. Aguanta lo que le echen. Emocionalmente, no.",
		"bio": "Hoplita veterano de la Guerra Fría Hormonal. Lleva casco griego porque leyó que daba autoridad. No la da."},
	"vulvalquiria": {"name": "VULVALQUIRIA", "title": "Heroína de Vulvania", "kingdom": "vulva", "hormone": "estrogeno",
		"perk": "El dash cuesta la mitad. Esquiva problemas mejor que tú.",
		"bio": "Guerrera del norte de Vulvania. Ha visto cosas. Ha censurado cero. Viene a por la Hoja de Parra con trenzas y sin paciencia."},
	"ornitorrinco": {"name": "ORNITORRINCO", "title": "No especifica", "kingdom": "ninguno", "hormone": "",
		"perk": "Inmune a las alergias. Pero ningún reino lo considera de casa.",
		"bio": "Pico de pato, cola de castor, pone huevos y es mamífero. La naturaleza tuvo un mal día. Él tuvo uno peor: le tocó salvar el mundo."},
}

var character: String = "pitocles"
var coins: int = 0
## hormonas en el cuerpo esta run: abren las Puertas Hormonales
var hormones: Dictionary = {}

func floor_data() -> Dictionary:
	return FLOORS[clampi(current_floor - 1, 0, FLOORS.size() - 1)]

func character_data() -> Dictionary:
	return CHARACTERS.get(character, CHARACTERS["pitocles"])

func is_allergic_to(hormone: String) -> bool:
	var own: String = character_data().hormone
	return own != "" and hormone != "" and hormone != own

func add_coins(n: int) -> void:
	coins += n
	get_node("/root/GlobalEvents").coins_changed.emit(coins)

@export var starting_floor: int = 1

var current_seed: int = 0
var current_floor: int = 1
var current_room_index: int = 0
var rooms_cleared_this_floor: int = 0
var total_enemies_killed: int = 0
var total_damage_dealt: float = 0.0
var total_damage_taken: float = 0.0
var items_collected: Array[Dictionary] = []
var lore_unlocked: Array[String] = []
var meta_currency: int = 0
var unlocked_perks: Array[String] = []
var run_active: bool = false
var run_start_time: float = 0.0
var last_run_victory: bool = false

signal room_cleared_signal
signal floor_advanced(floor: int)

func _ready() -> void:
	var data = load_meta_progression()
	meta_currency = data["meta_currency"] if data.has("meta_currency") else 0
	var perks_data = data["unlocked_perks"] if data.has("unlocked_perks") else []
	unlocked_perks = []
	for perk in perks_data:
		unlocked_perks.append(str(perk))
	print("Meta loaded: currency=%d perks=%d" % [meta_currency, unlocked_perks.size()])

func start_new_run(seed: int = 0) -> void:
	if seed == 0:
		seed = Time.get_ticks_msec()
	current_seed = seed
	RNG.randomize(seed)
	
	current_floor = starting_floor
	current_room_index = 0
	rooms_cleared_this_floor = 0
	total_enemies_killed = 0
	total_damage_dealt = 0.0
	total_damage_taken = 0.0
	items_collected.clear()
	lore_unlocked.clear()
	run_active = true
	last_run_victory = false
	coins = 0
	hormones = {}
	if character_data().hormone != "":
		hormones[character_data().hormone] = true
	run_start_time = Time.get_ticks_msec() / 1000.0
	
	get_node("/root/GlobalEvents").player_stats_reset_requested.emit()
	get_node("/root/GlobalEvents").run_started.emit(seed)
	print("Run started: seed=%d" % seed)

func end_run(victory: bool = false) -> void:
	run_active = false
	last_run_victory = victory
	var run_time = Time.get_ticks_msec() / 1000.0 - run_start_time
	var stats = {
		"seed": current_seed,
		"victory": victory,
		"floor_reached": current_floor,
		"time": run_time,
		"enemies_killed": total_enemies_killed,
		"damage_dealt": total_damage_dealt,
		"damage_taken": total_damage_taken,
		"items_collected": items_collected.size()
	}
	get_node("/root/GlobalEvents").run_ended.emit(victory, current_floor, stats)
	save_meta_progression()
	print("Run ended: victory=%s floor=%d time=%.1fs" % [victory, current_floor, run_time])

func advance_floor() -> void:
	current_floor += 1
	current_room_index = 0
	rooms_cleared_this_floor = 0
	get_node("/root/GlobalEvents").player_shields_restore_requested.emit()
	get_node("/root/GlobalEvents").floor_completed.emit(current_floor)
	print("Floor %d completed, advancing to %d" % [current_floor - 1, current_floor])

func clear_room() -> void:
	rooms_cleared_this_floor += 1
	current_room_index += 1
	room_cleared_signal.emit()

func add_meta_currency(amount: int) -> void:
	meta_currency += amount
	save_meta_progression()

func unlock_perk(perk_id: String) -> void:
	if perk_id not in unlocked_perks:
		unlocked_perks.append(perk_id)
		save_meta_progression()

func unlock_lore(entry_id: String) -> void:
	if entry_id not in lore_unlocked:
		lore_unlocked.append(entry_id)

func record_item_collected(item_id: String) -> void:
	items_collected.append({"id": item_id, "floor": current_floor, "time": Time.get_ticks_msec() / 1000.0 - run_start_time})

func get_run_data() -> Dictionary:
	return {
		"seed": current_seed,
		"floor": current_floor,
		"room_index": current_room_index,
		"enemies_killed": total_enemies_killed,
		"damage_dealt": total_damage_dealt,
		"damage_taken": total_damage_taken,
		"time": Time.get_ticks_msec() / 1000.0 - run_start_time if run_active else 0
	}

func save_meta_progression() -> void:
	var data = {
		"meta_currency": meta_currency,
		"unlocked_perks": unlocked_perks,
		"total_runs": (load_meta_progression().get("total_runs", 0) + 1),
		"best_floor": max(load_meta_progression().get("best_floor", 0), current_floor)
	}
	var file = FileAccess.open("user://meta_save.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_meta_progression() -> Dictionary:
	var file = FileAccess.open("user://meta_save.json", FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		file.close()
		return data
	return {}

func _on_run_started(seed: int) -> void:
	# Called via get_node("/root/GlobalEvents").run_started signal
	pass

func _on_run_ended(victory: bool, floor: int, stats: Dictionary) -> void:
	pass

func _on_floor_completed(floor: int) -> void:
	pass

func _on_room_cleared() -> void:
	pass

signal run_started(seed: int)
signal run_ended(victory: bool, floor: int, stats: Dictionary)
signal floor_completed(floor: int)