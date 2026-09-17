class_name Slime
extends Enemy
## Enemigo basico: da saltos hacia el jugador con pausas entre ellos.
##
## El patron "moverse a rafagas" es mejor que perseguir a velocidad constante:
## da al jugador ventanas para reposicionarse y hace legible la amenaza.

@export var hop_speed: float = 110.0
@export var hop_interval: float = 1.0
@export var hop_duration: float = 0.3

var _next_hop: float = 0.0
var _hop_left: float = 0.0


func _ready() -> void:
	super()
	# Desfase aleatorio para que un grupo de slimes no salte al unisono.
	_next_hop = randf_range(0.0, hop_interval)


func _think(delta: float) -> void:
	_next_hop -= delta
	_hop_left -= delta

	if _next_hop <= 0.0 and target != null:
		_next_hop = hop_interval * randf_range(0.8, 1.25)
		_hop_left = hop_duration
		velocity = (target.global_position - global_position).normalized() * hop_speed

	if _hop_left <= 0.0:
		velocity = velocity.move_toward(Vector2.ZERO, drag * delta)

	# Squash & stretch: se estira al saltar y se aplasta al aterrizar.
	# Detalle barato que aporta muchisima vida a un sprite estatico.
	var t: float = clampf(_hop_left / hop_duration, 0.0, 1.0)
	sprite.scale = Vector2(1.0 - 0.2 * t, 1.0 + 0.2 * t)
