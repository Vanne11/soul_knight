extends RoomDynamic

## Trampas de verdad en las salas trampa (Room.RoomType.TRAP). Tres peligros, todos con AVISO
## legible y escalados con RunManager.depth():
##
##  PINCHOS (los decorativos de room_obstacles, ahora vivos): la placa tiembla y se ilumina
##    de rojo ~0,9 s con un tic de sonido, sube 0,7 s (dano a quien este encima) y se esconde.
##    Cada placa lleva su propio ritmo (periodo 3,8 s en el piso 1, 2,4 s en lo hondo).
##  CERA CALIENTE (desde el piso 1, 1-3 respiraderos): el respiradero borbotea y marca con un
##    anillo donde va a salpicar (~1,1 s), escupe un chorro (dano) y deja un CHARCO de cera
##    7-9 s que ralentiza un 40% y quema a ratos, a ti y a los enemigos.
##  VENTILADORES (desde el piso 3, 1-2): se ponen en marcha ~1,2 s (aspas cada vez mas rapidas,
##    rayas de viento) y soplan 2,6 s empujando al jugador, a los enemigos, a los proyectiles
##    y a los objetos con fisica. Se colocan para barrer pinchos o cera: empuja a los enemigos ahi.
##
## Combate con el entorno: los tres hacen dano a los enemigos igual que a ti (el dash te
## salva, a ellos no), asi que atraerlos, disparar para empujarlos (el retroceso de las balas)
## o dejar que el viento los lleve es una estrategia. Los pinchos y el fuego dan la muerte
## a nombre del jugador (cuenta para limpiar la sala).
## Bot: todos estan en el grupo "rooms_hazard" (hazard_zones()); el bot esquiva los peligros
## activos o por activarse y, con modo dios, ni lo nota.

const PUSH_PLAYER := 150.0
const PUSH_ENEMY := 210.0
const PUSH_PROJ := 150.0
const SLOW := 0.4

var spikes: Array[Node2D] = []
var vents: Array[Node2D] = []
var fans: Array[Node2D] = []
var puddles: Array[Node2D] = []
var warn_mult := 1.0


func hazard_zones() -> Array:
	var out: Array = []
	for sp in spikes:
		if is_instance_valid(sp):
			out.append({"c": sp.global_position + sp.rect.size * 0.5 - sp.position, "r": sp.rect.size.length() * 0.5 + 18.0})
	for v in vents:
		if is_instance_valid(v):
			out.append({"c": v.global_position, "r": 62.0})
	for p in puddles:
		if is_instance_valid(p):
			out.append({"c": p.global_position, "r": p.radius + 12.0})
	return out


func debug() -> String:
	var fi := ""
	for f in fans:
		fi += " fan(pos=%s dir=%s len=%d estado=%s)" % [f.position, f.dir, f.length, f._state]
	return "trampas spikes=%d vents=%d fans=%d puddles=%d%s" % [spikes.size(), vents.size(), fans.size(), puddles.size(), fi]


func start() -> void:
	add_to_group("rooms_hazard")
	var d := depth()
	warn_mult = 1.25 if d < 2.0 else 1.0
	_build_spikes(d)
	_build_vents(d)
	if d >= 2.0:
		_build_fans(d)
	say_intro("rm_traps")
	toast(tr("RM_TRAPS_T"), tr("RM_TRAPS_D"), "ffa64a")


# ------------------------------------------------------------------ pinchos
func _build_spikes(d: float) -> void:
	var rects: Array[Rect2] = []
	var obs: Node = room.get_meta("obstacles", null)
	if obs != null:
		for r in obs._flat:
			rects.append(r)
		# los pinchos decorativos de room_obstacles ceden su dibujo a las placas vivas
		for spr in obs._flat_node.get_children():
			if spr is Sprite2D and rects.any(func(r): return r.grow(4.0).has_point(spr.position)):
				spr.visible = false
	if rects.size() < 2:
		for i in 2 - rects.size():
			var q := RoomUtil.free_spot(main, room, center() + Vector2(110 if i == 0 else -110, 70), 30.0)
			if q != Vector2.INF:
				rects.append(Rect2(q - Vector2(28, 28), Vector2(56, 56)))
	var period := clampf(3.8 - 0.28 * d, 2.3, 3.8)
	for i in rects.size():
		var sp := _Spikes.new()
		sp.dyn = self
		sp.rect = rects[i]
		sp.position = rects[i].position
		sp.period = period
		sp.t = fmod(float(i) * 0.9 + period * 0.3, period)
		sp.material = LightKit.unshaded_material()
		spikes.append(sp)
		floor_layer().add_child(sp)


