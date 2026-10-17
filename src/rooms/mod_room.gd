extends RoomDynamic

## Modificadores de sala (anunciados en la puerta). Un solo script, el `kind` elige:
##   celo       "Sala en celo": enemigos mas rapidos y nerviosos (rosados).
##   lubricado  "Piso lubricado": el suelo resbala (el jugador patina) y el dash llega mas lejos.
##   aduanera   "Inspeccion aduanera": un aduanero pide una mordida en monedas o pelea (2
##              inspectores extra, con su botin confiscado si ganas).
##   apagon     "Apagon": solo ves lo que alumbra tu halo.
##   censurada  "Censurada": barras negras tapan zonas de la sala (se mueven despacio).
## Riesgo y premio: limpiar una sala modificada da unas monedas extra ("pluses de peligrosidad").

const HAZARD_PAY := {"celo": 2, "lubricado": 2, "aduanera": 0, "apagon": 3, "censurada": 3}
const CELO_SPEED := 1.35
const SLIP_ACCEL := 420.0    # px/s^2 con los que el jugador recupera el control (menos = mas patina)
const DASH_MULT := 1.5

var _t := 0.0
var _poll := 0.0
var _paid := false
# lubricado
var _vel_s := Vector2.ZERO
var _dash_base := -1.0
var _sheen: Node2D
# apagon
var _was_dark := false
var _dark_on := false
var _amb_mul := 0.5
# censurada
var _bars: Array[Node2D] = []
var _bar_base: Array[Vector2] = []
var _bar_dir: Array[Vector2] = []
var _bar_ph: Array[float] = []


func _ready() -> void:
	process_physics_priority = 20  # despues del jugador: el patinaje se suma tras su movimiento
	super()


func start() -> void:
	toast(tr("RM_MOD_" + kind.to_upper()), tr("RM_MOD_%s_D" % kind.to_upper()), _color_hex())
	say_intro("rm_" + kind)
	match kind:
		"celo":
			_overlay(Color(1.0, 0.35, 0.6, 0.07))
		"lubricado":
			_sheen = _Sheen.new()
			_sheen.set("size", rsize())
			floor_layer().add_child(_sheen)
			_dash_begin()
		"aduanera":
			_customs()
		"apagon":
			_blackout()
		"censurada":
			_make_bars()


func _color_hex() -> String:
	return {"celo": "ff7ac0", "lubricado": "7ad8ff", "aduanera": "c9c9d6", "apagon": "8a8aa8", "censurada": "e0e0e0"}.get(kind, "b08d4a")


func _overlay(col: Color) -> void:
	var p := Polygon2D.new()
	var s := rsize()
	p.polygon = PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)])
	p.color = col
	p.material = LightKit.unshaded_material()
	floor_layer().add_child(p)


func _process(delta: float) -> void:
	if not started:
		return
	_t += delta
	if finished:
		return
	_poll -= delta
	match kind:
		"celo":
			if _poll <= 0.0:
				_poll = 0.25
				_apply_celo()
		"censurada":
			_move_bars()
		"apagon":
			if main.current_room == room and not room.cleared and _dark_on:
				_keep_dark()
	if room.cleared:
		_on_room_done()


func _on_room_done() -> void:
	finish(true)
	if not _paid:
		_paid = true
		var n: int = int(HAZARD_PAY.get(kind, 0))
		if kind == "aduanera":
			if has_meta("fought"):
				bonus(3, 1.0)
		elif n > 0:
			bonus(n + int(depth() / 2.0))
	match kind:
		"lubricado":
			_dash_end()
			if _sheen:
				_sheen.queue_free()
		"apagon":
			_restore_light()
		"censurada":
			for b in _bars:
				if is_instance_valid(b):
					var tw := b.create_tween()
					tw.tween_property(b, "modulate:a", 0.0, 0.6)
					tw.tween_callback(b.queue_free)
	room.set_meta("dyn_done", true)


# ------------------------------------------------------------------ celo
func _apply_celo() -> void:
	for e in room.enemies_spawned:
		if not is_instance_valid(e) or not e.is_inside_tree() or e.has_meta("celo") or e.is_in_group("boss"):
			continue
		e.set_meta("celo", true)
		e.move_speed *= CELO_SPEED
		# la IA con personalidad recalcula las velocidades desde su base (rabia, rencor...): se sube tambien ahi
		var ai = e.get("ai")
		if ai != null and "_base" in ai:
			for prop in ai._base:
				if prop != "damage":
					ai._base[prop] *= CELO_SPEED
					if prop != "move_speed" and prop in e:
						e.set(prop, float(e.get(prop)) * CELO_SPEED)
		if "attack_cooldown" in e:
			e.attack_cooldown *= 0.7
		if "lunge_speed" in e:
			e.lunge_speed *= 1.1
		var spr = e.get("animated_sprite")
		if spr is AnimatedSprite2D:
			spr.self_modulate = Color(1.0, 0.72, 0.88)
		var l := ActorFx.add_glow(e, Color(1.0, 0.4, 0.65), 0.7, 0.5)
		l.position = Vector2(0, -10)
		_hearts(e)


