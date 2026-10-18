extends Node
class_name RoomLighting

## Luz y atmosfera de las salas (roadmap_nico: puntos 1-4, 6, 9, 17 y fisica ambiental).
## Referencia visual aprobada: src/scenes/light_test.gd. Main lo añade como hijo y llama a:
##   setup(player)                     una vez
##   setup_floor(rooms, floor, seed)   al generar cada piso (sortea que salas son oscuras)
##   enter_room(room)                  al entrar a una sala
##   paint(room, colored, animate)     cuando main pinta la sala (censura gris / color)
## El sorteo de penumbra NO usa el RNG autoload: es un hash de (semilla, piso, grid_pos),
## asi la misma semilla sigue dando la misma mazmorra.

const TILE := 64
## Probabilidad de sala en penumbra por piso (indice 0..4).
const DARK_CHANCE := [0.25, 0.35, 0.45, 0.55, 0.65]
## Extra de salas en penumbra en la 2a etapa de cada reino.
const DEEP_DARK_BONUS := 0.15
const DEEP_AMBIENT := Color(0.78, 0.76, 0.88)  # ambiente de salas claras en la 2a etapa
const DEEP_AMBIENT_DARK := Color(0.8, 0.8, 0.85, 1.0)  # multiplica el de las salas oscuras
const AMBIENT_FREE := Color(0.13, 0.12, 0.16)
const AMBIENT_BOSS := Color(0.17, 0.08, 0.09)
const AMBIENT_CENSORED := Color(0.09, 0.09, 0.12)
const GREY_LIGHT := Color(0.80, 0.80, 0.86)
const MAX_CAST := 3
const CAST_MIN_LEN := 16.0
const CAST_MAX_LEN := 70.0
const CAST_ALPHA := 0.6
const CAST_RANGE := 520.0  # solo actores cerca del jugador reciben sombras proyectadas
## Capa fisica de los objetos sueltos: libre en todo el proyecto (1 jugador/muros,
## 2 enemigos, 3 interaccion, 4 hitboxes, 5 balas enemigas). Solo choca con muros y entre si.
const PROP_LAYER := 32
const PENDULUM_K := 26.0
const PENDULUM_DAMP := 1.6
const PENDULUM_MAX := 22.0
const WALL_SHADE := 20.0  # ancho (px) de la sombra de contacto de los muros
const WALL_SHADE_ALPHA := 0.5

var current_room: Room = null
var _dark_bonus := 0.0
var _player: Node2D
var _hero_light: PointLight2D
var _ambient: CanvasModulate
var _ambient_tween: Tween
var _noise := FastNoiseLite.new()
var _t := 0.0
var _floor_idx := 0
var _seed := 0
var _tint := Color.WHITE
var _colored := false
var _decor: Dictionary = {}  # Room -> Dictionary
var _bullets: Array[Node2D] = []
var _player_prev := Vector2.ZERO
var _have_prev := false
var _vert_tex: GradientTexture2D
var _horiz_tex: GradientTexture2D


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_ambient = CanvasModulate.new()
	_ambient.color = Color.WHITE
	add_child(_ambient)
	get_tree().node_added.connect(_on_node_added)
	_vert_tex = _linear_tex(Vector2(0, 0), Vector2(0, 1))
	_horiz_tex = _linear_tex(Vector2(0, 0), Vector2(1, 0))


