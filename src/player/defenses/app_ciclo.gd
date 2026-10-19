extends Defense
class_name DefAppCiclo

## APP DEL CICLO (defensa PASIVA). Te "predice" lo que viene: dentro de RADIUS marca ANTES los ataques de
## los enemigos que estan a punto de embestir (linea punteada hacia ti y "!") y el aviso de los jefes
## (cuenta atras del ataque que preparan). Es solo informacion: no frena nada; hay que esquivar. No reemplaza
## a la guard del heroe. "Ayuda a conocer el ciclo, pero por si sola no es un metodo anticonceptivo confiable."

const RADIUS := 420.0
const BOSS_LEAD := 1.1       # s antes del ataque del jefe en que aparece el aviso
const ENEMY_LEAD := 0.45     # s de enfriamiento que le quedan al enemigo para marcarlo
const COL := Color("c79bff")
const ST_CHASE := 1          # Enemy.State
const ST_WINDUP := 2
const BOSS_IDLE := 1         # EnemyBoss.State

var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = COL


func is_passive() -> bool:
	return true


func _draw_tick() -> void:
	_t += get_process_delta_time()
	queue_redraw()


func _draw_body() -> void:
	if player == null:
		return
	var here: Vector2 = player.global_position
	var blink := 0.6 + 0.4 * sin(_t * 12.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D) or float(e.get("current_health")) <= 0.0:
			continue
		var pos: Vector2 = (e as Node2D).global_position
		if pos.distance_to(here) > RADIUS:
			continue
		var st = e.get("state")
		if st == null:
			continue
		if e.is_in_group("boss"):
			var left := float(e.get("_timer"))
			if int(st) == BOSS_IDLE and left <= BOSS_LEAD:
				var p := to_local(pos) + Vector2(0, -70)
				draw_circle(p, 13.0, Color(0, 0, 0, 0.6))
				draw_arc(p, 13.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(1.0 - left / BOSS_LEAD, 0.0, 1.0), 20, COL, 3.0)
				draw_string(ThemeDB.fallback_font, p + Vector2(-4, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, blink))
			continue
		if not ("windup_time" in e):
			continue
		var soon: bool = int(st) == ST_WINDUP or (int(st) == ST_CHASE and float(e.get("_attack_timer")) <= ENEMY_LEAD \
				and pos.distance_to(here) <= float(e.get("lunge_trigger")) * 2.6)
		if not soon:
			continue
		var a := to_local(pos)
		var b := Vector2.ZERO
		var dir := (b - a).normalized()
		var n := int(a.distance_to(b) / 14.0)
		for i in n:
			if i % 2 == 0:
				draw_line(a + dir * (i * 14.0), a + dir * (i * 14.0 + 8.0), Color(COL.r, COL.g, COL.b, 0.7 * blink), 2.0)
		draw_string(ThemeDB.fallback_font, a + Vector2(-4, -26), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, blink))
