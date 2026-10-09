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
		"perk": "Empieza con 10 de escudo. Aguanta lo que le echen. Emocionalmente, no.",
		"bio": "Hoplita veterano de la Guerra Fría Hormonal. Lleva casco griego porque leyó que daba autoridad. No la da."},
	"vulvalquiria": {"name": "VULVALQUIRIA", "title": "Heroína de Vulvania", "kingdom": "vulva", "hormone": "estrogeno",
		"perk": "El dash cuesta la mitad. Esquiva problemas mejor que tú.",
		"bio": "Guerrera del norte de Vulvania. Ha visto cosas. Ha censurado cero. Viene a por la Hoja de Parra con trenzas y sin paciencia."},
	"ornitorrinco": {"name": "ORNITORRINCO", "title": "No especifica", "kingdom": "ninguno", "hormone": "",
		"perk": "Inmune a las alergias. Pero ningún reino lo considera de casa.",
		"bio": "Pico de pato, cola de castor, pone huevos y es mamífero. La naturaleza tuvo un mal día. Él tuvo uno peor: le tocó salvar el mundo."},
}

## Bendiciones de reino: se elige 1 de 3 al limpiar una sala que la ofrece.
## Las del reino contrario pegan doble (+2 niveles) pero dan alergia.
## stat: [stat, valor por nivel] se aplica al cogerla; el resto lo consulta el
## codigo de combate con blessing("id") (player.gd, player_bullet.gd, main.gd).
const BLESSINGS := {
	"calibre": {"name": "Calibre Grueso", "kingdom": "pene", "desc": "+20% de daño", "stat": ["damage", 1.2]},
	"descarga": {"name": "Descarga Múltiple", "kingdom": "pene", "desc": "+1 proyectil por disparo (cada uno pega un 70%)"},
	"embestida": {"name": "Embestida", "kingdom": "pene", "desc": "Tus balas empujan y aturden mucho más"},
	"penetracion": {"name": "Penetración", "kingdom": "pene", "desc": "Las balas atraviesan a un enemigo más"},
	"orgullo": {"name": "Orgullo Herido", "kingdom": "pene", "desc": "Al recibir un golpe sueltas 8 balas en círculo"},
	"testosterona": {"name": "Testosterona Pura", "kingdom": "pene", "desc": "+8 de vida máxima y +5 de escudo", "stat": ["max_health_flat", 8.0]},
	"ciclo": {"name": "Ciclo Acelerado", "kingdom": "vulva", "desc": "+20% de cadencia de disparo", "stat": ["fire_rate", 1.2]},
	"escurridiza": {"name": "Escurridiza", "kingdom": "vulva", "desc": "El dash recarga un 30% antes y cuesta menos"},
	"filo": {"name": "Dash Cortante", "kingdom": "vulva", "desc": "El dash daña a todo lo que atraviesas"},
	"intuicion": {"name": "Intuición", "kingdom": "vulva", "desc": "+12% de probabilidad de crítico", "stat": ["crit_chance", 0.12]},
	"regla": {"name": "Regeneración Cíclica", "kingdom": "vulva", "desc": "Curas 1 de vida al matar"},
	"caderas": {"name": "Caderas Ligeras", "kingdom": "vulva", "desc": "+12% de velocidad", "stat": ["speed", 1.12]},
	# Solo aparece con 2+ niveles de cada reino: premio a mezclar.
	"equilibrio": {"name": "Equilibrio Hormonal", "kingdom": "mixto", "desc": "Al hacer dash disparas un anillo de balas"},
}

var character: String = "pitocles"
var coins: int = 0
## hormonas en el cuerpo esta run: abren las Puertas Hormonales
var hormones: Dictionary = {}
## id de mejora -> veces comprada esta run (cada compra la encarece)
var upgrades_bought: Dictionary = {}
## id de bendicion -> nivel esta run
var blessings: Dictionary = {}

func blessing(id: String) -> int:
	return int(blessings.get(id, 0))

## Niveles sumados de un reino (para desbloquear Equilibrio Hormonal).
func kingdom_levels(kingdom: String) -> int:
	var n := 0
	for id in blessings:
		if BLESSINGS[id].kingdom == kingdom:
			n += blessings[id]
	return n

## Reino "de casa" del heroe (el ornitorrinco no tiene: nunca hay contrario).
func is_foreign(kingdom: String) -> bool:
	var home: String = character_data().kingdom
	return home in ["pene", "vulva"] and kingdom in ["pene", "vulva"] and kingdom != home