func _linear_tex(from: Vector2, to: Vector2) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, WALL_SHADE_ALPHA), Color(0, 0, 0, WALL_SHADE_ALPHA * 0.45), Color(0, 0, 0, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 8
	t.height = 8
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = from
	t.fill_to = to
	return t


## Halo calido colgado del jugador (sin tocar player.gd/.tscn).
func setup(player: Node2D) -> void:
	_player = player
	_hero_light = LightKit.make_light(Color(1.0, 0.86, 0.66), 0.75, 1.5)
	_player.add_child(_hero_light)
	if not _player.has_meta("foot"):
		var spr := _player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
		LightKit.mark_caster(_player, 13.0, LightKit.foot_y(spr) if spr else 0.0)
	_player.set_meta("rl_own", _hero_light)


# ------------------------------------------------------------------ sorteo
func setup_floor(rooms: Dictionary, floor_n: int, seed_: int) -> void:
	# Penumbra por reino (indice 0..4), no por piso 1..10; la 2a etapa es mas oscura (DEEP_DARK_BONUS).
	_floor_idx = clampi(RunManager.region_index(floor_n), 0, DARK_CHANCE.size() - 1)
	_dark_bonus = DEEP_DARK_BONUS if RunManager.floor_stage(floor_n) > 1 else 0.0
	_seed = seed_
	_decor.clear()
	_bullets.clear()
	current_room = null
	for pos in rooms:
		var room: Room = rooms[pos]
		room.is_dark = _roll_dark(room, floor_n)


func _roll_dark(room: Room, floor_n: int) -> bool:
	match room.room_type:
		Room.RoomType.START, Room.RoomType.SHOP:
			return false
		Room.RoomType.BOSS:
			return true
	return _hash01(_seed, floor_n, room.grid_pos.x, room.grid_pos.y) < DARK_CHANCE[_floor_idx] + _dark_bonus


## Hash entero determinista (sin estado global) -> 0..1.
static func _hash01(a: int, b: int, c: int, d: int) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791) ^ (d * 2654435761)
	h &= 0xFFFFFFFF
	h = ((h >> 16) ^ h) * 0x45d9f3b & 0xFFFFFFFF
	h = ((h >> 16) ^ h) * 0x45d9f3b & 0xFFFFFFFF
	h = (h >> 16) ^ h
	return float(h & 0xFFFFFF) / float(0x1000000)


func _room_seed(room: Room, salt: int) -> int:
	return int(_hash01(_seed + salt, _floor_idx, room.grid_pos.y, room.grid_pos.x) * 2147483647.0)


# ------------------------------------------------------------------ entrada
func enter_room(room: Room) -> void:
	if current_room and _decor.has(current_room):
		_set_decor_active(_decor[current_room], false)
	current_room = room
	_have_prev = false
	_bullets.clear()
	if not _decor.has(room):
		_decor[room] = _build_room(room)
	var d: Dictionary = _decor[room]
	_set_decor_active(d, true)
	LightKit.set_dark(get_tree(), room.is_dark)
	if not room.is_dark:
		_hide_all_casts()
	_apply_ambient(room, false)
	_apply_colors(room, false)


func _set_decor_active(d: Dictionary, on: bool) -> void:
	var node: Node2D = d.node
	node.visible = on
	node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


# ------------------------------------------------------------------ censura / color
func paint(room: Room, colored: bool, animate := false) -> void:
	if room != current_room:
		return
	var was: bool = room.get_meta("rl_colored", false)
	_tint = _tint_now()
	_colored = colored
	room.set_meta("rl_colored", colored)
	_apply_ambient(room, animate)
	_apply_colors(room, animate)
	# Al liberar una sala oscura entra un destello calido con el color del reino.
	if animate and colored and not was and room.is_dark:
		_flash()


func _tint_now() -> Color:
	var rm := get_node_or_null("/root/RunManager")
	if rm:
		return rm.floor_data().tint
	return Color.WHITE


func _apply_ambient(room: Room, animate: bool) -> void:
	_tint = _tint_now()
	var amb := Color.WHITE
	# 2a etapa de cada reino: todo un paso mas hondo (mas frio y apagado, tambien en salas claras).
	var deep: bool = RunManager.floor_stage(get_node("/root/RunManager").current_floor) > 1 if has_node("/root/RunManager") else false
	if room.is_dark:
		var free := AMBIENT_BOSS if room.room_type == Room.RoomType.BOSS else AMBIENT_FREE.lerp(_tint.darkened(0.7), 0.3)
		amb = free if _colored else AMBIENT_CENSORED
		if deep:
			amb = amb * DEEP_AMBIENT_DARK
	elif deep:
		amb = DEEP_AMBIENT
	if _ambient_tween and _ambient_tween.is_valid():
		_ambient_tween.kill()
	if animate:
		_ambient_tween = create_tween()
		_ambient_tween.tween_property(_ambient, "color", amb, 1.2)
	else:
		_ambient.color = amb


func _light_color(base: Color, k_tint: float) -> Color:
	return base.lerp(_tint, k_tint) if _colored else base.lerp(GREY_LIGHT, 0.85)


func _apply_colors(room: Room, animate: bool) -> void:
	_tint = _tint_now()
	var d: Dictionary = _decor.get(room, {})
	var tw: Tween = null
	if animate:
		tw = create_tween().set_parallel()
	if _hero_light:
		_put(tw, _hero_light, "color", (_hero_light.get_meta("base_color") as Color).lerp(_tint if _colored else GREY_LIGHT, 0.25))
	for l in d.get("lights", []):
		if not is_instance_valid(l):
			continue
		var base: Color = l.get_meta("base_color")
		var k: float = l.get_meta("tint_k", 0.45)
		_put(tw, l, "color", _light_color(base, k))
	var boss: PointLight2D = d.get("boss_light")
	if boss:
		var red: Color = boss.get_meta("base_color")
		_put(tw, boss, "color", red if _colored else red.lerp(GREY_LIGHT, 0.35))


