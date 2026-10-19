extends BossZone
class_name RulerZone

## Zona de PELIGRO de Dona Regla (y de sus Centimetros): una regla de medir roja con marcas.
## Aviso: contorno rojo oscuro que parpadea y una franja que se va llenando; activa: regla roja
## solida con las rayitas oscuras (barras) o reloj con 12 marcas (circulos). Borde siempre
## oscuro/rojizo, nunca blanco, para que no se confunda con lo que hay que TOCAR (BossZone, J3b).
## Misma logica que BossZone (aviso -> activa -> desvanece; dano por geometria): solo cambia el dibujo.

const RED := Color(0.95, 0.22, 0.28)
const DARK := Color(0.30, 0.03, 0.08)
const TICK := 18.0


static func bar(pos: Vector2, size_: Vector2, rot: float, warn_: float, active_: float, dmg: float, col := RED) -> RulerZone:
	var z := RulerZone.new()
	z.shape = Shape.RECT
	z.size = size_
	z.rotation = rot
	z.warn = warn_
	z.active = active_
	z.damage = dmg
	z.color = col
	z.position = pos
	return z


static func disc(pos: Vector2, r: float, warn_: float, active_: float, dmg: float, col := RED) -> RulerZone:
	var z := RulerZone.new()
	z.radius = r
	z.warn = warn_
	z.active = active_
	z.damage = dmg
	z.color = col
	z.position = pos
	return z


func _ready() -> void:
	super()
	material = null  # el peligro conserva su color aunque la sala siga censurada


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 22.0)
	var a := 1.0
	var p := 1.0
	if phase == 0:
		p = clampf(t / maxf(warn, 0.01), 0.0, 1.0)
	elif phase == 2:
		a = 1.0 - clampf(t / maxf(fade, 0.01), 0.0, 1.0)
	if shape == Shape.RECT and size.y <= 12.0:
		draw_rect(Rect2(-size * 0.5, size), Color(color, 0.5 + 0.4 * pulse))  # linea de punteria fina
		return
	if shape == Shape.CIRCLE:
		_draw_dial(p, a, pulse)
	else:
		_draw_ruler(p, a, pulse)


func _draw_ruler(p: float, a: float, pulse: float) -> void:
	var r := Rect2(-size * 0.5, size)
	var on := phase >= 1
	if on:
		draw_rect(r, Color(color, 0.86 * a))
		draw_rect(Rect2(-size.x * 0.5, -size.y * 0.5, size.x, size.y * 0.22), Color(DARK, 0.35 * a))  # canto
	else:
		draw_rect(r, Color(color, 0.08 + 0.12 * p))
		draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y * 0.5 * p), Vector2(size.x, size.y * p)), Color(DARK, 0.28 + 0.2 * p))
	# marcas de la regla a lo largo (el lado largo es x si es mas ancha que alta)
	var long_x := size.x >= size.y
	var ln := size.x if long_x else size.y
	var wid := size.y if long_x else size.x
	var n := int(ln / TICK)
	for i in n + 1:
		var u := -ln * 0.5 + i * TICK
		var big := i % 5 == 0
		var tl := wid * (0.42 if big else 0.22)
		var col := Color(DARK, (0.95 if on else 0.6) * a)
		if long_x:
			draw_line(Vector2(u, size.y * 0.5), Vector2(u, size.y * 0.5 - tl), col, 2.0 if big else 1.0)
		else:
			draw_line(Vector2(size.x * 0.5, u), Vector2(size.x * 0.5 - tl, u), col, 2.0 if big else 1.0)
	var edge := Color(DARK.lerp(RED, pulse), a) if not on else Color(DARK, a)
	draw_rect(r, edge, false, 4.0)


func _draw_dial(p: float, a: float, pulse: float) -> void:
	var on := phase >= 1
	if on:
		draw_circle(Vector2.ZERO, radius, Color(color, 0.82 * a))
		draw_circle(Vector2.ZERO, radius * 0.62, Color(DARK, 0.22 * a))
	else:
		draw_circle(Vector2.ZERO, radius, Color(color, 0.08 + 0.1 * p))
		draw_circle(Vector2.ZERO, radius * p, Color(DARK, 0.3))
	for i in 12:
		var ang := i * TAU / 12.0
		var d := Vector2.RIGHT.rotated(ang)
		var big := i % 3 == 0
		draw_line(d * radius * (0.8 if big else 0.88), d * radius * 0.97, Color(DARK, (0.95 if on else 0.65) * a), 3.0 if big else 2.0)
	# la manecilla corre mientras avisa: "puntual"
	var hand := Vector2.RIGHT.rotated(-PI * 0.5 + TAU * (p if phase == 0 else 1.0))
	draw_line(Vector2.ZERO, hand * radius * 0.72, Color(DARK, a), 4.0)
	draw_circle(Vector2.ZERO, 5.0, Color(DARK, a))
	var edge := Color(DARK.lerp(RED, pulse), a) if not on else Color(DARK, a)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, edge, 4.0)