# ------------------------------------------------------------------ cera
func _build_vents(d: float) -> void:
	var n := 1 if d < 2.0 else (2 if d < 4.0 else 3)
	var s := rsize()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([room.grid_pos.x, room.grid_pos.y, rm().current_floor, "vents"])
	var taken: Array[Vector2] = []
	for sp in spikes:
		taken.append(sp.position + sp.rect.size * 0.5)
	for t in room.spawn_points:
		taken.append(t - room.global_position)
	var tries := 0
	while vents.size() < n and tries < 120:
		tries += 1
		var p := Vector2(rng.randf_range(150.0, s.x - 150.0), rng.randf_range(130.0, s.y - 130.0))
		if taken.any(func(t): return t.distance_to(p) < 85.0):
			continue
		var q := RoomUtil.free_spot(main, room, p, 24.0, true, taken)
		if q == Vector2.INF or q.distance_to(p) > 60.0 or RoomUtil.entries(room).any(func(e): return e.entry.distance_to(q) < 120.0):
			continue
		taken.append(q)
		var v := _Vent.new()
		v.dyn = self
		v.position = q
		v.period = clampf(4.8 - 0.3 * d, 3.2, 4.8)
		v.t = rng.randf() * v.period
		v.material = LightKit.unshaded_material()
		vents.append(v)
		floor_layer().add_child(v)


func add_puddle(local_pos: Vector2) -> void:
	for p in puddles:
		if is_instance_valid(p) and p.position.distance_to(local_pos) < 20.0:
			p.renew()
			return
	var pd := _Puddle.new()
	pd.dyn = self
	pd.position = local_pos
	pd.life = 7.0 + depth() * 0.5
	pd.material = LightKit.unshaded_material()
	puddles.append(pd)
	floor_layer().add_child(pd)


# ------------------------------------------------------------------ ventiladores
func _build_fans(d: float) -> void:
	var n := 1 if d < 4.0 else 2
	var s := rsize()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([room.grid_pos.x, room.grid_pos.y, rm().current_floor, "fans"])
	var cands: Array[Dictionary] = []
	var WALL := 66.0
	for side in 4:
		var dir := [Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT][side] as Vector2
		var steps := 5
		for k in steps:
			var f := (k + 1.0) / (steps + 1.0)
			var pos: Vector2
			match side:
				0: pos = Vector2(s.x * f, WALL)
				1: pos = Vector2(s.x * f, s.y - WALL)
				2: pos = Vector2(WALL, s.y * f)
				_: pos = Vector2(s.x - WALL, s.y * f)
			cands.append({"pos": pos, "dir": dir})
	var ent := RoomUtil.entries(room)
	var scored: Array[Dictionary] = []
	for c in cands:
		var pos: Vector2 = c.pos
		if ent.any(func(e): return e.pos.distance_to(pos) < 130.0):
			continue
		var length := minf((s.y - 2.0 * WALL) if absf(c.dir.y) > 0.5 else (s.x - 2.0 * WALL), 360.0)
		var zone := _fan_rect(pos, c.dir, length)
		var score := 0.0
		for sp in spikes:
			if zone.intersects(Rect2(sp.position, sp.rect.size)):
				score += 2.0
		for v in vents:
			if zone.has_point(v.position):
				score += 1.5
		scored.append({"pos": pos, "dir": c.dir, "len": length, "score": score + rng.randf() * 0.5})
	scored.sort_custom(func(a, b): return a.score > b.score)
	for c in scored:
		if fans.size() >= n:
			break
		if fans.any(func(f): return f.position.distance_to(c.pos) < 200.0):
			continue
		var f := _Fan.new()
		f.dyn = self
		f.position = c.pos
		f.dir = c.dir
		f.length = c.len
		f.period = clampf(7.0 - 0.45 * depth(), 4.6, 7.0)
		f.t = rng.randf() * f.period * 0.5
		f.material = LightKit.unshaded_material()
		fans.append(f)
		room.add_child(f)


