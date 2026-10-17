class_name EnemyRegistry
extends RefCounted

## Registro de enemigos por id legible -> PackedScene. Los datos (pisos, extras, menu de
## debug) y el codigo usan el id ("melee", "its", ...) en vez de un indice numerico.
##
## Auto-registro: cada escena src/enemies/enemy_<id>.tscn queda registrada sola como
## "<id>" (enemy_taser.tscn -> "taser"). Para agregar un enemigo nuevo basta con crear su
## escena con ese nombre y usar el id en los datos: no hay lista que editar.
## ALIASES es solo para escenas que no siguen la convencion (una linea por enemigo).
##
## Ids actuales: melee, ranged, swarmer, tank, boss, taser, inspector, espinilla, its.

const DIR := "res://src/enemies/"
const ALIASES := {
	"melee": "res://src/enemies/enemy.tscn",  # el cuerpo a cuerpo base no lleva sufijo
}
## Si un dato pide un id que no existe se usa este (y se avisa).
const FALLBACK := "melee"

static var _paths: Dictionary = {}
static var _scenes: Dictionary = {}


static func _scan() -> void:
	if not _paths.is_empty():
		return
	_paths = ALIASES.duplicate()
	# list_directory entiende los .remap del juego exportado (igual que item_database).
	for file in ResourceLoader.list_directory(DIR):
		if file.begins_with("enemy_") and file.ends_with(".tscn"):
			var id := file.trim_prefix("enemy_").trim_suffix(".tscn")
			if not _paths.has(id):
				_paths[id] = DIR + file


## Ids registrados, ordenados.
static func ids() -> Array:
	_scan()
	var out: Array = _paths.keys()
	out.sort()
	return out


static func has(id: String) -> bool:
	_scan()
	return _paths.has(id)


static func path(id: String) -> String:
	_scan()
	return _paths.get(id, "")


## Escena del enemigo (cacheada). Id desconocido -> FALLBACK con aviso.
static func scene(id: String) -> PackedScene:
	_scan()
	if not _paths.has(id):
		push_warning("EnemyRegistry: id de enemigo desconocido '%s', uso '%s'" % [id, FALLBACK])
		id = FALLBACK
	if not _scenes.has(id):
		_scenes[id] = load(_paths[id])
	return _scenes[id]


## Carga todas las escenas de una vez (main lo llama al empezar para que el primer
## spawn de cada tipo no dé tirón, como hacian los preload de antes).
static func preload_all() -> void:
	for id in ids():
		scene(id)
