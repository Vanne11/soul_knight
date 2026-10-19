class_name TurnoCola
extends Node2D

## Marcador de turnos de La Ventanilla Unica, bajo sus pies (la cabeza la tapa el HUD): el numero que
## se atiende ahora (grande) y la cola de los que vienen. El que sigue parpadea y se llena: cuando se
## llena, ese turno dispara. `prog` 0..1 es el avance del aviso del turno actual.

const PAPER := Color(1.0, 0.85, 0.45)
const DARK := Color(0.12, 0.09, 0.05, 0.9)
const RED := Color(0.85, 0.15, 0.15)

var current := 0
var queue: Array = []
var prog := 0.0
var _t := 0.0


func _ready() -> void:
	z_index = 5
	position = Vector2(0, 30)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(-62, 0, 124, 36), DARK)
	draw_rect(Rect2(-62, 0, 124, 36), RED if prog > 0.0 else PAPER, false, 3.0)
	if prog > 0.0:
		draw_rect(Rect2(-60, 32, 120.0 * clampf(prog, 0.0, 1.0), 2), RED)
	draw_string(f, Vector2(-56, 14), tr("TURNO_NOW"), HORIZONTAL_ALIGNMENT_LEFT, 112, 11, PAPER)
	draw_string_outline(f, Vector2(-56, 32), "N° %03d" % current, HORIZONTAL_ALIGNMENT_LEFT, 112, 22, 4, Color(0, 0, 0))
	draw_string(f, Vector2(-56, 32), "N° %03d" % current, HORIZONTAL_ALIGNMENT_LEFT, 112, 22, Color(1.0, 0.95, 0.6))
	var n := mini(queue.size(), 6)
	var x0 := -float(n) * 17.0
	for i in n:
		var r := Rect2(x0 + i * 34.0, 42.0, 30.0, 20.0)
		var first := i == 0
		var pulse := 0.5 + 0.5 * sin(_t * 14.0)
		draw_rect(r, DARK)
		draw_rect(r, (RED if pulse > 0.5 else PAPER) if first else PAPER, false, 2.0 if first else 1.5)
		draw_string(f, r.position + Vector2(2, 15), "%d" % int(queue[i]), HORIZONTAL_ALIGNMENT_CENTER, 26, 14, PAPER)
