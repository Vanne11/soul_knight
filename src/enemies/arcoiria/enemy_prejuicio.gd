extends Enemy3a
class_name EnemyPrejuicio

## Base de los enemigos-PREJUICIO de Arcoiria (el reino del Orgullo): "Es una fase", "El Armario",
## "¿Y quien es el hombre?" (y "La Etiqueta", a distancia, en enemy_etiqueta.gd). Son ideas hechas
## monstruo: se sostienen mientras nadie las cuestiona y, al vencerlas, dejan la verdad (el humor es
## contra el prejuicio, nunca contra las personas). Cada uno define su id de codice (prej_id) y su
## mecanica; al morir llaman Arcoiria.vencido(): evento "orgullo_vencido_<id>" (abre su entrada del
## codice) y, la primera vez de la partida, el aviso de la verdad (locale/arcoiria.csv, ARC_VERDAD_*).
## Sin IA de personalidad ("none"): cada uno lleva su propia maquina de estados.

var prej_id := ""
var _vencido := false


func _setup() -> void:
	personality = "none"
	_setup_prejuicio()


func _setup_prejuicio() -> void:
	pass


func die(killer: Node = null) -> void:
	if not _vencido:
		_vencido = true
		if prej_id != "":
			Arcoiria.vencido(self, prej_id)
	super.die(killer)
