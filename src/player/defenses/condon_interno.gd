extends Defense
class_name DefCondonInterno

## CONDON INTERNO (defensa, USO UNICO). Hermano mayor del Condon Escudo. PULSAR "guard": una funda de
## latex te ENVUELVE entero DURATION s: absorbe balas, golpes (HITS como maximo) y no deja pasar contagios
## ni nubes. A diferencia del escudo, caminas y disparas con normalidad. Al acabarse el tiempo o los
## golpes queda inservible (`spent`: vuelve la guard del heroe). "Tambien existe, se pone por dentro."

const DURATION := 8.0
const HITS := 10

var hits_left := HITS
var _on := 0.0
var _flash := 0.0
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("b9a4ff")


func blocks_contagion() -> bool:
	return _on > 0.0


func blocks_cloud() -> bool:
	return _on > 0.0


func _physics_process(delta: float) -> void:
	if player == null or spent:
		return
	if _on <= 0.0:
		if guard_pressed():
			_on = DURATION
			guarding = true
			text("DEF_CONDOM_INT_ON", Color("d6c8ff"), 44.0)
			Sound.play("room_clear", 0.1)
		return
	_on -= delta
	gauge_visible = true
	gauge_value = _on / DURATION
	if _on <= 0.0:
		_finish()


func _finish() -> void:
	_on = 0.0
	spent = true
	guarding = false
	gauge_visible = false
	text("DEF_CONDOM_INT_OFF", Color("b8b0d0"), 40.0)
	Sound.play("crack", 0.1)


func try_guard(area: Area2D, _dmg: float) -> bool:
	if _on <= 0.0 or not is_projectile(area):
		return false
	consume(area)
	_absorb()
	return true


func filter_hit(dmg: float) -> float:
	if _on <= 0.0 or dmg <= 0.0:
		return dmg
	_absorb()
	return 0.0


func _absorb() -> void:
	hits_left -= 1
	_flash = 0.25
	Sound.play("crack", 0.1)
	HitFx.shake(0.15)
	if hits_left <= 0:
		_finish()
	else:
		text("DEF_CONDOM_HIT", Color("d6c8ff"))


func _draw_tick() -> void:
	_t += get_process_delta_time()
	_flash = maxf(0.0, _flash - get_process_delta_time())
	if _on > 0.0 or _flash > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if _on <= 0.0:
		return
	var life := float(hits_left) / HITS
	var fade := clampf(_on / 1.0, 0.3, 1.0)
	var col := Color("a78bff").lerp(Color("e4dcff"), 1.0 - life)
	# funda alargada que te cubre de pies a cabeza
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(Vector2(cos(a) * 19.0, sin(a) * 31.0 + sin(_t * 8.0 + a * 2.0) * 0.8 + 2.0))
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, (0.17 + _flash * 1.2) * fade))
	pts.append(pts[0])
	draw_polyline(pts, Color(0, 0, 0, 0.6 * fade), 4.0)
	draw_polyline(pts, Color(col.r, col.g, col.b, 0.95 * fade), 2.2)
	draw_arc(Vector2(0, 2), 14.0, PI * 1.1, PI * 1.45, 8, Color(1, 1, 1, 0.75 * fade), 2.0)
	draw_arc(Vector2(0, -27), 15.0, 0.0, TAU, 20, Color(1, 1, 1, 0.4 * fade), 1.5)  # aro abierto de la funda
