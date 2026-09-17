class_name Player
extends CharacterBody2D
## El personaje jugable.
##
## CharacterBody2D es el cuerpo con "movimiento guiado por codigo": nosotros
## decidimos la velocidad y el motor se encarga de deslizarlo contra los muros
## (move_and_slide). Para un juego cenital hay que poner motion_mode en
## FLOATING, si no Godot asume que hay gravedad y un "suelo".

@export_group("Movimiento")
@export var speed: float = 95.0
## Cuanto tarda en alcanzar la velocidad maxima (px/s^2). Alto = respuesta seca.
@export var acceleration: float = 1000.0
@export var friction: float = 1300.0

@export_group("Esquiva")
@export var dash_speed: float = 275.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.7

@export_group("Energia")
@export var max_energy: float = 100.0
@export var energy_regen: float = 10.0

@onready var health: Health = $Health
@onready var sprite: Sprite2D = $Sprite
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var weapon: Weapon = $WeaponPivot/Weapon

var energy: float
var aim_direction: Vector2 = Vector2.RIGHT

var _dash_left: float = 0.0
var _dash_cd: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	energy = max_energy
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.changed.connect(func() -> void: Events.player_stats_changed.emit())
	Events.player_spawned.emit(self)


func _physics_process(delta: float) -> void:
	if health.is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	_update_aim()
	_update_energy(delta)
	_update_dash(delta)
	_update_movement(delta)

	move_and_slide()

	if Input.is_action_pressed("shoot"):
		_try_shoot()


# --- Apuntado ---------------------------------------------------------------

func _update_aim() -> void:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 1.0:
		aim_direction = to_mouse.normalized()

	# Rotamos el PIVOTE, no el arma: asi el arma orbita alrededor del cuerpo
	# manteniendo su propia orientacion local.
	weapon_pivot.rotation = aim_direction.angle()
	weapon.set_flipped(aim_direction.x < 0.0)
	sprite.flip_h = aim_direction.x < 0.0


# --- Movimiento y esquiva ---------------------------------------------------

func _update_movement(delta: float) -> void:
	if _dash_left > 0.0:
		velocity = _dash_dir * dash_speed
		return

	# Input.get_vector lee las cuatro acciones y devuelve un vector ya
	# normalizado: resuelve gratis el clasico bug de ir mas rapido en diagonal.
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _update_dash(delta: float) -> void:
	_dash_cd = maxf(_dash_cd - delta, 0.0)
	_dash_left = maxf(_dash_left - delta, 0.0)

	if not Input.is_action_just_pressed("dash") or _dash_cd > 0.0:
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		dir = aim_direction
	_dash_dir = dir.normalized()
	_dash_left = dash_duration
	_dash_cd = dash_cooldown
	# Esquivar da invulnerabilidad: es la herramienta defensiva del jugador.
	health.grant_invulnerability(dash_duration + 0.05)
	_afterimage()


# --- Energia y disparo ------------------------------------------------------

func _update_energy(delta: float) -> void:
	if energy >= max_energy:
		return
	energy = minf(energy + energy_regen * delta, max_energy)
	Events.player_stats_changed.emit()


func _try_shoot() -> void:
	if not weapon.can_fire() or energy < weapon.data.energy_cost:
		return
	if not weapon.fire(aim_direction):
		return

	energy -= weapon.data.energy_cost
	velocity -= aim_direction * weapon.data.recoil
	Events.player_stats_changed.emit()
	Events.shake_requested.emit(weapon.data.shake)


# --- Reacciones -------------------------------------------------------------

func _on_damaged(_amount: int, from_position: Vector2) -> void:
	if from_position != Vector2.ZERO:
		velocity += (global_position - from_position).normalized() * 150.0
	flash()
	Events.shake_requested.emit(4.5)


func _on_died() -> void:
	set_collision_layer_value(2, false)
	weapon_pivot.hide()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "rotation", deg_to_rad(90.0), 0.35)
	tween.tween_property(sprite, "modulate:a", 0.45, 0.35)
	Events.player_died.emit()


## Destello blanco. Anima el uniform del shader del sprite.
func flash() -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("flash", 1.0)
	var tween := create_tween()
	tween.tween_property(mat, "shader_parameter/flash", 0.0, 0.18)


## Rastro visual de la esquiva: copias del sprite que se desvanecen.
func _afterimage() -> void:
	for i in 3:
		var ghost := Sprite2D.new()
		ghost.texture = sprite.texture
		ghost.offset = sprite.offset
		ghost.flip_h = sprite.flip_h
		ghost.global_position = global_position
		ghost.modulate = Color(0.6, 0.8, 1.0, 0.5)
		ghost.z_index = -1
		get_tree().current_scene.add_child(ghost)
		var tween := ghost.create_tween()
		tween.tween_interval(i * 0.04)
		tween.tween_property(ghost, "modulate:a", 0.0, 0.2)
		tween.tween_callback(ghost.queue_free)
