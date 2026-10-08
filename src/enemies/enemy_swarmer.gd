extends CharacterBody2D
class_name EnemySwarmer

const ITEM_PICKUP_SCENE := preload("res://src/items/item_pickup.tscn")

## Fast swarmer enemy - low health, high speed, swarms in groups

@export var enemy_name: String = "Enjambre"
@export var max_health: float = 15.0
@export var move_speed: float = 300.0
@export var damage: float = 8.0
@export var knockback: float = 100.0
@export var xp_value: int = 5
@export var drop_table: Array[Dictionary] = []
@export var swarm_radius: float = 80.0
@export var separation_weight: float = 1.5

var current_health: float = 15.0
var state: State = State.IDLE
var target: Node = null
var detection_range: float = 420.0
## Espermatozoide: nada en zigzag, rodea al jugador, se PARA y brilla (aviso)
## y sale disparado en linea recta. Esquivar = apartarse de la linea.
var orbit_radius: float = 140.0
var aim_time: float = 0.4
var dart_time: float = 0.32
var dart_speed: float = 560.0
var recover_time: float = 0.5
var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _dart_dir: Vector2 = Vector2.ZERO
var _hit_done := false
var _wiggle: float = 0.0
var _swarm_offset: Vector2 = Vector2.ZERO

enum State { IDLE, SWARM, AIM, DART, RECOVER, STUNNED, DEAD }

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox


func _drop_container() -> Node:
	var room := find_owning_room()
	if room != null:
		return room.get_drop_container()
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		return tree.current_scene
	return tree.root if tree != null else self

func _spawn_container() -> Node:
	var room := find_owning_room()
	if room != null:
		return room.get_spawn_container()
	return _drop_container()

func find_owning_room() -> Room:
	var node: Node = get_parent()
	while node != null:
		if node is Room:
			return node
		node = node.get_parent()
	return null

func _ready() -> void:
	current_health = max_health
	add_to_group("enemy")
	add_to_group("swarmer")
	
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_entered)
	if hitbox:
		hitbox.add_to_group("enemy_attack")
		hitbox.monitorable = false  # solo muerde durante el disparo (ver _strike)
		hitbox.monitoring = true
	
	_swarm_offset = Vector2(RNG.randf_range(-swarm_radius, swarm_radius), RNG.randf_range(-swarm_radius, swarm_radius))

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_state_timer -= delta
	_wiggle += delta * 14.0
	match state:
		State.IDLE:
			velocity = velocity.lerp(Vector2.ZERO, 5.0 * delta)
			if target and global_position.distance_to(target.global_position) <= detection_range:
				state = State.SWARM
				_attack_timer = RNG.randf_range(0.6, 1.8)  # que no ataquen todos a la vez
		State.SWARM:
			_swarm(delta)
		State.AIM:
			velocity = Vector2.ZERO
			if target and _state_timer > aim_time * 0.3:
				_dart_dir = (target.global_position - global_position).normalized()
			animated_sprite.modulate = Color(2.2, 2.2, 1.6) if int(_state_timer * 20.0) % 2 == 0 else Color.WHITE
			_update_animation(_dart_dir)
			if _state_timer <= 0.0:
				state = State.DART
				_state_timer = dart_time
				animated_sprite.modulate = Color.WHITE
				_hit_done = false
		State.DART:
			velocity = _dart_dir * dart_speed
			_strike()
			if _state_timer <= 0.0:
				state = State.RECOVER
				_state_timer = recover_time
		State.RECOVER, State.STUNNED:
			velocity = velocity.lerp(Vector2.ZERO, 6.0 * delta)
			if _state_timer <= 0.0:
				state = State.SWARM
				_attack_timer = RNG.randf_range(0.9, 1.8)
	move_and_slide()

