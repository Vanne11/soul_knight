class_name SilencioCuerpo
extends StaticBody2D

## UNO DE LOS 7 CUERPOS de "El Pacto de Silencio" (una silueta sin rostro ni genero). Todos comparten la
## UNICA vida del jefe (boss_pacto_silencio.gd): este nodo solo recibe el golpe y se lo pasa al jefe.
## Vive en la capa de enemigos para que balas y habilidades lo golpeen. No hace dano por contacto: el dano
## al jugador lo hacen las ondas y zonas del jefe (nunca golpes cuerpo a cuerpo).
##
## SENTADA (SEATED): en su silla, tapada por la cortina (se ve el velo) = PROTEGIDA, y recarga.
## FUERA (OUT/BACK): vulnerable. ATURDIDA (STUN): fuera de la silla, vulnerable. GONE: la salida final.

enum Mode { SEATED, OUT, BACK, STUN, GONE }

const SIT_CLIP := -26.0      ## sentada solo se ve de la cintura para arriba (altura local, pies en 0)
const SHADER := """
shader_type canvas_item;
uniform float clip_y = 2.0;
varying float ly;
void vertex() { ly = VERTEX.y; }
void fragment() { COLOR = texture(TEXTURE, UV); if (ly > clip_y) { discard; } }
"""

var boss: Node = null
var idx := 0
var mode := Mode.SEATED
var recharge := 0.0          ## segundos hasta poder volver a salir
var exposed := 0.0           ## la cortina esta abierta (un ruido la abrio)
var current_health := 1.0    ## solo para que las habilidades del heroe lo vean como algo golpeable
var max_health := 1.0
var sprite: SilencioEnte
var arrived := true

var _goal := Vector2.ZERO
var _speed := 90.0
var _moving := false
var _rest_pose := &"idle"
var _veil := 1.0
var _clip := SIT_CLIP
var _mat := ShaderMaterial.new()
var _t := 0.0
var _cs: CollisionShape2D


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 0
	set_collision_layer_value(2, true)
	collision_mask = 0
	var cs := CollisionShape2D.new()
	_cs = cs
	var sh := CircleShape2D.new()
	sh.radius = 24.0
	cs.shape = sh
	cs.position = Vector2(0, -34)
	add_child(cs)
	sprite = SilencioEnte.make(Vector2.ZERO)
	var sd := Shader.new()
	sd.code = SHADER
	_mat.shader = sd
	_mat.set_shader_parameter("clip_y", _clip)
	sprite.material = _mat
	add_child(sprite)
	z_index = 1


func protected() -> bool:
	return mode == Mode.SEATED and exposed <= 0.0


func is_out() -> bool:
	return mode in [Mode.OUT, Mode.BACK, Mode.STUN]


func take_damage(amount: float, source: Node = null, _kb: Vector2 = Vector2.ZERO) -> float:
	if boss == null or not is_instance_valid(boss) or mode == Mode.GONE:
		return 0.0
	return boss.cuerpo_hit(self, amount, source, false)


## Golpe de SONIDO de una habilidad del heroe (grito, escudo, pico).
func sound_hit(amount: float, source: Node = null) -> void:
	if boss != null and is_instance_valid(boss) and mode != Mode.GONE:
		boss.cuerpo_hit(self, amount, source, true)


func die(_killer: Node = null) -> void:
	pass  # solo muere el jefe


# ---------------------------------------------------------------- ordenes
func pose(p: StringName) -> void:
	_rest_pose = p
	if not _moving and sprite.animation != p:
		sprite.play(p)


func face(p: Vector2) -> void:
	if absf(p.x - global_position.x) > 2.0:
		sprite.flip_h = p.x < global_position.x


func go(p: Vector2, speed: float) -> void:
	_goal = p
	_speed = speed
	_moving = true
	arrived = false
	if sprite.animation != &"walk":
		sprite.play(&"walk")


func stop() -> void:
	_moving = false
	arrived = true
	sprite.play(_rest_pose)


## Se levanta de la silla y sale.
func salir() -> void:
	mode = Mode.OUT
	exposed = 0.0
	sprite.flip_h = false
	create_tween().tween_property(self, "_clip", 4.0, 0.4)
	pose(&"turn")


