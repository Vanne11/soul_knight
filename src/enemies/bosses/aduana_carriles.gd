class_name AduanaCarriles
extends Node2D

## Las ventanillas del Aduanero: la sala (global `area`) dividida en carriles numerados (separadores
## oscuros con el numero arriba). Los que se van a cerrar parpadean con un cartel; los cerrados llevan
## rejas. El dano lo ponen las BossZone TOXIC; esto solo se ve y se borra solo a los `life` segundos.

const PAPER := Color(1.0, 0.85, 0.25)
const RED := Color(0.85, 0.12, 0.15)

var area := Rect2()
var n := 4
var vertical := true        ## true: carriles verticales (se reparten en x)
var closing: Array = []     ## carriles que se cierran
var closed := false         ## ya cerrados (rejas)
var life := 8.0
var _t := 0.0


func _ready() -> void:
	z_index = 2
	add_to_group("boss_breakable")  # el jefe borra esto al cambiar de fase o morir


func _process(delta: float) -> void:
	_t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _lane(i: int) -> Rect2:
	if vertical:
		var w := area.size.x / n
		return Rect2(area.position.x + i * w, area.position.y, w, area.size.y)
	var h := area.size.y / n
	return Rect2(area.position.x, area.position.y + i * h, area.size.x, h)


func _draw() -> void:
	draw_set_transform(-global_position)
	var f := ThemeDB.fallback_font
	var fade := clampf(life / 0.4, 0.0, 1.0)
	for i in n:
		var r := _lane(i)
		draw_rect(r, Color(0.15, 0.1, 0.05, 0.9 * fade), false, 4.0)
		var c := r.position + (Vector2(r.size.x * 0.5 - 12.0, 36.0) if vertical else Vector2(34.0, r.size.y * 0.5 + 12.0))
		var shut := i in closing
		draw_string_outline(f, c, str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 6, Color(0, 0, 0, fade))
		draw_string(f, c, str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, (RED if shut else PAPER) * Color(1, 1, 1, fade))
		if shut and closed:
			var step := 34.0
			var k := 0.0
			var span := r.size.y if vertical else r.size.x
			while k < span:
				var p := r.position + (Vector2(0, k) if vertical else Vector2(k, 0))
				var q := p + (Vector2(r.size.x, 0) if vertical else Vector2(0, r.size.y))
				draw_line(p, q, Color(0.1, 0.06, 0.05, 0.55 * fade), 3.0)
				k += step
