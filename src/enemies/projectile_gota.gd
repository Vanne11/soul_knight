extends ProjectileEnemy
class_name ProjectileGota

## Gotita de crema de la Espinilla Reventona: igual que el proyectil base pero sin el sonido
## de disparo por cada gota (salen 10 de golpe) y con brillo crema-rosado.

const CREMA := Color(1.0, 0.82, 0.82)


func _ready() -> void:
	lifetime = 3.2
	add_to_group("enemy_attack")
	body_entered.connect(_on_body_entered)
	ActorFx.add_projectile_shadow(self, 5.0, 10.0)
	ActorFx.add_glow(self, CREMA, 0.5, 0.3)


func _physics_process(delta: float) -> void:
	super(delta)
	$Sprite.global_rotation = 0.0  # la gota no gira
