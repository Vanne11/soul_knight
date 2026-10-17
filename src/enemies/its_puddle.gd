extends Node2D

## Gota de la Gonorrea Goteante: charquito que escuece (dano pequeno + posible contagio)
## al pisarlo. Se seca solo. No interrumpe el movimiento: es una zona, no una pared.

const LIFE := 7.0
const RX := 20.0
const RY := 11.0
const TICK_EVERY := 0.9
const INFECT_CHANCE := 0.35
var tick_damage := 1.5
var _age := 0.0
var _cd := 0.0


func _ready() -> void:
	add_to_group("its_puddle")
	z_index = -1  # por debajo de los bichos


func _process(delta: float) -> void:
	_age += delta
	_cd = maxf(0.0, _cd - delta)
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()
	if _cd > 0.0:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null or ("is_dashing" in p and p.is_dashing):
		return
	var d: Vector2 = p.global_position - global_position
	if (d.x * d.x) / (RX * RX) + (d.y * d.y) / (RY * RY) > 1.0:
		return
	# un solo escozor a la vez aunque pises varias gotas
	var now := Time.get_ticks_msec()
	if now - int(p.get_meta("puddle_ms", -100000)) < TICK_EVERY * 1000.0:
		return
	p.set_meta("puddle_ms", now)
	_cd = TICK_EVERY
	var stats := get_node("/root/PlayerStats")
	stats.take_damage(tick_damage)
	get_node("/root/GlobalEvents").show_damage_number.emit(p.global_position + Vector2(0, -30), tick_damage, false)
	if RNG.randf() < INFECT_CHANCE:
		stats.infect("ardor", 8.0)


func _draw() -> void:
	var fade := clampf((LIFE - _age) / 1.5, 0.0, 1.0)
	var base := Color(0.62, 0.74, 0.16, 0.55 * fade)
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * RX, sin(a) * RY))
	draw_colored_polygon(pts, base)
	var hi := PackedVector2Array()
	for i in range(14):
		var a := TAU * i / 14.0
		hi.append(Vector2(-4 + cos(a) * 7, -2 + sin(a) * 3))
	draw_colored_polygon(hi, Color(0.85, 0.95, 0.45, 0.6 * fade))
