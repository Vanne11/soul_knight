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
## Cargas de dash (Vulvalquiria: 2). Se gasta una por dash y se rellenan juntas tras el enfriamiento.
var dash_charges := 1
var _dash_left := 1
var _dash_refill := 0.0
## Habilidad propia del heroe (src/player/abilities/<heroe>.gd), nodo hijo creado en _apply_character.
var ability: HeroAbility = null
## "Mirar a camara" y gestos de espera (ver _update_animation y look_at_camera).
var _camera_left := 0.0
var _gesture_left := 0.0
var _idle_t := 0.0
var _gesture_in := 7.0
const GESTURE_EVERY := Vector2(6.0, 12.0)
const GESTURE_TIME := 2.4
const HERO_ABILITIES := {
	"pitocles": preload("res://src/player/abilities/pitocles.gd"),
	"vulvalquiria": preload("res://src/player/abilities/vulvalquiria.gd"),
	"ornitorrinco": preload("res://src/player/abilities/ornitorrinco.gd"),
}
## Objeto con el que arranca cada heroe (reliquia pasiva; tag "especial" = no sale de botin).
const STARTING_ITEMS := {"pitocles": "casco_pulido", "vulvalquiria": "trenza_combate", "ornitorrinco": "huevo_suerte"}
var _last_move_direction: Vector2 = Vector2.DOWN
## Invulnerabilidad tras recibir un golpe (y durante el dash): sin esto un grupo
## de espermatozoides te borra en un frame y no hay forma "justa" de esquivar.
const HIT_IFRAMES := 0.8
var _iframes: float = 0.0
var _attack_anim: float = 0.0
## Tras disparar, el cuerpo sigue mirando al objetivo este rato aunque camines.
const FACE_AIM_MS := 600
var _last_shot_ms := -100000
## Alergia a la hormona del reino contrario: estornudos que te desplazan sin querer.
var _allergy: float = 0.0
var _sneeze_in: float = 0.0
var _sneeze_push: float = 0.0
## Toallita Humeda: segundos restantes de inmunidad a la alergia.
var _allergy_immune: float = 0.0
var _aim: Vector2 = Vector2.RIGHT
var _using_pad := false
const DASH_LIFT := 9.0
const ENEMY_LAYER := 2  # capa fisica de los enemigos (collision_layer = 2)
var _shadow_scale := Vector2.ZERO
## Retroceso visual del arma al disparar (px): solo mueve el sprite, nunca el origen de las balas.
const RECOIL_KICK := 4.0
const RECOIL_MAX := 6.0
const RECOIL_RETURN := 70.0  # px/s
var _recoil := 0.0
var _weapon_base_x := 16.0
## Mano de cada cuadro de animacion (tools/gen_hand_anchors.py): el arma se cuelga de ahi
## y sigue el vaiven del caminar y el golpe del ataque. {animacion: [[x, y], ...]}
const HAND_ANCHORS := "res://assets/data/hand_anchors.json"
var _hand: Dictionary = {}
const PLAYER_BULLET := preload("res://src/player/player_bullet.tscn")
const WEAPON_GAUGE := preload("res://src/player/weapon_gauge.gd")
## Mecanicas por arma (custom_data): cargador/recarga ("magazine", "reload") y calor
## ("heat_per_shot"). El medidor bajo los pies las muestra (weapon_gauge.gd).
const HEAT_MAX := 100.0
const HEAT_COOL := 30.0        # enfriamiento por segundo sin disparar
const HEAT_LOCK_COOL := 60.0   # enfriamiento forzado tras sobrecalentar
const HEAT_UNLOCK := 35.0      # al bajar de aqui el arma vuelve a disparar
const IDLE_RELOAD_S := 1.0     # sin disparar este rato, el cargador se rellena solo
var _ammo := 0
var _reload_t := 0.0           # >0 = recargando (segundos que faltan)
var _reload_total := 1.0
var _heat := 0.0
var _overheated := false
var _gauge: Node2D = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var weapon_sprite: Sprite2D = $WeaponPivot/WeaponSprite

