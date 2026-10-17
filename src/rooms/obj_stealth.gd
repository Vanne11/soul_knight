extends RoomDynamic

## Sigilo: la Censura patrulla la sala con linternas. Llega a la caja de decomisos (E) sin que
## te vean. Si te ven (te iluminan un instante y suena la alarma) la sala se llena de enemigos
## y es un combate normal, sin el botin de la caja. Si llegas: cofre, monedas y se abren las
## puertas. Los muros y obstaculos tapan la luz (el cono se corta ahi). Hay 2,5 s de gracia al
## entrar y el cono tarda ~0,8 s en llenarse: ver sin ser visto es posible.
## Bot: sin enemigos va a la caja como a cualquier objeto de la sala; si lo ven, pelea normal.

const GRACE := 2.5
const FILL := 0.8
const DRAIN := 0.7
const SPEED := 58.0
const INTERACTABLE := preload("res://src/items/interactable.gd")

var guards: Array[Node2D] = []
var box: Node2D
var alarmed := false
var _t := 0.0
var _hud: DynHud


func gate() -> bool:
	return true


func debug() -> String:
	return "stealth guards=%d alarmed=%s fin=%s ok=%s box=%s" % [guards.size(), alarmed, finished, success, box != null]


func start() -> void:
	owns_spawn = true
	room.seal_doors()
	if not _build():
		abort()
		return
	_hud = DynHud.make(self, tr("RM_STEALTH_T"), Color("ffe9a0"))
	toast(tr("RM_STEALTH_T"), tr("RM_STEALTH_D"), "ffe9a0")
	say_intro("rm_stealth")


func _build() -> bool:
	var s := rsize()
	var ent := RoomUtil.entries(room)
	var entries: Array[Vector2] = []
	for e in ent:
		entries.append(e.entry)
	# la caja: el sitio libre mas lejano a las entradas
	var best := Vector2.INF
	var best_d := -1.0
	for ix in 4:
		for iy in 3:
			var p := Vector2(lerpf(130.0, s.x - 130.0, ix / 3.0), lerpf(120.0, s.y - 120.0, iy / 2.0))
			var q := RoomUtil.free_spot(main, room, p, 20.0)
			if q == Vector2.INF:
				continue
			var d := 1e9
			for en in entries:
				d = minf(d, en.distance_to(q))
			if d > best_d:
				best_d = d
				best = q
	if best == Vector2.INF:
		return false
	_make_box(best)
	# patrullas: 2 (3 desde profundidad 3), rutas de puntos libres con linea recta entre ellos
	var n := 2 + (1 if depth() >= 3.0 else 0)
	var pts: Array[Vector2] = []
	for ix in 5:
		for iy in 4:
			var p := Vector2(lerpf(120.0, s.x - 120.0, ix / 4.0), lerpf(110.0, s.y - 110.0, iy / 3.0))
			var q := RoomUtil.free_spot(main, room, p, 16.0, true)
			if q != Vector2.INF and q.distance_to(p) < 1.0 and entries.all(func(en): return en.distance_to(q) > 170.0) and q.distance_to(best) > 90.0:
				pts.append(q)
	if pts.size() < 2:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([room.grid_pos.x, room.grid_pos.y, rm().current_floor, "guards"])
	for gi in n:
		var route := _route(pts, rng)
		if route.size() < 2:
			continue
		var g := _Guard.new()
		g.dyn = self
		g.route = route
		g.position = route[0]
		g.range_px = minf(260.0, 190.0 + 12.0 * depth())
		g.phase = rng.randf() * 3.0
		guards.append(g)
		add_child(g)
	return guards.size() > 0


