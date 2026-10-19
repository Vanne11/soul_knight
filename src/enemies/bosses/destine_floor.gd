extends Node2D
class_name DestineFloor

## El suelo de la pelea contra LA CENSURA QUE DESTINE: la sala es una rejilla de zonas. Cada zona esta
## en COLOR (una franja de la bandera por fila: rojo arriba ... violeta abajo) o en GRIS (destenida).
## Pisar gris te frena y te hace dano en goteo (lo aplica el jefe, ver boss_destine.gd). El jefe
## destiñe zonas (lineas, sellos, contagio) y tu las recolorizas con los orbes de color.
## Se dibuja siempre en color propio (sin material de censura): la sala del jefe esta gris hasta
## que cae, pero esta rejilla tiene que leerse. Posicion = esquina de la arena; coordenadas locales.

const COLS := 6
const ROWS := 6
const FADE_SPEED := 2.4
const CREEP_WARN := 1.0

signal changed

var cell := Vector2(150, 100)
var origin := Vector2.ZERO
var valid := PackedByteArray()
var target := PackedFloat32Array()   ## 1 = gris, 0 = color
var shown := PackedFloat32Array()
var warn := PackedFloat32Array()     ## > 0: se va a destenir (parpadea)
var _t := 0.0


## Crea la rejilla sobre la arena (Rect2 global). `room` decide que zonas son suelo pisable.
static func build(host: Node, arena: Rect2, room: Room) -> DestineFloor:
	var f := DestineFloor.new()
	f.name = "DestineFloor"
	f.origin = arena.position
	f.cell = Vector2(arena.size.x / COLS, arena.size.y / ROWS)
	f.valid.resize(COLS * ROWS)
	f.target.resize(COLS * ROWS)
	f.shown.resize(COLS * ROWS)
	f.warn.resize(COLS * ROWS)
	for i in COLS * ROWS:
		var c: Vector2 = f.center_of(i)
		var ok := true
		if room != null:
			var p := c - room.global_position
			ok = room.cell_kind(Vector2i(floori(p.x / 64.0), floori(p.y / 64.0))) == 0
		f.valid[i] = 1 if ok else 0
	f.z_index = 0
	host.add_child(f)
	f.global_position = arena.position
	return f


func idx(cx: int, cy: int) -> int:
	return cy * COLS + cx


func center_of(i: int) -> Vector2:
	return origin + Vector2((i % COLS + 0.5) * cell.x, (i / COLS + 0.5) * cell.y)


## Zona bajo un punto global (-1 si cae fuera de la rejilla).
func cell_at(p: Vector2) -> int:
	var l := p - origin
	var cx := floori(l.x / cell.x)
	var cy := floori(l.y / cell.y)
	if cx < 0 or cy < 0 or cx >= COLS or cy >= ROWS:
		return -1
	return idx(cx, cy)


func is_gray(i: int) -> bool:
	return i >= 0 and valid[i] == 1 and shown[i] > 0.55


func valid_count() -> int:
	var n := 0
	for i in COLS * ROWS:
		n += valid[i]
	return n


## Fraccion de zonas pisables que estan grises (0..1).
func gray_fraction() -> float:
	var n := 0
	var g := 0
	for i in COLS * ROWS:
		if valid[i] == 1:
			n += 1
			if target[i] > 0.5:
				g += 1
	return float(g) / maxf(n, 1.0)


func gray(i: int) -> void:
	if i >= 0 and valid[i] == 1 and target[i] < 0.5:
		target[i] = 1.0
		warn[i] = 0.0
		changed.emit()


func recolor(i: int) -> void:
	if i >= 0 and valid[i] == 1 and (target[i] > 0.5 or warn[i] > 0.0):
		target[i] = 0.0
		warn[i] = 0.0
		changed.emit()


