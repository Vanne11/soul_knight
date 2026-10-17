extends RoomDynamic

## La fiesta: aguantar 45 s en el antro. Las oleadas llegan a ritmo (cada ~11 s, y antes si
## limpias rapido), las puertas se sellan y al acabar el tiempo los que queden se van
## ("se acabo la fiesta"). Premio: botella, algo de vida y monedas.
## Bot: pelea de siempre; el tiempo corre solo.

const DURATION := 45.0
const WAVE_EVERY := 11.0
const MAX_ALIVE := 9

var t := 0.0
var wave_i := 0
var _hud: DynHud
var _glow: Polygon2D


func gate() -> bool:
	return finished


func start() -> void:
	owns_spawn = true
	room.seal_doors()
	_hud = DynHud.make(self, tr("RM_HOLD_T"), Color("ff7ac0"))
	_glow = Polygon2D.new()
	var s := rsize()
	_glow.polygon = PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)])
	_glow.material = LightKit.unshaded_material()
	floor_layer().add_child(_glow)
	toast(tr("RM_HOLD_T"), tr("RM_HOLD_D"), "ff7ac0")
	say_intro("rm_hold")
	_wave()


func _wave() -> void:
	var n := clampi(2 + wave_i + int(depth() / 2.0), 2, 7)
	RoomUtil.spawn_wave(main, room, n, true)
	wave_i += 1


func _process(delta: float) -> void:
	if not started:
		return
	if _glow != null:
		_glow.color = Color.from_hsv(fmod(t * 0.12, 1.0), 0.75, 1.0, 0.05 + 0.04 * sin(t * 7.0))
	if finished or room.cleared:
		return
	t += delta
	var alive := RoomUtil.alive(room)
	var due := WAVE_EVERY * wave_i
	if wave_i < 4 and alive.size() < MAX_ALIVE and (t >= due or (alive.is_empty() and t >= due - 7.0)):
		_wave()
	if _hud:
		_hud.set_value(1.0 - t / DURATION, tr("RM_HOLD_BAR") % [int(ceil(DURATION - t)), alive.size()])
	if t >= DURATION:
		_win()


func _win() -> void:
	finish(true)
	toast(tr("RM_HOLD_OK_T"), tr("RM_HOLD_OK"), "9be88a")
	Sound.play("puzzle_solve")
	bonus(4 + RunManager.depth_i(rm().current_floor), 0.0, "whiskey")
	main._spawn_pickup(room, "health_small", center() + Vector2(-40, 40))
	if _hud:
		_hud.queue_free()
	if _glow:
		_glow.queue_free()
	clear_room()
	say_when_calm("rm_hold_ok")
