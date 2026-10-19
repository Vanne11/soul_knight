class_name Affixes
extends RefCounted

## Afijos de elite (estilo Diablo): cada elite sale con 1-2 y cambian COMO se pelea con el.
## Este archivo es el registro (ids, colores, iconos, exclusiones) y el sorteo; cada afijo es un
## nodo hijo del enemigo (affix_<id>.gd, hereda de Affix) que se cuelga con `Affixes.attach`.
##
## Flujo: main._generate_enemy_data_for_room sortea `info.affixes = Affixes.roll(tipo, piso)` en la
## rama elite -> Room.spawn_enemies llama `Affixes.attach(enemy, data.affixes)` -> los nodos viven
## y mueren con el enemigo. El dano pasa por `Affixes.filter_damage` desde EnemyAI.on_damage
## (blindado absorbe), que ya llaman las 4 clases base (enemy, ranged, swarmer, tank).
##
## Para sumar un afijo: una entrada en DEFS, su script affix_<id>.gd y sus claves en
## locale/afijos.csv (AFFIX_<ID>, AFFIX_<ID>_DESC).

const DIR := "res://src/enemies/affixes/"

## Ids de EnemyRegistry que pueden salir con afijos. Todo lo demas queda fuera: ITS y espinilla
## (mecanica propia), jefes, minijefes (Gran Urologo / Gran Candado / gigantes), guardian,
## inspector (su sello es su gracia) y los enemigos de la 3a (agarres, cuerdas, mordaza...).
const ELIGIBLE := ["melee", "ranged", "swarmer", "tank", "taser"]

## Iconos 7x7: '#' = color del afijo, 'o' = el mismo mas claro, '.' = vacio.
const DEFS := {
	"rapido": {
		"color": Color("ffd23a"), "exclude": [],
		"icon": ["...##..", "..##...", ".###...", "..####.", "...##..", "..##...", ".#....."],
	},
	"blindado": {
		"color": Color("5fb0ff"), "exclude": [],
		"icon": ["#######", "#ooooo#", "#ooooo#", "#ooooo#", ".#ooo#.", "..###..", "......."],
	},
	"vampiro": {
		"color": Color("e8324e"), "exclude": [],
		"icon": ["...#...", "..###..", ".##o##.", ".#ooo#.", ".#ooo#.", ".#####.", "..###.."],
	},
	"explosivo": {
		"color": Color("ff8a2a"), "exclude": [],
		"icon": ["....#o.", "...#...", "..###..", ".#####.", "#######", "#######", ".#####."],
	},
	"invocador": {
		"color": Color("b36bff"), "exclude": ["swarmer"],
		"icon": ["..###..", ".#ooo#.", "#ooooo#", "#ooooo#", "#ooooo#", ".#ooo#.", "..###.."],
	},
	"saltarin": {
		"color": Color("4de8e0"), "exclude": ["swarmer"],
		"icon": ["...#...", "..#o#..", ".#ooo#.", "#ooooo#", ".#ooo#.", "..#o#..", "...#..."],
	},
	"reflector": {
		"color": Color("d8e0f0"), "exclude": [],
		"icon": [".#####.", "#oooo##", "#ooo#o#", "#oo#oo#", "#o#ooo#", "##oooo#", ".#####."],
	},
	"venenoso": {
		"color": Color("8fdc2a"), "exclude": [],
		"icon": [".#####.", "#ooooo#", "#o#o#o#", "#ooooo#", ".#ooo#.", ".#.#.#.", "......."],
	},
	"vengativo": {
		"color": Color("ff4fa0"), "exclude": [],
		"icon": ["...#...", "..##...", ".###.#.", ".#o###.", ".#oo##.", "..###..", "......."],
	},
	"pegajoso": {
		"color": Color("b8e84a"), "exclude": [],
		"icon": [".......", "..###..", ".#ooo#.", "#ooooo#", "#ooooo#", "#o#o#o#", ".#.#.#."],
	},
}

## Probabilidad de 2 afijos segun la profundidad (RunManager.depth): 1.0 -> 12%, 2.5 -> 39%, 5.5 -> 75% (tope).
const TWO_BASE := 0.12
const TWO_PER_DEPTH := 0.18
const TWO_MAX := 0.75


static func ids() -> Array:
	return DEFS.keys()


static func eligible(type_id: String) -> bool:
	return type_id in ELIGIBLE


## Sorteo con el RNG determinista del juego. [] si el tipo no admite afijos.
static func roll(type_id: String, depth: float) -> Array:
	if not eligible(type_id):
		return []
	var pool: Array = []
	for id in DEFS:
		if type_id not in DEFS[id].exclude:
			pool.append(id)
	RNG.shuffle(pool)
	var n := 1
	if RNG.randf() < clampf(TWO_BASE + TWO_PER_DEPTH * (depth - 1.0), 0.0, TWO_MAX):
		n = 2
	return pool.slice(0, n)


static func color_of(id: String) -> Color:
	return DEFS[id].color if DEFS.has(id) else Color.WHITE


static func affix_name(id: String) -> String:
	return Loc.tr_or("AFFIX_" + id.to_upper(), id.capitalize())


## "Explosivo y Vampiro" (traducido).
static func affixes_text(list: Array) -> String:
	var names: Array[String] = []
	for id in list:
		names.append(affix_name(id))
	return Loc.tr_or("AFFIX_AND", " y ").join(names)


## "Testiculo Errante [Vengativo]": el nombre del bicho (traducido) mas sus afijos.
## enemy_name NO se cambia en el enemigo (lo usan los contadores del codice y el narrador).
static func full_name(enemy_name: String, list: Array) -> String:
	if list.is_empty():
		return Loc.enemy_name(enemy_name)
	return Loc.tr_or("AFFIX_FMT", "%s [%s]") % [Loc.enemy_name(enemy_name), affixes_text(list)]


## Cuelga los afijos al enemigo (antes o despues de entrar al arbol). Devuelve los nodos.
static func attach(enemy: Node2D, list: Array) -> Array:
	var out: Array = []
	if list.is_empty() or enemy == null:
		return out
	var tag := AffixTag.new()
	tag.name = "AffixTag"
	tag.ids = list.duplicate()
	enemy.add_child(tag)
	enemy.set_meta("affix_ids", list.duplicate())
	for id in list:
		var path: String = DIR + "affix_%s.gd" % id
		if not DEFS.has(id) or not ResourceLoader.exists(path):
			push_warning("Affixes: afijo desconocido '%s'" % id)
			continue
		var node: Node = (Room.cached_load(path) as GDScript).new()
		node.name = "Affix_" + id
		node.set("id", id)
		node.set("tag", tag)
		enemy.add_child(node)
		out.append(node)
	tag.affix_nodes = out
	return out


## Scripts de todos los afijos cargados de antemano (el primer elite de la partida congelaba ~40 ms).
static func warm() -> void:
	Room.warm(DEFS.keys().map(func(id): return DIR + "affix_%s.gd" % id))


static func ids_of(enemy: Node) -> Array:
	return enemy.get_meta("affix_ids", []) if enemy != null else []


static func has(enemy: Node, id: String) -> bool:
	return id in ids_of(enemy)


## Gancho de dano (lo llama EnemyAI.on_damage): cada afijo puede absorber o modificar.
static func filter_damage(enemy: Node, amount: float, source: Node) -> float:
	if enemy == null or not enemy.has_meta("affix_ids"):
		return amount
	for n in enemy.get_children():
		if n is Affix:
			amount = n.filter_damage(amount, source)
	return amount