@onready var _player_stats: PlayerStats = get_node("/root/PlayerStats")
@onready var _global_events: GlobalEvents = get_node("/root/GlobalEvents")

func _ready() -> void:
	add_to_group("player")
	_weapon_base_x = _grip_offset()
	_gauge = WEAPON_GAUGE.new()
	add_child(_gauge)
	_player_stats.health_changed.connect(_on_health_changed)
	_player_stats.shields_changed.connect(_on_shields_changed)
	_player_stats.stamina_changed.connect(_on_stamina_changed)
	_player_stats.intoxication_changed.connect(_on_intoxication_changed)
	_player_stats.revived.connect(_on_revived)
	# Sin esta conexion la run nunca terminaba al morir: ni huesos ni estadisticas.
	_global_events.player_died.connect(_on_player_died)
	
	_player_stats.reset_for_new_run()
	_apply_character()
	_load_hand_anchors()
	ActorFx.setup_actor(self, animated_sprite)
	
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_entered)

func _apply_character() -> void:
	var rm = get_node("/root/RunManager")
	var frames := "res://assets/sprites/player/%s/sprite_frames.tres" % rm.character
	if ResourceLoader.exists(frames):
		animated_sprite.sprite_frames = load(frames)
	# Cada heroe juega distinto: numeros y habilidad en src/player/abilities/.
	if HERO_ABILITIES.has(rm.character):
		ability = HERO_ABILITIES[rm.character].new()
		ability.name = "HeroAbility"
		add_child(ability)
		ability.setup(self)
		var gauge := AbilityGauge.new()
		gauge.ability = ability
		add_child(gauge)
	_dash_left = dash_charges
	get_tree().create_timer(0.4).timeout.connect(_give_starting_item)
	_gesture_in = RNG.randf_range(GESTURE_EVERY.x, GESTURE_EVERY.y)

## Entrega el objeto inicial una vez que el HUD ya existe (para que ocupe su casilla).
func _give_starting_item() -> void:
	var id: String = STARTING_ITEMS.get(_rm().character, "")
	if id != "" and is_instance_valid(self) and not collected_items.has(id) \
			and get_node("/root/ItemDatabase").get_item(id) != null:
		add_item_to_inventory(id)

## Se gira hacia el jugador (cuarta pared): gesto propio de cada heroe. Lo puede llamar
## cualquier sistema (`if player.has_method("look_at_camera")`). Caminar lo cancela.
func look_at_camera(seconds := 2.5) -> void:
	_camera_left = seconds
	_gesture_left = 0.0

func _physics_process(delta: float) -> void:
	_handle_timers(delta)
	_handle_movement(delta)
	_handle_dash(delta)
	_update_aim()
	_update_dash_lift()
	_update_weapon_state(delta)
	_handle_attack(delta)
	_handle_interaction()
	move_and_slide()

## Solo visual: en el dash el sprite sube en arco; la sombra se queda en el suelo y se achica.
func _update_dash_lift() -> void:
	var lift := 0.0
	if is_dashing and dash_duration > 0.0:
		lift = sin(clampf(1.0 - _dash_timer / dash_duration, 0.0, 1.0) * PI) * DASH_LIFT
	if ability:
		lift += ability.hover_lift()
	animated_sprite.position.y = -lift
	weapon_pivot.position = _hand_position()
	_recoil = maxf(0.0, _recoil - RECOIL_RETURN * get_physics_process_delta_time())
	weapon_sprite.position.x = _weapon_base_x - _recoil
	var shadow := get_node_or_null("ContactShadow") as Sprite2D
	if shadow:
		if _shadow_scale == Vector2.ZERO:
			_shadow_scale = shadow.scale
		shadow.scale = _shadow_scale * (1.0 - 0.3 * minf(lift, DASH_LIFT) / DASH_LIFT)
		shadow.modulate.a = 1.0 - 0.25 * minf(lift, DASH_LIFT) / DASH_LIFT

