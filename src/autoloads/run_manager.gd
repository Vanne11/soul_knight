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
## liberated_variant: (GANCHO, sin implementar) id de otro reino en el que se transforma este al
##   liberarlo. Para Silencio: no es un reino de celebracion, al liberarlo pasa a ser un reino de
##   igualdad. Hoy solo se lee con RunManager.liberated_variant(region); nadie lo aplica aun.
## peace: true lo pone RunManager.begin_rescue en la copia del piso que se recorre en paz (no va en los JSON).
## tint: color de la sala cuando la liberas (antes de eso esta gris: censurada). En el
##   JSON va en hex ("7fe0a0") y aqui se convierte a Color.
## wip: true marca un reino INCOMPLETO (hoy: Las Tierras del Silencio, 80_silencio.json). Sus pisos
##   NO entran en FLOORS: ni en regions() ni en la ruta (routes.json los nombra y se saltan, como
##   cualquier reino sin JSON). Esperan en WIP_FLOORS hasta RunManager.enable_wip(), que los suma a
##   FLOORS en el orden de sus prefijos; solo lo llama la opcion de depuracion F1 "Ir al Silencio
##   (WIP)" (debug_menu.gd). Para publicar el reino: quitar "wip" del JSON de cada piso.
## layout: "silencio" (opcional) = el piso no usa el trazado BSP sino la cadena de salas de situacion
##   de src/silencio/silencio.gd (Silencio.plan_layout), sin enemigos.
## FLOORS se carga una vez al cargar el script (static var): mismo Array de Dictionary que
## antes era const, accesible igual como RunManager.FLOORS.
const FLOORS_DIR := "res://assets/data/floors/"
const FLOORS_EXTRA_DIR := "res://assets/data/floors/extra/"
## Pisos "wip": true, fuera de FLOORS hasta enable_wip(). Va ANTES que FLOORS: _load_floors lo llena.
static var WIP_FLOORS: Array = []
static var wip_enabled := false
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
		f.file = file
		if not f.has("region"):
			f.region = f.id
		f.stage = int(f.get("stage", 1))
		f.elite_chance = float(f.get("elite_chance", 0.0))
		if not f.has("boss"):
			f.boss = ""
			f.boss_name = ""
		if bool(f.get("wip", false)):
			WIP_FLOORS.append(f)  # reino incompleto: fuera de la ruta hasta enable_wip()
			continue
		floors.append(f)
		ids.append(_floor_id(file))
	_load_extra_files(floors, ids)
	if floors.is_empty():
		push_error("RunManager: no hay pisos en %s" % FLOORS_DIR)
	return floors


## Suma los pisos "wip" a FLOORS (y por tanto a regions() y a la ruta). Solo para depuracion
## (debug_menu.gd, "Ir al Silencio (WIP)"); dura lo que la sesion.
static func enable_wip() -> void:
	if wip_enabled:
		return
	wip_enabled = true
	FLOORS.append_array(WIP_FLOORS)
	FLOORS.sort_custom(func(a, b): return str(a.file) < str(b.file))


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


## --- RUTAS: sellos + eleccion de puerta (assets/data/routes.json) ---
## "body" = reinos del cuerpo (su jefe final da 1 sello), "center" = reinos del centro en orden,
## "seals_needed" = sellos para abrir el centro, "start" = reino inicial por heroe (con "default").
## La ruta NO es una lista fija: se arma sobre la marcha. Al terminar un reino (next_options):
## sellos < seals_needed -> el jugador elige entre los reinos de body sin visitar; si no, el
## siguiente reino de center sin visitar. Los reinos sin JSON en floors/ se saltan. Meter un
## reino nuevo = su JSON en floors/ + su id en routes.json, sin tocar codigo.
const ROUTES_FILE := "res://assets/data/routes.json"
static var ROUTES: Dictionary = _load_routes()
## Pisos (Dictionary de FLOORS) de la ruta activa hasta ahora, en orden; vacia = orden de los archivos.
static var route_floors: Array = []
## Ids de region de la ruta activa, en orden de visita (para dificultad por posicion).
static var route_regions: Array = []
## Reinos que dieron sello en esta partida.
static var seal_regions: Array = []
## La ruta se arma por sellos (true) o es una lista fija puesta con set_route (false).
static var route_dynamic := false
## Eleccion de puerta del bot (--route-pick): "first", "random" (determinista) o un id de region.
static var route_pick := "first"
## Run de rescate (post-juego "Desordenes"): ruta fija = tramos en paz por reinos ya liberados +
## los reinos pendientes (ver begin_rescue).
static var rescue_mode := false
## Reinos de la ruta que se cruzan en paz (un piso corto sin combates, ver _peace_floor).
static var peace_regions: Array = []


