extends EnemyRanged
class_name EnemyMordaza

## La Mordaza (bondage, tema censura/represion; idea de Vanessa): lanza bolas con correa que te
## SILENCIAN: sin habilidades de heroe unos segundos (escudo, alas, grito, huevo, espolon) y el
## narrador se calla. Carga con aviso visible, como cualquier enemigo a distancia.
## Una sola bola por salva (no abanico): lo que duele es el silencio, no el dano.

const GAG_SCENE := preload("res://src/enemies/projectile_mordaza.tscn")
const GAG_TIME := 5.0


func _ready() -> void:
	E3a.ensure()
	personality = "bondage"
	projectile_scene = GAG_SCENE
	spread_shots = 1
	fire_rate = 3.2
	charge_time = 0.75
	projectile_speed = 270.0
	preferred_distance = 320.0
	super._ready()


func _fire_projectile(dir: Vector2) -> void:
	super._fire_projectile(dir)
	E3a.say(self, "mordaza_shoot", 1.4)


func die(killer: Node = null) -> void:
	E3a.note("e3a_mordaza")
	super.die(killer)
