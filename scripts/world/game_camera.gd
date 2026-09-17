extends Camera2D
## Camara que sigue al jugador, se adelanta hacia el raton y tiembla.
##
## El "look ahead" (adelantarse hacia donde apuntas) es un truco estandar en
## twin-stick shooters: revela un poco mas de terreno en la direccion en la que
## vas a disparar, sin marear.

@export var follow_speed: float = 7.0
## Fraccion del vector jugador->raton que se adelanta la camara (0 = nada).
@export var look_ahead: float = 0.25
## Tope del adelanto, en pixeles.
@export var look_ahead_max: float = 42.0
## Velocidad a la que se apaga la sacudida (pixeles por segundo).
@export var shake_decay: float = 26.0

var target: Node2D
var _shake: float = 0.0


func _ready() -> void:
	Events.player_spawned.connect(_on_player_spawned)
	Events.shake_requested.connect(_on_shake_requested)


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var focus := target.global_position
		var ahead := (get_global_mouse_position() - target.global_position)
		focus += ahead.limit_length(look_ahead_max) * look_ahead
		# lerp con factor exponencial: el suavizado queda independiente de los
		# FPS, que es la forma correcta de interpolar por delta.
		global_position = global_position.lerp(focus, 1.0 - exp(-follow_speed * delta))

	_shake = maxf(_shake - shake_decay * delta, 0.0)
	offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))


func _on_player_spawned(player: Node2D) -> void:
	target = player
	global_position = player.global_position


func _on_shake_requested(strength: float) -> void:
	# Nos quedamos con la sacudida mas fuerte en curso, no las sumamos:
	# si no, una rafaga de disparos volveria la pantalla ilegible.
	_shake = maxf(_shake, strength)
