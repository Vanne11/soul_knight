extends Node2D

## Medidor minimo bajo los pies del jugador para las armas con mecanica:
## "ammo" = casillas de cargador (y barra de recarga) / "heat" = barra de calor /
## "charge" = barra de carga de la ballesta (parpadea al llegar al maximo).
## Solo se dibuja cuando aporta informacion; el jugador le pasa los valores cada frame.

var kind := ""
var count := 0        # casillas del cargador
var ammo := 0
var progress := -1.0  # recarga 0-1 (-1 = no recarga)
var value := 0.0      # calor 0-1
var locked := false   # sobrecalentada
var _last := ""

const W := 30.0
const H := 4.0

func _ready() -> void:
	position = Vector2(0, 24)
	z_index = 20

func _process(_delta: float) -> void:
	var sig := "%s%d%d%.2f%.2f%s%d" % [kind, count, ammo, progress, value, locked, int(Time.get_ticks_msec() / 90) if locked else 0]
	if sig != _last:
		_last = sig
		queue_redraw()

func _draw() -> void:
	if kind == "ammo":
		if ammo >= count and progress < 0.0:
			return
		if progress >= 0.0:
			_bar(progress, Color("ffd27a"))
		else:
			var w := W / count
			for i in count:
				var r := Rect2(-W * 0.5 + i * w + 1.0, 0, w - 2.0, H)
				draw_rect(r, Color("fff1d6") if i < ammo else Color(0.05, 0.04, 0.06, 0.7))
	elif kind == "charge":
		if value <= 0.02:
			return
		var ccol := Color("ffd27a").lerp(Color("fff7c8"), value)
		if locked and int(Time.get_ticks_msec() / 90) % 2 == 0:
			ccol = Color("ff8a3c")
		_bar(value, ccol)
	elif kind == "heat":
		if value <= 0.02:
			return
		var col := Color("ffd27a").lerp(Color("ff3c2a"), value)
		if locked and int(Time.get_ticks_msec() / 90) % 2 == 0:
			col = Color.WHITE
		_bar(value, col)

func _bar(frac: float, col: Color) -> void:
	draw_rect(Rect2(-W * 0.5 - 1.0, -1.0, W + 2.0, H + 2.0), Color(0.05, 0.04, 0.06, 0.8))
	draw_rect(Rect2(-W * 0.5, 0, W * clampf(frac, 0.0, 1.0), H), col)
