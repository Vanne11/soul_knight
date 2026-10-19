extends Node2D
class_name RoomDecor

## Decoracion junto a los muros y en las esquinas (roadmap tanda 3, puntos 35 y 38-45):
## telaranas, restos de heroes anteriores, estatuas clasicas con su hoja de parra, y por reino:
## Selva (matorrales y pelos gigantes que tapan la vista, lianas, hongos, raices, ladillas
## paseando), Penelandia (anforas, columnas jonicas rotas, escudos y cascos), Vulvania (flores,
## corazones, cortinas, jarrones), Perineo (garita, vallas, carteles) y Palacio (sellos de
## CENSURADO, barras negras, alfombras rojas, hojas de parra).
##
## Etapa 7 (doble sentido de fondo, canon de fantasia): matas de rizos de vello y matorrales con rizos
## en la Selva, flores-pliegue en Vulvania, hermas y columnas "de bellota" en Penelandia, un cartel
## de dos lomas en Perineo y estatuas pixeladas por la censura en el Palacio.
##
## Es puro adorno: NINGUN nodo de aqui tiene colision, asi que nada bloquea, daña ni frena.
## Lo unico que cambia lo que se ve de los actores son los matorrales/pelos de la Selva, que se
## dibujan por ENCIMA (z_index 2) y se vuelven semitransparentes cuando alguien (jugador,
## enemigo, bala enemiga, objeto del suelo) esta debajo, para no esconder peligros.
## Lo que se apoya en el suelo (estatuas, columnas, carteles...) pasa por TallProp: orden por Y.
##
## Trabaja en la franja de 1 baldosa junto a los muros (y en las esquinas), deja libre la entrada
## de cada puerta (y los 96 px donde aparece el jugador) y esquiva las antorchas de
## room_lighting.gd (centros de baldosa) sin tocar ventanas ni variantes de room_dressing.gd (esas
## van en la cara del muro, por encima de y=0; aqui lo de arriba cabe en 46 px de alto).
##
## Nace gris con Censor (material por sala) y se colorea al liberar la sala. Determinista:
## RandomNumberGenerator local con hash(semilla de la run, piso, posicion en la cuadricula),
## sin tocar el autoload RNG. Las animaciones (balanceo, pulso, ladillas) las mueve _process,
## asi se pausan solas cuando la sala no es la actual (main apaga el proceso de sus hijos).
## Arte: tools/gen_decor_art.py -> assets/sprites/environment/decor/

const DIR := "res://assets/sprites/environment/decor/"
const TILE := 64
const MASK_FLOOR := 1
const MASK_WALL := 2
const TOP_FEET := 46.0      # pies de lo que se apoya en el muro de arriba
const TOP_MAX_H := 46.0     # alto maximo arriba (para no pisar la cara del muro)
const EDGE := 10.0          # margen al muro (zocalo)
const FADE_ALPHA := 0.3
const CALM := [Room.RoomType.TREASURE, Room.RoomType.REST, Room.RoomType.LORE]
## Salas donde NO van matorrales: ahi se pelea o hay trampas/puzzles que no deben taparse.
const NO_COVER := [Room.RoomType.TRAP, Room.RoomType.PUZZLE, Room.RoomType.BOSS, Room.RoomType.MINIBOSS, Room.RoomType.SHOP]