func _swarm(_delta: float) -> void:
	if not target:
		return
	var to_target: Vector2 = target.global_position - global_position
	var dist := to_target.length()
	# Orbita a distancia, con separacion entre ellos y meneo de cola.
	var desired: Vector2 = to_target.normalized() * clampf((dist - orbit_radius) / 60.0, -1.0, 1.0)
	desired += to_target.normalized().orthogonal() * 0.6 * signf(_swarm_offset.x + 0.01)
	var separation := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("swarmer"):
		if other != self and is_instance_valid(other):
			var diff: Vector2 = global_position - other.global_position
			var d := diff.length()
			if d > 0.0 and d < swarm_radius:
				separation += diff.normalized() * (swarm_radius - d) / swarm_radius
	var dir := (desired + separation * separation_weight).normalized()
	velocity = (dir + dir.orthogonal() * sin(_wiggle) * 0.35) * move_speed * 0.7
	_update_animation(to_target)
	if _attack_timer <= 0.0 and dist < orbit_radius * 1.5:
		state = State.AIM
		_state_timer = aim_time
		_dart_dir = to_target.normalized()
		animated_sprite.play("attack")

## Golpe activo: mira a quien solapa el hitbox AHORA. No se usa area_entered
## porque al apagar monitorable Godot no borra el solape y el siguiente ataque
## a quemarropa nunca generaba un "enter" nuevo (1 de cada 6 embestidas pegaba).
func _strike() -> void:
	if _hit_done:
		return
	for b in hitbox.get_overlapping_bodies():
		if b.has_method("receive_hit") and b.receive_hit(damage):
			_hit_done = true

func _find_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if state == State.DEAD:
		return 0.0
	
	current_health -= amount
	
	if kb != Vector2.ZERO and state != State.DART:
		velocity = kb * 1.5
		state = State.STUNNED
		_state_timer = 0.2
	
	if animated_sprite:
		animated_sprite.modulate = Color(2, 0.4, 0.4)
		get_tree().create_timer(0.08).timeout.connect(_reset_color)
	
	get_node("/root/GlobalEvents").enemy_damaged.emit(self, amount, source)
	get_node("/root/GlobalEvents").show_damage_number.emit(global_position + Vector2(0, -20), amount, false)
	
	if current_health <= 0.0:
		die(source)
	
	return amount

func _reset_color() -> void:
	if is_instance_valid(animated_sprite) and state != State.AIM:
		animated_sprite.modulate = Color.WHITE

func die(killer: Node = null) -> void:
	state = State.DEAD
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	if animated_sprite:
		animated_sprite.play("death")
		await get_tree().create_timer(0.3).timeout
	
	_drop_loot()
	get_node("/root/GlobalEvents").enemy_killed.emit(self, killer)
	get_node("/root/RunManager").total_enemies_killed += 1
	queue_free()

func _drop_loot() -> void:
	for drop in drop_table:
		if RNG.randf() < drop.chance:
			var pickup = ITEM_PICKUP_SCENE.instantiate()
			pickup.item_id = drop.item_id
			pickup.position = global_position + Vector2(RNG.randf_range(-15, 15), RNG.randf_range(-15, 15))
			# Deferred: die() runs inside a physics query flush, and adding an
			# Area2D there raises "Can't change this state while flushing queries".
			_drop_container().add_child.call_deferred(pickup)

func _update_animation(dir: Vector2) -> void:
	if not animated_sprite:
		return
	
	if state in [State.AIM, State.DART]:
		if dir.x != 0:
			animated_sprite.flip_h = dir.x < 0
		return
	var anim = "idle"
	if velocity.length() > 10:
		anim = "walk"
	
	if animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)
	
	if dir.x != 0:
		animated_sprite.flip_h = dir.x < 0

func _on_hurtbox_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		var dmg = float(area.damage) if "damage" in area else 10.0
		var kb = (global_position - area.global_position).normalized() * (float(area.knockback) if "knockback" in area else 200.0)
		take_damage(dmg, area.get_parent(), kb)