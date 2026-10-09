extends CharacterBody2D
class_name EnemyBoss

const ITEM_PICKUP_SCENE := preload("res://src/items/item_pickup.tscn")
const PROJECTILE := preload("res://src/enemies/projectile_enemy.tscn")
const MINION := preload("res://src/enemies/enemy_swarmer.tscn")

## Jefe de piso (piso 1: Testiculo Primordial). Estilo Gungeon:
## - cada ataque tiene AVISO (brilla / tiembla) antes de salir;
## - tras la embestida queda AGOTADO: esa es la ventana para pegarle;
## - 3 fases (66% / 33%): cada una añade patrones y aprieta los tiempos.
## Las frases salen de lines.json: boss<piso>_intro/_phase2/_phase3/_death/_after.

@export var enemy_name: String = "JEFE"
@export var max_health: float = 600.0
@export var move_speed: float = 70.0
@export var damage: float = 16.0
@export var drop_table: Array[Dictionary] = []

enum State { INTRO, IDLE, TELEGRAPH, FAN, CHARGE, TIRED, SPIRAL, SUMMON, RING, TRANSITION, DEAD }

var current_health: float = 600.0
var current_phase: int = 1
var state: State = State.INTRO
var target: Node = null
var _timer: float = 0.0
var _shot_timer: float = 0.0
var _count: int = 0
var _next: State = State.IDLE
var _last_pattern: State = State.IDLE
var _charge_dir: Vector2 = Vector2.ZERO
var _spin: float = 0.0
var _floor: int = 1
var _hit_done := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var _ge: Node = get_node("/root/GlobalEvents")


func _ready() -> void:
	current_health = max_health
	add_to_group("enemy")
	add_to_group("boss")
	_floor = get_node("/root/RunManager").current_floor
	hurtbox.area_entered.connect(_on_hurtbox_entered)
	hitbox.add_to_group("enemy_attack")
	hitbox.monitorable = false
	hitbox.monitoring = true
	_timer = 2.2
	_say("intro")
	_emit_health()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player")
		if not target:
			return
	_timer -= delta
	_shot_timer -= delta
	match state:
		State.INTRO, State.TRANSITION:
			velocity = Vector2.ZERO
			animated_sprite.offset.x = RNG.randf_range(-2, 2) if state == State.TRANSITION else 0.0
			if _timer <= 0.0:
				animated_sprite.offset.x = 0.0
				animated_sprite.modulate = Color.WHITE
				_go_idle()
		State.IDLE:
			_drift()
			if _timer <= 0.0:
				_pick_pattern()
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			var flash := int(_timer * 16.0) % 2 == 0
			animated_sprite.modulate = (Color(2.2, 0.6, 0.6) if _next == State.CHARGE else Color(2.0, 2.0, 0.9)) if flash else Color.WHITE
			if _next == State.CHARGE:
				animated_sprite.offset.x = RNG.randf_range(-3, 3)
				if _timer > 0.2:
					_charge_dir = (target.global_position - global_position).normalized()
			if _timer <= 0.0:
				animated_sprite.modulate = Color.WHITE
				animated_sprite.offset.x = 0.0
				_begin(_next)
		State.FAN:
			velocity = Vector2.ZERO
			if _shot_timer <= 0.0:
				_fire_fan()
				_count -= 1
				_shot_timer = 0.5 - current_phase * 0.06
				if _count <= 0:
					_go_idle()
		State.CHARGE:
			velocity = _charge_dir * (430.0 + current_phase * 50.0)
			_strike()
			if _timer <= 0.0 or get_slide_collision_count() > 0:
				# Contra la pared se queda mas tiempo atontado: premio por esquivar bien.
				_tire(1.0 if _timer <= 0.0 else 1.7)
		State.TIRED:
			velocity = velocity.lerp(Vector2.ZERO, 6.0 * delta)
			if _timer <= 0.0:
				animated_sprite.modulate = Color.WHITE
				_go_idle()
		State.SPIRAL:
			velocity = Vector2.ZERO
			_spin += delta * (2.2 + current_phase * 0.4)
			if _shot_timer <= 0.0:
				for arm in range(current_phase):
					_fire(_spin + arm * TAU / current_phase, 190.0)
				_shot_timer = 0.11
			if _timer <= 0.0:
				_go_idle()
		State.RING:
			velocity = Vector2.ZERO
			if _shot_timer <= 0.0:
				_fire_ring()
				_count -= 1
				_shot_timer = 0.85
				if _count <= 0:
					_go_idle()
		State.SUMMON:
			velocity = Vector2.ZERO
			if _timer <= 0.0:
				_summon()
				_go_idle()
	_update_animation()
	move_and_slide()


