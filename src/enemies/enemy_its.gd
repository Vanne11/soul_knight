extends Enemy
class_name EnemyIts

## Microbios de infecciones de transmision sexual (ITS). Una sola escena/script, un
## its_kind por bicho (main.gd lo pasa en los datos). Cada uno guina a la infeccion real:
##   clamidia  -> asintomatica: casi invisible hasta que la tienes encima
##   herpes    -> recurrente: al caer deja una ampolla; si no la pisas, rebrota (una vez)
##   gonorrea  -> deja un rastro de gotas que escuecen al pisarlas
##   vph       -> suelta verruguitas
##   sifilis   -> la gran imitadora: se disfraza de otro bicho de la sala
##   verruguita-> minion debil del VPH
## Sus golpes pueden contagiar (PlayerStats.infect): leve, temporal, y el preservativo lo evita.

const PUDDLE := preload("res://src/enemies/its_puddle.gd")
const SCENE_PATH := "res://src/enemies/enemy_its.tscn"

@export var its_kind: String = "clamidia"

## kind -> [tipo de contagio, probabilidad por golpe, segundos]
const CONTAGION_OF := {
	"clamidia": ["ardor", 0.5, 8.0],
	"herpes": ["picazon", 0.5, 8.0],
	"gonorrea": ["ardor", 0.5, 8.0],
	"vph": ["picazon", 0.5, 8.0],
	"sifilis": ["picazon", 0.5, 8.0],
	"verruguita": ["picazon", 0.25, 6.0],
}

# clamidia
const GHOST_ALPHA := 0.1
const GHOST_NEAR := 110.0
const GHOST_FAR := 260.0
var _reveal_t := 0.0
# herpes
const REBROTE_SECONDS := 6.0
const REBROTE_HEALTH := 0.5
const REMATE_RADIUS := 26.0
var reborn := false
var _latent := false
var _latent_t := 0.0
var _residue: Sprite2D = null
# gonorrea
const DRIP_EVERY := 0.55
const MAX_PUDDLES := 14
var _drip_t := 0.0
# vph
const WART_EVERY := 6.0
const WART_MAX_ALIVE := 4
var _wart_t := 3.0
# sifilis
var _disguised := false
var _real_name := ""
var _real_frames: SpriteFrames = null
var _real_offset := Vector2.ZERO
var _real_scale := Vector2.ONE


func _ready() -> void:
	super()
	_real_name = enemy_name
	match its_kind:
		"clamidia":
			windup_time = 0.3
			recover_time = 0.7
			lunge_speed = 560.0
			animated_sprite.self_modulate.a = GHOST_ALPHA
		"herpes":
			recover_time = 0.8
		"gonorrea":
			windup_time = 0.6
		"vph":
			windup_time = 0.7
			recover_time = 0.9
		"sifilis":
			windup_time = 0.4
			_disguise_deferred()
		"verruguita":
			windup_time = 0.35
			recover_time = 0.5
			lunge_trigger = 70.0
			lunge_speed = 380.0
			detection_range = 520.0
			# cuerpo mas chico (el sprite ya viene en 16x18)
			for n in ["CollisionShape2D", "Hurtbox", "Hitbox"]:
				var c := get_node_or_null(n) as Node2D
				if c:
					c.scale = Vector2(0.6, 0.6)
			animated_sprite.offset = Vector2(0, -2)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	match its_kind:
		"clamidia":
			_update_ghost(delta)
		"vph":
			_update_warts(delta)
	super(delta)


func _process(delta: float) -> void:
	if _latent:
		_update_latent(delta)


# ------------------------------------------------------------------ contagio
func _try_infect() -> void:
	var c: Array = CONTAGION_OF.get(its_kind, ["picazon", 0.3, 6.0])
	if RNG.randf() < float(c[1]):
		get_node("/root/PlayerStats").infect(c[0], float(c[2]), its_kind)


func _strike() -> void:
	if _hit_done:
		return
	for b in hitbox.get_overlapping_bodies():
		if b.has_method("receive_hit") and b.receive_hit(damage):
			_hit_done = true
			_try_infect()


# ------------------------------------------------------------------ clamidia
func _update_ghost(delta: float) -> void:
	_reveal_t = maxf(0.0, _reveal_t - delta)
	var a := 1.0
	if _reveal_t <= 0.0 and state not in [State.WINDUP, State.LUNGE]:
		var d := 9999.0
		if target and is_instance_valid(target):
			d = global_position.distance_to(target.global_position)
		# fuera de rango casi no se ve; cerca aparece
		a = clampf(inverse_lerp(GHOST_FAR, GHOST_NEAR, d), 0.0, 1.0) * (1.0 - GHOST_ALPHA) + GHOST_ALPHA
	animated_sprite.self_modulate.a = a


# ------------------------------------------------------------------ vph
func _update_warts(delta: float) -> void:
	if state == State.IDLE or not target:
		return
	_wart_t -= delta
	if _wart_t > 0.0:
		return
	_wart_t = WART_EVERY
	var alive := get_tree().get_nodes_in_group("verruguita").size()
	var n := mini(2, WART_MAX_ALIVE - alive)
	for i in range(n):
		_spawn_wart(Vector2(-26 if i == 0 else 26, 6))
	if n > 0:
		get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -34), tr("FX_VERRUGAS"), Color("e6b48c"))


