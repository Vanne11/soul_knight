class_name SpecialShots
extends RefCounted

## Disparos de las armas con mecanica propia (etapa 6d): rayo, bumeran, globos, atrapabalas
## y el combo cuerpo a cuerpo. Los llama Player._shoot() cuando custom_data trae "special".
## Los datos de cada arma viven en su .tres (assets/data/items/*.tres, custom_data).
## `dmg` ya trae todos los multiplicadores del jugador (bendiciones, intoxicacion, afinidad).

const PLAYER_BULLET := preload("res://src/player/player_bullet.tscn")
const BOOMERANG_TEX := preload("res://assets/sprites/projectiles/boomerang.png")
const TARRO_TEX := preload("res://assets/sprites/projectiles/tarro_masilla.png")
const BALLOON_TEX := preload("res://assets/sprites/projectiles/water_balloon.png")
const GLOBO_TEX := preload("res://assets/sprites/projectiles/globocondon.png")
const LUBE_TEX := preload("res://assets/sprites/projectiles/lubricante_agua.png")


## Devuelve la espera (s) hasta el siguiente disparo si es distinta de fire_rate; -1 = normal.
static func fire(p: Node, cd: Dictionary, dmg: float, aim: Vector2, origin: Vector2) -> float:
	match String(cd.get("special", "")):
		"beam":
			_beam(p, cd, dmg, aim, origin)
		"boomerang":
			_boomerang(p, cd, dmg, aim, origin)
		"balloon":
			_balloon(p, cd, dmg, aim, origin)
		"tarro":
			_tarro(p, cd, dmg, aim, origin)
		"catcher":
			_catcher(p, cd, dmg, aim, origin)
		"ducha":
			_ducha(p, cd, dmg, aim, origin)
		"globocondon":
			_globocondon(p, cd, dmg, aim, origin)
		"lube":
			_lube(p, cd, dmg, aim, origin)
		"combo":
			return _combo(p, cd, dmg, aim, origin)
	return -1.0


static func _crit(p: Node, cd: Dictionary) -> float:
	var ps := p.get_node("/root/PlayerStats")
	var chance: float = ps.crit_chance_modifier + float(cd.get("crit_bonus", 0.0))
	return ps.crit_damage_modifier if RNG.randf() < chance else 1.0


static func _enemies() -> Array:
	return p_tree().get_nodes_in_group("enemy").filter(func(e):
		return is_instance_valid(e) and e.has_method("take_damage") and float(e.get("current_health")) > 0.0)


static func p_tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _heal(p: Node, dmg: float) -> void:
	var ps := p.get_node("/root/PlayerStats")
	if ps.lifesteal > 0.0:
		ps.heal(dmg * ps.lifesteal)


