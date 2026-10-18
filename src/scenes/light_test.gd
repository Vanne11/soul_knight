extends Node2D

## Sala de prueba de luz y sombra (roadmap_nico, tanda 1: puntos 1-4 y 13-17).
## No la usa el juego: sirve para aprobar el aspecto antes de llevarlo a las salas.
## Abrir con:  godot --path . res://src/scenes/light_test.tscn
## Captura automatica:  ... -- --capture=<carpeta>  (saca PNGs de cada estado y sale)
##
## Teclas: 1 luz on/off · 2 reino siguiente · 3 censurada/liberada · 4 sombras de muros
##         5 sombras de personajes · 6 antorchas · 7 sala oscura/clara · N sortear sala
##         R objetos de nuevo
##         F12 captura

const TILESET := preload("res://assets/tilesets/dungeon_tileset.tres")
const PLAYER_SCENE := preload("res://src/player/player.tscn")
const WALL_SOURCE := 4
const TILE := 64
const ROOM := Vector2i(16, 12)
## Capas de luz: 1 = suelo y actores (reciben sombra), 2 = muros (se iluminan, no se sombrean).
const MASK_FLOOR := 1
const MASK_WALL := 2
## Columnas interiores (en tiles) para ver la sombra proyectada.
const PILLARS := [Vector2i(4, 3), Vector2i(11, 3), Vector2i(4, 8), Vector2i(11, 8)]
const ENEMIES := ["granito", "testiculo", "ovulo", "aduanero", "barra_negra"]
## Probabilidad de que una sala salga en penumbra con antorchas, por piso
## (indice de reino 0..4; la 2a etapa suma RoomLighting.DEEP_DARK_BONUS): cuanto mas hondo, mas salas oscuras.
const DARK_CHANCE := [0.25, 0.35, 0.45, 0.55, 0.65, 0.7]

## Oscuridad ambiental (punto 1). Censurada: mas oscura y fria (punto 6).
const AMBIENT_FREE := Color(0.13, 0.12, 0.16)
const AMBIENT_CENSORED := Color(0.09, 0.09, 0.12)
const GREY_FLOOR := Color(0.42, 0.42, 0.46)
const GREY_WALLS := Color(0.3, 0.3, 0.34)
const GREY_LIGHT := Color(0.80, 0.80, 0.86)
## Sombras de personajes por luz: cuantas como maximo y cuanto se alargan.
const MAX_CAST := 3
const CAST_MIN_LEN := 16.0
const CAST_MAX_LEN := 70.0
const CAST_ALPHA := 0.6
## Fisica: capa de los objetos sueltos (chocan con muros y entre ellos, no frenan al jugador).
const PROP_LAYER := 4
## Faroles colgantes (en tiles): pendulo visto desde arriba, se mecen al pasar debajo.
const HANGING := [Vector2(6, 6), Vector2(10.5, 5.5)]
const PENDULUM_K := 26.0  # rigidez del resorte (vuelta al centro)
const PENDULUM_DAMP := 1.6  # amortiguacion
const PENDULUM_MAX := 22.0  # cuanto se aleja del punto de anclaje

var kingdom_idx := 0
var colored := true
var lights_on := true
var cast_shadows := true
var blob_shadows := true
var torches_on := true
var room_dark := true

var _floor: TileMap
var _walls: TileMap
var _ambient: CanvasModulate
var _player: Node2D
var _hero_light: PointLight2D
var _torches: Array[PointLight2D] = []
var _flames: Array[Node2D] = []
## Cada actor: {node, foot (local), contact (Sprite2D), casts (Array de Sprite2D), own (luz propia o null)}
var _actors: Array[Dictionary] = []
var _occluders: Array[LightOccluder2D] = []
var _noise := FastNoiseLite.new()
var _t := 0.0
var _label: Label
var _fps_samples: Array[float] = []
var _light_tex: GradientTexture2D
var _contact_tex: GradientTexture2D
var _cast_tex: GradientTexture2D
## Faroles colgantes: {anchor, lamp (Node2D), chain (Line2D), light, off, vel}
var _hanging: Array[Dictionary] = []
var _props: Array[RigidBody2D] = []
var _prop_lights: Array[PointLight2D] = []
var _player_prev := Vector2.ZERO


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 1.0
	_build_textures()
	_build_room()
	_build_occluders()
	_build_actors()
	_build_torches()
	_build_hanging()
	_spawn_props()
	_build_ambient()
	_build_hud()
	_apply_all(false)
	var cap := _arg("--capture=")
	if cap != "":
		_auto_capture.call_deferred(cap)


