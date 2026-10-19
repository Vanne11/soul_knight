extends Defense
class_name DefToalla

## TOALLA NOCTURNA (defensa). MANTENER "guard": escudo ABSORBENTE que se carga con el dano que recibe
## (balas de frente y golpes de cerca). Tiene CAP puntos de capacidad: al llenarse hay que "cambiarla"
## (CHANGE_TIME segundos sin poder usarla) y vuelve vacia. "Para flujo abundante": aguanta mucho, pero no
## es infinita. Camina lento y no dispara mientras la sostienes.

const CAP := 60.0
const CHANGE_TIME := 8.0
const WALK_MULT := 0.7
const FRONT_DOT := -0.15  # casi todo el frente y los costados

var charge := 0.0
var absorbed_total := 0.0
var changes := 0
var _change_left := 0.0
var _flash := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("c9b0ff")


func speed_mult() -> float:
	return WALK_MULT if guarding else 1.0


func can_attack() -> bool:
	return not guarding


func _physics_process(delta: float) -> void:
	if player == null:
		return
	if _change_left > 0.0:
		_change_left -= delta
		cooling = true
		guarding = false
		gauge_visible = true
		gauge_value = 1.0 - _change_left / CHANGE_TIME
		gauge_color = Color("8a8498")
		if _change_left <= 0.0:
			charge = 0.0
			changes += 1
			text("DEF_PAD_FRESH", Color("c9b0ff"))
			Sound.play("room_clear", 0.1)
		return
	cooling = false
	guarding = guard_held()
	gauge_visible = charge > 0.0
	gauge_value = 1.0 - charge / CAP
	gauge_color = Color("ff7a9a") if charge > CAP * 0.75 else Color("c9b0ff")


func try_guard(area: Area2D, dmg: float) -> bool:
	if not guarding or not is_projectile(area) or facing_dot(area) < FRONT_DOT:
		return false
	consume(area)
	_soak(dmg)
	return true


func filter_hit(dmg: float) -> float:
	if not guarding or dmg <= 0.0:
		return dmg
	var room := CAP - charge
	_soak(dmg)
	return maxf(0.0, dmg - room)


func _soak(dmg: float) -> void:
	charge = minf(CAP, charge + dmg)
	absorbed_total += dmg
	_flash = 0.2
	Sound.play("crack", 0.1)
	if charge >= CAP:
		guarding = false
		_change_left = CHANGE_TIME
		text("DEF_PAD_FULL", Color("ff7a9a"), 40.0)
		Sound.play("hurt")
	else:
		text("DEF_PAD_SOAK", Color("d8c8ff"))


func _draw_tick() -> void:
	_flash = maxf(0.0, _flash - get_process_delta_time())
	if _change_left > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if not guarding:
		return
	# toalla "de cometa" frente al heroe: el relleno lila sube segun lo absorbido
	var a: float = player._aim.angle()
	var f: Vector2 = Vector2.from_angle(a)
	var n: Vector2 = f.rotated(PI * 0.5)
	var c := f * 17.0
	var pts := PackedVector2Array([c + f * 7.0, c + n * 9.0, c - f * 8.0 + n * 6.0, c - f * 8.0 - n * 6.0, c - n * 9.0])
	draw_colored_polygon(pts, Color(0.96, 0.95, 1.0, 0.95))
	var fill := charge / CAP
	var inner := PackedVector2Array([c + f * 5.0 * fill, c + n * 5.0 * fill, c - f * 6.0 * fill + n * 3.0 * fill, c - f * 6.0 * fill - n * 3.0 * fill, c - n * 5.0 * fill])
	if fill > 0.02:
		draw_colored_polygon(inner, Color(0.78, 0.69, 1.0, 0.9).lerp(Color("ff7a9a"), fill))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]), Color(0, 0, 0, 0.85), 1.5)
	if _flash > 0.0:
		draw_circle(c, 11.0, Color(1, 1, 1, 0.35))
