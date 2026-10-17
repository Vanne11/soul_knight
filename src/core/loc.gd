class_name Loc
extends RefCounted

## Textos de DATOS (objetos, lore, narrador, pisos, enemigos, personajes, bendiciones,
## mejoras) traducidos al mostrarlos. Los datos siguen en espanol: son la fuente y a veces
## el id (p.ej. LoreEntry.unlock_condition.target_id = nombre del enemigo en espanol, y
## enemy_name se compara asi). Por eso NUNCA se traduce el dato en origen: solo aqui,
## justo antes de pintarlo. Si no hay traduccion (TranslationServer devuelve la clave)
## se cae al texto original en espanol.
## Claves (locale/items|lore|narrator|world.csv) las genera tools/extract_locale_data.py.

static var _enemy_keys: Dictionary = {}  # nombre en espanol -> clave
static var _extra_loaded := false

const LOCALE_DIR := "res://locale/"


## Carga las traducciones de locale/ que no esten en project.godot (locale/translations):
## cada bloque crea su locale/<bloque>.csv, Godot genera <bloque>.<idioma>.translation al
## importarlo y aqui se suma sola, sin tocar project.godot. Lo llama el Narrator al
## arrancar (es el primer autoload con textos). tools/register_locales.py las registra
## en project.godot para dejarlo ordenado; con eso esto no hace nada.
## Devuelve las rutas cargadas (para pruebas).
static func load_unregistered_translations() -> PackedStringArray:
	var loaded := PackedStringArray()
	if _extra_loaded:
		return loaded
	_extra_loaded = true
	var registered: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	var files := Array(ResourceLoader.list_directory(LOCALE_DIR))
	files.sort()
	for f in files:
		var path: String = LOCALE_DIR + f
		if f.get_extension() != "translation" or path in registered:
			continue
		var t := load(path) as Translation
		if t:
			TranslationServer.add_translation(t)
			loaded.append(path)
	return loaded


static func tr_or(key: String, fallback: String) -> String:
	var s := String(TranslationServer.translate(key))
	return fallback if s == key or s == "" else s


# ------------------------------------------------------------------ objetos
static func item_name(item) -> String:
	return tr_or("ITEM_%s_NAME" % String(item.id).to_upper(), item.display_name)


static func item_desc(item) -> String:
	return tr_or("ITEM_%s_DESC" % String(item.id).to_upper(), item.description)


## Linea de afinidad del cuadro de objeto (BBCode): "Afinidad: Pene" y, si el heroe es de
## ese reino, "(¡te sienta bien!)". "" si el objeto no tiene afinidad. Los datos: custom_data.affinity.
const AFFINITY_COLORS := {"pene": "6ec6ff", "vulva": "ff7ac0", "neutral": "c9c2b0"}

static func affinity_line(item) -> String:
	var aff: String = item.custom_data.get("affinity", "")
	if not AFFINITY_COLORS.has(aff):
		return ""
	var line := "[color=#%s]%s[/color]" % [AFFINITY_COLORS[aff], tr_or("AFFINITY_" + aff.to_upper(), aff)]
	var rm: Node = (Engine.get_main_loop() as SceneTree).root.get_node("RunManager")
	if aff != "neutral" and rm.character_data().kingdom == aff:
		line += " [color=#ffd75a]%s[/color]" % tr_or("AFFINITY_FIT", "(¡te sienta bien!)")
	return line


# ------------------------------------------------------------------ lore
static func lore_title(e) -> String:
	return tr_or("LORE_%s_TITLE" % String(e.id).to_upper(), e.title)


static func lore_text(e) -> String:
	return tr_or("LORE_%s_TEXT" % String(e.id).to_upper(), e.text)


static func lore_flavor(e) -> String:
	return tr_or("LORE_%s_FLAVOR" % String(e.id).to_upper(), e.flavor_text)


# ------------------------------------------------------------------ narrador
## Clave de traduccion de la frase i-esima de un evento en assets/data/narrator/<stem>.json
## (i = indice dentro de ESE archivo). lines.json conserva las claves de siempre
## (NARR_<EVENTO>_<i>, locale/narrator.csv); los demas archivos llevan su nombre delante,
## con doble guion bajo para no chocar con eventos de lines.json:
## NARR_<STEM>__<EVENTO>_<i> (locale/narrator_<stem>.csv, ver tools/extract_locale_data.py).
static func narr_key(stem: String, event: String, i: int) -> String:
	if stem == "lines":
		return "NARR_%s_%d" % [event.to_upper(), i]
	return "NARR_%s__%s_%d" % [stem.to_upper(), event.to_upper(), i]


