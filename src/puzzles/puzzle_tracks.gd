extends Puzzle
class_name PuzzleTracks

## Huellas (acertijo creativo, cualquier reino). Algo que no se ve cruzo la sala por el
## barro y dejo huellas de tres dedos. Hay que seguirlas hasta el botin que escondio. En los
## cruces solo un camino es el bueno: en el falso las huellas apuntan HACIA el cruce (lo que
## las hizo venia de vuelta de la madriguera vacia), y pisar ese final no cuesta mas que
## que el narrador se rie. Nadie lo explica. Las huellas se ven mejor al acercarse.
## Dificultad: uno, dos o tres cruces.

const STEP := 15.0
const SEE_NEAR := 56.0
const SEE_FAR := 120.0

var _route: Array[Vector2] = []     # camino bueno: salida, cruces, botin
var _prints: Array[Sprite2D] = []
var _dead: Array[Vector2] = []
var _dead_spr: Array[Sprite2D] = []
var _prize: Sprite2D
var _prize_pos := Vector2.ZERO
var _hit_dead := -1.0


func build() -> void:
	kind = "tracks"
	var hx := clampf(area.x * 0.5 - 14.0, 90.0, 190.0)
	var hy := clampf(area.y * 0.5 - 10.0, 56.0, 100.0)
	var forks := clampi(1 + depth / 3, 1, 3)
	# barro de fondo
	for x in range(-int(hx) + 30, int(hx), 70):
		for y in [-hy * 0.45, hy * 0.45]:
			var m := make_sprite("mud_patch", Vector2(x, y + rng.randf_range(-6.0, 6.0)), 0)
			m.modulate = Color(1, 1, 1, 0.5)
	# camino bueno: de izquierda a derecha, zigzag; un cruce en cada tramo
	var xs: Array[float] = []
	for i in forks + 2:
		xs.append(lerpf(-hx + 12.0, hx - 16.0, float(i) / float(forks + 1)))
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	for i in xs.size():
		var y := rng.randf_range(0.15, 0.7) * hy * side
		if i == 0:
			y = rng.randf_range(-0.2, 0.2) * hy
		_route.append(Vector2(xs[i], y))
		side = -side
	_prize_pos = _route[_route.size() - 1]
	# rutas falsas: salen de cada cruce y mueren en una madriguera vacia
	for i in range(1, _route.size() - 1):
		var f := _route[i]
		var d := f
		for _try in 12:  # un final que no quede cerca del camino bueno
			var away := Vector2(rng.randf_range(-0.3, 0.8), signf(-f.y) if f.y != 0.0 else 1.0).normalized()
			if _try > 5:
				away.y = -away.y
			d = f + away * rng.randf_range(40.0, 66.0)
			d.x = clampf(d.x, -hx + 10.0, hx - 10.0)
			d.y = clampf(d.y, -hy + 8.0, hy - 8.0)
			if _dist_to_route(d, i) > 30.0:
				break
		_dead.append(d)
		_trail(d, f, true)   # sus huellas VUELVEN hacia el cruce
	for i in range(_route.size() - 1):
		_trail(_route[i], _route[i + 1], false)
	for d in _dead:
		_dead_spr.append(make_sprite("track_hole", d, 0))
	_prize = make_sprite("track_sack", _prize_pos + Vector2(0, -8), 1)
	LightKit.add_contact_shadow(_prize, 9.0, 9.0)
	# que el barro y las huellas se vean desde el principio, tenues
	_update_visibility()


## Distancia de p al camino bueno, sin contar el tramo que sale del cruce `skip` (donde nace).
func _dist_to_route(p: Vector2, skip: int) -> float:
	var best := INF
	for k in range(_route.size() - 1):
		if k == skip or k == skip - 1:
			continue
		var a := _route[k]
		var ab := _route[k + 1] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## Huellas de a -> b, una de cada pie, apuntando en el sentido de la marcha.
func _trail(a: Vector2, b: Vector2, _fake: bool) -> void:
	var dir := (b - a).normalized()
	var n := int((b - a).length() / STEP)
	var foot := 1.0
	for i in range(1, n):
		var p := a + dir * (STEP * i) + dir.orthogonal() * 3.5 * foot
		foot = -foot
		var s := make_sprite("track_print", p, 0)
		s.rotation = dir.angle() + PI * 0.5
		s.modulate.a = 0.0
		_prints.append(s)


func _process(delta: float) -> void:
	if not done:
		_update_visibility()
		idle_hint(delta, 28.0)


func _update_visibility() -> void:
	var pl := player()
	var pp := to_local(pl.global_position + Vector2(0, 10)) if pl else Vector2(-9999, -9999)
	for s in _prints:
		var d := s.position.distance_to(pp)
		s.modulate.a = lerpf(0.9, 0.35, clampf((d - SEE_NEAR) / (SEE_FAR - SEE_NEAR), 0.0, 1.0))


func _physics_process(delta: float) -> void:
	if done:
		return
	_hit_dead = maxf(0.0, _hit_dead - delta)
	var pl := player()
	if pl == null:
		return
	var foot := to_local(pl.global_position + Vector2(0, 10))
	if foot.distance_to(_prize_pos) < 16.0:
		_prize.create_tween().tween_property(_prize, "scale", Vector2(1.3, 1.3), 0.15)
		_prize.create_tween().tween_property(_prize, "modulate", Color(1.8, 1.7, 1.2), 0.15)
		solve()
		return
	for i in _dead.size():
		if foot.distance_to(_dead[i]) < 13.0 and _hit_dead <= 0.0:
			_hit_dead = 2.0
			Sound.play("puzzle_fail")
			var sp := _dead_spr[i]
			sp.create_tween().tween_property(sp, "modulate", Color.WHITE, 0.5).from(Color(1.0, 0.4, 0.4))
			note_fail(1)


func _bot_plan(_from: Vector2) -> Array:
	var plan: Array = []
	for p in _route:
		plan.append(_wp(p - Vector2(0, 10)))
	return plan
