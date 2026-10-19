extends Defense
class_name DefDiafragma

## DIAFRAGMA. MANTENER "guard": escudo frontal (domo de silicona) que bloquea balas de frente. PARRY: si lo
## subes justo cuando llega la bala (PARRY_WINDOW desde que pulsas) se la devuelves a quien la disparo con
## mas dano. Cada bloqueo gasta estamina; sin estamina se "cae" y no se sube por un rato. Camina mas
## rapido que el escudo del hoplita pero NO frena golpes cuerpo a cuerpo.

const PARRY_WINDOW := 0.3
const FRONT_DOT := 0.25
const WALK_MULT := 0.8
const BLOCK_COST := 5.0
const BLOCK_PER_DMG := 0.5
const PARRY_MULT := 2.5
const PARRY_STAMINA := 6.0
const BREAK_LOCK := 1.2
const RELEASE_LOCK := 0.3

var parries := 0
var blocks := 0
var in_parry_window := false
var _since_press := 0.0
var _lock := 0.0
var _lock_total := RELEASE_LOCK
var _flash := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("ff9ec4")


func speed_mult() -> float:
	return WALK_MULT if guarding else 1.0


func can_attack() -> bool:
	return not guarding


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_lock = maxf(0.0, _lock - delta)
	var want: bool = guard_held() and _lock <= 0.0 and stats.current_stamina > 1.0
	if want and not guarding:
		guarding = true
		_since_press = 0.0
		Sound.play("locked", 0.1)
	elif not want and guarding:
		_release(RELEASE_LOCK)
	if guarding:
		_since_press += delta
		in_parry_window = _since_press <= PARRY_WINDOW
	else:
		in_parry_window = false
	gauge_visible = _lock > 0.0
	gauge_value = 1.0 - _lock / _lock_total


func _release(lock: float) -> void:
	guarding = false
	in_parry_window = false
	_lock = lock
	_lock_total = maxf(lock, 0.01)


func try_guard(area: Area2D, dmg: float) -> bool:
	if not guarding or not is_projectile(area) or facing_dot(area) < FRONT_DOT:
		return false
	if _since_press <= PARRY_WINDOW:
		parries += 1
		reflect(area, PARRY_MULT)
		stats.apply_stat_mod("stamina", PARRY_STAMINA)
		player._iframes = maxf(player._iframes, 0.25)
		_flash = 0.3
		text("HERO_PARRY", Color.WHITE, 40.0)
		Sound.play("room_clear", 0.1)
		HitFx.shake(0.3)
		return true
	if not stats.use_stamina(BLOCK_COST + dmg * BLOCK_PER_DMG):
		_release(BREAK_LOCK)
		text("DEF_DIAPHRAGM_SLIP", Color("ff9ec4"))
		Sound.play("hurt")
		return false
	blocks += 1
	consume(area)
	text("HERO_BLOCK", Color("ffc4dc"))
	Sound.play("crack", 0.1)
	HitFx.shake(0.15)
	return true


func _draw_tick() -> void:
	_flash = maxf(0.0, _flash - get_process_delta_time())


func _draw_body() -> void:
	if not guarding:
		return
	var a: float = player._aim.angle()
	var col := Color.WHITE if (in_parry_window or _flash > 0.0) else Color("ffb3d0")
	draw_arc(Vector2.ZERO, 20.0, a - 1.05, a + 1.05, 16, Color(0, 0, 0, 0.8), 6.0)
	draw_arc(Vector2.ZERO, 20.0, a - 1.05, a + 1.05, 16, col, 4.0)
	draw_arc(Vector2.ZERO, 17.0, a - 0.9, a + 0.9, 14, Color("e8e8f0"), 1.5)  # aro de metal