func _load_hand_anchors() -> void:
	var f := FileAccess.open(HAND_ANCHORS, FileAccess.READ)
	if f == null:
		return
	var all = JSON.parse_string(f.get_as_text())
	if all is Dictionary:
		_hand = all.get(_rm().character, {})


## Mano del cuadro actual en coordenadas del jugador (con giro y elevacion del dash).
## Sin datos para el personaje, el punto fijo de siempre.
func _hand_position() -> Vector2:
	var anchor_anim: String = animated_sprite.animation
	if anchor_anim.begins_with("walk"):  # walk_up/walk_down cuelgan del mismo vaiven
		anchor_anim = "walk"
	elif anchor_anim.begins_with("idle") or anchor_anim in ["camera", "gesture"]:
		anchor_anim = "idle"
	var pts: Array = _hand.get(anchor_anim, [])
	var tex := animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame) if animated_sprite.sprite_frames else null
	if pts.is_empty() or tex == null:
		return Vector2(0, 6.0 + animated_sprite.position.y)
	var p: Array = pts[animated_sprite.frame % pts.size()]
	var local := (Vector2(p[0], p[1]) + Vector2(0.5, 0.5) - tex.get_size() * 0.5) * animated_sprite.scale
	if animated_sprite.flip_h:
		local.x = -local.x
	return animated_sprite.position + animated_sprite.offset + local


## El arma se agarra por su primer tercio: la mano queda sobre la empunadura.
func _grip_offset() -> float:
	if weapon_sprite.texture == null:
		return 16.0
	return weapon_sprite.texture.get_width() * weapon_sprite.scale.x * 0.2

func _handle_timers(delta: float) -> void:
	if _dash_timer > 0.0:
		_dash_timer -= delta
		_dash_cut()
		if ability:
			ability.on_dash_tick(_dash_direction)
		if _dash_timer <= 0.0:
			is_dashing = false
			set_collision_mask_value(ENEMY_LAYER, true)
			velocity = velocity.lerp(Vector2.ZERO, 10.0 * delta)
	
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
	if _dash_refill > 0.0:
		_dash_refill -= delta
		if _dash_refill <= 0.0:
			_dash_left = dash_charges
	_camera_left = maxf(0.0, _camera_left - delta)
	_gesture_left = maxf(0.0, _gesture_left - delta)
	
	if _attack_timer > 0.0:
		_attack_timer -= delta
	if _attack_anim > 0.0:
		_attack_anim -= delta
	_sneeze_push = maxf(0.0, _sneeze_push - delta)
	_allergy_immune = maxf(0.0, _allergy_immune - delta)
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
	
	var speed_mult = get_node("/root/PlayerStats").speed_modifier * get_node("/root/PlayerStats").get_intoxication_effects().get("speed", 1.0) * get_node("/root/PlayerStats").contagion_speed_mult()
	if ability:
		speed_mult *= ability.speed_mult()
	var st := _status()  # estados de enemigos (status_effects.gd): enrollado, jaula, correa...
	if st != null:
		speed_mult *= st.speed_mult()
	velocity = input_dir * move_speed * speed_mult
	if st != null:
		velocity += st.pull_velocity()
	
	_update_animation(input_dir)

## Estados que le ponen los enemigos (null si nunca te han puesto uno). Ver status_effects.gd.
func _status() -> StatusEffects:
	var n := get_node_or_null("StatusEffects")
	return n if n is StatusEffects else null

