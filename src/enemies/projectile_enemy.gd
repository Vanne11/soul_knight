extends Area2D
class_name ProjectileEnemy

## Proyectil enemigo. Lo detecta el Hurtbox del jugador (capa 16, grupo
## enemy_attack); antes estaba en la capa 1 y nunca hacia daño a nadie.

var damage: float = 10.0
var speed: float = 300.0
var lifetime: float = 5.0
var projectile_owner: Node = null
## Color propio del proyectil (jefes). Transparente = el verde de siempre.
var tint := Color(0, 0, 0, 0)
var _timer: float = 0.0

func _ready() -> void:
	add_to_group("enemy_attack")
	Sound.play("enemy_shoot")
	body_entered.connect(_on_body_entered)
	ActorFx.add_projectile_shadow(self, 5.0, 10.0)
	if tint.a > 0.0:
		$Sprite.modulate = tint
		ActorFx.add_glow(self, tint, 0.5, 0.34)
	else:
		ActorFx.add_glow(self, Color(0.71, 0.9, 0.42), 0.5, 0.34)

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