func _dark() -> bool:
	return room_dark and lights_on


# ------------------------------------------------------------------ texturas
func _build_textures() -> void:
	# Luz: caida suave (casi cuadratica) en vez de un degradado lineal con borde marcado.
	_light_tex = _radial(256, [
		[0.0, Color(1, 1, 1, 1.0)],
		[0.25, Color(1, 1, 1, 0.78)],
		[0.5, Color(1, 1, 1, 0.42)],
		[0.75, Color(1, 1, 1, 0.13)],
		[1.0, Color(1, 1, 1, 0.0)],
	])
	# Sombra de contacto: elipse bajo los pies.
	_contact_tex = _radial(64, [
		[0.0, Color(0, 0, 0, 0.7)],
		[0.4, Color(0, 0, 0, 0.55)],
		[1.0, Color(0, 0, 0, 0.0)],
	])
	# Sombra proyectada: degradado radial con el centro en el borde izquierdo
	# (los pies); se estira hacia +x y se gira lejos de la luz.
	_cast_tex = _radial(64, [
		[0.0, Color(0, 0, 0, 1.0)],
		[0.5, Color(0, 0, 0, 0.55)],
		[1.0, Color(0, 0, 0, 0.0)],
	], Vector2(0.0, 0.5), Vector2(1.0, 0.5))


func _radial(size: int, stops: Array, from := Vector2(0.5, 0.5), to := Vector2(1.0, 0.5)) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = from
	t.fill_to = to
	return t


# ------------------------------------------------------------------ sala
func _build_room() -> void:
	_floor = TileMap.new()
	_floor.tile_set = TILESET
	_floor.light_mask = MASK_FLOOR
	add_child(_floor)
	_walls = TileMap.new()
	_walls.tile_set = TILESET
	_walls.light_mask = MASK_WALL
	add_child(_walls)
	for x in ROOM.x:
		for y in ROOM.y:
			_floor.set_cell(0, Vector2i(x, y), randi_range(0, 3), Vector2i.ZERO)
	for x in range(-1, ROOM.x + 1):
		_walls.set_cell(0, Vector2i(x, -1), WALL_SOURCE, Vector2i.ZERO)
		_walls.set_cell(0, Vector2i(x, ROOM.y), WALL_SOURCE, Vector2i.ZERO)
	for y in ROOM.y:
		_walls.set_cell(0, Vector2i(-1, y), WALL_SOURCE, Vector2i.ZERO)
		_walls.set_cell(0, Vector2i(ROOM.x, y), WALL_SOURCE, Vector2i.ZERO)
	for p in PILLARS:
		_walls.set_cell(0, p, WALL_SOURCE, Vector2i.ZERO)


## Punto 4: un oclusor por muro y por columna (no uno por baldosa).
## Los muros van al borde exterior: la luz los alumbra por dentro y no se sale.
func _build_occluders() -> void:
	var w := ROOM.x * TILE
	var h := ROOM.y * TILE
	var rects := [
		Rect2(-TILE, -TILE, w + TILE * 2, TILE),  # arriba
		Rect2(-TILE, h, w + TILE * 2, TILE),  # abajo
		Rect2(-TILE, 0, TILE, h),  # izquierda
		Rect2(w, 0, TILE, h),  # derecha
	]
	for p in PILLARS:
		rects.append(Rect2(Vector2(p) * TILE, Vector2(TILE, TILE)))
	for r in rects:
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		occ.occluder = poly
		add_child(occ)
		_occluders.append(occ)


