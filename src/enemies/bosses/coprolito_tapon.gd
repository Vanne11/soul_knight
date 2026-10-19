extends BossBreakable
class_name CoprolitoTapon

## TAPON de El Coprolito: una roca que se atora en medio de la sala. Bloquea el paso (tuyo y de las balas)
## y se va hinchando: si no la rompes a tiros antes de que se acabe el tiempo, revienta soltando
## fragmentos. Hereda de BossBreakable (grupo "enemy", balas del jugador y del bot, senales broken/expired).
## Se dibuja por codigo (sin arte aparte); el aro blanco es el tiempo que le queda.

const ROCK := Color(0.52, 0.45, 0.37)
const ROCK_DARK := Color(0.2, 0.15, 0.12)
const VEIN := Color(0.33, 0.26, 0.2)
const RADIUS := 30.0


func _ready() -> void:
	kind = Kind.EGG  # solo para el radio base; el dibujo y el choque son propios
	super()
	add_to_group("coprolito_tapon")
	set_collision_layer_value(1, true)  # tapa el paso (balas y heroe); la capa 2 deja golpearlo a tiros
	var cs := get_child(0) as CollisionShape2D
	if cs and cs.shape is CircleShape2D:
		(cs.shape as CircleShape2D).radius = RADIUS


func _draw() -> void:
	if _popped:
		return
	var urgent := life >= 0.0 and remaining() < 1.6
	var wob := Vector2(sin(_t * 60.0) * 2.0, 0.0) if urgent else Vector2.ZERO
	var body := Color(1.7, 1.6, 1.5) if _flash > 0.0 else ROCK
	if urgent and int(_t * 10.0) % 2 == 0:
		body = Color(0.95, 0.55, 0.3)  # a punto de reventar: se pone naranja
	var c := wob + Vector2(0, -6)
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var r := RADIUS * (0.92 + 0.12 * sin(a * 3.0 + 1.0))
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.82))
	draw_colored_polygon(pts, body)
	draw_polyline(pts + PackedVector2Array([pts[0]]), ROCK_DARK, 3.0)
	draw_line(c + Vector2(-12, -10), c + Vector2(-2, 2), VEIN, 3.0)
	draw_line(c + Vector2(-2, 2), c + Vector2(8, -2), VEIN, 3.0)
	draw_line(c + Vector2(8, -2), c + Vector2(14, 10), VEIN, 3.0)
	draw_arc(c + Vector2(8, -10), 6.0, 0.0, TAU * 0.85, 10, VEIN.lightened(0.2), 2.0)  # amonita incrustada
	if life > 0.0:
		var frac := clampf(remaining() / life, 0.0, 1.0)
		draw_arc(c, RADIUS + 6.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, Color(1, 1, 1, 0.9), 3.0)
	var f := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
	draw_rect(Rect2(-22, -54, 44, 6), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(-21, -53, 42.0 * f, 4), Color(1.0, 0.85, 0.2))
