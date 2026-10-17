extends Node2D
class_name RoomDecals

## Capa de calcomanias de suelo (roadmap tanda 2, puntos 20, 21, 22 y 25): caminos o alfombras
## entre las puertas, parches de otro material con borde de transicion, charcos que reflejan
## un poco la luz y detalle segun el tipo de sala (monedas en la tienda, pergaminos en las
## inscripciones, vasos en el antro). Es puro adorno: nada bloquea, frena ni daña.
##
## Se construye una vez por sala (RoomDecals.build) como el nodo "Decals", justo encima del
## suelo y debajo de todo lo demas. Nace gris con Censor y se colorea al liberar la sala
## (vigila la meta "rl_colored" que RoomLighting.paint deja en la sala).
## Determinista: RandomNumberGenerator local con hash de (semilla, piso, posicion en la
## cuadricula), sin tocar el autoload RNG (cambiaria la mazmorra de cada semilla).
## Arte: tools/gen_decal_art.py -> assets/sprites/environment/decals/

const DIR := "res://assets/sprites/environment/decals/"
const TILE := 64
const PATH_W := 44
const T := 32  # lado de las baldosas tileables

## Borde del camino por reino: [linea exterior oscura, linea interior de color].
const RING := {
	"neutral": [Color(0.2, 0.16, 0.1, 0.55), Color(0.35, 0.49, 0.24, 0.9)],
	"pene": [Color(0.27, 0.36, 0.52, 0.5), Color(0.75, 0.63, 0.31, 0.85)],
	"vulva": [Color(0.44, 0.23, 0.32, 0.5), Color(0.93, 0.55, 0.69, 0.85)],
	"mixto": [Color(0.19, 0.17, 0.18, 0.55), Color(0.78, 0.63, 0.24, 0.85)],
	"censura": [Color(0.2, 0.04, 0.08, 0.6), Color(0.84, 0.69, 0.31, 0.9)],
}
## Liquidos por reino (con su peso). El dudoso sale poco: es un chiste, no una plaga.
const PUDDLES := {
	"neutral": [["mud", 0.5], ["water", 0.4], ["dudoso", 0.1]],
	"pene": [["water", 0.7], ["dudoso", 0.3]],
	"vulva": [["baba", 0.6], ["water", 0.25], ["dudoso", 0.15]],
	"mixto": [["aceite", 0.5], ["water", 0.35], ["dudoso", 0.15]],
	"censura": [["tinta", 0.65], ["water", 0.35]],
}
const STAMPS := {"mixto": "stamp_mixto", "censura": "stamp_censura"}
const CALM := [Room.RoomType.TREASURE, Room.RoomType.REST, Room.RoomType.LORE]

static var _tiles: Dictionary = {}
static var _add_mat: CanvasItemMaterial
static var _glint_mat: CanvasItemMaterial

var room: Room
var kingdom := "neutral"
var _rng := RandomNumberGenerator.new()
var _size := Vector2.ZERO
var _center := Vector2.ZERO
var _avoid: Array[Rect2] = []  # zonas que no se tocan (puertas, props, centro del puzzle)
var _taken: Array[Rect2] = []  # lo ya colocado (que no se pisen entre si)
var _ground: Image
var _carpets: Array[Rect2i] = []
var _synced := false
var _colored := false


## Construye (una sola vez) las calcomanias de la sala. Llamar al entrar a ella.
static func build(room_: Room, kingdom_: String, run_seed: int, floor_n: int) -> RoomDecals:
	if room_.has_meta("decals"):
		return room_.get_meta("decals")
	var d := RoomDecals.new()
	d.name = "Decals"
	d.room = room_
	d.kingdom = kingdom_ if RING.has(kingdom_) else "neutral"
	room_.set_meta("decals", d)
	d._rng.seed = hash([run_seed, floor_n, room_.grid_pos.x, room_.grid_pos.y, "decals"])
	room_.add_child(d)
	# justo encima del suelo (la franja de sombra de los muros queda por encima)
	room_.move_child(d, room_.floor_tilemap.get_index() + 1)
	Censor.apply(room_, d)
	d._populate()
	return d


