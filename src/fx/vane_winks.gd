class_name VaneWinks
extends RefCounted

## Guiños pequeños a Vanessa (historia.md, seccion 7). Discretos y raros: nunca en el narrador.
##   1. Graffiti "V. estuvo aquí" en UNA sala por region (room_dressing.gd lo cuelga del muro).
##   2. Notita bajo el jefe final: "Si lees esto, ganaste. Un abrazo, Vane." (main._complete_floor).
##   3. En el Archivo Clasificado, un estante con tomos tachados y UNO sin tachar (room_decor.gd).
## Todo es decoracion o texto: nada colisiona ni cambia la partida. Arte: tools/gen_guinos_art.py.
## Textos: locale/guinos.csv. La sala elegida es determinista (semilla de la run + piso).

const ART := "res://assets/sprites/guinos/"
const NOTE := preload("res://src/fx/vane_note.gd")
const INTERACTABLE := preload("res://src/items/interactable.gd")
## Salas "normales" donde cabe un hallazgo (sin tienda, jefe, trampa, secreta ni inicio).
const SPOT_ROOMS := [Room.RoomType.COMBAT, Room.RoomType.LORE, Room.RoomType.REST, Room.RoomType.TREASURE]
## Plan B si en ninguna de las anteriores cabe: cualquiera menos tienda, jefe, secreta e inicio.
const SPOT_ROOMS_WIDE := [Room.RoomType.COMBAT, Room.RoomType.LORE, Room.RoomType.REST, Room.RoomType.TREASURE,
	Room.RoomType.TRAP, Room.RoomType.PUZZLE, Room.RoomType.INTOXICATION, Room.RoomType.MINIBOSS]

static var _cache: Dictionary = {}


static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		var path := ART + name + ".png"
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


## Salas de `rooms` aptas para un hallazgo, en orden fijo (por posicion en la cuadricula).
static func candidates(rooms: Array, wide := false) -> Array:
	var types: Array = SPOT_ROOMS_WIDE if wide else SPOT_ROOMS
	var out: Array = rooms.filter(func(r): return r is Room and r.room_type in types)
	out.sort_custom(func(a, b): return a.grid_pos.x < b.grid_pos.x or (a.grid_pos.x == b.grid_pos.x and a.grid_pos.y < b.grid_pos.y))
	return out


## Indice estable (0..n-1) segun la semilla de la run, el piso y una sal.
static func pick_index(n: int, floor_n: int, seed_: int, salt: String) -> int:
	return absi(hash([seed_, floor_n, salt])) % maxi(n, 1)


## Graffiti en el idioma actual (es/en).
static func graffiti_tex() -> Texture2D:
	return tex("graffiti_v_" + ("en" if TranslationServer.get_locale().begins_with("en") else "es"))


## Archivo Clasificado: 2.ª etapa del Palacio.
static func is_archive(floor_n: int) -> bool:
	return RunManager.floor_region(floor_n) == "palacio" and RunManager.floor_stage(floor_n) == 2


## Notita en el suelo de la sala del jefe final, en el sitio donde cayo (`fall_global`), sin tapar
## el cofre (centro, arriba), las monedas (centro, abajo) ni nada de lo que ya hay. Se lee con E
## y tambien sola al pasar. Devuelve false si no pudo ponerla.
static func drop_note(room: Room, fall_global: Vector2) -> bool:
	var t := tex("nota")
	if t == null or room.props_node == null:
		return false
	var c := room.get_center_position()
	var taken: Array = [c + Vector2(0, -40), c + Vector2(0, 40), c + Vector2(0, 150)]
	for holder in [room.pickups_node, room.props_node]:
		if holder:
			for n in holder.get_children():
				if n is Node2D:
					taken.append(n.position)
	var it := NOTE.new()
	it.position = RoomUtil.loot_spot(room, room.to_local(fall_global), taken, null, 64.0)
	it.prompt_text = _t("GUINO_NOTA_PROMPT")
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.offset = -t.get_size() * 0.5
	s.modulate = Color(1.5, 1.45, 1.3)  # sobreexpuesta: que se vea aunque la sala este en penumbra
	Censor.apply(room, s)  # gris hasta que la sala recupera el color
	it.add_child(s)
	it.used.connect(func(_p): Narrator.toast(_t("GUINO_NOTA_TITLE"), _t("GUINO_NOTA_TEXT"), "ff7ac0"))
	room.props_node.add_child.call_deferred(it)
	return true


## Interactuable del tomo sin tachar, delante del estante (`feet`: pies del estante, locales).
static func add_tomo_prompt(room: Room, feet: Vector2) -> void:
	var it := INTERACTABLE.new()
	it.position = feet + Vector2(0, 24)
	it.prompt_text = _t("GUINO_TOMO_PROMPT")
	var shape := CollisionShape2D.new()  # ancho como el estante
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(84, 44)
	it.add_child(shape)
	it.collision_layer = 0
	it.collision_mask = 1  # el jugador
	it.used.connect(func(_p): Narrator.toast(_t("GUINO_TOMO_TITLE"), _t("GUINO_TOMO_SAY"), "ff7ac0"))
	room.props_node.add_child.call_deferred(it)
