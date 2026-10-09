extends CharacterBody2D
class_name Player

## Player controller with movement, dash, attack, intoxication integration

@export var move_speed: float = 250.0
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.2
@export var dash_cooldown: float = 1.0
@export var dash_stamina_cost: float = 15.0
@export var attack_cooldown: float = 0.3
@export var interaction_range: float = 40.0

var current_weapon: Item = null
var collected_items: Array[String] = []
var is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _attack_timer: float = 0.0
var _dash_direction: Vector2 = Vector2.ZERO
var _last_move_direction: Vector2 = Vector2.DOWN
## Invulnerabilidad tras recibir un golpe (y durante el dash): sin esto un grupo
## de espermatozoides te borra en un frame y no hay forma "justa" de esquivar.
const HIT_IFRAMES := 0.8
var _iframes: float = 0.0
var _attack_anim: float = 0.0
## Alergia a la hormona del reino contrario: estornudos que te desplazan sin querer.
var _allergy: float = 0.0
var _sneeze_in: float = 0.0
var _sneeze_push: float = 0.0
var _aim: Vector2 = Vector2.RIGHT
var _using_pad := false
const PLAYER_BULLET := preload("res://src/player/player_bullet.tscn")

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var weapon_sprite: Sprite2D = $WeaponPivot/WeaponSprite

@onready var _player_stats: PlayerStats = get_node("/root/PlayerStats")
@onready var _global_events: GlobalEvents = get_node("/root/GlobalEvents")

func _ready() -> void:
	add_to_group("player")
	_player_stats.health_changed.connect(_on_health_changed)
	_player_stats.shields_changed.connect(_on_shields_changed)
	_player_stats.stamina_changed.connect(_on_stamina_changed)
	_player_stats.intoxication_changed.connect(_on_intoxication_changed)
	# Sin esta conexion la run nunca terminaba al morir: ni huesos ni estadisticas.
	_global_events.player_died.connect(_on_player_died)
	
	_player_stats.reset_for_new_run()
	_apply_character()
	
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_entered)

func _apply_character() -> void:
	var rm = get_node("/root/RunManager")
	var frames := "res://assets/sprites/player/%s/sprite_frames.tres" % rm.character
	if ResourceLoader.exists(frames):
		animated_sprite.sprite_frames = load(frames)
	match rm.character:
		"pitocles":
			_player_stats.max_shields += 10.0
			_player_stats.current_shields = _player_stats.max_shields
			_player_stats.emit_all_signals()
		"vulvalquiria":
			dash_stamina_cost *= 0.5

func _physics_process(delta: float) -> void:
	_handle_timers(delta)
	_handle_movement(delta)
	_handle_dash(delta)
	_update_aim()
	_handle_attack(delta)
	_handle_interaction()
	move_and_slide()

func _handle_timers(delta: float) -> void:
	if _dash_timer > 0.0:
		_dash_timer -= delta
		_dash_cut()
		if _dash_timer <= 0.0:
			is_dashing = false
			velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)
	
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
	
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _attack_anim > 0.0:
		_attack_anim -= delta
	_sneeze_push = maxf(0.0, _sneeze_push - delta)
	if _allergy > 0.0:
		_allergy -= delta
		_sneeze_in -= delta
		if _sneeze_in <= 0.0:
			_sneeze()
		if _allergy <= 0.0:
			animated_sprite.self_modulate = Color.WHITE
	if _iframes > 0.0:
		_iframes -= delta
		animated_sprite.visible = _iframes <= 0.0 or int(_iframes * 20.0) % 2 == 0

func _handle_movement(delta: float) -> void:
	if is_dashing or _sneeze_push > 0.0:
		return
	
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	input_dir = input_dir.normalized()
	
	if input_dir != Vector2.ZERO:
		_last_move_direction = input_dir
	
	var speed_mult = get_node("/root/PlayerStats").speed_modifier * get_node("/root/PlayerStats").get_intoxication_effects().get("speed", 1.0)
	velocity = input_dir * move_speed * speed_mult
	
	_update_animation(input_dir)

func _handle_dash(delta: float) -> void:
	if Input.is_action_just_pressed("dash") and not Narrator.ate_input() and not is_dashing and _dash_cooldown_timer <= 0.0:
		if get_node("/root/PlayerStats").use_stamina(dash_stamina_cost):
			_start_dash()
		else:
			get_node("/root/GlobalEvents").show_floating_text.emit(global_position, "Sin estamina!", Color.YELLOW)

