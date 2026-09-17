class_name Bullet
extends Area2D
## Proyectil generico.
##
## Es un Area2D (detector) y no un cuerpo fisico: las balas no deben empujar
## ni ser empujadas, solo avisar de que han tocado algo. Se mueve a mano en
## _physics_process porque un Area2D no tiene resolucion de colisiones.

var direction: Vector2 = Vector2.RIGHT
var speed: float = 230.0
var damage: int = 2
var knockback: float = 90.0
var life: float = 1.6
var pierce: int = 0
var texture_override: Texture2D

@onready var sprite: Sprite2D = $Sprite


func _ready() -> void:
	rotation = direction.angle()
	if texture_override != null:
		sprite.texture = texture_override
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	# Convencion del proyecto: todo lo que puede recibir dano tiene un hijo
	# llamado "Health". Si no lo tiene (un muro, el TileMapLayer), la bala
	# simplemente revienta.
	var health := body.get_node_or_null("Health") as Health
	if health != null:
		health.take_damage(damage, global_position)
		if body is CharacterBody2D:
			(body as CharacterBody2D).velocity += direction * knockback
		if pierce > 0:
			pierce -= 1
			return

	_impact()


func _impact() -> void:
	# Desacoplamos la colision para que no dispare mas eventos mientras
	# se reproduce el pequeno destello de desaparicion.
	set_deferred("monitoring", false)
	set_physics_process(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(2.0, 2.0), 0.07)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.07)
	tween.chain().tween_callback(queue_free)