# ---------------------------------------------------------------- patrones
func _available() -> Array:
	var p := [State.FAN, State.CHARGE]
	if current_phase >= 2:
		p += [State.SPIRAL, State.SUMMON]
	if current_phase >= 3:
		p += [State.RING, State.RING]
	return p


func _pick_pattern() -> void:
	var options := _available().filter(func(x): return x != _last_pattern)
	var choice: State = options[RNG.randi_range(0, options.size() - 1)]
	if choice == State.SUMMON and get_tree().get_nodes_in_group("boss_minion").size() >= 6:
		choice = State.FAN
	_last_pattern = choice
	_next = choice
	state = State.TELEGRAPH
	_timer = 0.85 if choice == State.CHARGE else 0.5
	animated_sprite.play("attack")


func _begin(pattern: State) -> void:
	state = pattern
	_shot_timer = 0.0
	match pattern:
		State.FAN:
			_count = current_phase + 1
		State.CHARGE:
			_timer = 0.75
			_hit_done = false
		State.SPIRAL:
			_timer = 2.0 + current_phase * 0.4
			_spin = (target.global_position - global_position).angle()
		State.RING:
			_count = 3
		State.SUMMON:
			_timer = 0.3


func _go_idle() -> void:
	state = State.IDLE
	_timer = RNG.randf_range(0.7, 1.2) - current_phase * 0.15


func _tire(seconds: float) -> void:
	state = State.TIRED
	_timer = seconds
	animated_sprite.modulate = Color(0.6, 0.6, 0.75)


## Golpe activo: mira a quien solapa el hitbox AHORA. No se usa area_entered
## porque al apagar monitorable Godot no borra el solape y el siguiente ataque
## a quemarropa nunca generaba un "enter" nuevo (1 de cada 6 embestidas pegaba).
func _strike() -> void:
	if _hit_done:
		return
	for b in hitbox.get_overlapping_bodies():
		if b.has_method("receive_hit") and b.receive_hit(damage):
			_hit_done = true


func _drift() -> void:
	var to_target: Vector2 = target.global_position - global_position
	velocity = to_target.normalized() * move_speed if to_target.length() > 180.0 else Vector2.ZERO


func _fire_fan() -> void:
	var shots := 5 + current_phase * 2
	var base: float = (target.global_position - global_position).angle()
	for i in range(shots):
		_fire(base + (i - (shots - 1) / 2.0) * 0.16, 230.0)


func _fire_ring() -> void:
	# Anillo con un hueco: el hueco apunta cerca de ti. Busca el hueco.
	var n := 24
	var gap_center: float = (target.global_position - global_position).angle() + RNG.randf_range(-0.6, 0.6)
	for i in range(n):
		var a := i * TAU / n
		if absf(angle_difference(a, gap_center)) < 0.42:
			continue
		_fire(a, 170.0)


func _summon() -> void:
	for i in range(2 + current_phase):
		var m := MINION.instantiate()
		m.max_health = 12.0
		m.damage = 8.0
		m.enemy_name = "Espermatozoide"
		m.add_to_group("boss_minion")
		_spawn_container().add_child(m)
		m.global_position = global_position + Vector2.RIGHT.rotated(i * TAU / (2 + current_phase)) * 90.0