func _handle_dash(delta: float) -> void:
	var st := _status()
	if st != null and st.blocks_dash():
		return
	if Input.is_action_just_pressed("dash") and not Narrator.ate_input() and not is_dashing and _dash_cooldown_timer <= 0.0 and _dash_left > 0:
		if get_node("/root/PlayerStats").use_stamina(dash_stamina_cost):
			_start_dash()
		else:
			get_node("/root/GlobalEvents").show_floating_text.emit(global_position, tr("FX_NO_STAMINA"), Color.YELLOW)

func _start_dash() -> void:
	is_dashing = true
	_dash_timer = dash_duration
	var full_cd: float = dash_cooldown * pow(0.7, _rm().blessing("escurridiza"))
	if _dash_left >= dash_charges:
		_dash_refill = full_cd  # arranca la recarga de todas las cargas
	_dash_left -= 1
	_dash_cooldown_timer = full_cd if _dash_left <= 0 else 0.25
	if ability:
		ability.on_dash_start(_last_move_direction)
	_dash_hits.clear()
	
	var dir = _last_move_direction
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	
	_dash_direction = dir
	# El dash atraviesa enemigos: un cerco de bichos ya no te deja sin salida.
	set_collision_mask_value(ENEMY_LAYER, false)
	Sound.play("dash")
	velocity = dir * dash_speed * get_node("/root/PlayerStats").speed_modifier
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position, tr("FX_DASH"), Color.CYAN)
	if _rm().blessing("equilibrio") > 0 and current_weapon:
		_ring(10, get_weapon_damage() * _player_stats.damage_modifier)
	

func _handle_attack(delta: float) -> void:
	if ability and not ability.can_attack():
		return
	var st := _status()
	if st != null and st.blocks_shoot():
		return
	if Input.is_action_pressed("attack") and not Narrator.ate_input() and _attack_timer <= 0.0 and not current_weapon:
		# Sin cuerpo a cuerpo: a manos limpias te rompes tu antes que ellos.
		_attack_timer = 1.0
		_global_events.show_floating_text.emit(global_position + Vector2(0, -30), tr("FX_PUNCH"), Color("ff7ac0"))
		Narrator.say_first("no_weapon_attack")
		Sound.play("crack")
	elif Input.is_action_pressed("attack") and not Narrator.ate_input() and _attack_timer <= 0.0 and _weapon_ready():
		_shoot()
		_attack_timer = float(current_weapon.custom_data.get("fire_rate", attack_cooldown)) / _rate_mult()
		_after_shot()

## Cadencia total: bendiciones/reliquias x intoxicacion.
func _rate_mult() -> float:
	return _player_stats.fire_rate_modifier * _player_stats.get_intoxication_effects().get("speed", 1.0)

## false mientras el arma recarga o esta sobrecalentada (el gatillo no hace nada).
func _weapon_ready() -> bool:
	if _reload_t > 0.0 or _overheated:
		return false
	var mag := int(current_weapon.custom_data.get("magazine", 0))
	if mag > 0 and _ammo <= 0:
		_start_reload()
		return false
	return true

func _start_reload() -> void:
	_reload_total = maxf(0.2, float(current_weapon.custom_data.get("reload", 1.2)) / _rate_mult())
	_reload_t = _reload_total
	_global_events.show_floating_text.emit(global_position + Vector2(0, -34), tr("FX_RELOAD"), Color("ffd27a"))

## Gasta bala del cargador o suma calor tras cada disparo.
func _after_shot() -> void:
	_since_shot = 0.0
	var cd: Dictionary = current_weapon.custom_data
	if int(cd.get("magazine", 0)) > 0:
		_ammo -= 1
		if _ammo <= 0:
			_start_reload()
	var hps := float(cd.get("heat_per_shot", 0.0))
	if hps > 0.0:
		_heat += hps
		if _heat >= HEAT_MAX:
			_heat = HEAT_MAX
			_overheated = true
			Sound.play("hurt")
			_global_events.show_floating_text.emit(global_position + Vector2(0, -34), tr("FX_OVERHEAT"), Color("ff5a3c"))
			_steam_puff()

