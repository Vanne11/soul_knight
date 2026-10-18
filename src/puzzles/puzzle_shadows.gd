extends Puzzle
class_name PuzzleShadows

## Sombras (acertijo creativo, cualquier reino). Una o dos antorchas fijas proyectan TU
## sombra por el suelo (la misma que el juego dibuja con la luz) y hay placas con un sol
## que no se pisan: se tapan. Nadie lo explica: la sombra y las placas se explican solas.
## Hay que pararse en el sitio justo para que la sombra de cada antorcha caiga sobre su
## placa y aguantar un rato. Siempre tiene solucion: se elige primero donde estara el
## heroe y de ahi se colocan las placas. Dificultad: 1 antorcha y placa, luego 2 y 2.

const COVER := 1.1        # segundos tapadas todas las placas
const SHADOW_W := 22.0
const HIT_R := 9.0        # tolerancia de la sombra sobre el centro de la placa

var _lamps: Array[Vector2] = []
var _plates: Array[PuzzlePlate] = []
var _shadows: Array[Sprite2D] = []
var _stand := Vector2.ZERO   # donde se resuelve (para el bot)
var _hold := 0.0
var _idle := 0.0
var _on_plate := false
var _covered: Array[bool] = []


func build() -> void:
	kind = "shadows"
	var n := 1 if depth < 3 else 2
	var hx := clampf(area.x * 0.5 - 6.0, 90.0, 190.0)
	var hy := clampf(area.y * 0.5 - 4.0, 60.0, 110.0)
	var tries := 0
	while true:
		tries += 1
		_lamps.clear()
		var plates: Array[Vector2] = []
		_stand = Vector2(rng.randf_range(0.3, 0.65) * hx * (1.0 if rng.randf() < 0.5 else -1.0), rng.randf_range(-0.1, 0.45) * hy)
		var ok := true
		var flip := rng.randf() < 0.5
		for i in n:
			var lamp := Vector2(hx if (i == 1 or (n == 1 and flip)) else -hx, -hy)
			_lamps.append(lamp)
			var cast := _cast(lamp, _stand)
			var p: Vector2 = _stand + cast.dir * cast.len * 0.62
			if absf(p.x) > hx - 12.0 or absf(p.y) > hy - 4.0 or p.distance_to(_stand) < 26.0:
				ok = false
			plates.append(p)
		if n == 2 and plates[0].distance_to(plates[1]) < 36.0:
			ok = false
		if ok or tries > 200:
			_make(plates, hx, hy)
			break


## Sombra de un heroe en `foot` (local) desde la antorcha `lamp`: direccion y largo.
func _cast(lamp: Vector2, foot: Vector2) -> Dictionary:
	var to_foot := foot - lamp
	var dist := maxf(to_foot.length(), 1.0)
	return {"dir": to_foot / dist, "len": lerpf(52.0, 118.0, clampf(dist / 230.0, 0.0, 1.0)), "dist": dist}


func _make(plates: Array[Vector2], _hx: float, _hy: float) -> void:
	for i in _lamps.size():
		var lamp_spr := make_sprite("lamp", _lamps[i] + Vector2(0, -8), 1)
		lamp_spr.set_meta("lamp", true)
		var glow := ActorFx.add_glow(lamp_spr, Color(1.0, 0.75, 0.3), 0.7, 1.0)
		glow.position = Vector2(0, -14)
		var s := Sprite2D.new()
		s.texture = LightKit.cast_texture()
		s.centered = false
		s.offset = Vector2(0, -32)
		s.position = Vector2.ZERO
		s.z_index = 1
		s.modulate = Color(1, 1, 1, 0.0)
		add_child(s)
		_shadows.append(s)
	for p in plates:
		var pl := PuzzlePlate.new().setup(kingdom, false)
		pl.position = p
		pl.set_glyph("glyph_sun", -4.0)
		pl.base().use_parent_material = true
		pl.glyph().use_parent_material = true
		gray(pl)
		add_child(pl)
		_plates.append(pl)
		_covered.append(false)


func _physics_process(delta: float) -> void:
	if done:
		return
	var pl := player()
	if pl == null:
		return
	var foot := to_local(pl.global_position + Vector2(0, 10))
	var all := true
	var on_plate := false
	for i in _lamps.size():
		var c := _cast(_lamps[i], foot)
		var s := _shadows[i]
		var near: bool = c.dist < 300.0
		s.position = foot
		s.rotation = (c.dir as Vector2).angle()
		s.scale = Vector2(c.len / 64.0, SHADOW_W / 64.0)
		s.modulate.a = lerpf(s.modulate.a, 0.62 if near else 0.0, 0.3)
		var hit := false
		if near:
			var tip: Vector2 = foot + c.dir * c.len
			var d := _dist_to_segment(_plates[i].position, foot, tip)
			hit = d < HIT_R and foot.distance_to(_plates[i].position) > 18.0
		if foot.distance_to(_plates[i].position) < 16.0:
			on_plate = true
		if hit != _covered[i]:
			_covered[i] = hit
			_plates[i].set_pressed(hit)
			_plates[i].set_glyph("glyph_moon" if hit else "glyph_sun", -4.0)
			if hit:
				Sound.play("crack", 0.1)
		all = all and hit
	if on_plate and not _on_plate:
		Sound.play("puzzle_fail")
		note_fail()
	_on_plate = on_plate
	if all:
		_hold += delta
		_idle = 0.0
		for p in _plates:
			p.modulate = Color.WHITE.lerp(Color(1.5, 1.4, 0.9), clampf(_hold / COVER, 0.0, 1.0))
		if _hold >= COVER:
			for p in _plates:
				p.flash(Color(1.8, 1.7, 1.2), 1.0)
				p.set_glyph("glyph_sun", -4.0)
			for s in _shadows:
				s.create_tween().tween_property(s, "modulate:a", 0.0, 0.6)
			solve()
	else:
		_hold = maxf(0.0, _hold - delta * 2.0)
		for p in _plates:
			p.modulate = Color.WHITE
		_idle += delta
		if _idle > 18.0:  # un buen rato sin dar con ello: pista
			_idle = 0.0
			note_fail()


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _bot_plan(_from: Vector2) -> Array:
	return [_wp(_stand - Vector2(0, 10))]