func _fan_rect(pos: Vector2, dir: Vector2, length: float) -> Rect2:
	var w := 130.0
	if absf(dir.x) > 0.5:
		return Rect2(Vector2(pos.x if dir.x > 0.0 else pos.x - length, pos.y - w * 0.5), Vector2(length, w))
	return Rect2(Vector2(pos.x - w * 0.5, pos.y if dir.y > 0.0 else pos.y - length), Vector2(w, length))


# ------------------------------------------------------------------ efectos que actuan sobre los cuerpos
func _physics_process(delta: float) -> void:
	if not started or main.current_room != room or room.cleared:
		return
	var pl := player() as CharacterBody2D
	var enemies := RoomUtil.enemies_in(room)
	# cera: ralentiza (y las llamas de _Puddle queman)
	for pd in puddles:
		if not is_instance_valid(pd):
			continue
		var g: Vector2 = pd.global_position
		var r: float = pd.radius
		if pl != null and not pl.is_dashing and pl.global_position.distance_to(g) <= r:
			pl.move_and_collide(-pl.velocity * SLOW * delta)
		for e in enemies:
			if e is CharacterBody2D and e.global_position.distance_to(g) <= r:
				(e as CharacterBody2D).move_and_collide(-(e as CharacterBody2D).velocity * SLOW * delta)
	# viento
	for f in fans:
		if not is_instance_valid(f) or f.strength() <= 0.01:
			continue
		var k: float = f.strength()
		var zone: Rect2 = _fan_rect(f.global_position, f.dir, f.length)
		var push: Vector2 = f.dir * k
		if pl != null and not pl.is_dashing and zone.has_point(pl.global_position):
			pl.move_and_collide(push * PUSH_PLAYER * delta)
		for e in enemies:
			if e is CharacterBody2D and not e.is_in_group("boss") and zone.has_point(e.global_position):
				(e as CharacterBody2D).move_and_collide(push * PUSH_ENEMY * delta)
				PitFall.launch(e, 0.15)  # el viento puede tirarlos a un foso
		# proyectiles: los del jugador cuelgan de main (clase PlayerBullet); los enemigos, del grupo enemy_attack
		var shots: Array = []
		for c in main.get_children():
			if c is PlayerBullet:
				shots.append(c)
		for b in get_tree().get_nodes_in_group("enemy_attack"):
			if b is Area2D and ("speed" in b):
				shots.append(b)
		for b in shots:
			if is_instance_valid(b) and zone.has_point(b.global_position):
				b.global_position += push * PUSH_PROJ * delta
		for rb in _bodies():
			if zone.has_point(rb.global_position):
				rb.apply_central_impulse(push * 120.0 * delta)


## Objetos con fisica de la sala (escombro suelto de RoomLighting).
func _bodies() -> Array:
	var out: Array = []
	var lg = main._lighting
	var dd = lg._decor.get(room)
	if dd != null:
		for c in dd.node.get_children():
			if c is RigidBody2D:
				out.append(c)
	return out