func _fire(angle: float, speed: float) -> void:
	var p := PROJECTILE.instantiate()
	p.damage = damage * 0.7
	p.speed = speed
	p.projectile_owner = self
	p.lifetime = 6.0
	_spawn_container().add_child(p)
	p.global_rotation = angle
	p.global_position = global_position + Vector2(0, -50) + Vector2.RIGHT.rotated(angle) * 30.0


# ---------------------------------------------------------------- vida / fases
func take_damage(amount: float, source: Node = null, _kb: Vector2 = Vector2.ZERO) -> float:
	if state in [State.DEAD, State.INTRO, State.TRANSITION]:
		return 0.0
	# Agotado tras embestir recibe el doble: aprende a esperar el momento.
	if state == State.TIRED:
		amount *= 2.0
	current_health -= amount
	_emit_health()
	if state not in [State.TELEGRAPH, State.TIRED]:
		animated_sprite.modulate = Color(2, 0.5, 0.5)
		get_tree().create_timer(0.07).timeout.connect(func():
			if is_instance_valid(self) and state not in [State.TELEGRAPH, State.TIRED, State.TRANSITION]:
				animated_sprite.modulate = Color.WHITE)
	_ge.enemy_damaged.emit(self, amount, source)
	_ge.show_damage_number.emit(global_position + Vector2(0, -150), amount, state == State.TIRED)
	if current_health <= 0.0:
		die(source)
	elif current_phase == 1 and current_health <= max_health * 0.66:
		_enter_phase(2)
	elif current_phase == 2 and current_health <= max_health * 0.33:
		_enter_phase(3)
	return amount


func _enter_phase(n: int) -> void:
	current_phase = n
	state = State.TRANSITION
	_timer = 1.8
	animated_sprite.modulate = Color(1.8, 0.5, 0.5)
	_say("phase%d" % n)
	_clear_bullets()


func die(killer: Node = null) -> void:
	state = State.DEAD
	current_health = 0.0
	_emit_health()
	_clear_bullets()
	for m in get_tree().get_nodes_in_group("boss_minion"):
		if is_instance_valid(m) and m.has_method("die"):
			m.die(null)
	_say("death")
	_say("after")
	animated_sprite.modulate = Color.WHITE
	animated_sprite.play("death")
	set_collision_layer_value(2, false)
	await get_tree().create_timer(1.4).timeout
	_drop_loot()
	_ge.enemy_killed.emit(self, killer)
	get_node("/root/RunManager").total_enemies_killed += 1
	queue_free()


func _clear_bullets() -> void:
	for p in _spawn_container().get_children():
		if p is ProjectileEnemy:
			p.queue_free()


func _emit_health() -> void:
	_ge.boss_health_changed.emit(enemy_name, maxf(current_health, 0.0), max_health)


func _say(suffix: String) -> void:
	var key := "boss%d_%s" % [_floor, suffix]
	if Narrator.has_lines(key):
		Narrator.say(key)


# ---------------------------------------------------------------- utilidades
func _update_animation() -> void:
	if state in [State.TELEGRAPH, State.FAN, State.RING, State.SPIRAL, State.DEAD]:
		return
	var anim := "walk" if velocity.length() > 10.0 else "idle"
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)
	if absf(velocity.x) > 1.0:
		animated_sprite.flip_h = velocity.x < 0.0


func _on_hurtbox_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		take_damage(float(area.damage) if "damage" in area else 10.0, area.get_parent())


func _drop_loot() -> void:
	for drop in drop_table:
		if RNG.randf() < drop.chance:
			var pickup = ITEM_PICKUP_SCENE.instantiate()
			pickup.item_id = drop.item_id
			pickup.position = global_position + Vector2(RNG.randf_range(-50, 50), RNG.randf_range(-30, 30))
			_drop_container().add_child.call_deferred(pickup)


func find_owning_room() -> Room:
	var node: Node = get_parent()
	while node != null:
		if node is Room:
			return node
		node = node.get_parent()
	return null


func _drop_container() -> Node:
	var room := find_owning_room()
	return room.get_drop_container() if room else get_tree().current_scene


func _spawn_container() -> Node:
	var room := find_owning_room()
	return room.get_spawn_container() if room else get_tree().current_scene
