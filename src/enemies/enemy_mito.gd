extends Enemy3a
class_name EnemyMito

## Base de los enemigos MITO (educacion sexual: la censura esparce mitos). Se sostienen mientras
## nadie los cuestione; al vencerlos revelan la VERDAD (burbuja + entrada del codice). El dato de
## cada uno es de referencia y esta pendiente de validar por Vanessa (ver informe).
## Cada mito define: lore_id (entrada del codice), truth_key (E3A_*) y su propia mecanica.

var lore_id := ""
var truth_key := ""
var _truth_done := false


func _setup() -> void:
	personality = "mito"
	_setup_mito()


func _setup_mito() -> void:
	pass


func die(killer: Node = null) -> void:
	if not _truth_done:
		_truth_done = true
		if lore_id != "":
			E3a.reveal_truth(self, lore_id, truth_key)
	super.die(killer)
