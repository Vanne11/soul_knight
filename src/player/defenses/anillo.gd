extends Defense
class_name DefAnillo

## ANILLO VAGINAL (defensa PASIVA). Un aro flexible de hormonas: AURA continua de radio RADIUS que EMPUJA a
## los enemigos cercanos (PUSH px/s) lejos de ti, sin tocar la guard del heroe. No empuja a los jefes ni a
## quien esta en plena embestida. Un metodo que se coloca y "se cambia segun indicacion": aqui, siempre activo.

const RADIUS := 100.0
const PUSH := 80.0
const LUNGE_STATE := 3  # Enemy.State.LUNGE

var pushed := 0
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("ff9ec8")


func is_passive() -> bool:
	return true


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var here: Vector2 = player.global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is CharacterBody2D) or e.is_in_group("boss"):
			continue
		if float(e.get("current_health")) <= 0.0 or int(e.get("state")) == LUNGE_STATE:
			continue
		var to: Vector2 = (e as Node2D).global_position - here
		var d := to.length()
		if d >= RADIUS or d < 1.0:
			continue
		var k := 1.0 - d / RADIUS * 0.5  # mas fuerte cerca del aro
		(e as CharacterBody2D).move_and_collide(to / d * PUSH * k * delta)
		pushed += 1


func _draw_tick() -> void:
	_t += get_process_delta_time()
	queue_redraw()


func _draw_body() -> void:
	for i in 3:
		var k := fposmod(_t * 0.7 + i / 3.0, 1.0)
		draw_arc(Vector2.ZERO, RADIUS * (0.35 + 0.65 * k), 0.0, TAU, 40, Color(1.0, 0.62, 0.8, 0.22 * (1.0 - k)), 2.0)
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(1.0, 0.62, 0.8, 0.10), 1.5)
