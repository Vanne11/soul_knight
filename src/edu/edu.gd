class_name Edu
extends RefCounted

## Educacion sexual ligera (etapa 4a). Datos en assets/data/edu/*.json (ids, fuentes y la
## marca "validar": true para que Vanessa los revise); los textos, en locale/edu.csv.
## Regla de Nico: guiños breves, opcionales y con humor; nada obliga ni interrumpe, y quien
## quiera mas lo tiene en el codice.

const DIR := "res://assets/data/edu/"

static var _cache: Dictionary = {}
## Ids ya mostrados en esta sesion (se reinicia al agotarlos): no se repite hasta que salen todos.
static var _seen_facts: Array = []
static var _seen_mv: Array = []


static func _json(file: String) -> Variant:
	if not _cache.has(file):
		var res = load(DIR + file)
		_cache[file] = res.data if res is JSON else null
	return _cache[file]


## Autoloads sin singleton (PlayerStats, RunManager, GlobalEvents): el nombre es la clase, no la instancia.
static func ps() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("PlayerStats")


static func rm() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("RunManager")


static func ge() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GlobalEvents")


## Traduccion por clave (tr() es de instancia: aqui todo es estatico).
static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


static func _pick(items: Array, seen: Array) -> Dictionary:
	if items.is_empty():
		return {}
	var fresh := items.filter(func(e): return not seen.has(e.id))
	if fresh.is_empty():
		seen.clear()
		fresh = items
	var e: Dictionary = fresh[RNG.randi_range(0, fresh.size() - 1)]
	seen.append(e.id)
	return e


## Un dato breve de "¿Sabias que...?", distinto cada vez dentro de la sesion. "" si no hay datos.
static func next_fact() -> String:
	var d = _json("sabias_que.json")
	if d == null:
		return ""
	var e := _pick(d.items, _seen_facts)
	return t("EDU_FACT_" + String(e.id).to_upper()) if not e.is_empty() else ""


## Una pregunta de Mito o Verdad: {id, es_verdad, pregunta, explicacion}. {} si no hay datos.
static func next_mito_verdad() -> Dictionary:
	var d = _json("mito_verdad.json")
	if d == null:
		return {}
	var e := _pick(d.items, _seen_mv)
	if e.is_empty():
		return {}
	var k := String(e.id).to_upper()
	return {"id": e.id, "es_verdad": e.respuesta == "verdad",
		"pregunta": t("EDU_MV_%s_Q" % k), "explicacion": t("EDU_MV_%s_A" % k)}


## Linea "Fuente: ..." (BBCode) para el detalle del codice; "" si la entrada no tiene.
static func source_line(lore_id: String) -> String:
	var d = _json("fuentes_codice.json")
	if d == null or not d.items.has(lore_id):
		return ""
	return "[font_size=12][color=#8a8494]%s[/color][/font_size]" % (t("EDU_SOURCE_LABEL") % d.items[lore_id].fuente)


static func consultorio_cfg() -> Dictionary:
	var d = _json("consultorio.json")
	return d if d != null else {}


## Precio en monedas: sube con el piso igual que la tienda (shop_item.gd FLOOR_MARKUP).
static func price(base: int) -> int:
	return int(round(base * (1.0 + 0.15 * (RunManager.depth(rm().current_floor) - 1.0)) * Censura.mult("price")))
