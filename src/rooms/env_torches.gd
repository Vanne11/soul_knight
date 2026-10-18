extends RoomDynamic

## Antorchas que caen. Cada 8-13 s (antes en pisos hondos) una antorcha se suelta del techo:
## primero una SOMBRA en el suelo que crece durante 1,3 s (ahi caera: da tiempo de sobra
## para salirse o, mejor, para arrastrar a los enemigos encima), luego el golpe seco (dano en
## el centro) y el suelo arde 7 s: quema a quien este dentro, a ti tambien. Maximo 3 fuegos a la vez.
## Bot: los fuegos y las sombras estan en el grupo "rooms_hazard" (hazard_zones) y el bot los esquiva.

const WARN := 1.3
const FIRE_SECS := 7.0
const FIRE_R := 50.0
const MAX_FIRES := 3

var _next := 5.0
var _fires := 0
var _warned_once := false


func start() -> void:
	_next = 6.0
	add_to_group("rooms_hazard")
	toast(tr("RM_TORCHES_T"), tr("RM_TORCHES_D"), "ffa64a")
	say_intro("rm_torches")


func _process(delta: float) -> void:
	if not started or main.current_room != room or room.cleared:
		return
	_next -= delta
	if _next <= 0.0 and _fires < MAX_FIRES:
		_next = randf_range(8.0, 13.0) - minf(3.0, depth() * 0.6)
		_drop()


func _drop() -> void:
	var s := rsize()
	var pl := player()
	var enemies := RoomUtil.enemies_in(room)
	var pos := Vector2.INF
	for attempt in 6:
		var base: Vector2
		if not enemies.is_empty() and randf() < 0.6:
			base = enemies[randi() % enemies.size()].global_position - room.global_position
		elif pl != null:
			base = pl.global_position - room.global_position + Vector2(randf_range(-70, 70), randf_range(-70, 70))
		else:
			base = center()
		base = base.clamp(Vector2(120, 110), s - Vector2(120, 110))
		var q := RoomUtil.free_spot(main, room, base, FIRE_R * 0.5, false)
		if q != Vector2.INF and q.distance_to(base) < 50.0:
			pos = q
			break
	if pos == Vector2.INF:
		return
	_fires += 1
	var f := _Fall.new()
	f.dyn = self
	f.position = pos
	room.add_child(f)


func hazard_zones() -> Array:
	var out: Array = []
	for c in room.get_children():
		if c is _Fall and is_instance_valid(c):
			out.append({"c": c.global_position, "r": FIRE_R + 24.0, "ar": FIRE_R + 8.0,
					"kind": "fire", "active": true, "soon": 0.0})
	return out


func debug() -> String:
	return "torches fires=%d next=%.1f" % [_fires, _next]


## Una antorcha: sombra de aviso -> caida -> fuego.
class _Fall extends Node2D:
	var dyn
	var _t := 0.0
	var _phase := 0  # 0 aviso, 1 fuego
	var _hit_e := 0.0
	var _hit_p := 0.0
	var _flames: CPUParticles2D
	var _light: PointLight2D
	var _impacted := false

	func _ready() -> void:
		z_index = 1
		material = LightKit.unshaded_material()
		Sound.play("poor", 0.0)

	func _process(delta: float) -> void:
		_t += delta
		if _phase == 0:
			if _t >= dyn.WARN:
				_impact()
		else:
			var life: float = dyn.FIRE_SECS
			_burn(delta)
			if _t >= dyn.WARN + life:
				dyn._fires -= 1
				queue_free()
		queue_redraw()

	func _impact() -> void:
		_phase = 1
		Sound.play("crack", 0.1)
		HitFx.shake(0.25)
		var d: float = dyn.depth()
		for e in RoomUtil.enemies_in(dyn.room):
			if e.global_position.distance_to(global_position) <= 38.0:
				RoomUtil.hurt_enemy(e, 18.0 + 4.0 * d, global_position, 260.0, "calor")
		var pl: Node2D = dyn.player()
		if pl != null and pl.global_position.distance_to(global_position) <= 38.0:
			RoomUtil.hurt_player(pl, 0.6 * RoomUtil.std_hit(d))
		_flames = CPUParticles2D.new()
		_flames.amount = Settings.fx_amount(26)
		_flames.lifetime = 0.7
		_flames.gravity = Vector2(0, -60)
		_flames.initial_velocity_min = 10.0
		_flames.initial_velocity_max = 40.0
		_flames.direction = Vector2.UP
		_flames.spread = 40.0
		_flames.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		_flames.emission_sphere_radius = dyn.FIRE_R * 0.7
		_flames.scale_amount_min = 2.5
		_flames.scale_amount_max = 5.0
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1.0, 0.95, 0.5, 0.95), Color(1.0, 0.5, 0.15, 0.8), Color(0.4, 0.1, 0.05, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		_flames.color_ramp = g
		_flames.material = LightKit.unshaded_material()
		add_child(_flames)
		_light = ActorFx.add_glow(self, Color(1.0, 0.6, 0.25), 1.2, 1.4)

	func _burn(delta: float) -> void:
		_hit_e -= delta
		_hit_p -= delta
		var d: float = dyn.depth()
		if _hit_e <= 0.0:
			_hit_e = 0.5
			for e in RoomUtil.enemies_in(dyn.room):
				if e.global_position.distance_to(global_position) <= dyn.FIRE_R:
					RoomUtil.hurt_enemy(e, 4.0 + d, global_position, 0.0, "calor")
		var pl: Node2D = dyn.player()
		if _hit_p <= 0.0 and pl != null and pl.global_position.distance_to(global_position) <= dyn.FIRE_R:
			_hit_p = 0.8
			if RoomUtil.hurt_player(pl, 0.25 * RoomUtil.std_hit(d)):
				RoomUtil.popup(pl.global_position + Vector2(0, -34), "!", Color("ff9a3a"))

	func _draw() -> void:
		var r: float = dyn.FIRE_R
		if _phase == 0:
			var k := clampf(_t / dyn.WARN, 0.0, 1.0)
			# sombra que crece + borde que parpadea cada vez mas rapido
			draw_circle(Vector2.ZERO, r * k, Color(0.05, 0.02, 0.02, 0.35 + 0.25 * k))
			var blink := int(_t * (6.0 + 14.0 * k)) % 2 == 0
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.45, 0.15, 0.95 if blink else 0.45), 2.0)
			# la antorcha cae en el ultimo cuarto de segundo
			var fall := clampf((_t - (dyn.WARN - 0.28)) / 0.28, 0.0, 1.0)
			if fall > 0.0:
				var y := lerpf(-170.0, -6.0, fall * fall)
				draw_line(Vector2(0, y), Vector2(0, y + 18), Color(0.3, 0.2, 0.12), 3.0)
				draw_colored_polygon(PackedVector2Array([Vector2(0, y - 12), Vector2(5, y), Vector2(-5, y)]), Color(1.0, 0.7, 0.2))
		else:
			var left: float = float(dyn.FIRE_SECS) - (_t - float(dyn.WARN))
			var a := clampf(left / 1.5, 0.0, 1.0)
			draw_circle(Vector2.ZERO, r, Color(0.9, 0.35, 0.1, 0.18 * a))
			draw_circle(Vector2.ZERO, r * 0.6, Color(1.0, 0.55, 0.15, 0.16 * a))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1.0, 0.5, 0.15, 0.6 * a), 2.0)
			draw_line(Vector2(-10, 2), Vector2(10, -2), Color(0.25, 0.15, 0.1), 4.0)
