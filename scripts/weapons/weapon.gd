class_name Weapon
extends Node2D
## Comportamiento del arma: cadencia, instanciado de balas y retroceso visual.
##
## Cuelga de un "pivote" que el actor rota hacia donde apunta. El arma no sabe
## quien la lleva: recibe la direccion y dispara. Asi la misma escena sirve
## para el jugador y, mas adelante, para enemigos con armas.

@export var data: WeaponData

## Capas de fisica de las balas que genera. Se configuran por instancia:
## el arma del jugador dispara balas en la capa "player_bullet" que chocan
## con "world" + "enemy"; la de un enemigo haria lo contrario.
@export_flags_2d_physics var bullet_layer: int = 8      # player_bullet
@export_flags_2d_physics var bullet_mask: int = 1 | 4   # world | enemy

@onready var sprite: Sprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle

var _cooldown: float = 0.0


func _ready() -> void:
	equip(data)


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func equip(new_data: WeaponData) -> void:
	data = new_data
	_cooldown = 0.0
	if data != null and data.texture != null:
		sprite.texture = data.texture


func can_fire() -> bool:
	return data != null and _cooldown <= 0.0


## Al apuntar a la izquierda volteamos el arma en vertical en vez de en
## horizontal: asi el canon sigue saliendo "hacia delante" y no boca abajo.
func set_flipped(flipped: bool) -> void:
	sprite.flip_v = flipped


## Dispara hacia `direction` (normalizada). Devuelve true si salio el disparo.
func fire(direction: Vector2) -> bool:
	if not can_fire():
		return false

	_cooldown = 1.0 / maxf(data.fire_rate, 0.01)

	# Las balas cuelgan de la escena raiz, no del arma: si el arma se mueve o
	# se destruye, las balas ya disparadas deben seguir su camino.
	var container := get_tree().current_scene
	for i in data.bullet_count:
		var angle := deg_to_rad(randf_range(-data.spread_deg, data.spread_deg))
		var bullet: Bullet = data.bullet_scene.instantiate()
		bullet.direction = direction.rotated(angle).normalized()
		bullet.speed = data.bullet_speed * randf_range(0.94, 1.06)
		bullet.damage = data.damage
		bullet.knockback = data.knockback
		bullet.life = data.bullet_life
		bullet.pierce = data.pierce
		bullet.texture_override = data.bullet_texture
		bullet.collision_layer = bullet_layer
		bullet.collision_mask = bullet_mask
		container.add_child(bullet)
		# Ojo al orden: global_position solo es valido DESPUES de add_child().
		bullet.global_position = muzzle.global_position

	_recoil_animation()
	return true


func _recoil_animation() -> void:
	# Un Tween es una animacion creada al vuelo, sin AnimationPlayer.
	# Se autodestruye al terminar.
	sprite.position.x = -2.0
	var tween := create_tween()
	tween.tween_property(sprite, "position:x", 0.0, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
