class_name RoomObstacles
extends Node2D

## Obstaculos de sala (roadmap tanda 3, puntos 31, 33, 34 y 37).
##
##  31  rocas y escombros: bloquean el paso y cubren de las balas (las del jugador y las de
##      los enemigos).
##  33  columnas de cobertura, solo en salas grandes.
##  34  barriles y cajas que se rompen a balazos y, a veces (COIN_CHANCE), sueltan una moneda
##      con el mismo pickup "coin" de siempre. Poco: no toca la economia.
##  37  salas trampa: pinchos visibles con huesos. Es SOLO decoracion (hoy las salas trampa
##      son combates sin mecanica propia): no hacen dano, estan lejos de los caminos.
##
## Fisica: StaticBody2D en la capa 1 (la de los muros). Asi, sin tocar nada mas, frenan al
## jugador y a los enemigos (mascara 3), paran las balas del jugador (mascara 3) y las de los
## enemigos (mascara 1) y tapan los rayos de luz de los casters de RoomLighting (mascara 1).
## NO usa la capa 32 (objetos con fisica de RoomLighting) ni la 3/4 (interaccion).
##
## Colocacion: patrones simetricos (4, 2 en diagonal o 2 en fila) o grupos pequenos, siempre
## dentro del interior (queda libre 1 baldosa junto a los muros para la decoracion de pared),
## sin tapar el camino puerta-centro de las alfombras, ni el punto donde aparece el jugador
## (96 px dentro de cada puerta), ni el centro (recompensas), ni los spawn points de enemigos.
## Despues de colocar, una busqueda en grilla comprueba que todas las puertas, el centro y los
## spawns siguen conectados a pie; si no, se descarta el patron.
##
## Enemigos: los cuerpo a cuerpo y los que disparan van en linea recta con move_and_slide, asi
## que se deslizan por los lados de un obstaculo convexo. Por eso todo son rectangulos bajos
## (la huella de los pies, no la altura del dibujo), nunca hay huecos de menos de 40 px entre
## dos obstaculos (no hay bolsillos donde se atasquen) y los grupos pegados forman una pieza
## maciza sin concavidades.
##
## Nace gris con Censor y se colorea al liberar la sala (vigila la meta "rl_colored").
## Determinista: RandomNumberGenerator local con hash(semilla, piso, grid_pos); no usa el RNG
## global. Arte: tools/gen_obstacle_art.py -> assets/sprites/environment/obstacles/

const DIR := "res://assets/sprites/environment/obstacles/%s/%s.png"
const COMMON := "res://assets/sprites/environment/obstacles/%s.png"
const TILE := 64
const STRIP := 72.0  # margen libre junto a los muros (1 baldosa + aire)
const COIN_CHANCE := 0.10  # de cada barril/caja; ~0.3 monedas por sala (un enemigo da 0.4)
const BREAK_HP := 14.0  # dos balazos normales
const CELL := 8.0
const PLAYER_R := 13.0  # el jugador mide 24x24
const GAP := 40.0  # hueco minimo entre obstaculos de grupos distintos
const SOLID_ROOMS := [Room.RoomType.COMBAT, Room.RoomType.MINIBOSS, Room.RoomType.INTOXICATION, Room.RoomType.TRAP]
const ITEM_PICKUP_SCENE := preload("res://src/items/item_pickup.tscn")

## col = huella de colision (ancho, alto), pad = pixeles del dibujo bajo los pies,
## sr = radio de la sombra, hp > 0 = rompible.
const KINDS := {
	"rock_a": {"col": Vector2(38, 20), "pad": 3, "sr": 19.0, "hp": 0.0},
	"rock_b": {"col": Vector2(24, 14), "pad": 3, "sr": 13.0, "hp": 0.0},
	"column": {"col": Vector2(24, 14), "pad": 4, "sr": 14.0, "hp": 0.0},
	"extra": {"col": Vector2(58, 14), "pad": 3, "sr": 28.0, "hp": 0.0},
	"barrel": {"col": Vector2(22, 14), "pad": 3, "sr": 12.0, "hp": BREAK_HP},
	"crate": {"col": Vector2(28, 14), "pad": 3, "sr": 15.0, "hp": BREAK_HP},
}
const KING_LIST := ["neutral", "pene", "vulva", "mixto", "censura"]
## Peso del barril frente a la caja por reino (anforas en Penelandia, cajas en el Perineo).
const BARREL_W := {"neutral": 0.5, "pene": 0.75, "vulva": 0.6, "mixto": 0.35, "censura": 0.4}

