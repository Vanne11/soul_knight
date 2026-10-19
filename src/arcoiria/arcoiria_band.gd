class_name ArcoiriaBand
extends Node2D

## La franja de la bandera que aparece en una sala de Arcoiria al liberarla: una banda de color
## cruza el suelo (la fila que le toca a su franja: rojo arriba ... violeta abajo, como la bandera)
## con un brillo que la recorre. En salas oscuras suma dos luces del color para que se note.
## La sala nace gris (Censor) y la franja es lo primero que trae color: no usa el material de censura.

const TILE := 64
const ROWS := 6
const FADE := 1.2

var color := Color.WHITE
var light := Color.WHITE
var row := 0
var size := Vector2(1024, 640)
var _a := 0.0
var _t := 0.0


## Crea la franja `idx` (0..5 = rojo..violeta; mas alla vuelve a empezar) en la sala.
static func build(room: Room, idx: int) -> ArcoiriaBand:
	var s := Arcoiria.stripe(idx)
	var b := ArcoiriaBand.new()
	b.name = "ArcoiriaBand"
	b.color = s.color
	b.light = s.light
	b.row = posmod(idx, ROWS)
	b.size = Vector2(room.floor_tilemap.get_used_rect().size) * TILE
	room.add_child(b)
	room.move_child(b, room.floor_tilemap.get_index() + 1)  # sobre el suelo, bajo los actores
	var cy := (b.row + 0.5) * b.size.y / ROWS
	for fx in [0.25, 0.75]:
		var l := LightKit.make_light(s.color, 0.55, 2.6, false)
		l.position = Vector2(b.size.x * fx, cy)
		b.add_child(l)
	b.create_tween().tween_property(b, "_a", 1.0, FADE)
	return b


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _a <= 0.0:
		return
	var h := size.y / ROWS
	var r := Rect2(0.0, row * h + h * 0.08, size.x, h * 0.84)
	draw_rect(r, Color(color, 0.26 * _a))
	draw_rect(Rect2(r.position.x, r.position.y + r.size.y * 0.32, size.x, r.size.y * 0.36), Color(light, 0.14 * _a))
	draw_line(r.position, r.position + Vector2(size.x, 0.0), Color(light, 0.55 * _a), 2.0)
	draw_line(r.position + Vector2(0.0, r.size.y), r.end, Color(color, 0.55 * _a), 2.0)
	# brillo que recorre la franja
	var sx := fmod(_t * 140.0, size.x + 240.0) - 120.0
	draw_rect(Rect2(sx, r.position.y, 90.0, r.size.y), Color(1, 1, 1, 0.10 * _a))