## Vuelve a su silla (speed alto = vuelta rapida si se cancela el ataque).
func volver(speed := 95.0) -> void:
	if mode == Mode.GONE:
		return
	mode = Mode.BACK
	go(boss.seat_of(idx), speed)


func aturdir(secs: float) -> void:
	if mode == Mode.GONE:
		return
	mode = Mode.STUN
	exposed = 0.0
	create_tween().tween_property(self, "_clip", 4.0, 0.3)
	pose(&"away")
	go(boss.seat_of(idx) + Vector2(0, 46), 70.0)
	get_tree().create_timer(secs).timeout.connect(func():
		if is_instance_valid(self) and mode == Mode.STUN:
			volver(110.0))


## La salida final: de pie, con su luz, camina hasta la salida y se desvanece. Sin violencia.
func final_exit(to: Vector2, delay: float) -> void:
	mode = Mode.GONE
	remove_from_group("enemy")
	_moving = false
	current_health = 0.0
	_cs.set_deferred("disabled", true)
	exposed = 0.0
	create_tween().tween_property(self, "_clip", 4.0, 0.5)
	sprite.carry_light()
	var l := LightKit.make_light(Color(1.0, 0.86, 0.55), 0.3, 0.9, false)
	l.remove_from_group(LightKit.GROUP_DARK)
	l.position = Vector2(0, -22)
	l.enabled = true
	add_child(l)
	var secs := global_position.distance_to(to) / 55.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): sprite.flip_h = to.x < global_position.x)
	tw.tween_property(self, "global_position", to, maxf(0.1, secs)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(sprite, "modulate:a", 0.0, 1.2)
	tw.tween_callback(queue_free)


# ---------------------------------------------------------------- fisica
func _physics_process(delta: float) -> void:
	if mode == Mode.GONE:
		return
	_t += delta
	exposed = maxf(0.0, exposed - delta)
	if mode == Mode.SEATED:
		recharge = maxf(0.0, recharge - delta)
	if boss != null and is_instance_valid(boss):
		current_health = maxf(1.0, float(boss.current_health))
	if _moving:
		var d := _goal - global_position
		var step := _speed * delta
		face(_goal)
		if d.length() <= step:
			global_position = _goal
			_moving = false
			arrived = true
			if mode == Mode.BACK:
				_sit()
			else:
				sprite.play(_rest_pose)
		else:
			global_position += d.normalized() * step
	# el velo (la cortina) cubre a la silla mientras esta protegida
	_veil = move_toward(_veil, 1.0 if protected() else 0.0, delta * 3.0)
	_mat.set_shader_parameter("clip_y", _clip)
	sprite.modulate = Color(0.62, 0.62, 0.72).lerp(Color.WHITE, 1.0 - _veil)
	queue_redraw()


func _sit() -> void:
	mode = Mode.SEATED
	recharge = boss.recharge_secs()
	pose(&"idle")
	sprite.flip_h = false
	create_tween().tween_property(self, "_clip", SIT_CLIP, 0.4)


func _draw() -> void:
	if mode == Mode.GONE:
		return
	if _veil > 0.02:
		# la cortina cae sobre la silla: tela oscura con pliegues, de la cintura para abajo y un velo sobre el pecho
		var a := 0.7 * _veil
		var c := Color(0.13, 0.12, 0.21, a)
		draw_colored_polygon(PackedVector2Array([Vector2(-24, -38), Vector2(24, -38), Vector2(27, 2), Vector2(-27, 2)]), c)
		for k in 5:
			var x := -22.0 + k * 11.0
			draw_line(Vector2(x + 2.0, -36), Vector2(x + 2.0 + (k - 2) * 1.2, 0), Color(0.26, 0.25, 0.4, a), 1.5)
		draw_line(Vector2(-24, -38), Vector2(24, -38), Color(0.34, 0.32, 0.5, a), 2.0)
	if mode == Mode.SEATED and recharge > 0.0 and boss != null and is_instance_valid(boss):
		# recargando: un arco fino, frio, que se completa sobre la cabeza
		var f: float = 1.0 - recharge / float(boss.recharge_secs())
		draw_arc(Vector2(0, -92), 6.0, -PI * 0.5, -PI * 0.5 + TAU * f, 16, Color(0.5, 0.55, 0.8, 0.8), 1.5)
