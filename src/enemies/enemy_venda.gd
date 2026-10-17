extends EnemyRanged
class_name EnemyVenda

## Venda en los ojos (bondage; idea de Vanessa): lanza un pano negro que te deja casi a CIEGAS
## unos segundos (solo ves un circulo pequeno alrededor del heroe). Aviso de carga visible.
##   Ornitorrinco  la electrorrecepcion le deja "ver" aunque no vea: venda mas corta.

const BLIND_SCENE := preload("res://src/enemies/projectile_venda.tscn")
## segundos de venda: los fija projectile_venda.tscn (seconds y platypus_mult)


func _ready() -> void:
	E3a.ensure()
	personality = "bondage"
	projectile_scene = BLIND_SCENE
	spread_shots = 1
	fire_rate = 3.4
	charge_time = 0.8
	projectile_speed = 250.0
	preferred_distance = 300.0
	super._ready()


func _fire_projectile(dir: Vector2) -> void:
	super._fire_projectile(dir)
	E3a.say(self, "venda_shoot", 1.4)


func die(killer: Node = null) -> void:
	E3a.note("e3a_venda")
	super.die(killer)
