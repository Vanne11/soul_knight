extends Defense
class_name DefCopa

## COPA MENSTRUAL (defensa). MANTENER "guard": la copa recoge los proyectiles enemigos de frente (hasta
## CAP guardados). AL SOLTAR el boton los vacia de vuelta como un chorro en abanico, con el dano de cada
## uno. "Reutilizable": no se gasta. Camina lento y no dispara mientras la sostienes; los golpes de cerca
## la ignoran (solo recoge proyectiles).

const CAP := 8
const FRONT_DOT := 0.2
const WALK_MULT := 0.7
const SPILL_SPEED := 380.0
const SPILL_SPREAD := 0.5
const SPILL_MIN := 4.0
const SPILL_MAX := 14.0
const SPILL_MULT := 0.9
const RELEASE_LOCK := 0.35

var stored: Array[float] = []
var spills := 0
var _lock := 0.0
var _flash := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("d8284a")


func speed_mult() -> float:
	return WALK_MULT if guarding else 1.0


func can_attack() -> bool:
	return not guarding


func on_removed() -> void:
	stored.clear()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_lock = maxf(0.0, _lock - delta)
	var want := guard_held() and _lock <= 0.0
	if want and not guarding:
		guarding = true
		Sound.play("locked", 0.1)
	elif not want and guarding:
		guarding = false
		_lock = RELEASE_LOCK
		_spill()
	gauge_visible = not stored.is_empty()
	gauge_value = float(stored.size()) / CAP


func try_guard(area: Area2D, dmg: float) -> bool:
	if not guarding or not is_projectile(area) or stored.size() >= CAP or facing_dot(area) < FRONT_DOT:
		return false
	stored.append(dmg)
	consume(area)
	_flash = 0.15
	Sound.play("crack", 0.1)
	if stored.size() >= CAP:
		text("DEF_CUP_FULL", Color("ff6a88"), 40.0)
	return true


## Vacia lo guardado: un abanico de balas rojas hacia donde apuntas (escalonadas unas milesimas).
func _spill() -> void:
	if stored.is_empty():
		return
	spills += 1
	var n := stored.size()
	var base: float = player._aim.angle()
	var dmgs := stored.duplicate()
	stored.clear()
	text("DEF_CUP_SPILL", Color("ff6a88"), 40.0)
	Sound.play("room_clear", 0.1)
	HitFx.shake(0.2)
	for i in n:
		var k := (float(i) / maxf(1.0, n - 1.0) - 0.5) * SPILL_SPREAD if n > 1 else 0.0
		var d := clampf(float(dmgs[i]) * SPILL_MULT, SPILL_MIN, SPILL_MAX)
		get_tree().create_timer(0.04 * i).timeout.connect(_fire.bind(base + k, d))


func _fire(angle: float, dmg: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var b := Player.PLAYER_BULLET.instantiate()
	b.damage = dmg * stats.damage_modifier
	b.speed = SPILL_SPEED
	b.rotation = angle
	b.tint = Color("e0284c")
	b.knockback = 60.0
	var at: Vector2 = player.global_position + Vector2.from_angle(angle) * 16.0
	player.get_parent().add_child(b)
	b.global_position = at


func _draw_tick() -> void:
	_flash = maxf(0.0, _flash - get_process_delta_time())


func _draw_body() -> void:
	if not guarding:
		return
	# copa violeta frente al heroe, con el nivel de lo recogido en rojo
	var a: float = player._aim.angle()
	var f: Vector2 = Vector2.from_angle(a)
	var n: Vector2 = f.rotated(PI * 0.5)
	var c := f * 16.0
	var rim := PackedVector2Array([c + n * 9.0 + f * 5.0, c - n * 9.0 + f * 5.0, c - n * 5.0 - f * 8.0, c + n * 5.0 - f * 8.0])
	draw_colored_polygon(rim, Color(0.62, 0.42, 0.9, 0.95))
	var fill := float(stored.size()) / CAP
	if fill > 0.0:
		var w := 9.0 - 4.0 * (1.0 - fill)
		var t := f * (5.0 - 13.0 * (1.0 - fill))
		draw_colored_polygon(PackedVector2Array([c + n * w + t, c - n * w + t, c - n * 5.0 - f * 8.0, c + n * 5.0 - f * 8.0]), Color(0.85, 0.12, 0.26, 0.9))
	draw_polyline(PackedVector2Array([rim[0], rim[1], rim[2], rim[3], rim[0]]), Color(0, 0, 0, 0.85), 1.5)
	draw_line(c - f * 8.0, c - f * 12.0, Color(0.62, 0.42, 0.9), 2.0)  # tallito
	if _flash > 0.0:
		draw_circle(c + f * 5.0, 7.0, Color(1, 0.4, 0.5, 0.4))
