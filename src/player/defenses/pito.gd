extends Defense
class_name DefPito

## PITO DE EMERGENCIA (defensa). PULSAR "guard": pitazo fuerte. Los enemigos cercanos (RADIUS) huyen sin rumbo
## un instante (scare) y los jefes solo se tambalean; es como el grito de Vulvalquiria pero para cualquier
## heroe. Cuenta como SONIDO: a quien lo oye como sonido (El Pacto de Silencio y sus siluetas, via
## `sound_hit`) le hace SOUND_DAMAGE x tu modificador de dano, igual que el grito. Recarga (COOLDOWN).
## Guino al silbato contra el acoso callejero: hacer ruido y pedir ayuda funciona.

const RADIUS := 160.0
const FLEE := 2.5
const BOSS_STAGGER := 0.35
const SOUND_DAMAGE := 18.0
const COOLDOWN := 12.0
const LIFE := 0.5

var blows := 0
var _cd := 0.0
var _wave := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("ffd23a")


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	_wave = maxf(0.0, _wave - delta)
	cooling = _cd > 0.0
	gauge_visible = _cd > 0.0
	gauge_value = 1.0 - _cd / COOLDOWN
	if guard_pressed() and _cd <= 0.0:
		_blow()


func _blow() -> void:
	_cd = COOLDOWN
	_wave = LIFE
	blows += 1
	text("DEF_WHISTLE_BLOW", Color("fff1b0"), 44.0)
	Sound.play("boss_die", 0.1)
	HitFx.shake(0.35)
	var here: Vector2 = player.global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D) or float(e.get("current_health")) <= 0.0:
			continue
		if (e as Node2D).global_position.distance_to(here) > RADIUS:
			continue
		if e.has_method("sound_hit"):  # El Pacto de Silencio: el pitazo es SONIDO (dano x1,8)
			e.sound_hit(SOUND_DAMAGE * stats.damage_modifier, player)
		elif e.is_in_group("boss"):
			if e.has_method("stun"):
				e.stun(BOSS_STAGGER)
		elif e.has_method("scare"):
			e.scare(FLEE, here)
		elif e.has_method("stun"):
			e.stun(FLEE * 0.5)


func _draw_tick() -> void:
	if _wave > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if _wave <= 0.0:
		return
	var k := clampf(1.0 - _wave / LIFE, 0.0, 1.0)
	for i in 3:
		var r := RADIUS * clampf(k * 1.3 - i * 0.12, 0.0, 1.0)
		if r > 2.0:
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.9, 0.4, (1.0 - k) * (0.8 - i * 0.2)), 3.0 - i)