## Catalogo por reino: [textura, peso, tipo, caster]. Tipos: prop (de pie, con sombra), flat (pegado
## al suelo, sin sombra), hang (cuelga y se balancea), float (flota y sube y baja).
const CATALOG := {
	"neutral": [
		["neutral_mushroom_a", 3.0, "prop", false], ["neutral_mushroom_b", 3.0, "prop", false],
		["neutral_root", 3.0, "flat", false], ["neutral_liana_a", 2.0, "hang", false],
		["neutral_liana_b", 2.0, "hang", false], ["statue_neutral_m", 0.7, "prop", true],
		["statue_neutral_f", 0.7, "prop", true],
	],
	"pene": [
		["pene_amphora_a", 4.0, "prop", true], ["pene_amphora_b", 2.0, "prop", false],
		["pene_amphora_fallen", 2.0, "flat", false], ["pene_column_broken", 3.0, "prop", true],
		["pene_column_fallen", 2.0, "flat", false], ["pene_shield", 2.5, "prop", false],
		["pene_helmet", 2.5, "prop", false], ["statue_pene_m", 1.4, "prop", true],
		["statue_pene_f", 1.4, "prop", true],
		["pene_herma", 1.6, "prop", true], ["pene_column_glans", 1.8, "prop", true],
	],
	"vulva": [
		["vulva_flowers_pot", 3.0, "prop", false], ["vulva_flowers_bed", 3.0, "flat", false],
		["vulva_heart_topiary", 2.0, "prop", false], ["vulva_heart_float", 2.0, "float", false],
		["vulva_curtain", 2.5, "prop", false], ["vulva_vase_a", 3.0, "prop", false],
		["vulva_vase_b", 3.0, "prop", false], ["statue_vulva_m", 1.0, "prop", true],
		["statue_vulva_f", 1.0, "prop", true],
		["vulva_orchid_pot", 2.5, "prop", false], ["vulva_orchid_bed", 2.5, "flat", false],
	],
	"mixto": [
		["mixto_booth", 2.0, "prop", true], ["mixto_fence", 3.0, "prop", false],
		["mixto_cone", 3.0, "prop", false], ["mixto_sign_stop", 2.0, "prop", true],
		["mixto_sign_no", 3.0, "prop", false], ["mixto_sign_icon", 2.0, "prop", true],
		["statue_mixto_m", 0.6, "prop", true], ["statue_mixto_f", 0.6, "prop", true],
		["mixto_sign_hills", 2.0, "prop", true],
	],
	"censura": [
		["censura_stamp", 3.0, "flat", false], ["censura_bar_a", 2.5, "flat", false],
		["censura_bar_b", 2.5, "flat", false], ["censura_carpet_flat", 2.0, "flat", false],
		["censura_carpet_roll", 2.0, "prop", false], ["censura_leaf_plant", 3.0, "prop", false],
		["censura_leaf_pile", 2.0, "flat", false], ["statue_censura_m", 1.2, "prop", true],
		["statue_censura_f", 1.2, "prop", true], ["statue_censura_mosaic_m", 1.0, "prop", true],
		["statue_censura_mosaic_f", 1.0, "prop", true],
	],
	"orgullo": [
		["orgullo_banderin", 3.0, "hang", false], ["orgullo_guirnalda", 2.5, "hang", false],
		["orgullo_maceta", 3.0, "prop", false], ["orgullo_farol", 2.5, "prop", true],
		["orgullo_mural", 2.0, "prop", true], ["orgullo_carro", 1.5, "prop", true],
		["orgullo_sombrilla", 2.0, "flat", false], ["orgullo_tambor", 2.0, "prop", false],
		["orgullo_regalos", 2.0, "prop", false],
	],
	"prostata": [
		["prostata_chairs", 4.0, "prop", false], ["prostata_magazines", 3.0, "prop", false],
		["prostata_dispenser", 2.5, "prop", true], ["prostata_poster", 3.0, "prop", false],
		["prostata_plant", 3.0, "prop", false], ["prostata_cooler", 2.0, "prop", true],
	],
}
## Restos de heroes anteriores (todos los reinos). El sentado va de espaldas al muro de arriba.
const HEROES := ["hero_0", "hero_1", "hero_2", "hero_3"]

static var _cache: Dictionary = {}

var room: Room
var kingdom := "neutral"
var floor_n := 1
var run_seed := 0
var _rng := RandomNumberGenerator.new()
var _size := Vector2.ZERO
var _under: Node2D   # a ras de suelo y de pared, bajo los actores
var _over: Node2D    # matorrales: sobre los actores
var _avoid: Array[Rect2] = []  # entradas de puertas y sitio de aparicion
var _taken: Array[Rect2] = []
var _torches: Array[Vector2] = []
var _anims: Array[Dictionary] = []
var _crawlers: Array[Dictionary] = []
var _covers: Array[Dictionary] = []
var _t := 0.0