func _process(_delta: float) -> void:
	# Sigue a la censura de la sala sin depender de quien pinte: RoomLighting.paint deja
	# la meta "rl_colored". La primera vez sin animar; despues con la misma transicion.
	var c: bool = room.get_meta("rl_colored", false)
	if not _synced:
		_synced = true
		_colored = c
		Censor.set_colored(room, c, false)
	elif c != _colored:
		_colored = c
		Censor.set_colored(room, c, true)


# ------------------------------------------------------------------ arte
static func _tex(name: String) -> Texture2D:
	return load(DIR + name + ".png")


static func _tile_img(name: String) -> Image:
	if not _tiles.has(name):
		var im: Image = _tex(name).get_image()
		im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		_tiles[name] = im
	return _tiles[name]


## Imagen del tamano de la sala rellena con la baldosa (alineada al mundo de la sala).
func _tiled(name: String) -> Image:
	var tile := _tile_img(name)
	var im := Image.create(int(_size.x), int(_size.y), false, Image.FORMAT_RGBA8)
	for y in range(0, int(_size.y), T):
		for x in range(0, int(_size.x), T):
			im.blit_rect(tile, Rect2i(0, 0, T, T), Vector2i(x, y))
	return im


static func _additive(lit := true) -> CanvasItemMaterial:
	if lit:
		if _add_mat == null:
			_add_mat = CanvasItemMaterial.new()
			_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		return _add_mat
	if _glint_mat == null:
		_glint_mat = CanvasItemMaterial.new()
		_glint_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_glint_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _glint_mat


# ------------------------------------------------------------------ construccion
func _populate() -> void:
	var rect := room.floor_tilemap.get_used_rect()
	_size = Vector2(rect.size) * TILE
	if _size.x < TILE or _size.y < TILE:
		return
	_center = _size * 0.5
	_ground = Image.create(int(_size.x), int(_size.y), false, Image.FORMAT_RGBA8)
	_collect_avoid()
	var t: int = room.room_type

	# 20: parches de otro material (van abajo del todo: el camino se pinta encima)
	var n_patch := _rng.randi_range(0, 1) + (1 if _size.x * _size.y > 640.0 * 440.0 else 0)
	if t in [Room.RoomType.TRAP, Room.RoomType.SECRET]:
		n_patch = 0
	var ground_used := _build_patches(n_patch)
	# 21: alfombras y caminos entre las puertas
	if _wants_carpet(t):
		ground_used = _build_carpet() or ground_used
	if ground_used:
		_flush_ground()

	_build_puddles(t)
	_build_scatter(t)
	_build_room_type(t)


func _collect_avoid() -> void:
	# entradas de las puertas: se queda limpio para que se lean
	for door in room.doors.values():
		_avoid.append(Rect2(door.position - Vector2(76, 76), Vector2(152, 152)))
	var c := _center
	match room.room_type:
		Room.RoomType.PUZZLE:
			_avoid.append(Rect2(c - Vector2(140, 140), Vector2(280, 280)))  # placas del puzzle
		Room.RoomType.TREASURE, Room.RoomType.REST, Room.RoomType.LORE:
			_avoid.append(Rect2(c - Vector2(80, 80), Vector2(160, 160)))  # cofre, fuente, inscripcion
		Room.RoomType.SHOP:
			# los productos (mismas posiciones que main._build_shop): 3 arriba y 2 abajo
			for i in 5:
				var row := 0 if i < 3 else 1
				var col: float = (i - 1) if row == 0 else (i - 3.5)
				_avoid.append(Rect2(c + Vector2(col * 120.0 - 44.0, -40.0 + row * 110.0 - 50.0), Vector2(88, 110)))
		Room.RoomType.BOSS:
			_avoid.append(Rect2(c + Vector2(-64, 90), Vector2(128, 120)))  # escotilla del piso
	if room.room_type == Room.RoomType.BOSS or room.room_type == Room.RoomType.MINIBOSS:
		_avoid.append(Rect2(c - Vector2(150, 90), Vector2(300, 150)))  # el jefe y su corte


func _wants_carpet(t: int) -> bool:
	if room.doors.is_empty() or t == Room.RoomType.PUZZLE:
		return false
	if t == Room.RoomType.BOSS or t == Room.RoomType.SHOP or kingdom == "censura":
		return true
	if t == Room.RoomType.START:
		return _rng.randf() < 0.5
	if t in [Room.RoomType.TRAP, Room.RoomType.SECRET]:
		return false
	return _rng.randf() < 0.35