func _start_dash() -> void:
	is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown * pow(0.7, _rm().blessing("escurridiza"))
	_dash_hits.clear()
	
	var dir = _last_move_direction
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	
	_dash_direction = dir
	Sound.play("dash")
	velocity = dir * dash_speed * get_node("/root/PlayerStats").speed_modifier
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position, "DASH!", Color.CYAN)
	if _rm().blessing("equilibrio") > 0 and current_weapon:
		_ring(10, get_weapon_damage() * _player_stats.damage_modifier)
	

func _handle_attack(delta: float) -> void:
	if Input.is_action_pressed("attack") and not Narrator.ate_input() and _attack_timer <= 0.0 and not current_weapon:
		# Sin cuerpo a cuerpo: a manos limpias te rompes tu antes que ellos.
		_attack_timer = 1.0
		_global_events.show_floating_text.emit(global_position + Vector2(0, -30), "¡CRAC! (tu mano)", Color("ff7ac0"))
		Narrator.say_first("no_weapon_attack")
		Sound.play("crack")
	elif Input.is_action_pressed("attack") and not Narrator.ate_input() and _attack_timer <= 0.0:
		_shoot()
		_attack_timer = float(current_weapon.custom_data.get("fire_rate", attack_cooldown)) / (get_node("/root/PlayerStats").fire_rate_modifier * get_node("/root/PlayerStats").get_intoxication_effects().get("speed", 1.0))

func get_weapon_damage() -> float:
	# Weapons store their damage inside custom_data (see assets/data/items),
	# not as an Item property, so has("base_damage") was always false.
	if current_weapon == null:
		return 0.0
	if current_weapon.custom_data.has("base_damage"):
		return float(current_weapon.custom_data["base_damage"])
	return 10.0

## Multiplicador de un stat que da el arma equipada (efectos STAT_MOD del .tres).
func _weapon_mod(stat: String) -> float:
	var m := 1.0
	for effect in current_weapon.effects:
		if effect.type == 0 and effect.stat == stat:
			m *= effect.magnitude
	return m

func _get_effect_multiplier(effects: Dictionary, key: String) -> float:
	if effects.has(key):
		return float(effects[key])
	return 1.0

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_using_pad = true
	elif event is InputEventMouseMotion or event is InputEventMouseButton:
		_using_pad = false

## Siempre al raton; con mando, hacia donde caminas.
func _update_aim() -> void:
	if not _using_pad:
		var to_mouse := get_global_mouse_position() - weapon_pivot.global_position
		if to_mouse.length() > 4.0:
			_aim = to_mouse.normalized()
	elif _last_move_direction != Vector2.ZERO:
		_aim = _last_move_direction
	# el arma apunta siempre a donde vas a disparar
	weapon_pivot.rotation = _aim.angle()
	weapon_sprite.flip_v = _aim.x < 0
	animated_sprite.flip_h = _aim.x < 0

func _home_bonus() -> float:
	var rm = get_node("/root/RunManager")
	return 1.15 if rm.floor_data().kingdom == rm.character_data().kingdom else 1.0

func _shoot() -> void:
	Sound.play("shoot")
	var cd: Dictionary = current_weapon.custom_data
	var effects = _player_stats.get_intoxication_effects()
	var accuracy: float = maxf(0.2, _player_stats.accuracy_modifier * _get_effect_multiplier(effects, "accuracy") * _weapon_mod("accuracy"))
	var dmg: float = get_weapon_damage() * _player_stats.damage_modifier * _get_effect_multiplier(effects, "damage") * _weapon_mod("damage") * _home_bonus()
	var count: int = int(cd.get("pellets", cd.get("projectiles", 1)))
	# borracho = mas dispersion, no fallos aleatorios
	var spread: float = float(cd.get("spread", 0.05)) / accuracy
	var extra: int = _rm().blessing("descarga")
	if extra > 0:
		count += extra
		dmg *= 0.7
		spread = maxf(spread, 0.12)  # en abanico, no todas por el mismo sitio
	_attack_anim = 0.15
	for i in range(count):
		var b := PLAYER_BULLET.instantiate()
		var ang := _aim.angle() + RNG.randf_range(-spread, spread)
		if count > 1:
			ang += (i - (count - 1) / 2.0) * spread
		# escopeta: base_damage repartido entre perdigones (x2 si aciertan todos a quemarropa)
		b.damage = dmg * 2.0 / count if cd.has("pellets") else dmg
		if RNG.randf() < _player_stats.crit_chance_modifier:
			b.damage *= _player_stats.crit_damage_modifier
		b.speed = float(cd.get("projectile_speed", 500)) * _player_stats.projectile_speed_modifier
		b.rotation = ang
		_bless_bullet(b)
		get_parent().add_child(b)
		b.global_position = weapon_pivot.global_position + Vector2.RIGHT.rotated(ang) * 14.0

