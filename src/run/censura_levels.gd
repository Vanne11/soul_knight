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

## Nivel activo en la partida en curso (0 = normal).
static var level := 0


static func mult(key: String) -> float:
	var m := 1.0
	for i in mini(level, LEVELS.size()):
		m *= float(LEVELS[i].get("mult", {}).get(key, 1.0))
	return m


static func has(flag: String) -> bool:
	for i in mini(level, LEVELS.size()):
		if flag in LEVELS[i].get("flags", []):
			return true
	return false


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
