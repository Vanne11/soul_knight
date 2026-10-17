extends RoomDynamic

## Contra el reloj: la Censura entra por la puerta pintando de gris la sala y te alcanza.
## Mata a todos antes de que cubra la sala entera. Dentro de lo gris te "censuran": vas mas
## lento y te hace dano a ratos (como todo, el dash lo esquiva). Si termina de cubrirla se
## pierde la recompensa anunciada y el gris no se va hasta limpiar la sala.
## Bot: pelea de siempre (va con modo dios; sin el, el dano por tick es moderado).

const TICK_EVERY := 1.1
const SLOW := 0.28

var secs_total := 40.0
var elapsed := 0.0
var progress := 0.0
var axis := Vector2.RIGHT
var _tide: Node2D
var _hud: DynHud
var _tick_t := 0.0
var _announced_full := false
var _len := 1.0
var _base := Vector2.ZERO


func gate() -> bool:
	return true


func start() -> void:
	secs_total = maxf(28.0, 46.0 - 3.0 * depth())
	var s := rsize()
	var ent := RoomUtil.entries(room)
	var inward := Vector2.RIGHT
	for e in ent:
		if entry_door == null or e.door == entry_door:
			inward = e.inward
			break
	axis = inward
	_len = s.x if absf(axis.x) > 0.5 else s.y
	_base = Vector2(0.0 if axis.x >= 0.0 else s.x, 0.0 if axis.y >= 0.0 else s.y)
	_tide = _Tide.new()
	_tide.set("dyn", self)
	_tide.z_index = 5
	_tide.material = LightKit.unshaded_material()
	add_child(_tide)
	_hud = DynHud.make(self, tr("RM_CLOCK_T"), Color("c9c9d6"))
	toast(tr("RM_CLOCK_T"), tr("RM_CLOCK_D"), "c9c9d6")
	say_intro("rm_clock")


func debug() -> String:
	return "clock p=%.2f fin=%s ok=%s axis=%s" % [progress, finished, success, axis]


## true si el punto local esta bajo lo gris.
func covers(p: Vector2) -> bool:
	return (p - _base).dot(axis) < progress * _len


func tide_rect() -> Rect2:
	var s := rsize()
	var w := progress * _len
	if absf(axis.x) > 0.5:
		return Rect2(Vector2(_base.x if axis.x > 0.0 else _base.x - w, 0.0), Vector2(w, s.y))
	return Rect2(Vector2(0.0, _base.y if axis.y > 0.0 else _base.y - w), Vector2(s.x, w))


func _process(delta: float) -> void:
	if not started:
		return
	if finished:
		return
	if room.cleared:
		_end()
		return
	elapsed += delta
	progress = clampf(elapsed / secs_total, 0.0, 1.0)
	if _hud:
		_hud.set_value(1.0 - progress, tr("RM_CLOCK_BAR") % int(ceil(secs_total - elapsed)))
	if progress >= 1.0 and not _announced_full:
		_announced_full = true
		room.reward = ""
		room.reward_kingdom = ""
		toast(tr("RM_CLOCK_FAIL_T"), tr("RM_CLOCK_FAIL"), "ff6b6b")


func _physics_process(delta: float) -> void:
	if not started:
		return
	if finished or not is_inside_tree() or main.current_room != room:
		return
	var pl := player() as CharacterBody2D
	if pl == null:
		return
	var lp := pl.global_position - room.global_position
	if covers(lp):
		pl.move_and_collide(-pl.velocity * SLOW * delta)
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = TICK_EVERY
			if RoomUtil.hurt_player(pl, 0.3 * RoomUtil.std_hit(depth())):
				RoomUtil.popup(pl.global_position + Vector2(0, -34), tr("RM_CLOCK_CENSORED"), Color("c9c9d6"))
	else:
		_tick_t = 0.2


func _end() -> void:
	var ok := progress < 1.0
	finish(ok)
	if _hud:
		_hud.queue_free()
	if _tide:
		var tw := _tide.create_tween()
		tw.tween_property(_tide, "modulate:a", 0.0, 0.8)
		tw.tween_callback(_tide.queue_free)
	if ok:
		var left := 1.0 - progress
		Sound.play("puzzle_solve")
		toast(tr("RM_CLOCK_OK_T"), tr("RM_CLOCK_OK"), "9be88a")
		bonus(3 + RunManager.depth_i(rm().current_floor) + int(left * (4.0 + 2.0 * depth())), 0.4)
		say_when_calm("rm_clock_ok")
	else:
		say_when_calm("rm_clock_fail")
	room.set_meta("dyn_done", true)


## La marea gris: capa translucida con la cresta de barras negras.
class _Tide extends Node2D:
	var dyn

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if dyn == null or not is_instance_valid(dyn) or dyn.progress <= 0.0:
			return
		var r: Rect2 = dyn.tide_rect()
		draw_rect(r, Color(0.16, 0.16, 0.22, 0.55))
		# cresta: bloques negros de "censura" en el borde que avanza
		var ax: Vector2 = dyn.axis
		var horiz := absf(ax.x) > 0.5
		var front := (r.end.x if ax.x > 0.0 else r.position.x) if horiz else (r.end.y if ax.y > 0.0 else r.position.y)
		var sign := (1.0 if (ax.x > 0.0 if horiz else ax.y > 0.0) else -1.0)
		var n := int((r.size.y if horiz else r.size.x) / 28.0) + 1
		for i in n:
			var off := (i * 28.0)
			var w := 14.0 + float((i * 7) % 5) * 5.0
			var a := front - sign * w
			var rect := Rect2(Vector2(minf(a, front), off), Vector2(w, 24.0)) if horiz else Rect2(Vector2(off, minf(a, front)), Vector2(24.0, w))
			draw_rect(rect, Color(0.03, 0.03, 0.04, 0.95))
