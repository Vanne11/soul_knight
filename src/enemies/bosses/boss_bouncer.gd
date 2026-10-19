extends Node2D
class_name BossBouncer

## Mitad del Testiculo Primordial: rueda por la sala rebotando en los muros con una
## estela que marca por donde pasa. No se puede matar; tras N rebotes se funde.
## El choque contra el muro se mide con un rayo (no es un cuerpo fisico).

const CENSOR_UNSHADED := preload("res://src/shaders/censor_unshaded.gdshader")

signal finished

var dir := Vector2.RIGHT
var speed := 380.0
var bounces_left := 4
var damage := 14.0
var body_radius := 30.0
var tex: Texture2D = null
var sprite_scale := 1.0
## Cuadros de rodar de la mitad (arte de tools/gen_testiculo_art.py): mirando a la derecha / a la izquierda.
## Si estan vacios se dibuja `tex` girando, como siempre.
var frames_right: Array[Texture2D] = []
var frames_left: Array[Texture2D] = []

var _trail: Array[Vector2] = []
var _t := 0.0
var _fading := 0.0
var _hit_cd := 0.0
var _mat := ShaderMaterial.new()
var _room: Node = null
var _launch_delay := 0.0


func _ready() -> void:
	add_to_group("boss_hazard")
	_mat.shader = CENSOR_UNSHADED
	material = _mat
	var n: Node = get_parent()
	while n != null and not (n is Room):
		n = n.get_parent()
	_room = n
	z_index = 1
	ActorFx.add_glow(self, Color(1.0, 0.75, 0.5), 0.6, 0.6)


func launch_after(secs: float) -> void:
	_launch_delay = secs


func _physics_process(delta: float) -> void:
	_t += delta
	_mat.set_shader_parameter("color_amount", Censor.amount(_room) if _room else 1.0)
	if _fading > 0.0:
		_fading -= delta
		modulate.a = clampf(_fading / 0.4, 0.0, 1.0)
		if _fading <= 0.0:
			finished.emit()
			queue_free()
		queue_redraw()
		return
	if _launch_delay > 0.0:
		_launch_delay -= delta
		queue_redraw()
		return
	_hit_cd = maxf(0.0, _hit_cd - delta)
	var step := speed * delta
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * (step + body_radius), 1)
	var res := space.intersect_ray(q)
	if res:
		var n: Vector2 = res.normal
		dir = dir.bounce(n).normalized()
		global_position = res.position + n * body_radius
		bounces_left -= 1
		HitFx.shake(0.12)
		if bounces_left < 0:
			_fading = 0.4
	else:
		global_position += dir * step
	_trail.append(global_position)
	if _trail.size() > 14:
		_trail.pop_front()
	var tg := get_tree().get_first_node_in_group("player")
	if tg and _hit_cd <= 0.0 and tg.global_position.distance_to(global_position + Vector2(0, -20)) < body_radius + 14.0:
		if tg.has_method("receive_hit") and tg.receive_hit(damage):
			_hit_cd = 0.8
	queue_redraw()


func _draw() -> void:
	# estela (en coordenadas locales)
	for i in range(_trail.size() - 1):
		var a := float(i) / maxf(_trail.size(), 1.0)
		draw_line(to_local(_trail[i]) + Vector2(0, -20), to_local(_trail[i + 1]) + Vector2(0, -20), Color(1, 0.85, 0.7, 0.45 * a), 4.0 + 18.0 * a)
	if _launch_delay > 0.0:
		var p := 0.5 + 0.5 * sin(_t * 30.0)
		draw_arc(Vector2(0, -20), body_radius + 6.0, 0.0, TAU, 32, Color(1, 1, 1, 0.5 + 0.5 * p), 3.0)
	var fr := frames_right if dir.x >= 0.0 else frames_left
	if not fr.is_empty():
		var ft: Texture2D = fr[int(_t * 11.0) % fr.size()]
		var sq := 1.0 + 0.04 * sin(_t * 22.0)  # latido: la mitad rueda "a golpes"
		draw_set_transform(Vector2(0, -20), 0.0, Vector2(sprite_scale * sq, sprite_scale / sq))
		draw_texture(ft, -ft.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif tex:
		var s := sprite_scale
		draw_set_transform(Vector2(0, -20), _t * 7.0 * (1.0 if dir.x >= 0.0 else -1.0), Vector2(s, s))
		draw_texture(tex, -tex.get_size() * 0.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(Vector2(0, -20), body_radius, Color(0.9, 0.6, 0.5))
