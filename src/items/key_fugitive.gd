extends Node
class_name KeyFugitive

## Cerebro del ladron de la llave maestra: cuelga del enemigo (el suyo se apaga) y lo hace
## HUIR del jugador esquivando muros, con arranques de velocidad cuando lo acorralan. Si
## nadie lo atrapa en ESCAPE_SECS, se esfuma por una grieta (la mision lo avisa y la llave
## vuelve a su sitio, custodiada). No se toca enemy*.gd: el enemigo solo pierde su IA.

signal escaped

const SPEED := 225.0
const DASH_SPEED := 420.0
const ESCAPE_SECS := 55.0
const STEPS := 16
const LOOK := 70.0

var enemy: CharacterBody2D
var _life := 0.0
var _dash_t := 0.0
var _dash_dir := Vector2.ZERO
var _cool := 0.0


func _ready() -> void:
	enemy = get_parent() as CharacterBody2D
	var hb := enemy.get_node_or_null("Hitbox")
	if hb:
		hb.set_deferred("monitorable", false)  # que no pegue: solo huye


func _physics_process(delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		queue_free()
		return
	if enemy.is_physics_processing():
		enemy.set_physics_process(false)  # la sala los reactiva al entrar
	if enemy.get("state") == Enemy.State.DEAD:
		return
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	_life += delta
	if _life > ESCAPE_SECS:
		escaped.emit()
		return
	var away := enemy.global_position - pl.global_position
	var d := away.length()
	if d > 340.0:
		enemy.velocity = Vector2.ZERO
		enemy._update_animation(Vector2.ZERO)
		return
	_cool -= delta
	var dir := _best_dir(pl.global_position)
	var spd := SPEED
	if _dash_t > 0.0:
		_dash_t -= delta
		dir = _dash_dir
		spd = DASH_SPEED
	elif d < 85.0 and _cool <= 0.0 and enemy.get_slide_collision_count() > 0:
		# acorralado: se escabulle de lado a toda velocidad
		_dash_dir = (-away.normalized()).orthogonal() * (1.0 if randf() < 0.5 else -1.0)
		_dash_t = 0.28
		_cool = 1.4
	enemy.velocity = dir * spd
	enemy.move_and_slide()
	enemy._update_animation(dir)


func _best_dir(from_player: Vector2) -> Vector2:
	var space := enemy.get_world_2d().direct_space_state
	var best := Vector2.ZERO
	var best_score := -INF
	for i in STEPS:
		var dir := Vector2.RIGHT.rotated(TAU * i / STEPS)
		var q := PhysicsRayQueryParameters2D.create(enemy.global_position, enemy.global_position + dir * LOOK, 65)
		q.exclude = [enemy.get_rid()]
		var hit := space.intersect_ray(q)
		var free_len := LOOK if hit.is_empty() else enemy.global_position.distance_to(hit.position)
		var after := enemy.global_position + dir * minf(free_len, 40.0)
		var score := after.distance_to(from_player) + free_len * 0.8
		if free_len < 30.0:
			score -= 200.0
		if score > best_score:
			best_score = score
			best = dir
	return best
