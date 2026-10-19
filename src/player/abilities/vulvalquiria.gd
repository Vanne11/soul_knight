extends HeroAbility
class_name HeroVulvalquiria

## Vulvalquiria, guerrera agil. Menos vida, mas rapida, DOBLE DASH (Player.dash_charges).
## Alas del casco: MANTENER "guard" (clic derecho / K / RB) mientras caminas = planeo:
## sube del suelo (los charcos no la alcanzan), +20% velocidad, gasta estamina.
## Grito de valquiria: "ability" (F / B del mando), recarga 14 s; los enemigos a menos
## de 170 px HUYEN 3 s (los jefes solo se tambalean).

const HEALTH_PENALTY := -4.0
const SPEED_BONUS := 1.12
const DASH_COST_MULT := 0.6
const GLIDE_DRAIN := 12.0
const GLIDE_SPEED := 1.2
const GLIDE_LIFT := 7.0
const SCREAM_CD := 14.0
const SCREAM_RADIUS := 170.0
const SCREAM_FLEE := 3.0
## Dano de sonido del grito contra quien lo oye como sonido (El Pacto de Silencio).
const SOUND_DAMAGE := 22.0

var gliding := false
var screams := 0
var _lift := 0.0
var _cd := 0.0


func setup(p: Player) -> void:
	super.setup(p)
	stats.apply_stat_mod("max_health_flat", HEALTH_PENALTY)
	p.move_speed *= SPEED_BONUS
	p.dash_stamina_cost *= DASH_COST_MULT
	p.dash_charges = 2
	gauge_color = Color("e872bf")


func speed_mult() -> float:
	return GLIDE_SPEED if gliding else 1.0


func hover_lift() -> float:
	return _lift


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	gauge_visible = _cd > 0.0
	gauge_value = 1.0 - _cd / SCREAM_CD
	# planeo
	var want: bool = guard_held() and not player.is_dashing \
			and player.velocity.length() > 10.0 and stats.current_stamina > 1.0 and not Narrator.ate_input()
	if want:
		if not stats.use_stamina(GLIDE_DRAIN * delta):
			want = false
	if want and not gliding:
		_text("HERO_GLIDE", Color("e872bf"))
		_say("hero_glide_vulvalquiria")
	gliding = want
	_lift = move_toward(_lift, GLIDE_LIFT if gliding else 0.0, 40.0 * delta)
	if gliding:  # las gotas de gonorrea miran el reloj de este meta: parece que no la tocan
		player.set_meta("puddle_ms", Time.get_ticks_msec())
	# grito
	if Input.is_action_just_pressed("ability") and _cd <= 0.0 and not Narrator.ate_input():
		scream()


func scream() -> void:
	_cd = SCREAM_CD
	screams += 1
	_text("HERO_SCREAM", Color("fff1d6"), 44.0)
	Sound.play("boss_die", 0.1)
	HitFx.shake(0.55)
	var fx := ScreamFx.new()
	fx.radius = SCREAM_RADIUS
	player.get_parent().add_child(fx)
	fx.global_position = player.global_position
	for e in enemies_near(player.global_position, SCREAM_RADIUS):
		scare(e, SCREAM_FLEE, player.global_position)
		if e.has_method("sound_hit"):  # El Pacto de Silencio: el grito es SONIDO (dano x1,8)
			e.sound_hit(SOUND_DAMAGE * stats.damage_modifier, player)
	player._attack_anim = 0.4
	_say("hero_scream_vulvalquiria")


## Onda de sonido que se expande hasta el radio real del grito.
class ScreamFx extends Node2D:
	var radius := 170.0
	var _t := 0.0
	const LIFE := 0.45

	func _ready() -> void:
		z_index = 5

	func _process(d: float) -> void:
		_t += d
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / LIFE, 0.0, 1.0)
		for i in 3:
			var r := radius * clampf(k * 1.3 - i * 0.12, 0.0, 1.0)
			if r > 2.0:
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.85, 0.95, (1.0 - k) * (0.8 - i * 0.2)), 3.0 - i)
