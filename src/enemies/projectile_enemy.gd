extends Area2D
class_name ProjectileEnemy

## Proyectil enemigo. Lo detecta el Hurtbox del jugador (capa 16, grupo
## enemy_attack); antes estaba en la capa 1 y nunca hacia daño a nadie.

var damage: float = 10.0
var speed: float = 300.0
var lifetime: float = 5.0
var projectile_owner: Node = null
var _timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy_attack")
	Sound.play("enemy_shoot")
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += Vector2.RIGHT.rotated(global_rotation) * speed * delta
	_timer += delta
	if _timer >= lifetime:
		queue_free()

func on_hit() -> void:
	queue_free()

func _on_body_entered(body: Node) -> void:
	# Mascara 1 = paredes y jugador; el jugador ya lo gestiona su Hurtbox.
	if not body.is_in_group("player"):
		queue_free()