static var _tex_cache: Dictionary = {}

var room: Room
var kingdom := "neutral"
var _rng := RandomNumberGenerator.new()
var _size := Vector2.ZERO
var _center := Vector2.ZERO
var _doors: Array[Dictionary] = []  # {pos, inward}
var _keep: Array[Rect2] = []  # zonas prohibidas (spawns, entradas, centro)
var _spawns: Array[Vector2] = []
var _solid: Array[Rect2] = []  # huellas de lo que bloquea (para la grilla)
var _flat: Array[Rect2] = []  # pinchos (no bloquean)
var _props: Array[Prop] = []
var _flat_node: Node2D
var _synced := false
var _colored := false


static func build_floor(rooms: Dictionary, floor_n: int, seed_: int) -> void:
	var floors: Array = RunManager.FLOORS
	var k: String = floors[clampi(floor_n - 1, 0, floors.size() - 1)].kingdom
	for pos in rooms:
		build(rooms[pos], k, seed_, floor_n)


## Construye (una sola vez) los obstaculos de la sala. Devuelve null si la sala no los lleva.
static func build(room_: Room, kingdom_: String, seed_: int, floor_n: int) -> RoomObstacles:
	if room_.has_meta("obstacles"):
		return room_.get_meta("obstacles")
	if room_.room_type not in SOLID_ROOMS:
		return null
	var o := RoomObstacles.new()
	o.name = "Obstacles"
	o.room = room_
	o.kingdom = kingdom_ if kingdom_ in KING_LIST else "neutral"
	o._rng.seed = hash([seed_, floor_n, room_.grid_pos.x, room_.grid_pos.y, "obstacles"])
	room_.set_meta("obstacles", o)
	room_.add_child(o)
	room_.move_child(o, room_.props_node.get_index())
	o.material = Censor.material_for(room_)
	o._populate()
	room_.set_meta("obstacle_rects", o._solid)  # RoomLighting no suelta piedrecitas encima
	return o


func _process(_delta: float) -> void:
	var c: bool = room.get_meta("rl_colored", false)
	if not _synced:
		_synced = true
		_colored = c
		Censor.set_colored(room, c, false)
	elif c != _colored:
		_colored = c
		Censor.set_colored(room, c, true)
	# Profundidad: si el jugador esta detras (mas arriba) y a su lado, el obstaculo lo tapa.
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var pp := to_local(pl.global_position)
	for p in _props:
		if not is_instance_valid(p):
			continue
		var d := p.position - Vector2(pp.x, pp.y + 12.0)
		p.z_index = 2 if (d.y > 0.0 and d.y < p.sprite_h and absf(d.x) < p.sprite_w * 0.5 + 12.0) else 0


# ------------------------------------------------------------------ arte
static func _tex(k: String, name: String) -> Texture2D:
	var path := DIR % [k, name]
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


static func _common(name: String) -> Texture2D:
	var path := COMMON % name
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


# ------------------------------------------------------------------ construccion
func _populate() -> void:
	var rect := room.floor_tilemap.get_used_rect()
	_size = Vector2(rect.size) * TILE
	if _size.x < TILE * 8 or _size.y < TILE * 6 or _tex(kingdom, "rock_a") == null:
		return
	_center = _size * 0.5
	_flat_node = Node2D.new()
	_flat_node.name = "Flat"
	add_child(_flat_node)
	_collect()
	var trap: bool = room.room_type == Room.RoomType.TRAP
	var big := _size.x >= TILE * 10 and _size.y >= TILE * 7
	# solidos: casi todas las salas; en las trampa solo a veces (ahi mandan los pinchos)
	var p_solid := 0.4 if trap else (0.7 if room.room_type == Room.RoomType.MINIBOSS else 0.88)
	if _rng.randf() < p_solid:
		_place_solid(big)
	if trap:
		_place_spikes(big)
	else:
		# rompibles: no en el minijefe (pelea de gigantes: que no haya nada que estorbe)
		if room.room_type != Room.RoomType.MINIBOSS and _rng.randf() < 0.75:
			var n := 1 if _rng.randf() < 0.6 else 2
			for i in n:
				_place_breakables()