func _put(tw: Tween, obj: Object, prop: String, value) -> void:
	if tw:
		tw.tween_property(obj, prop, value, 1.2)
	else:
		obj.set(prop, value)


func _flash() -> void:
	var flash := LightKit.make_light(_tint.lerp(Color(1, 0.9, 0.7), 0.4), 0.0, 9.0, false)
	flash.global_position = _player.global_position
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "energy", 1.3, 0.18)
	tw.tween_property(flash, "energy", 0.0, 1.1)
	tw.tween_callback(flash.queue_free)


# ------------------------------------------------------------------ construccion de sala
func _room_size(room: Room) -> Vector2:
	var rect := room.floor_tilemap.get_used_rect()
	return Vector2(rect.size) * TILE


func _build_room(room: Room) -> Dictionary:
	var size := _room_size(room)
	var node := Node2D.new()
	node.name = "Lighting"
	room.add_child(node)
	var d := {"node": node, "size": size, "lights": [], "torches": [], "hanging": [], "props": [], "boss_light": null}
	var rng := RandomNumberGenerator.new()
	rng.seed = _room_seed(room, 1)
	_build_wall_shade(room, size)
	_build_occluders(node, size)
	if room.is_dark:
		_build_torches(room, d, rng)
		_build_hanging(room, d, rng)
		if room.room_type == Room.RoomType.BOSS:
			_build_boss_light(d, size)
	# La fisica no puede crearse mientras el motor vacia consultas (la entrada a la sala
	# viene de un body_entered de la puerta): los objetos nacen un frame despues.
	_spawn_props.call_deferred(room, d, rng.randi())
	return d


## Punto 17: franja degradada oscura en la base interior de los muros.
func _build_wall_shade(room: Room, size: Vector2) -> void:
	var strips := Node2D.new()
	strips.name = "WallShade"
	var w := WALL_SHADE
	var defs := [
		[_vert_tex, Vector2(0, 0), Vector2(size.x, w), false, false],  # arriba
		[_vert_tex, Vector2(0, size.y - w), Vector2(size.x, w), false, true],  # abajo
		[_horiz_tex, Vector2(0, 0), Vector2(w, size.y), false, false],  # izquierda
		[_horiz_tex, Vector2(size.x - w, 0), Vector2(w, size.y), true, false],  # derecha
	]
	for df in defs:
		var s := Sprite2D.new()
		s.texture = df[0]
		s.centered = false
		s.position = df[1]
		s.scale = Vector2(df[2].x / 8.0, df[2].y / 8.0)
		s.flip_h = df[3]
		s.flip_v = df[4]
		strips.add_child(s)
	room.add_child(strips)
	room.move_child(strips, room.floor_tilemap.get_index() + 1)


## Un oclusor por lado de muro (borde exterior): la luz alumbra los muros por dentro y no se sale.
func _build_occluders(parent: Node2D, size: Vector2) -> void:
	var rects := [
		Rect2(-TILE, -TILE, size.x + TILE * 2, TILE),
		Rect2(-TILE, size.y, size.x + TILE * 2, TILE),
		Rect2(-TILE, 0, TILE, size.y),
		Rect2(size.x, 0, TILE, size.y),
	]
	for r in rects:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		occ.occluder = poly
		parent.add_child(occ)


func _door_points(room: Room) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for door in room.doors.values():
		out.append(door.position)
	return out


## Posicion dentro de la huella de un obstaculo (RoomObstacles): no soltar objetos ahi.
func _in_obstacle(room: Room, pos: Vector2) -> bool:
	for r: Rect2 in room.get_meta("obstacle_rects", []):
		if r.grow(10.0).has_point(pos):
			return true
	return false


func _near_door(p: Vector2, doors: Array[Vector2], dist: float) -> bool:
	for dp in doors:
		if p.distance_to(dp) < dist:
			return true
	return false


