class_name UteroFolliculos
extends RoomDynamic

## Fase FOLICULAR del Utero: la sala florece. Folículos hinchados (bolas rosa con un brillo
## verde) repartidos por el suelo: un balazo los revienta y sueltan botin (monedas casi siempre,
## a veces vida). Son solidos como los barriles, pero no hacen dano: es botin a tiro, no un
## peligro. Los enemigos no los rompen (solo balas del jugador).

const TEX := "res://assets/sprites/utero/foliculo.png"
const HP := 12.0

var follicles: Array[Node] = []


func start() -> void:
	var s := rsize()
	var n := 5 + (1 if depth() >= 3.0 else 0)
	var taken: Array = []
	for sp in room.spawn_points:
		taken.append(sp - room.global_position)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([room.grid_pos.x, room.grid_pos.y, rm().current_floor, "foliculos"])
	var tries := 0
	while follicles.size() < n and tries < 60:
		tries += 1
		var p := Vector2(rng.randf_range(140.0, s.x - 140.0), rng.randf_range(130.0, s.y - 130.0))
		if taken.any(func(t): return t.distance_to(p) < 100.0):
			continue
		var q := RoomUtil.free_spot(main, room, p, 18.0, true, taken)
		if q == Vector2.INF or q.distance_to(p) > 60.0:
			continue
		taken.append(q)
		var f := _Foliculo.new()
		f.dyn = self
		f.position = q
		f.collision_layer = 1
		f.collision_mask = 0
		follicles.append(f)
		room.props_node.add_child.call_deferred(f)


func pop(local_pos: Vector2) -> void:
	var gpos := room.global_position + local_pos
	Sound.play("pickup")
	RoomUtil.burst(room, gpos, Color(1.0, 0.7, 0.85), 18)
	RoomUtil.burst(room, gpos, Color(0.7, 1.0, 0.55), 8)
	RoomUtil.popup(gpos + Vector2(0, -26), tr("UTERO_FOLI_POP"), Color("9be86a"))
	for p in RoomUtil.loot_spots(room, 2, local_pos):
		main._spawn_pickup(room, "coin", p)
	if randf() < 0.18:
		main._spawn_pickup(room, "health_small", local_pos + Vector2(0, 22))


## Folículo: cuerpo solido en la capa 1 que revienta a balazos.
class _Foliculo extends StaticBody2D:
	var dyn
	var hp := UteroFolliculos.HP
	var _spr: Sprite2D
	var _t := 0.0
	var _flash := 0.0
	var _ph := randf() * TAU

	func _ready() -> void:
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(22, 14)
		cs.shape = rs
		cs.position = Vector2(0, -7)
		add_child(cs)
		_spr = Sprite2D.new()
		_spr.centered = false
		if ResourceLoader.exists(UteroFolliculos.TEX):
			var tex: Texture2D = load(UteroFolliculos.TEX)
			_spr.texture = tex
			_spr.position = Vector2(-tex.get_width() * 0.5, -tex.get_height() + 3)
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_spr)
		LightKit.add_contact_shadow(self, 14.0, 2.0)
		ActorFx.add_glow(self, Color(0.75, 1.0, 0.6), 0.5, 0.5).position = Vector2(0, -14)

	func _process(delta: float) -> void:
		_t += delta
		_flash = maxf(0.0, _flash - delta * 5.0)
		var k := 1.0 + 0.06 * sin(_t * 2.6 + _ph)  # late, hinchado
		_spr.scale = Vector2(k, 1.0 / k)
		_spr.modulate = Color.WHITE.lerp(Color(2.2, 2.0, 2.0), _flash)

	func hit_by_bullet(damage: float, _dir: Vector2) -> void:
		hp -= damage
		_flash = 1.0
		if hp <= 0.0:
			collision_layer = 0
			dyn.follicles.erase(self)
			dyn.pop(position)
			queue_free()
		else:
			Sound.play("enemy_hit")
