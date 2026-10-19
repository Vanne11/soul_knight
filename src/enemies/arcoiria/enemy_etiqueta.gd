extends EnemyRanged
class_name EnemyEtiqueta

## "LA ETIQUETA": un cartel de precio con patitas que te pega etiquetas SIN PREGUNTAR. Escupe una
## etiqueta adhesiva (ProjectileEtiqueta) que, si te da, se te pega y te FRENA (estado "etiquetado" de
## StatusEffects, hasta 3 etiquetas apiladas, cada una mas lenta). Se arrancan con el DASH: al
## romperlas hacen DANO EXTRA en un anillo a tu alrededor (Arcoiria.rip_labels), asi que ser
## etiquetado y esquivar a lo grande te devuelve el golpe.
## Verdad: las etiquetas son herramientas, no obligaciones, y no se le ponen a otro sin preguntar.

const LABEL_SCENE := preload("res://src/enemies/arcoiria/projectile_etiqueta.tscn")
const PREJ_ID := "la_etiqueta"

var _vencido := false


func _ready() -> void:
	projectile_scene = LABEL_SCENE
	spread_shots = 1
	fire_rate = 2.6
	charge_time = 0.7
	projectile_speed = 250.0
	preferred_distance = 300.0
	super._ready()


func _fire_projectile(dir: Vector2) -> void:
	super._fire_projectile(dir)
	if RNG.randf() < 0.3:
		Arcoiria.say(self, "etiqueta_dispara", 1.2)


func die(killer: Node = null) -> void:
	if not _vencido:
		_vencido = true
		Arcoiria.vencido(self, PREJ_ID)
	super.die(killer)
