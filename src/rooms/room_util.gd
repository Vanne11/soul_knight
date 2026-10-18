class_name RoomUtil
extends RefCounted

## Ayudas comunes de las dinamicas de sala (src/rooms/). Todo en coordenadas LOCALES de la
## sala salvo que se diga global. Lo que crea cuerpos o areas debe anadirse con
## add_child.call_deferred: las salas se entran desde un callback de fisica y Godot no deja
## cambiar el estado ahi.

const TILE := 64.0
const GOLD := Color("ffd75a")
const PINK := Color("ff7ac0")
const GREY := Color("b8b8c8")


## Golpe estandar de un enemigo comun a esta profundidad (el que usa main._generate_enemy_data_for_room).
## El dano de los peligros de sala se calibra como fraccion de esto: la vida base es 25.
static func std_hit(d: float) -> float:
	return 6.0 + 3.0 * d


static func main_of(tree: SceneTree) -> Node:
	return tree.get_first_node_in_group("main") if tree else null


static func size_of(room: Room) -> Vector2:
	return Vector2(room.floor_tilemap.get_used_rect().size) * TILE


## Cuanto mide la sala en baldosas (para filtrar dinamicas que necesitan sitio).
static func tiles_of(room: Room) -> Vector2i:
	return room.floor_tilemap.get_used_rect().size


## Por donde se entra: {door, pos (puerta), inward (hacia dentro), entry (donde aparece el jugador)}.
static func entries(room: Room) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for door: Door in room.doors.values():
		var inward := Vector2.DOWN
		match door.get_direction_name():
			"up": inward = Vector2.DOWN
			"down": inward = Vector2.UP
			"left": inward = Vector2.RIGHT
			"right": inward = Vector2.LEFT
		out.append({"door": door, "pos": door.position, "inward": inward, "entry": door.position + inward * 96.0})
	return out


## Sitio libre (sin muros ni obstaculos ni lo que ya hay) cerca de `prefer`, o Vector2.INF si
## no hay ninguno. `avoid_entries`: se aleja de donde aparece el jugador.
static func free_spot(main: Node, room: Room, prefer: Vector2, radius := 22.0, avoid_entries := true, taken: Array = []) -> Vector2:
	var space: PhysicsDirectSpaceState2D = main.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.collision_mask = 65  # muros + huecos
	var size := size_of(room)
	var avoid: Array[Vector2] = []
	for t in taken:
		avoid.append(t)
	for holder in [room.pickups_node, room.props_node]:
		for c in holder.get_children():
			if c is Node2D:
				avoid.append(c.position)
	if avoid_entries:
		for e in entries(room):
			avoid.append(e.entry)
	for r in [0.0, 40.0, 80.0, 120.0, 170.0, 230.0]:
		for i in 12:
			var p: Vector2 = prefer + Vector2(r, 0).rotated(TAU * i / 12.0)
			if p.x < 100.0 or p.y < 100.0 or p.x > size.x - 100.0 or p.y > size.y - 100.0:
				continue
			if avoid.any(func(t): return t.distance_to(p) < 70.0):
				continue
			q.transform = Transform2D(0.0, room.global_position + p)
			if space.intersect_shape(q, 1).is_empty():
				return p
	return Vector2.INF


## true si el segmento a-b (locales) no choca con muros ni obstaculos.
static func line_clear(main: Node, room: Room, a: Vector2, b: Vector2, mask := 1) -> bool:
	var q := PhysicsRayQueryParameters2D.create(room.global_position + a, room.global_position + b, mask)
	return main.get_world_2d().direct_space_state.intersect_ray(q).is_empty()


static func popup(pos_global: Vector2, text: String, color := GOLD) -> void:
	(Engine.get_main_loop() as SceneTree).root.get_node("GlobalEvents").show_floating_text.emit(pos_global, text, color)


## Monedas en abanico compacto alrededor de `around` (locales), siempre en suelo pisable.
static func coins(main: Node, room: Room, n: int, around: Vector2) -> void:
	for p in loot_spots(room, n, around):
		main._spawn_pickup(room, "coin", p)


# ---------------------------------------------------------------- botin accesible
const LOOT_R := 16.0  # holgura de un objeto en el suelo
const LOOT_EDGE := 76.0  # distancia minima al borde de la sala (los muros van dentro del rectangulo)


