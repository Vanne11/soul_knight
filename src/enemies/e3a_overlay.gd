extends Node2D
class_name E3aOverlay

## Capa de dibujo POR ENCIMA del sprite de un enemigo (el _draw del propio CharacterBody2D
## queda debajo de sus hijos). Se le da un Callable que recibe este nodo para dibujar.

var draw_cb: Callable = Callable()


func _draw() -> void:
	if draw_cb.is_valid():
		draw_cb.call(self)
