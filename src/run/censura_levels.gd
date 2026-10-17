class_name Censura
extends RefCounted

## Niveles de Censura (como la Ascension de Slay the Spire): al ganar una partida en Censura N
## se desbloquea la N+1. Son ACUMULATIVOS: el nivel 5 lleva las reglas 1..5. Nivel 0 = juego normal.
##
## Las reglas se consultan SOLO desde aqui:
##   Censura.mult("elite_chance")  -> producto de los multiplicadores de los niveles activos (1.0 si ninguno)
##   Censura.has("jefe_furia")     -> true si algun nivel activo trae esa bandera
## El nivel activo (`level`) lo fija RunManager.start_new_run() al empezar cada partida.
## Para anadir un nivel basta una entrada mas en LEVELS (y sus textos en locale/censura.csv).
##
## Cada nivel: id (para los textos CENSURA_RULE_<ID>_NAME/_DESC), mult {clave: factor}, flags [banderas].

const LEVELS: Array[Dictionary] = [
	{"id": "elites", "mult": {"elite_chance": 1.5}},         # main.gd: _generate_enemy_data_for_room
	{"id": "monedas", "mult": {"coin_drop": 0.75}},          # main.gd: drops de moneda de los bichos
	{"id": "tienda", "mult": {"price": 1.25}},               # shop_item.gd y edu.gd (consultorio)
	{"id": "curacion", "mult": {"heal": 0.7}, "flags": ["curacion_escasa"]},  # player_stats.gd: heal()
	{"id": "rapidos", "mult": {"enemy_speed": 1.1}},         # room.gd: al instanciar enemigos
	{"id": "oleadas", "mult": {"wave_mult": 1.2}},           # waves.gd: build_pool (bichos extra)
	{"id": "jefes", "mult": {"boss_health": 1.25}},          # main.gd: vida del jefe
	{"id": "escudo", "mult": {"shield": 0.6}},               # player_stats.gd: reset_for_new_run
	{"id": "contagio", "mult": {"contagion_time": 1.5}},     # player_stats.gd: infect()
	{"id": "furia", "flags": ["jefe_furia"]},                # enemy_boss.gd: fase extra de furia
]
const MAX_LEVEL := 10

## Maldiciones de los PACTOS MAYORES de la Hoja de Parra (src/rooms/enc_pact.gd). Duran toda la
## partida y usan las MISMAS claves que los niveles: mult()/has() las combinan con ellos, asi el
## resto del juego las respeta sin ganchos nuevos. El premio tambien va por clave ("coin_drop" > 1)
## y, si trae "cofres", la Hoja suelta esa cantidad de cofres en el acto.
## Textos: PACTO_<ID>_NAME/_CURSE/_PRIZE en locale/pactos.csv.
const PACT_CURSES := {
	"avaricia": {"mult": {"coin_drop": 1.6, "price": 1.5}},                                   # mas monedas, tienda carisima
	"ayuno": {"mult": {"coin_drop": 1.35, "heal": 0.5}, "flags": ["curacion_escasa"], "cofres": 1},  # curas a la mitad
	"clausura": {"mult": {"coin_drop": 1.3, "wave_mult": 1.3, "enemy_speed": 1.08}, "cofres": 1},    # oleadas mas gordas
	"inquisicion": {"mult": {"coin_drop": 1.5, "elite_chance": 2.0}, "flags": ["jefe_furia"]},        # mas elites y jefes furiosos
	"contagio": {"mult": {"coin_drop": 1.45, "contagion_time": 2.0, "enemy_speed": 1.05}, "cofres": 1},   # infecciones el doble de largas
}
## Maximo de pactos mayores por partida.
const MAX_PACT_CURSES := 2

## Nivel activo en la partida en curso (0 = normal).
static var level := 0
## Ids de las maldiciones de pacto activas en la partida en curso (se limpia al empezar partida).
static var pact_curses: Array = []


static func mult(key: String) -> float:
	var m := 1.0
	for i in mini(level, LEVELS.size()):
		m *= float(LEVELS[i].get("mult", {}).get(key, 1.0))
	for id in pact_curses:
		m *= float(PACT_CURSES[id].get("mult", {}).get(key, 1.0))
	return m


static func has(flag: String) -> bool:
	for i in mini(level, LEVELS.size()):
		if flag in LEVELS[i].get("flags", []):
			return true
	for id in pact_curses:
		if flag in PACT_CURSES[id].get("flags", []):
			return true
	return false


## Maldiciones de pacto que aun se pueden aceptar (no repetidas, y solo si cabe otra).
static func available_curses() -> Array:
	if pact_curses.size() >= MAX_PACT_CURSES:
		return []
	return PACT_CURSES.keys().filter(func(id): return id not in pact_curses)


static func add_curse(id: String) -> bool:
	if not PACT_CURSES.has(id) or id in pact_curses or pact_curses.size() >= MAX_PACT_CURSES:
		return false
	pact_curses.append(id)
	return true


static func clear_curses() -> void:
	pact_curses.clear()


static func curse_name(id: String) -> String:
	return TranslationServer.translate("PACTO_%s_NAME" % id.to_upper())


static func curse_curse(id: String) -> String:
	return TranslationServer.translate("PACTO_%s_CURSE" % id.to_upper())


static func curse_prize(id: String) -> String:
	return TranslationServer.translate("PACTO_%s_PRIZE" % id.to_upper())


## Ids de las reglas de los niveles 1..n (por defecto, las del nivel activo), en orden.
static func rule_ids(n: int = -1) -> Array:
	var out: Array = []
	for i in mini(level if n < 0 else n, LEVELS.size()):
		out.append(LEVELS[i].id)
	return out


static func rule_name(id: String) -> String:
	return TranslationServer.translate("CENSURA_RULE_%s_NAME" % id.to_upper())


static func rule_desc(id: String) -> String:
	return TranslationServer.translate("CENSURA_RULE_%s_DESC" % id.to_upper())
