class_name PitFall
extends Node

## Caida de enemigos a fosos y lagunas (celdas PIT/WATER de src/dungeon/room_shapes.gd).
## Caminando NO entran: el foso (capa 64) es una pared para su cuerpo, asi la IA no se tira sola.
## Pero si algo los EMPUJA (retroceso de balas, explosion de barriles, ventiladores de la sala
## trampa, embestida o dash del jugador), PitFall.push() les apaga esa capa unos instantes; si el
## centro cruza una celda de foso caen (o se ahogan, en agua) y mueren con su muerte normal: se
## colocan en el borde ANTES de morir, asi el botin cae en suelo firme. Jefes y minijefes no caen.
## Es un nodo hijo que solo existe mientras dura el empujon.

const PIT_MASK := 7   # capa 64
const MIN_PUSH := 110.0

var enemy: CharacterBody2D = null
var _t := 0.0
var _done := false


## Llamar con el retroceso aplicado (px/s). Si es fuerte y la sala tiene huecos, la capa se apaga.
static func push(e: Node, kb: Vector2) -> void:
	if kb.length() >= MIN_PUSH:
		launch(e, 0.12 + kb.length() / 1400.0)


## Empujon sostenido (ventiladores): cada llamada alarga `secs` el permiso de cruzar.
static func launch(e: Node, secs: float) -> void:
	if not (e is CharacterBody2D) or not is_instance_valid(e) or e.is_in_group("boss"):
		return
	var room := Pit.room_of(e)
	if room == null or not Pit.has_holes(room):
		return
	if room.room_type in [Room.RoomType.BOSS, Room.RoomType.MINIBOSS] or e is EnemyGranUrologo or e is EnemyGranCandado:
		return
	var n := e.get_node_or_null("PitFall") as PitFall
	if n == null:
		n = PitFall.new()
		n.name = "PitFall"
		n.enemy = e as CharacterBody2D
		e.add_child(n)
	n._t = maxf(n._t, secs)
	(e as CharacterBody2D).set_collision_mask_value(PIT_MASK, false)


func _physics_process(delta: float) -> void:
	if _done:
		return
	if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		queue_free()
		return
	if float(enemy.get("current_health")) <= 0.0:
		_end(false)
		return
	var room := Pit.room_of(enemy)
	if room == null:
		_end(true)
		return
	var k := Pit.kind_at(room, enemy.global_position)
	if k == RoomShapes.PIT or k == RoomShapes.WATER:
		_fall(room, k == RoomShapes.WATER)
		return
	_t -= delta
	if _t <= 0.0:
		_end(true)


func _end(restore: bool) -> void:
	_done = true
	if restore and is_instance_valid(enemy):
		enemy.set_collision_mask_value(PIT_MASK, true)
	queue_free()


func _fall(room: Room, water: bool) -> void:
	_done = true
	var e := enemy
	var spr := e.get("animated_sprite") as AnimatedSprite2D
	Pit.fall_ghost(spr, e.get_parent(), e.global_position, water)
	# al borde antes de morir: el botin y el cadaver quedan en suelo firme
	e.global_position = room.snap_global(e.global_position, 22.0)
	e.velocity = Vector2.ZERO
	e.visible = false  # la caida la hace el fantasma; la muerte normal solo suelta botin y avisa
	if e.has_method("die"):
		e.die(e.get_tree().get_first_node_in_group("player"))
	queue_free()
