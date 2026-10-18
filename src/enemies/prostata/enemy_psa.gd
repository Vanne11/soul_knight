extends Enemy3a
class_name EnemyPsa

## PSA Sospechoso (La Prostata): un tubo de muestra con gabardina y lentes oscuros. Sobre su cabeza
## flota una CIFRA que sube con el tiempo. Mientras esta baja (amarillo/blanco) es un perseguidor
## lento; si la dejas subir pasa del umbral, se pone ROJA y se vuelve peligroso: mas rapido, pega
## mas y suelta un pulso de balas lentas con aviso. Cada golpe que le das BAJA la cifra: matarlo
## rapido es la solucion. Todo se ve en la cifra: no hay nada oculto.

const START := 2.0
const RISE := 0.36          ## por segundo
const MAX_PSA := 12.0
const HOT := 4.0            ## umbral rojo
const HIT_DROP := 0.55      ## lo que baja con cada golpe
const PULSE_EVERY := 3.0
const PULSE_WARN := 0.55
const PULSE_SHOTS := 8

var psa := START
var _label: Label
var _hot := false
var _pulse_t := PULSE_EVERY
var _warn_t := 0.0
var _base_speed := 110.0
var _base_dmg := 6.0
var _hot_said := false


func _setup() -> void:
	Prostata.ensure()
	personality = "psa"
	move_speed = 105.0
	lunge_trigger = 120.0
	windup_time = 0.55
	lunge_time = 0.22
	lunge_speed = 480.0
	recover_time = 0.8
	attack_cooldown = 0.6
	detection_range = 560.0
	_base_speed = move_speed
	psa = START + RNG.randf_range(0.0, 0.8)


func _ready() -> void:
	super._ready()
	_base_dmg = damage
	_label = Label.new()
	HudStyle.style_label(_label, 14, Color("fff2a8"), true)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(70, 0)
	_label.position = Vector2(-35, -76)
	_label.z_index = 20
	add_child(_label)
	_refresh()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD:
		return
	psa = minf(MAX_PSA, psa + RISE * delta)
	var hot := psa >= HOT
	if hot != _hot:
		_set_hot(hot)
	if _hot:
		_tick_pulse(delta)
	_refresh()


func _set_hot(hot: bool) -> void:
	_hot = hot
	if hot:
		move_speed = _base_speed * (1.45 + 0.04 * minf(psa - HOT, 6.0))
		damage = _base_dmg * 1.5
		_pulse_t = PULSE_EVERY * 0.6
		if not _hot_said:
			_hot_said = true
			Prostata.say(self, "psa_hot", 2.0)
			Prostata.icon(self, "vein", 1.4)
	else:
		move_speed = _base_speed
		damage = _base_dmg
		_warn_t = 0.0
		animated_sprite.self_modulate = Color.WHITE
		Prostata.say(self, "psa_down", 1.6)


func _refresh() -> void:
	if _label == null:
		return
	_label.text = "PSA %.1f" % psa
	var t := clampf((psa - 2.0) / (HOT - 2.0 + 3.0), 0.0, 1.0)
	_label.add_theme_color_override("font_color", Color("fff2a8").lerp(Color("ff3030"), t) if not _hot else Color("ff2a2a"))
	if _hot:
		animated_sprite.self_modulate = Color(1.45, 0.7, 0.7) if int(Time.get_ticks_msec() / 160) % 2 == 0 else Color(1.2, 0.85, 0.85)


func _tick_pulse(delta: float) -> void:
	if state in [State.STUNNED]:
		return
	if _warn_t > 0.0:
		_warn_t -= delta
		animated_sprite.modulate = Color(2.4, 0.6, 0.6) if int(_warn_t * 18.0) % 2 == 0 else Color.WHITE
		if _warn_t <= 0.0:
			animated_sprite.modulate = Color.WHITE
			_release_pulse()
		return
	_pulse_t -= delta
	if _pulse_t <= 0.0:
		_pulse_t = PULSE_EVERY
		_warn_t = PULSE_WARN
		Prostata.icon(self, "alert", 0.7)


func _release_pulse() -> void:
	var scn := preload("res://src/enemies/projectile_enemy.tscn")
	var a0 := RNG.randf_range(0.0, TAU)
	for i in PULSE_SHOTS:
		var p: ProjectileEnemy = scn.instantiate()
		p.damage = _base_dmg * 0.8
		p.speed = 150.0
		p.lifetime = 3.0
		p.tint = Color(1.0, 0.3, 0.3)
		p.projectile_owner = self
		_spawn_container().add_child(p)
		p.global_rotation = a0 + i * TAU / PULSE_SHOTS
		p.global_position = global_position + Vector2(0, -14)


## Cada golpe baja la cifra.
func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if state == State.DEAD:
		return 0.0
	psa = maxf(1.0, psa - HIT_DROP)
	return super.take_damage(amount, source, kb)


func die(killer: Node = null) -> void:
	if state != State.DEAD:
		Prostata.codex("psa_sospechoso")
		Prostata.note("pro_psa")
		if not _hot:
			Prostata.floating(global_position + Vector2(0, -70), Loc.tr_or("PRO_PSA_LOW", "PSA BAJO"), Color("7fe0a0"))
		if is_instance_valid(_label):
			_label.queue_free()
	super.die(killer)
