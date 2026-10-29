class_name SaveSlots
extends RefCounted

## Tres espacios de guardado (Nico, 2026-10-29): cada uno es una carpeta user://slot_N/ con el progreso
## entero (meta, codice, narrador, cuarta pared, medallas, memoria del Algoritmo). Los ajustes
## (settings.cfg) y la ayuda de teclas son de la maquina y no van por espacio.
## Se elige al iniciar el juego (src/scenes/save_slots.gd, tras el aviso +16) y desde el menu.
## Quien guarda o carga pide su ruta con SaveSlots.path("archivo.json").

const COUNT := 3
const FILES := ["meta_save.json", "lore_progress.json", "narrator.json", "fourth_wall.json", "medallas.json", "algoritmo_memoria.json"]
const CFG := "user://slots.cfg"

static var _current := 0  # 0 = sin leer todavia


## Espacio activo (1..COUNT). La primera vez lee slots.cfg y pasa el guardado de antes (suelto en user://) al 1.
static func current() -> int:
	if _current == 0:
		var cfg := ConfigFile.new()
		var first := cfg.load(CFG) != OK
		_current = clampi(int(cfg.get_value("slots", "current", 1)), 1, COUNT)
		if first:
			_migrate_legacy()
			_store_current()
	return _current


static func path(file: String) -> String:
	return dir(current()) + "/" + file


static func dir(i: int) -> String:
	return "user://slot_%d" % i


static func is_empty(i: int) -> bool:
	for f: String in FILES:
		if FileAccess.file_exists(dir(i) + "/" + f):
			return false
	return true


static func first_empty(except := 0) -> int:
	for i in range(1, COUNT + 1):
		if i != except and is_empty(i):
			return i
	return 0


## Cambia de espacio y recarga todo lo que vive en los autoloads (el resto se lee al usarse).
static func select(i: int) -> void:
	flush_all()
	_current = clampi(i, 1, COUNT)
	_store_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir(_current)))
	var root := (Engine.get_main_loop() as SceneTree).root
	root.get_node("RunManager").load_meta()
	root.get_node("LoreDatabase").reload_progress()
	root.get_node("Narrator").reload_memory()
	root.get_node("Medallas").reload_progress()
	root.get_node("FourthWall").reload()


## Lo pendiente de guardar va al espacio de ahora antes de cambiar o tocar archivos.
static func flush_all() -> void:
	var root := (Engine.get_main_loop() as SceneTree).root
	root.get_node("LoreDatabase").flush()


static func copy(src: int, dst: int) -> void:
	flush_all()
	erase(dst)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir(dst)))
	for f: String in FILES:
		var from := dir(src) + "/" + f
		if FileAccess.file_exists(from):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(from), ProjectSettings.globalize_path(dir(dst) + "/" + f))


static func erase(i: int) -> void:
	for f: String in FILES:
		var p := dir(i) + "/" + f
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if i == current():
		select(i)  # el activo queda en blanco tambien en memoria


## Resumen para la pantalla de espacios (lee los archivos, no los autoloads).
static func summary(i: int) -> Dictionary:
	var out := {"empty": is_empty(i), "bones": 0, "runs": 0, "best_floor": 0, "liberated": 0, "codex": 0, "medals": 0, "date": ""}
	var meta = _read(dir(i) + "/meta_save.json")
	out.bones = int(meta.get("meta_currency", 0))
	out.runs = int(meta.get("total_runs", 0))
	out.best_floor = int(meta.get("best_floor", 0))
	var lib = meta.get("liberated", [])
	out.liberated = lib.size() if lib is Array else 0
	var lore = _read(dir(i) + "/lore_progress.json")
	var un = lore.get("unlocked", [])
	out.codex = un.size() if un is Array else 0
	var med = _read(dir(i) + "/medallas.json")
	var won = med.get("won", {})
	out.medals = won.size() if won is Dictionary else 0
	var newest := 0
	for f: String in FILES:
		var p := dir(i) + "/" + f
		if FileAccess.file_exists(p):
			newest = maxi(newest, FileAccess.get_modified_time(p))
	if newest > 0:
		out.date = Time.get_date_string_from_unix_time(newest)
	return out


static func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}


static func _store_current() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("slots", "current", _current)
	cfg.save(CFG)


## Guardado de antes de los espacios (archivos sueltos en user://): pasa entero al espacio 1.
static func _migrate_legacy() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir(1)))
	for f: String in FILES:
		var old := "user://" + f
		if FileAccess.file_exists(old) and not FileAccess.file_exists(dir(1) + "/" + f):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(old), ProjectSettings.globalize_path(dir(1) + "/" + f))
