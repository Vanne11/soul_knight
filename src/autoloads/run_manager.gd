extends Node
class_name RunManager

## Manages run state: seed, floor, meta-progression, persistence

## Historia "La Gran Censura": cruzas los dos reinos hasta el palacio de la
## Hoja de Parra. Ganar = matar al jefe del ultimo piso.
##
## El ORDEN en que cada heroe recorre los reinos vive en assets/data/routes.json (ver "RUTAS"
## mas abajo): los pisos se cargan una sola vez, la ruta solo los reordena. "Piso n" =
## n-esimo piso de LA RUTA del heroe (current_floor), y la dificultad depende de esa posicion.
##
## Los pisos viven en datos: assets/data/floors/<NN>_<id>.json, uno por piso, en el
## orden de su prefijo numerico (10, 20, 30... deja huecos para intercalar pisos).
## El <id> (nombre del archivo sin prefijo ni .json) sirve para referirse al piso.
## Claves de cada piso:
## roster: [melee, ranged, swarmer] -> variante de sprite (assets/sprites/enemies/<v>_sprite_frames.tres)
## extra: bichos opcionales del piso aparte del trio. type = id de EnemyRegistry
##   ("melee", "its", ...). Ademas se suman los de assets/data/floors/extra/*.json
##   (ver _load_extra_files): asi cada bloque de enemigos nuevos va en su propio archivo.
## region: id estable del reino ("selva", "penelandia"...). Cada reino tiene 2 pisos (etapas):
##   stage 1 = sin jefe (su sala final es un guardian que abre la salida) y stage 2 = jefe del
##   reino (clave "boss"/"boss_name"; solo la 2a etapa las tiene). Las etapas de un reino
##   van seguidas en el orden de los prefijos.
## elite_chance: probabilidad de que un bicho comun salga reforzado (mas vida/dano, aura roja).
## needs: hormonas que exige la Puerta Hormonal de la sala del jefe (solo stage 2).
## miniboss: {type, variant, name} opcional: minijefe propio de la sala MINIBOSS (sin el, dos gigantes del roster).
## tint: color de la sala cuando la liberas (antes de eso esta gris: censurada). En el
##   JSON va en hex ("7fe0a0") y aqui se convierte a Color.
## FLOORS se carga una vez al cargar el script (static var): mismo Array de Dictionary que
## antes era const, accesible igual como RunManager.FLOORS.
const FLOORS_DIR := "res://assets/data/floors/"
const FLOORS_EXTRA_DIR := "res://assets/data/floors/extra/"
static var FLOORS: Array = _load_floors()


static func _json_files(dir: String) -> PackedStringArray:
	var files := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return files
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			files.append(f)
	files.sort()
	return files


static func _read_json(path: String) -> Variant:
	var txt := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(txt)
	if data == null:
		push_error("RunManager: JSON invalido en %s" % path)
	return data


## Id de un piso a partir del archivo: "40_perineo.json" -> "perineo".
static func _floor_id(file: String) -> String:
	var base := file.get_basename()
	var cut := base.find("_")
	return base.substr(cut + 1) if cut >= 0 and base.left(cut).is_valid_int() else base


static func _load_floors() -> Array:
	var floors: Array = []
	var ids: Array = []
	for file in _json_files(FLOORS_DIR):
		var f = _read_json(FLOORS_DIR + file)
		if not f is Dictionary:
			continue
		if f.has("tint"):
			f.tint = Color(str(f.tint))
		if not f.has("extra"):
			f.extra = []
		f.id = _floor_id(file)
		if not f.has("region"):
			f.region = f.id
		f.stage = int(f.get("stage", 1))
		f.elite_chance = float(f.get("elite_chance", 0.0))
		if not f.has("boss"):
			f.boss = ""
			f.boss_name = ""
		floors.append(f)
		ids.append(_floor_id(file))
	_load_extra_files(floors, ids)
	if floors.is_empty():
		push_error("RunManager: no hay pisos en %s" % FLOORS_DIR)
	return floors


## Bichos extra por bloque: cada assets/data/floors/extra/<bloque>.json es un Array de
## {"floor": "<id de piso o lista>" y/o "kingdom": "<reino o lista>", "variant", "name",
##  "type", "weight", "its"?}. Se agregan (por orden de archivo y de entrada) detras de
## los "extra" del propio piso. "floor"/"kingdom" solo eligen piso: no se copian.
static func _load_extra_files(floors: Array, ids: Array) -> void:
	for file in _json_files(FLOORS_EXTRA_DIR):
		var list = _read_json(FLOORS_EXTRA_DIR + file)
		if not list is Array:
			push_error("RunManager: %s debe ser un Array de bichos" % file)
			continue
		for x in list:
			if not x is Dictionary:
				continue
			var want_floor: Array = _as_list(x.get("floor", []))
			var want_kingdom: Array = _as_list(x.get("kingdom", []))
			var entry: Dictionary = x.duplicate()
			entry.erase("floor")
			entry.erase("kingdom")
			var hit := false
			for i in floors.size():
				if ids[i] in want_floor or floors[i].get("kingdom", "") in want_kingdom:
					floors[i].extra.append(entry.duplicate())
					hit = true
			if not hit:
				push_warning("RunManager: %s: '%s' no cae en ningun piso" % [file, entry.get("name", "?")])