## La sala a la que pertenece un nodo (o null).
static func room_of(n: Node) -> Room:
	while n != null:
		if n is Room:
			return n
		n = n.get_parent()
	return null


## true si en `p` (local) cabe un objeto: dentro de la sala, en suelo pisable y, si se pasa
## `space`, sin muros, obstaculos ni huecos encima (consulta fisica).
static func loot_ok(room: Room, p: Vector2, space: PhysicsDirectSpaceState2D = null) -> bool:
	var size := size_of(room)
	if p.x < LOOT_EDGE or p.y < LOOT_EDGE or p.x > size.x - LOOT_EDGE or p.y > size.y - LOOT_EDGE:
		return false
	if not room.is_walkable(p, LOOT_R):
		return false
	if space != null:
		var shape := CircleShape2D.new()
		shape.radius = LOOT_R
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = shape
		q.collision_mask = 65  # muros y obstaculos + huecos
		q.transform = Transform2D(0.0, room.global_position + p)
		if not space.intersect_shape(q, 1).is_empty():
			return false
	return true


## El sitio valido mas cercano a `prefer` (locales), a `gap` o mas de lo ya `taken`. Sin `space`
## solo mira la forma de la sala (seguro en cualquier momento); con `space`, tambien la fisica
## (solo fuera de un callback de fisica). Si no hay ninguno, el punto pisable mas cercano.
static func loot_spot(room: Room, prefer: Vector2, taken: Array = [], space: PhysicsDirectSpaceState2D = null, gap := 20.0) -> Vector2:
	for ri in 18:
		var r := ri * 22.0
		var steps := 1 if ri == 0 else mini(int(TAU * r / 22.0), 36)
		for i in steps:
			var p: Vector2 = prefer + Vector2(r, 0).rotated(TAU * i / steps + ri * 0.7)
			if not loot_ok(room, p, space):
				continue
			if taken.any(func(t): return t.distance_to(p) < gap):
				continue
			return p
	return room.nearest_walkable(prefer, LOOT_R)


## `n` sitios en espiral compacta alrededor de `center` (en vez de filas largas que se
## meten en muros), todos validos y separados. Evita lo que ya hay en el suelo de la sala.
static func loot_spots(room: Room, n: int, center: Vector2, space: PhysicsDirectSpaceState2D = null, spacing := 24.0) -> Array[Vector2]:
	var taken: Array = []
	for c in room.pickups_node.get_children():
		if c is Node2D:
			taken.append(c.position)
	var origin := loot_spot(room, center, taken, space, spacing)
	var out: Array[Vector2] = []
	for i in n:
		var ideal := origin + Vector2.from_angle(i * 2.39996) * spacing * sqrt(float(i))
		var p := loot_spot(room, ideal, taken, space, spacing * 0.8)
		taken.append(p)
		out.append(p)
	return out


## Posicion local de un drop en `container` (la sala o su pickups_node) llevada a suelo pisable.
static func snap_drop(container: Node, local_pos: Vector2) -> Vector2:
	var room := room_of(container)
	return local_pos if room == null else loot_spot(room, local_pos)


## Red de seguridad de un objeto o cofre recien puesto: si nacio sobre algo solido o fuera del
## suelo, se desliza al sitio libre mas cercano. Lo llaman item_pickup y chest desde _ready.
static func settle(node: Node2D) -> void:
	var room := room_of(node)
	if room == null or not node.is_inside_tree():
		return
	await node.get_tree().physics_frame
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var space: PhysicsDirectSpaceState2D = room.get_world_2d().direct_space_state
	var offset: Vector2 = node.position - room.to_local(node.global_position)
	var here: Vector2 = node.position - offset
	if loot_ok(room, here, space):
		return
	var taken: Array = []
	for c in node.get_parent().get_children():
		if c is Node2D and c != node:
			taken.append(c.get_meta("settle_to", c.position) - offset)
	var to := loot_spot(room, here, taken, space, 18.0)
	if to.distance_to(here) < 1.0:
		return
	node.set_meta("settle_to", to + offset)
	node.create_tween().tween_property(node, "position", to + offset, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Enemigos nuevos para esta sala con los datos normales del piso (vida/dano por profundidad).
## Devuelve los que acaba de crear. Sella la puerta si `seal`. `upgrade` (opcional) retoca
## cada diccionario de datos antes de crearlos.
static func spawn_wave(main: Node, room: Room, n: int, seal := true, upgrade := Callable()) -> Array:
	var data: Array = main._generate_enemy_data_for_room(room)
	var typed: Array[Dictionary] = []
	for i in mini(n, data.size()):
		var d: Dictionary = data[i]
		if upgrade.is_valid():
			upgrade.call(d)
		typed.append(d)
	ensure_spawn_points(room)
	var before := room.enemies_spawned.size()
	room.spawn_enemies(typed, seal)
	return room.enemies_spawned.slice(before)


static func ensure_spawn_points(room: Room) -> void:
	if not room.spawn_points.is_empty():
		return
	var c := room.global_position + room.get_center_position()
	for i in 4:
		room.spawn_points.append(c + Vector2(110, 0).rotated(TAU * i / 4.0 + 0.4))


static func alive(room: Room) -> Array:
	return room.enemies_spawned.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion() and e.get("current_health") != null and e.current_health > 0.0)


