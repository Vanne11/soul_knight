extends HeroAbility
class_name HeroOrnitorrinco

## Ornitorrinco, el raro (equilibrado, sin alergias, objetos de ambos reinos mejoran un 25%).
##  - Electrorrecepcion (pasiva, real): a menos de 280 px ve a los enemigos invisibles
##    (Clamidia); un pulso azul lo recuerda cada pocos segundos.
##  - Huevo (ability: F / B del mando, recarga 9 s): lo pone a sus pies. Los enemigos cercanos
##    lo persiguen (distrae: se les cambia el `target`; el huevo esta en el grupo "decoy"),
##    y a los 2.6 s (o si lo pisan) explota con dano en area.
##  - Espolon venenoso (guard: clic derecho / K / RB, real): estocada corta frente a el que
##    hace dano y envenena 6 tics. No necesita arma.

const ELECTRO_RADIUS := 280.0
const EGG_CD := 9.0
const EGG_FUSE := 2.6
const EGG_DAMAGE := 32.0
const EGG_RADIUS := 80.0
const EGG_LURE_RADIUS := 240.0
const SPUR_CD := 0.75
const SPUR_RANGE := 40.0
const SPUR_DAMAGE := 10.0
const SPUR_POISON_DAMAGE := 2.5
const SPUR_POISON_TICKS := 6

var spurs := 0
var eggs := 0
var revealed_total := 0
var _egg_cd := 0.0
var _spur_cd := 0.0
var _electro_t := 0.0
var _pulse_t := 2.0


func setup(p: Player) -> void:
	super.setup(p)
	gauge_color = Color("86aea1")


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_egg_cd = maxf(0.0, _egg_cd - delta)
	_spur_cd = maxf(0.0, _spur_cd - delta)
	gauge_visible = _egg_cd > 0.0
	gauge_value = 1.0 - _egg_cd / EGG_CD
	_electro(delta)
	if Input.is_action_just_pressed("ability") and _egg_cd <= 0.0 and not Narrator.ate_input():
		lay_egg()
	if Input.is_action_pressed("guard") and _spur_cd <= 0.0 and not Narrator.ate_input() and not player.is_dashing:
		spur()


func _electro(delta: float) -> void:
	_electro_t -= delta
	_pulse_t -= delta
	if _pulse_t <= 0.0:
		_pulse_t = 3.5
		var fx := ElectroFx.new()
		fx.radius = ELECTRO_RADIUS
		player.add_child(fx)
	if _electro_t > 0.0:
		return
	_electro_t = 0.15
	for e in enemies_near(player.global_position, ELECTRO_RADIUS):
		# Enemigos invisibles: EnemyIts (clamidia) los esconde mientras _reveal_t sea 0.
		if "_reveal_t" in e:
			if float(e._reveal_t) <= 0.0:
				revealed_total += 1
				if revealed_total == 1:
					_text("HERO_ELECTRO", Color("9be8ff"))
					_say("hero_electro_ornitorrinco")
			e._reveal_t = 0.4
		elif e.has_method("reveal"):
			e.reveal(0.4)


func lay_egg() -> void:
	_egg_cd = EGG_CD
	eggs += 1
	var egg := EggBomb.new()
	egg.owner_player = player
	egg.damage = EGG_DAMAGE * stats.damage_modifier
	egg.radius = EGG_RADIUS
	egg.fuse = EGG_FUSE
	egg.lure_radius = EGG_LURE_RADIUS
	player.get_parent().add_child(egg)
	egg.global_position = player.global_position + Vector2(0, 8)
	_text("HERO_EGG", Color("fff1d6"))
	Sound.play("crack", 0.1)
	_say("hero_egg_ornitorrinco")


func spur() -> void:
	_spur_cd = SPUR_CD
	spurs += 1
	var aim: Vector2 = player._aim
	var origin: Vector2 = player.global_position
	var hit := false
	for e in enemies_near(origin, SPUR_RANGE + 14.0):
		var to_e: Vector2 = (e.global_position - origin).normalized()
		if to_e.dot(aim) < 0.2:
			continue
		hit = true
		BossDamage.tag("", 1.0, "perforante")
		e.take_damage(SPUR_DAMAGE * stats.damage_modifier, player, aim * 240.0)
		if not is_instance_valid(e) or float(e.get("current_health")) <= 0.0:
			continue
		var p := e.get_node_or_null("SpurPoison") as SpurPoison
		if p:
			p.renew(SPUR_POISON_TICKS)
		else:
			p = SpurPoison.new()
			p.name = "SpurPoison"
			p.damage = SPUR_POISON_DAMAGE * stats.damage_modifier
			p.ticks = SPUR_POISON_TICKS
			p.source = player
			e.add_child(p)
	var fx := SpurFx.new()
	fx.aim = aim
	player.add_child(fx)
	player._attack_anim = 0.2
	Sound.play("bite", 0.1)
	if hit:
		_text("HERO_SPUR", Color("b7ff6a"))
		HitFx.shake(0.2)
		_say("hero_spur_ornitorrinco")