# ------------------------------------------------------------------ antorchas
func _build_torches(room: Room, d: Dictionary, rng: RandomNumberGenerator) -> void:
	var size: Vector2 = d.size
	var doors := _door_points(room)
	var n := clampi(int(round((size.x + size.y) / TILE / 5.0)), 2, 6)
	if room.room_type == Room.RoomType.BOSS:
		n = clampi(n + 1, 3, 7)
	# Candidatos: centros de baldosa a lo largo de los 4 muros (sin esquinas), lejos de las puertas.
	var cands: Array[Dictionary] = []
	for x in range(1, int(size.x / TILE) - 1):
		var px := (x + 0.5) * TILE
		cands.append({"p": Vector2(px, 6), "n": Vector2(0, 1)})
		cands.append({"p": Vector2(px, size.y - 6), "n": Vector2(0, -1)})
	for y in range(1, int(size.y / TILE) - 1):
		var py := (y + 0.5) * TILE
		cands.append({"p": Vector2(6, py), "n": Vector2(1, 0)})
		cands.append({"p": Vector2(size.x - 6, py), "n": Vector2(-1, 0)})
	cands = cands.filter(func(c): return not _near_door(c.p, doors, 100.0) and room.is_walkable(c.p + c.n * 20.0))  # y en suelo (forma de sala)
	# Barajado con el RNG local (no el autoload).
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	var chosen: Array[Dictionary] = []
	for c in cands:
		if chosen.size() >= n:
			break
		var ok := true
		for o in chosen:
			if o.p.distance_to(c.p) < 170.0:
				ok = false
				break
		if ok:
			chosen.append(c)
	var node: Node2D = d.node
	for c in chosen:
		var flame := _make_flame()
		flame.position = c.p
		node.add_child(flame)
		var l := LightKit.make_light(Color(1.0, 0.62, 0.30), 1.1, 1.4)
		l.position = c.p + c.n * 10.0
		l.set_meta("base_pos", l.position)
		node.add_child(l)
		d.lights.append(l)
		d.torches.append({"light": l, "flame": flame})


func _make_flame() -> Node2D:
	var root := Node2D.new()
	var base := Polygon2D.new()
	base.color = Color(0.25, 0.17, 0.12)
	base.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(2, 10), Vector2(-2, 10)])
	root.add_child(base)
	var fire := Polygon2D.new()
	fire.name = "Fire"
	fire.color = Color(1.0, 0.75, 0.3)
	fire.polygon = PackedVector2Array([Vector2(0, -12), Vector2(5, -2), Vector2(0, 2), Vector2(-5, -2)])
	root.add_child(fire)
	var core := Polygon2D.new()
	core.color = Color(1.0, 0.95, 0.7)
	core.polygon = PackedVector2Array([Vector2(0, -6), Vector2(2.5, -1), Vector2(0, 1), Vector2(-2.5, -1)])
	fire.add_child(core)
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	fire.material = mat
	core.use_parent_material = true
	root.add_to_group(LightKit.GROUP_DARK)
	return root


func _make_lamp_visual() -> Node2D:
	var root := Node2D.new()
	var frame := Polygon2D.new()
	frame.color = Color(0.2, 0.16, 0.12)
	frame.polygon = PackedVector2Array([Vector2(-5, -6), Vector2(5, -6), Vector2(6, 6), Vector2(-6, 6)])
	root.add_child(frame)
	var glow := Polygon2D.new()
	glow.name = "Glow"
	glow.color = Color(1.0, 0.85, 0.5)
	glow.polygon = PackedVector2Array([Vector2(-3, -4), Vector2(3, -4), Vector2(4, 4), Vector2(-4, 4)])
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = mat
	root.add_child(glow)
	return root


# ------------------------------------------------------------------ faroles colgantes
func _build_hanging(room: Room, d: Dictionary, rng: RandomNumberGenerator) -> void:
	var size: Vector2 = d.size
	var tiles := (size.x / TILE) * (size.y / TILE)
	var count := 0
	if rng.randf() < 0.65:
		count = 1
		if tiles >= 100.0 and rng.randf() < 0.6:
			count = 2
	var doors := _door_points(room)
	var node: Node2D = d.node
	var tries := 0
	while count > 0 and tries < 30:
		tries += 1
		var anchor := Vector2(rng.randf_range(2.0, size.x / TILE - 2.0), rng.randf_range(2.0, size.y / TILE - 2.0)) * TILE
		if _near_door(anchor, doors, 130.0):
			continue
		count -= 1
		var chain := Line2D.new()
		chain.width = 1.5
		chain.default_color = Color(0.15, 0.13, 0.12)
		chain.points = PackedVector2Array([anchor, anchor])
		chain.add_to_group(LightKit.GROUP_DARK)
		node.add_child(chain)
		var lamp := _make_lamp_visual()
		lamp.position = anchor
		lamp.add_to_group(LightKit.GROUP_DARK)
		node.add_child(lamp)
		var l := LightKit.make_light(Color(1.0, 0.8, 0.5), 0.9, 1.1)
		l.set_meta("tint_k", 0.3)
		lamp.add_child(l)
		d.lights.append(l)
		d.hanging.append({"anchor": anchor, "lamp": lamp, "chain": chain, "light": l, "off": Vector2.ZERO, "vel": Vector2.ZERO})


