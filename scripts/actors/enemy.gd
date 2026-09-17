class_name Enemy
extends CharacterBody2D
## Clase base de los enemigos: vida, dano por contacto, empujon y muerte.
##
## Cada enemigo concreto hereda de esta y solo reimplementa `_think()`, que es
## su "cerebro". El resto (recibir golpes, morir, avisar al juego) ya esta
## resuelto aqui una sola vez.

@export var speed: float = 40.0
@export var contact_damage: int = 1
## Rozamiento que frena el empujon de las balas.
@export var drag: float = 500.0

@onready var health: Health = $Health
@onready var sprite: Sprite2D = $Sprite
@onready var contact_area: Area2D = $ContactDamage

var target: Node2D


func _ready() -> void:
	add_to_group("enemies")
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_acquire_target()


func _physics_process(delta: float) -> void:
	if health.is_dead:
		return
	if target == null or not is_instance_valid(target):
		_acquire_target()

	_think(delta)
	move_and_slide()
	_apply_contact_damage()


## Cerebro del enemigo. Debe fijar `velocity`. Lo sobrescriben las subclases.
func _think(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, drag * delta)


func _acquire_target() -> void:
	# Los grupos son etiquetas de nodo: una forma barata de encontrar cosas
	# sin guardar referencias ni recorrer el arbol a mano.
	target = get_tree().get_first_node_in_group("player")


func _apply_contact_damage() -> void:
	for body in contact_area.get_overlapping_bodies():
		var hp := body.get_node_or_null("Health") as Health
		if hp != null:
			# La invulnerabilidad del propio Health limita la frecuencia,
			# no hace falta un temporizador aqui.
			hp.take_damage(contact_damage, global_position)


func _on_damaged(_amount: int, _from_position: Vector2) -> void:
	flash()


func _on_died() -> void:
	Events.enemy_died.emit(global_position)
	set_physics_process(false)
	set_collision_layer_value(3, false)
	contact_area.set_deferred("monitoring", false)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.6, 0.4), 0.18)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.18)
	tween.chain().tween_callback(queue_free)


func flash() -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash", 1.0)
	var tween := create_tween()
	tween.tween_property(mat, "shader_parameter/flash", 0.0, 0.16)