# ------------------------------------------------------------------ alfombras
## Une cada puerta con el centro: entra recto y gira (esquinas) hasta el centro.
## Una sola puerta deja un felpudo corto (un extremo).
func _build_carpet() -> bool:
	var half := PATH_W * 0.5
	var rects: Array[Rect2] = []
	var doors: Array = room.doors.values()
	var cx := snappedf(_center.x, 2.0)
	var cy := snappedf(_center.y, 2.0)
	for door in doors:
		var p: Vector2 = door.position
		var dir: int = door.direction
		var vertical := dir == 0 or dir == 1  # puertas de arriba/abajo
		if doors.size() == 1:
			var depth := (_size.y if vertical else _size.x) * (0.55 if room.room_type == Room.RoomType.BOSS else 0.42)
			if dir == 0:
				rects.append(Rect2(p.x - half, 0, PATH_W, depth))
			elif dir == 1:
				rects.append(Rect2(p.x - half, _size.y - depth, PATH_W, depth))
			elif dir == 2:
				rects.append(Rect2(0, p.y - half, depth, PATH_W))
			else:
				rects.append(Rect2(_size.x - depth, p.y - half, depth, PATH_W))
			continue
		if vertical:
			var y0 := 0.0 if dir == 0 else cy
			var y1 := cy if dir == 0 else _size.y
			rects.append(Rect2(p.x - half, y0, PATH_W, y1 - y0 + (half if dir == 0 else 0.0)))
			rects.append(Rect2(minf(p.x, cx) - half, cy - half, absf(p.x - cx) + PATH_W, PATH_W))
		else:
			var x0 := 0.0 if dir == 2 else cx
			var x1 := cx if dir == 2 else _size.x
			rects.append(Rect2(x0, p.y - half, x1 - x0 + (half if dir == 2 else 0.0), PATH_W))
			rects.append(Rect2(cx - half, minf(p.y, cy) - half, PATH_W, absf(p.y - cy) + PATH_W))
	var pattern := _tiled("rug_" + kingdom)
	var ring: Array = RING[kingdom]
	var bounds := Rect2i(Vector2i.ZERO, Vector2i(_size))
	var ints: Array[Rect2i] = []
	for r in rects:
		var ri := Rect2i(Vector2i(r.position.round()), Vector2i(r.size.round())).intersection(bounds)
		if ri.size.x > 0 and ri.size.y > 0:
			ints.append(ri)
	# capas: primero toda la linea exterior, luego la interior y al final el dibujo; asi
	# las esquinas y cruces se funden y no quedan lineas atravesadas
	for ri in ints:
		_ground.fill_rect(ri.grow(3).intersection(bounds), ring[0])
	for ri in ints:
		_ground.fill_rect(ri.grow(2).intersection(bounds), ring[1])
	for ri in ints:
		_ground.blit_rect(pattern, ri, ri.position)
		_carpets.append(ri.grow(14))
	return not ints.is_empty()


# ------------------------------------------------------------------ parches
func _build_patches(n: int) -> bool:
	var made := false
	for i in n:
		var rx := _rng.randf_range(38.0, 74.0)
		var ry := _rng.randf_range(28.0, 50.0)
		var pos = _pick(rx * 0.8, rx * 0.8 + 28.0, false)
		if pos == null:
			continue
		var name := "patch_%s_%s" % [kingdom, "a" if _rng.randf() < 0.5 else "b"]
		_blob(pos, rx, ry, name)
		made = true
	return made


