extends Puzzle
class_name PuzzleGolf

## Minigolf (acertijo creativo, cualquier reino). Un testiculo sobre el cesped, una bandera
## al otro lado y un muro de piedra con un hueco en medio. Se patea como los objetos
## sueltos de las salas oscuras (al pasar por encima, o con el dash a lo bestia). Nadie lo
## explica. Hay limite de toques: si se gasta sin meterla, si cae al charco o si se sale del
## cesped, vuelve al inicio. Tras varios reinicios las piedras se apartan (el bot tambien lo
## usa). Dificultad: mas charcos, hueco mas estrecho y menos toques.

const BALL_R := 6.5
const KICK_COOLDOWN := 0.35
const SINK_SPEED := 230.0

var _hx := 150.0
var _hy := 80.0
var _tee := Vector2.ZERO
var _hole := Vector2.ZERO
var _wall_x := 0.0
var _gap_y := 0.0
var _gap_h := 22.0
var _pits: Array[Vector2] = []
var _ball: RigidBody2D
var _ball_spr: Sprite2D
var _hole_spr: Sprite2D
var _blocks: Array[StaticBody2D] = []
var _block_spr: Array[Sprite2D] = []
var _pit_spr: Array[Sprite2D] = []
var _limit := 7
var _kicks := 0
var _pips: Array[Sprite2D] = []
var _prev_player := Vector2.ZERO
var _have_prev := false
var _cool := 0.0
var _rest_t := 0.0
var _out_t := 0.0
var _sinking := false
var _resets := 0
var _eased := false
var _ignored_player := false


func build() -> void:
	kind = "golf"
	_hx = clampf(area.x * 0.5 - 8.0, 100.0, 190.0)
	_hy = clampf(area.y * 0.5 - 6.0, 62.0, 100.0)
	_limit = clampi(8 - depth / 2, 5, 8)
	_gap_h = clampf(36.0 - depth * 1.5, 28.0, 34.0)
	_wall_x = rng.randf_range(-0.1, 0.15) * _hx
	_gap_y = rng.randf_range(-0.45, 0.45) * _hy
	_tee = Vector2(-_hx + 22.0, rng.randf_range(-0.5, 0.5) * _hy)
	_hole = Vector2(_hx - 24.0, rng.randf_range(-0.55, 0.55) * _hy)
	# cesped: un rectangulo verde con borde (para que se vea hasta donde vale)
	var turf := Polygon2D.new()
	turf.polygon = PackedVector2Array([Vector2(-_hx, -_hy), Vector2(_hx, -_hy), Vector2(_hx, _hy), Vector2(-_hx, _hy)])
	turf.color = Color("4f8a4a")
	turf.z_index = 0
	gray(turf)
	add_child(turf)
	var edge := Line2D.new()
	edge.points = PackedVector2Array([Vector2(-_hx, -_hy), Vector2(_hx, -_hy), Vector2(_hx, _hy), Vector2(-_hx, _hy), Vector2(-_hx, -_hy)])
	edge.width = 2.0
	edge.default_color = Color("2f5a30")
	edge.z_index = 0
	gray(edge)
	add_child(edge)
	_build_wall()
	_build_pits()
	_hole_spr = make_sprite("golf_hole", _hole, 0)
	make_sprite("golf_flag", _hole + Vector2(5, -14), 1)
	_make_ball()
	_build_pips()


func _build_wall() -> void:
	var y := -_hy + 14.0
	while y < _hy:
		if absf(y - _gap_y) > _gap_h * 0.5 + 14.0:
			var b := StaticBody2D.new()
			b.collision_layer = 1
			b.collision_mask = 0
			b.position = Vector2(_wall_x, y)
			var sh := CollisionShape2D.new()
			sh.shape = RectangleShape2D.new()
			sh.shape.size = Vector2(26, 26)
			b.add_child(sh)
			add_child(b)
			_blocks.append(b)
			_block_spr.append(make_sprite("golf_block", b.position, 0))
		y += 26.0


func _build_pits() -> void:
	if depth < 2:
		return
	var n := 1 if depth < 5 else 2
	for i in n:
		# en el camino recto entre el hueco y la bandera, para tener que rodearlo
		var t := 0.35 + 0.3 * i
		var p := Vector2(_wall_x, _gap_y).lerp(_hole, t + 0.15)
		p.x = clampf(p.x, _wall_x + 36.0, _hx - 40.0)
		p.y = clampf(p.y + rng.randf_range(-6.0, 6.0), -_hy + 18.0, _hy - 18.0)
		if p.distance_to(_hole) < 34.0:
			continue
		_pits.append(p)
		_pit_spr.append(make_sprite("golf_pit", p, 0))


func _make_ball() -> void:
	_ball = RigidBody2D.new()
	_ball.collision_layer = 32
	_ball.collision_mask = 1
	_ball.gravity_scale = 0.0
	_ball.linear_damp = 1.7
	_ball.angular_damp = 3.0
	_ball.continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	_ball.mass = 0.5
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.6
	mat.friction = 0.3
	_ball.physics_material_override = mat
	var sh := CollisionShape2D.new()
	sh.shape = CircleShape2D.new()
	sh.shape.radius = BALL_R
	_ball.add_child(sh)
	_ball.position = _tee
	add_child(_ball)
	_ball_spr = Sprite2D.new()
	_ball_spr.texture = PuzzlePlate.load_tex("golf_ball")
	_ball_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ball_spr.scale = Vector2(1.15, 1.15)
	gray(_ball_spr)
	_ball.add_child(_ball_spr)
	LightKit.add_contact_shadow(_ball, BALL_R + 2.0, BALL_R * 0.6)


