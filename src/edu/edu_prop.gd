extends "res://src/items/interactable.gd"

## Interactuable del consultorio / Mito o Verdad: igual que los de la sala, pero con el
## texto del cuadro calculado al acercarte (precio, si estas contagiado...). Siempre opcional.

var prompt_fn: Callable


func _prompt_text() -> String:
	return prompt_fn.call() if prompt_fn.is_valid() else prompt_text