## Parche irregular: dibujo de otra baldosa, linea oscura pegada al borde y un
## difuminado de puntos por fuera (borde de transicion con el suelo de la sala).
func _blob(center: Vector2, rx: float, ry: float, tile_name: String) -> void:
	var tile := _tile_img(tile_name)
	var ph := [_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU]
	var m := 6
	var box := Rect2i(Vector2i((center - Vector2(rx, ry)).floor()) - Vector2i(m, m), Vector2i(Vector2(rx, ry) * 2.0) + Vector2i(m, m) * 2)
	box = box.intersection(Rect2i(Vector2i.ZERO, Vector2i(_size)))
	var avg := Color(0, 0, 0, 0)
	for y in range(0, T, 4):
		for x in range(0, T, 4):
			avg += tile.get_pixel(x, y) / 64.0
	var edge := Color(avg.r * 0.55, avg.g * 0.55, avg.b * 0.58, 0.8)
	var img := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	var rmin := minf(rx, ry)
	for y in box.size.y:
		for x in box.size.x:
			var wx := box.position.x + x
			var wy := box.position.y + y
			var u := (wx + 0.5 - center.x) / rx
			var v := (wy + 0.5 - center.y) / ry
			var a := atan2(v, u)
			var f := 0.84 + 0.13 * sin(3.0 * a + ph[0]) + 0.08 * sin(5.0 * a + ph[1]) + 0.05 * sin(8.0 * a + ph[2])
			var s := (f - sqrt(u * u + v * v)) * rmin  # distancia (px) al borde, + dentro
			if s >= 1.5:
				img.set_pixel(x, y, tile.get_pixel(wx % T, wy % T))
			elif s >= 0.0:
				img.set_pixel(x, y, edge)
			elif s > -3.0 and (wx + wy) % 2 == 0 and (s > -1.5 or (wx / 2 + wy / 2) % 2 == 0):
				img.set_pixel(x, y, Color(avg.r, avg.g, avg.b, 0.55 if s > -1.5 else 0.35))
	_ground.blend_rect(img, Rect2i(Vector2i.ZERO, box.size), box.position)


func _flush_ground() -> void:
	var s := Sprite2D.new()
	s.name = "Ground"
	s.centered = false
	s.texture = ImageTexture.create_from_image(_ground)
	s.use_parent_material = true
	add_child(s)


# ------------------------------------------------------------------ colocacion
func _pick(r: float, margin: float, check_taken := true) -> Variant:
	for i in 16:
		var p := Vector2(_rng.randf_range(margin, _size.x - margin), _rng.randf_range(margin, _size.y - margin))
		if _is_free(p, r, check_taken):
			return p
	return null


func _is_free(p: Vector2, r: float, check_taken := true, on_carpet := false) -> bool:
	var box := Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0)
	for a in _avoid:
		if a.intersects(box):
			return false
	if check_taken:
		for a in _taken:
			if a.intersects(box):
				return false
		if not on_carpet:
			for c in _carpets:
				if Rect2(c).intersects(box):
					return false
	return true


func _put(tex_name: String, p: Vector2, r: float, flip := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(tex_name)
	s.position = p.round()
	s.use_parent_material = true
	if flip and _rng.randf() < 0.5:
		s.flip_h = true
	add_child(s)
	_taken.append(Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0))
	return s


func _weighted(list: Array) -> Variant:
	var tot := 0.0
	for e in list:
		tot += e[1]
	var x := _rng.randf() * tot
	for e in list:
		x -= e[1]
		if x <= 0.0:
			return e[0]
	return list[0][0]


# ------------------------------------------------------------------ charcos (22)
func _build_puddles(t: int) -> void:
	var n := _rng.randi_range(0, 2) + (1 if _size.x * _size.y > 640.0 * 440.0 else 0)
	if t == Room.RoomType.REST:
		n = 2
	elif t == Room.RoomType.PUZZLE or t == Room.RoomType.START:
		n = mini(n, 1)
	for i in n:
		var kind: String = "water" if t == Room.RoomType.REST else _weighted(PUDDLES[kingdom])
		_puddle(kind)


