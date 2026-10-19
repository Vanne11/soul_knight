extends Defense
class_name DefDiu

## DIU DE COBRE (defensa). Proteccion de LARGO PLAZO: ORBS esferas de cobre giran siempre alrededor del
## heroe y desvian los proyectiles que las tocan (cada una, una vez; vuelve sola a los ORB_REGEN s). No
## hace falta nada para usarla. MANTENER "guard" = giro rapido y ancho: las esferas se recuperan al doble
## de velocidad (gasta estamina). No frena ni impide disparar; los golpes de cerca la ignoran.

const ORBS := 3
const RADIUS := 27.0
const RADIUS_FAST := 35.0
const SPIN := 2.4
const SPIN_FAST := 5.5
const HIT_R := 13.0
const ORB_REGEN := 5.0
const DRAIN := 3.5

var deflects := 0
var _cd: Array[float] = [0.0, 0.0, 0.0]
var _ang := 0.0
var _rad := RADIUS
var _fast := false


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("d98a4a")
	guarding = true


func _ready_orbs() -> int:
	var n := 0
	for c in _cd:
		if c <= 0.0:
			n += 1
	return n


func _orb_pos(i: int) -> Vector2:
	return Vector2.from_angle(_ang + TAU * i / ORBS) * _rad


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_fast = guard_held() and stats.current_stamina > 1.0
	if _fast:
		stats.use_stamina(DRAIN * delta)
	_rad = move_toward(_rad, RADIUS_FAST if _fast else RADIUS, 60.0 * delta)
	_ang += (SPIN_FAST if _fast else SPIN) * delta
	for i in ORBS:
		if _cd[i] > 0.0:
			_cd[i] = maxf(0.0, _cd[i] - delta * (2.0 if _fast else 1.0))
	# desvia lo que toca una esfera lista
	for a in get_tree().get_nodes_in_group("enemy_attack"):
		if not is_instance_valid(a) or not (a is Area2D) or not is_projectile(a):
			continue
		for i in ORBS:
			if _cd[i] <= 0.0 and (a as Node2D).global_position.distance_to(global_position + _orb_pos(i)) <= HIT_R:
				_deflect(i, a)
				break
	var ready := _ready_orbs()
	gauge_visible = ready < ORBS
	gauge_value = float(ready) / ORBS


func _deflect(i: int, a: Area2D) -> void:
	_cd[i] = ORB_REGEN
	deflects += 1
	consume(a)
	Sound.play("crack", 0.1)
	text("DEF_IUD_DEFLECT", Color("f0a060"))


## Una bala que llega al cuerpo antes de tocar una esfera tambien gasta una esfera lista.
func try_guard(area: Area2D, _dmg: float) -> bool:
	if not is_projectile(area):
		return false
	for i in ORBS:
		if _cd[i] <= 0.0:
			_deflect(i, area)
			return true
	return false


func _draw_tick() -> void:
	queue_redraw()


func _draw_body() -> void:
	for i in ORBS:
		var p := _orb_pos(i)
		if _cd[i] <= 0.0:
			draw_circle(p, 6.0, Color(0, 0, 0, 0.75))
			draw_circle(p, 4.5, Color("d98a4a"))
			draw_circle(p + Vector2(-1.5, -1.5), 1.6, Color("ffd9a8"))
			if _fast:
				draw_arc(p, 7.5, 0.0, TAU, 12, Color(1.0, 0.7, 0.35, 0.5), 1.0)
		else:
			draw_arc(p, 4.0, 0.0, TAU, 10, Color(0.85, 0.54, 0.29, 0.45), 1.2)
