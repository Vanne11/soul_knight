class_name AffixBlast
extends Node2D

## Reventon de un elite Explosivo: aviso (circulo que se llena y parpadea) y despues la explosion
## con el mismo radio. Vive en la sala, no en el enemigo (el enemigo ya murio).

var radius := 78.0
var fuse := 1.1
var damage := 10.0
var color := Color("ff8a2a")
var _t := 0.0
var _boom := false


func _ready() -> void:
	z_index = -1
	add_to_group("affix_blast")


func _process(delta: float) -> void:
	_t += delta
	if not _boom and _t >= fuse:
		_boom = true
		_explode()
	if _boom and _t >= fuse + 0.1:
		queue_free()
		return
	queue_redraw()


func _explode() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null and p.global_position.distance_to(global_position) <= radius + 10.0 and p.has_method("receive_hit"):
		p.receive_hit(damage)
	var fx := ExplosionFx.new()
	fx.radius = radius
	get_parent().add_child(fx)
	fx.global_position = global_position
	HitFx.shake(0.35)


func _draw() -> void:
	if _boom:
		return
	var k := clampf(_t / fuse, 0.0, 1.0)
	var rate := lerpf(4.0, 22.0, k)
	var on := int(_t * rate) % 2 == 0
	draw_circle(Vector2.ZERO, radius * k, Color(color.r, color.g, color.b, 0.22 if on else 0.4))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, 0.95 if on else 0.5), 2.5)