func _collect() -> void:
	for door: Door in room.doors.values():
		var inward := Vector2.DOWN
		match door.get_direction_name():
			"up": inward = Vector2.DOWN
			"down": inward = Vector2.UP
			"left": inward = Vector2.RIGHT
			"right": inward = Vector2.LEFT
		_doors.append({"pos": door.position, "inward": inward})
		# donde aparece el jugador al entrar (main._place_player_in_room): 96 px dentro
		var entry: Vector2 = door.position + inward * 96.0
		_keep.append(Rect2(entry - Vector2(75, 75), Vector2(150, 150)))
	# recompensas: donde las suelta la sala (en las de forma el centro geometrico puede ser un hueco)
	_keep.append(Rect2(room.get_center_position() - Vector2(90, 90), Vector2(180, 180)))
	# spawns de enemigos (+ el reparto de grupos: hasta 56 px a la derecha y 24 abajo)
	for sp in room.spawn_points_node.get_children():
		if sp is Node2D:
			_spawns.append((sp as Node2D).position)
			_keep.append(Rect2((sp as Node2D).position + Vector2(-34, -34), Vector2(124, 92)))


## Un pie `r` (huella) es valido si cabe en el interior, no pisa zonas prohibidas ni la franja
## puerta-centro de las alfombras. `others`: huellas con las que respetar el hueco GAP.
func _valid(r: Rect2, others: Array[Rect2], gap := GAP) -> bool:
	var inner := Rect2(STRIP, STRIP, _size.x - STRIP * 2.0, _size.y - STRIP * 2.0)
	if not inner.encloses(r):
		return false
	if not room.rect_walkable(r.grow(18.0)):
		return false  # forma de sala: ni en recortes ni en huecos ni pegado a ellos
	for k in _keep:
		if r.intersects(k):
			return false
	var fat := r.grow(36.0)
	for d in _doors:
		var a: Vector2 = d.pos + (d.inward as Vector2) * 30.0
		var n := int(a.distance_to(_center) / 12.0) + 1
		for i in n + 1:
			if fat.has_point(a.lerp(_center, float(i) / float(n))):
				return false
	var far := r.grow(gap)
	for o in others:
		if far.intersects(o):
			return false
	return true


func _foot_rect(kind: String, foot: Vector2) -> Rect2:
	var c: Vector2 = KINDS[kind].col
	return Rect2(foot - Vector2(c.x * 0.5, c.y), c)


## Camino a pie: todas las entradas de puerta, el centro y los spawns en una sola region libre.
func _connected(extra: Array[Rect2]) -> bool:
	var nx := int(ceil(_size.x / CELL))
	var ny := int(ceil(_size.y / CELL))
	var blocked := PackedByteArray()
	blocked.resize(nx * ny)
	var shaped := not room.shape_cells.is_empty()
	for y in ny:
		for x in nx:
			var p := Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)
			if p.x < 12.0 or p.y < 12.0 or p.x > _size.x - 12.0 or p.y > _size.y - 12.0:
				blocked[y * nx + x] = 1
			elif shaped and not room.is_walkable(p, 12.0):
				blocked[y * nx + x] = 1
	for list in [_solid, extra]:
		for r: Rect2 in list:
			var g := r.grow(PLAYER_R)
			for y in range(maxi(0, int(g.position.y / CELL)), mini(ny, int(g.end.y / CELL) + 1)):
				for x in range(maxi(0, int(g.position.x / CELL)), mini(nx, int(g.end.x / CELL) + 1)):
					if g.has_point(Vector2((x + 0.5) * CELL, (y + 0.5) * CELL)):
						blocked[y * nx + x] = 1
	var goals: Array[Vector2i] = []
	for d in _doors:
		goals.append(_cell(d.pos + (d.inward as Vector2) * 40.0, nx, ny))
	goals.append(_cell(room.nearest_walkable(_center, 20.0) if shaped else _center, nx, ny))
	for sp in _spawns:
		goals.append(_cell(sp, nx, ny))
	for g in goals:
		if blocked[g.y * nx + g.x] == 1:
			return false
	var seen := PackedByteArray()
	seen.resize(nx * ny)
	var stack: Array[Vector2i] = [goals[0]]
	seen[goals[0].y * nx + goals[0].x] = 1
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dv
			if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= ny:
				continue
			var i := n.y * nx + n.x
			if blocked[i] == 0 and seen[i] == 0:
				seen[i] = 1
				stack.append(n)
	for g in goals:
		if seen[g.y * nx + g.x] == 0:
			return false
	return true


