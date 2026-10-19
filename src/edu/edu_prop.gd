extends "res://src/items/interactable.gd"

## Interactuable del consultorio / Mito o Verdad: igual que los de la sala, pero con el
## texto del cuadro calculado al acercarte (precio, si estas contagiado...). Siempre opcional.
## Si lleva la marca de dato ("badge"), un iconito flota encima y el narrador lo presenta
## una sola vez (la primera vez que te acercas a uno, en toda la partida guardada).

const BADGE := preload("res://src/edu/edu_badge.gd")

var prompt_fn: Callable
var has_badge := false


func _ready() -> void:
	super()
	if has_badge:
		var b := BADGE.new()
		b.position = Vector2(0, badge_y)
		add_child(b)


## Altura (negativa) del iconito sobre el origen del prop.
var badge_y := -50.0


func _on_enter(body: Node) -> void:
	super(body)
	if has_badge and body.is_in_group("player"):
		Narrator.say_once_ever("edu_primer_dato")


func _prompt_text() -> String:
	return prompt_fn.call() if prompt_fn.is_valid() else prompt_text
