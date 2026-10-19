extends Defense
class_name DefParche

## PARCHE ANTICONCEPTIVO (defensa PASIVA). Mientras no recibes golpes regenera tu ESCUDO poco a poco:
## pasados GRACE s sin dano suma REGEN puntos de escudo por segundo (mas rapido que el regenerado base).
## No reemplaza a la guard del heroe. Cada recibida de dano reinicia la espera.

const GRACE := 1.5
const REGEN := 7.0
const COLOR := Color("ffb0a0")

var restored := 0.0
var _t := 0.0
var _active := false


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = COLOR


func is_passive() -> bool:
	return true


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var since: float = Time.get_ticks_msec() / 1000.0 - stats._last_damage_time
	_active = false
	if since >= GRACE and stats.current_shields < stats.max_shields:
		var add := minf(REGEN * delta, stats.max_shields - stats.current_shields)
		stats.current_shields += add
		stats.shields_changed.emit(stats.current_shields, stats.max_shields)
		restored += add
		_active = true
	gauge_visible = stats.current_shields < stats.max_shields
	gauge_value = clampf(since / GRACE, 0.0, 1.0) if not _active else stats.current_shields / maxf(stats.max_shields, 1.0)


func _draw_tick() -> void:
	_t += get_process_delta_time()
	if _active:
		queue_redraw()


func _draw_body() -> void:
	if not _active:
		return
	for i in 3:
		var ph := fmod(_t * 0.9 + i / 3.0, 1.0)
		var p := Vector2(-8.0 + i * 8.0, 14.0 - ph * 28.0)
		draw_rect(Rect2(p - Vector2(1, 3), Vector2(2, 6)), Color(1.0, 0.7, 0.65, 1.0 - ph))
		draw_rect(Rect2(p - Vector2(3, 1), Vector2(6, 2)), Color(1.0, 0.7, 0.65, 1.0 - ph))