func _cell(p: Vector2, nx: int, ny: int) -> Vector2i:
	return Vector2i(clampi(int(p.x / CELL), 0, nx - 1), clampi(int(p.y / CELL), 0, ny - 1))


# ------------------------------------------------------------------ solidos (31 y 33)
## Sitios simetricos respecto al centro: (+-dx, +-dy) segun el modo.
func _sites(mode: String, dx: float, dy: float) -> Array[Vector2]:
	var c := _center
	match mode:
		"diag":
			return [c + Vector2(-dx, -dy), c + Vector2(dx, dy)] if _rng.randf() < 0.5 else [c + Vector2(dx, -dy), c + Vector2(-dx, dy)]
		"fila":
			var sy := -1.0 if _rng.randf() < 0.5 else 1.0
			return [c + Vector2(-dx, sy * dy), c + Vector2(dx, sy * dy)]
		"columna":
			var sx := -1.0 if _rng.randf() < 0.5 else 1.0
			return [c + Vector2(sx * dx, -dy), c + Vector2(sx * dx, dy)]
	return [c + Vector2(-dx, -dy), c + Vector2(dx, -dy), c + Vector2(-dx, dy), c + Vector2(dx, dy)]


## Piezas de un sitio segun el tema. Cada pieza: {kind, pos (pies), flip}.
func _site_items(theme: String, site: Vector2, big: bool) -> Array[Dictionary]:
	var sx := 1.0 if site.x >= _center.x else -1.0
	var sy := 1.0 if site.y >= _center.y else -1.0
	var out: Array[Dictionary] = []
	var t := theme
	if t == "mixto":
		t = "columns" if (sy < 0.0 and big) else ("extras" if sy < 0.0 else "rocks")
	match t:
		"columns":
			out.append({"kind": "column", "pos": site, "flip": sx < 0.0})
		"extras":
			out.append({"kind": "extra", "pos": site, "flip": sx < 0.0})
		_:
			out.append({"kind": "rock_a", "pos": site, "flip": sx < 0.0})
			out.append({"kind": "rock_b", "pos": site + Vector2(sx * 30.0, -sy * 8.0), "flip": sx > 0.0})
	return out


func _place_solid(big: bool) -> void:
	var themes: Array[String] = ["rocks", "rocks", "extras", "mixto"]
	if big:
		themes.append_array(["columns", "columns", "mixto"])
	var theme: String = themes[_rng.randi_range(0, themes.size() - 1)]
	var modes: Array[String] = ["quad", "diag", "fila", "columna"]
	var first: String = modes[_rng.randi_range(0, modes.size() - 1)]
	for attempt in 12:
		# los primeros intentos con el patron sorteado; si no cabe, se prueba con menos sitios
		var mode: String = first if attempt < 4 else modes[1 + (attempt % 3)]
		var dx := snappedf(_size.x * _rng.randf_range(0.2, 0.3), 8.0)
		var dy := snappedf(_size.y * _rng.randf_range(0.18, 0.27), 8.0)
		var groups: Array = []
		for site in _sites(mode, dx, dy):
			groups.append(_site_items(theme, site, big))
		if _try_groups(groups):
			return
	# no cabe ningun patron simetrico (sala llena de spawns): uno o dos grupos sueltos
	var loose := 0
	for attempt in 30:
		var pos := Vector2(_rng.randf_range(STRIP, _size.x - STRIP), _rng.randf_range(STRIP, _size.y - STRIP))
		pos = Vector2(snappedf(pos.x, 8.0), snappedf(pos.y, 8.0))
		if _try_groups([_site_items(theme, pos, big)]):
			loose += 1
			if loose >= 2:
				return


## Todo o nada: si falla un grupo o se corta el camino, no se coloca ninguno.
func _try_groups(groups: Array) -> bool:
	var placed: Array[Rect2] = []
	for g: Array in groups:
		var mine: Array[Rect2] = []
		for it: Dictionary in g:
			mine.append(_foot_rect(it.kind, it.pos))
		var others: Array[Rect2] = _solid.duplicate()
		others.append_array(placed)
		for r in mine:
			if not _valid(r, others):
				return false
		placed.append_array(mine)
	if not _connected(placed):
		return false
	for g: Array in groups:
		for it: Dictionary in g:
			_spawn_prop(it.kind, it.pos, it.flip)
	_solid.append_array(placed)
	return true