# ================================================================== piezas
class _Spikes extends Node2D:
	var dyn
	var rect := Rect2()
	var period := 3.6
	var t := 0.0
	var _state := "idle"
	var _hit_p := false
	var _bit: Dictionary = {}
	const WARN := 0.9
	const UP := 0.7

	func warn_time() -> float:
		return WARN * dyn.warn_mult

	func _process(delta: float) -> void:
		t = fmod(t + delta, period)
		var w: float = warn_time()
		var start_warn := period - w - UP
		var prev := _state
		if t < start_warn:
			_state = "idle"
		elif t < start_warn + w:
			_state = "warn"
		else:
			_state = "up"
		if _state != prev:
			if _state == "warn":
				Sound.play("tone_0", 0.0)
			elif _state == "up":
				Sound.play("crack", 0.05)
				_hit_p = false
				_bit.clear()
		if _state == "warn" and prev == "warn":
			# segundo tic a mitad del aviso
			var mid := start_warn + w * 0.55
			if t >= mid and t - delta < mid:
				Sound.play("tone_1", 0.0)
		if _state == "up":
			_bite(delta)
		queue_redraw()

	## Un mordisco por subida y por cuerpo (el aviso ya fue la advertencia): quien siga encima cuando
	## sube recibe UN golpe; quien se queda encima no se lleva dos.
	func _bite(_delta: float) -> void:
		var d: float = dyn.depth()
		var rg := Rect2(dyn.room.global_position + position, rect.size).grow(-2.0)
		var pl: Node2D = dyn.player()
		if not _hit_p and pl != null and rg.has_point(pl.global_position):
			if RoomUtil.hurt_player(pl, 0.8 * RoomUtil.std_hit(d)):
				_hit_p = true
				RoomUtil.popup(pl.global_position + Vector2(0, -34), "!", Color("ff6b6b"))
		for e in RoomUtil.enemies_in(dyn.room):
			var id: int = e.get_instance_id()
			if not _bit.has(id) and rg.has_point(e.global_position):
				_bit[id] = true
				RoomUtil.hurt_enemy(e, 14.0 + 6.0 * d, rg.get_center(), 180.0)

	## Cinta de peligro (amarillo y negro) alrededor de la placa: se ve siempre, hasta en sala gris.
	func _tape(r: Rect2) -> void:
		var step := 8.0
		var yellow := Color(0.95, 0.75, 0.2, 0.95)
		var black := Color(0.08, 0.07, 0.09, 0.95)
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
		var i := 0
		for c in 4:
			var a: Vector2 = corners[c]
			var b: Vector2 = corners[(c + 1) % 4]
			var n := int(a.distance_to(b) / step)
			for k in n:
				var p0 := a.lerp(b, float(k) / n)
				var p1 := a.lerp(b, float(k + 1) / n)
				draw_line(p0, p1, yellow if i % 2 == 0 else black, 3.0)
				i += 1

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, rect.size)
		draw_rect(r, Color(0.16, 0.14, 0.18, 0.95))
		_tape(r)
		var w: float = warn_time()
		var start_warn: float = period - w - UP
		var k := 0.0
		match _state:
			"warn":
				k = clampf((t - start_warn) / w, 0.0, 1.0)
			"up":
				k = 1.0
		var cols := 3
		var rows := 3
		for ix in cols:
			for iy in rows:
				var c := Vector2((ix + 0.5) * r.size.x / cols, (iy + 0.5) * r.size.y / rows)
				draw_circle(c, 4.0, Color(0.05, 0.04, 0.06))
				if _state == "warn":
					var blink := int(t * (7.0 + 14.0 * k)) % 2 == 0
					draw_circle(c, 3.0, Color(1.0, 0.25, 0.15, 0.95 if blink else 0.4))
					draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3.0 - 3.0 * k), c + Vector2(2, 1), c + Vector2(-2, 1)]), Color(0.85, 0.85, 0.9))
				elif _state == "up":
					var h := 15.0 * minf(1.0, (t - (period - UP)) / 0.08 + 0.15)
					draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(4, 3), c + Vector2(-4, 3)]), Color(0.86, 0.87, 0.95))
					draw_line(c + Vector2(0, -h), c + Vector2(0, 2), Color(0.55, 0.57, 0.68), 1.0)
		if _state == "warn":
			var blink2 := int(t * (6.0 + 16.0 * k)) % 2 == 0
			draw_rect(r.grow(2.0), Color(1.0, 0.3, 0.2, 0.9 if blink2 else 0.35), false, 2.0)
		elif _state == "up":
			draw_rect(r.grow(2.0), Color(1.0, 0.35, 0.3, 0.7), false, 2.0)