func _rm() -> Node:
	return get_node("/root/RunManager")

func _bless_bullet(b: Node) -> void:
	b.pierce = _rm().blessing("penetracion")
	b.knockback *= 1.0 + 1.5 * _rm().blessing("embestida")

## Anillo de balas alrededor del jugador (Orgullo Herido, Equilibrio Hormonal).
func _ring(n: int, dmg: float) -> void:
	for i in n:
		var b := PLAYER_BULLET.instantiate()
		b.damage = dmg
		b.speed = 420.0
		b.rotation = TAU * i / n
		_bless_bullet(b)
		get_parent().add_child.call_deferred(b)
		b.set_deferred("global_position", global_position)

## Dash Cortante: cada enemigo que atraviesas en un dash recibe un tajo (una vez).
var _dash_hits: Array = []
func _dash_cut() -> void:
	var lvl: int = _rm().blessing("filo")
	if lvl == 0 or not current_weapon:
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if e not in _dash_hits and is_instance_valid(e) and e.global_position.distance_to(global_position) < 40.0:
			_dash_hits.append(e)
			e.take_damage(get_weapon_damage() * _player_stats.damage_modifier * 1.5 * lvl, self, _dash_direction * 200.0)

func _sneeze() -> void:
	_sneeze_in = RNG.randf_range(3.0, 6.0)
	var dir := Vector2.RIGHT.rotated(RNG.randf() * TAU)
	velocity = dir * 420.0
	_sneeze_push = 0.15
	_global_events.show_floating_text.emit(global_position + Vector2(0, -30), "¡ACHÍS!", Color("ff7ac0"))

func start_allergy(seconds: float) -> void:
	_allergy = maxf(_allergy, seconds)
	_sneeze_in = 1.5
	animated_sprite.self_modulate = Color(1.0, 0.75, 0.8)

func _handle_interaction() -> void:
	if Input.is_action_just_pressed("interact"):
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + _last_move_direction * interaction_range)
		query.collision_mask = 1 << 2
		var result = space_state.intersect_ray(query)
		
		if result:
			var obj = result.collider
			if obj.has_method("interact"):
				obj.interact(self)

func _update_animation(dir: Vector2) -> void:
	if not animated_sprite:
		return
	
	var anim = "idle"
	if dir != Vector2.ZERO:
		anim = "walk"
	if _attack_anim > 0.0:
		anim = "attack"
	if is_dashing:
		anim = "dash"
	
	if animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)
	

func _on_health_changed(current: float, max: float) -> void:
	pass

func _on_shields_changed(current: float, max: float) -> void:
	pass

func _on_stamina_changed(current: float, max: float) -> void:
	pass

func _on_intoxication_changed(level: float, tier: int) -> void:
	var tier_names = ["Sober", "Tipsy", "Drunk", "BLACKOUT"]
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position, "Intoxicación: %s" % tier_names[tier], Color.MAGENTA)
	
	if tier == 3:
		animated_sprite.modulate = Color(1.0, 0.5, 1.0, 0.8)
	elif tier == 2:
		animated_sprite.modulate = Color(1.0, 0.7, 0.3)
	elif tier == 1:
		animated_sprite.modulate = Color(1.0, 0.9, 0.5)

func _on_hurtbox_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_attack"):
		return
	if area.has_method("on_hit"):
		area.on_hit()  # los proyectiles desaparecen aunque no hagan daño
	receive_hit(float(area.damage) if "damage" in area else 10.0)