# ------------------------------------------------------------------ rompibles (34)
func _place_breakables() -> void:
	var corners: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	var offs: Array = [
		[Vector2(0, 0), Vector2(30, 0)],
		[Vector2(0, 0), Vector2(30, 0), Vector2(15, -28)],
		[Vector2(0, 0), Vector2(30, 0), Vector2(0, -28), Vector2(30, -28)],
	]
	for attempt in 16:
		var cs: Vector2 = corners[_rng.randi_range(0, 3)]
		var ax := STRIP + _rng.randf_range(24.0, 110.0)
		var ay := STRIP + _rng.randf_range(34.0, 100.0)
		var anchor := Vector2(ax if cs.x < 0.0 else _size.x - ax, ay if cs.y < 0.0 else _size.y - ay)
		var pattern: Array = offs[_rng.randi_range(0, offs.size() - 1)]
		var items: Array[Dictionary] = []
		for o: Vector2 in pattern:
			var kind := "barrel" if _rng.randf() < float(BARREL_W[kingdom]) else "crate"
			items.append({"kind": kind, "pos": anchor + Vector2(o.x * -cs.x, o.y * -cs.y), "flip": _rng.randf() < 0.5})
		var mine: Array[Rect2] = []
		for it in items:
			mine.append(_foot_rect(it.kind, it.pos))
		var ok := true
		for r in mine:
			if not _valid(r, _solid):
				ok = false
				break
		if ok and _connected(mine):
			for it in items:
				_spawn_prop(it.kind, it.pos, it.flip)
			_solid.append_array(mine)
			return


# ------------------------------------------------------------------ pinchos (37)
func _place_spikes(big: bool) -> void:
	var n_spikes := 3 if big else 2
	var side := 16.0 * n_spikes + 12.0
	var modes: Array[String] = ["quad", "diag", "fila", "columna"]
	for attempt in 10:
		var mode: String = modes[_rng.randi_range(0, 3)] if attempt < 5 else "diag"
		var dx := snappedf(_size.x * _rng.randf_range(0.2, 0.3), 8.0)
		var dy := snappedf(_size.y * _rng.randf_range(0.2, 0.28), 8.0)
		var rects: Array[Rect2] = []
		var ok := true
		for site in _sites(mode, dx, dy):
			var r := Rect2(site - Vector2(side, side) * 0.5, Vector2(side, side))
			if not _valid(r, _solid, 24.0):
				ok = false
				break
			rects.append(r)
		if not ok:
			continue
		_put_spikes(rects, side, big)
		return
	# sin sitio simetrico: una o dos placas sueltas
	var loose: Array[Rect2] = []
	for attempt in 30:
		var c := Vector2(snappedf(_rng.randf_range(STRIP + side * 0.5, _size.x - STRIP - side * 0.5), 8.0), snappedf(_rng.randf_range(STRIP + side * 0.5, _size.y - STRIP - side * 0.5), 8.0))
		var r := Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))
		if _valid(r, _solid + loose, 24.0):
			loose.append(r)
			if loose.size() >= 2:
				break
	if not loose.is_empty():
		_put_spikes(loose, side, big)


func _put_spikes(rects: Array[Rect2], side: float, big: bool) -> void:
	for r in rects:
		_add_flat(_tex(kingdom, "spikes" if big else "spikes_s"), r.get_center(), false)
		_flat.append(r)
	# huesos de quien no tuvo cuidado
	var sk := _common("skull")
	var bn := _common("bones")
	var r0: Rect2 = rects[0]
	if bn:
		_add_flat(bn, r0.position + Vector2(side * 0.5 - 8.0, side + 12.0), _rng.randf() < 0.5)
	if sk and rects.size() > 1:
		var r1: Rect2 = rects[rects.size() - 1]
		_add_flat(sk, r1.position + Vector2(side + 10.0, side * 0.7), _rng.randf() < 0.5)


func _add_flat(tex: Texture2D, pos: Vector2, flip: bool) -> void:
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.flip_h = flip
	s.material = material
	_flat_node.add_child(s)


