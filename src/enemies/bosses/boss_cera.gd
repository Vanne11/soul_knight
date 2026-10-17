extends EnemyBoss

## DOÑA CERA CALIENTE (piso 1, Selva Pubica). Cera de depilar:
## - GOTEO (siempre): al moverse deja charcos de cera caliente que queman al pisarlos;
## - TIRON: lanza una tira (aviso: franja en el suelo); si te alcanza te arrastra hacia ella
##   y remata con un manotazo; si fallas, la tira se queda pegada y queda AGOTADA;
## - SALPICADURA (fase 1+): escupe cera sobre tu posicion: charcos que tardan en salir;
## - CRUZ (fase 3): dos tiras en cruz que giran barriendo la sala; luego queda AGOTADA.

const WAX := Color(1.0, 0.78, 0.3)
const MAX_PUDDLES := 9
const PUDDLE_GROUP := "boss_puddle"

var _drip_dist := 0.0
var _last_pos := Vector2.ZERO
var _aim := Vector2.RIGHT
var _aim_len := 500.0


func _ready() -> void:
	super()
	fan_tint = WAX
	keep_min = 190.0
	keep_max = 310.0
	_last_pos = global_position


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_fan", &"atk_tiron", &"atk_salpicadura"]
		2:
			return [&"atk_fan", &"atk_tiron", &"atk_salpicadura", &"atk_charge"]
	return [&"atk_tiron", &"atk_salpicadura", &"atk_cruz", &"atk_cruz", &"atk_charge", &"atk_fan"]


func _challenges() -> Array:
	return [&"ch_tira"]


func _channel_color() -> Color:
	return WAX


func _on_phase(n: int) -> void:
	move_speed = 70.0 + 18.0 * (n - 1)


# ---------------------------------------------------------------- goteo
func _tick(_delta: float) -> void:
	if state not in [State.IDLE, State.ATTACK]:
		_last_pos = global_position
		return
	var moved := global_position.distance_to(_last_pos)
	_last_pos = global_position
	if moved < 0.3 or moved > 60.0:
		return
	_drip_dist += moved
	if _drip_dist >= 130.0:
		_drip_dist = 0.0
		_puddle(global_position + Vector2(0, 6), 0.55, 5.0)


## Charco de cera: avisa (contorno tibio), luego quema unos segundos y se enfria.
func _puddle(pos: Vector2, warn: float, burn: float) -> BossZone:
	var all := get_tree().get_nodes_in_group(PUDDLE_GROUP)
	if all.size() >= MAX_PUDDLES:
		for z in all:
			if is_instance_valid(z) and z.phase < 2:
				z.dismiss()
				break
	var z := BossZone.circle(clamp_to_arena(pos, 40.0), 38.0, warn, burn, damage * 0.4, WAX)
	z.one_hit = false
	z.fade = 0.9
	z.add_to_group(PUDDLE_GROUP)
	return _add_hazard(z)


# ---------------------------------------------------------------- ataques
## Tira de cera: aviso largo, si te alcanza te arrastra.
func atk_tiron() -> void:
	_aim = (target.global_position - _muzzle()).normalized()
	var lane := BossZone.rect(_muzzle(), Vector2(500, 70), 0.0, 1.6, 0.05, 0.0, WAX)
	_add_hazard(lane)
	var track := func(left: float):
		if left > 0.3:
			_aim = (target.global_position - _muzzle()).normalized()
		_aim_len = _ray_len(_muzzle(), _aim, 620.0)
		if is_instance_valid(lane):
			lane.size.x = _aim_len
			lane.global_position = _muzzle() + _aim * _aim_len * 0.5
			lane.rotation = _aim.angle()
	if not await _tele(0.9, Color(2.2, 1.6, 0.6), 2.5, track):
		return
	var hit: bool = is_instance_valid(lane) and lane.contains(target.global_position)
	var strike := BossZone.rect(_muzzle() + _aim * _aim_len * 0.5, Vector2(_aim_len, 70), _aim.angle(), 0.0, 0.2, 0.0, Color.WHITE)
	_add_hazard(strike)
	if is_instance_valid(lane):
		lane.dismiss()
	Sound.play("crack")
	HitFx.shake(0.25)
	if not hit:
		# La tira se queda pegada en el suelo: tu ventana.
		_tire(1.5)
		return
	# Arrastre hasta la jefa
	var t := 0.0
	while t < 0.6:
		if not await _frame():
			return
		t += 1.0 / 60.0
		var to_b := global_position - target.global_position
		var dist := to_b.length()
		if dist <= 105.0:
			break
		target.move_and_collide(to_b.normalized() * minf(1000.0 / 60.0, dist - 105.0))
	if target.has_method("receive_hit"):
		target.receive_hit(damage * 0.35)
	var slap := BossZone.circle(global_position, 135.0, 0.55, 0.2, damage, WAX)
	_add_hazard(slap)
	slap.follow = self
	if not await _tele(0.5, Color(2.2, 0.6, 0.6), 3.0):
		return
	if not await _wait(0.3):
		return
	_tire(1.0)