var _since_shot := 9.0

## Recarga, enfriamiento, color/inclinacion del arma y medidor. Corre cada frame de fisica.
func _update_weapon_state(delta: float) -> void:
	_since_shot += delta
	if current_weapon == null:
		_gauge.set("kind", "")
		return
	var cd: Dictionary = current_weapon.custom_data
	var mag := int(cd.get("magazine", 0))
	var hps := float(cd.get("heat_per_shot", 0.0))
	var tilt := 0.0
	var tint := Color.WHITE
	if mag > 0:
		if _reload_t > 0.0:
			_reload_t -= delta
			if _reload_t <= 0.0:
				_ammo = mag
				Sound.play("crack")
			else:
				tilt = sin(clampf(1.0 - _reload_t / _reload_total, 0.0, 1.0) * PI) * 0.9
		elif _ammo < mag and _since_shot > IDLE_RELOAD_S:
			_start_reload()
		_gauge.set("kind", "ammo")
		_gauge.set("count", mag)
		_gauge.set("ammo", _ammo)
		_gauge.set("progress", 1.0 - _reload_t / _reload_total if _reload_t > 0.0 else -1.0)
	elif hps > 0.0:
		if _overheated:
			_heat -= HEAT_LOCK_COOL * delta
			if _heat <= HEAT_UNLOCK:
				_overheated = false
		elif _since_shot > 0.2:
			_heat -= HEAT_COOL * delta
		_heat = maxf(0.0, _heat)
		tint = Color.WHITE.lerp(Color(1.0, 0.3, 0.2), clampf(_heat / HEAT_MAX, 0.0, 1.0) * 0.9)
		_gauge.set("kind", "heat")
		_gauge.set("value", _heat / HEAT_MAX)
		_gauge.set("locked", _overheated)
	else:
		_gauge.set("kind", "")
	weapon_sprite.modulate = tint
	weapon_sprite.rotation = tilt * (-1.0 if weapon_sprite.flip_v else 1.0)

