extends CharacterBody2D
class_name EnemyTank

const ITEM_PICKUP_SCENE := preload("res://src/items/item_pickup.tscn")

## Tank enemy - high health, slow, charges at player

@export var enemy_name: String = "Tanque"
@export var max_health: float = 500.0
@export var move_speed: float = 60.0
@export var charge_speed: float = 400.0
@export var damage: float = 40.0
@export var knockback: float = 300.0
@export var xp_value: int = 50
@export var drop_table: Array[Dictionary] = []
@export var charge_cooldown: float = 3.0
@export var charge_windup: float = 1.0
@export var charge_duration: float = 0.8

var current_health: float = 500.0
var state: State = State.IDLE
var target: Node = null
var detection_range: float = 400.0
var _charge_timer: float = 0.0
var _windup_timer: float = 0.0
var _charge_duration_timer: float = 0.0
var _is_charging: bool = false
var _charge_dir: Vector2 = Vector2.ZERO

enum State { IDLE, CHASE, CHARGE_WINDUP, CHARGING, STUNNED, DEAD }

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
	
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_entered)
	if hitbox:
		# The player's Hurtbox only reacts to areas in this group, and nothing
		# registered it, so enemies could never deal damage.
		hitbox.add_to_group("enemy_attack")

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	
	_handle_timers(delta)
	_update_state()
	_execute_state(delta)
	move_and_slide()

func _handle_timers(delta: float) -> void:
	if _charge_timer > 0.0:
		_charge_timer -= delta
	if _windup_timer > 0.0:
		_windup_timer -= delta
		if _windup_timer <= 0.0 and state == State.CHARGE_WINDUP:
			_start_charge()
	# The charge has to end on its own: _is_charging stayed true forever, so the
	# tank could only leave CHARGING through the (unreachable) branch above.
	if _charge_duration_timer > 0.0:
		_charge_duration_timer -= delta
		if _charge_duration_timer <= 0.0 and state == State.CHARGING:
			_is_charging = false

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
				state = State.CHASE
		State.CHASE:
			if dist <= 250.0 and _charge_timer <= 0.0:
				state = State.CHARGE_WINDUP
				_windup_timer = charge_windup
			elif dist > detection_range * 1.5:
				state = State.IDLE
		State.CHARGE_WINDUP:
			pass
		State.CHARGING:
			if _is_charging == false:
				state = State.CHASE
				_charge_timer = charge_cooldown
		State.STUNNED:
			pass

func _execute_state(delta: float) -> void:
	match state:
		State.IDLE:
			velocity = velocity.lerp(Vector2.ZERO, 5.0 * delta)
			_update_animation(Vector2.ZERO)
		State.CHASE:
			_chase(delta)
		State.CHARGE_WINDUP:
			velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)
			if animated_sprite:
				animated_sprite.modulate = Color(1, 1, 0)  # Yellow warning
			_update_animation(Vector2.ZERO)
		State.CHARGING:
			velocity = _charge_dir * charge_speed
			if animated_sprite:
				animated_sprite.modulate = Color(1, 0, 0)  # Red charging
			_update_animation(_charge_dir)
		State.STUNNED:
			velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)

func _chase(delta: float) -> void:
	if not target:
		return
	
	var dir = (target.global_position - global_position).normalized()
	velocity = dir * move_speed
	_update_animation(dir)

func _start_charge() -> void:
	_is_charging = true
	if not target:
		_is_charging = false
		return
	
	_charge_dir = (target.global_position - global_position).normalized()
	# The state was never moved to CHARGING, so the tank stayed locked in
	# CHARGE_WINDUP forever: velocity always lerped to zero and it never moved.
	state = State.CHARGING
	_charge_duration_timer = charge_duration
	
	# Visual/sound cue
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position, "¡CARGA!", Color.RED)

func _find_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if state == State.DEAD:
		return 0.0
	
	# Tanks take reduced knockback
	var actual_kb = kb * 0.3
	
	current_health -= amount
	
	if actual_kb != Vector2.ZERO and state != State.CHARGING:
		velocity = actual_kb
		state = State.STUNNED
		call_deferred("_exit_stun")
	
	if animated_sprite and state != State.CHARGING:
		animated_sprite.modulate = Color.RED
		call_deferred("_reset_color")
	
	get_node("/root/GlobalEvents").enemy_damaged.emit(self, amount, source)
	get_node("/root/GlobalEvents").show_damage_number.emit(global_position + Vector2(0, -40), amount, false)
	
	if current_health <= 0.0:
		die(source)
	
	return amount

func _exit_stun() -> void:
	if state == State.STUNNED:
		state = State.CHASE

func _reset_color() -> void:
	if animated_sprite:
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
			pickup.position = global_position + Vector2(RNG.randf_range(-30, 30), RNG.randf_range(-30, 30))
			# Deferred: die() runs inside a physics query flush, and adding an
			# Area2D there raises "Can't change this state while flushing queries".
			_drop_container().add_child.call_deferred(pickup)

func _update_animation(dir: Vector2) -> void:
	if not animated_sprite:
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