func _hearts(e: Node2D) -> void:
	var p := CPUParticles2D.new()
	p.amount = 3
	p.lifetime = 1.1
	p.gravity = Vector2(0, -26)
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 16.0
	p.direction = Vector2.UP
	p.spread = 30.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.color = Color(1.0, 0.35, 0.6, 0.9)
	p.position = Vector2(0, -34)
	p.z_index = 3
	p.material = LightKit.unshaded_material()
	e.add_child(p)


# ------------------------------------------------------------------ lubricado
func _dash_begin() -> void:
	var pl := player()
	if pl == null:
		return
	if not pl.has_meta("dash_base_dur"):
		pl.set_meta("dash_base_dur", pl.dash_duration)
	_dash_base = float(pl.get_meta("dash_base_dur"))
	pl.dash_duration = _dash_base * DASH_MULT


func _dash_end() -> void:
	var pl := player()
	if pl != null and pl.has_meta("dash_base_dur"):
		pl.dash_duration = float(pl.get_meta("dash_base_dur"))


func _exit_tree() -> void:
	if kind == "lubricado":
		_dash_end()
	if kind == "apagon":
		_restore_light()


func _physics_process(delta: float) -> void:
	if not started:
		return
	if kind != "lubricado" or finished or main.current_room != room:
		return
	var pl := player() as CharacterBody2D
	if pl == null:
		return
	if pl.is_dashing:
		_vel_s = pl.velocity
		return
	# velocidad "deseada" (la del jugador este fotograma) vs la velocidad real con inercia
	var want := pl.velocity
	_vel_s = _vel_s.move_toward(want, SLIP_ACCEL * delta)
	var extra := _vel_s - want
	if extra.length_squared() > 1.0:
		pl.move_and_collide(extra * delta)


# ------------------------------------------------------------------ aduanera
func _customs() -> void:
	var n := 4 + 2 * RunManager.depth_i(rm().current_floor)
	var spot := RoomUtil.free_spot(main, room, center() + Vector2(0, -90))
	if spot == Vector2.INF:
		spot = center() + Vector2(0, -90)
	var npc := AnimatedSprite2D.new()
	npc.sprite_frames = load("res://assets/sprites/enemies/aduanero_sprite_frames.tres")
	npc.play("idle")
	npc.scale = Vector2(0.55, 0.55)
	npc.position = spot
	npc.offset = Vector2(0, -40)
	add_child(npc)
	var opts: Array = []
	var can_pay: bool = rm().coins >= n
	if can_pay:
		opts.append(tr("RM_CUSTOMS_PAY") % n)
	opts.append(tr("RM_CUSTOMS_FIGHT"))
	Narrator.choose(tr("RM_CUSTOMS_Q") % n if can_pay else tr("RM_CUSTOMS_Q_POOR"), opts)
	var pick: int = await Narrator.chosen
	if not is_instance_valid(self) or room.cleared:
		return
	if can_pay and pick == 0:
		rm().add_coins(-n)
		RoomUtil.popup(player().global_position + Vector2(0, -40), "-%d $" % n, RoomUtil.GOLD)
		say_when_calm("rm_aduanera_paid")
		Sound.play("buy")
	else:
		set_meta("fought", true)
		say_when_calm("rm_aduanera_fight")
		var extra := _inspectors()
		if not extra.is_empty():
			room.spawn_enemies(extra, main._has_real_weapon())
	var tw := npc.create_tween()
	tw.tween_property(npc, "modulate:a", 0.0, 0.8)
	tw.tween_callback(npc.queue_free)


func _inspectors() -> Array[Dictionary]:
	var d := depth()
	var out: Array[Dictionary] = []
	for i in 2:
		out.append({
			"enemy_type": "inspector",
			"name": tr("RM_CUSTOMS_INSPECTOR"),
			"frames": main._frames_path("inspector_fluidos"),
			"health": (30.0 + d * 10.0) * 1.2,
			"damage": main.ENEMY_DAMAGE_BASE + d * 3.0,
			"drops": [{"item_id": "coin", "chance": 0.5}],
		})
	RoomUtil.ensure_spawn_points(room)
	return out