## Vapor que sale del arma al sobrecalentarse.
func _steam_puff() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(_weapon_base_x + (weapon_sprite.texture.get_width() * weapon_sprite.scale.x * 0.5 if weapon_sprite.texture else 8.0), 0)
	p.amount = 14
	p.lifetime = 0.7
	p.one_shot = true
	p.explosiveness = 0.8
	p.emitting = true
	p.direction = Vector2.UP
	p.spread = 50.0
	p.gravity = Vector2(0, -40)
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 55.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.5
	p.color = Color(0.9, 0.9, 0.9, 0.7)
	weapon_pivot.add_child(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

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
## Apuntado forzado (lo usa el bot de pruebas tools/autoplay; ZERO = normal).
var aim_override := Vector2.ZERO

func _update_aim() -> void:
	if aim_override != Vector2.ZERO:
		_aim = aim_override.normalized()
	elif not _using_pad:
		var to_mouse := get_global_mouse_position() - weapon_pivot.global_position
		if to_mouse.length() > 4.0:
			_aim = to_mouse.normalized()
	elif _last_move_direction != Vector2.ZERO:
		_aim = _last_move_direction
	# el arma apunta siempre a donde vas a disparar
	weapon_pivot.rotation = _aim.angle()
	weapon_sprite.flip_v = _aim.x < 0
	# el cuerpo mira hacia donde caminas; solo se gira al raton mientras disparas
	# (si no, con el raton quieto a un lado caminaba de espaldas)
	var face_x := _aim.x
	if absf(velocity.x) > 10.0 and not Input.is_action_pressed("attack") \
			and Time.get_ticks_msec() - _last_shot_ms > FACE_AIM_MS:
		face_x = velocity.x
	animated_sprite.flip_h = face_x < 0

func _home_bonus() -> float:
	var rm = get_node("/root/RunManager")
	return 1.15 if rm.floor_data().kingdom == rm.character_data().kingdom else 1.0

func _shoot() -> void:
	_last_shot_ms = Time.get_ticks_msec()
	Sound.play("shoot")
	_muzzle_flash()
	_recoil = minf(RECOIL_MAX, _recoil + RECOIL_KICK)
	var cd: Dictionary = current_weapon.custom_data
	var effects = _player_stats.get_intoxication_effects()
	var accuracy: float = maxf(0.2, _player_stats.accuracy_modifier * _get_effect_multiplier(effects, "accuracy") * _weapon_mod("accuracy"))
	var dmg: float = get_weapon_damage() * _player_stats.damage_modifier * _get_effect_multiplier(effects, "damage") * _weapon_mod("damage") * _home_bonus()
	# Satisfyer: en vez de balas lanza un vortice que succiona (base_damage = dano por tic)
	if cd.has("vortex"):
		_attack_anim = 0.15
		var v := SuctionVortex.new()
		v.damage = dmg * (_player_stats.crit_damage_modifier if RNG.randf() < _player_stats.crit_chance_modifier else 1.0)
		v.radius = float(cd.get("vortex_radius", v.radius))
		v.duration = float(cd.get("vortex_duration", v.duration))
		v.pull = float(cd.get("vortex_pull", v.pull))
		v.rotation = _aim.angle()
		get_parent().add_child(v)
		v.global_position = weapon_pivot.global_position + _aim * 14.0
		return
	var base_count: int = int(cd.get("pellets", cd.get("projectiles", 1)))
	var count: int = base_count
	# borracho = mas dispersion, no fallos aleatorios
	var spread: float = float(cd.get("spread", 0.05)) / accuracy
	var extra: int = _rm().blessing("descarga")
	if extra > 0:
		count += extra
		dmg *= 0.7
		spread = maxf(spread, 0.12)  # en abanico, no todas por el mismo sitio
	_attack_anim = 0.15
	var crit_chance: float = _player_stats.crit_chance_modifier + float(cd.get("crit_bonus", 0.0))
	var speed: float = float(cd.get("projectile_speed", 500)) * _player_stats.projectile_speed_modifier
	for i in range(count):
		var b := PLAYER_BULLET.instantiate()
		var ang := _aim.angle() + RNG.randf_range(-spread, spread)
		if count > 1:
			ang += (i - (count - 1) / 2.0) * spread
		# escopeta: el dano del arma se reparte entre los perdigones PROPIOS (las extra de
		# Descarga Multiple suman encima); x2 si aciertan todos a quemarropa
		b.damage = dmg * 2.0 / base_count if cd.has("pellets") else dmg
		var crit := RNG.randf() < crit_chance
		if crit:
			b.damage *= _player_stats.crit_damage_modifier
		b.speed = speed
		b.crit = crit
		b.rotation = ang
		if cd.has("range"):
			b.lifetime = float(cd["range"]) / speed
		if cd.has("falloff_end"):  # caida de dano por distancia (escopeta)
			b.falloff_start = float(cd.get("falloff_start", 0.0))
			b.falloff_end = float(cd["falloff_end"])
			b.falloff_min = float(cd.get("falloff_min", 0.2))
		b.explosion_radius = float(cd.get("explosion_radius", 0.0))
		b.chain = int(cd.get("chain", 0))
		b.chain_radius = float(cd.get("chain_radius", 110.0))
		b.chain_mult = float(cd.get("chain_mult", 0.5))
		if cd.has("bullet_color"):
			b.tint = Color(cd["bullet_color"])
		_bless_bullet(b)
		b.pierce += int(cd.get("pierce", 0))
		b.knockback *= float(cd.get("knockback_mult", 1.0))
		get_parent().add_child(b)
		b.global_position = weapon_pivot.global_position + Vector2.RIGHT.rotated(ang) * 14.0

func _muzzle_flash() -> void:
	var tip := _weapon_base_x
	if weapon_sprite.texture:
		tip += weapon_sprite.texture.get_width() * weapon_sprite.scale.x * 0.5
	ActorFx.muzzle_flash(weapon_pivot, Vector2(tip, 0), Color(1.0, 0.78, 0.4))

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
	_global_events.show_floating_text.emit(global_position + Vector2(0, -30), tr("FX_SNEEZE"), Color("ff7ac0"))

func start_allergy(seconds: float) -> void:
	if _allergy_immune > 0.0:
		return
	_allergy = maxf(_allergy, seconds)
	_sneeze_in = 1.5
	animated_sprite.self_modulate = Color(1.0, 0.75, 0.8)

func stop_allergy() -> void:
	_allergy = 0.0
	animated_sprite.self_modulate = Color.WHITE

## Afinidad del objeto con el heroe: >1 si es del mismo reino (Pitocles=pene, Vulvalquiria=vulva).
## El resto (otro reino, neutral u ornitorrinco) funciona normal: no castiga.
func affinity_boost(item: Item) -> float:
	var aff: String = item.custom_data.get("affinity", "neutral")
	if aff != "neutral" and _rm().character == "ornitorrinco":
		return PLATYPUS_BOOST  # usa objetos de ambos reinos, sin alergia y con algo de provecho
	return AFFINITY_BOOST if aff != "neutral" and aff == _rm().character_data().kingdom else 1.0
const AFFINITY_BOOST := 1.5
const PLATYPUS_BOOST := 1.25

## Multiplicador escalado por afinidad: 1.3 -> 1.45, 0.7 -> 0.55 (el cambio crece, no el valor).
static func _boost_mult(m: float, boost: float) -> float:
	return m if boost == 1.0 else maxf(0.2, 1.0 + (m - 1.0) * boost)

## Aplica un efecto de objeto ya escalado por la afinidad (boost). Cubre los efectos
## viejos (0 STAT_MOD, 1 INTOXICATION, 2 HEAL, 5 UNLOCK_LORE) y los nuevos (>= 10).
func apply_item_effect(e: Dictionary, boost := 1.0) -> void:
	var st := _player_stats
	match int(e.type):
		0:  # STAT_MOD: "stamina" es una cantidad; el resto, multiplicadores
			if e.stat == "stamina":
				st.apply_stat_mod("stamina", float(e.magnitude) * boost)
			else:
				st.apply_stat_mod(e.stat, _boost_mult(float(e.magnitude), boost))
		1:  # INTOXICATION: solo se potencia lo que limpia
			var a := float(e.intoxication_amount)
			st.add_intoxication(a * boost if a < 0.0 else a)
		2:
			st.heal(float(e.magnitude) * boost)
		5:
			get_node("/root/LoreDatabase").unlock_entry(e.lore_entry_id)
		10:
			var d: Dictionary = e.duplicate()
			d.rate = float(e.rate) * boost
			st.apply_item_effect(d)
		11:
			var d: Dictionary = e.duplicate()
			d.magnitude = _boost_mult(float(e.magnitude), boost)
			st.apply_item_effect(d)
		12:
			var d: Dictionary = e.duplicate()
			d.magnitude = _boost_mult(float(e.magnitude), boost)
			st.apply_item_effect(d)
		13:
			var d: Dictionary = e.duplicate()
			d.hits = int(round(float(e.hits) * boost))
			st.apply_item_effect(d)
		14:
			var d: Dictionary = e.duplicate()
			d.fraction = minf(1.0, float(e.get("fraction", 0.4)) * boost)
			st.apply_item_effect(d)
		15:  # CLEANSE {intox (negativo), allergy}
			if float(e.get("intox", 0.0)) != 0.0:
				st.add_intoxication(float(e.intox) * boost)
			if e.get("allergy", false):
				stop_allergy()
		16:  # ALLERGY_IMMUNE {duration}
			_allergy_immune = float(e.duration) * boost
			stop_allergy()

func _on_revived() -> void:
	_iframes = 2.0
	HitFx.shake(0.5)
	_global_events.show_floating_text.emit(global_position + Vector2(0, -34), tr("FX_REVIVED"), Color("ffe08a"))

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
	var moving := dir != Vector2.ZERO
	var shooting := _attack_anim > 0.0 or Input.is_action_pressed("attack") \
			or Time.get_ticks_msec() - _last_shot_ms < FACE_AIM_MS
	var anim := "idle"
	if moving:
		anim = "walk"
		# vertical sin disparar: de frente al bajar, de espaldas al subir
		if not shooting and absf(dir.y) > absf(dir.x) * 1.3:
			anim = "walk_down" if dir.y > 0.0 else "walk_up"
		_idle_t = 0.0
		_camera_left = 0.0
		_gesture_left = 0.0
	elif shooting or is_dashing:
		_idle_t = 0.0
	else:
		_idle_t += get_physics_process_delta_time()
		if _camera_left > 0.0:
			anim = "camera"
		elif _gesture_left > 0.0:
			anim = "gesture"
		elif _idle_t > _gesture_in:
			_gesture_in = RNG.randf_range(GESTURE_EVERY.x, GESTURE_EVERY.y)
			_idle_t = 0.0
			_gesture_left = GESTURE_TIME
			anim = "gesture"
			_idle_quip()
	if _attack_anim > 0.0:
		anim = "attack"
	if is_dashing:
		anim = "dash"
	
	if animated_sprite.sprite_frames.has_animation(anim):
		animated_sprite.play(anim)

## Murmullo del heroe en sus gestos de espera (textos en locale/heroes.csv).
func _idle_quip() -> void:
	var key := "HERO_QUIP_%s_%d" % [_rm().character.to_upper(), RNG.randi_range(1, 3)]
	if tr(key) != key:
		_global_events.show_floating_text.emit(global_position + Vector2(0, -36), tr(key), Color("fff1d6"))

func _on_health_changed(current: float, max: float) -> void:
	pass

func _on_shields_changed(current: float, max: float) -> void:
	pass

func _on_stamina_changed(current: float, max: float) -> void:
	pass

func _on_intoxication_changed(level: float, tier: int) -> void:
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position, tr("FX_INTOX") % tr("INTOX_TIER_%d" % tier).capitalize(), Color.MAGENTA)
	
	if tier == 3:
		animated_sprite.modulate = Color(1.0, 0.5, 1.0, 0.8)
	elif tier == 2:
		animated_sprite.modulate = Color(1.0, 0.7, 0.3)
	elif tier == 1:
		animated_sprite.modulate = Color(1.0, 0.9, 0.5)

func _on_hurtbox_entered(area: Area2D) -> void:
	if not area.is_in_group("enemy_attack"):
		return
	if ability and ability.try_guard(area, float(area.damage) if "damage" in area else 10.0):
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
	HitFx.flash(animated_sprite)
	HitFx.shake(clampf(0.25 + dmg * 0.01, 0.25, 0.6))
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
	_ammo = int(item.custom_data.get("magazine", 0))
	_reload_t = 0.0
	_heat = 0.0
	_overheated = false
	weapon_sprite.texture = item.sprite
	_weapon_base_x = _grip_offset()
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
		var boost := affinity_boost(item)
		if boost > 1.0:
			_global_events.show_floating_text.emit(global_position + Vector2(0, -46), tr("FX_AFFINITY_FIT"), Color("ffd75a"))
		for effect in ([] if item.equip_slot == Item.EquipSlot.WEAPON else item.effects):
			apply_item_effect(effect, boost)

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
			_player_stats.revived.disconnect(_on_revived)
		if is_instance_valid(_global_events) and _global_events.player_died.is_connected(_on_player_died):
			_global_events.player_died.disconnect(_on_player_died)