static func _load_routes() -> Dictionary:
	var r = _read_json(ROUTES_FILE)
	return r if r is Dictionary else {}


static func _existing(ids: Array) -> Array:
	var all := regions()
	return ids.filter(func(id): return str(id) in all)


static func body_regions() -> Array:
	return _existing(ROUTES.get("body", []))


static func center_regions() -> Array:
	return _existing(ROUTES.get("center", []))


static func seals_needed() -> int:
	return int(ROUTES.get("seals_needed", 2))


## Reino inicial del heroe (start.<heroe>; si no existe en FLOORS, start.default).
static func start_region(hero: String) -> String:
	var st: Dictionary = ROUTES.get("start", {})
	var all := regions()
	var r := str(st.get(hero, st.get("default", "")))
	if r not in all:
		r = str(st.get("default", ""))
	if r not in all:
		r = all[0] if not all.is_empty() else ""
	return r


static func seals() -> int:
	return seal_regions.size()


## Reinos en el orden del mundo/historia (body y luego center; los que falten van al final, en
## orden de archivo). Para listarlos al jugador; NO cambia ids ni guardados.
static func world_order() -> Array:
	var out: Array = body_regions() + center_regions()
	var optional := detour_regions()
	for r in regions():
		if r not in out and r not in optional:  # los desvios opcionales no cuentan como reino obligatorio
			out.append(r)
	return out


## DESVIOS (routes.json "detours"): puerta extra opcional desde el jefe final de un reino hacia un reino
## secreto. {"to": id, "open": bool} o {} si el reino no tiene. "open": true = la puerta biologica se puede abrir (en secreto); false = queda sellada.
static func detour_for(region: String) -> Dictionary:
	var d = ROUTES.get("detours", {}).get(region, {})
	return d if d is Dictionary else {}


## Ids de los reinos de desvio (no entran en la ruta base ni en el final verdadero).
static func detour_regions() -> Array:
	var out: Array = []
	for k in ROUTES.get("detours", {}):
		out.append(str(ROUTES.detours[k].get("to", "")))
	return out


## Reino "padre" de un desvio (donde esta su puerta) o "" si no es desvio.
static func detour_parent(region: String) -> String:
	for k in ROUTES.get("detours", {}):
		if str(ROUTES.detours[k].get("to", "")) == region:
			return str(k)
	return ""


## Estilo (kingdom de los JSON de piso) del reino: tilesets, puertas y decoracion. Mira tambien los pisos wip.
static func region_kingdom(region: String) -> String:
	for f in FLOORS + WIP_FLOORS:
		if f.region == region:
			return str(f.get("kingdom", "neutral"))
	return "neutral"


## Color de acento (tint) del reino.
static func region_tint(region: String) -> Color:
	for f in FLOORS + WIP_FLOORS:
		if f.region == region and f.has("tint"):
			return f.tint
	return Color.WHITE


static func _add_region_floors(id: String) -> void:
	route_regions.append(id)
	for f in FLOORS:
		if f.region == id:
			route_floors.append(f)


## Empieza la ruta de un heroe: solo su reino inicial; el resto se decide jugando.
static func begin_route(hero: String, _seed: int = 0) -> void:
	route_dynamic = true
	rescue_mode = false
	peace_regions = []
	route_regions = []
	route_floors = []
	seal_regions = []
	_add_region_floors(start_region(hero))


static func set_route_for(hero: String, seed_: int) -> void:
	begin_route(hero, seed_)


## Fija una ruta fija (lista de ids de region): sus pisos, por reino y etapa. Sin sellos ni eleccion.
static func set_route(region_ids: Array) -> void:
	route_dynamic = false
	rescue_mode = false
	peace_regions = []
	route_regions = []
	route_floors = []
	seal_regions = []
	for r in region_ids:
		_add_region_floors(str(r))


## Suma un reino (sus pisos) al final de la ruta activa si aun no esta.
static func add_region(id: String) -> void:
	if id not in route_regions:
		_add_region_floors(id)