static func narr_line(key: String, fallback: String) -> String:
	return tr_or(key, fallback)


# ------------------------------------------------------------------ mundo
## Piso: numero 1..N o el diccionario de RunManager.FLOORS. short = version del mapa.
## Claves: 1a etapa FLOOR_<reino 1..5>_NAME/SHORT (las de siempre); 2a etapa FLOOR_<reino>B_NAME/SHORT.
static func floor_name(floor_or_fd, short := false) -> String:
	var floors: Array = RunManager.FLOORS
	var n := 0
	var fb := ""
	if floor_or_fd is Dictionary:
		n = floors.find(floor_or_fd) + 1
		fb = floor_or_fd.get("name", "")
	else:
		n = int(floor_or_fd)
		if n >= 1 and n <= floors.size():
			fb = floors[n - 1].name
	if short:
		fb = fb.replace("EL PALACIO DE LA ", "PALACIO ")
	if n < 1:
		return fb
	var suffix := "B" if RunManager.floor_stage(n) > 1 else ""
	return tr_or("FLOOR_%d%s_%s" % [RunManager.region_index(n) + 1, suffix, "SHORT" if short else "NAME"], fb)


## Nombre del reino al que pertenece el piso (el de su 1a etapa): "LA SELVA PÚBICA" para el
## Folículo Profundo. Para textos de liberacion, que valen para las dos etapas.
static func region_name(floor_n: int, short := false) -> String:
	var r := RunManager.floor_region(floor_n)
	for i in RunManager.FLOORS.size():
		if RunManager.FLOORS[i].region == r:
			return floor_name(i + 1, short)
	return floor_name(floor_n, short)


static func _build_enemy_keys() -> void:
	for f in RunManager.FLOORS:
		for pair in [["roster", "names"], ["alt_roster", "alt_names"]]:
			if f.has(pair[0]):
				for i in f[pair[0]].size():
					_enemy_keys[f[pair[1]][i]] = "ENEMY_%s_NAME" % String(f[pair[0]][i]).to_upper()
		for x in f.get("extra", []):
			_enemy_keys[x.name] = "ENEMY_%s_NAME" % String(x.variant).to_upper()
		if f.boss_name != "":
			_enemy_keys[f.boss_name] = "BOSS_%s_NAME" % String(f.boss).trim_prefix("boss_").to_upper()


## Nombre visible (en espanol, tal cual en los datos) de enemigo o jefe -> traducido.
## Los minijefes se llaman "<bicho> Gigante".
static func enemy_name(es_name: String) -> String:
	if _enemy_keys.is_empty():
		_build_enemy_keys()
	if _enemy_keys.has(es_name):
		return tr_or(_enemy_keys[es_name], es_name)
	if es_name.ends_with(" Gigante"):
		var base := es_name.trim_suffix(" Gigante")
		var fmt := tr_or("ENEMY_GIANT_FMT", "%s Gigante")
		return fmt % enemy_name(base)
	return es_name


## field: "name" | "title" | "perk" | "bio"
static func char_field(id: String, field: String) -> String:
	return tr_or("CHAR_%s_%s" % [id.to_upper(), field.to_upper()], RunManager.CHARACTERS.get(id, {}).get(field, ""))


## field: "name" | "desc"
static func blessing(id: String, field: String) -> String:
	return tr_or("BLESSING_%s_%s" % [id.to_upper(), field.to_upper()], RunManager.BLESSINGS.get(id, {}).get(field, ""))


## field: "name" | "desc"
static func meta(id: String, field: String) -> String:
	return tr_or("META_%s_%s" % [id.to_upper(), field.to_upper()], RunManager.META_UPGRADES.get(id, {}).get(field, ""))


## Nombre del reino ("pene"/"vulva") en mayusculas, como KINGDOM_NAMES de main.gd.
static func kingdom_name(k: String) -> String:
	var es: String = {"pene": "PENELANDIA", "vulva": "VULVANIA"}.get(k, "")
	return tr_or("KINGDOM_%s_NAME" % k.to_upper(), es) if es != "" else k
