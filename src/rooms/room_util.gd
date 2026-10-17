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
	q.collision_mask = 1
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


static func coins(main: Node, room: Room, n: int, around: Vector2) -> void:
	for i in n:
		main._spawn_pickup(room, "coin", around + Vector2((i - (n - 1) / 2.0) * 26.0, 30.0 + (i % 2) * 14.0))


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
	p.amount = amount
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


## Enemigos vivos dentro de la sala (nodos del grupo "enemy").
static func enemies_in(room: Room) -> Array:
	var out: Array = []
	for e in room.get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e is Node2D and room.is_ancestor_of(e) and e.get("current_health") != null and e.current_health > 0.0 and not e.is_queued_for_deletion():
			out.append(e)
	return out
