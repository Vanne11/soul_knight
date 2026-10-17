extends Area2D
class_name PlayerBullet

## Bala del jugador. Mascara 1 (paredes) + 2 (cuerpos enemigos).

var damage: float = 8.0
var speed: float = 500.0
var lifetime: float = 1.6
## Bendiciones: enemigos que aun atraviesa y fuerza del empujon.
var pierce: int = 0
var knockback: float = 120.0
var _t: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	ActorFx.add_projectile_shadow(self, 4.0, 9.0)
	ActorFx.add_glow(self, Color(1.0, 0.8, 0.35), 0.55, 0.32)

func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	_t += delta
	if _t >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage, get_tree().get_first_node_in_group("player"), Vector2.RIGHT.rotated(rotation) * knockback)
		var ps := get_node("/root/PlayerStats")
		if ps.lifesteal > 0.0:
			ps.heal(damage * ps.lifesteal)
		if pierce > 0:
			pierce -= 1
			return
	elif body.has_method("hit_by_bullet"):  # barriles y cajas rompibles (RoomObstacles)
		body.hit_by_bullet(damage, Vector2.RIGHT.rotated(rotation))
	queue_free()
