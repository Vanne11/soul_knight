extends Node
class_name FleeEffect

## Grito de Vulvalquiria: el enemigo al que cuelgan este nodo huye `seconds` segundos.
## Funciona sobre el Enemy base sin editarlo (lo mantiene en STUNNED y lo empuja lejos).
## Si 2b agrega enemy.scare(seconds, from), HeroAbility.scare lo usa en su lugar.

var seconds := 3.0
var from := Vector2.ZERO
const FLEE_SPEED := 150.0


func _physics_process(delta: float) -> void:
	seconds -= delta
	var e := get_parent() as CharacterBody2D
	if e == null or seconds <= 0.0 or not is_instance_valid(e) or float(e.get("current_health")) <= 0.0:
		queue_free()
		return
	var away := (e.global_position - from).normalized()
	if "state" in e and "_state_timer" in e:
		e.state = Enemy.State.STUNNED
		e._state_timer = 0.15
	e.velocity = away * FLEE_SPEED
	var spr = e.get("animated_sprite")
	if spr:
		spr.flip_h = away.x < 0.0


func _exit_tree() -> void:
	var e := get_parent()
	if e and is_instance_valid(e) and "state" in e and e.state != Enemy.State.DEAD:
		e.state = Enemy.State.CHASE
		var spr = e.get("animated_sprite")
		if spr:
			spr.modulate = Color.WHITE
