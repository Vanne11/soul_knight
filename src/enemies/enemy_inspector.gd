extends EnemyRanged
class_name EnemyInspector

## Inspector de Fluidos: enemigo a distancia. Misma IA y mismos numeros que el
## EnemyRanged (carga, ventana para esquivar, 3 disparos en abanico); solo cambia
## el proyectil: sellos de RECHAZADO que rebotan una vez en la pared.

const SELLO_SCENE := preload("res://src/enemies/projectile_sello.tscn")


func _ready() -> void:
	projectile_scene = SELLO_SCENE
	super._ready()