func _update_hanging(d: Dictionary, delta: float, wob: float) -> void:
	var pv := Vector2.ZERO
	if _have_prev:
		pv = (_player.position - _player_prev) / maxf(delta, 0.0001)
	var ppos := _player.global_position - (current_room.global_position if current_room else Vector2.ZERO)
	for h in d.hanging:
		var lamp_pos: Vector2 = h.anchor + h.off
		var dist := lamp_pos.distance_to(ppos)
		if dist < 30.0 and pv.length() > 20.0 and pv.length() < 900.0:
			h.vel += pv * (1.0 - dist / 30.0) * delta * 6.0
		var wind := Vector2(_noise.get_noise_2d(_t * 0.4, h.anchor.x), _noise.get_noise_2d(_t * 0.4, h.anchor.y + 300.0)) * 18.0 * (1.0 + wob * 3.0)
		var acc: Vector2 = -h.off * PENDULUM_K - h.vel * PENDULUM_DAMP + wind
		h.vel += acc * delta
		h.off += h.vel * delta
		var maxoff := PENDULUM_MAX * (1.0 + wob * 0.5)
		if h.off.length() > maxoff:
			h.off = h.off.limit_length(maxoff)
			h.vel *= 0.6
		var lamp: Node2D = h.lamp
		lamp.position = h.anchor + h.off
		lamp.rotation = h.vel.x * 0.004
		var chain: Line2D = h.chain
		chain.points = PackedVector2Array([h.anchor, lamp.position + Vector2(0, -6)])


# ------------------------------------------------------------------ jefe
## Punto 9: luz roja pulsante e inquietante.
func _build_boss_light(d: Dictionary, size: Vector2) -> void:
	var l := LightKit.make_light(Color(1.0, 0.1, 0.08), 0.85, 5.0)
	l.position = size * 0.5
	d.node.add_child(l)
	d.boss_light = l


# ------------------------------------------------------------------ objetos sueltos
func _spawn_props(room: Room, d: Dictionary, seed_: int) -> void:
	if not is_instance_valid(room) or not is_instance_valid(d.node):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var size: Vector2 = d.size
	var tiles := (size.x / TILE) * (size.y / TILE)
	var count: int
	match room.room_type:
		Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP, Room.RoomType.MINIBOSS, Room.RoomType.PUZZLE:
			count = clampi(int(tiles / 16.0) + rng.randi_range(0, 2), 3, 9)
		Room.RoomType.BOSS:
			count = rng.randi_range(2, 4)
		Room.RoomType.START, Room.RoomType.SHOP:
			count = rng.randi_range(0, 1)
		_:
			count = rng.randi_range(1, 3)
	var doors := _door_points(room)
	var kinds := ["piedra", "piedra", "piedra", "hueso", "hueso", "lata", "lata", "craneo"]
	var lamp_done := not room.is_dark or rng.randf() > 0.3
	for i in count:
		var pos := Vector2.ZERO
		var ok := false
		for k in 12:
			pos = Vector2(rng.randf_range(1.0, size.x / TILE - 1.0), rng.randf_range(1.0, size.y / TILE - 1.0)) * TILE
			if not _near_door(pos, doors, 120.0) and not _in_obstacle(room, pos) and room.is_walkable(pos, 10.0):
				ok = true
				break
		if not ok:
			continue
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		if not lamp_done:
			kind = "farol"
			lamp_done = true
		d.props.append(_make_prop(d, kind, pos, rng))
	# El tinte de las luces de objetos sueltos se aplica con el color ya conocido.
	_apply_colors(room, false)
	if room == current_room:
		LightKit.set_dark(get_tree(), room.is_dark)