## Escupe cera sobre ti: los charcos tardan en salir, no te quedes quieto.
func atk_salpicadura() -> void:
	if not await _tele(0.45, Color(2.2, 1.6, 0.6)):
		return
	var n := 2 + current_phase
	for i in n:
		var p: Vector2 = target.global_position + Vector2(RNG.randf_range(-70, 70), RNG.randf_range(-70, 70))
		_puddle(p, 0.85, 5.5)
		Sound.play("enemy_shoot")
		if not await _wait(0.4):
			return
	if not await _wait(0.5):
		return
	_tire(0.8)


## Dos tiras en cruz que giran por la sala (fase 3).
func atk_cruz() -> void:
	var ang := RNG.randf_range(0.0, PI)
	var sp := 0.62 * (1.0 if RNG.randf() < 0.5 else -1.0)
	var reach := arena().size.length() * 0.95
	if not await _walk_to(arena().get_center(), 1.4):
		return
	var c := _muzzle()
	var zs: Array[BossZone] = []
	for k in 2:
		var z := BossZone.rect(c, Vector2(reach, 46), ang + k * PI * 0.5, 1.0, 2.6, damage, WAX)
		z.spin = sp
		z.one_hit = false
		z.fade = 0.4
		zs.append(_add_hazard(z))
	if not await _tele(0.95, Color(2.2, 1.6, 0.6), 2.5):
		return
	if not await _wait(2.8):
		return
	# Despega las tiras: agotada.
	_tire(1.7)


# ---------------------------------------------------------------- desafios de la cura
## TIRA: una tira de depilar corre rapidisimo rebotando por la sala. Hay que tocarla
## (con el cuerpo o con un dash) antes de que acabe la recalentada.
func ch_tira() -> void:
	var a := arena().grow(-30.0)
	var v0 := Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * 370.0
	var strip := _make_prop(_muzzle() + Vector2(0, 60), Callable(), Callable(), {"v": v0, "turn": 0.9})
	strip.drawer = func(n):
		var v: Vector2 = n.data.v
		var pulse := 0.5 + 0.5 * sin(n.t * 22.0)
		n.draw_circle(Vector2(0, -12), 46.0, Color(WAX, 0.16 + 0.16 * pulse))
		n.draw_arc(Vector2(0, -12), 46.0, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 3.0)
		n.draw_set_transform(Vector2(0, -12), v.angle())
		n.draw_rect(Rect2(-44, -11, 88, 22), Color(1.0, 0.96, 0.75))
		n.draw_rect(Rect2(-44, -11, 88, 22), Color(0.35, 0.22, 0.05), false, 3.0)
		for k in 4:
			n.draw_line(Vector2(-30 + k * 20, -11), Vector2(-30 + k * 20, 11), Color(0.35, 0.22, 0.05, 0.6), 2.0)
		n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	strip.updater = func(n, dt):
		var v: Vector2 = n.data.v
		var away: Vector2 = n.global_position - target.global_position
		if away.length() < 230.0:
			v += away.normalized() * 650.0 * dt  # la tira se aparta de ti: hay que arrinconarla
			v = v.limit_length(430.0)
		n.data.turn -= dt
		if n.data.turn <= 0.0:
			n.data.turn = RNG.randf_range(0.6, 1.2)
			v = v.rotated(RNG.randf_range(-1.4, 1.4))
		var p: Vector2 = n.global_position + v * dt
		if p.x < a.position.x:
			p.x = a.position.x
			v.x = absf(v.x)
		elif p.x > a.end.x:
			p.x = a.end.x
			v.x = -absf(v.x)
		if p.y < a.position.y:
			p.y = a.position.y
			v.y = absf(v.y)
		elif p.y > a.end.y:
			p.y = a.end.y
			v.y = -absf(v.y)
		n.data.v = v
		n.global_position = p
		var tp: Vector2 = target.global_position
		var dist := tp.distance_to(p)
		if dist < 44.0:
			_chan_ok = true
		bot_goal_pos = p + v * 0.22
		bot_dash_vec = (p - tp).normalized() if dist < 190.0 else Vector2.ZERO
	await _ch_loop(8.0)
