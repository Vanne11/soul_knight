extends Defense
class_name DefAutotest

## AUTOTEST DE VIH (defensa). PULSAR "guard": te haces el test: durante REVEAL_TIME s se MARCAN las trampas
## (anillos en el suelo), los enemigos invisibles (p. ej. el Polipo Callado, que casi no se ve) y las SALAS
## SECRETAS cercanas aparecen en el minimapa (meta "autotest_until" en main; lo dibuja minimap.gd). Los enemigos
## con `reveal()` quedan a la vista. Recarga (COOLDOWN). "Un resultado reactivo se confirma con un profesional."

const REVEAL_TIME := 7.0
const COOLDOWN := 24.0
const RANGE := 620.0
const COL := Color("4fe0d0")

var tests := 0
var _on := 0.0
var _cd := 0.0
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = COL


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_cd = maxf(0.0, _cd - delta)
	_on = maxf(0.0, _on - delta)
	cooling = _cd > 0.0 and _on <= 0.0
	if guard_pressed() and _cd <= 0.0 and _on <= 0.0:
		_test()
	if _on > 0.0:
		gauge_visible = true
		gauge_value = _on / REVEAL_TIME
	else:
		gauge_visible = _cd > 0.0
		gauge_value = 1.0 - _cd / COOLDOWN


func _test() -> void:
	tests += 1
	_on = REVEAL_TIME
	_cd = COOLDOWN
	text("DEF_AUTOTEST_ON", Color("a8fff4"), 44.0)
	Sound.play("room_clear", 0.1)
	var main := get_tree().get_first_node_in_group("main")
	if main != null:
		main.set_meta("autotest_until", Time.get_ticks_msec() + int(REVEAL_TIME * 1000.0))
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("reveal"):
			e.reveal(REVEAL_TIME)


func _hidden(e: Node) -> bool:
	var spr = e.get("animated_sprite")
	return spr != null and (spr as CanvasItem).modulate.a < 0.5


func _draw_tick() -> void:
	_t += get_process_delta_time()
	if _on > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if _on <= 0.0:
		return
	var fade := clampf(_on / 1.0, 0.0, 1.0)
	var pulse := 0.6 + 0.4 * sin(_t * 8.0)
	var here: Vector2 = player.global_position
	# trampas: anillo sobre cada peligro cercano
	for h in get_tree().get_nodes_in_group("rooms_hazard"):
		if not is_instance_valid(h) or not h.has_method("hazard_zones"):
			continue
		for z in h.hazard_zones():
			var c: Vector2 = z.get("c", Vector2.ZERO)
			if c.distance_to(here) > RANGE:
				continue
			var r := float(z.get("ar", z.get("r", 30.0)))
			draw_arc(to_local(c), r, 0.0, TAU, 28, Color(1.0, 0.8, 0.2, 0.85 * fade * pulse), 2.5)
			draw_string(ThemeDB.fallback_font, to_local(c) + Vector2(-4, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.9, 0.3, fade))
	# invisibles: anillo y "?"
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D) or not _hidden(e):
			continue
		var p := to_local((e as Node2D).global_position)
		draw_arc(p, 30.0 + pulse * 3.0, 0.0, TAU, 24, Color(COL.r, COL.g, COL.b, fade), 2.5)
		draw_arc(p, 20.0, 0.0, TAU, 20, Color(0, 0, 0, 0.5 * fade), 1.5)
		draw_string(ThemeDB.fallback_font, p + Vector2(-5, -34), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(COL.r, COL.g, COL.b, fade))
	# onda de escaneo
	var k := fposmod(_t * 0.9, 1.0)
	draw_arc(Vector2.ZERO, RANGE * k, 0.0, TAU, 48, Color(COL.r, COL.g, COL.b, 0.25 * (1.0 - k) * fade), 2.0)