func _make_prop(d: Dictionary, kind: String, pos: Vector2, rng: RandomNumberGenerator) -> RigidBody2D:
	var body := RigidBody2D.new()
	body.collision_layer = PROP_LAYER
	body.collision_mask = 1 | 64 | PROP_LAYER  # 64 = huecos
	body.gravity_scale = 0.0
	body.linear_damp = 3.0
	body.angular_damp = 3.0
	body.position = pos
	body.rotation = rng.randf() * TAU
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.45
	mat.friction = 0.6
	body.physics_material_override = mat
	var vis := Polygon2D.new()
	var radius := 5.0
	match kind:
		"piedra":
			radius = rng.randf_range(3.5, 6.0)
			var pts := PackedVector2Array()
			for k in 7:
				pts.append(Vector2.from_angle(k * TAU / 7.0) * radius * rng.randf_range(0.75, 1.1))
			vis.polygon = pts
			vis.color = Color(0.55, 0.52, 0.5)
			body.mass = 0.6
		"hueso":
			radius = 6.0
			vis.polygon = PackedVector2Array([Vector2(-8, -1.5), Vector2(8, -1.5), Vector2(9, -3), Vector2(10, 0), Vector2(9, 3), Vector2(8, 1.5), Vector2(-8, 1.5), Vector2(-9, 3), Vector2(-10, 0), Vector2(-9, -3)])
			vis.color = Color(0.92, 0.88, 0.78)
			body.mass = 0.3
		"lata":
			radius = 4.0
			vis.polygon = PackedVector2Array([Vector2(-6, -3.5), Vector2(6, -3.5), Vector2(6, 3.5), Vector2(-6, 3.5)])
			vis.color = Color(0.7, 0.3, 0.35)
			body.mass = 0.15
			mat.bounce = 0.7
		"craneo":
			radius = 7.0
			var pts := PackedVector2Array()
			for k in 10:
				pts.append(Vector2.from_angle(k * TAU / 10.0) * Vector2(7, 6))
			vis.polygon = pts
			vis.color = Color(0.9, 0.86, 0.76)
			body.mass = 0.5
		"farol":
			radius = 6.0
			body.mass = 0.8
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	body.set_meta("rl_radius", radius)
	var own: PointLight2D = null
	if kind == "farol":
		vis.free()
		var lamp := _make_lamp_visual()
		for c in lamp.get_children():
			c.reparent(body, false)
		lamp.free()
		body.get_node("Glow").add_to_group(LightKit.GROUP_DARK)
		own = LightKit.make_light(Color(1.0, 0.75, 0.45), 0.8, 0.8)
		own.set_meta("tint_k", 0.3)
		body.add_child(own)
		d.lights.append(own)
		body.set_meta("rl_own", own)
	else:
		body.add_child(vis)
	d.node.add_child(body)
	LightKit.add_contact_shadow(body, radius + 2.0, radius * 0.6)
	LightKit.mark_caster(body, radius + 2.0, radius * 0.6)
	return body


## El jugador las patea al pisarlas (segun su velocidad; el dash las lanza).
func _kick_props(d: Dictionary, delta: float) -> void:
	if not _have_prev:
		return
	var pv: Vector2 = (_player.global_position - _player_prev) / maxf(delta, 0.0001)
	var speed := pv.length()
	if speed < 30.0 or speed > 1500.0:
		return
	var feet := _player.global_position + Vector2(0, 10)
	for b in d.props:
		if not is_instance_valid(b):
			continue
		var dv: Vector2 = b.global_position - feet
		if dv.length() > 16.0:
			continue
		var dir := (pv.normalized() * 0.75 + dv.normalized() * 0.25).normalized()
		var power := speed * (0.9 if speed < 300.0 else 1.6)
		b.apply_central_impulse(dir * power * b.mass * 0.6)
		b.apply_torque_impulse(randf_range(-1.0, 1.0) * power * 2.0)


## Lo que pateas y sale volando hace un poco de dano al enemigo que alcanza (mas si es pesado y
## va rapido: una lata pica, una piedra lanzada con dash duele). Un golpe por objeto y enemigo
## mientras siga en vuelo; el objeto rebota. El autor es el jugador (cuenta como suya la muerte).
const PROP_HIT_SPEED := 80.0  # px/s minimos para que haga dano
const PROP_HIT_RANGE := 18.0  # radio del enemigo que se suma al del objeto

