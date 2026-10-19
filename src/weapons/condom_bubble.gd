class_name CondomBubble
extends Masilla

## Globocondon: el condon-globo revienta al tocar y se infla en una BURBUJA de latex que ATRAPA a los enemigos de dentro
## (casi no se mueven; los jefes solo van lentos). Dura `time` s y al final REVIENTA con un "pop" que pega a todos los de
## dentro. Reutiliza la logica de agarre de Masilla (velocidad, liberacion), cambia el dibujo y suma el pop.
## No cuenta para la medalla "Con carino" (esa es de la masilla).

var pop_damage := 20.0
var weapon_id := ""
var _popped := false


static func make(parent: Node, pos: Vector2, cfg: Dictionary) -> CondomBubble:
	var m := CondomBubble.new()
	m.radius = float(cfg.get("radius", 52.0))
	m.time = float(cfg.get("time", 3.6))
	m.stick = m.time  # atrapados todo el rato
	m.boss_slow = float(cfg.get("boss_slow", 0.7))
	m.pop_damage = float(cfg.get("pop_damage", 20.0))
	m.weapon_id = String(cfg.get("weapon_id", ""))
	m.counts_medal = false
	parent.add_child(m)
	m.global_position = pos
	return m


func _physics_process(delta: float) -> void:
	if not _popped and _t + delta >= time:
		_pop()
	super(delta)


func _pop() -> void:
	_popped = true
	var player := get_tree().get_first_node_in_group("player")
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e.has_method("take_damage") or float(e.get("current_health")) <= 0.0:
			continue
		if e.global_position.distance_to(global_position) > radius + 8.0:
			continue
		BossDamage.tag(weapon_id, 1.0)
		e.take_damage(pop_damage, player, (e.global_position - global_position).normalized() * 160.0)
	var fx := ExplosionFx.new()
	fx.radius = radius
	fx.modulate = Color(0.6, 1.2, 1.1)
	get_parent().add_child(fx)
	fx.global_position = global_position
	Sound.play("crack", 0.15)
	HitFx.shake(0.25)


func _draw() -> void:
	var fade := clampf((time - _t) / 0.5, 0.0, 1.0)
	var k := minf(1.0, 0.3 + _t * 6.0)
	var r := radius * k
	var wob := 1.0 + 0.03 * sin(_t * 9.0)
	# a punto de reventar: tiembla y se pone mas opaca
	var warn := clampf((_t - (time - 0.7)) / 0.7, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(wob, 1.0 / wob) * Vector2(1.0, 0.8))
	draw_circle(Vector2.ZERO, r, Color(0.45, 0.9, 0.85, (0.2 + 0.2 * warn) * fade))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(0.75, 1.0, 0.95, 0.9 * fade), 2.0)
	draw_arc(Vector2(-r * 0.25, -r * 0.2), r * 0.6, PI * 1.05, PI * 1.5, 12, Color(1, 1, 1, 0.85 * fade), 2.0)
	draw_circle(Vector2(r * 0.4, -r * 0.35), 3.0, Color(1, 1, 1, 0.9 * fade))
	for e in _state.keys():
		if is_instance_valid(e):
			var p: Vector2 = e.global_position - global_position
			draw_arc(Vector2(p.x, p.y / 0.8 - 14.0), 20.0, 0.0, TAU, 14, Color(0.8, 1.0, 0.95, 0.5 * fade), 1.5)  # cada atrapado, en su propia burbujita