## Construye (una sola vez) la decoracion de la sala. Llamar al entrar a ella.
static func build(room_: Room, kingdom_: String, run_seed: int, floor_n: int) -> RoomDecor:
	if room_.has_meta("decor"):
		return room_.get_meta("decor")
	if kingdom_ == "silencio":  # el Silencio dibuja su propia sala: nada de otros reinos
		return null
	var d := RoomDecor.new()
	d.name = "Decor"
	d.room = room_
	d.kingdom = kingdom_ if CATALOG.has(kingdom_) else "neutral"
	d.floor_n = floor_n
	d.run_seed = run_seed
	room_.set_meta("decor", d)
	d._rng.seed = hash([run_seed, floor_n, room_.grid_pos.x, room_.grid_pos.y, "decor"])
	room_.add_child(d)
	# justo sobre el vestido de muros (si existe), bajo puertas y actores
	var dress := room_.get_node_or_null("Dressing")
	room_.move_child(d, (dress.get_index() if dress else room_.walls_tilemap.get_index()) + 1)
	d._populate()
	return d


static func _tex(name: String) -> Texture2D:
	if not _cache.has(name):
		var path := DIR + name + ".png"
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


## Carteles con texto pintado: variante en el idioma actual (es, fr; el resto de idiomas usa la en).
static func _lang_name(name: String) -> String:
	if name in ["mixto_sign_no", "censura_stamp", "prostata_poster"]:
		var loc := TranslationServer.get_locale()
		return name + ("_es" if loc.begins_with("es") else ("_fr" if loc.begins_with("fr") else "_en"))
	return name


# ------------------------------------------------------------------ construccion
func _populate() -> void:
	var rect := room.floor_tilemap.get_used_rect()
	_size = Vector2(rect.size) * TILE
	if _size.x < TILE * 4 or _size.y < TILE * 4:
		return
	_under = Node2D.new()
	_under.name = "Under"
	Censor.apply(room, _under)
	add_child(_under)
	_over = Node2D.new()
	_over.name = "Over"
	_over.z_index = 2
	_over.use_parent_material = false
	Censor.apply(room, _over)
	add_child(_over)
	_collect_avoid()
	var t: int = room.room_type
	var calm := t in CALM
	var perim := (_size.x + _size.y) * 2.0 / TILE
	var n := clampi(int(round(perim / 7.5)) + _rng.randi_range(-1, 1), 2, 7)
	if calm:
		n += 2
	if t == Room.RoomType.BOSS or t == Room.RoomType.MINIBOSS:
		n = maxi(2, n - 2)
	_build_props(n, calm)
	_build_heroes(calm)
	if kingdom == "neutral":
		_build_crawlers()
		if not (t in NO_COVER):
			_build_cover()
	_build_webs(calm)
	_build_vane_tomo()


func _collect_avoid() -> void:
	for door in room.doors.values():
		_avoid.append(Rect2(door.position - Vector2(95, 95), Vector2(190, 190)))
	# antorchas de room_lighting.gd: centros de baldosa de los 4 muros, sin esquinas
	var w := int(_size.x / TILE)
	var h := int(_size.y / TILE)
	for x in range(1, w - 1):
		_torches.append(Vector2((x + 0.5) * TILE, 6.0))
		_torches.append(Vector2((x + 0.5) * TILE, _size.y - 6.0))
	for y in range(1, h - 1):
		_torches.append(Vector2(6.0, (y + 0.5) * TILE))
		_torches.append(Vector2(_size.x - 6.0, (y + 0.5) * TILE))


