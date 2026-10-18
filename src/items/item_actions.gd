class_name ItemActions
extends RefCounted

## Efectos de objetos de ranura que ocurren EN EL MUNDO (efecto 7 TRANSFORM de custom_data.use_effects,
## con custom_data.type): granadas, trampa, nube del desodorante, examen de PSA, autoexamen,
## estimulante y liquido misterioso. Se llaman desde ItemSlots.use_item. Los enemigos se tocan
## solo con los ganchos de siempre (scare / stun / reveal, con has_method) y take_damage.


static func run(player: Node, item: Item, cd: Dictionary, boost: float) -> void:
	match String(cd.get("type", "")):
		"throw_grenade": _grenade(player, cd, boost)
		"throw_flashbang": _flashbang(player, cd, boost)
		"place_trap": _trap(player, cd, boost)
		"combat_stim": _stim(player, cd, boost)
		"random": _mystery(player, boost)
		"deodorant": _deodorant(player, cd, boost)
		"psa": _psa(player, cd, boost)
		"self_exam": _self_exam(player)
		_: push_warning("ItemActions: tipo desconocido '%s' en %s" % [cd.get("type", ""), item.id])


static func enemies() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var out: Array = []
	for g in ["enemy", "boss"]:
		for n in tree.get_nodes_in_group(g):
			if is_instance_valid(n) and n not in out:
				out.append(n)
	return out


static func _world(player: Node) -> Node:
	return player.get_parent()


static func _stats() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("PlayerStats")


static func _aim_point(player: Node, dist: float) -> Vector2:
	var aim: Vector2 = player._aim if "_aim" in player else Vector2.RIGHT
	return player.global_position + aim.normalized() * dist


static func _hurt(e: Node, dmg: float, player: Node, from: Vector2, dtype := "explosivo") -> void:
	if e.has_method("take_damage"):
		BossDamage.tag("", 1.0, dtype)
		e.take_damage(dmg, player, (e.global_position - from).normalized() * 220.0)


# ------------------------------------------------------------------ granadas y trampa
static func _grenade(player: Node, cd: Dictionary, boost: float) -> void:
	var at := _aim_point(player, 190.0)
	var radius := float(cd.get("radius", 120.0))
	var dmg: float = float(cd.get("damage", 80.0)) * _stats().damage_modifier * boost
	var tree := player.get_tree()
	tree.create_timer(0.7).timeout.connect(func():
		if not is_instance_valid(player):
			return
		var fx := ExplosionFx.new()
		fx.radius = radius
		_world(player).add_child(fx)
		fx.global_position = at
		HitFx.shake(0.6)
		for e in enemies():
			if e.global_position.distance_to(at) <= radius:
				_hurt(e, dmg, player, at))


static func _flashbang(player: Node, cd: Dictionary, boost: float) -> void:
	var radius := float(cd.get("radius", 150.0)) * boost
	var secs := float(cd.get("duration", 4.0))
	HitFx.shake(0.4)
	for e in enemies():
		if e.global_position.distance_to(player.global_position) <= radius and not e.is_in_group("boss"):
			if e.has_method("stun"):
				e.stun(secs)


static func _trap(player: Node, cd: Dictionary, boost: float) -> void:
	var t := Trap.new()
	t.player = player
	t.damage = float(cd.get("damage", 60.0)) * boost
	t.immobilize = float(cd.get("immobilize", 3.0))
	t.bleed_dps = float(cd.get("bleed_dps", 10.0))
	t.bleed_secs = float(cd.get("bleed_duration", 5.0))
	t.radius = float(cd.get("trigger_radius", 40.0))
	_world(player).add_child(t)
	t.global_position = player.global_position


## Estimulante: potencia durante `duration` y luego el bajon (crash_penalty) durante crash_duration.
static func _stim(player: Node, cd: Dictionary, boost: float) -> void:
	var st := _stats()
	var dur := float(cd.get("duration", 15.0))
	for stat in ["speed", "fire_rate", "damage"]:
		if cd.has(stat):
			var m := maxf(0.2, 1.0 + (float(cd[stat]) - 1.0) * boost)
			st.apply_item_effect({"type": 11, "stat": stat, "magnitude": m, "duration": dur})
	var crash := float(cd.get("crash_penalty", 0.5))
	var crash_t := float(cd.get("crash_duration", 10.0))
	player.get_tree().create_timer(dur + 0.2).timeout.connect(func():
		if is_instance_valid(player):
			for stat in ["speed", "fire_rate"]:
				st.apply_item_effect({"type": 11, "stat": stat, "magnitude": crash, "duration": crash_t})
			(player.get_node("/root/GlobalEvents")).show_floating_text.emit(
				player.global_position + Vector2(0, -46), player.tr("FX_STIM_CRASH"), Color("c05a5a")))


## Liquido misterioso: una sorpresa de la lista (casi siempre buena; a veces no).
static func _mystery(player: Node, boost: float) -> void:
	var st := _stats()
	match RNG.randi_range(0, 5):
		0: st.heal(25.0 * boost)
		1: st.apply_item_effect({"type": 11, "stat": "speed", "magnitude": 1.3, "duration": 15.0})
		2: st.apply_item_effect({"type": 11, "stat": "damage", "magnitude": 1.3, "duration": 15.0})
		3: st.apply_item_effect({"type": 13, "hits": 1})
		4: st.add_intoxication(25.0)
		5: st.apply_item_effect({"type": 11, "stat": "speed", "magnitude": 0.75, "duration": 10.0})


