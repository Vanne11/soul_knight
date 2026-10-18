extends RefCounted
class_name BossNotebook

## CUADERNO DEL JUGADOR (J1e): modulo comun que los jefes usan para "aprender" como juegas.
## Anota hacia donde dasheas, en que sentido lo rodeas, a que distancia te quedas, en que zona
## de la sala estas y que arma usas. Todo con OLVIDO gradual (los pesos decaen con el tiempo),
## asi que si cambias de habito el jefe tambien tiene que cambiar su lectura.
## Uso: crear uno, llamar update(delta, jugador, jefe, sala) cada frame y consultar
## dash_pattern() / orbit_pattern() / ... O escuchar la senal pattern_detected.

## Se emite una sola vez cuando un habito pasa el umbral (y se rearma al perderse).
signal pattern_detected(kind: StringName, detail: Variant)

## Segundos para que un recuerdo pierda ~63% de su peso.
var forget_secs := 28.0
## Cuanto pesa un habito para considerarlo "patron": parte de las muestras y minimo de ellas.
var share_needed := 0.72
var weight_needed := 2.4

var _dash := {&"izq": 0.0, &"der": 0.0, &"arriba": 0.0, &"abajo": 0.0}
var _dash_spots: Array = []  # [{pos, w}] donde terminaste cada dash (global)
var _orbit := {&"horario": 0.0, &"antihorario": 0.0}
var _dist_avg := 0.0
var _dist_w := 0.0
var _zone := {}  # celda "x,y" de la sala (3x3) -> tiempo
var _weapons := {}  # id de arma -> tiempo
var _was_dashing := false
var _prev_rel := Vector2.ZERO
var _armed := {}  # kind -> true mientras el patron esta activo (evita repetir el aviso)
var _dash_start := Vector2.ZERO


func update(delta: float, player: Node2D, boss: Node2D, room: Rect2) -> void:
	if player == null or boss == null:
		return
	var k := exp(-delta / forget_secs)
	for key in _dash:
		_dash[key] *= k
	for key in _orbit:
		_orbit[key] *= k
	for key in _zone:
		_zone[key] *= k
	for key in _weapons:
		_weapons[key] *= k
	for s in _dash_spots:
		s.w *= k
	_dash_spots = _dash_spots.filter(func(s): return s.w > 0.15)
	_dist_w *= k
	var rel := player.global_position - boss.global_position
	# dash: al empezar anota la direccion; al terminar, donde cayo
	var dashing: bool = bool(player.get("is_dashing"))
	if dashing and not _was_dashing:
		var d: Vector2 = player.get("_dash_direction")
		if d == Vector2.ZERO:
			d = (player.get("velocity") as Vector2)
		if d != Vector2.ZERO:
			_note_dash(d.normalized())
		_dash_start = player.global_position
	elif _was_dashing and not dashing:
		_dash_spots.append({"pos": player.global_position, "w": 1.0})
		if _dash_spots.size() > 12:
			_dash_spots.pop_front()
	_was_dashing = dashing
	# sentido en que lo rodeas (giro del vector jefe->jugador), solo a media distancia
	var dist := rel.length()
	if dist > 70.0 and dist < 460.0 and _prev_rel != Vector2.ZERO and not dashing:
		var cr := _prev_rel.normalized().cross(rel.normalized())
		if absf(cr) > 0.002:
			var key := &"horario" if cr > 0.0 else &"antihorario"  # y hacia abajo: cross > 0 = horario en pantalla
			_orbit[key] += delta * clampf(absf(cr) * 40.0, 0.0, 1.0)
	_prev_rel = rel
	# distancia preferida
	_dist_avg = (_dist_avg * _dist_w + dist * delta) / maxf(_dist_w + delta, 0.0001)
	_dist_w += delta
	# zona de la sala (3x3)
	if room.size.x > 1.0:
		var cx := clampi(int((player.global_position.x - room.position.x) / room.size.x * 3.0), 0, 2)
		var cy := clampi(int((player.global_position.y - room.position.y) / room.size.y * 3.0), 0, 2)
		var zk := "%d,%d" % [cx, cy]
		_zone[zk] = float(_zone.get(zk, 0.0)) + delta
	# arma en la mano
	var w = player.get("current_weapon")
	if w != null and "id" in w:
		var wid := str(w.id)
		_weapons[wid] = float(_weapons.get(wid, 0.0)) + delta
	_check_patterns()


func _note_dash(d: Vector2) -> void:
	if absf(d.x) >= absf(d.y):
		_dash[&"der" if d.x > 0.0 else &"izq"] += 1.0
	else:
		_dash[&"abajo" if d.y > 0.0 else &"arriba"] += 1.0


## Habito de dash: {dir, share, weight} si el mismo lado pasa el umbral; si no, {}.
func dash_pattern() -> Dictionary:
	return _top(_dash, weight_needed, share_needed)


## Habito de rodeo: {dir: &"horario"/&"antihorario", share, weight}.
func orbit_pattern() -> Dictionary:
	return _top(_orbit, 3.5, 0.78)


func _top(d: Dictionary, wmin: float, smin: float) -> Dictionary:
	var total := 0.0
	var best: StringName = &""
	var bw := 0.0
	for key in d:
		total += d[key]
		if d[key] > bw:
			bw = d[key]
			best = key
	if total <= 0.0 or bw < wmin or bw / total < smin:
		return {}
	return {"dir": best, "share": bw / total, "weight": bw}


## Donde sueles caer despues de un dash (promedio ponderado de los ultimos), o Vector2.INF.
func dash_spot() -> Vector2:
	var sum := Vector2.ZERO
	var tw := 0.0
	for s in _dash_spots:
		sum += (s.pos as Vector2) * s.w
		tw += s.w
	return sum / tw if tw > 0.5 else Vector2.INF


## Distancia media a la que te quedas del jefe (0 si aun no hay datos).
func preferred_distance() -> float:
	return _dist_avg if _dist_w > 3.0 else 0.0


## Zona 3x3 donde mas estas ("x,y") o "" si todavia no se sabe.
func favorite_zone() -> String:
	var best := ""
	var bw := 0.0
	var total := 0.0
	for key in _zone:
		total += _zone[key]
		if _zone[key] > bw:
			bw = _zone[key]
			best = key
	return best if total > 6.0 and bw / total > 0.45 else ""


func favorite_weapon() -> String:
	var best := ""
	var bw := 0.0
	for key in _weapons:
		if _weapons[key] > bw:
			bw = _weapons[key]
			best = key
	return best


## Direccion unitaria (mundo) de un nombre de dash.
static func dir_vector(name: StringName) -> Vector2:
	match name:
		&"izq":
			return Vector2.LEFT
		&"der":
			return Vector2.RIGHT
		&"arriba":
			return Vector2.UP
		&"abajo":
			return Vector2.DOWN
	return Vector2.ZERO


func _check_patterns() -> void:
	_edge(&"dash", dash_pattern())
	_edge(&"orbit", orbit_pattern())


func _edge(kind: StringName, p: Dictionary) -> void:
	if p.is_empty():
		_armed.erase(kind)
		return
	if _armed.has(kind):
		return
	_armed[kind] = true
	pattern_detected.emit(kind, p)
