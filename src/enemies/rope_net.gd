extends StaticBody2D
class_name RopeNet

## Red de cuerda del Shibari: un tramo de pared temporal (capa 1: bloquea al jugador, los bichos
## y las balas enemigas). Tus disparos la ROMPEN: aguanta unos tiros (hit_by_bullet) y se suelta
## sola a los LIFETIME segundos. Son tramos sueltos, no una jaula: siempre se pueden romper.

const LIFETIME := 8.0
var hp := 3.0
var size := Vector2(70, 12)
var _t := 0.0
var _flash := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	add_child(cs)
	add_to_group("rope_net")
	z_index = 2


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	if _t >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func hit_by_bullet(damage: float, _dir: Vector2) -> void:
	hp -= maxf(damage, 1.0) / 8.0
	_flash = 0.12
	if hp <= 0.0:
		var ge := get_node_or_null("/root/GlobalEvents")
		if ge != null:
			ge.show_floating_text.emit(global_position + Vector2(0, -14), Loc.tr_or("E3A_ROPE_CUT", "¡Zas!"), Color("e8a060"))
		queue_free()


func _draw() -> void:
	var a := 1.0
	if _t > LIFETIME - 1.5:
		a = 0.5 + 0.5 * sin(_t * 22.0)
	var rope := Color(0.78, 0.5, 0.26, a)
	var dark := Color(0.1, 0.06, 0.03, a)
	if _flash > 0.0:
		rope = Color(1.0, 0.9, 0.7, a)
	var h := size.x * 0.5
	# dos cuerdas trenzadas en zigzag
	var prev1 := Vector2(-h, -3)
	var prev2 := Vector2(-h, 3)
	var n := 14
	for i in range(1, n + 1):
		var x := -h + size.x * float(i) / n
		var y1 := -3.0 if i % 2 == 0 else 3.0
		var y2 := -y1
		draw_line(prev1, Vector2(x, y1), dark, 4.0)
		draw_line(prev2, Vector2(x, y2), dark, 4.0)
		draw_line(prev1, Vector2(x, y1), rope, 2.0)
		draw_line(prev2, Vector2(x, y2), rope, 2.0)
		prev1 = Vector2(x, y1)
		prev2 = Vector2(x, y2)
	for sx in [-h, h]:
		draw_circle(Vector2(sx, 0), 5.0, dark)
		draw_circle(Vector2(sx, 0), 3.5, rope)
