extends EnemySwarmer
class_name EnemyHojitaCensora

## HOJITA CENSORA (esbirro de la Hoja de Parra y de la Parra entera). No persigue: ronda a
## distancia, planta un PARCHE DE PIXELES sobre ti (aviso 0.9 s) y se coloca detras del parche
## para dispararte a traves de el: la bala se esconde al cruzarlo y reaparece cerca. Cada
## disparo avisa (parpadea 0.55 s). No pega por contacto. Matarla deshace su parche.
## Ayuda al jefe: mientras mas hojitas vivas, mas parches cubren la sala.

enum H { ORBIT, PLANT, SETUP, AIM, RECOVER }

const LEAFG := Color(0.55, 0.9, 0.45)
const INK := Color(0.9, 0.9, 0.95)
const PROJECTILE := preload("res://src/enemies/projectile_enemy.tscn")
const PATCH_SIDE := 120.0
const SHOTS := 3
const MAX_PATCHES := 3

var h_state := H.ORBIT
var h_t := 2.0
var h_shots := 0
var _orbit_dir := 1.0
var _patch: BossZone = null
var _post := Vector2.ZERO  # donde se coloca para disparar (detras del parche)


func _init() -> void:
	personality = "none"


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.2}]
	super()
	add_to_group("hojita_censora")
	_orbit_dir = 1.0 if RNG.randf() < 0.5 else -1.0
	h_t = RNG.randf_range(1.2, 2.4)  # que no planten todas a la vez


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		_find_target()
		if not target:
			return
	h_t -= delta
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	match h_state:
		H.ORBIT:
			# ronda a ~220 px: se acerca si esta lejos, se aleja si esta cerca, y gira alrededor tuyo
			var radial := clampf((d - 220.0) / 80.0, -1.0, 1.0)
			var dir := to_t.normalized() * radial + to_t.normalized().orthogonal() * _orbit_dir * 0.8
			velocity = dir.normalized() * move_speed + _separation() * 60.0
			if h_t <= 0.0 and d < 380.0 and _patches_alive() < MAX_PATCHES:
				_plant()
		H.PLANT:
			velocity = Vector2.ZERO
			animated_sprite.modulate = Color(1.8, 2.2, 1.6) if int(h_t * 18.0) % 2 == 0 else Color.WHITE
			if h_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				h_state = H.SETUP
				h_t = 1.2
		H.SETUP:
			var to_post := _post - global_position
			velocity = to_post.normalized() * move_speed * 1.6 if to_post.length() > 14.0 else Vector2.ZERO
			if to_post.length() <= 14.0 or h_t <= 0.0:
				h_state = H.AIM
				h_t = 0.55
				h_shots = 0
				animated_sprite.play("attack")
		H.AIM:
			velocity = Vector2.ZERO
			animated_sprite.modulate = Color(1.8, 2.2, 1.6) if int(h_t * 20.0) % 2 == 0 else Color.WHITE
			if h_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				_shoot()
				h_shots += 1
				if h_shots >= SHOTS or not is_instance_valid(_patch):
					h_state = H.RECOVER
					h_t = 1.2
				else:
					h_t = 0.55
		H.RECOVER:
			velocity = velocity.lerp(Vector2.ZERO, 8.0 * delta)
			if h_t <= 0.0:
				h_state = H.ORBIT
				h_t = RNG.randf_range(3.0, 4.5)
				_orbit_dir = -_orbit_dir
	_update_animation(to_t)
	move_and_slide()


## Planta y dispara con sus propios cuadros (el swarmer los pisaba con idle/walk cada frame).
func _update_animation(dir: Vector2) -> void:
	var a := "plant" if h_state == H.PLANT else ("attack" if h_state == H.AIM else "")
	if a != "" and animated_sprite.sprite_frames.has_animation(a):
		if animated_sprite.animation != a:
			animated_sprite.play(a)
		if dir.x != 0:
			animated_sprite.flip_h = dir.x < 0
		return
	super(dir)


func _patches_alive() -> int:
	var n := 0
	for h in get_tree().get_nodes_in_group("hojita_censora"):
		if is_instance_valid(h) and is_instance_valid(h._patch):
			n += 1
	return n


func _separation() -> Vector2:
	var sep := Vector2.ZERO
	for o in get_tree().get_nodes_in_group("hojita_censora"):
		if o != self and is_instance_valid(o):
			var diff: Vector2 = global_position - o.global_position
			if diff.length() < 70.0 and diff.length() > 0.1:
				sep += diff.normalized()
	return sep


## Parche cerca de ti (a ~110 px, no encima) y puesto de tiro mas alla, con el parche de por medio.
func _plant() -> void:
	var dir := Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU))
	var tp: Vector2 = target.global_position
	var at := tp + dir * 110.0
	_post = tp + dir * 235.0
	var room := find_owning_room()
	if room != null:
		at = room.clamp_global(at, 70.0)
		_post = room.clamp_global(_post, 40.0)
	_patch = BossZone.rect(at, Vector2(PATCH_SIDE, PATCH_SIDE), 0.0, 0.9, 5.5, 0.0, INK)
	_patch.style = BossZone.Style.PIXEL
	_patch.fade = 0.4
	_spawn_container().add_child(_patch)
	_patch.global_position = at
	h_state = H.PLANT
	h_t = 0.9


func _shoot() -> void:
	var p := PROJECTILE.instantiate()
	p.damage = damage
	p.speed = 210.0
	p.projectile_owner = self
	p.lifetime = 5.0
	p.tint = LEAFG
	_spawn_container().add_child(p)
	var ang: float = (target.global_position - global_position).angle()
	p.global_rotation = ang
	p.global_position = global_position + Vector2.RIGHT.rotated(ang) * 20.0 + Vector2(0, -10)


func die(killer: Node = null) -> void:
	if state != State.DEAD and is_instance_valid(_patch):
		_patch.dismiss()
	super(killer)