static func burst(parent: Node, pos_global: Vector2, color: Color, amount := 16) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = Settings.fx_amount(amount)
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 140.0
	p.damping_min = 80.0
	p.damping_max = 120.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	p.z_index = 4
	p.material = LightKit.unshaded_material()
	parent.add_child.call_deferred(p)
	p.set_deferred("global_position", pos_global)
	parent.get_tree().create_timer(1.3).timeout.connect(p.queue_free)


## Dano al jugador con las reglas normales (el dash y la invulnerabilidad lo esquivan).
static func hurt_player(pl: Node, dmg: float) -> bool:
	if pl != null and pl.has_method("receive_hit"):
		var hit: bool = pl.receive_hit(dmg)
		if hit:
			var st := get_stack()
			print("[salas] dano de peligro %.1f (%s)" % [dmg, str(st[1].source).get_file() if st.size() > 1 else "?"])
		return hit
	return false


## Dano a un enemigo con empujon (kb en px/s hacia fuera de `from_global`).
static func hurt_enemy(e: Node, dmg: float, from_global: Vector2, kb := 0.0) -> void:
	if not is_instance_valid(e) or not e.has_method("take_damage") or e.get("current_health") == null or e.current_health <= 0.0:
		return
	var away: Vector2 = e.global_position - from_global
	away = away.normalized() if away.length() > 1.0 else Vector2.RIGHT.rotated(randf() * TAU)
	# el jugador figura como autor: main solo comprueba si la sala se limpio con muertes suyas
	e.take_damage(dmg, e.get_tree().get_first_node_in_group("player"), away * kb)


static var _hz_frame := -1
static var _hz_cache: Array = []


## Zonas peligrosas de las dinamicas de sala vivas (grupo "rooms_hazard"): pinchos, cera, fuego de
## antorchas, barriles a punto de estallar, sombra de las jaulas. Cada una es
## {c: centro global, r: radio generoso (bot), ar: radio ajustado (IA enemiga), kind: "spike" |
##  "vent" | "puddle" | "fire" | "barrel" | "cage", active: peligrosa ahora o ya avisando,
##  soon: segundos hasta que se active (0 si ya lo esta)}. Se calcula una vez por fisica.
static func hazard_zones(tree: SceneTree) -> Array:
	var f := Engine.get_physics_frames()
	if f == _hz_frame:
		return _hz_cache
	_hz_frame = f
	_hz_cache = []
	for n in tree.get_nodes_in_group("rooms_hazard"):
		if is_instance_valid(n) and n.has_method("hazard_zones"):
			_hz_cache.append_array(n.hazard_zones())
	return _hz_cache


## Primera zona peligrosa que contiene `pos` (con `margin` extra de radio), activa o que se activara
## en menos de `horizon` segundos. {} si no hay.
static func hazard_at(tree: SceneTree, pos: Vector2, margin := 0.0, horizon := 0.0) -> Dictionary:
	for z in hazard_zones(tree):
		if (z.active or float(z.soon) <= horizon) and pos.distance_to(z.c) <= float(z.get("ar", z.r)) + margin:
			return z
	return {}


## Enemigos vivos dentro de la sala (nodos del grupo "enemy").
static func enemies_in(room: Room) -> Array:
	var out: Array = []
	for e in room.get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e is Node2D and room.is_ancestor_of(e) and e.get("current_health") != null and e.current_health > 0.0 and not e.is_queued_for_deletion():
			out.append(e)
	return out