## 3 bendiciones a elegir; la mayoria del reino pedido. Equilibrio sustituye a la
## ultima si ya la mereces.
func roll_blessings(kingdom: String) -> Array:
	var other := "vulva" if kingdom == "pene" else "pene"
	var main_pool := BLESSINGS.keys().filter(func(id): return BLESSINGS[id].kingdom == kingdom)
	var other_pool := BLESSINGS.keys().filter(func(id): return BLESSINGS[id].kingdom == other)
	RNG.shuffle(main_pool)
	RNG.shuffle(other_pool)
	var out: Array = main_pool.slice(0, 2) + other_pool.slice(0, 1)
	if blessing("equilibrio") == 0 and kingdom_levels("pene") >= 2 and kingdom_levels("vulva") >= 2:
		out[2] = "equilibrio"
	return out

## Regiones cuyo jefe has derrotado alguna vez (indice de piso). Para siempre.
var liberated: Array = []

func is_liberated(floor_n: int) -> bool:
	return floor_n in liberated

func liberate(floor_n: int) -> bool:
	if floor_n in liberated:
		return false
	liberated.append(floor_n)
	save_meta_progression()
	return true

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

## Mejoras permanentes: se compran con huesos en el menu y valen para todas las
## partidas. player_stats.gd las aplica al empezar; el coste sube con el nivel.
const META_UPGRADES := {
	"vida": {"name": "Corazón Curtido", "desc": "+5 de vida al empezar", "cost": 15, "max": 5},
	"estamina": {"name": "Pulmones de Exfumador", "desc": "+10 de estamina al empezar", "cost": 10, "max": 5},
	"escudo": {"name": "Látex de Serie", "desc": "+5 de escudo al empezar", "cost": 20, "max": 4},
	"monedas": {"name": "Hucha Escondida", "desc": "+5 monedas al empezar", "cost": 10, "max": 3},
}
var meta_upgrades: Dictionary = {}
var best_floor := 0
var total_runs := 0
## Huesos ganados en la ultima partida (los ensena game_over).
var last_huesos := 0

func _ready() -> void:
	var data = load_meta_progression()
	meta_currency = int(data.get("meta_currency", 0))
	meta_upgrades = data.get("meta_upgrades", {})
	best_floor = int(data.get("best_floor", 0))
	liberated = data.get("liberated", []).map(func(f): return int(f))
	total_runs = int(data.get("total_runs", 0))
	unlocked_perks = []
	for perk in data.get("unlocked_perks", []):
		unlocked_perks.append(str(perk))

func meta_level(id: String) -> int:
	return int(meta_upgrades.get(id, 0))

func meta_cost(id: String) -> int:
	return META_UPGRADES[id].cost * (meta_level(id) + 1)

func buy_meta(id: String) -> bool:
	if meta_level(id) >= META_UPGRADES[id].max or meta_currency < meta_cost(id):
		return false
	meta_currency -= meta_cost(id)
	meta_upgrades[id] = meta_level(id) + 1
	save_meta_progression()
	return true

## Huesos: 10 por piso superado, 1 cada 3 enemigos, 50 extra si ganas.
func huesos_for_run(victory: bool) -> int:
	return (current_floor - 1) * 10 + total_enemies_killed / 3 + (50 if victory else 0)

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
	coins = 5 * meta_level("monedas")
	hormones = {}
	upgrades_bought = {}
	blessings = {}
	if character_data().hormone != "":
		hormones[character_data().hormone] = true
	run_start_time = Time.get_ticks_msec() / 1000.0
	
	get_node("/root/GlobalEvents").player_stats_reset_requested.emit()
	get_node("/root/GlobalEvents").run_started.emit(seed)
	print("Run started: seed=%d" % seed)

func end_run(victory: bool = false) -> void:
	if not run_active:
		return  # ya terminada: no cobrar huesos dos veces
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
	last_huesos = huesos_for_run(victory)
	meta_currency += last_huesos
	total_runs += 1
	best_floor = maxi(best_floor, current_floor)
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
		"meta_upgrades": meta_upgrades,
		"unlocked_perks": unlocked_perks,
		"total_runs": total_runs,
		"best_floor": best_floor,
		"liberated": liberated,
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
		return data if data is Dictionary else {}  # guardado corrupto: se empieza de cero
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