# ------------------------------------------------------------------ actores
func _build_actors() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector2(ROOM) * TILE * 0.5
	add_child(_player)
	var cam := _player.get_node("Camera2D") as Camera2D
	cam.limit_left = -40
	cam.limit_top = -40
	cam.limit_right = ROOM.x * TILE + 40
	cam.limit_bottom = ROOM.y * TILE + 40

	# Punto 2: halo calido que lleva el heroe.
	_hero_light = _make_light(Color(1.0, 0.86, 0.66), 0.75, 1.5)
	_player.add_child(_hero_light)
	var pspr := _player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_add_actor(_player, 13.0, _foot_y(pspr), _hero_light)

	# Enemigos quietos: solo para ver sombras y luz sobre ellos.
	for i in ENEMIES.size():
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = load("res://assets/sprites/enemies/%s_sprite_frames.tres" % ENEMIES[i])
		spr.play("idle")
		spr.position = Vector2(180 + i * 170, 560 if i % 2 == 0 else 200)
		add_child(spr)
		_add_actor(spr, 15.0, _foot_y(spr, false), null)


## Pie del sprite: borde inferior del primer cuadro (local, o en coordenadas del padre).
func _foot_y(spr: AnimatedSprite2D, in_parent := true) -> float:
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, 0)
	var local := spr.offset.y + tex.get_height() * 0.5
	return spr.position.y + local * spr.scale.y if in_parent else local


## Punto 13: sombra de contacto bajo el actor + sombras alargadas, una por luz cercana.
func _add_actor(target: Node2D, radius: float, foot: float, own: PointLight2D) -> void:
	var foot_pos := Vector2(0, foot - 2.0)
	var contact := Sprite2D.new()
	contact.texture = _contact_tex
	contact.scale = Vector2(radius * 2.0 / 64.0, radius * 0.8 / 64.0)
	contact.position = foot_pos
	contact.show_behind_parent = true
	target.add_child(contact)
	var casts: Array[Sprite2D] = []
	for i in MAX_CAST:
		var s := Sprite2D.new()
		s.texture = _cast_tex
		s.centered = false
		s.offset = Vector2(0, -32)  # el borde izquierdo (centro del degradado) en los pies
		s.position = foot_pos
		s.show_behind_parent = true
		s.visible = false
		s.set_meta("width", radius * 1.5)
		target.add_child(s)
		casts.append(s)
	_actors.append({"node": target, "foot": foot_pos, "contact": contact, "casts": casts, "own": own})


## Cada luz cercana tira la sombra del actor hacia el lado contrario: mas larga y
## tenue cuanto mas lejos esta la luz. Si una columna tapa la luz, no hay sombra.
func _update_cast_shadows() -> void:
	var lights := _all_lights().filter(func(l): return l.enabled)
	var space := get_world_2d().direct_space_state
	for a in _actors:
		var node: Node2D = a.node
		var foot: Vector2 = node.global_position + a.foot
		var hits: Array = []
		if _dark() and blob_shadows:
			for l in lights:
				if l == a.own:
					continue
				var to_foot: Vector2 = foot - l.global_position
				var reach: float = 128.0 * l.texture_scale
				var dist := to_foot.length()
				if dist >= reach or dist < 1.0:
					continue
				var q := PhysicsRayQueryParameters2D.create(l.global_position, foot, 1)
				q.exclude = [_player.get_rid()]
				if not space.intersect_ray(q).is_empty():
					continue
				var k := 1.0 - dist / reach
				var strength: float = k * k * l.energy / float(l.get_meta("base_energy"))
				hits.append({"dir": to_foot / dist, "dist": dist, "reach": reach, "s": strength})
			hits.sort_custom(func(x, y): return x.s > y.s)
		var casts: Array = a.casts
		for i in casts.size():
			var s: Sprite2D = casts[i]
			if i >= hits.size():
				s.visible = false
				continue
			var h: Dictionary = hits[i]
			var length := lerpf(CAST_MIN_LEN, CAST_MAX_LEN, clampf(h.dist / h.reach, 0.0, 1.0))
			s.visible = true
			s.rotation = h.dir.angle()
			s.scale = Vector2(length / 64.0, float(s.get_meta("width")) / 64.0)
			s.modulate.a = clampf(h.s * CAST_ALPHA * 1.6, 0.0, CAST_ALPHA)
		var contact: Sprite2D = a.contact
		contact.visible = blob_shadows


