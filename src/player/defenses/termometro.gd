extends Defense
class_name DefTermometro

## TERMOMETRO (defensa PASIVA). Toma la temperatura a los enemigos cercanos (RADIUS): los que estan "con
## fiebre" (a punto de atacar o enrabiados) llevan un termometro rojo sobre la cabeza y reciben FEVER_MULT x
## de dano mientras duran (las defensas los ven pasados de revoluciones). No afecta a los jefes (solo los
## marca) y no reemplaza a la guard del heroe. "Metodo de la temperatura basal: pide constancia."

const RADIUS := 480.0
const FEVER_MULT := 1.25
const TICK := 0.15
const ST_WINDUP := 2   # Enemy.State
const ST_LUNGE := 3
const BOSS_ATTACK := 2  # EnemyBoss.State.ATTACK

var _tick := 0.0
var _hot: Dictionary = {}   # id -> nodo con fiebre ahora
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("ff6a4a")


func is_passive() -> bool:
	return true


func on_removed() -> void:
	for id in _hot:
		_clear(_hot[id])
	_hot.clear()


func _clear(e) -> void:
	if is_instance_valid(e) and e.has_meta("dmg_taken_mult"):
		e.remove_meta("dmg_taken_mult")


func _feverish(e: Node) -> bool:
	var st = e.get("state")
	if st == null:
		return false
	if e.is_in_group("boss"):
		return int(st) == BOSS_ATTACK
	if "windup_time" in e and int(st) in [ST_WINDUP, ST_LUNGE]:
		return true
	var ai = e.get("ai")
	return ai != null and ai.get("_enraged") == true


func _physics_process(delta: float) -> void:
	if player == null:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	var here: Vector2 = player.global_position
	var now := {}
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D) or float(e.get("current_health")) <= 0.0:
			continue
		if (e as Node2D).global_position.distance_to(here) > RADIUS or not _feverish(e):
			continue
		now[e.get_instance_id()] = e
		if not e.is_in_group("boss"):
			e.set_meta("dmg_taken_mult", FEVER_MULT)
	for id in _hot:
		if not now.has(id):
			_clear(_hot[id])
	_hot = now


func _draw_tick() -> void:
	_t += get_process_delta_time()
	if not _hot.is_empty():
		queue_redraw()


func _draw_body() -> void:
	for id in _hot:
		var e = _hot[id]
		if not is_instance_valid(e):
			continue
		var p := to_local((e as Node2D).global_position) + Vector2(0, -44 + sin(_t * 8.0 + id % 7) * 1.5)
		# termometro: tubo blanco, bulbo y mercurio rojo
		draw_rect(Rect2(p + Vector2(-3, -10), Vector2(6, 17)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(p + Vector2(-2, -9), Vector2(4, 14)), Color("eef2f6"))
		draw_rect(Rect2(p + Vector2(-1, -4), Vector2(2, 9)), Color("ff3b2e"))
		draw_circle(p + Vector2(0, 8), 5.5, Color(0, 0, 0, 0.7))
		draw_circle(p + Vector2(0, 8), 4.0, Color("ff3b2e"))
		draw_circle(p + Vector2(9, -2), 1.8, Color("8fd8ff"))  # gota de sudor