## Ruta cerrada de 2-4 puntos cuyos tramos consecutivos estan libres de muros.
func _route(pts: Array[Vector2], rng: RandomNumberGenerator) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for attempt in 24:
		var a: Vector2 = pts[rng.randi_range(0, pts.size() - 1)]
		var cand: Array[Vector2] = [a]
		for k in rng.randi_range(1, 3):
			var b: Vector2 = pts[rng.randi_range(0, pts.size() - 1)]
			if b.distance_to(cand[-1]) > 150.0 and RoomUtil.line_clear(main, room, cand[-1], b, 65):
				cand.append(b)
		if cand.size() >= 2 and RoomUtil.line_clear(main, room, cand[-1], cand[0], 65):
			out = cand
			break
	return out


func _make_box(pos: Vector2) -> void:
	box = INTERACTABLE.new()
	box.position = pos
	box.set("prompt_text", tr("RM_STEALTH_BOX"))
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/sprites/environment/obstacles/neutral/crate.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.offset = Vector2(0, -16)
	box.add_child(spr)
	ActorFx.add_glow(box, Color(1.0, 0.85, 0.4), 0.9, 0.9)
	var star := _Pulse.new()
	box.add_child(star)
	box.connect("used", _on_box)
	room.props_node.add_child.call_deferred(box)


func _on_box(_pl: Node) -> void:
	if finished or alarmed:
		return
	finish(true)
	Sound.play("puzzle_solve")
	toast(tr("RM_STEALTH_OK_T"), tr("RM_STEALTH_OK"), "9be88a")
	box.call("finish")
	for g in guards:
		if is_instance_valid(g):
			g.call("fade")
	if _hud:
		_hud.queue_free()
	main._spawn_chest(room, "", Vector2(0, -40))
	bonus(3 + RunManager.depth_i(rm().current_floor), 0.3)
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 0.0, 0.5)
	tw.tween_callback(box.queue_free)
	clear_room()
	say_when_calm("rm_stealth_ok")


func alarm(by: Node2D) -> void:
	if alarmed or finished:
		return
	alarmed = true
	finish(false)
	Sound.play("locked")
	HitFx.shake(0.5)
	toast(tr("RM_STEALTH_ALARM_T"), tr("RM_STEALTH_ALARM"), "ff5a5a")
	say_when_calm("rm_stealth_alarm")
	for g in guards:
		if is_instance_valid(g):
			g.call("alarmed")
	if is_instance_valid(box):
		box.call("finish")
		var tw := box.create_tween()
		tw.tween_property(box, "modulate:a", 0.0, 0.6)
		tw.tween_callback(box.queue_free)
	if _hud:
		_hud.queue_free()
	main._paint_room(room, false)
	RoomUtil.spawn_wave(main, room, 99, true)  # todos los enemigos normales de la sala, de golpe


func _process(delta: float) -> void:
	if not started:
		return
	_t += delta
	if _hud and not finished:
		var m := 0.0
		for g in guards:
			if is_instance_valid(g):
				m = maxf(m, float(g.get("meter")))
		_hud.set_value(1.0 - m, tr("RM_STEALTH_BAR") if _t >= GRACE else tr("RM_STEALTH_GRACE"))
		_hud.set_color(Color("ffe9a0").lerp(Color("ff5a5a"), m))


## true si el jugador esta a la vista de un guardia con esa posicion/orientacion.
func sees_player(from_local: Vector2, facing: float, range_px: float, half: float) -> bool:
	var pl := player()
	if pl == null:
		return false
	var lp := pl.global_position - room.global_position
	var d := lp - from_local
	if d.length() > range_px or d.length() < 1.0:
		return d.length() < 1.0
	if absf(angle_difference(facing, d.angle())) > half:
		return false
	return RoomUtil.line_clear(main, room, from_local, lp)