## Distancia hasta la primera pared (capa 1) o el alcance maximo.
static func _wall_dist(p: Node, origin: Vector2, aim: Vector2, reach: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(origin, origin + aim * reach, 1)
	var hit: Dictionary = p.get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return reach
	var c = hit.get("collider")
	if c is Node and c.has_method("hit_by_bullet"):
		c.hit_by_bullet(1.0, aim)  # cajas y barriles aguantan el rayo un tic
	return origin.distance_to(hit.position)


# ---------------------------------------------------------------- rayo (Depiladora Laser)
## Un tic del rayo continuo: instantaneo, atraviesa a todos los enemigos de la linea.
static func _beam(p: Node, cd: Dictionary, dmg: float, aim: Vector2, origin: Vector2) -> void:
	var reach := float(cd.get("range", 300.0))
	var width := float(cd.get("beam_width", 12.0))
	var length := _wall_dist(p, origin, aim, reach)
	var mult := _crit(p, cd)
	var per := dmg * mult
	var wid := BossDamage.weapon_of(p)
	for e in _enemies():
		var rel: Vector2 = e.global_position - origin
		var t := rel.dot(aim)
		if t < -8.0 or t > length + 12.0:
			continue
		if absf(rel.cross(aim)) > width * 0.5 + 12.0:
			continue
		BossDamage.tag(wid, mult)
		e.take_damage(per, p, aim * 25.0)
		_heal(p, per)
	var fx := BeamFx.new()
	fx.length = length
	fx.width = width
	fx.color = Color(String(cd.get("bullet_color", "ff5a4a")))
	fx.rotation = aim.angle()
	p.get_parent().add_child(fx)
	fx.global_position = origin


# ---------------------------------------------------------------- bumeran
static func _boomerang(p: Node, cd: Dictionary, dmg: float, aim: Vector2, origin: Vector2) -> void:
	var b := Boomerang.new()
	b.player = p
	b.damage = dmg
	b.speed = float(cd.get("projectile_speed", 540.0)) * p.get_node("/root/PlayerStats").projectile_speed_modifier
	b.reach = float(cd.get("range", 230.0))
	b.knockback = 120.0 * float(cd.get("knockback_mult", 1.0)) * (1.0 + 1.5 * p._rm().blessing("embestida"))
	b.crit_mult = _crit(p, cd)
	b.weapon_id = BossDamage.weapon_of(p)
	b.pierce_all = true
	b.direction = aim
	b.return_mult = 1.5 if Synergies.has("siempre_vuelve") else 1.0
	p.get_parent().add_child(b)
	b.global_position = origin
	p.set("_boomerang", b)


# ---------------------------------------------------------------- globos de agua
static func _balloon(p: Node, cd: Dictionary, dmg: float, aim: Vector2, origin: Vector2) -> void:
	var b: PlayerBullet = PLAYER_BULLET.instantiate()
	b.crit_mult = _crit(p, cd)
	b.weapon_id = BossDamage.weapon_of(p)
	b.damage = dmg * b.crit_mult
	b.speed = float(cd.get("projectile_speed", 310.0)) * p.get_node("/root/PlayerStats").projectile_speed_modifier
	b.lifetime = float(cd.get("range", 270.0)) / b.speed
	b.explosion_radius = float(cd.get("explosion_radius", 55.0))
	b.water = true
	b.skin = BALLOON_TEX
	b.tint = Color(0.75, 0.9, 1.0)
	b.puddle = {
		"radius": float(cd.get("puddle_radius", 62.0)),
		"time": float(cd.get("puddle_time", 4.0)),
		"slow": float(cd.get("puddle_slow", 0.5)),
	}
	b.rotation = aim.angle() + RNG.randf_range(-0.03, 0.03)
	p.get_parent().add_child(b)
	b.global_position = origin


# ---------------------------------------------------------------- tarro de masilla
## Se lanza en arco; al reventar deja una mancha que pega a los enemigos (ver Masilla).
static func _tarro(p: Node, cd: Dictionary, dmg: float, aim: Vector2, origin: Vector2) -> void:
	var b: PlayerBullet = PLAYER_BULLET.instantiate()
	b.crit_mult = _crit(p, cd)
	b.weapon_id = BossDamage.weapon_of(p)
	b.damage = dmg * b.crit_mult
	b.speed = float(cd.get("projectile_speed", 260.0)) * p.get_node("/root/PlayerStats").projectile_speed_modifier
	b.lifetime = float(cd.get("range", 250.0)) / b.speed
	b.explosion_radius = float(cd.get("explosion_radius", 46.0))
	b.knockback = 60.0
	b.water = true  # sin mecha rosa
	b.skin = TARRO_TEX
	b.arc = float(cd.get("arc", 22.0))
	b.putty = {
		"radius": float(cd.get("putty_radius", 58.0)),
		"time": float(cd.get("putty_time", 5.0)),
		"stick": float(cd.get("stick_time", 2.5)),
		"boss_slow": float(cd.get("boss_slow", 0.75)),
	}
	b.rotation = aim.angle()
	p.get_parent().add_child(b)
	b.global_position = origin


# ---------------------------------------------------------------- Ducha Anal (LA PUERTA TRASERA)
## Chorro de agua a presion en cono corto: cada tic pega poco, EMPUJA y LIMPIA los charcos de aceite y las grietas de la zona.
## Dato (PT-26): hace gracia, pero las duchas internas frecuentes irritan; con higiene normal basta.
static func _ducha(p: Node, cd: Dictionary, dmg: float, aim: Vector2, origin: Vector2) -> void:
	var reach := float(cd.get("range", 175.0))
	var half := float(cd.get("cone", 0.28))
	var kb := float(cd.get("push", 55.0))
	var mult := _crit(p, cd)
	var wid := BossDamage.weapon_of(p)
	var length := _wall_dist(p, origin, aim, reach)
	for e in _enemies():
		var rel: Vector2 = e.global_position - origin
		if rel.length() > length + 12.0:
			continue
		if rel.length() > 16.0 and absf(angle_diff(rel.angle(), aim.angle())) > half + 12.0 / maxf(rel.length(), 24.0):
			continue
		BossDamage.tag(wid, mult)
		var per := dmg * mult
		e.take_damage(per, p, aim * kb)
		_heal(p, per)
	PtHazard.clean(p_tree(), origin + aim * length * 0.5, length * 0.5)
	var fx := WaterJetFx.new()
	fx.length = length
	fx.spread = half
	fx.rotation = aim.angle()
	p.get_parent().add_child(fx)
	fx.global_position = origin


# ---------------------------------------------------------------- Globocondon (LA PUERTA TRASERA)
## El condon-globo vuela, revienta al tocar y deja una burbuja de latex que atrapa a los enemigos (ver CondomBubble).
static func _globocondon(p: Node, cd: Dictionary, dmg: float, aim: Vector2, origin: Vector2) -> void:
	var b: PlayerBullet = PLAYER_BULLET.instantiate()
	b.crit_mult = _crit(p, cd)
	b.weapon_id = BossDamage.weapon_of(p)
	b.damage = dmg * b.crit_mult
	b.speed = float(cd.get("projectile_speed", 290.0)) * p.get_node("/root/PlayerStats").projectile_speed_modifier
	b.lifetime = float(cd.get("range", 270.0)) / b.speed
	b.explosion_radius = float(cd.get("explosion_radius", 34.0))
	b.knockback = 40.0
	b.water = true
	b.skin = GLOBO_TEX
	b.rotation = aim.angle()
	var cfg := {"radius": float(cd.get("bubble_radius", 54.0)), "time": float(cd.get("bubble_time", 3.6)),
		"boss_slow": float(cd.get("boss_slow", 0.7)), "pop_damage": dmg * float(cd.get("pop_mult", 1.6)), "weapon_id": b.weapon_id}
	b.burst_cb = func(parent: Node, pos: Vector2) -> void: CondomBubble.make(parent, pos, cfg)
	p.get_parent().add_child(b)
	b.global_position = origin


# ---------------------------------------------------------------- Lubricante a base de agua (LA PUERTA TRASERA)
static func _lube(p: Node, cd: Dictionary, dmg: float, aim: Vector2, origin: Vector2) -> void:
	var b: PlayerBullet = PLAYER_BULLET.instantiate()
	b.crit_mult = _crit(p, cd)
	b.weapon_id = BossDamage.weapon_of(p)
	b.damage = dmg * b.crit_mult
	b.speed = float(cd.get("projectile_speed", 250.0)) * p.get_node("/root/PlayerStats").projectile_speed_modifier
	b.lifetime = float(cd.get("range", 240.0)) / b.speed
	b.explosion_radius = float(cd.get("explosion_radius", 30.0))
	b.knockback = 30.0
	b.water = true
	b.skin = LUBE_TEX
	b.arc = float(cd.get("arc", 18.0))
	b.rotation = aim.angle()
	var cfg := {"radius": float(cd.get("patch_radius", 64.0)), "time": float(cd.get("patch_time", 6.0)),
		"slip_every": float(cd.get("slip_every", 1.6)), "slip_time": float(cd.get("slip_time", 0.7)),
		"slip_damage": dmg * float(cd.get("slip_mult", 0.9)), "weapon_id": b.weapon_id}
	b.burst_cb = func(parent: Node, pos: Vector2) -> void: LubePatch.make(parent, pos, cfg)
	p.get_parent().add_child(b)
	b.global_position = origin


# ---------------------------------------------------------------- atrapabalas
static func _catcher(p: Node, cd: Dictionary, dmg: float, aim: Vector2, origin: Vector2) -> void:
	var c := CatcherBubble.new()
	c.damage = dmg
	c.weapon_id = BossDamage.weapon_of(p)
	c.speed = float(cd.get("projectile_speed", 150.0))
	c.life = float(cd.get("range", 230.0)) / c.speed
	c.catch_radius = float(cd.get("catch_radius", 44.0))
	c.catch_max = int(cd.get("catch_max", 14))
	if Synergies.has("doble_proteccion"):
		c.catch_radius *= 1.5
		c.return_mult = 2.0
	c.direction = aim
	p.get_parent().add_child(c)
	c.global_position = origin


# ---------------------------------------------------------------- combo (Chancleta)
## Tres golpes: los dos primeros rapidos, el tercero lento y de mucho empuje.
static func _combo(p: Node, cd: Dictionary, dmg: float, aim: Vector2, origin: Vector2) -> float:
	var steps := int(cd.get("combo_steps", 3))
	var window := float(cd.get("combo_window", 0.7))
	var st: Dictionary = p.get("_wstate")
	var now := Time.get_ticks_msec() / 1000.0
	var i := int(st.get("combo_i", 0))
	if now - float(st.get("combo_t", -99.0)) > window:
		i = 0
	var last := i >= steps - 1
	var reach := float(cd.get("reach", 66.0)) * (1.4 if Synergies.has("chancla_materna") else 1.0)
	var arc := float(cd.get("arc", 2.0)) * (1.25 if last else 1.0)
	var mult := float(cd.get("finisher_mult", 2.5)) if last else 1.0
	var kb := 160.0 * float(cd.get("knockback_mult", 1.0)) * (2.4 if last else 1.0)
	var player := p
	var hits := 0
	for e in _enemies():
		var rel: Vector2 = e.global_position - origin
		if rel.length() > reach + 14.0:
			continue
		if rel.length() > 14.0 and absf(angle_diff(rel.angle(), aim.angle())) > arc * 0.5:
			continue
		var cm := _crit(p, cd)
		var per := dmg * mult * cm
		BossDamage.tag(BossDamage.weapon_of(p), cm)
		e.take_damage(per, player, rel.normalized() * kb)
		_heal(p, per)
		hits += 1
		if last and e.has_method("stun") and not e.is_in_group("boss"):
			e.stun(0.5)
	# la chancleta tambien devuelve los proyectiles que alcanza
	for a in p_tree().get_nodes_in_group("enemy_attack"):
		if is_instance_valid(a) and a is ProjectileEnemy and (a.global_position - origin).length() < reach:
			a.queue_free()
	var fx := ArcSlash.new()
	fx.reach = reach
	fx.arc = arc
	fx.heavy = last
	fx.flip = i % 2 == 1
	fx.rotation = aim.angle()
	p.get_parent().add_child(fx)
	fx.global_position = origin
	if last:
		HitFx.shake(0.25)
		if hits > 0:
			HitFx.hitstop()
		if Synergies.has("chancla_materna"):
			p.call("_ring", 8, dmg * 0.8)
		i = 0
	else:
		i += 1
	st["combo_i"] = i
	st["combo_t"] = now
	p.set("_wstate", st)
	return float(cd.get("finisher_rate", 0.55)) if last else -1.0


static func angle_diff(a: float, b: float) -> float:
	return fposmod(a - b + PI, TAU) - PI