## Recolorea todas las zonas con centro a menos de `radius` de un punto global. Devuelve cuantas.
func recolor_radius(at: Vector2, radius: float) -> int:
	var n := 0
	for i in COLS * ROWS:
		if valid[i] == 1 and target[i] > 0.5 and center_of(i).distance_to(at) <= radius:
			recolor(i)
			n += 1
	return n


func gray_radius(at: Vector2, radius: float) -> void:
	for i in COLS * ROWS:
		if center_of(i).distance_to(at) <= radius:
			gray(i)


## Destiñe una fila (axis 0) o una columna (axis 1) entera.
func gray_line(axis: int, n: int) -> void:
	for i in COLS * ROWS:
		if (axis == 0 and i / COLS == n) or (axis == 1 and i % COLS == n):
			gray(i)


func recolor_all() -> void:
	for i in COLS * ROWS:
		recolor(i)


## Contagio: avisa y destine una zona de color pegada a una gris (o una al azar si no hay ninguna).
func creep() -> void:
	var cand: Array[int] = []
	for i in COLS * ROWS:
		if valid[i] == 0 or target[i] > 0.5 or warn[i] > 0.0:
			continue
		if _gray_neighbors(i) > 0:
			cand.append(i)
	if cand.is_empty():
		for i in COLS * ROWS:
			if valid[i] == 1 and target[i] < 0.5 and warn[i] <= 0.0:
				cand.append(i)
	if cand.is_empty():
		return
	warn[cand[RNG.randi_range(0, cand.size() - 1)]] = CREEP_WARN


func _gray_neighbors(i: int) -> int:
	var n := 0
	var cx := i % COLS
	var cy := i / COLS
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var x: int = cx + d.x
		var y: int = cy + d.y
		if x >= 0 and y >= 0 and x < COLS and y < ROWS and target[idx(x, y)] > 0.5 and valid[idx(x, y)] == 1:
			n += 1
	return n


func _process(delta: float) -> void:
	_t += delta
	for i in COLS * ROWS:
		if warn[i] > 0.0:
			warn[i] -= delta
			if warn[i] <= 0.0:
				warn[i] = 0.0
				target[i] = 1.0
				changed.emit()
		shown[i] = move_toward(shown[i], target[i], FADE_SPEED * delta)
	queue_redraw()


func _draw() -> void:
	for i in COLS * ROWS:
		if valid[i] == 0:
			continue
		var r := Rect2(Vector2((i % COLS) * cell.x, (i / COLS) * cell.y) + Vector2(3, 3), cell - Vector2(6, 6))
		var s := Arcoiria.stripe(i / COLS)
		var g: float = shown[i]
		# zona de color: baldosa tenue con el tono de su franja y un brillo suave
		var pulse := 0.5 + 0.5 * sin(_t * 2.0 + i * 0.7)
		draw_rect(r, Color(s.color, (0.17 + 0.05 * pulse) * (1.0 - g)))
		draw_rect(r, Color(s.light, 0.35 * (1.0 - g)), false, 2.0)
		if g > 0.01:
			# zona gris: velo plomizo con rayado de censura y borde oscuro
			draw_rect(r, Color(0.42, 0.42, 0.5, 0.62 * g))
			var step := 18.0
			var k := -r.size.y
			while k < r.size.x:
				var a := Vector2(r.position.x + maxf(k, 0.0), r.position.y + maxf(-k, 0.0))
				var len := minf(r.size.x - maxf(k, 0.0), r.size.y - maxf(-k, 0.0))
				if len > 0.0:
					draw_line(a, a + Vector2(len, len), Color(0.14, 0.14, 0.2, 0.5 * g), 3.0)
				k += step
			draw_rect(r, Color(0.1, 0.1, 0.16, 0.9 * g), false, 3.0)
		if warn[i] > 0.0:
			var blink := int(warn[i] * 10.0) % 2 == 0
			draw_rect(r, Color(0.55, 0.55, 0.62, 0.45 if blink else 0.2))
			draw_rect(r, Color(0.9, 0.9, 1.0, 0.8), false, 2.0)