## --- RUTAS: orden de los reinos por heroe (assets/data/routes.json) ---
## {"<heroe>": [<reino>, ...]} donde cada <reino> es un id de region ("selva", "penelandia"...) o
## una lista de ids que se juegan en orden AL AZAR segun la semilla de la partida (la del dia
## incluida). Cada reino aporta sus pisos (etapas) seguidos. Meter un reino nuevo = su JSON en
## floors/ + su id aqui. "default" se usa con heroes sin ruta propia.
const ROUTES_FILE := "res://assets/data/routes.json"
static var ROUTES: Dictionary = _load_routes()
## Pisos (Dictionary de FLOORS) de la ruta activa, en orden; vacia = orden de los archivos.
static var route_floors: Array = []
## Ids de region de la ruta activa, en orden (para dificultad por posicion).
static var route_regions: Array = []


static func _load_routes() -> Dictionary:
	var r = _read_json(ROUTES_FILE)
	return r if r is Dictionary else {}


## Ids de region de la ruta de un heroe para una semilla. Los que no existen en FLOORS se ignoran.
static func route_for(hero: String, seed_: int) -> Array:
	var spec: Array = ROUTES.get(hero, ROUTES.get("default", regions()))
	var all := regions()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 2654435761 + 97  # propio: no gasta tiradas del RNG de la partida
	var out: Array = []
	for step in spec:
		var group: Array = step.duplicate() if step is Array else [str(step)]
		for i in range(group.size() - 1, 0, -1):  # Fisher-Yates
			var j := rng.randi_range(0, i)
			var t = group[i]
			group[i] = group[j]
			group[j] = t
		for id in group:
			if id not in all:
				push_warning("RunManager: la ruta de '%s' nombra un reino sin JSON: %s" % [hero, id])
			elif id not in out:
				out.append(id)
	return out


## Fija la ruta activa (lista de ids de region): sus pisos, por reino y etapa.
static func set_route(region_ids: Array) -> void:
	route_regions = region_ids.duplicate()
	route_floors = []
	for r in region_ids:
		for f in FLOORS:
			if f.region == r:
				route_floors.append(f)


static func set_route_for(hero: String, seed_: int) -> void:
	set_route(route_for(hero, seed_))


## Cantidad de pisos de la ruta activa (el ultimo trae el jefe final).
static func route_size() -> int:
	return route_floors.size() if not route_floors.is_empty() else FLOORS.size()


static func _as_list(v) -> Array:
	if v is Array:
		return v
	return [] if str(v) == "" else [str(v)]