## Guardia con linterna: patrulla una ruta y barre con el cono; el cono se corta en los muros.
class _Guard extends Node2D:
	var dyn
	var route: Array[Vector2] = []
	var range_px := 200.0
	var half := deg_to_rad(29.0)
	var meter := 0.0
	var facing := 0.0
	var phase := 0.0
	var _idx := 1
	var _pause := 0.0
	var _t := 0.0
	var _spr: AnimatedSprite2D
	var _poly: PackedVector2Array = PackedVector2Array()
	var _alarm := false
	var _fading := false

	func _ready() -> void:
		_spr = AnimatedSprite2D.new()
		_spr.sprite_frames = load("res://assets/sprites/enemies/sello_sprite_frames.tres")
		_spr.play("walk")
		_spr.offset = Vector2(0, -22)
		add_child(_spr)
		z_index = 1
		facing = (route[1] - route[0]).angle()

	func fade() -> void:
		_fading = true
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.6)
		tw.tween_callback(queue_free)

	func alarmed() -> void:
		_alarm = true
		meter = 1.0
		fade()

	func _physics_process(delta: float) -> void:
		if dyn == null or not is_instance_valid(dyn) or not dyn.started or dyn.finished or _fading:
			return
		_t += delta
		# movimiento
		if _pause > 0.0:
			_pause -= delta
			facing += sin((_t + phase) * 2.2) * delta * 1.3  # barre el cono de lado a lado
			_spr.play("idle")
		else:
			var target: Vector2 = route[_idx]
			var to := target - position
			if to.length() < 6.0:
				_idx = (_idx + 1) % route.size()
				_pause = 0.9
			else:
				facing = lerp_angle(facing, to.angle(), clampf(delta * 5.0, 0.0, 1.0))
				position += to.normalized() * dyn.SPEED * delta
				_spr.play("walk")
				_spr.flip_h = to.x < 0.0
		# vision
		var seen := false
		if dyn._t >= dyn.GRACE:
			seen = dyn.sees_player(position + Vector2(0, -14), facing, range_px, half)
		if seen:
			meter = minf(1.0, meter + delta / dyn.FILL)
			if meter >= 1.0:
				dyn.alarm(self)
		else:
			meter = maxf(0.0, meter - delta * dyn.DRAIN)
		_poly = _cone()
		queue_redraw()

	func _cone() -> PackedVector2Array:
		var pts := PackedVector2Array()
		var o := position + Vector2(0, -14)
		pts.append(Vector2(0, -14))
		var steps := 14
		var space := get_world_2d().direct_space_state
		var gp: Vector2 = dyn.room.global_position + o
		for i in steps + 1:
			var a := facing - half + (2.0 * half) * float(i) / float(steps)
			var dir := Vector2.from_angle(a)
			var q := PhysicsRayQueryParameters2D.create(gp, gp + dir * range_px, 1)
			var hit := space.intersect_ray(q)
			var l: float = range_px if hit.is_empty() else gp.distance_to(hit.position)
			pts.append(Vector2(0, -14) + dir * l)
		return pts

	func _draw() -> void:
		if _poly.size() < 3:
			return
		var col := Color(1.0, 0.96, 0.7, 0.20).lerp(Color(1.0, 0.25, 0.2, 0.34), meter)
		if _alarm:
			col = Color(1.0, 0.2, 0.2, 0.4)
		draw_colored_polygon(_poly, col)
		var edge := Color(1.0, 0.95, 0.75, 0.45).lerp(Color(1.0, 0.3, 0.25, 0.8), meter)
		draw_line(_poly[0], _poly[1], edge, 1.5)
		draw_line(_poly[0], _poly[_poly.size() - 1], edge, 1.5)
		# "!" / "?" sobre la cabeza segun cuanto te ve
		if meter > 0.02:
			var f := ThemeDB.fallback_font
			draw_rect(Rect2(-14, -62, 28, 5), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(-13, -61, 26.0 * meter, 3), Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.2, 0.2), meter))
			draw_string(f, Vector2(-4, -66), "!" if meter > 0.6 else "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.6))


## Brillo que late sobre la caja.
class _Pulse extends Node2D:
	var _t := 0.0

	func _ready() -> void:
		material = LightKit.unshaded_material()

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var r := 26.0 + sin(_t * 3.0) * 3.0
		draw_arc(Vector2(0, -12), r, 0.0, TAU, 28, Color(1.0, 0.9, 0.5, 0.7), 2.0)
