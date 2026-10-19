class_name WorldMap
extends RefCounted

## Estado del mapa del mundo (ver map_metroid.gd, que lo dibuja a pantalla completa): lee
## assets/data/world_map.json (sale de tools/gen_world_map.py, en celdas de cuadricula) y el estado
## de la ruta (RunManager: route_regions, seal_regions, seals(), next_options()) y los reinos
## liberados de forma permanente (RunManager.liberated). Solo LEE: no decide nada ni dibuja.

const FILE := "res://assets/data/world_map.json"

static var _data: Dictionary = {}

# estado de la ruta (se recalcula con refresh(); es barato)
var route: Array = []
var exist: Array = []
var opts: Array = []
var cur := ""
var back := ""
var center: Array = []
var body: Array = []
var lib: Array = []
## Reinos TOMADOS por la copia de seguridad del Algoritmo (RunManager.taken: region -> jefe que lo tomo).
var taken: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(FILE, FileAccess.READ)
		if f:
			var j = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				_data = j
	return _data


static func region_data(id: String) -> Dictionary:
	for r in data().get("regions", []):
		if str(r.id) == id:
			return r
	return {}


## Region donde esta el jugador ahora.
static func current_region(rm: Node) -> String:
	return str(rm.floor_data().get("region", ""))


## Nombre del reino: el de siempre si existe en FLOORS (Loc.region_name_id) o la clave de mapa_mundo.csv.
static func region_label(r: Dictionary, voz := false) -> String:
	if voz and r.has("name_key_lib"):
		return Loc.tr_or(str(r.name_key_lib), str(r.get("name_lib", r.name)))  # estado "liberado" (Las Tierras de la Voz)
	if str(r.id) in RunManager.regions():
		return Loc.region_name_id(str(r.id))
	return Loc.tr_or(str(r.name_key), str(r.name))


func refresh(rm: Node) -> void:
	route = RunManager.route_regions
	exist = RunManager.regions()
	opts = RunManager.next_options()
	cur = current_region(rm)
	back = str(route.back()) if not route.is_empty() else cur
	center = RunManager.ROUTES.get("center", [])
	body = RunManager.ROUTES.get("body", [])
	lib = rm.liberated
	taken = RunManager.taken


func visited(id: String) -> bool:
	return id in route or id == cur


## Reino "pasado": visitado, o inexistente (aun por disenar) con un reino posterior del centro visitado.
func reached(id: String) -> bool:
	if visited(id):
		return true
	var i := center.find(id)
	if i < 0 or id in exist:
		return false
	for c in center.slice(i + 1):
		if visited(str(c)):
			return true
	return false


func is_missing(id: String) -> bool:
	return id not in exist


func is_taken(id: String) -> bool:
	return taken.has(id)


## "Desorden": reino que existe, no esta liberado y no lo pisas ahora. Solo se marca cuando ya
## liberaste alguno (en la primera partida todo esta por liberar y las alertas serian ruido).
func is_disorder(id: String) -> bool:
	return not lib.is_empty() and id in exist and id not in lib and not visited(id)


## El reino tiene dos estados (diseno_E3 7.5): "silencio" y "liberado". Hoy solo Las Tierras del Silencio: al
## transformarse (Silencio.liberado en esta partida, o liberado de forma permanente) pasa a "Las Tierras de la Voz".
func voz(r: Dictionary) -> bool:
	return r.has("color_lib") and str(r.id) == Silencio.REGION and (Silencio.REGION in lib or Silencio.liberado)


## Jefe vencido: reino liberado, o reino de la ruta que ya dejaste atras (para salir hay que vencerlo).
func boss_defeated(id: String) -> bool:
	return id in lib or (id in route and id != cur)


## "used" / "possible" / "idle" segun la ruta.
func door_state(door: Dictionary) -> String:
	var fr := str(door["from"])
	var to := str(door["to"])
	var next_c := str(opts[0]) if opts.size() == 1 and str(opts[0]) in center else ""
	if door.kind == "eleccion":
		var i := route.find(fr)
		if i >= 0 and i + 1 < route.size() and str(route[i + 1]) in body:
			return "used"
		if fr == back and not opts.is_empty() and str(opts[0]) in body:
			return "possible"
		return "idle"
	if fr in body:  # puerta del cuerpo al centro (candado de sellos)
		var last_body := ""
		for r in route:
			if str(r) in body:
				last_body = str(r)
		if fr == last_body and reached(to):
			return "used"
		if fr == back and next_c != "":
			return "possible"
		return "idle"
	if reached(to) and reached(fr):
		return "used"
	# tramo del centro hacia el siguiente reino: se ilumina el camino que viene
	if next_c != "" and center.find(to) <= center.find(next_c) and (center.find(fr) >= center.find(back) or back in body):
		return "possible"
	return "idle"