## Personajes. Mismas stats base: cada uno tiene un perk distinto, ninguno es "el debil".
## hormone: la que llevas de serie. La del reino contrario te da alergia (salvo al ornitorrinco).
const CHARACTERS := {
	"pitocles": {"name": "PITOCLES", "title": "Héroe de Penelandia", "kingdom": "pene", "hormone": "testosterona",
		"perk": "Escudo (clic der./K): bloquea de frente y, con parry a tiempo, devuelve la bala. Su dash aturde. Más duro, más lento.",
		"bio": "Hoplita veterano de la Guerra Fría Hormonal. Lleva penacho rojo porque dijeron que da autoridad. No la da."},
	"vulvalquiria": {"name": "VULVALQUIRIA", "title": "Heroína de Vulvania", "kingdom": "vulva", "hormone": "estrogeno",
		"perk": "Más rápida, con doble dash y alas (clic der./K) que planean. Grito (F): los enemigos huyen. Menos vida, mejores esquivas.",
		"bio": "Guerrera de los fiordos de Vulvania. Cero batallas perdidas, sin contar las que abandonó. Va por la Hoja con trenzas y sin paciencia."},
	"ornitorrinco": {"name": "ORNITORRINCO", "title": "No especifica", "kingdom": "ninguno", "hormone": "",
		"perk": "Electrorrecepción: ve lo invisible. Huevo-trampa (F) y espolón venenoso (clic der./K). Sin alergias, sin reino.",
		"bio": "Pico de pato, cola de castor, pone huevos y es mamífero. Nadie sabe qué es. Salvar el mundo tampoco estaba en el formulario."},
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

## Regiones (reinos) cuyo jefe has derrotado alguna vez, por id estable (floor.region). Para
## siempre. Vencer al jefe de la 2a etapa libera el reino entero: sus dos pisos.
var liberated: Array = []

## Ids de region en orden, sin repetir (cada reino son 2 pisos).
static func regions() -> Array:
	var out: Array = []
	for f in FLOORS:
		if f.region not in out:
			out.append(f.region)
	return out

## Piso n (1..route_size) de la ruta activa.
static func _floor_at(floor_n: int) -> Dictionary:
	var floors: Array = route_floors if not route_floors.is_empty() else FLOORS
	return floors[clampi(floor_n - 1, 0, floors.size() - 1)]

## Datos del piso n de la ruta (para quien antes indexaba FLOORS con el numero de piso).
static func floor_at(floor_n: int) -> Dictionary:
	return _floor_at(floor_n)

## Id de la region del piso n (1..FLOORS.size()).
static func floor_region(floor_n: int) -> String:
	return _floor_at(floor_n).region

## POSICION del reino en la ruta 0..N-1 (el "piso" de antes del cambio a 2 etapas). Es lo que
## escala la dificultad: el 1er reino que juegas es el 0 sea cual sea. Para nombres/arte/textos
## por reino usa canon_region_index (no depende del heroe).
static func region_index(floor_n: int) -> int:
	var r := floor_region(floor_n)
	var i: int = route_regions.find(r) if not route_floors.is_empty() else regions().find(r)
	return maxi(i, 0)

## Indice fijo del reino entre todos (orden de los archivos), igual para todos los heroes.
static func canon_region_index(floor_n: int) -> int:
	return maxi(regions().find(floor_region(floor_n)), 0)

## 1 o 2.
static func floor_stage(floor_n: int) -> int:
	return int(_floor_at(floor_n).stage)

## Solo la ultima etapa de cada reino tiene jefe.
static func floor_has_boss(floor_n: int) -> bool:
	return str(_floor_at(floor_n).boss) != ""

## "Profundidad" para escalar dificultad (vida, dano, cantidad, precios, premios): el numero de
## reino 1..5 de siempre, con +0.5 en la 2a etapa. Asi la curva por reino es la de antes y la
## 2a etapa es medio paso mas dura; NO se duplica la escalada por tener el doble de pisos.
static func depth(floor_n: int) -> float:
	return float(region_index(floor_n) + 1) + 0.5 * float(floor_stage(floor_n) - 1)

## Depth redondeado para cantidades enteras (enemigos por sala, largo de puzzles...).
static func depth_i(floor_n: int) -> int:
	return roundi(depth(floor_n))

func is_liberated(floor_n: int) -> bool:
	return floor_region(floor_n) in liberated

func is_region_liberated(region: String) -> bool:
	return region in liberated

## Libera la region del piso (sus dos etapas). true si era nueva.
func liberate(floor_n: int) -> bool:
	var r := floor_region(floor_n)
	if r in liberated:
		return false
	liberated.append(r)
	save_meta_progression()
	return true

## Guardados viejos (antes de las etapas): enteros = indice de piso 1..5 (el reino k). Se pasan a
## id de region sin perder progreso. Tambien acepta 0..4 si aparece un 0. Ids desconocidos se descartan.
static func migrate_liberated(raw: Array) -> Array:
	var regs := regions()
	var zero_based := false
	for v in raw:
		if (v is int or v is float) and int(v) == 0:
			zero_based = true
	var out: Array = []
	for v in raw:
		var id := ""
		if v is String and v in regs:
			id = v
		elif v is int or v is float:
			var i := int(v) - (0 if zero_based else 1)
			if i >= 0 and i < regs.size():
				id = regs[i]
		if id != "" and id not in out:
			out.append(id)
	return out

func floor_data() -> Dictionary:
	return _floor_at(current_floor)

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

## --- Censura (src/run/censura_levels.gd) y partida del dia: meta persistente ---
## Nivel mas alto jugable (0 al principio; ganar en el maximo desbloquea el siguiente).
var censura_unlocked := 0
## Nivel elegido en el menu para la proxima partida (siempre <= censura_unlocked).
var censura_selected := 0
## Nivel recien desbloqueado en la ultima partida (0 = ninguno); lo lee main.gd para avisar.
var last_censura_unlocked := 0
## Partida del dia: el menu pide una (daily_requested) y start_new_run la marca (daily_mode).
## fecha "AAAA-MM-DD" (UTC) -> {"victory": bool, "floor": int, "time": float, "hero": String}
var daily_requested := false
var daily_mode := false
var daily_records: Dictionary = {}
const DAILY_KEEP := 60  # fechas que se guardan
var best_floor := 0
var total_runs := 0
## Huesos ganados en la ultima partida (los ensena game_over).
var last_huesos := 0
## Duracion de la ultima partida: get_run_data() da 0 cuando ya termino (game over).
var last_run_time := 0.0

func _ready() -> void:
	var data = load_meta_progression()
	meta_currency = int(data.get("meta_currency", 0))
	meta_upgrades = data.get("meta_upgrades", {})
	liberated = migrate_liberated(data.get("liberated", []))
	best_floor = int(data.get("best_floor", 0))
	if int(data.get("save_version", 1)) < 2 and best_floor > 0:
		best_floor = best_floor * 2 - 1  # antes 5 pisos (1 por reino); ahora 2 por reino
	total_runs = int(data.get("total_runs", 0))
	# Censura y partida del dia: campos nuevos; un guardado viejo sin ellos arranca en 0 / vacio.
	censura_unlocked = clampi(int(data.get("censura_unlocked", 0)), 0, Censura.MAX_LEVEL)
	censura_selected = clampi(int(data.get("censura_selected", 0)), 0, censura_unlocked)
	var dr = data.get("daily_records", {})
	daily_records = dr if dr is Dictionary else {}
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

## Huesos: 5 por piso superado (10 pisos: lo mismo que antes con 5), 1 cada 3 enemigos, 50 extra si ganas.
func huesos_for_run(victory: bool) -> int:
	return (current_floor - 1) * 5 + total_enemies_killed / 3 + (50 if victory else 0)

func start_new_run(seed: int = 0) -> void:
	if seed == 0:
		seed = Time.get_ticks_msec()
	current_seed = seed
	RNG.randomize(seed)
	# Partida del dia (pedida desde el menu): misma semilla para todos, con la Censura elegida en el menu.
	daily_mode = daily_requested
	daily_requested = false
	Censura.level = clampi(censura_selected, 0, censura_unlocked)
	Censura.clear_curses()  # las maldiciones de pactos mayores no pasan de una partida a otra
	last_censura_unlocked = 0
	
	set_route_for(character, seed)  # el orden de los reinos depende del heroe (y la semilla)
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
	last_run_time = run_time
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
	if victory and Censura.level == censura_unlocked and censura_unlocked < Censura.MAX_LEVEL:
		censura_unlocked += 1  # ganar en tu nivel maximo abre el siguiente
		last_censura_unlocked = censura_unlocked
	if daily_mode:
		_record_daily(victory, current_floor, run_time)
	save_meta_progression()
	print("Run ended: victory=%s floor=%d time=%.1fs" % [victory, current_floor, run_time])

## --- Partida del dia ---
## Fecha de hoy en UTC ("AAAA-MM-DD"): la misma para todo el mundo ese dia.
static func daily_date() -> String:
	var d := Time.get_date_dict_from_system(true)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

## Semilla de una fecha: una mezcla entera propia (no hash(), para que no dependa de la version del motor).
static func daily_seed(date: String = "") -> int:
	if date == "":
		date = daily_date()
	var h := 5381
	for c in date.to_utf8_buffer():
		h = ((h * 33) + c) & 0x7fffffff
	h = (h * 1103515245 + 12345) & 0x7fffffff
	return maxi(h, 1)  # 0 significaria "semilla al azar"

## Empieza la partida del dia (con el heroe ya elegido).
func start_daily_run() -> void:
	daily_requested = true
	start_new_run(daily_seed())

## Mejor resultado de hoy (o de la fecha dada); {} si no hay.
func daily_record(date: String = "") -> Dictionary:
	return daily_records.get(date if date != "" else daily_date(), {})

## Mejor = victoria > mas piso > menos tiempo (solo la victoria compara tiempo con otra victoria).
static func _daily_better(a: Dictionary, b: Dictionary) -> bool:
	if bool(a.victory) != bool(b.victory):
		return bool(a.victory)
	if int(a.floor) != int(b.floor):
		return int(a.floor) > int(b.floor)
	return float(a.time) < float(b.time) if bool(a.victory) else false

func _record_daily(victory: bool, floor_n: int, time: float) -> void:
	var rec := {"victory": victory, "floor": floor_n, "time": time, "hero": character}
	var key := daily_date()
	if not daily_records.has(key) or _daily_better(rec, daily_records[key]):
		daily_records[key] = rec
	var keys := daily_records.keys()
	keys.sort()
	while keys.size() > DAILY_KEEP:
		daily_records.erase(keys.pop_front())

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
		"time": Time.get_ticks_msec() / 1000.0 - run_start_time if run_active else last_run_time
	}

func save_meta_progression() -> void:
	var data = {
		"meta_currency": meta_currency,
		"meta_upgrades": meta_upgrades,
		"unlocked_perks": unlocked_perks,
		"total_runs": total_runs,
		"best_floor": best_floor,
		"liberated": liberated,
		"censura_unlocked": censura_unlocked,
		"censura_selected": censura_selected,
		"daily_records": daily_records,
		"save_version": 2,
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