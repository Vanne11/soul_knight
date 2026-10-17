class_name RoomDressing
extends RefCounted

## Vestido de las salas (roadmap tanda 2, puntos 20/26-30): zocalo, esquinas, columnas,
## variantes decorativas en la cara del muro, marcos/umbral/escalon de puertas y la luz que
## entra por ventanas y puertas. Todo es visual: ningun nodo de aqui tiene colision, asi los
## muros y las puertas chocan EXACTAMENTE igual que antes (las baldosas siguen siendo las mismas
## celdas con el mismo poligono).
##
## Decision sobre la cara frontal (vista 3/4): la cara del muro de arriba va DENTRO de su
## baldosa (la fila y=-1 usa la baldosa "cara" del atlas en vez de la "tapa"), asi no invade el
## suelo ni tapa jugabilidad. Lo unico que sale al suelo son 8-14 px de zocalo/escalon, sin
## colision y por debajo del jugador (z_index 1) y de las puertas.
##
## Determinismo: nada de RNG autoload; un RandomNumberGenerator local sembrado con
## hash(semilla de la run, piso, grid_pos). Todo cuelga de un nodo "Dressing" por sala, que
## pinta main.gd llamando a Censor (material por sala: gris hasta liberar).
##
## Uso: RoomDressing.build_floor(rooms, floor, seed) una vez por piso, tras setup_floor
## (necesita room.is_dark).

const TILE := 64
const DIR := "res://assets/sprites/environment/walls/%s/%s.png"
const MASK_FLOOR := 1
const MASK_WALL := 2
const ZOC_TOP := 12.0
const ZOC_SIDE := 8.0
const FACE_VISIBLE := 44.0  # lo que la camara ve de la cara (el resto queda bajo el HUD)
const WARM := Color(1.0, 0.86, 0.6)

static var _cache: Dictionary = {}


static func build_floor(rooms: Dictionary, floor_n: int, seed_: int) -> void:
	var floors: Array = RunManager.FLOORS
	var fl: Dictionary = floors[clampi(floor_n - 1, 0, floors.size() - 1)]
	for pos in rooms:
		var room: Room = rooms[pos]
		if room.get_node_or_null("Dressing") == null:
			_dress(room, rooms, fl, floor_n, seed_)


static func _tex(kingdom: String, name: String) -> Texture2D:
	var path := DIR % [kingdom, name]
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func _rng(seed_: int, floor_n: int, room: Room, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_, floor_n, room.grid_pos.x, room.grid_pos.y, salt])
	return r


## Sprite suelto (esquina superior izquierda en pos). Hereda el material de censura del grupo.
static func _spr(parent: Node, tex: Texture2D, pos: Vector2, mask: int, flip_h := false, flip_v := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.light_mask = mask
	s.flip_h = flip_h
	s.flip_v = flip_v
	s.use_parent_material = true
	parent.add_child(s)
	return s


## Tira de textura de largo arbitrario cortando la ultima pieza (region).
static func _strip(parent: Node, tex: Texture2D, from: Vector2, length: float, vertical: bool, mask: int, flip_h := false, flip_v := false) -> void:
	var done := 0.0
	var step_len := float(tex.get_height() if vertical else tex.get_width())
	while done < length - 0.5:
		var seg := minf(step_len, length - done)
		var s := _spr(parent, tex, from + (Vector2(0, done) if vertical else Vector2(done, 0)), mask, flip_h, flip_v)
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, tex.get_width() if vertical else seg, seg if vertical else tex.get_height())
		if flip_v and vertical:
			s.region_rect.position.y = tex.get_height() - seg
		if flip_h and not vertical:
			s.region_rect.position.x = tex.get_width() - seg
		done += seg


static func _dress(room: Room, rooms: Dictionary, fl: Dictionary, floor_n: int, seed_: int) -> void:
	var k: String = fl.kingdom
	if _tex(k, "atlas") == null:
		return
	var cells := room.floor_tilemap.get_used_rect().size
	var size := Vector2(cells) * TILE
	var rng := _rng(seed_, floor_n, room, 77)
	var mat := Censor.material_for(room)

	var root := Live.new()
	root.name = "Dressing"
	root.room = room
	room.add_child(root)
	room.move_child(root, room.walls_tilemap.get_index() + 1)  # sobre los muros, bajo puertas y actores

	var under := Node2D.new()  # a ras de suelo: zocalo, umbrales, ladrillos
	under.name = "Under"
	under.material = mat
	root.add_child(under)
	var face := Node2D.new()  # sobre la pared: variantes, ventanas, columnas
	face.name = "Face"
	face.material = mat
	root.add_child(face)

	_zocalo(under, k, size)
	_corners(under, face, k, size)
	var door_xs := _doors(room, rooms, root, under, k, size, fl)
	_variants(room, root, under, face, k, size, rng, door_xs, fl)


