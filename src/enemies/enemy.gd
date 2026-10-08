extends CharacterBody2D
class_name Enemy

const ITEM_PICKUP_SCENE := preload("res://src/items/item_pickup.tscn")

## Base enemy with simple AI states

@export var enemy_name: String = "Enemy"
@export var max_health: float = 30.0
@export var move_speed: float = 120.0
@export var damage: float = 10.0
@export var knockback: float = 200.0
@export var xp_value: int = 10
@export var drop_table: Array[Dictionary] = []

var current_health: float = 30.0
var state: State = State.IDLE
var target: Node = null
var detection_range: float = 420.0
## Patron Gungeon: persigue -> AVISA (parpadea/tiembla) -> embiste -> queda agotado.
## El aviso es lo que hace el golpe esquivable; el agotamiento es tu ventana.
var lunge_trigger: float = 110.0
var windup_time: float = 0.55
var lunge_time: float = 0.22
var lunge_speed: float = 520.0
var recover_time: float = 0.65
var attack_cooldown: float = 0.6
var _state_timer: float = 0.0
var _attack_timer: float = 0.0
var _lunge_dir: Vector2 = Vector2.ZERO
var _hit_done := false
var _wander_timer: float = 0.0
var _wander_direction: Vector2 = Vector2.ZERO

enum State { IDLE, CHASE, WINDUP, LUNGE, RECOVER, STUNNED, DEAD }

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
		hitbox.add_to_group("enemy_attack")
		# Solo hace daño durante la embestida (ver _strike), nunca por roce.
		hitbox.monitorable = false
		hitbox.monitoring = true

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_state_timer -= delta
	match state:
		State.IDLE:
			_wander(delta)
			if target and global_position.distance_to(target.global_position) <= detection_range:
				state = State.CHASE
		State.CHASE:
			_chase(delta)
		State.WINDUP:
			velocity = Vector2.ZERO
			# sigue apuntando hasta el ultimo cuarto del aviso, luego se compromete
			if target and _state_timer > windup_time * 0.25:
				_lunge_dir = (target.global_position - global_position).normalized()
			animated_sprite.modulate = Color(2, 2, 2) if int(_state_timer * 16.0) % 2 == 0 else Color(1.6, 0.4, 0.4)
			animated_sprite.offset.x = RNG.randf_range(-1.5, 1.5)
			if _state_timer <= 0.0:
				_start_lunge()
		State.LUNGE:
			velocity = _lunge_dir * lunge_speed
			_strike()
			if _state_timer <= 0.0:
				state = State.RECOVER
				_state_timer = recover_time
				animated_sprite.modulate = Color(0.6, 0.6, 0.7)
		State.RECOVER, State.STUNNED:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			if _state_timer <= 0.0:
				animated_sprite.modulate = Color.WHITE
				state = State.CHASE
	move_and_slide()

func _wander(delta: float) -> void:
	if _wander_timer <= 0.0 or _wander_direction == Vector2.ZERO:
		_wander_direction = Vector2(RNG.randf_range(-1, 1), RNG.randf_range(-1, 1)).normalized()
		_wander_timer = RNG.randf_range(1.0, 3.0)
	_wander_timer -= delta
	velocity = _wander_direction * move_speed * 0.3
	_update_animation(_wander_direction)

func _chase(_delta: float) -> void:
	if not target:
		return
	var to_target: Vector2 = target.global_position - global_position
	velocity = to_target.normalized() * move_speed
	_update_animation(to_target)
	if to_target.length() <= lunge_trigger and _attack_timer <= 0.0:
		state = State.WINDUP
		_state_timer = windup_time
		_lunge_dir = to_target.normalized()
		animated_sprite.play("attack")

func _start_lunge() -> void:
	state = State.LUNGE
	_state_timer = lunge_time
	_attack_timer = attack_cooldown + recover_time
	animated_sprite.offset.x = 0.0
	animated_sprite.modulate = Color(1.4, 0.5, 0.5)
	_hit_done = false

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
	
	# Retroceso solo si no esta embistiendo: el golpe no cancela su ataque.
	if kb != Vector2.ZERO and state in [State.CHASE, State.IDLE, State.RECOVER]:
		velocity = kb
		state = State.STUNNED
		_state_timer = 0.15
	
	if animated_sprite and state != State.WINDUP:
		animated_sprite.modulate = Color(2, 0.4, 0.4)
		get_tree().create_timer(0.08).timeout.connect(_reset_color)
	
	get_node("/root/GlobalEvents").enemy_damaged.emit(self, amount, source)
	get_node("/root/GlobalEvents").show_damage_number.emit(global_position + Vector2(0, -30), amount, false)
	
	if current_health <= 0.0:
		die(source)
	
	return amount

func _reset_color() -> void:
	if is_instance_valid(animated_sprite) and state not in [State.WINDUP, State.RECOVER]:
		animated_sprite.modulate = Color.WHITE

func die(killer: Node = null) -> void:
	state = State.DEAD
	animated_sprite.modulate = Color.WHITE
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
	
	if state in [State.WINDUP, State.LUNGE]:
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