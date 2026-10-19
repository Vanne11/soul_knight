extends Defense
class_name DefBarrera

## BARRERA DE LATEX (campo de latex, para sexo oral). PULSAR "guard": despliega frente a ti un muro delgado
## y translucido que tapa el paso: para a los enemigos, las balas enemigas (y las tuyas). Dura LIFE s o
## HP proyectiles; despues hay que esperar el enfriamiento. Un solo uso por vez, como el real.

const LIFE := 7.0
const COOLDOWN := 14.0
const HP := 8
const WALL_LEN := 52.0
const WALL_THICK := 5.0
const AHEAD := 38.0

var deployed := 0
var _cd := 0.0
var _wall: LatexWall = null


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("8fd8ff")


func on_removed() -> void:
	if _wall != null and is_instance_valid(_wall):
		_wall.queue_free()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	var alive := _wall != null and is_instance_valid(_wall)
	guarding = alive
	if guard_pressed() and _cd <= 0.0 and not alive:
		_deploy()
		alive = true
	cooling = not alive and _cd > 0.0
	if alive:
		gauge_visible = true
		gauge_value = _wall.life / LIFE
		gauge_color = Color("8fd8ff")
	else:
		gauge_visible = _cd > 0.0
		gauge_value = 1.0 - _cd / COOLDOWN
		gauge_color = Color("6a8aa0")


func _deploy() -> void:
	deployed += 1
	_cd = COOLDOWN
	var aim: Vector2 = player._aim.normalized()
	var w := LatexWall.new()
	w.position = player.global_position + aim * AHEAD
	w.rotation = aim.angle() + PI * 0.5
	player.get_parent().add_child(w)
	_wall = w
	Sound.play("locked", 0.1)
	text("DEF_BARRIER_UP", Color("8fd8ff"))


## El muro: cuerpo estatico en la capa de paredes (1) + un detector de balas enemigas (capa 16).
class LatexWall extends Node2D:
	var life := LIFE
	var hp := HP
	var _t := 0.0

	func _ready() -> void:
		z_index = 5
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = Vector2(WALL_LEN, WALL_THICK)
		cs.shape = rs
		body.add_child(cs)
		add_child(body)
		var det := Area2D.new()
		det.collision_layer = 0
		det.collision_mask = 16
		var ds := CollisionShape2D.new()
		var dr := RectangleShape2D.new()
		dr.size = Vector2(WALL_LEN + 4.0, WALL_THICK + 8.0)
		ds.shape = dr
		det.add_child(ds)
		det.area_entered.connect(_on_bullet)
		add_child(det)

	func _on_bullet(a: Area2D) -> void:
		if a.is_in_group("enemy_attack"):
			hp -= 1
			if hp <= 0:
				life = 0.0

	func _physics_process(delta: float) -> void:
		_t += delta
		life -= delta
		if life <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var fade := clampf(life / 1.2, 0.0, 1.0)
		var wob := sin(_t * 7.0) * 0.8
		var r := Rect2(Vector2(-WALL_LEN * 0.5, -WALL_THICK * 0.5 + wob * 0.2), Vector2(WALL_LEN, WALL_THICK))
		var dmg := 1.0 - float(hp) / HP
		draw_rect(r.grow(1.0), Color(0, 0, 0, 0.6 * fade))
		draw_rect(r, Color(0.56, 0.85, 1.0, (0.55 - 0.2 * dmg) * fade))
		draw_line(Vector2(-WALL_LEN * 0.5 + 3.0, -1.0), Vector2(WALL_LEN * 0.5 - 8.0 + wob, -1.0), Color(1, 1, 1, 0.8 * fade), 1.0)
		for i in int(dmg * 4.0):
			var x := -WALL_LEN * 0.5 + 9.0 + i * 12.0
			draw_line(Vector2(x, -WALL_THICK * 0.5), Vector2(x + 3.0, WALL_THICK * 0.5), Color(0.1, 0.2, 0.3, 0.8 * fade), 1.0)