# ------------------------------------------------------------------ guiño a Vanessa (VaneWinks)
## Archivo Clasificado: en UNA sala hay un estante de tomos tachados con barra negra... y uno
## que no lo esta ("Manual de Educación Sexual, 2.ª ed. (V.)"). Se hojea con E. Contra el muro de arriba.
func _build_vane_tomo() -> void:
	if not VaneWinks.is_archive(floor_n) or room.get_parent() == null:
		return
	var list := VaneWinks.candidates(room.get_parent().get_children())
	if list.is_empty() or list[VaneWinks.pick_index(list.size(), floor_n, run_seed, "tomo")] != room:
		return
	var tex := VaneWinks.tex("estante_archivo")
	if tex == null:
		return
	# el estante (64 px) es mas ancho que el hueco entre antorchas: se apoya en un borde de baldosa
	# (las antorchas cuelgan en los centros) y solo evita puertas, otros adornos y suelo no pisable
	var spot := {}
	var cols: Array[int] = []
	for i in range(1, int(_size.x / TILE)):
		cols.append(i)
	for i in range(cols.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var t := cols[i]
		cols[i] = cols[j]
		cols[j] = t
	for c in cols:
		var r := Rect2(c * TILE - tex.get_width() * 0.5, TOP_FEET - tex.get_height(), tex.get_width(), tex.get_height())
		if _free_wall(r, true):
			spot = {"rect": r, "feet": Vector2(c * TILE, TOP_FEET), "wall": 0}
			break
	if spot.is_empty():
		return
	_taken.append(spot.rect)
	_add_item(tex, spot, "prop", false)
	VaneWinks.add_tomo_prompt(room, spot.feet)


# ------------------------------------------------------------------ colocacion
func _free_wall(r: Rect2, ignore_torches := false) -> bool:
	if not Rect2(Vector2.ZERO, _size).encloses(r):
		return false
	# los pies tienen que caer en suelo pisable (forma de sala: recortes, huecos)
	if not room.rect_walkable(Rect2(r.position.x, r.end.y - 16.0, r.size.x, 16.0)):
		return false
	for a in _avoid:
		if a.intersects(r):
			return false
	for o in _taken:
		if o.grow(3.0).intersects(r):
			return false
	if ignore_torches:
		return true
	var g := r.grow(10.0)
	for p in _torches:
		if g.has_point(p):
			return false
	return true


## Busca sitio junto a un muro. Devuelve {rect, feet, wall} o {} si no cabe.
func _find_spot(tex: Texture2D, lift := 0.0, only_top := false) -> Dictionary:
	var w := float(tex.get_width())
	var h := float(tex.get_height()) + lift
	for _i in 18:
		var walls: Array[int] = []
		if h <= TOP_MAX_H:
			walls.append(0)
			walls.append(0)
		if not only_top:
			walls.append(1)
			walls.append(1)
			walls.append(2)
			walls.append(3)
		if walls.is_empty():
			return {}
		var wall: int = walls[_rng.randi_range(0, walls.size() - 1)]
		var r := Rect2()
		var feet := Vector2.ZERO
		match wall:
			0, 1:
				var t := _rng.randf_range(w * 0.5 + 8.0, _size.x - w * 0.5 - 8.0)
				var fy := TOP_FEET if wall == 0 else _size.y - EDGE
				r = Rect2(t - w * 0.5, fy - h, w, h)
				feet = Vector2(t, fy)
			_:
				var t2 := _rng.randf_range(h * 0.5 + 8.0, _size.y - h * 0.5 - 8.0)
				var x0 := EDGE if wall == 2 else _size.x - EDGE - w
				r = Rect2(x0, t2 - h * 0.5, w, h)
				feet = Vector2(x0 + w * 0.5, t2 + h * 0.5)
		if _free_wall(r):
			return {"rect": r, "feet": feet, "wall": wall}
	return {}


func _pick_weighted(items: Array) -> Array:
	var total := 0.0
	for it in items:
		total += float(it[1])
	var roll := _rng.randf() * total
	for it in items:
		roll -= float(it[1])
		if roll <= 0.0:
			return it
	return items[items.size() - 1]


func _build_props(n: int, calm: bool) -> void:
	var items: Array = CATALOG[kingdom]
	var used: Dictionary = {}
	var statues := 0
	for _i in n:
		var it: Array = _pick_weighted(items)
		var key: String = it[0]
		var is_statue := key.begins_with("statue_")
		if used.get(key, 0) >= 2 or (is_statue and statues >= (2 if calm else 1)):
			continue
		var tex := _tex(_lang_name(key))
		if tex == null:
			continue
		var kind: String = it[2]
		var spot := _find_spot(tex, 14.0 if kind == "float" else 0.0)
		if spot.is_empty():
			continue
		_taken.append(spot.rect)
		used[key] = int(used.get(key, 0)) + 1
		if is_statue:
			statues += 1
		_add_item(tex, spot, kind, bool(it[3]), _rng.randf() < 0.5 and not is_statue and kind != "hang")


func _add_item(tex: Texture2D, spot: Dictionary, kind: String, caster: bool, flip := false) -> void:
	var w := float(tex.get_width())
	var h := float(tex.get_height())
	var holder := Node2D.new()
	holder.use_parent_material = true
	var feet: Vector2 = spot.feet
	holder.position = feet
	_under.add_child(holder)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.flip_h = flip
	s.light_mask = MASK_FLOOR
	s.use_parent_material = true
	holder.add_child(s)
	match kind:
		"hang":
			holder.position = Vector2(feet.x, (spot.rect as Rect2).position.y)
			s.position = Vector2(-w * 0.5, 0.0)
			_anims.append({"n": holder, "type": "sway", "amp": _rng.randf_range(0.03, 0.06), "sp": _rng.randf_range(0.8, 1.4), "ph": _rng.randf_range(0.0, 6.0)})
		"float":
			s.position = Vector2(-w * 0.5, -h - 14.0)
			LightKit.add_contact_shadow(holder, 5.0, 0.0)
			_anims.append({"n": s, "type": "bob", "base": s.position, "amp": 3.0, "sp": _rng.randf_range(1.2, 1.8), "ph": _rng.randf_range(0.0, 6.0)})
		"flat":
			s.position = Vector2(-w * 0.5, -h)
		_:
			s.position = Vector2(-w * 0.5, -h)
			LightKit.add_contact_shadow(holder, clampf(w * 0.42, 6.0, 22.0), 0.0)
			if caster:
				LightKit.mark_caster(holder, clampf(w * 0.3, 6.0, 14.0), 0.0)
			TallProp.attach(holder, TallProp.box_of(s))  # el heroe pasa por detras (tall_prop.gd)


# ------------------------------------------------------------------ restos de heroes
func _build_heroes(calm: bool) -> void:
	var chance := 0.85 if room.room_type == Room.RoomType.LORE else (0.55 if calm else 0.3)
	if room.room_type == Room.RoomType.BOSS or room.room_type == Room.RoomType.START:
		chance = 0.1
	if _rng.randf() >= chance:
		return
	var name: String = HEROES[_rng.randi_range(0, HEROES.size() - 1)]
	var tex := _tex(name)
	if tex == null:
		return
	var spot := _find_spot(tex, 0.0, name == "hero_1")  # el sentado, de espaldas al muro de arriba
	if spot.is_empty():
		return
	_taken.append(spot.rect)
	_add_item(tex, spot, "prop", false, _rng.randf() < 0.5 and name != "hero_3")
	# unos huesos sueltos al lado (a veces)
	if _rng.randf() < 0.5:
		var b := _tex("bones_a" if _rng.randf() < 0.5 else "bones_b")
		if b:
			var bs := _find_spot(b)
			if not bs.is_empty():
				_taken.append(bs.rect)
				_add_item(b, bs, "flat", false, _rng.randf() < 0.5)


# ------------------------------------------------------------------ telaranas
func _build_webs(calm: bool) -> void:
	var tex_a := _tex("web_a")
	var tex_b := _tex("web_b")
	if tex_a == null:
		return
	# [esquina, volteo h, volteo v, probabilidad]
	var corners := [
		[Vector2(0, -6), false, false, 0.75], [Vector2(_size.x, -6), true, false, 0.75],
		[Vector2(0, _size.y), false, true, 0.35], [Vector2(_size.x, _size.y), true, true, 0.35],
	]
	var count := 0
	for c in corners:
		var p := 0.9 if calm else float(c[3])
		if _rng.randf() > p or (count >= 2 and not calm):
			continue
		var tex: Texture2D = tex_b if (tex_b and _rng.randf() < 0.3) else tex_a
		var cell_c := Vector2i(0 if c[0].x < 1.0 else int(_size.x / TILE) - 1, 0 if not c[2] else int(_size.y / TILE) - 1)
		if not room.is_cell_walkable(cell_c):
			continue  # esquina recortada por la forma de la sala
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.flip_h = c[1]
		s.flip_v = c[2]
		s.light_mask = MASK_WALL
		s.use_parent_material = true
		var pos: Vector2 = c[0]
		s.position = pos - Vector2(tex.get_width() if c[1] else 0.0, tex.get_height() if c[2] else 0.0)
		_under.add_child(s)
		count += 1


# ------------------------------------------------------------------ ladillas por las paredes (41)
func _build_crawlers() -> void:
	var frames: Array[Texture2D] = []
	for i in 3:
		var tx := _tex("neutral_ladilla_%d" % i)
		if tx == null:
			return
		frames.append(tx)
	var n := _rng.randi_range(1, 2) + (1 if _size.x * _size.y > 700.0 * 500.0 else 0)
	for _i in n:
		var top := _rng.randf() < 0.6
		var lo := 40.0
		var hi := (_size.x if top else _size.y) - 40.0
		var a := _rng.randf_range(lo, hi - 90.0)
		var b := minf(hi, a + _rng.randf_range(90.0, 220.0))
		# se parte el tramo si cruza una puerta: elegimos solo un lado libre
		var line := -17.0 if top else (7.0 if _rng.randf() < 0.5 else _size.x - 7.0)
		var ok := true
		# el tramo recorre la fila/columna de borde: tiene que ser suelo de punta a punta
		var run := Rect2(a, 0.0, b - a, TILE) if top else Rect2(0.0 if line < _size.x * 0.5 else _size.x - TILE, a, TILE, b - a)
		if not room.rect_walkable(run):
			continue
		for dr in _avoid:
			var seg := Rect2(a, line - 6.0, b - a, 12.0) if top else Rect2(line - 6.0, a, 12.0, b - a)
			if dr.intersects(seg):
				ok = false
		if not ok:
			continue
		var s := Sprite2D.new()
		s.texture = frames[0]
		s.light_mask = MASK_WALL if top else MASK_FLOOR
		s.use_parent_material = true
		s.rotation = 0.0 if top else (PI * 0.5 if line < _size.x * 0.5 else -PI * 0.5)
		_under.add_child(s)
		_crawlers.append({"s": s, "frames": frames, "top": top, "line": line, "a": a, "b": b,
			"p": _rng.randf_range(a, b), "dir": 1.0 if _rng.randf() < 0.5 else -1.0,
			"speed": _rng.randf_range(14.0, 24.0), "pause": 0.0, "ph": _rng.randf_range(0.0, 3.0)})
		_place_crawler(_crawlers[_crawlers.size() - 1])


func _place_crawler(c: Dictionary) -> void:
	var s: Sprite2D = c.s
	s.position = Vector2(c.p, c.line) if c.top else Vector2(c.line, c.p)
	if c.top:
		s.flip_h = c.dir < 0.0
	else:
		s.flip_v = false
		s.scale.x = 1.0 if c.dir > 0.0 else -1.0


func _step_crawlers(dt: float) -> void:
	for c in _crawlers:
		if c.pause > 0.0:
			c.pause -= dt
		else:
			c.p += c.dir * c.speed * dt
			if c.p >= c.b or c.p <= c.a:
				c.p = clampf(c.p, c.a, c.b)
				c.dir = -c.dir
				c.pause = _rng.randf_range(0.6, 2.2)
		c.ph += dt
		var fi := 0
		if c.pause > 0.0:
			fi = 2 if int(c.ph * 3.0) % 3 == 0 else 0  # parada: mueve las pinzas
		else:
			fi = int(c.ph * 9.0) % 2
		(c.s as Sprite2D).texture = c.frames[fi]
		_place_crawler(c)


# ------------------------------------------------------------------ matorrales y pelos (35)
func _build_cover() -> void:
	# 4 matorrales frondosos (liso, con bayas, con flores, con rizos asomando), el matorral con pechos
	# (dos lobulos y sus pezones) y 4 matas de vello pubico gigante (pelos rizados que brotan de la piel)
	var names := ["neutral_bush_a", "neutral_bush_b", "neutral_bush_c", "neutral_bush_d", "neutral_bush_e",
		"neutral_hair_a", "neutral_hair_b", "neutral_hair_c", "neutral_hair_d"]
	var weights := [0.13, 0.13, 0.12, 0.12, 0.1, 0.1, 0.1, 0.1, 0.1]
	var n := _rng.randi_range(2, 3) + (1 if _size.x * _size.y > 700.0 * 500.0 else 0)
	var center := Rect2(_size * 0.5 - Vector2(100, 80), Vector2(200, 160))
	var placed: Array[Rect2] = []
	for _i in n:
		var roll := _rng.randf()
		var idx := 0
		for k in weights.size():
			roll -= weights[k]
			if roll <= 0.0:
				idx = k
				break
		var tex := _tex(names[idx])
		if tex == null:
			continue
		var w := float(tex.get_width())
		var h := float(tex.get_height())
		for _try in 14:
			var fx := _rng.randf_range(w * 0.5 + 80.0, _size.x - w * 0.5 - 80.0)
			var fy := _rng.randf_range(h + 40.0, _size.y - 70.0)
			var r := Rect2(fx - w * 0.5, fy - h, w, h)
			var bad := center.intersects(r) or not room.rect_walkable(Rect2(r.position.x, r.end.y - 16.0, r.size.x, 16.0))
			for a in _avoid:
				if a.intersects(r):
					bad = true
			for o in placed:
				if o.grow(24.0).intersects(r):
					bad = true
			if bad:
				continue
			placed.append(r)
			_add_cover(tex, r, Vector2(fx, fy), _rng.randf() < 0.5)
			break


func _add_cover(tex: Texture2D, r: Rect2, feet: Vector2, flip := false) -> void:
	# sombra a ras de suelo (la copa va por encima de los actores)
	var holder := Node2D.new()
	holder.position = feet
	holder.use_parent_material = true
	_under.add_child(holder)
	LightKit.add_contact_shadow(holder, r.size.x * 0.38, 0.0)
	# la copa cuelga de un nodo en los pies: el viento la inclina (skew) sin mover la base
	var sway := Node2D.new()
	sway.position = feet
	sway.use_parent_material = true
	_over.add_child(sway)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.flip_h = flip
	s.position = Vector2(-r.size.x * 0.5, -r.size.y)
	s.light_mask = MASK_FLOOR
	s.use_parent_material = true
	sway.add_child(s)
	# zona que tapa: lo mas alto de la copa; quien este ahi dentro (o rozando) la vuelve transparente
	var cover := Rect2(r.position + Vector2(4, 6), r.size - Vector2(8, 14)).grow(12.0)
	_covers.append({"s": s, "sway": sway, "rect": cover, "a": 1.0, "rustle": 0.0,
		"sp": _rng.randf_range(0.7, 1.2), "ph": _rng.randf_range(0.0, 6.0), "amp": _rng.randf_range(0.012, 0.022)})


func _step_covers(dt: float) -> void:
	if _covers.is_empty():
		return
	var pts: Array[Vector2] = []
	for g in ["player", "enemy", "enemy_attack"]:
		for node in get_tree().get_nodes_in_group(g):
			if node is Node2D and (node as Node2D).is_visible_in_tree():
				pts.append(room.to_local((node as Node2D).global_position))
	for holder in [room.pickups_node, room.props_node]:
		if holder:
			for node in holder.get_children():
				if node is Node2D:
					pts.append((node as Node2D).position)
	for c in _covers:
		var under := false
		for p in pts:
			if (c.rect as Rect2).has_point(p):
				under = true
				break
		c.a = move_toward(c.a, FADE_ALPHA if under else 1.0, dt * 4.0)
		(c.s as Sprite2D).modulate.a = c.a
		# vaiven: brisa suave siempre; si pasas por debajo se sacude un rato (y se calma solo)
		c.rustle = 1.0 if under else move_toward(c.rustle, 0.0, dt * 1.2)
		(c.sway as Node2D).skew = sin(_t * c.sp + c.ph) * c.amp + sin(_t * 11.0 + c.ph) * 0.045 * c.rustle


# ------------------------------------------------------------------ animacion
func _process(delta: float) -> void:
	_t += delta
	for a in _anims:
		var n: Node2D = a.n
		match a.type:
			"sway":
				n.rotation = sin(_t * a.sp + a.ph) * a.amp
			"bob":
				n.position = (a.base as Vector2) + Vector2(0.0, sin(_t * a.sp * 2.0 + a.ph) * a.amp)
	if not _crawlers.is_empty():
		_step_crawlers(delta)
	_step_covers(delta)
