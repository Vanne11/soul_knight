class_name RoomDynamic
extends Node2D

## Base de las dinamicas de sala (objetivos, modificadores, encuentros, peligros).
## Cuelga de la sala (se libera con el piso) y se crea desde RoomDirector.
##
## Contrato:
##  - start(): lo llama un fotograma de fisica despues de entrar a la sala (main ya genero
##    sus enemigos y se puede crear fisica sin el error de "flushing queries").
##  - owns_spawn = true: main NO genera los enemigos de la sala; los crea la dinamica
##    (RoomDirector.takes_over). Si start() no puede montarse llama a abort(), que deja una
##    sala de combate normal.
##  - finish(ok): cierra el objetivo. Las dinamicas con objetivo ponen room.clear_gate y solo
##    llaman a room.room_cleared() cuando el objetivo esta resuelto.

var main: Node
var room: Room
var director: Node
var kind := ""
var entry_door: Door = null
var owns_spawn := false
var finished := false
var success := false
var started := false   # start() ya se ejecuto (los _process esperan a esto)
var _bonus_done := false


func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if main == null or not is_instance_valid(main) or room == null or not is_instance_valid(room):
		return
	started = true
	start()


func start() -> void:
	pass


## Solo para las pruebas (_t.gd): una linea con el estado.
func debug() -> String:
	return "%s started=%s fin=%s ok=%s" % [kind, started, finished, success]


## Capa de suelo de esta dinamica: dibuja sobre el suelo y las calcomanias pero BAJO los
## enemigos, cofres y objetos (se inserta antes de Pickups/Props, como RoomObstacles).
var _floor_layer: Node2D = null


func floor_layer() -> Node2D:
	if _floor_layer == null or not is_instance_valid(_floor_layer):
		_floor_layer = Node2D.new()
		_floor_layer.name = "Floor_" + kind
		room.add_child(_floor_layer)
		room.move_child(_floor_layer, room.pickups_node.get_index())
	return _floor_layer


func player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func ps() -> Node:
	return get_node("/root/PlayerStats")


func rm() -> Node:
	return get_node("/root/RunManager")


func depth() -> float:
	return RunManager.depth(rm().current_floor)


func rsize() -> Vector2:
	return RoomUtil.size_of(room)


func center() -> Vector2:
	return room.get_center_position()


func say(event: String) -> void:
	Narrator.say(event)


## Frase del narrador para cuando acabe la pelea (en combate Narrator.say se pierde).
func say_when_calm(event: String) -> void:
	for _i in 120:
		if not is_inside_tree():
			return
		if not Narrator._in_combat():
			Narrator.say(event)
			return
		await get_tree().create_timer(0.5).timeout


## Comentario de "primera vez": una sola vez por partida, cuando acabe la pelea (en combate el
## narrador calla y Narrator.say_first se gastaria sin decir nada).
func say_intro(event: String) -> void:
	if Narrator._seen.has(event):
		return
	Narrator._seen[event] = true
	say_when_calm(event)


func toast(title: String, text := "", color := "b08d4a") -> void:
	Narrator.toast(title, text, color)


## room.clear_gate: true si la sala puede limpiarse ya. Por defecto si (sin objetivo propio:
## basta con matar a todos); los objetivos lo sobreescriben.
func gate() -> bool:
	return true


func abort() -> void:
	if owns_spawn and main != null and room.enemies_spawned.is_empty() and not room.cleared:
		var n := 2 + RunManager.depth_i(rm().current_floor)
		RoomUtil.spawn_wave(main, room, n, main._has_real_weapon())
	finished = true
	queue_free()


## Botin de bonus por cumplir (monedas, y a veces un objeto). Una sola vez.
func bonus(coins_n: int, loot_chance := 0.0, extra_id := "") -> void:
	if _bonus_done:
		return
	_bonus_done = true
	RoomUtil.coins(main, room, coins_n, center() + Vector2(0, -20))
	if extra_id != "":
		main._spawn_pickup(room, extra_id, center() + Vector2(0, 30))
	elif randf() < loot_chance:
		main._spawn_pickup(room, main._random_loot_id(), center() + Vector2(0, 30))
	Sound.play("room_clear")


func finish(ok: bool) -> void:
	if finished:
		return
	finished = true
	success = ok
	print("[salas] %s %s: %s" % [kind, room.grid_pos, "cumplida" if ok else "fallida"])
	on_finished(ok)


func on_finished(_ok: bool) -> void:
	pass


## Limpia la sala ya (objetivo cumplido) pasando por la puerta de room.gd.
func clear_room() -> void:
	room.clear_gate = Callable()
	room.room_cleared()