# ------------------------------------------------------------------ zocalo y esquinas
static func _zocalo(under: Node2D, k: String, size: Vector2) -> void:
	var top := _tex(k, "zocalo_top")
	var side := _tex(k, "zocalo_side")
	var bot := _tex(k, "zocalo_bottom")
	if top:
		_strip(under, top, Vector2(0, 0), size.x, false, MASK_FLOOR)
	if side:
		_strip(under, side, Vector2(0, ZOC_TOP), size.y - ZOC_TOP - ZOC_SIDE, true, MASK_FLOOR)
		_strip(under, side, Vector2(size.x - ZOC_SIDE, ZOC_TOP), size.y - ZOC_TOP - ZOC_SIDE, true, MASK_FLOOR, true)
	if bot:
		_strip(under, bot, Vector2(0, size.y - ZOC_SIDE), size.x, false, MASK_FLOOR, false, true)
	# esquinas internas de arriba: arista de piedra pegada a la cara frontal
	var pil := _tex(k, "pilaster")
	if pil:
		var ph := float(pil.get_height())
		_spr(under, pil, Vector2(0, ZOC_TOP - ph), MASK_WALL)
		_spr(under, pil, Vector2(size.x - pil.get_width(), ZOC_TOP - ph), MASK_WALL, true)


static func _corners(_under: Node2D, face: Node2D, k: String, size: Vector2) -> void:
	var col := _tex(k, "column")
	if col == null:
		return
	var cw := float(col.get_width())
	var ch := float(col.get_height())
	for c: Vector2 in [Vector2(-0.5, -0.5), Vector2(size.x / TILE + 0.5, -0.5), Vector2(-0.5, size.y / TILE + 0.5), Vector2(size.x / TILE + 0.5, size.y / TILE + 0.5)]:
		var base := c * TILE + Vector2(0, TILE * 0.5 + 4.0)  # pie de la columna: borde inferior de la celda
		_spr(face, col, base - Vector2(cw * 0.5, ch), MASK_WALL)


# ------------------------------------------------------------------ puertas
## Marco, umbral, escalon y luz. Devuelve las x de las puertas del muro de arriba (para no tapar).
static func _doors(room: Room, rooms: Dictionary, root: Live, under: Node2D, k: String, size: Vector2, fl: Dictionary) -> Array[float]:
	var xs: Array[float] = []
	var frame := _tex(k, "frame")
	var stp := _tex(k, "step")
	var mat := Censor.material_for(room)
	for door: Door in room.doors.values():
		var d: int = door.direction
		var out := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT][d] as Vector2
		var rot := [0.0, PI, -PI / 2.0, PI / 2.0][d] as float
		if d == 0:
			xs.append(door.position.x)
		# El sprite de la puerta se centra en la celda de muro (antes quedaba 32 px corrido en
		# las puertas laterales y la de abajo se pintaba sobre el suelo).
		door.sprite.offset = out * 32.0
		door.sprite.material = mat
		if frame:
			var f := Sprite2D.new()
			f.name = "Frame"
			f.texture = frame
			f.position = out * 32.0
			f.rotation = rot
			f.light_mask = MASK_WALL
			f.material = mat
			door.add_child(f)
			door.move_child(f, door.sprite.get_index() + 1)
		if stp:
			var s := Sprite2D.new()
			s.texture = stp
			s.position = door.position - out * (stp.get_height() * 0.5)
			s.rotation = rot
			s.light_mask = MASK_FLOOR
			s.use_parent_material = true
			under.add_child(s)
		# Luz de la sala vecina: solo si esta es oscura y la otra no.
		var other: Room = rooms.get(door.target_pos)
		if room.is_dark and other != null and not other.is_dark:
			var inward := -out
			var l := LightKit.make_light(WARM, 0.32, 1.4, false)
			l.position = door.position + inward * 22.0
			root.add_child(l)
			root.track(l, "color", WARM)
			var beam := _beam(Vector2(26, 0), Vector2(70, 150), 0.34)
			beam.position = door.position
			beam.rotation = rot
			root.add_child(beam)
			root.track(beam, "modulate", WARM)
	return xs