# ------------------------------------------------------------------ lado pene
static func _deodorant(player: Node, cd: Dictionary, boost: float) -> void:
	var c := Cloud.new()
	c.radius = float(cd.get("radius", 140.0)) * boost
	c.seconds = float(cd.get("seconds", 7.0))
	_world(player).add_child(c)
	c.global_position = player.global_position


static func _psa(player: Node, cd: Dictionary, boost: float) -> void:
	var secs := float(cd.get("seconds", 20.0)) * boost
	for e in enemies():
		if e.has_method("reveal"):
			e.reveal(secs)
		var old = e.get_node_or_null("PsaTag")
		if old:
			old.queue_free()
		var tag := PsaTag.new()
		tag.name = "PsaTag"
		tag.seconds = secs
		e.add_child(tag)


## Revela el mapa del piso (salas y secretas) y deja el dato de prevencion.
static func _self_exam(player: Node) -> void:
	var tree := player.get_tree()
	var main := tree.get_first_node_in_group("main")
	if main:
		main.set_meta("map_revealed_floor", tree.root.get_node("RunManager").current_floor)


# ------------------------------------------------------------------ nodos del mundo
## Nube del desodorante "Machote": espanta (scare) a todo lo que entre; los jefes ni se enteran.
class Cloud extends Node2D:
	var radius := 140.0
	var seconds := 7.0
	var _t := 0.0
	var _tick := 0.0
	var _puffs: Array = []

	func _ready() -> void:
		z_index = 4
		for i in 14:
			_puffs.append({"a": randf() * TAU, "r": randf(), "s": randf_range(0.5, 1.0), "p": randf() * TAU})

	func _process(delta: float) -> void:
		_t += delta
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.4
			for e in ItemActions.enemies():
				if e.global_position.distance_to(global_position) <= radius and e.has_method("scare") and not e.is_in_group("boss"):
					e.scare(1.6, global_position)
		if _t >= seconds:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var life := clampf((seconds - _t) / 1.2, 0.0, 1.0)
		var grow := clampf(_t / 0.6, 0.0, 1.0)
		for p in _puffs:
			var ang: float = p.a + _t * 0.3 * p.s
			var pos: Vector2 = Vector2.from_angle(ang) * radius * 0.72 * p.r * grow
			pos += Vector2(sin(_t * 1.7 + p.p), cos(_t * 1.3 + p.p)) * 6.0
			var col := Color(0.62, 0.88, 0.7, 0.20 * life)
			draw_circle(pos, radius * 0.3 * (0.8 + 0.2 * sin(_t * 2.0 + p.p)), col)
		draw_arc(Vector2.ZERO, radius * grow, 0.0, TAU, 40, Color(0.7, 0.95, 0.75, 0.25 * life), 2.0)


## Vida de enemigos visible ("42/60") sobre ellos mientras dura el examen de PSA.
class PsaTag extends Label:
	var seconds := 20.0
	var _t := 0.0

	func _ready() -> void:
		add_theme_font_size_override("font_size", 13)
		add_theme_color_override("font_color", Color("ffe08a"))
		add_theme_color_override("font_outline_color", Color("0d0b0f"))
		add_theme_constant_override("outline_size", 4)
		z_index = 20
		position = Vector2(-26, -64)
		_refresh()

	func _process(delta: float) -> void:
		_t += delta
		if _t >= seconds:
			queue_free()
			return
		_refresh()

	func _refresh() -> void:
		var e := get_parent()
		if "current_health" in e and "max_health" in e:
			text = "%d/%d" % [ceili(e.current_health), ceili(e.max_health)]
		position.y = -64.0 if not e.is_in_group("boss") else -120.0


## Trampa de oso: espera enemigos; al pisarla muerde, inmoviliza y deja sangrado.
class Trap extends Node2D:
	var player: Node
	var damage := 60.0
	var immobilize := 3.0
	var bleed_dps := 10.0
	var bleed_secs := 5.0
	var radius := 40.0
	var _life := 90.0

	func _ready() -> void:
		z_index = 1

	func _process(delta: float) -> void:
		_life -= delta
		if _life <= 0.0:
			queue_free()
			return
		for e in ItemActions.enemies():
			if e.global_position.distance_to(global_position) <= radius and not e.is_in_group("boss"):
				_snap(e)
				return

	func _snap(e: Node) -> void:
		ItemActions._hurt(e, damage * ItemActions._stats().damage_modifier, player, global_position, "perforante")
		if e.has_method("stun"):
			e.stun(immobilize)
		HitFx.shake(0.3)
		var secs := int(bleed_secs)
		var tree := get_tree()
		for i in secs:
			tree.create_timer(float(i + 1)).timeout.connect(func():
				if is_instance_valid(e) and is_instance_valid(player):
					ItemActions._hurt(e, bleed_dps, player, e.global_position, "sangrado"))
		queue_free()

	func _draw() -> void:
		var c := Color("b9b9d0")
		draw_arc(Vector2.ZERO, 11.0, 0.0, TAU, 16, c, 2.0)
		for i in 6:
			var a := i * TAU / 6.0
			draw_line(Vector2.from_angle(a) * 6.0, Vector2.from_angle(a + 0.25) * 12.0, c, 2.0)
