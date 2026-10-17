extends RoomDynamic

## Barriles explosivos (combate con el entorno). Rojizos, con un triangulo de aviso que late.
## Un balazo (el tuyo; los enemigos no los rompen) enciende la mecha: 0,55 s parpadeando y
## revientan en radio de 96 px, dano a enemigos Y a ti (el dash lo esquiva), empujon fuerte
## y reaccion en cadena con otros barriles cercanos. Esta pensado para que atraigas a los
## enemigos y dispares en el momento justo, o para que no dispares con ellos pegados a ti.
## Sin recompensa propia: su premio es la pelea mas corta.

const RADIUS := 96.0
const FUSE := 0.55
const HP := 10.0
const KINGDOM_DIR := "res://assets/sprites/environment/obstacles/%s/barrel.png"

var barrels: Array[Node] = []


func start() -> void:
	var s := rsize()
	var n := 3 + (1 if depth() >= 3.0 else 0)
	var taken: Array = []
	for sp in room.spawn_points:
		taken.append(sp - room.global_position)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([room.grid_pos.x, room.grid_pos.y, rm().current_floor, "barrels"])
	var tries := 0
	while barrels.size() < n and tries < 40:
		tries += 1
		var p := Vector2(rng.randf_range(150.0, s.x - 150.0), rng.randf_range(130.0, s.y - 130.0))
		if taken.any(func(t): return t.distance_to(p) < 110.0):
			continue
		var q := RoomUtil.free_spot(main, room, p, 18.0, true, taken)
		if q == Vector2.INF or q.distance_to(p) > 60.0:
			continue
		taken.append(q)
		_add(q)
	if not barrels.is_empty():
		say_intro("rm_barrels")
		toast(tr("RM_BARRELS_T"), tr("RM_BARRELS_D"), "ff8a5a")


func _add(pos: Vector2) -> void:
	var b := _Barrel.new()
	b.dyn = self
	b.position = pos
	b.collision_layer = 1
	b.collision_mask = 0
	barrels.append(b)
	room.props_node.add_child.call_deferred(b)


func explode_at(local_pos: Vector2, source: Node) -> void:
	var gpos := room.global_position + local_pos
	var fx := ExplosionFx.new()
	fx.radius = RADIUS
	room.add_child(fx)
	fx.global_position = gpos
	HitFx.shake(0.45)
	Sound.play("crack", 0.15)
	var d := depth()
	for e in RoomUtil.enemies_in(room):
		if e.global_position.distance_to(gpos) <= RADIUS + 14.0:
			RoomUtil.hurt_enemy(e, 38.0 + 10.0 * d, gpos, 520.0)
	var pl := player()
	if pl != null and pl.global_position.distance_to(gpos) <= RADIUS:
		if RoomUtil.hurt_player(pl, 1.1 * RoomUtil.std_hit(d)):
			RoomUtil.popup(pl.global_position + Vector2(0, -34), "BOOM", Color("ff8a5a"))
	# cadena: otros barriles y objetos rompibles cerca
	for other in barrels:
		if other != source and is_instance_valid(other) and other.global_position.distance_to(gpos) <= RADIUS + 10.0:
			other.call("ignite", 0.2)
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, gpos)
	q.collision_mask = 1
	for r in main.get_world_2d().direct_space_state.intersect_shape(q, 24):
		var c = r.collider
		if c is Node and c != source and not (c in barrels) and c.has_method("hit_by_bullet"):
			c.hit_by_bullet(60.0, (c.global_position - gpos).normalized())
	# marca de quemado en el suelo
	var scorch := _Scorch.new()
	scorch.position = local_pos
	floor_layer().add_child(scorch)


## Barril explosivo (cuerpo solido en la capa 1, como los de RoomObstacles).
class _Barrel extends StaticBody2D:
	var dyn
	var hp: float = 10.0
	var lit := false
	var _t := 0.0
	var _fuse := 0.0
	var _spr: Sprite2D
	var _warn: Node2D

	func _ready() -> void:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(22, 14)
		cs.shape = rs
		cs.position = Vector2(0, -7)
		add_child(cs)
		var tex_path: String = "res://assets/sprites/environment/obstacles/%s/barrel.png" % str(dyn.rm().floor_data().get("kingdom", "neutral"))
		if not ResourceLoader.exists(tex_path):
			tex_path = "res://assets/sprites/environment/obstacles/neutral/barrel.png"
		var tex: Texture2D = load(tex_path)
		_spr = Sprite2D.new()
		_spr.texture = tex
		_spr.centered = false
		_spr.position = Vector2(-tex.get_width() * 0.5, -tex.get_height() + 3)
		_spr.modulate = Color(1.0, 0.55, 0.5)
		add_child(_spr)
		LightKit.add_contact_shadow(self, 16.0, 2.0)
		LightKit.mark_caster(self, 12.0, 2.0)
		_warn = _Warn.new()
		_warn.position = Vector2(0, -tex.get_height() - 8)
		add_child(_warn)
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-11, -14), Vector2(11, -14), Vector2(11, 0), Vector2(-11, 0)])
		occ.occluder = poly
		add_child(occ)
		ActorFx.add_glow(self, Color(1.0, 0.5, 0.3), 0.5, 0.5).position = Vector2(0, -10)

	func hit_by_bullet(damage: float, _dir: Vector2) -> void:
		if lit:
			return
		hp -= damage
		_spr.modulate = Color(2.0, 1.4, 1.2)
		if hp <= 0.0:
			ignite(FUSE)
		else:
			Sound.play("enemy_hit")

	func ignite(secs: float) -> void:
		if lit:
			return
		lit = true
		_fuse = secs
		Sound.play("enemy_hit")

	func _process(delta: float) -> void:
		_t += delta
		if lit:
			_fuse -= delta
			var fast := 10.0 + (1.0 - clampf(_fuse / 0.55, 0.0, 1.0)) * 22.0
			_spr.modulate = Color(2.4, 2.4, 2.2) if int(_t * fast) % 2 == 0 else Color(1.0, 0.25, 0.2)
			if _fuse <= 0.0:
				_boom()
		elif _spr.modulate != Color(1.0, 0.55, 0.5):
			_spr.modulate = _spr.modulate.lerp(Color(1.0, 0.55, 0.5), clampf(delta * 8.0, 0.0, 1.0))

	func _boom() -> void:
		set_process(false)
		collision_layer = 0
		remove_from_group(LightKit.GROUP_CASTER)
		dyn.explode_at(position, self)
		dyn.barrels.erase(self)
		queue_free()


## Triangulo de aviso sobre el barril.
class _Warn extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		material = LightKit.unshaded_material()

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var k := 0.5 + 0.5 * sin(_t * 5.0)
		var c := Color(1.0, 0.8 - 0.4 * k, 0.2, 0.9)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(7, 5), Vector2(-7, 5)]), c)
		draw_rect(Rect2(-1, -3, 2, 5), Color(0.1, 0.05, 0.05))
		draw_rect(Rect2(-1, 3, 2, 1.5), Color(0.1, 0.05, 0.05))


## Marca de quemadura que se desvanece despacio.
class _Scorch extends Node2D:
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		if _t > 25.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := 0.42 * (1.0 - clampf(_t / 25.0, 0.0, 1.0))
		draw_circle(Vector2.ZERO, 46.0, Color(0.05, 0.03, 0.03, a * 0.6))
		draw_circle(Vector2.ZERO, 30.0, Color(0.03, 0.02, 0.02, a))
