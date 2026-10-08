extends CharacterBody2D
class_name EnemyRanged

const ITEM_PICKUP_SCENE := preload("res://src/items/item_pickup.tscn")

## Ranged enemy that shoots projectiles

@export var enemy_name: String = "Ranged Enemy"
@export var max_health: float = 40.0
@export var move_speed: float = 100.0
@export var damage: float = 12.0
@export var knockback: float = 150.0
@export var xp_value: int = 15
@export var drop_table: Array[Dictionary] = []
@export var projectile_scene: PackedScene = preload("res://src/enemies/projectile_enemy.tscn")
@export var fire_rate: float = 2.0
@export var projectile_speed: float = 240.0  # lento y legible: el reto es la cantidad, no la velocidad
@export var preferred_distance: float = 300.0
@export var strafe_speed: float = 80.0

var current_health: float = 40.0
var state: State = State.IDLE
var target: Node = null
var detection_range: float = 500.0
var _fire_timer: float = 0.0
var _strafe_dir: int = 1
## Carga visible (brilla) antes de escupir: el aviso que permite esquivar.
var charge_time: float = 0.6
var spread_shots: int = 3
var _charging: float = 0.0

enum State { IDLE, STRAFE, ATTACK, FLEE, STUNNED, DEAD }

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var projectile_spawn: Node2D = $ProjectileSpawn


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
	
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_entered)
	if hitbox:
		hitbox.add_to_group("enemy_attack")
		hitbox.monitorable = false  # no pega cuerpo a cuerpo, solo escupe
	
	_strafe_dir = RNG.randi_range(0, 1) * 2 - 1

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	
	_handle_timers(delta)
	if _charging <= 0.0:  # mientras carga se queda quieto: es su punto debil
		_update_state()
		_execute_state(delta)
	move_and_slide()

func _handle_timers(delta: float) -> void:
	if _fire_timer > 0.0:
		_fire_timer -= delta
	if _charging > 0.0:
		_charging -= delta
		velocity = Vector2.ZERO
		animated_sprite.modulate = Color(1.2, 2.2, 0.8) if int(_charging * 18.0) % 2 == 0 else Color.WHITE
		if _charging <= 0.0:
			_release_spread()

func _release_spread() -> void:
	animated_sprite.modulate = Color.WHITE
	_fire_timer = fire_rate
	if not target or not is_instance_valid(target) or state == State.DEAD:
		return
	var base: float = (target.global_position - projectile_spawn.global_position).angle()
	for i in range(spread_shots):
		_fire_projectile(Vector2.RIGHT.rotated(base + (i - (spread_shots - 1) / 2.0) * 0.24))

func _update_state() -> void:
	if not target or not is_instance_valid(target):
		_find_target()
	
	if not target:
		state = State.IDLE
		return
	
	var dist = global_position.distance_to(target.global_position)
	
	match state:
		State.IDLE:
			if dist <= detection_range:
				if dist > preferred_distance * 1.2:
					state = State.STRAFE
				elif dist < preferred_distance * 0.7:
					state = State.FLEE
				else:
					state = State.ATTACK
		State.STRAFE:
			if dist <= preferred_distance * 1.1 and dist >= preferred_distance * 0.8:
				state = State.ATTACK
			elif dist > detection_range * 1.3:
				state = State.IDLE
		State.ATTACK:
			if dist < preferred_distance * 0.6:
				state = State.FLEE
			elif dist > preferred_distance * 1.3:
				state = State.STRAFE
		State.FLEE:
			if dist >= preferred_distance:
				state = State.STRAFE
		State.STUNNED:
			pass

func _execute_state(delta: float) -> void:
	match state:
		State.IDLE:
			velocity = velocity.lerp(Vector2.ZERO, 5.0 * delta)
			_update_animation(Vector2.ZERO)
		State.STRAFE:
			_strafe(delta)
		State.ATTACK:
			_attack()
		State.FLEE:
			_flee(delta)
		State.STUNNED:
			velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)

func _strafe(delta: float) -> void:
	if not target:
		return
	
	var to_target = (target.global_position - global_position).normalized()
	var perp = Vector2(-to_target.y, to_target.x) * _strafe_dir
	
	var dist = global_position.distance_to(target.global_position)
	if dist < preferred_distance * 0.9:
		perp += to_target * 0.5
	elif dist > preferred_distance * 1.1:
		perp -= to_target * 0.5
	
	velocity = perp.normalized() * strafe_speed
	_update_animation(perp)

func _attack() -> void:
	if _fire_timer > 0.0 or _charging > 0.0 or not target:
		velocity = velocity.lerp(Vector2.ZERO, 0.2)
		return
	_charging = charge_time
	animated_sprite.play("attack")

func _fire_projectile(dir: Vector2) -> void:
	var proj = projectile_scene.instantiate()
	proj.global_rotation = dir.angle()
	proj.damage = damage
	proj.speed = projectile_speed
	proj.projectile_owner = self
	_spawn_container().add_child(proj)
	# Position only after parenting, otherwise the room offset is applied twice.
	proj.global_position = projectile_spawn.global_position

func _flee(delta: float) -> void:
	if not target:
		return
	
	var dir = (global_position - target.global_position).normalized()
	velocity = dir * move_speed * 1.2
	_update_animation(dir)

func _find_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if state == State.DEAD:
		return 0.0
	
	current_health -= amount
	
	if kb != Vector2.ZERO and _charging <= 0.0:
		velocity = kb
		state = State.STUNNED
		get_tree().create_timer(0.15).timeout.connect(_exit_stun)
	
	if animated_sprite and _charging <= 0.0:
		animated_sprite.modulate = Color(2, 0.4, 0.4)
		get_tree().create_timer(0.08).timeout.connect(_reset_color)
	
	get_node("/root/GlobalEvents").enemy_damaged.emit(self, amount, source)
	get_node("/root/GlobalEvents").show_damage_number.emit(global_position + Vector2(0, -30), amount, false)
	
	if current_health <= 0.0:
		die(source)
	
	return amount

func _exit_stun() -> void:
	if state == State.STUNNED:
		state = State.IDLE

func _reset_color() -> void:
	if is_instance_valid(animated_sprite) and _charging <= 0.0:
		animated_sprite.modulate = Color.WHITE

func die(killer: Node = null) -> void:
	state = State.DEAD
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	
	if animated_sprite:
		animated_sprite.play("death")
		await get_tree().create_timer(0.5).timeout
	
	_drop_loot()
	get_node("/root/GlobalEvents").enemy_killed.emit(self, killer)
	get_node("/root/RunManager").total_enemies_killed += 1
	queue_free()

func _drop_loot() -> void:
	for drop in drop_table:
		if RNG.randf() < drop.chance:
			var pickup = ITEM_PICKUP_SCENE.instantiate()
			pickup.item_id = drop.item_id
			pickup.position = global_position + Vector2(RNG.randf_range(-20, 20), RNG.randf_range(-20, 20))
			# Deferred: die() runs inside a physics query flush, and adding an
			# Area2D there raises "Can't change this state while flushing queries".
			_drop_container().add_child.call_deferred(pickup)

func _update_animation(dir: Vector2) -> void:
	if not animated_sprite:
		return
	
	if _charging > 0.0:
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