func _spawn_wart(off: Vector2) -> void:
	var e: Node = load(SCENE_PATH).instantiate()
	e.its_kind = "verruguita"
	e.enemy_name = "Verruguita"
	e.max_health = maxf(6.0, max_health * 0.15)
	e.damage = damage * 0.5
	e.move_speed = move_speed * 2.0
	e.get_node("AnimatedSprite2D").sprite_frames = load("res://assets/sprites/enemies/verruguita_sprite_frames.tres")
	e.add_to_group("verruguita")
	var room := find_owning_room()
	if room != null:
		room.enemies_spawned.append(e)  # cuenta para despejar la sala
	_spawn_container().add_child.call_deferred(e)
	e.set_deferred("global_position", global_position + off)


# ------------------------------------------------------------------ gonorrea / sifilis
func _chase(delta: float) -> void:
	if its_kind == "sifilis" and _disguised and target and global_position.distance_to(target.global_position) <= lunge_trigger:
		_reveal()  # sorpresa: se quita el disfraz justo antes de embestir
	super(delta)
	if its_kind == "gonorrea":
		_drip_t -= delta
		if _drip_t <= 0.0 and velocity.length() > 10.0:
			_drip_t = DRIP_EVERY
			_drop_puddle()


func _drop_puddle() -> void:
	var olds := get_tree().get_nodes_in_group("its_puddle")
	if olds.size() >= MAX_PUDDLES:
		olds[0].queue_free()
	var p := Node2D.new()
	p.set_script(PUDDLE)
	# dano chico: no escala como el golpe del bicho
	p.set("tick_damage", clampf(damage * 0.25, 1.0, 4.0))
	_spawn_container().add_child(p)
	p.global_position = global_position + Vector2(0, 6)


func _disguise_deferred() -> void:
	await get_tree().create_timer(0.2).timeout  # que el resto de la sala ya exista
	if state == State.DEAD or not is_inside_tree():
		return
	var room := find_owning_room()
	var models: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not is_instance_valid(e) or (e is EnemyIts) or e.is_in_group("boss"):
			continue
		if room != null and e.has_method("find_owning_room") and e.find_owning_room() != room:
			continue
		if e.get_node_or_null("AnimatedSprite2D") != null and "enemy_name" in e:
			models.append(e)
	if models.is_empty():
		return  # sin nadie a quien imitar, va de cara
	var m = models[RNG.randi_range(0, models.size() - 1)]
	var ms: AnimatedSprite2D = m.get_node("AnimatedSprite2D")
	_real_frames = animated_sprite.sprite_frames
	_real_offset = animated_sprite.offset
	_real_scale = animated_sprite.scale
	animated_sprite.sprite_frames = ms.sprite_frames
	animated_sprite.offset = ms.offset
	animated_sprite.scale = ms.scale
	animated_sprite.play("idle")
	enemy_name = m.enemy_name
	_disguised = true


func _reveal() -> void:
	if not _disguised:
		return
	_disguised = false
	animated_sprite.sprite_frames = _real_frames
	animated_sprite.offset = _real_offset
	animated_sprite.scale = _real_scale
	animated_sprite.play("attack")
	enemy_name = _real_name
	HitFx.flash(animated_sprite)
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -34), tr("FX_SIFILIS"), Color("c08cff"))


# ------------------------------------------------------------------ dano / muerte
func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if state == State.DEAD:
		return 0.0
	_reveal()
	_reveal_t = 1.5
	if its_kind == "herpes" and not reborn and current_health - amount <= 0.0:
		_go_latent(amount)
		return amount
	return super(amount, source, kb)


## Herpes: "muere" pero deja su ampolla. Pisarla lo remata; si no, rebrota con media vida.
func _go_latent(amount: float) -> void:
	current_health = 0.0
	state = State.DEAD
	get_node("/root/GlobalEvents").show_damage_number.emit(global_position + Vector2(0, -30), amount, false)
	animated_sprite.modulate = Color.WHITE
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(7, false)  # huecos (capa 64): el cuerpo sigue la misma regla que con los muros
	hurtbox.set_deferred("monitoring", false)
	animated_sprite.play("death")
	await get_tree().create_timer(0.5).timeout
	animated_sprite.visible = false
	_residue = Sprite2D.new()
	_residue.texture = load("res://assets/sprites/enemies/herpes_residuo.png")
	_residue.position = Vector2(0, 8)
	add_child(_residue)
	_latent = true
	_latent_t = REBROTE_SECONDS


func _update_latent(delta: float) -> void:
	_latent_t -= delta
	# la ampolla late cada vez mas rapido: avisa de que va a rebrotar
	_residue.scale = Vector2.ONE * (1.0 + 0.12 * sin(_latent_t * (4.0 + (REBROTE_SECONDS - _latent_t) * 2.0)))
	if not target or not is_instance_valid(target):
		_find_target()
	if target and global_position.distance_to(target.global_position + Vector2(0, 8)) <= REMATE_RADIUS:
		_remate()
	elif _latent_t <= 0.0:
		_rebrote()


func _remate() -> void:
	_latent = false
	_residue.queue_free()
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -20), tr("FX_REMATE"), Color("ffd84a"))
	Sound.play("hurt")
	_drop_loot()
	get_node("/root/GlobalEvents").enemy_killed.emit(self, target)
	get_node("/root/RunManager").total_enemies_killed += 1
	queue_free()


func _rebrote() -> void:
	_latent = false
	_residue.queue_free()
	reborn = true
	current_health = max_health * REBROTE_HEALTH
	animated_sprite.visible = true
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(7, true)  # huecos (capa 64): el cuerpo sigue la misma regla que con los muros
	hurtbox.set_deferred("monitoring", true)
	state = State.CHASE
	animated_sprite.play("idle")
	HitFx.flash(animated_sprite)
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -34), tr("FX_REBROTA"), Color("ff7a7a"))