## Unico punto de entrada del daño al jugador. Devuelve false si lo esquivo
## (dash o invulnerabilidad tras un golpe).
func receive_hit(dmg: float) -> bool:
	if is_dashing or _iframes > 0.0:
		return false
	_iframes = HIT_IFRAMES
	_player_stats.take_damage(dmg)
	Sound.play("hurt")
	var pride: int = _rm().blessing("orgullo")
	if pride > 0 and current_weapon and _player_stats.current_health > 0.0:
		_ring(8, get_weapon_damage() * _player_stats.damage_modifier * pride)
	return true

## El arma que sueltas al coger otra se queda en el suelo: puedes volver a por ella.
func _drop_weapon(id: String) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main and main.current_room:
		main._spawn_pickup(main.current_room, id, global_position - main.current_room.global_position + Vector2(0, 28))

func equip_weapon(item: Item) -> void:
	current_weapon = item
	weapon_sprite.texture = item.sprite
	if not collected_items.has(item.id):
		collected_items.append(item.id)
	print("Equipped: %s" % item.display_name)

func has_item(item_id: String) -> bool:
	# Locked doors probe this before opening.
	return collected_items.has(item_id)

func add_item_to_inventory(item_id: String) -> void:
	var item = get_node("/root/ItemDatabase").get_item(item_id)
	var rm = get_node("/root/RunManager")
	if item and "moneda" in item.tags:
		var n := RNG.randi_range(1, 2)  # economia: ver COIN_DROP_CHANCE en main.gd
		rm.add_coins(n)
		get_node("/root/LoreDatabase")._on_item_picked_up(item, n)  # cuenta para "La Moneda Pudorosa"
		return
	if item:
		var hormone: String = item.custom_data.get("hormone", "")
		if hormone != "":
			rm.hormones[hormone] = true
			_global_events.hormones_changed.emit()
		# Lo del reino contrario: necesario a veces, pero da alergia (el ornitorrinco ni se inmuta).
		var opposite: bool = ("masculino" in item.tags and rm.is_allergic_to("testosterona")) or ("femenino" in item.tags and rm.is_allergic_to("estrogeno"))
		if opposite:
			start_allergy(25.0)
			_player_stats.add_intoxication(30.0)
			Narrator.say_first("allergy")
			get_node("/root/LoreDatabase").custom_event("allergy")
		elif (hormone != "" or "masculino" in item.tags or "femenino" in item.tags) and rm.character == "ornitorrinco":
			Narrator.say_first("platypus_immune")
		if not collected_items.has(item_id):
			collected_items.append(item_id)
		# Picking up a weapon equips it, otherwise combat stays impossible.
		if item.equip_slot == Item.EquipSlot.WEAPON:
			if current_weapon and current_weapon != item:
				_drop_weapon(current_weapon.id)
			equip_weapon(item)
		get_node("/root/RunManager").record_item_collected(item_id)
		get_node("/root/GlobalEvents").item_picked_up.emit(item, 1)
		
		# Los efectos de un arma solo valen mientras la llevas (ver _weapon_mod):
		# aplicarlos al recogerla los acumulaba cada vez que la soltabas y cogias.
		for effect in ([] if item.equip_slot == Item.EquipSlot.WEAPON else item.effects):
			if effect.type == 1:  # INTOXICATION
				get_node("/root/PlayerStats").add_intoxication(effect.intoxication_amount)
			elif effect.type == 2:  # HEAL
				get_node("/root/PlayerStats").heal(effect.magnitude)
			elif effect.type == 0:  # STAT_MOD
				get_node("/root/PlayerStats").apply_stat_mod(effect.stat, effect.magnitude)
			elif effect.type == 5:  # UNLOCK_LORE
				get_node("/root/LoreDatabase").unlock_entry(effect.lore_entry_id)

func _on_player_died() -> void:
	get_node("/root/RunManager").end_run(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Use cached references: absolute get_node() is invalid once the node
		# has left the scene tree.
		if is_instance_valid(_player_stats):
			_player_stats.health_changed.disconnect(_on_health_changed)
			_player_stats.shields_changed.disconnect(_on_shields_changed)
			_player_stats.stamina_changed.disconnect(_on_stamina_changed)
			_player_stats.intoxication_changed.disconnect(_on_intoxication_changed)
		if is_instance_valid(_global_events) and _global_events.player_died.is_connected(_on_player_died):
			_global_events.player_died.disconnect(_on_player_died)