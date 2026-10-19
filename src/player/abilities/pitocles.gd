extends HeroAbility
class_name HeroPitocles

## Pitocles, hoplita (tanque). Escudo griego: MANTENER "guard" (clic derecho / K / RB)
## bloquea balas y golpes de frente. Parry: si el escudo sube justo cuando llega la bala
## (PARRY_WINDOW desde que pulsas), la devuelve a quien la disparo con el triple de dano.
## Con el escudo arriba camina a media velocidad, gasta estamina y no dispara.
## Dash = embestida de falange: aturde a lo que atraviesa. Mas vida/escudo, mas lento.

const PARRY_WINDOW := 0.28
const FRONT_DOT := 0.3          # cuan "de frente" debe venir el golpe (1 = justo al frente)
const DRAIN := 5.0              # estamina por segundo con el escudo arriba
const BLOCK_COST := 6.0         # estamina por bloqueo + BLOCK_PER_DMG por punto de dano
const BLOCK_PER_DMG := 0.6
const BREAK_LOCK := 1.4         # escudo roto (sin estamina): no se puede subir este rato
const RELEASE_LOCK := 0.35      # al soltar: evita spamear el parry
const WALK_MULT := 0.55
const PARRY_DAMAGE_MULT := 3.0
const PARRY_STAMINA := 8.0
const RAM_DAMAGE := 6.0
const RAM_STUN := 1.2
const BONUS_HEALTH := 5.0
const BONUS_SHIELDS := 15.0
const SLOW := 0.92

var guarding := false
var in_parry_window := false
var parries := 0
var blocks := 0
var _since_press := 0.0
var _lock := 0.0
var _lock_total := BREAK_LOCK
var _rammed: Array = []
var _fx: Node2D = null


func setup(p: Player) -> void:
	super.setup(p)
	stats.apply_stat_mod("max_health_flat", BONUS_HEALTH)
	stats.apply_stat_mod("max_shields_flat", BONUS_SHIELDS)
	p.move_speed *= SLOW
	_fx = ShieldFx.new()
	_fx.set("ability", self)
	p.add_child(_fx)
	gauge_color = Color("ff9f3a")


func speed_mult() -> float:
	return WALK_MULT if guarding else 1.0


func can_attack() -> bool:
	return not guarding


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_lock = maxf(0.0, _lock - delta)
	var want: bool = Input.is_action_pressed("guard") and _lock <= 0.0 and not player.is_dashing \
			and not Narrator.ate_input() and stats.current_stamina > 1.0
	if want and not guarding:
		guarding = true
		_since_press = 0.0
		Sound.play("locked", 0.1)
	elif not want and guarding:
		_release(RELEASE_LOCK)
	if guarding:
		_since_press += delta
		in_parry_window = _since_press <= PARRY_WINDOW
		if not stats.use_stamina(DRAIN * delta):
			_break()
	else:
		in_parry_window = false
	gauge_visible = _lock > 0.0
	gauge_value = 1.0 - _lock / _lock_total


func _release(lock: float) -> void:
	guarding = false
	in_parry_window = false
	_lock = lock
	_lock_total = lock


func _break() -> void:
	_release(BREAK_LOCK)
	_text("HERO_GUARD_BREAK", Color("ff9f3a"))
	Sound.play("hurt")


## true = bloqueado/devuelto: Player no recibe dano.
func try_guard(area: Area2D, dmg: float) -> bool:
	if not guarding:
		return false
	var to_src: Vector2 = (area.global_position - player.global_position).normalized()
	if to_src.dot(player._aim) < FRONT_DOT:
		return false
	var is_proj: bool = "speed" in area and area.has_method("on_hit")
	if is_proj and _since_press <= PARRY_WINDOW:
		_parry(area)
		return true
	var cost := BLOCK_COST + dmg * BLOCK_PER_DMG * (1.0 if is_proj else 1.6)
	if not stats.use_stamina(cost):
		_break()
		return false
	blocks += 1
	_text("HERO_BLOCK", Color("ffd75a"))
	Sound.play("crack", 0.1)
	HitFx.shake(0.2)
	if is_proj:
		area.on_hit()
	else:  # golpe cuerpo a cuerpo: el escudo empuja y descoloca al agresor
		var enemy := area.get_parent()
		if enemy and enemy.is_in_group("enemy"):
			stun(enemy, 0.6, -to_src * 300.0)
	_say("hero_block_pitocles")
	return true


func _parry(area: Area2D) -> void:
	parries += 1
	var owner_node = area.get("projectile_owner")
	var dir: Vector2 = player._aim
	if owner_node is Node2D and is_instance_valid(owner_node):
		dir = (owner_node.global_position - area.global_position).normalized()
	var b := Player.PLAYER_BULLET.instantiate()
	b.damage = maxf(float(area.get("damage")) * PARRY_DAMAGE_MULT, 18.0) * stats.damage_modifier
	b.speed = maxf(float(area.get("speed")) * 1.4, 420.0)
	b.rotation = dir.angle()
	b.tint = Color("fff1b0")
	b.crit = true
	b.pierce = 1
	var at: Vector2 = area.global_position
	player.get_parent().add_child.call_deferred(b)  # estamos dentro de una consulta de fisica
	b.set_deferred("global_position", at)
	area.on_hit()
	stats.apply_stat_mod("stamina", PARRY_STAMINA)
	player._iframes = maxf(player._iframes, 0.3)
	_text("HERO_PARRY", Color("ffffff"), 40.0)
	Sound.play("room_clear", 0.1)
	HitFx.shake(0.35)
	_say("hero_parry_pitocles")


func on_dash_start(_dir: Vector2) -> void:
	_rammed.clear()
	if guarding:
		_release(0.0)


func on_dash_tick(dir: Vector2) -> void:
	for e in enemies_near(player.global_position, 40.0):
		if e in _rammed:
			continue
		_rammed.append(e)
		if e.has_method("sound_hit"):  # El Pacto de Silencio: el golpe de escudo suena (dano de sonido)
			e.sound_hit(RAM_DAMAGE * stats.damage_modifier, player)
			continue
		BossDamage.tag("", 1.0, "contundente")
		e.take_damage(RAM_DAMAGE * stats.damage_modifier, player, dir * 320.0)
		if is_instance_valid(e) and float(e.get("current_health")) > 0.0:
			stun(e, RAM_STUN, dir * 380.0)
		_text("HERO_RAM", Color("ffd75a"), 40.0)
		HitFx.shake(0.3)
		_say("hero_ram_pitocles")


## Arco dorado del escudo frente al heroe; destella en blanco durante la ventana del parry.
class ShieldFx extends Node2D:
	var ability: HeroPitocles = null

	func _ready() -> void:
		z_index = 6
		visible = false

	func _process(_d: float) -> void:
		visible = ability != null and ability.guarding
		if visible:
			queue_redraw()

	func _draw() -> void:
		var a: float = ability.player._aim.angle()
		var c := Vector2(0, -2)
		var col := Color.WHITE if ability.in_parry_window else Color("ffc93c")
		draw_arc(c, 21.0, a - 1.15, a + 1.15, 18, Color(0, 0, 0, 0.8), 6.0)
		draw_arc(c, 21.0, a - 1.15, a + 1.15, 18, col, 4.0)
		draw_arc(c, 19.0, a - 1.0, a + 1.0, 16, Color("a48132"), 1.5)