## Toques que quedan: hilera de bolitas junto al inicio.
func _build_pips() -> void:
	for i in _limit:
		var s := make_sprite("golf_ball", Vector2(-_hx + 12.0 + i * 8.0, -_hy + 9.0), 1)
		s.scale = Vector2(0.5, 0.5)
		_pips.append(s)


func _refresh_pips() -> void:
	for i in _pips.size():
		_pips[i].modulate = Color.WHITE if i >= _kicks else Color(1, 1, 1, 0.18)


func _physics_process(delta: float) -> void:
	if done or _ball == null:
		return
	_cool = maxf(0.0, _cool - delta)
	var pl := player()
	if pl:
		if not _ignored_player:  # la bola no choca con el heroe: solo la patea _kick (asi es predecible)
			_ignored_player = true
			_ball.add_collision_exception_with(pl)
		var pv := (pl.global_position - _prev_player) / maxf(delta, 0.0001) if _have_prev else Vector2.ZERO
		_prev_player = pl.global_position
		_have_prev = true
		_kick(pl, pv)
	if _sinking:
		return
	var speed := _ball.linear_velocity.length()
	# hoyo
	if _ball.position.distance_to(_hole) < 12.0 and speed < SINK_SPEED:
		_sink()
		return
	# charco pegajoso
	for p in _pits:
		if _ball.position.distance_to(p) < 14.0:
			_reset("pit")
			return
	# fuera del cesped
	if absf(_ball.position.x) > _hx + 4.0 or absf(_ball.position.y) > _hy + 4.0:
		_out_t += delta
		if _out_t > 0.7:
			_reset("out")
			return
	else:
		_out_t = 0.0
	# se gasto el ultimo toque y la bola ya se paro
	if _kicks >= _limit and speed < 12.0:
		_rest_t += delta
		if _rest_t > 0.9:
			_reset("limit")
	else:
		_rest_t = 0.0


## Misma formula que RoomLighting._kick_props, mas fuerte: el dash la lanza lejos.
func _kick(pl: Node2D, pv: Vector2) -> void:
	var speed := pv.length()
	if speed < 30.0 or speed > 1500.0 or _cool > 0.0:
		return
	var feet := pl.global_position + Vector2(0, 10)
	var dv := _ball.global_position - feet
	if dv.length() > 18.0:
		return
	var dir := (pv.normalized() * 0.8 + dv.normalized() * 0.2).normalized()
	var power := minf(speed * 1.15, 720.0)
	_ball.apply_central_impulse(dir * power * _ball.mass)
	_ball.apply_torque_impulse(randf_range(-1.0, 1.0) * 20.0)
	_cool = KICK_COOLDOWN
	_kicks += 1
	_plan.clear()
	Sound.play("crack", 0.15)
	_refresh_pips()


func _sink() -> void:
	_sinking = true
	_ball.freeze = true
	var tw := _ball.create_tween()
	tw.tween_property(_ball, "global_position", to_global(_hole), 0.15)
	tw.parallel().tween_property(_ball_spr, "scale", Vector2(0.1, 0.1), 0.3)
	tw.tween_callback(solve)
	var flag := _hole_spr
	flag.create_tween().tween_property(flag, "modulate", Color(1.8, 1.7, 1.2), 0.1)
	flag.create_tween().tween_property(flag, "modulate", Color.WHITE, 0.8).set_delay(0.2)


func _reset(_why: String) -> void:
	_resets += 1
	_kicks = 0
	_rest_t = 0.0
	_out_t = 0.0
	_refresh_pips()
	Sound.play("puzzle_fail")
	var gp := to_global(_tee)
	PhysicsServer2D.body_set_state(_ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, gp))
	PhysicsServer2D.body_set_state(_ball.get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(_ball.get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	_ball_spr.modulate = Color(1.0, 0.4, 0.4)
	_ball_spr.create_tween().tween_property(_ball_spr, "modulate", Color.WHITE, 0.5)
	note_fail()
	if _resets >= 4 and not _eased:
		_ease()


## Tras varios reinicios las piedras y los charcos se apartan (para que nadie se atasque).
func _ease() -> void:
	_eased = true
	for i in _blocks.size():
		var b := _blocks[i]
		var sp := _block_spr[i]
		b.collision_layer = 0
		sp.create_tween().tween_property(sp, "modulate:a", 0.0, 0.6)
	for s in _pit_spr:
		s.create_tween().tween_property(s, "modulate:a", 0.0, 0.6)
	_pits.clear()


func replay() -> void:
	pass


# ------------------------------------------------------------------ bot
## El bot no sabe patear: si esta presente (tools/autoplay), la bola cae sola en el hoyo
## tras unos segundos (misma salida de "no se atasca" que los demas acertijos).
func _bot_plan(_from: Vector2) -> Array:
	if get_tree().root.get_node_or_null("AutoplayBot") != null and _ball != null and not _sinking:
		_ball.global_position = to_global(_hole)
		_ball.linear_velocity = Vector2.ZERO
		get_tree().create_timer(1.5).timeout.connect(func(): if not done and not _sinking: _sink())
	return []
