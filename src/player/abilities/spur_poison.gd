extends Node
class_name SpurPoison

## Veneno del espolon del Ornitorrinco: dano cada `every` segundos durante `ticks` tics.
## Colgado del enemigo; volver a envenenar renueva los tics (no se apila).

var damage := 3.0
var every := 0.5
var ticks := 6
var source: Node = null
var _t := 0.0


func renew(new_ticks: int) -> void:
	ticks = maxi(ticks, new_ticks)


func _ready() -> void:
	var e := get_parent()
	var spr = e.get("animated_sprite")
	if spr:
		spr.self_modulate = Color(0.7, 1.0, 0.6)


func _physics_process(delta: float) -> void:
	var e := get_parent()
	if e == null or not is_instance_valid(e) or float(e.get("current_health")) <= 0.0:
		queue_free()
		return
	_t += delta
	if _t < every:
		return
	_t = 0.0
	ticks -= 1
	BossDamage.tag("", 1.0, "veneno")
	e.take_damage(damage, source if is_instance_valid(source) else null, Vector2.ZERO)
	if ticks <= 0:
		queue_free()


func _exit_tree() -> void:
	var e := get_parent()
	if e and is_instance_valid(e):
		var spr = e.get("animated_sprite")
		if spr:
			spr.self_modulate = Color.WHITE
