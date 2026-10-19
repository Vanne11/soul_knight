extends EnemyPtBase
class_name EnemyTodos

## TODOS-LO-HACEN (PT-27/33: presion de grupo; no es obligatorio ni una prueba de nada). Un bicho simpatico y MUY
## insistente que persigue y se multiplica: cada ~5 s, si estas cerca, LLAMA a un amigo (aviso: levanta los brazos 0,7 s con
## arcos de sonido) y aparece un clon debil, hasta 5 en la sala. Solo hay UN lider (lleva corona dorada): al romperlo
## todos los demas dicen "¡Ah, no, gracias!" y se desvanecen. Decir que no funciona.

enum S { CHASE, CALL }

const MAX_CROWD := 5
const CROWN := Color(1.0, 0.82, 0.2)

var leader := true
var st := S.CHASE
var st_t := 3.0
var _bite_cd := 0.0


func _ready() -> void:
	if leader:
		drop_table = [{"item_id": "health_small", "chance": 0.2}]
	move_speed = 150.0 if leader else 175.0
	super()
	add_to_group("todos_lo_hacen")
	if not leader:
		animated_sprite.modulate = Color(0.85, 0.85, 1.0, 0.9)
		damage *= 0.6
	st_t = RNG.randf_range(2.5, 4.0)


func _physics_process(delta: float) -> void:
	if state == State.DEAD or not _has_target():
		return
	st_t -= delta
	_bite_cd = maxf(0.0, _bite_cd - delta)
	var to_t: Vector2 = target.global_position - global_position
	match st:
		S.CHASE:
			var sep := Vector2.ZERO
			for o in get_tree().get_nodes_in_group("todos_lo_hacen"):
				if o != self and is_instance_valid(o):
					var diff: Vector2 = global_position - o.global_position
					if diff.length() < 46.0 and diff.length() > 0.0:
						sep += diff.normalized()
			velocity = (to_t.normalized() + sep * 0.8).normalized() * move_speed
			_play(&"walk")
			if _bite_cd <= 0.0 and to_t.length() < 46.0 and contact(damage):
				_bite_cd = 0.9
			if leader and st_t <= 0.0 and to_t.length() < 420.0 and get_tree().get_nodes_in_group("todos_lo_hacen").size() < MAX_CROWD:
				st = S.CALL
				st_t = 0.7
				say("PT_TODOS_CALL", Color("b8b0ff"))
		S.CALL:
			velocity = Vector2.ZERO
			animated_sprite.modulate = Color(1.6, 1.6, 2.0) if int(st_t * 20.0) % 2 == 0 else Color.WHITE
			_play(&"attack")
			if st_t <= 0.0:
				animated_sprite.modulate = Color.WHITE
				_clone()
				st = S.CHASE
				st_t = RNG.randf_range(4.5, 6.0)
	_face(to_t.x)
	move_and_slide()
	queue_redraw()


func _clone() -> void:
	var c: EnemyTodos = EnemyRegistry.scene("todos").instantiate()
	c.leader = false
	c.max_health = max_health * 0.4
	c.damage = damage
	c.enemy_name = enemy_name
	_spawn_container().add_child(c)
	c.global_position = global_position + Vector2.from_angle(RNG.randf() * TAU) * 34.0
	var room := find_owning_room()
	if room != null:
		room.enemies_spawned.append(c)  # la sala no se da por limpia hasta que caiga el clon
	Sound.play("enemy_shoot")


func _draw() -> void:
	if not leader:
		return
	# corona dorada del lider
	var y := -64.0
	draw_colored_polygon(PackedVector2Array([Vector2(-8, y), Vector2(-8, y - 9), Vector2(-4, y - 4), Vector2(0, y - 11), Vector2(4, y - 4), Vector2(8, y - 9), Vector2(8, y)]), CROWN)
	draw_polyline(PackedVector2Array([Vector2(-8, y), Vector2(-8, y - 9), Vector2(-4, y - 4), Vector2(0, y - 11), Vector2(4, y - 4), Vector2(8, y - 9), Vector2(8, y), Vector2(-8, y)]), Color(0.4, 0.28, 0.05), 1.0)


func die(killer: Node = null) -> void:
	if leader:
		_dismiss_crowd()
	super.die(killer)


## Sin lider no hay presion: los clones se desvanecen.
func _dismiss_crowd() -> void:
	say("PT_TODOS_NO", Color("9be37a"))
	for o in get_tree().get_nodes_in_group("todos_lo_hacen"):
		if o != self and is_instance_valid(o) and o is EnemyTodos and not o.leader and o.state != State.DEAD:
			o.drop_table.clear()
			o.take_damage(o.max_health * 10.0, null, Vector2.ZERO)