func _props_hit_enemies(d: Dictionary) -> void:
	if d.props.is_empty() or current_room.enemies_spawned.is_empty():
		return
	var foes := RoomUtil.alive(current_room)
	if foes.is_empty():
		return
	for b in d.props:
		if not is_instance_valid(b):
			continue
		var v: Vector2 = b.linear_velocity
		var speed := v.length()
		if speed < PROP_HIT_SPEED:
			if b.has_meta("rl_hit"):
				b.remove_meta("rl_hit")  # quieto otra vez: puede volver a pegar
			continue
		var hit: Array = b.get_meta("rl_hit", [])
		var reach: float = b.get_meta("rl_radius", 6.0) + PROP_HIT_RANGE
		for e in foes:
			if e in hit or b.global_position.distance_to(e.global_position + Vector2(0, -8)) > reach:
				continue
			hit.append(e)
			b.set_meta("rl_hit", hit)
			var dmg := clampf(round(1.0 + speed * b.mass * 0.012), 1.0, 6.0)
			e.take_damage(dmg, _player, v.normalized() * minf(speed, 300.0) * 0.6)
			b.linear_velocity = -v * 0.4  # rebota en el bicho
			Sound.play("enemy_hit")
			break


func _on_node_added(n: Node) -> void:
	if n is PlayerBullet:
		_bullets.append(n)


## Las balas del jugador (Area2D que no ve la capa de los objetos) tambien los empujan.
func _push_with_bullets(d: Dictionary) -> void:
	_bullets = _bullets.filter(func(b): return is_instance_valid(b))
	if _bullets.is_empty() or d.props.is_empty():
		return
	for bl in _bullets:
		var dir := Vector2.RIGHT.rotated(bl.global_rotation)
		for b in d.props:
			if not is_instance_valid(b):
				continue
			if b.global_position.distance_to(bl.global_position) > 14.0:
				continue
			var key := "rl_hit_%d" % b.get_instance_id()
			if bl.has_meta(key):
				continue
			bl.set_meta(key, true)
			b.apply_central_impulse(dir * 140.0 * b.mass)
			b.apply_torque_impulse(randf_range(-1.0, 1.0) * 40.0)


# ------------------------------------------------------------------ bucle
func _process(delta: float) -> void:
	_t += delta
	if current_room == null or _player == null or not _decor.has(current_room):
		return
	var d: Dictionary = _decor[current_room]
	var wob := LightKit.intox_wobble
	var smooth := 1.0 - exp(-delta * 12.0)
	var dark := current_room.is_dark
	if dark:
		_flicker_torches(d, smooth, wob)
		_update_hanging(d, delta, wob)
		if d.boss_light:
			_pulse_boss(d.boss_light)
		_hero_light.energy = _hero_light.get_meta("base_energy") * (1.0 + _noise.get_noise_2d(_t * 0.5, 500.0) * 0.06)
	_kick_props(d, delta)
	_push_with_bullets(d)
	_props_hit_enemies(d)
	_player_prev = _player.global_position
	_have_prev = true
	if dark:
		_update_cast_shadows(d)


## Parpadeo suave: capas de ruido lento + una rapida muy leve, filtradas; la luz se mece unos pixeles.
func _flicker_torches(d: Dictionary, smooth: float, wob: float) -> void:
	var amp := 1.0 + wob * 2.5
	var sway_amp := 1.0 + wob * 3.0
	for i in d.torches.size():
		var t: Dictionary = d.torches[i]
		var l: PointLight2D = t.light
		var slow := _noise.get_noise_2d(_t * (0.9 + wob), i * 37.0)
		var mid := _noise.get_noise_2d(_t * (2.3 + wob * 2.0), i * 91.0)
		var fast := _noise.get_noise_2d(_t * (7.0 + wob * 4.0), i * 13.0)
		var e: float = l.get_meta("base_energy") * (1.0 + (slow * 0.18 + mid * 0.08 + fast * 0.03) * amp)
		l.energy = lerpf(l.energy, e, smooth)
		l.texture_scale = lerpf(l.texture_scale, l.get_meta("base_scale") * (1.0 + slow * 0.05 * amp), smooth)
		var sway := Vector2(_noise.get_noise_2d(_t * 1.4, i * 53.0), _noise.get_noise_2d(_t * 1.1, i * 71.0)) * Vector2(4.0, 2.5) * sway_amp
		l.position = l.position.lerp(l.get_meta("base_pos") + sway, smooth)
		var fire := (t.flame as Node2D).get_node("Fire") as Node2D
		fire.scale = Vector2(1.0 + mid * 0.12 * amp, 1.0 + slow * 0.2 * amp + fast * 0.06)
		fire.rotation = sway.x * 0.04
		fire.skew = mid * 0.15 * amp
	# Los faroles colgantes tambien titilan un poco mas con la intoxicacion.
	for h in d.hanging:
		var l: PointLight2D = h.light
		l.energy = l.get_meta("base_energy") * (1.0 + _noise.get_noise_2d(_t * 1.6, h.anchor.x) * 0.05 * amp)


