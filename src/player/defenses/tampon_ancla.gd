extends Defense
class_name DefTamponAncla

## TAMPON ANCLA (defensa). MANTENER "guard": te ANCLAS: inmune a empujones, succiones, correas y knockback
## (Player.shove, StatusEffects.push/pull) mientras lo mantienes. Caminas lento, pero puedes disparar.
## "Cambialo cada pocas horas": aqui se gasta estamina mientras esta puesto y, al agotarse, hay que
## cambiarlo (CHANGE_TIME sin poder usarlo).

const WALK_MULT := 0.45
const DRAIN := 9.0
const CHANGE_TIME := 3.0

var anchors := 0
var _lock := 0.0
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("5a86d8")


func speed_mult() -> float:
	return WALK_MULT if guarding else 1.0


func anchored() -> bool:
	return guarding


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_lock = maxf(0.0, _lock - delta)
	cooling = _lock > 0.0
	var want: bool = guard_held() and _lock <= 0.0 and stats.current_stamina > 1.0
	if want and not guarding:
		guarding = true
		anchors += 1
		text("DEF_ANCHOR_ON", Color("8fb4ff"))
		Sound.play("locked", 0.1)
	elif not want and guarding:
		guarding = false
		if stats.current_stamina <= 1.0:
			_lock = CHANGE_TIME
			text("DEF_ANCHOR_CHANGE", Color("c8c8d8"))
	if guarding:
		stats.use_stamina(DRAIN * delta)
	gauge_visible = guarding or _lock > 0.0
	gauge_value = (stats.current_stamina / stats.max_stamina) if guarding else 1.0 - _lock / CHANGE_TIME


func _draw_tick() -> void:
	_t += get_process_delta_time()


func _draw_body() -> void:
	if not guarding:
		return
	# anclaje sobrio: aro sutil en los pies (elipse achatada) y un tampon chiquito en la mano izquierda
	var pulse := 0.5 + 0.15 * sin(_t * 5.0)
	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.4))
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, Color(0.4, 0.6, 1.0, pulse * 0.45), 2.5)
	draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, Color(0.7, 0.85, 1.0, pulse), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var a: float = player._aim.angle()
	var f := Vector2.from_angle(a)
	var hand: Vector2 = f * 9.0 + f.rotated(-PI * 0.5) * 8.0
	draw_line(hand - f * 3.5, hand + f * 3.5, Color(0, 0, 0, 0.85), 4.0)
	draw_line(hand - f * 3.0, hand + f * 3.0, Color(0.97, 0.97, 1.0), 2.5)
	draw_line(hand - f * 3.0, hand - f * 6.0 + f.rotated(PI * 0.5) * 1.5, Color(0.8, 0.85, 1.0), 1.0)
