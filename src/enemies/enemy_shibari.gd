extends Enemy3a
class_name EnemyShibari

## Shibari (bondage caricaturesco; idea de Vanessa): maestro de las cuerdas. Cada pocos segundos
## lanza REDES: tres tramos de cuerda que te cortan la huida (delante de ti, hacia donde corres).
## Las redes bloquean el paso y las balas enemigas; tus disparos las rompen y se sueltan solas a
## los 8 s. Cuerpo a cuerpo es debil: lo suyo es encerrarte con los demas.

const NET_CD := 5.5
const NET_WINDUP := 0.6
const NET_AHEAD := 105.0
const NET_SEGMENTS := 3
const NET_GAP := 80.0
const MAX_NETS := 6
var _net_cd := 2.0
var _casting := false


func _setup() -> void:
	personality = "bondage"
	move_speed = 100.0
	lunge_trigger = 85.0
	windup_time = 0.5
	lunge_time = 0.22
	lunge_speed = 480.0
	recover_time = 0.8


func _physics_process(delta: float) -> void:
	_net_cd = maxf(0.0, _net_cd - delta)
	super._physics_process(delta)


func _chase(delta: float) -> void:
	if target == null:
		return
	var to: Vector2 = target.global_position - global_position
	var d := to.length()
	if _net_cd <= 0.0 and d <= 460.0 and get_tree().get_nodes_in_group("rope_net").size() < MAX_NETS:
		_casting = true
		state = State.WINDUP
		_state_timer = NET_WINDUP
		_lunge_dir = to.normalized()
		animated_sprite.play("attack")
		_say("shibari_cast", 1.4)
		return
	if d > 150.0:
		super._chase(delta)
	else:
		# se mantiene a distancia de tiro de cuerda
		velocity = -to.normalized() * move_speed * 0.6
		_update_animation(-to)
		if d < 85.0:
			super._chase(delta)


func _start_lunge() -> void:
	if not _casting:
		super._start_lunge()
		return
	_casting = false
	state = State.CHASE
	_net_cd = NET_CD
	animated_sprite.offset.x = 0.0
	animated_sprite.modulate = Color.WHITE
	_cast_net()


## Tres tramos en fila perpendicular a tu direccion de huida (la de tu movimiento; si estas
## quieto, alejandote del Shibari), a NET_AHEAD delante de ti, con huecos entre tramos.
func _cast_net() -> void:
	if target == null:
		return
	var dir := Vector2.ZERO
	var vel = target.get("velocity")
	if vel is Vector2 and (vel as Vector2).length() > 30.0:
		dir = (vel as Vector2).normalized()
	else:
		dir = (target.global_position - global_position).normalized()
	var center: Vector2 = target.global_position + dir * NET_AHEAD
	var perp := dir.orthogonal()
	var cont := _spawn_container()
	for i in NET_SEGMENTS:
		var net := RopeNet.new()
		cont.add_child(net)
		net.global_position = center + perp * (i - (NET_SEGMENTS - 1) / 2.0) * NET_GAP
		net.rotation = perp.angle()
		# de pie respecto al avance: el tramo mide lo ancho en la direccion de perp
	E3a.note("e3a_shibari")