## Haz de luz sobre el suelo (trapecio aditivo con degradado). Solo se ve en sala oscura.
static func _beam(half_near: Vector2, half_far: Vector2, alpha: float) -> Polygon2D:
	var p := Polygon2D.new()
	# abanico de 3 vertices cerca (centro mas intenso) y 3 lejos (se pierde)
	p.polygon = PackedVector2Array([
		Vector2(-half_near.x, 0), Vector2(0, 0), Vector2(half_near.x, 0),
		Vector2(half_far.x, half_far.y), Vector2(0, half_far.y * 1.1), Vector2(-half_far.x, half_far.y)])
	p.vertex_colors = PackedColorArray([
		Color(1, 1, 1, alpha * 0.35), Color(1, 1, 1, alpha), Color(1, 1, 1, alpha * 0.35),
		Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = m
	p.visible = LightKit.dark
	p.add_to_group(LightKit.GROUP_DARK)
	return p


# ------------------------------------------------------------------ variantes y ventanas
static func _variants(room: Room, root: Live, under: Node2D, face: Node2D, k: String, size: Vector2, rng: RandomNumberGenerator, door_xs: Array[float], fl: Dictionary) -> void:
	var door_pts: Array[Vector2] = []
	for door: Door in room.doors.values():
		door_pts.append(door.position)
	var w := int(size.x / TILE)
	# Huecos en los bordes entre baldosas (las antorchas van al centro de baldosa: no chocan).
	var slots: Array[int] = []
	for i in range(1, w):
		var x := float(i * TILE)
		var blocked := false
		for dx in door_xs:
			if absf(dx - x) < 78.0:
				blocked = true
		if not blocked:
			slots.append(i)
	# barajado con el RNG local
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := slots[i]
		slots[i] = slots[j]
		slots[j] = t
	var taken: Array[int] = []
	var n_deco := rng.randi_range(1, 2) + (1 if w >= 12 else 0)
	var want_window := room.is_dark or rng.randf() < 0.5
	var kinds: Array[String] = []
	if want_window:
		kinds.append("window")
	for i in n_deco:
		kinds.append(["painting", "banner", "vines"][rng.randi_range(0, 2)])
	for kind in kinds:
		var slot := -1
		for s in slots:
			var near := false
			for t in taken:
				if absi(t - s) < 2:
					near = true
			if not near:
				slot = s
				break
		if slot < 0:
			break
		taken.append(slot)
		var tex := _tex(k, kind)
		if tex == null:
			continue
		var x := float(slot * TILE)
		var y := -float(tex.get_height()) - 2.0 + 0.0
		y = -FACE_VISIBLE - 2.0 if kind != "window" else -FACE_VISIBLE - 4.0
		if kind == "painting":
			y = -float(tex.get_height()) - 4.0 + 2.0
		_spr(face, tex, Vector2(x - tex.get_width() * 0.5, y), MASK_WALL)
		if kind == "window" and room.is_dark:  # la luz solo existe en sala oscura (como las antorchas)
			_window_light(root, Vector2(x, 16.0), fl)
	# ladrillos sueltos al pie de los muros (a ras de suelo)
	var loose := _tex(k, "loose")
	if loose:
		for i in rng.randi_range(1, 3):
			var side := rng.randi_range(0, 2)
			var u := rng.randf_range(0.15, 0.85)
			var pos := Vector2(size.x * u - 15.0, 6.0)
			if side == 1:
				pos = Vector2(ZOC_SIDE, size.y * u)
			elif side == 2:
				pos = Vector2(size.x - ZOC_SIDE - 30.0, size.y * u)
			var near_door := false
			for dp in door_pts:
				if dp.distance_to(pos + Vector2(15, 7)) < 110.0:
					near_door = true
			if not near_door:
				_spr(under, loose, pos, MASK_FLOOR, side == 2 or (side == 0 and rng.randf() < 0.5))


## Luz de color que entra por la ventana: PointLight suave + haz sobre el suelo (solo sala oscura).
static func _window_light(root: Live, at: Vector2, fl: Dictionary) -> void:
	var tint: Color = fl.tint
	var col := tint.lerp(Color.WHITE, 0.25)
	var l := LightKit.make_light(col, 0.45, 1.7, false)
	l.position = at
	root.add_child(l)
	root.track(l, "color", col)
	var beam := _beam(Vector2(10, 0), Vector2(62, 170), 0.18)
	beam.position = at + Vector2(0, -2)
	root.add_child(beam)
	root.track(beam, "modulate", col)


## Nodo raiz de cada sala: ademas de agrupar, mantiene las luces de color en gris mientras la
## sala sigue censurada (la mecanica sagrada: sin color hasta liberarla).
class Live extends Node2D:
	var room: Room
	var _items: Array = []
	var _last := -1.0

	func track(node: Object, prop: String, color: Color) -> void:
		_items.append({"n": node, "p": prop, "c": color})
		_apply(Censor.amount(room))

	func _process(_dt: float) -> void:
		var a := Censor.amount(room)
		if absf(a - _last) > 0.002:
			_apply(a)

	func _apply(a: float) -> void:
		_last = a
		for it in _items:
			var c: Color = it.c
			var lum := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			var grey := Color(lum, lum, lum * 1.05) * 0.8
			var v := grey.lerp(c, a)
			v.a = 1.0
			it.n.set(it.p, v)