func _pulse_boss(l: PointLight2D) -> void:
	var beat := pow(sin(_t * 2.1) * 0.5 + 0.5, 1.6)
	var jitter := _noise.get_noise_2d(_t * 5.0, 900.0) * 0.08
	l.energy = (0.45 + 0.75 * beat + jitter) * l.get_meta("base_energy")
	l.texture_scale = l.get_meta("base_scale") * (0.92 + 0.12 * beat)


# ------------------------------------------------------------------ sombras proyectadas
func _hide_all_casts() -> void:
	for n in get_tree().get_nodes_in_group(LightKit.GROUP_CASTER):
		for s in n.get_meta("rl_casts", []):
			if is_instance_valid(s):
				s.visible = false


func _casts_for(n: Node2D) -> Array:
	if n.has_meta("rl_casts"):
		return n.get_meta("rl_casts")
	var foot: Vector2 = n.get_meta("foot", Vector2.ZERO)
	var radius: float = n.get_meta("shadow_radius", 12.0)
	var casts: Array = []
	for i in MAX_CAST:
		var s := Sprite2D.new()
		s.texture = LightKit.cast_texture()
		s.centered = false
		s.offset = Vector2(0, -32)
		s.position = foot
		s.show_behind_parent = true
		s.visible = false
		s.set_meta("width", radius * 1.5)
		n.add_child(s)
		casts.append(s)
	n.set_meta("rl_casts", casts)
	return casts


## Cada luz cercana tira la sombra del actor hacia el lado contrario: mas larga y tenue
## cuanto mas lejos esta la luz. Si un muro tapa la luz, no hay sombra.
func _update_cast_shadows(d: Dictionary) -> void:
	var lights: Array[PointLight2D] = [_hero_light]
	for l in d.lights:
		if is_instance_valid(l) and l.enabled and l.is_visible_in_tree():
			lights.append(l)
	var boss: PointLight2D = d.boss_light
	if boss:
		lights.erase(boss)  # la luz del jefe es ambiental: no proyecta sombras por actor
	var space := _player.get_world_2d().direct_space_state
	var ppos := _player.global_position
	var exclude: Array[RID] = []
	if _player is CollisionObject2D:
		exclude.append((_player as CollisionObject2D).get_rid())
	for n in get_tree().get_nodes_in_group(LightKit.GROUP_CASTER):
		if not (n is Node2D) or not n.is_visible_in_tree():
			continue
		if n != _player and not current_room.is_ancestor_of(n):
			continue
		if n.global_position.distance_to(ppos) > CAST_RANGE:
			continue
		var foot: Vector2 = n.global_position + (n.get_meta("foot", Vector2.ZERO) as Vector2).rotated(n.global_rotation)
		var own = n.get_meta("rl_own") if n.has_meta("rl_own") else null
		var hits: Array = []
		for l in lights:
			if l == own:
				continue
			var to_foot: Vector2 = foot - l.global_position
			var reach: float = 128.0 * l.texture_scale
			var dist := to_foot.length()
			if dist >= reach or dist < 1.0:
				continue
			var q := PhysicsRayQueryParameters2D.create(l.global_position, foot, 1)
			q.exclude = exclude
			if n is CollisionObject2D:  # un obstaculo no se tapa a si mismo la luz
				var ex: Array[RID] = exclude.duplicate()
				ex.append((n as CollisionObject2D).get_rid())
				q.exclude = ex
			if not space.intersect_ray(q).is_empty():
				continue
			var k := 1.0 - dist / reach
			var strength: float = k * k * l.energy / float(l.get_meta("base_energy"))
			hits.append({"dir": to_foot / dist, "dist": dist, "reach": reach, "s": strength})
		hits.sort_custom(func(x, y): return x.s > y.s)
		var casts: Array = _casts_for(n)
		for i in casts.size():
			var s: Sprite2D = casts[i]
			if i >= hits.size():
				s.visible = false
				continue
			var h: Dictionary = hits[i]
			var length := lerpf(CAST_MIN_LEN, CAST_MAX_LEN, clampf(h.dist / h.reach, 0.0, 1.0))
			s.visible = true
			s.global_rotation = (h.dir as Vector2).angle()
			s.scale = Vector2(length / 64.0, float(s.get_meta("width")) / 64.0)
			s.modulate.a = clampf(h.s * CAST_ALPHA * 1.6, 0.0, CAST_ALPHA)