# ------------------------------------------------------------------ apagon
func _blackout() -> void:
	_was_dark = room.is_dark
	room.is_dark = true
	_dark_on = true
	main._lighting.enter_room(room)
	_keep_dark()


## Apaga las antorchas y faroles de la sala (los reenciende LightKit.set_dark al entrar) y oscurece
## el ambiente: queda el halo del jugador.
func _keep_dark() -> void:
	var lg: RoomLighting = main._lighting
	var d = lg._decor.get(room)
	if d != null:
		for l in d.lights:
			if is_instance_valid(l):
				l.enabled = false
	if int(_t * 60.0) % 30 == 0 or _t < 0.1:
		var amb: CanvasModulate = lg._ambient
		if lg._ambient_tween and lg._ambient_tween.is_valid():
			return
		var base := Color(0.07, 0.07, 0.09)
		amb.color = base


func _restore_light() -> void:
	if not _dark_on:
		return
	_dark_on = false
	room.is_dark = _was_dark
	if main != null and is_instance_valid(main) and main.current_room == room:
		main._lighting.enter_room(room)
		main._lighting.paint(room, room.cleared, true)


# ------------------------------------------------------------------ censurada
func _make_bars() -> void:
	var s := rsize()
	var n := 3 + (1 if depth() >= 3.0 else 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([room.grid_pos.x, room.grid_pos.y, rm().current_floor, "bars"])
	var entries := RoomUtil.entries(room)
	for i in n:
		for attempt in 20:
			var horiz := rng.randf() < 0.55
			var sz := Vector2(rng.randf_range(130, 190), 46) if horiz else Vector2(46, rng.randf_range(110, 160))
			var pos := Vector2(rng.randf_range(110.0 + sz.x * 0.5, s.x - 110.0 - sz.x * 0.5), rng.randf_range(110.0 + sz.y * 0.5, s.y - 110.0 - sz.y * 0.5))
			var r := Rect2(pos - sz * 0.5, sz).grow(70.0)
			if entries.any(func(e): return r.has_point(e.entry)):
				continue
			if _bar_base.any(func(b): return b.distance_to(pos) < 130.0):
				continue
			var bar := _Bar.new()
			bar.set("size", sz)
			bar.position = pos
			bar.z_index = 9
			bar.material = LightKit.unshaded_material()
			add_child(bar)
			_bars.append(bar)
			_bar_base.append(pos)
			_bar_dir.append(Vector2.RIGHT if horiz else Vector2.DOWN)
			_bar_ph.append(rng.randf() * TAU)
			break


func _move_bars() -> void:
	for i in _bars.size():
		if is_instance_valid(_bars[i]):
			_bars[i].position = _bar_base[i] + _bar_dir[i] * sin(_t * 0.55 + _bar_ph[i]) * 55.0


## Barra negra de censura (con su rotulo).
class _Bar extends Node2D:
	var size := Vector2(150, 46)

	func _draw() -> void:
		var r := Rect2(-size * 0.5, size)
		draw_rect(r, Color(0.02, 0.02, 0.03, 0.96))
		draw_rect(r.grow(-3.0), Color(0.12, 0.12, 0.14, 1.0), false, 1.0)
		var f := ThemeDB.fallback_font
		var txt := "CENSURADO"
		if size.x >= size.y:
			draw_string(f, Vector2(-size.x * 0.5 + 8.0, 5.0), txt, HORIZONTAL_ALIGNMENT_LEFT, size.x - 16.0, 12, Color(0.35, 0.35, 0.4))
		else:
			draw_string(f, Vector2(-size.x * 0.5 + 6.0, -size.y * 0.5 + 18.0), "XXX", HORIZONTAL_ALIGNMENT_LEFT, size.x - 8.0, 12, Color(0.35, 0.35, 0.4))


## Brillo de suelo mojado: franjas diagonales claras que se desplazan.
class _Sheen extends Node2D:
	var size := Vector2(640, 384)
	var _t := 0.0

	func _ready() -> void:
		material = LightKit.unshaded_material()

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.5, 0.85, 1.0, 0.09))
		var step := 90.0
		var off := fmod(_t * 26.0, step)
		var x := -size.y + off
		while x < size.x:
			var a := Vector2(x, size.y)
			var b := Vector2(x + size.y, 0.0)
			# recorta al rectangulo (la linea y = size.y - (px - x))
			var pa := a
			var pb := b
			if pa.x < 0.0:
				pa = Vector2(0.0, size.y - (0.0 - x))
			if pb.x > size.x:
				pb = Vector2(size.x, size.y - (size.x - x))
			if pa.x < size.x and pb.x > 0.0:
				draw_line(pa, pb, Color(0.9, 1.0, 1.0, 0.13), 7.0)
			x += step
