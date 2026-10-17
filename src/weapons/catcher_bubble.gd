class_name CatcherBubble
extends Node2D

## Preservativo Atrapabalas: globo lento que se traga los proyectiles enemigos que entran en
## su radio. Al reventar (tiempo, pared o enemigo) los devuelve en circulo como balas tuyas.

const TEX := preload("res://assets/sprites/projectiles/condom_bubble.png")
const PLAYER_BULLET := preload("res://src/player/player_bullet.tscn")

var damage := 6.0
var speed := 150.0
var life := 1.5
var catch_radius := 44.0
var catch_max := 14
var direction := Vector2.RIGHT
var return_mult := 1.0
var caught := 0
var _t := 0.0
var _spr: Sprite2D
var _done := false


func _ready() -> void:
	z_index = 3
	_spr = Sprite2D.new()
	_spr.texture = TEX
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2.ONE * (catch_radius * 2.0 / 34.0)
	add_child(_spr)
	ActorFx.add_glow(self, Color(0.5, 1.0, 0.85), 0.5, 0.5)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var step := direction * speed * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step * 3.0 + direction * catch_radius * 0.5, 1)
	if get_world_2d().direct_space_state.intersect_ray(q):
		_pop()
		return
	global_position += step
	# pulsa: avisa de que va a reventar y se infla al tragar
	var pulse := 1.0 + 0.04 * sin(_t * 12.0) + 0.02 * caught
	_spr.scale = Vector2.ONE * (catch_radius * 2.0 / 34.0) * pulse
	if life - _t < 0.4:
		_spr.modulate = Color.WHITE if int(_t * 22.0) % 2 == 0 else Color(1.0, 1.0, 1.0, 0.45)
	for a in get_tree().get_nodes_in_group("enemy_attack"):
		if caught >= catch_max:
			break
		if not is_instance_valid(a) or not (a is ProjectileEnemy) or a.is_queued_for_deletion():
			continue
		if a.global_position.distance_to(global_position) <= catch_radius + 4.0:
			a.queue_free()
			caught += 1
			get_node("/root/Sound").play("pickup", 0.15)
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("take_damage") and float(e.get("current_health")) > 0.0 \
				and e.global_position.distance_to(global_position) <= catch_radius * 0.6 + 12.0:
			_pop()
			return
	if _t >= life:
		_pop()


## Revienta: pega en area pequena y escupe de vuelta lo que se trago.
func _pop() -> void:
	if _done:
		return
	_done = true
	var player := get_tree().get_first_node_in_group("player")
	var r := catch_radius * 0.9
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("take_damage") and float(e.get("current_health")) > 0.0 \
				and e.global_position.distance_to(global_position) <= r + 14.0:
			e.take_damage(damage, player, (e.global_position - global_position).normalized() * 160.0)
	var n := caught
	for i in n:
		var b: PlayerBullet = PLAYER_BULLET.instantiate()
		b.damage = (damage * 1.4 + 4.0) * return_mult
		b.speed = 460.0
		b.rotation = TAU * i / maxi(n, 1) + _t
		b.tint = Color(0.6, 1.0, 0.85)
		get_parent().add_child.call_deferred(b)
		b.set_deferred("global_position", global_position)
	var fx := ExplosionFx.new()
	fx.radius = r
	get_parent().add_child(fx)
	fx.global_position = global_position
	get_node("/root/Sound").play("crack", 0.15)
	queue_free()