# ------------------------------------------------------------------ piezas
func _spawn_prop(kind: String, foot: Vector2, flip: bool) -> void:
	var info: Dictionary = KINDS[kind]
	var tex := _tex(kingdom, kind)
	if tex == null:
		return
	var p := Prop.new()
	p.position = foot
	p.kind = kind
	p.kingdom = kingdom
	p.room = room
	p.collision_layer = 1
	p.collision_mask = 0
	p.hp = float(info.hp)
	p.drops_coin = p.hp > 0.0 and _rng.randf() < COIN_CHANCE
	p.sprite_w = tex.get_width()
	p.sprite_h = tex.get_height()
	var col: Vector2 = info.col
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = col
	shape.shape = rs
	shape.position = Vector2(0, -col.y * 0.5)
	p.add_child(shape)
	p.shape_node = shape
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(-tex.get_width() * 0.5, -tex.get_height() + int(info.pad))
	s.flip_h = flip
	s.material = material
	p.add_child(s)
	p.sprite = s
	# luz y sombra: contacto, sombras proyectadas por las antorchas y oclusor (la luz no lo atraviesa)
	var sr: float = info.sr
	LightKit.add_contact_shadow(p, sr + 4.0, 2.0)
	LightKit.mark_caster(p, sr, 2.0)
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	var h := col * 0.5
	var cy := -col.y * 0.5
	poly.polygon = PackedVector2Array([Vector2(-h.x, cy - h.y), Vector2(h.x, cy - h.y), Vector2(h.x, cy + h.y), Vector2(-h.x, cy + h.y)])
	occ.occluder = poly
	p.add_child(occ)
	p.occluder = occ
	add_child(p)
	_props.append(p)


## Obstaculo con colision. Si hp > 0 se rompe a balazos (PlayerBullet llama hit_by_bullet).
class Prop extends StaticBody2D:
	var kind := ""
	var kingdom := ""
	var room: Room
	var hp := 0.0
	var drops_coin := false
	var sprite: Sprite2D
	var shape_node: CollisionShape2D
	var occluder: LightOccluder2D
	var sprite_w := 32.0
	var sprite_h := 32.0
	var _broken := false
	var _tw: Tween

	func hit_by_bullet(damage: float, dir: Vector2) -> void:
		if hp <= 0.0 or _broken:
			return
		hp -= damage
		if hp <= 0.0:
			_break(dir)
			return
		Sound.play("enemy_hit")
		if _tw != null and _tw.is_valid():
			_tw.kill()
		sprite.modulate = Color(1.9, 1.9, 1.9)
		sprite.position.x += dir.x * 2.0
		_tw = create_tween()
		_tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)
		_tw.parallel().tween_property(sprite, "position:x", sprite.position.x - dir.x * 2.0, 0.12)

	func _break(dir: Vector2) -> void:
		_broken = true
		Sound.play("crack")
		shape_node.set_deferred("disabled", true)
		collision_layer = 0
		remove_from_group(LightKit.GROUP_CASTER)
		var holder := get_parent() as Node2D
		var mat: Material = sprite.material
		# restos planos en el suelo
		var debris_tex := RoomObstacles._tex(kingdom, kind + "_broken")
		if debris_tex != null and holder != null:
			var d := Sprite2D.new()
			d.texture = debris_tex
			d.position = position + Vector2(0, -debris_tex.get_height() * 0.5 + 4.0)
			d.material = mat
			d.modulate.a = 0.0
			holder.get_node("Flat").add_child(d)
			d.create_tween().tween_property(d, "modulate:a", 1.0, 0.12)
		# trozos que saltan
		var chunk_tex := RoomObstacles._tex(kingdom, "chunk")
		if chunk_tex != null and holder != null:
			for i in 8:
				var c := Sprite2D.new()
				c.texture = chunk_tex
				c.region_enabled = true
				c.region_rect = Rect2((i % 4) * 6, 0, 6, 6)
				c.position = position + Vector2(0, -10.0)
				c.z_index = 3
				c.material = mat
				holder.add_child(c)
				var ang := dir.angle() + (float(i) / 7.0 - 0.5) * 2.6 + float(i % 3) * 0.5
				var dist := 22.0 + float((i * 7) % 24)
				var target := c.position + Vector2.from_angle(ang) * dist
				var tw := c.create_tween()
				tw.tween_property(c, "position", target, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.parallel().tween_property(c, "rotation", float(i - 4) * 1.2, 0.35)
				tw.tween_property(c, "modulate:a", 0.0, 0.3)
				tw.tween_callback(c.queue_free)
		if drops_coin and room != null and is_instance_valid(room):
			var pick: Node = RoomObstacles.ITEM_PICKUP_SCENE.instantiate()
			pick.set("item_id", "coin")
			pick.set("position", position + Vector2(0, -6.0))
			room._add_pickup_deferred(pick)
		queue_free()