## Reinos entre los que seguir al terminar el ultimo reino de la ruta: [] = fin de la partida,
## 1 = sigue solo (center), 2+ = el jugador elige (body, sellos insuficientes).
static func next_options(extra_seals := 0) -> Array:
	if seals() + extra_seals < seals_needed():
		var body: Array = body_regions().filter(func(id): return id not in route_regions)
		if not body.is_empty():
			return body
	for id in center_regions():
		if id not in route_regions:
			return [id]
	return []


## El piso n es el ultimo de su reino (su jefe es "el final" del reino).
static func is_region_last_floor(floor_n: int) -> bool:
	var f := _floor_at(floor_n)
	var last: Dictionary = {}
	for x in FLOORS:
		if x.region == f.region:
			last = x
	return last.get("id", "") == f.id


## Terminar este piso cierra la partida: es el final de su reino y no queda a donde ir.
static func is_route_end(floor_n: int) -> bool:
	if not route_dynamic:
		return floor_n >= route_size()
	return floor_n >= route_floors.size() and is_region_last_floor(floor_n) and next_options().is_empty()


## true si vencer al jefe de este piso DARIA un sello (mismas condiciones que award_seal, sin darlo).
static func would_award_seal(floor_n: int) -> bool:
	if not route_dynamic or not floor_has_boss(floor_n) or not is_region_last_floor(floor_n):
		return false
	var r := floor_region(floor_n)
	return r in ROUTES.get("body", []) and r not in seal_regions


## PASILLOS: reinos a los que llevan las puertas de la sala del jefe de este piso (el jefe FINAL de un
## reino). Existen desde que entras a la sala (selladas) y se abren al vencerlo; por eso cuenta el sello que
## ese jefe va a dar. Siguiente de la ruta si ya esta armada (rescate, saltos de depuracion) o las opciones por
## sellos. [] = no hay puertas de reino (etapa 1, tramo en paz, Silencio: escotilla de siempre).
static func exit_regions(floor_n: int) -> Array:
	if not floor_has_boss(floor_n) or not is_region_last_floor(floor_n) or floor_is_peace(floor_n) or Silencio.is_floor(floor_n):
		return []
	if floor_n < route_floors.size():
		var nf: Dictionary = floor_at(floor_n + 1)
		return [str(nf.region)] if str(nf.region) != floor_region(floor_n) and not floor_is_peace(floor_n + 1) else []
	if not route_dynamic:
		return []
	var out: Array = next_options(1 if would_award_seal(floor_n) else 0)
	if out.is_empty():
		return out  # fin de la partida: sin desvios
	# el desvio opcional (routes.json "detours") NO es una puerta mas: es la puerta biologica de main.gd (condicion secreta)
	return out


## Da el sello si el piso es el final de un reino del cuerpo y trae jefe. true si lo dio.
static func award_seal(floor_n: int) -> bool:
	if not route_dynamic or not floor_has_boss(floor_n) or not is_region_last_floor(floor_n):
		return false
	var r := floor_region(floor_n)
	if r not in ROUTES.get("body", []) or r in seal_regions:
		return false
	seal_regions.append(r)
	return true


## Elige un reino de las opciones segun route_pick: "first", "random" (semilla de la partida,
## determinista) o un id de region.
static func pick_option(options: Array, seed_: int) -> String:
	if route_pick == "random" and options.size() > 1:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_ * 2654435761 + 97 + route_regions.size()
		return str(options[rng.randi_range(0, options.size() - 1)])
	if route_pick in options:
		return route_pick
	return str(options[0])


## Prolonga la ruta (eligiendo con route_pick) hasta tener al menos n pisos. Para saltos de
## depuracion/pruebas.
static func extend_to(n: int) -> void:
	while route_dynamic and route_floors.size() < n:
		var o := next_options()
		if o.is_empty():
			return
		add_region(pick_option(o, 0))


## Cantidad de pisos PLANEADOS de la ruta activa (el ultimo trae el jefe final). Es determinista
## desde el inicio: los ya armados + los reinos de center que faltan + los reinos de body que
## faltan para llegar a seals_needed (el inicio cuenta como uno de los sellos si es del cuerpo).
static func route_size() -> int:
	if route_floors.is_empty():
		return FLOORS.size()
	if not route_dynamic:
		return route_floors.size()
	var total := route_floors.size()
	for id in center_regions():
		if id not in route_regions:
			total += _region_floor_count(id)
	var left: Array = body_regions().filter(func(id): return id not in route_regions)
	var visited_body: int = route_regions.filter(func(id): return id in body_regions()).size()
	var missing := mini(maxi(seals_needed() - visited_body, 0), left.size())
	if missing > 0:
		var sum := 0
		for id in left:
			sum += _region_floor_count(id)
		total += roundi(float(sum) / float(left.size()) * missing)
	return total


