extends CharacterBody2D
class_name Entity

## Base class for all living entities (player, enemies, NPCs)

@export var entity_name: String = "Entity"
@export var max_health: float = 100.0
@export var move_speed: float = 200.0

var current_health: float = 100.0
var invulnerable: bool = false
var invuln_time: float = 0.15
var _invuln_timer: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_decay: float = 10.0
var last_damage_source: Node = null

signal died(killer: Node)
signal damaged(amount: float, source: Node)
signal health_changed(current: float, max: float)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox

func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)
	
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_area_entered)

func _physics_process(delta: float) -> void:
	_apply_knockback(delta)
	_update_invulnerability(delta)

func _apply_knockback(delta: float) -> void:
	if knockback_velocity.length() > 1.0:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, knockback_decay * delta)
	else:
		knockback_velocity = Vector2.ZERO

func _update_invulnerability(delta: float) -> void:
	if invulnerable:
		_invuln_timer -= delta
		if _invuln_timer <= 0.0:
			invulnerable = false
			if animated_sprite:
				animated_sprite.modulate = Color.WHITE

func take_damage(amount: float, source: Node = null, knockback: Vector2 = Vector2.ZERO) -> float:
	if invulnerable or current_health <= 0.0:
		return 0.0
	
	var actual_damage = amount
	current_health = max(0.0, current_health - actual_damage)
	
	invulnerable = true
	_invuln_timer = invuln_time
	
	if animated_sprite:
		animated_sprite.modulate = Color.RED
	
	if knockback.length() > 0.0:
		knockback_velocity = knockback
	
	last_damage_source = source
	damaged.emit(actual_damage, source)
	health_changed.emit(current_health, max_health)
	get_node("/root/GlobalEvents").entity_hit.emit(self, actual_damage, knockback)
	
	if current_health <= 0.0:
		die(source)
	
	return actual_damage

func heal(amount: float) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

func die(killer: Node = null) -> void:
	died.emit(killer)
	queue_free()

func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_attack"):
		var dmg = float(area.damage) if "damage" in area else 10.0
		var kb = (global_position - area.global_position).normalized() * (float(area.knockback) if "knockback" in area else 200.0)
		take_damage(dmg, area.get_parent(), kb)

func _on_hitbox_area_entered(area: Area2D) -> void:
	pass

func get_health_percentage() -> float:
	return current_health / max_health