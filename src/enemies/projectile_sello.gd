extends ProjectileEnemy
class_name ProjectileSello

## Sello de RECHAZADO del Inspector de Fluidos: mismo dano y velocidad que el
## proyectil normal; rebota UNA vez en la primera pared y a la segunda se rompe.

const SELLO_ROJO := Color(1.0, 0.3, 0.3)

var bounces_left := 1


func _ready() -> void:
	super._ready()
	var old := get_node_or_null("Glow")  # el brillo verde del proyectil base
	if old:
		old.queue_free()
	ActorFx.add_glow(self, SELLO_ROJO, 0.55, 0.36)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	$Sprite.global_rotation = 0.0  # el sello no gira: el texto se lee siempre


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	if bounces_left <= 0:
		queue_free()
		return
	bounces_left -= 1
	var dir := Vector2.RIGHT.rotated(global_rotation)
	# La normal de la pared: rayo corto a lo largo del avance contra las paredes.
	var q := PhysicsRayQueryParameters2D.create(global_position - dir * 14.0, global_position + dir * 14.0, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	var normal := -dir
	if not hit.is_empty():
		normal = hit.normal
		global_position = hit.position + normal * 7.0
	global_rotation = dir.bounce(normal).angle()
	Sound.play("enemy_shoot")