static func _region_floor_count(id: String) -> int:
	return FLOORS.filter(func(f): return f.region == id).size()


## Ultimo piso del juego (jefe final): el ultimo piso del ultimo reino de center que existe.
static func final_floor() -> Dictionary:
	var c := center_regions()
	var region: String = c[c.size() - 1] if not c.is_empty() else str(FLOORS[FLOORS.size() - 1].region)
	var last: Dictionary = FLOORS[FLOORS.size() - 1]
	for f in FLOORS:
		if f.region == region:
			last = f
	return last


static func _as_list(v) -> Array:
	if v is Array:
		return v
	return [] if str(v) == "" else [str(v)]


## Personajes. Mismas stats base: cada uno tiene un perk distinto, ninguno es "el debil".
## hormone: la que llevas de serie. La del reino contrario te da alergia (salvo al ornitorrinco).
const CHARACTERS := {
	"pitocles": {"name": "PITOCLES", "title": "Héroe de Penelandia", "kingdom": "pene", "hormone": "testosterona",
		"perk": "Escudo: bloquea de frente y, con parry a tiempo, devuelve la bala. Su dash aturde. Más duro, más lento.",
		"bio": "Hoplita veterano de la Guerra Fría Hormonal. Lleva penacho rojo porque dijeron que da autoridad. No la da."},
	"vulvalquiria": {"name": "VULVALQUIRIA", "title": "Heroína de Vulvania", "kingdom": "vulva", "hormone": "estrogeno",
		"perk": "Más rápida, con doble dash y alas que planean. Grito: los enemigos huyen. Menos vida, mejores esquivas.",
		"bio": "Guerrera de los fiordos de Vulvania. Cero batallas perdidas, sin contar las que abandonó. Va por la Hoja con trenzas y sin paciencia."},
	"ornitorrinco": {"name": "ORNITORRINCO", "title": "No especifica", "kingdom": "ninguno", "hormone": "",
		"perk": "Electrorrecepción: ve lo invisible. Huevo-trampa y espolón venenoso. Sin alergias, sin reino.",
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
	var played: Array = route_regions
	if not peace_regions.is_empty():
		played = route_regions.filter(func(x): return x not in peace_regions)  # los tramos en paz no suben la dificultad
	var parent := detour_parent(r)
	if parent != "":
		r = parent  # un desvio opcional tiene la dificultad del reino donde esta su puerta
	played = played.filter(func(x): return x not in detour_regions())  # y no sube la de los reinos que siguen
	var i: int = played.find(r) if not route_floors.is_empty() else regions().find(r)
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
	taken.erase(r)  # si estaba tomado (copia de seguridad), vuelve a ser libre
	get_node("/root/GlobalEvents").game_event.emit("reino_liberado")  # medallas
	if desorden_notice and pending_regions().is_empty():
		desorden_notice = false  # ya no queda ningun desorden
	save_meta_progression()
	return true

## --- Post-juego "Desordenes" ---
## Tras ganar, cada heroe solo cruzo parte de los reinos: los que no estan en `liberated` (progreso
## permanente) quedan "en desorden". El aviso se recuerda entre partidas hasta liberarlos todos.
var desorden_notice := false
## Lo piden el panel del post-juego / el menu y lo consume start_new_run.
var rescue_requested := false
## true = otro heroe (arranca en SU reino de inicio); false = el mismo, "caminando" desde donde ganaste.
var rescue_new_hero := false
## Heroe que gano y se cambia: el selector lo deshabilita (la idea es probar otro).
var rescue_swap_from := ""
## Maximo de reinos pendientes por run de rescate y de tramos en paz antes del primero.
const RESCUE_MAX_TARGETS := 2
const PEACE_MAX_STOPS := 3

## Reinos existentes sin liberar, en el orden del mundo.
func pending_regions() -> Array:
	return world_order().filter(func(r): return r not in liberated)

## Marca (o borra) el aviso segun lo que quede pendiente. Se llama al ganar.
func note_desordenes() -> void:
	desorden_notice = not pending_regions().is_empty()
	save_meta_progression()

## --- PLAN 6: la copia de seguridad del Algoritmo (historia.md, seccion 2 y 7) ---
## Estado persistente (meta_save.json). El Algoritmo Moderador es un jefe SECRETO opcional del Archivo
## (piso 2 del Palacio): vencerlo marca `algoritmo_vencido` y la copia de seguridad ya no existe.
## Si vences a la Hoja de Parra SIN haberlo vencido, "restaura su copia": cada reino liberado que
## tenga jefe de retorno pasa a TOMADO (sale de `liberated`, entra en `taken`), asi que todo lo del
## post-juego (pending_regions, rutas de rescate, panel de desordenes) lo trata como pendiente.
## Reinos tomados: region -> {"variant", "name"} del jefe que lo tomo (estatico: lo lee BossPicker).
static var taken: Dictionary = {}
var algoritmo_vencido := false
## Venciste a la Hoja sin vencer al Algoritmo (hay copia de seguridad restaurada).
var copia_restaurada := false
## La intro larga de la copia de seguridad ya se conto una vez (despues solo el resumen).
var copia_intro_vista := false
## Todos los reinos liberados al mismo tiempo: final verdadero (gancho para medallas/platino).
var final_verdadero := false
## Cuantas veces se mostro la intro completa (0 = primera vez).
var intro_vistas := 0
## Derrotas seguidas (se pone a 0 al ganar).
var derrotas_seguidas := 0
## Heroe de la partida con la que terminaste el juego sin vencer al Algoritmo: {hero, region}. Aparece
## entre los restos de heroes anteriores del decorado (room_decor.gd).
var heroe_resto: Dictionary = {}
## Final de la ultima victoria: "" (normal), "copia", "completo" (Hoja y Algoritmo) o "verdadero".
var last_ending := ""
## Gancho para medallas/platino: se emite al lograr el final verdadero.
signal true_ending_reached


## Jefe con el que un reino vuelve a ser tomado: {variant, name} o {} (silencio, palacio...). Es el jefe
## alternativo del reino ("boss_alt") o, si el piso lo marca "boss_returns": true (Utero, Arcoiria), su
## propio jefe de siempre.
static func takeover_for(region: String) -> Dictionary:
	for f in FLOORS:
		if f.region != region or str(f.boss) == "":
			continue
		if str(f.get("boss_alt", "")) != "":
			return {"variant": str(f.boss_alt), "name": str(f.get("boss_alt_name", f.boss_name))}
		if bool(f.get("boss_returns", false)):
			return {"variant": str(f.boss), "name": str(f.boss_name)}
	return {}


## Jefe que tiene tomado el reino ({variant, name}) o {} si no esta tomado.
static func taken_boss(region: String) -> Dictionary:
	var t = taken.get(region, {})
	return t if t is Dictionary else {}


## Ultimo reino de la ruta del juego (el palacio de la Hoja de Parra).
static func final_region() -> String:
	return str(final_floor().region)


## El Algoritmo cae: la copia de seguridad se destruye. Los reinos tomados vuelven a ser libres.
func defeat_algoritmo() -> void:
	algoritmo_vencido = true
	get_node("/root/GlobalEvents").game_event.emit("algoritmo_vencido")  # medallas
	copia_restaurada = false
	for r in taken.keys():
		if r not in liberated:
			liberated.append(r)
	taken.clear()
	note_desordenes()


## Se llama al vencer al jefe que cierra la partida (fin de ruta; el piso ya se libero). Decide el final
## y deja el estado persistente: "copia" | "completo" | "verdadero" | "" (victoria normal de rescate).
func resolve_victory(floor_n: int, was_liberated: bool) -> String:
	var kind := ""
	if floor_region(floor_n) == final_region() and not was_liberated:
		if algoritmo_vencido:
			kind = "completo"
		else:
			kind = "copia"
			_restore_backup(floor_n)
	if pending_regions().is_empty():
		kind = "verdadero"
		if not final_verdadero:
			final_verdadero = true
			true_ending_reached.emit()
			get_node("/root/GlobalEvents").game_event.emit("final_verdadero")  # medallas
	derrotas_seguidas = 0
	last_ending = kind
	note_desordenes()
	return kind


## "El Algoritmo restauro su copia de seguridad": los reinos liberados con jefe de retorno quedan tomados.
func _restore_backup(floor_n: int) -> void:
	copia_restaurada = true
	copia_intro_vista = false
	heroe_resto = {"hero": character, "region": floor_region(floor_n)}
	for r in liberated.duplicate():
		var t := takeover_for(str(r))
		if not t.is_empty():
			taken[r] = t
			liberated.erase(r)


## Que intro toca (ver src/core/intro_story.gd): "primera" | "resumen" | "copia" | "verdadero".
func intro_kind() -> String:
	if intro_vistas <= 0:
		return "primera"
	if final_verdadero and pending_regions().is_empty():
		return "verdadero"
	if copia_restaurada and not algoritmo_vencido:
		return "copia"
	return "resumen"


## La intro completa se mostro: la proxima vez cuenta el resumen (y la historia de la copia, una sola vez).
func mark_intro_seen() -> void:
	intro_vistas += 1
	if intro_kind() == "copia":
		copia_intro_vista = true
	save_meta_progression()


## Reinos tomados, en el orden del mundo.
func taken_regions() -> Array:
	return world_order().filter(func(r): return taken.has(r))


## Ruta de rescate (fija, sin sellos): tramos en paz por reinos ya liberados y luego los pendientes
## (hasta RESCUE_MAX_TARGETS). Si new_hero, el heroe empieza en SU reino de inicio (en paz si ya
## esta liberado; si esta pendiente, es el primer objetivo); si no, "se va caminando" y cruza en
## paz los PEACE_MAX_STOPS reinos liberados que preceden al primer objetivo en el orden del mundo.
## Cada tramo en paz es UN piso de una sala (sin enemigos, ni monedas ni cofres): ver _peace_floor.
func begin_rescue(hero: String, new_hero: bool) -> void:
	var pending := pending_regions()
	if pending.is_empty():
		begin_route(hero)
		return
	var start := start_region(hero)
	var targets: Array = []
	if new_hero and start in pending:
		targets.append(start)
	for r in pending:
		if targets.size() >= RESCUE_MAX_TARGETS:
			break
		if r not in targets:
			targets.append(r)
	var stops: Array = []
	if new_hero and start in liberated:
		stops.append(start)
	var order := world_order()
	var before: Array = order.slice(0, order.find(targets[0])).filter(func(r): return r in liberated and r not in stops)
	stops.append_array(before.slice(maxi(before.size() - (PEACE_MAX_STOPS - stops.size()), 0)))
	route_dynamic = false
	rescue_mode = true
	peace_regions = stops.duplicate()
	route_regions = []
	route_floors = []
	seal_regions = []
	for s in stops:
		route_regions.append(s)
		route_floors.append(_peace_floor(s))
	for t in targets:
		_add_region_floors(t)

## Copia del 1er piso del reino para recorrerlo en paz: sin jefe y con UNA sala (la de inicio,
## que main.gd viste de plaza con carteles y portal).
static func _peace_floor(region: String) -> Dictionary:
	var f: Dictionary = FLOORS[FLOORS.find_custom(func(x): return x.region == region)].duplicate(true)
	f["peace"] = true
	f["boss"] = ""
	f["room_count"] = [1, 1]
	return f

## El piso n es un tramo en paz de la run de rescate.
static func floor_is_peace(floor_n: int) -> bool:
	return bool(_floor_at(floor_n).get("peace", false))

## GANCHO (sin implementar): reino en el que se transforma `region` al liberarlo ("" = ninguno).
## Silencio lo usara para volverse un reino de igualdad; ver "liberated_variant" arriba.
static func liberated_variant(region: String) -> String:
	for f in FLOORS:
		if f.region == region:
			return str(f.get("liberated_variant", ""))
	return ""

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
## Mapa real de cada piso ya dejado en esta partida ("<reino>:<etapa>" -> foto de MapMetroid.snapshot):
## el mapa del mundo dibuja TUS salas en los pisos recorridos, y silueta en los que no pisaste.
var floor_maps: Dictionary = {}
var lore_unlocked: Array[String] = []
var meta_currency: int = 0
var unlocked_perks: Array[String] = []
var run_active: bool = false
var run_start_time: float = 0.0  # marca de la partida (otros sistemas la usan para saber si cambio)
## Segundos jugados de la partida actual: sin el tiempo en pausa (menu, bendiciones), que
## antes contaba para el record de la partida del dia y la cifra del game over.
var run_played_time: float = 0.0


func _process(delta: float) -> void:
	if run_active:
		run_played_time += delta  # el autoload se detiene con el arbol pausado
var last_run_victory: bool = false

signal room_cleared_signal
signal floor_advanced(floor: int)
signal seal_gained(n: int)

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
	desorden_notice = bool(data.get("desorden_notice", false)) and not pending_regions().is_empty()
	var tk = data.get("taken", {})
	taken = {}
	if tk is Dictionary:
		for r in tk:
			if tk[r] is Dictionary and str(r) in regions() and str(r) not in liberated:
				taken[str(r)] = tk[r]
	algoritmo_vencido = bool(data.get("algoritmo_vencido", false))
	copia_restaurada = bool(data.get("copia_restaurada", false))
	copia_intro_vista = bool(data.get("copia_intro_vista", false))
	final_verdadero = bool(data.get("final_verdadero", false))
	derrotas_seguidas = int(data.get("derrotas_seguidas", 0))
	var hr = data.get("heroe_resto", {})
	heroe_resto = hr if hr is Dictionary else {}
	best_floor = int(data.get("best_floor", 0))
	if int(data.get("save_version", 1)) < 2 and best_floor > 0:
		best_floor = best_floor * 2 - 1  # antes 5 pisos (1 por reino); ahora 2 por reino
	total_runs = int(data.get("total_runs", 0))
	intro_vistas = maxi(int(data.get("intro_vistas", 0)), 1 if total_runs > 0 else 0)  # guardado viejo: ya la viste
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

## Semilla fija para pruebas (la pone el bot tools/autoplay con --seed=N); 0 = al azar.
static var test_seed := 0


func start_new_run(seed: int = 0) -> void:
	if seed == 0:
		seed = test_seed if test_seed != 0 else Time.get_ticks_msec()
	current_seed = seed
	RNG.randomize(seed)
	floor_maps.clear()
	# Partida del dia (pedida desde el menu): misma semilla para todos, con la Censura elegida en el menu.
	daily_mode = daily_requested
	daily_requested = false
	Censura.level = clampi(censura_selected, 0, censura_unlocked)
	Censura.clear_curses()  # las maldiciones de pactos mayores no pasan de una partida a otra
	last_censura_unlocked = 0
	
	var go_rescue := rescue_requested and not pending_regions().is_empty()
	rescue_requested = false
	if go_rescue:
		begin_rescue(character, rescue_new_hero)  # post-juego: tramos en paz + reinos pendientes
	else:
		begin_route(character, seed)  # el orden de los reinos depende del heroe (y la semilla)
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
	run_played_time = 0.0
	
	get_node("/root/GlobalEvents").player_stats_reset_requested.emit()
	get_node("/root/GlobalEvents").run_started.emit(seed)
	print("Run started: seed=%d" % seed)

func end_run(victory: bool = false) -> void:
	if not run_active:
		return  # ya terminada: no cobrar huesos dos veces
	run_active = false
	last_run_victory = victory
	var run_time = run_played_time
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
	derrotas_seguidas = 0 if victory else derrotas_seguidas + 1
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
	items_collected.append({"id": item_id, "floor": current_floor, "time": run_played_time})

func get_run_data() -> Dictionary:
	return {
		"seed": current_seed,
		"floor": current_floor,
		"room_index": current_room_index,
		"enemies_killed": total_enemies_killed,
		"damage_dealt": total_damage_dealt,
		"damage_taken": total_damage_taken,
		"time": run_played_time if run_active else last_run_time
	}

func save_meta_progression() -> void:
	var data = {
		"meta_currency": meta_currency,
		"meta_upgrades": meta_upgrades,
		"unlocked_perks": unlocked_perks,
		"total_runs": total_runs,
		"best_floor": best_floor,
		"liberated": liberated,
		"desorden_notice": desorden_notice,
		"taken": taken,
		"algoritmo_vencido": algoritmo_vencido,
		"copia_restaurada": copia_restaurada,
		"copia_intro_vista": copia_intro_vista,
		"final_verdadero": final_verdadero,
		"intro_vistas": intro_vistas,
		"derrotas_seguidas": derrotas_seguidas,
		"heroe_resto": heroe_resto,
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