class _Vent extends Node2D:
	var dyn
	var period := 4.4
	var t := 0.0
	var _state := "idle"
	var _jet_t := 0.0
	var _hit := false
	const WARN := 1.1
	const JET := 0.35
	const SPLASH_R := 40.0

	func _process(delta: float) -> void:
		t = fmod(t + delta, period)
		var w: float = WARN * dyn.warn_mult
		var start_warn := period - w - JET
		var prev := _state
		if t < start_warn:
			_state = "idle"
		elif t < start_warn + w:
			_state = "warn"
		else:
			_state = "jet"
		if _state != prev:
			if _state == "warn":
				Sound.play("tone_2", 0.0)
			elif _state == "jet":
				_hit = false
				_splash()
		queue_redraw()

	func _splash() -> void:
		Sound.play("suck", 0.1)
		RoomUtil.burst(dyn.room, global_position + Vector2(0, -10), Color("ffb24a"), 18)
		var d: float = dyn.depth()
		var pl: Node2D = dyn.player()
		if pl != null and pl.global_position.distance_to(global_position) <= SPLASH_R:
			if RoomUtil.hurt_player(pl, 0.7 * RoomUtil.std_hit(d)):
				RoomUtil.popup(pl.global_position + Vector2(0, -34), "!", Color("ffb24a"))
		for e in RoomUtil.enemies_in(dyn.room):
			if e.global_position.distance_to(global_position) <= SPLASH_R:
				RoomUtil.hurt_enemy(e, 14.0 + 4.0 * d, global_position, 320.0)
		dyn.add_puddle(position)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, 17.0, Color(0.9, 0.65, 0.2, 0.9))
		draw_circle(Vector2.ZERO, 14.0, Color(0.35, 0.22, 0.08, 0.95))
		draw_circle(Vector2.ZERO, 10.0, Color(0.06, 0.04, 0.03))
		draw_circle(Vector2.ZERO, 4.0, Color(0.95, 0.45, 0.1, 0.55))
		draw_arc(Vector2.ZERO, SPLASH_R, 0.0, TAU, 40, Color(0.95, 0.65, 0.2, 0.18), 1.0)
		if _state == "warn":
			var w: float = WARN * dyn.warn_mult
			var start_warn: float = period - w - JET
			var k := clampf((t - start_warn) / w, 0.0, 1.0)
			var blink := int(t * (6.0 + 16.0 * k)) % 2 == 0
			draw_circle(Vector2.ZERO, 8.0 + 3.0 * k, Color(1.0, 0.55, 0.12, 0.95))
			draw_arc(Vector2.ZERO, SPLASH_R, 0.0, TAU, 40, Color(1.0, 0.5, 0.15, 0.95 if blink else 0.4), 2.0)
			draw_arc(Vector2.ZERO, SPLASH_R * k, 0.0, TAU, 32, Color(1.0, 0.7, 0.3, 0.7), 1.0)
		elif _state == "jet":
			var jt := (t - (period - JET)) / JET
			draw_circle(Vector2.ZERO, SPLASH_R * (0.4 + 0.6 * jt), Color(1.0, 0.6, 0.15, 0.45 * (1.0 - jt)))
			draw_line(Vector2.ZERO, Vector2(0, -46.0 * (1.0 - jt * 0.5)), Color(1.0, 0.85, 0.4, 0.95), 7.0)


class _Puddle extends Node2D:
	var dyn
	var radius := 44.0
	var life := 7.5
	var _t := 0.0
	var _burn_p := 0.0
	var _burn_e := 0.0

	func renew() -> void:
		_t = 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			dyn.puddles.erase(self)
			queue_free()
			return
		_burn_p -= delta
		_burn_e -= delta
		var d: float = dyn.depth()
		var hot := 1.0 - clampf(_t / life, 0.0, 1.0)
		var pl: Node2D = dyn.player()
		if _burn_p <= 0.0 and hot > 0.25 and pl != null and pl.global_position.distance_to(global_position) <= radius:
			_burn_p = 1.2
			if RoomUtil.hurt_player(pl, 0.25 * RoomUtil.std_hit(d)):
				RoomUtil.popup(pl.global_position + Vector2(0, -34), "~", Color("ffb24a"))
		if _burn_e <= 0.0 and hot > 0.25:
			_burn_e = 0.8
			for e in RoomUtil.enemies_in(dyn.room):
				if e.global_position.distance_to(global_position) <= radius:
					RoomUtil.hurt_enemy(e, 3.0 + d, global_position, 0.0)
		queue_redraw()

	func _draw() -> void:
		var hot := 1.0 - clampf(_t / life, 0.0, 1.0)
		var col := Color(0.95, 0.62, 0.15, 0.55).lerp(Color(0.9, 0.82, 0.5, 0.45), 1.0 - hot)
		var a := clampf((life - _t) / 1.2, 0.0, 1.0)
		col.a *= a
		var pts := PackedVector2Array()
		for i in 22:
			var ang := TAU * i / 22.0
			pts.append(Vector2(cos(ang), sin(ang) * 0.72) * radius * (1.0 + 0.08 * sin(ang * 3.0 + 1.0)))
		draw_colored_polygon(pts, col)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 0.85, 0.45, 0.7 * a * hot + 0.2 * a), 2.0)
		draw_circle(Vector2(-10, -4), 4.0, Color(1.0, 0.95, 0.7, 0.4 * a))
		draw_circle(Vector2(14, 6), 3.0, Color(1.0, 0.95, 0.7, 0.3 * a))


