extends Node2D
## Escena principal: monta la sala, coloca al jugador y siembra enemigos.
##
## De momento es una unica sala fija. Cuando pasemos a mazmorra generada,
## este script sera quien encadene salas; el resto del juego no se entera.

const TILE_SIZE: int = 16

@export var room_size := Vector2i(30, 18)
@export var player_scene: PackedScene
@export var enemy_scenes: Array[PackedScene] = []
@export var enemy_count: int = 8

@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_layer: TileMapLayer = $Walls
@onready var camera: Camera2D = $Camera

var player: Player
var _enemies_alive: int = 0


func _ready() -> void:
	RoomBuilder.build_room(floor_layer, wall_layer, room_size)
	_setup_camera_limits()

	Events.enemy_died.connect(_on_enemy_died)

	_spawn_player()
	_spawn_enemies()

	Events.message.emit("Sala 1 - acaba con todos", 2.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


# --- Montaje ----------------------------------------------------------------

func _spawn_player() -> void:
	player = player_scene.instantiate()
	add_child(player)
	player.global_position = RoomBuilder.center(room_size, TILE_SIZE)


func _spawn_enemies() -> void:
	if enemy_scenes.is_empty():
		return

	var points := RoomBuilder.spawn_points(
		room_size, TILE_SIZE, enemy_count, player.global_position, 6)

	for point in points:
		var scene: PackedScene = enemy_scenes.pick_random()
		var enemy: Enemy = scene.instantiate()
		add_child(enemy)
		enemy.global_position = point
		_enemies_alive += 1


## La camara no debe mostrar el vacio de fuera de la sala.
func _setup_camera_limits() -> void:
	camera.limit_left = -TILE_SIZE
	camera.limit_top = -TILE_SIZE * 2
	camera.limit_right = room_size.x * TILE_SIZE + TILE_SIZE
	camera.limit_bottom = room_size.y * TILE_SIZE + TILE_SIZE


# --- Estado de la sala ------------------------------------------------------

func _on_enemy_died(_at: Vector2) -> void:
	_enemies_alive -= 1
	if _enemies_alive <= 0:
		Events.room_cleared.emit()
		Events.message.emit("Sala despejada", 2.5)