func _puddle(kind: String, at: Variant = null, size_: String = "") -> void:
	var sz: String = size_ if size_ != "" else ["s", "m", "m", "l"][_rng.randi_range(0, 3)]
	if kind == "dudoso" and _rng.randf() < 0.5:
		sz = "l"  # el interrogante solo se lee en el grande
	var murky := kind in ["tinta", "mud", "aceite"]
	if murky and sz == "l":
		sz = "m"  # un charco oscuro grande se lee como un hoyo (y los hoyos son jugabilidad)
	var base := _tex("puddle_%s_%s" % [kind, sz])
	var r := maxf(base.get_width(), base.get_height()) * 0.5
	var pos = at if at != null else _pick(r + 6.0, r + 50.0)
	if pos == null:
		return
	var flip := _rng.randf() < 0.5
	var s := _put("puddle_%s_%s" % [kind, sz], pos, r + 6.0, false)
	s.flip_h = flip
	if murky:
		s.modulate.a = 0.45  # que se vea el suelo a traves: mancha, no agujero
	# dos cuadros de brillo que se alternan despacio (aditivos, se apagan con la sala oscura)
	var shines: Array[Sprite2D] = []
	for v in ["a", "b"]:
		var sh := Sprite2D.new()
		sh.texture = _tex("puddle_%s_%s_%s" % [kind, sz, v])
		sh.position = s.position
		sh.flip_h = flip
		sh.material = _additive(true)
		sh.modulate.a = 0.0
		add_child(sh)
		shines.append(sh)
	var lit_a := 0.42
	var tw := create_tween().set_loops()
	tw.tween_interval(_rng.randf() * 2.0)
	tw.tween_property(shines[0], "modulate:a", lit_a, 1.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(shines[1], "modulate:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(shines[0], "modulate:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(shines[1], "modulate:a", lit_a, 1.4).set_trans(Tween.TRANS_SINE)
	# en sala oscura recoge la luz de las antorchas: destello extra que solo existe a oscuras
	var glint := Sprite2D.new()
	glint.texture = shines[0].texture
	glint.position = s.position
	glint.flip_h = flip
	glint.material = _additive(false)
	glint.modulate = Color(1, 1, 1, 0.55)
	glint.visible = LightKit.dark
	glint.add_to_group(LightKit.GROUP_DARK)
	add_child(glint)
	var gt := create_tween().set_loops()
	gt.tween_interval(_rng.randf() * 1.5)
	gt.tween_property(glint, "modulate:a", 0.9, 1.1).set_trans(Tween.TRANS_SINE)
	gt.tween_property(glint, "modulate:a", 0.35, 1.3).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------------ detalle del reino
func _build_scatter(t: int) -> void:
	var n := _rng.randi_range(1, 3) + (2 if _size.x * _size.y > 640.0 * 440.0 else 0)
	if t == Room.RoomType.PUZZLE:
		n = 1
	for i in n:
		var name := "scatter_%s_%d" % [kingdom, _rng.randi_range(0, 2)]
		var tex := _tex(name)
		var r := maxf(tex.get_width(), tex.get_height()) * 0.5
		var pos = _pick(r + 4.0, r + 46.0)
		if pos != null:
			_put(name, pos, r + 4.0)
	if STAMPS.has(kingdom):
		var count := 1 if t != Room.RoomType.BOSS else 2
		for i in count:
			var tex := _tex(STAMPS[kingdom])
			var r := maxf(tex.get_width(), tex.get_height()) * 0.5
			var pos = _pick(r + 6.0, r + 60.0)
			if pos != null:
				_put(STAMPS[kingdom], pos, r + 6.0, false)


# ------------------------------------------------------------------ 25: segun el tipo de sala
func _build_room_type(t: int) -> void:
	match t:
		Room.RoomType.SHOP:
			# monedas aplastadas en el suelo: se ven hundidas y apagadas, no como las de recoger
			for i in _rng.randi_range(5, 9):
				_scatter_near("coin_%d" % _rng.randi_range(0, 3), 11.0, 120.0, 330.0)
		Room.RoomType.LORE:
			for i in _rng.randi_range(4, 6):
				_scatter_near("scroll_%d" % _rng.randi_range(0, 4), 16.0, 100.0, 300.0)
		Room.RoomType.INTOXICATION:
			for i in _rng.randi_range(8, 12):
				_scatter_near("glass_%d" % _weighted([[0, 2], [1, 2], [2, 2], [3, 2], [4, 3], [5, 1]]), 14.0, 40.0, 400.0)
			for i in _rng.randi_range(1, 2):
				_puddle("whiskey")


## Un detalle suelto a una distancia (min..max) del centro de la sala, sin pisar nada.
func _scatter_near(name: String, r: float, dmin: float, dmax: float) -> void:
	for i in 12:
		var p := _center + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(dmin, dmax) * Vector2(1.25, 0.85)
		if p.x < 70.0 or p.y < 70.0 or p.x > _size.x - 70.0 or p.y > _size.y - 70.0:
			continue
		if _is_free(p, r, true, true):  # monedas, papeles y vidrios tambien caen sobre la alfombra
			_put(name, p, r)
			return