class _Fan extends Node2D:
	var dyn
	var dir := Vector2.DOWN
	var length := 300.0
	var period := 6.0
	var t := 0.0
	var _blade := 0.0
	var _state := "off"
	const WARN := 1.2
	const BLOW := 2.6
	const DOWN := 0.6

	## 0..1: fuerza del viento ahora (0 en el aviso).
	func strength() -> float:
		if _state == "blow":
			return 1.0
		if _state == "down":
			return clampf(1.0 - (t - (period - DOWN)) / DOWN, 0.0, 1.0) * 0.6
		return 0.0

	func _spin() -> float:
		match _state:
			"warn":
				return clampf((t - (period - DOWN - BLOW - WARN * dyn.warn_mult)) / (WARN * dyn.warn_mult), 0.0, 1.0)
			"blow":
				return 1.0
			"down":
				return clampf(1.0 - (t - (period - DOWN)) / DOWN, 0.0, 1.0)
		return 0.0

	func _process(delta: float) -> void:
		t = fmod(t + delta, period)
		var w: float = WARN * dyn.warn_mult
		var start_warn := period - DOWN - BLOW - w
		var prev := _state
		if t < start_warn:
			_state = "off"
		elif t < start_warn + w:
			_state = "warn"
		elif t < period - DOWN:
			_state = "blow"
		else:
			_state = "down"
		if _state != prev and _state == "warn":
			Sound.play("tone_3", 0.0)
		if _state != prev and _state == "blow":
			Sound.play("suck", 0.1)
		_blade += delta * (2.0 + 28.0 * _spin())
		queue_redraw()

	func _draw() -> void:
		# carcasa
		var perp := dir.orthogonal()
		draw_circle(Vector2.ZERO, 24.0, Color(0.2, 0.2, 0.26))
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 28, Color(0.55, 0.55, 0.66), 3.0)
		var sp := _spin()
		for i in 3:
			var a := _blade + TAU * i / 3.0
			var v := Vector2.from_angle(a)
			draw_line(Vector2.ZERO, v * 20.0, Color(0.8, 0.82, 0.9, 0.9 - 0.5 * sp), 5.0)
		draw_circle(Vector2.ZERO, 4.0, Color(0.9, 0.9, 0.95))
		if _state == "warn":
			var blink := int(t * 14.0) % 2 == 0
			draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 28, Color(1.0, 0.6, 0.2, 0.95 if blink else 0.4), 2.0)
		# rayas de viento: se ven mas cuanto mas sopla
		var s := strength()
		var zone_a := 0.0 if _state == "off" else clampf(sp, 0.0, 1.0)
		if zone_a > 0.02:
			var shown := 0.25 + 0.75 * (1.0 if _state == "blow" else 0.0)
			for i in 7:
				var lane := (float(i) - 3.0) * 18.0
				var off := fmod(t * 260.0 * (0.4 + sp) + float(i) * 53.0, length)
				var seg := 38.0
				var a0 := dir * (30.0 + off) + perp * lane
				var a1 := a0 + dir * seg
				if (30.0 + off + seg) < length + 30.0:
					draw_line(a0, a1, Color(0.85, 0.95, 1.0, 0.5 * zone_a * shown), 2.0)
		if s > 0.01 or _state == "warn":
			# marco del area barrida (tenue)
			var w := 130.0
			var rect := Rect2(Vector2.ZERO, Vector2.ZERO)
			if absf(dir.x) > 0.5:
				rect = Rect2(Vector2(0.0 if dir.x > 0.0 else -length, -w * 0.5), Vector2(length, w))
			else:
				rect = Rect2(Vector2(-w * 0.5, 0.0 if dir.y > 0.0 else -length), Vector2(w, length))
			draw_rect(rect, Color(0.8, 0.95, 1.0, 0.07 if _state == "warn" else 0.10))