## Huevo-trampa: senuelo que explota. La explosion es la de PlayerBullet (dano a enemigos,
## rompe cajas y barriles) con la mecha ya gastada.
class EggBomb extends Node2D:
	var owner_player: Node = null
	var damage := 32.0
	var radius := 80.0
	var fuse := 2.6
	var lure_radius := 240.0
	var _t := 0.0
	var _lure_t := 0.0

	func _ready() -> void:
		add_to_group("decoy")
		z_index = 1

	func _physics_process(delta: float) -> void:
		_t += delta
		_lure_t -= delta
		if _lure_t <= 0.0:
			_lure_t = 0.3
			for e in get_tree().get_nodes_in_group("enemy"):
				if is_instance_valid(e) and not e.is_in_group("boss") and "target" in e \
						and e.global_position.distance_to(global_position) <= lure_radius:
					e.target = self
		if _t >= fuse or _stepped_on():
			_boom()
		queue_redraw()

	func _stepped_on() -> bool:
		for e in get_tree().get_nodes_in_group("enemy"):
			if is_instance_valid(e) and float(e.get("current_health")) > 0.0 \
					and e.global_position.distance_to(global_position) < 22.0:
				return true
		return false

	func _boom() -> void:
		var b := Player.PLAYER_BULLET.instantiate()
		b.damage = damage
		b.speed = 0.0
		b.lifetime = 0.02
		b.explosion_radius = radius
		get_parent().add_child(b)
		b.global_position = global_position
		queue_free()

	func _draw() -> void:
		var blink := _t > fuse - 0.7 and int(_t * 14.0) % 2 == 0
		var wob := sin(_t * 9.0) * 0.12 if _t > fuse - 1.2 else 0.0
		draw_set_transform(Vector2.ZERO, wob, Vector2.ONE)
		var body := Color(2.0, 2.0, 2.0) if blink else Color("eed6a1")
		draw_circle(Vector2(0, 1), 6.5, Color(0, 0, 0, 0.8))
		draw_circle(Vector2(0, 0), 5.5, body)
		draw_circle(Vector2(-2, -1), 1.2, Color("86aea1"))
		draw_circle(Vector2(2, 1), 1.0, Color("86aea1"))
		draw_circle(Vector2(0, 3), 0.9, Color("5c968c"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, radius * clampf(_t / fuse, 0.0, 1.0), 0.0, TAU, 40, Color(1, 0.9, 0.5, 0.18), 1.5)


## Estocada del espolon: una raya verde corta hacia donde apunta.
class SpurFx extends Node2D:
	var aim := Vector2.RIGHT
	var _t := 0.0

	func _ready() -> void:
		z_index = 6

	func _process(d: float) -> void:
		_t += d
		if _t > 0.14:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / 0.14
		var a := aim * (10.0 + 30.0 * k)
		var b := aim * (6.0 + 14.0 * k)
		draw_line(b, a, Color(0, 0, 0, 0.7 * (1.0 - k)), 5.0)
		draw_line(b, a, Color(0.72, 1.0, 0.42, 1.0 - k), 3.0)
		draw_circle(a, 2.5, Color(1, 1, 1, 1.0 - k))


## Pulso azul de la electrorrecepcion: un anillo fino que se expande y se apaga.
class ElectroFx extends Node2D:
	var radius := 280.0
	var _t := 0.0
	const LIFE := 1.3

	func _ready() -> void:
		z_index = -1

	func _process(d: float) -> void:
		_t += d
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / LIFE, 0.0, 1.0)
		draw_arc(Vector2(0, 8), radius * k, 0.0, TAU, 64, Color(0.5, 0.9, 1.0, 0.22 * (1.0 - k)), 2.0)
