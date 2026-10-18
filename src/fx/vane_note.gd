extends "res://src/items/interactable.gd"

## La notita de Vane bajo el jefe final: se lee con E y tambien sola la primera vez que pasas
## por encima (la partida termina enseguida; asi no hay que adivinar que es interactuable).
## Respira un poquito para que se note sin gritar.

var _read := false
var _t := 0.0


func _on_enter(body: Node) -> void:
	super._on_enter(body)
	if not _read and body.is_in_group("player"):
		_read = true
		_use(body)


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	scale = Vector2.ONE * (1.0 + 0.05 * sin(_t * 3.0))