# ------------------------------------------------------------------ antorchas
## Punto 3: antorchas en los muros con parpadeo y vaiven por ruido.
func _build_torches() -> void:
	var w := ROOM.x * TILE
	var h := ROOM.y * TILE
	var spots := [
		Vector2(w * 0.25, 6), Vector2(w * 0.75, 6),
		Vector2(w * 0.25, h - 6), Vector2(w * 0.75, h - 6),
		Vector2(6, h * 0.5), Vector2(w - 6, h * 0.5),
	]
	for p in spots:
		var flame := _make_flame()
		flame.position = p
		add_child(flame)
		_flames.append(flame)
		var l := _make_light(Color(1.0, 0.62, 0.30), 1.1, 1.4)
		# La luz sale un poco hacia la sala, no del muro mismo.
		var inward: Vector2 = (Vector2(w, h) * 0.5 - p).normalized() * 10.0
		l.position = p + inward
		l.set_meta("base_pos", l.position)
		add_child(l)
		_torches.append(l)


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
	# El fuego no se oscurece con el ambiente: emite.
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	fire.material = mat
	core.use_parent_material = true
	return root


func _make_light(color: Color, energy: float, scale_: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.texture_scale = scale_
	l.color = color
	l.energy = energy
	l.range_item_cull_mask = MASK_FLOOR | MASK_WALL
	l.shadow_item_cull_mask = MASK_FLOOR
	l.shadow_enabled = true
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF13
	l.shadow_filter_smooth = 6.0
	l.set_meta("base_energy", energy)
	l.set_meta("base_scale", scale_)
	l.set_meta("base_color", color)
	return l


# ------------------------------------------------------------------ fisica
## Faroles colgados del techo: un resorte amortiguado (pendulo visto desde arriba).
## El anclaje no se mueve; el farol y su luz se desplazan y la cadena los une.
func _build_hanging() -> void:
	for t in HANGING:
		var anchor: Vector2 = t * TILE
		var chain := Line2D.new()
		chain.width = 1.5
		chain.default_color = Color(0.15, 0.13, 0.12)
		chain.points = PackedVector2Array([anchor, anchor])
		add_child(chain)
		var lamp := _make_lamp_visual()
		lamp.position = anchor
		add_child(lamp)
		var l := _make_light(Color(1.0, 0.8, 0.5), 0.9, 1.1)
		lamp.add_child(l)
		_hanging.append({"anchor": anchor, "lamp": lamp, "chain": chain, "light": l, "off": Vector2.ZERO, "vel": Vector2.ZERO})


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


func _update_hanging(delta: float) -> void:
	var pv := (_player.position - _player_prev) / maxf(delta, 0.0001)
	for h in _hanging:
		var lamp_pos: Vector2 = h.anchor + h.off
		# Al pasar debajo, el jugador empuja el farol en su direccion de marcha.
		var d := lamp_pos.distance_to(_player.position)
		if d < 30.0 and pv.length() > 20.0:
			h.vel += pv * (1.0 - d / 30.0) * delta * 6.0
		# Brisa leve para que nunca quede del todo quieto.
		var wind := Vector2(_noise.get_noise_2d(_t * 0.4, h.anchor.x), _noise.get_noise_2d(_t * 0.4, h.anchor.y + 300.0)) * 18.0
		var acc: Vector2 = -h.off * PENDULUM_K - h.vel * PENDULUM_DAMP + wind
		h.vel += acc * delta
		h.off += h.vel * delta
		if h.off.length() > PENDULUM_MAX:
			h.off = h.off.limit_length(PENDULUM_MAX)
			h.vel *= 0.6
		var lamp: Node2D = h.lamp
		lamp.position = h.anchor + h.off
		lamp.rotation = h.vel.x * 0.004
		var chain: Line2D = h.chain
		chain.points = PackedVector2Array([h.anchor, lamp.position + Vector2(0, -6)])


## Cosas sueltas en el suelo: cuerpos rigidos con roce alto (vista cenital, sin gravedad).
## El jugador no choca con ellas: al pisarlas les da un impulso segun su velocidad.
func _spawn_props() -> void:
	for p in _props:
		p.queue_free()
	_props.clear()
	_prop_lights.clear()
	_actors = _actors.filter(func(a): return not (a.node is RigidBody2D))
	var kinds := ["piedra", "piedra", "piedra", "hueso", "hueso", "lata", "lata", "craneo", "piedra", "lata"]
	for i in kinds.size():
		var pos := Vector2(randf_range(1.5, ROOM.x - 1.5), randf_range(1.5, ROOM.y - 1.5)) * TILE
		_add_prop(kinds[i], pos)
	_add_prop("farol", Vector2(ROOM.x * 0.5 + 1.5, ROOM.y * 0.5) * TILE)


func _add_prop(kind: String, pos: Vector2) -> void:
	var body := RigidBody2D.new()
	body.collision_layer = PROP_LAYER
	body.collision_mask = 1 | PROP_LAYER
	body.gravity_scale = 0.0
	body.linear_damp = 3.0
	body.angular_damp = 3.0
	body.position = pos
	body.rotation = randf() * TAU
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.45
	mat.friction = 0.6
	body.physics_material_override = mat
	var shape := CollisionShape2D.new()
	var vis := Polygon2D.new()
	var radius := 5.0
	match kind:
		"piedra":
			radius = randf_range(3.5, 6.0)
			var pts := PackedVector2Array()
			for k in 7:
				pts.append(Vector2.from_angle(k * TAU / 7.0) * radius * randf_range(0.75, 1.1))
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
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	body.add_child(shape)
	if kind == "farol":
		var lamp := _make_lamp_visual()
		for c in lamp.get_children():
			c.reparent(body, false)
		lamp.free()
		vis.free()
		var l := _make_light(Color(1.0, 0.75, 0.45), 0.8, 0.8)
		body.add_child(l)
		_prop_lights.append(l)
	else:
		body.add_child(vis)
	add_child(body)
	_props.append(body)
	_add_actor(body, radius + 2.0, radius * 0.6, _prop_lights.back() if kind == "farol" else null)


func _kick_props(delta: float) -> void:
	var pv := (_player.position - _player_prev) / maxf(delta, 0.0001)
	var speed := pv.length()
	if speed < 30.0:
		return
	for b in _props:
		var d := b.position - (_player.position + Vector2(0, 10))
		var reach := 16.0
		if d.length() > reach:
			continue
		# Empuje en la direccion de marcha + un poco hacia fuera; el dash (rapido) las lanza.
		var dir := (pv.normalized() * 0.75 + d.normalized() * 0.25).normalized()
		var power := speed * (0.9 if speed < 300.0 else 1.6)
		b.apply_central_impulse(dir * power * b.mass * 0.6)
		b.apply_torque_impulse(randf_range(-1.0, 1.0) * power * 2.0)


## Para la captura: lanza cada objeto como si lo hubiera pateado el jugador.
func kick_all(power: float) -> void:
	for b in _props:
		b.apply_central_impulse(Vector2.from_angle(randf() * TAU) * power * b.mass)
		b.apply_torque_impulse(randf_range(-1.0, 1.0) * power * 3.0)
	for h in _hanging:
		h.vel += Vector2(power * 0.25, -power * 0.15)


# ------------------------------------------------------------------ ambiente
func _build_ambient() -> void:
	_ambient = CanvasModulate.new()
	add_child(_ambient)


func _process(delta: float) -> void:
	_t += delta
	# Parpadeo suave: dos capas de ruido lento + una rapida muy leve, filtradas para
	# que no tiemble a saltos. La luz tambien se mece unos pixeles (sombras vivas).
	var smooth := 1.0 - exp(-delta * 12.0)
	for i in _torches.size():
		var l := _torches[i]
		var slow := _noise.get_noise_2d(_t * 0.9, i * 37.0)
		var mid := _noise.get_noise_2d(_t * 2.3, i * 91.0)
		var fast := _noise.get_noise_2d(_t * 7.0, i * 13.0)
		var e: float = l.get_meta("base_energy") * (1.0 + slow * 0.18 + mid * 0.08 + fast * 0.03)
		l.energy = lerpf(l.energy, e, smooth)
		l.texture_scale = lerpf(l.texture_scale, l.get_meta("base_scale") * (1.0 + slow * 0.05), smooth)
		var sway := Vector2(_noise.get_noise_2d(_t * 1.4, i * 53.0), _noise.get_noise_2d(_t * 1.1, i * 71.0)) * Vector2(4.0, 2.5)
		l.position = l.position.lerp(l.get_meta("base_pos") + sway, smooth)
		var fire := _flames[i].get_node("Fire") as Node2D
		fire.scale = Vector2(1.0 + mid * 0.12, 1.0 + slow * 0.2 + fast * 0.06)
		fire.rotation = sway.x * 0.04
		fire.skew = mid * 0.15
	# Halo del heroe: respiracion leve.
	_hero_light.energy = _hero_light.get_meta("base_energy") * (1.0 + _noise.get_noise_2d(_t * 0.5, 500.0) * 0.06)
	_update_hanging(delta)
	_kick_props(delta)
	_player_prev = _player.position
	_update_cast_shadows()
	_fps_samples.append(Engine.get_frames_per_second())
	if _fps_samples.size() > 60:
		_fps_samples.pop_front()
	_update_label()


# ------------------------------------------------------------------ estados
## kingdom_idx recorre los pisos de la ruta (RunManager.route_size(); 2 etapas por reino, la Prostata 1); la penumbra va por reino y sube en la 2a etapa.
func _dark_chance() -> float:
	var f := kingdom_idx + 1
	return DARK_CHANCE[clampi(RunManager.region_index(f), 0, DARK_CHANCE.size() - 1)] + (RoomLighting.DEEP_DARK_BONUS if RunManager.floor_stage(f) > 1 else 0.0)


func _kingdom() -> Dictionary:
	return RunManager.floor_at(kingdom_idx + 1)


func _apply_all(animate: bool) -> void:
	var tint: Color = _kingdom().tint
	var dark := _dark()
	var floor_col := tint if colored else GREY_FLOOR
	var walls_col := tint.darkened(0.35) if colored else GREY_WALLS
	# Piso oscuro: el ambiente toma un poco del color del reino; censurado, frio.
	# Piso claro: sin oscuridad ni antorchas, solo la sombra de contacto.
	var amb := Color.WHITE
	if dark:
		amb = AMBIENT_FREE.lerp(tint.darkened(0.7), 0.3) if colored else AMBIENT_CENSORED
	var tw: Tween = null
	if animate:
		tw = create_tween().set_parallel()
	_put(tw, _floor, "modulate", floor_col)
	_put(tw, _walls, "modulate", walls_col)
	_put(tw, _ambient, "color", amb)
	for l in _torches:
		var base: Color = l.get_meta("base_color")
		var c := base.lerp(tint, 0.45) if colored else base.lerp(GREY_LIGHT, 0.85)
		_put(tw, l, "color", c)
		l.enabled = dark and torches_on
	for f in _flames:
		f.visible = dark and torches_on
	var hero: Color = _hero_light.get_meta("base_color")
	_put(tw, _hero_light, "color", hero.lerp(tint if colored else GREY_LIGHT, 0.25))
	_hero_light.enabled = dark
	for h in _hanging:
		h.light.enabled = dark
		h.lamp.visible = dark
		h.chain.visible = dark
		_put(tw, h.light, "color", Color(1.0, 0.8, 0.5).lerp(tint, 0.3) if colored else GREY_LIGHT)
	for l in _prop_lights:
		l.enabled = dark
		l.get_parent().get_node("Glow").visible = dark
	for l in _all_lights():
		l.shadow_enabled = cast_shadows


func _put(tw: Tween, obj: Object, prop: String, value) -> void:
	if tw:
		tw.tween_property(obj, prop, value, 1.2)
	else:
		obj.set(prop, value)


func _all_lights() -> Array[PointLight2D]:
	var out: Array[PointLight2D] = [_hero_light]
	out.append_array(_torches)
	for h in _hanging:
		out.append(h.light)
	out.append_array(_prop_lights)
	return out


## Punto 6: al liberar entra un destello calido con el color del reino.
func _liberate() -> void:
	colored = true
	if _dark():
		var flash := _make_light(_kingdom().tint.lerp(Color(1, 0.9, 0.7), 0.4), 0.0, 9.0)
		flash.shadow_enabled = false
		flash.position = _player.position
		add_child(flash)
		var tw := create_tween()
		tw.tween_property(flash, "energy", 1.3, 0.18)
		tw.tween_property(flash, "energy", 0.0, 1.1)
		tw.tween_callback(flash.queue_free)
	_apply_all(true)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1: lights_on = not lights_on
		KEY_2: kingdom_idx = (kingdom_idx + 1) % RunManager.route_size()
		KEY_3:
			if colored:
				colored = false
			else:
				_liberate()
				return
		KEY_4: cast_shadows = not cast_shadows
		KEY_5: blob_shadows = not blob_shadows
		KEY_6: torches_on = not torches_on
		KEY_7: room_dark = not room_dark
		KEY_N: room_dark = randf() < _dark_chance()
		KEY_R:
			_spawn_props()
			return
		KEY_F12:
			_shot(OS.get_user_data_dir().path_join("light_test_%d.png" % Time.get_ticks_msec()))
			return
		_: return
	_apply_all(false)


# ------------------------------------------------------------------ HUD y captura
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_color_override("font_color", Color(1, 1, 0.85))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	layer.add_child(_label)


func _update_label() -> void:
	var avg := 0.0
	for f in _fps_samples:
		avg += f
	avg /= maxf(_fps_samples.size(), 1)
	_label.text = "%s · %s · %s · %d fps\n1 luz:%s  2 reino  3 censura  4 sombras muros:%s  5 sombras personajes:%s  6 antorchas:%s  7 oscura/clara  N sortear (%d%%)  R objetos  F12 foto" % [
		_kingdom().name, "LIBERADA" if colored else "CENSURADA", "SALA OSCURA" if room_dark else "SALA CLARA", int(avg),
		_on(lights_on), _on(cast_shadows), _on(blob_shadows), _on(torches_on), int(_dark_chance() * 100)]


func _on(b: bool) -> String:
	return "si" if b else "no"


func _arg(prefix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""


func _shot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[luz] captura: ", path)


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _set_state(idx: int, col: bool) -> void:
	kingdom_idx = idx
	colored = col
	_apply_all(false)


## Saca una foto de cada estado para revisar sin jugar.
func _auto_capture(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	# Selva (oscuro), jugador entre la columna y una antorcha de abajo.
	_player.position = Vector2(ROOM.x * 0.75 + 0.6, ROOM.y - 3.2) * TILE
	_set_state(0, true)
	await _wait(30)
	_shot(dir.path_join("01_selva_oscuro_antorcha.png"))
	_player.position = Vector2(5.5, 4.5) * TILE
	await _wait(10)
	_shot(dir.path_join("02_selva_oscuro_columna.png"))
	_set_state(0, false)
	await _wait(5)
	_shot(dir.path_join("03_selva_censurada.png"))
	room_dark = false
	_set_state(2, true)  # Penelandia (indice de piso 0..9)
	await _wait(5)
	_shot(dir.path_join("04_penelandia_claro.png"))
	room_dark = true
	_set_state(6, true)  # El Perineo
	_player.position = Vector2(ROOM.x * 0.25, ROOM.y * 0.5) * TILE
	await _wait(10)
	_shot(dir.path_join("05_perineo_oscuro.png"))
	_set_state(0, true)
	_player.position = Vector2(ROOM.x * 0.5, ROOM.y * 0.5) * TILE
	await _wait(20)
	_shot(dir.path_join("06_faroles_quietos.png"))
	kick_all(260.0)
	await _wait(10)
	_shot(dir.path_join("07_faroles_pateados.png"))
	await _wait(40)
	_shot(dir.path_join("08_despues.png"))
	# Rendimiento: 3 s quieto con todo encendido.
	_fps_samples.clear()
	await get_tree().create_timer(3.0).timeout
	var avg := 0.0
	for f in _fps_samples:
		avg += f
	print("[luz] fps medio con todo: %.1f" % (avg / maxf(_fps_samples.size(), 1)))
	get_tree().quit()
