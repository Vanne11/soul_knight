extends Area2D
class_name PlayerBullet

## Bala del jugador. Mascara 1 (paredes) + 2 (cuerpos enemigos).

var damage: float = 8.0
var speed: float = 500.0
var lifetime: float = 1.6
## Bendiciones: enemigos que aun atraviesa y fuerza del empujon.
var pierce: int = 0
var knockback: float = 120.0
## Solo presentacion: critico o golpe fuerte dispara la pausa breve al impactar.
var crit := false
## Para BossDamage: arma que la disparo y factor de critico aplicado (1.0 = sin critico).
var weapon_id := ""
var crit_mult := 1.0
const STRONG_HIT := 20.0
var _t: float = 0.0
var _dist: float = 0.0
## Caida de dano por distancia (escopeta): 100% hasta falloff_start, falloff_min a falloff_end.
var falloff_start := 0.0
var falloff_end := 0.0
var falloff_min := 1.0
## Explosion en area al impactar o agotarse la mecha (lanzapreservativos). 0 = bala normal.
var explosion_radius := 0.0
## Cadena electrica (taser): salta a otros enemigos cercanos con chain_mult del dano.
var chain := 0
var chain_radius := 110.0
var chain_mult := 0.5
var tint := Color.WHITE
## Globo de agua (etapa 6d): explota en agua (sin mecha rosa) y deja un charco `puddle`
## {radius, time, slow}. `skin` cambia la textura; `stun` aturde (segundos) al golpear (confeti).
var water := false
var puddle: Dictionary = {}
var skin: Texture2D = null
var stun := 0.0
## Tarro de Masilla: mancha {radius, time, stick, boss_slow} al reventar; `arc` = altura visual del lanzamiento en arco.
var putty: Dictionary = {}
var arc := 0.0
## Efecto propio al reventar (Globocondon, Lubricante): Callable(parent: Node, pos: Vector2).
var burst_cb := Callable()
var _done := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	ActorFx.add_projectile_shadow(self, 4.0, 9.0)
	if skin != null:
		$Sprite2D.texture = skin
	var glow_col := Color(1.0, 0.8, 0.35)
	if tint != Color.WHITE:
		$Sprite2D.modulate = tint
		glow_col = tint
	if explosion_radius > 0.0 and water:
		glow_col = Color(0.7, 0.85, 0.6) if not putty.is_empty() else Color(0.4, 0.7, 1.0)
	elif explosion_radius > 0.0:
		$Sprite2D.scale = Vector2.ONE * 1.8
		glow_col = Color(1.0, 0.45, 0.7)
		$Sprite2D.modulate = Color(1.0, 0.7, 0.85)
	ActorFx.add_glow(self, glow_col, 0.55, 0.32)

func _physics_process(delta: float) -> void:
	position += Vector2.RIGHT.rotated(rotation) * speed * delta
	_dist += speed * delta
	_t += delta
	if arc > 0.0:
		var k := clampf(_t / lifetime, 0.0, 1.0)
		$Sprite2D.position.y = -sin(k * PI) * arc
		$Sprite2D.rotation += delta * 9.0
	if explosion_radius > 0.0 and not water:
		# la mecha avisa: el preservativo parpadea mas rapido al acercarse a estallar
		var left := lifetime - _t
		if left < 0.35:
			$Sprite2D.modulate = Color(1.0, 0.7, 0.85) if int(_t * 24.0) % 2 == 0 else Color(2.2, 2.2, 2.2)
	if _t >= lifetime:
		if explosion_radius > 0.0:
			_explode()
		else:
			queue_free()

## Multiplicador de dano segun lo lejos que ha volado.
func _falloff() -> float:
	if falloff_end <= 0.0 or _dist <= falloff_start:
		return 1.0
	return lerpf(1.0, falloff_min, clampf((_dist - falloff_start) / (falloff_end - falloff_start), 0.0, 1.0))

func _explode() -> void:
	if _done:
		return
	_done = true
	var player := get_tree().get_first_node_in_group("player")
	var ps := get_node("/root/PlayerStats")
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not e.has_method("take_damage") or float(e.get("current_health")) <= 0.0:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d > explosion_radius + 14.0:  # + medio cuerpo del enemigo
			continue
		# 100% en el centro, 60% en el borde
		var dmg := damage * lerpf(1.0, 0.6, clampf(d / explosion_radius, 0.0, 1.0))
		var away: Vector2 = (e.global_position - global_position).normalized()
		BossDamage.tag(weapon_id, crit_mult)
		e.take_damage(dmg, player, away * knockback * 1.6)
		if ps.lifesteal > 0.0:
			ps.heal(dmg * ps.lifesteal)
	# cajas y barriles
	var q := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	q.shape = shape
	q.transform = Transform2D(0.0, global_position)
	q.collision_mask = 1
	for r in get_world_2d().direct_space_state.intersect_shape(q, 16):
		var c = r.collider
		if c is Node and c.has_method("hit_by_bullet"):
			c.hit_by_bullet(damage, (c.global_position - global_position).normalized())
	var fx := ExplosionFx.new()
	fx.radius = explosion_radius
	if water:
		fx.modulate = Color(0.85, 1.05, 0.8) if not putty.is_empty() else Color(0.45, 1.0, 1.4)
	get_parent().add_child(fx)
	fx.global_position = global_position
	if not puddle.is_empty():
		Puddle.spawn(get_parent(), global_position, puddle)
	if not putty.is_empty():
		Masilla.spawn(get_parent(), global_position, putty)
	if burst_cb.is_valid():
		burst_cb.call(get_parent(), global_position)
	HitFx.shake(0.4)
	HitFx.hitstop()
	get_node("/root/Sound").play("crack", 0.15)
	queue_free()

## Taser: del enemigo golpeado salta a los mas cercanos (sin repetir).
func _chain_from(first: Node) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var hit: Array = [first]
	var from: Vector2 = first.global_position
	for _i in chain:
		var best: Node2D = null
		var bd := chain_radius
		for e in get_tree().get_nodes_in_group("enemy"):
			if e in hit or not is_instance_valid(e) or not e.has_method("take_damage") or float(e.get("current_health")) <= 0.0:
				continue
			var d: float = e.global_position.distance_to(from)
			if d < bd:
				bd = d
				best = e
		if best == null:
			break
		hit.append(best)
		BossDamage.tag(weapon_id, crit_mult)
		best.take_damage(damage * chain_mult, player, Vector2.ZERO)
		ArcFx.zap(get_parent(), from + Vector2(0, -8), best.global_position + Vector2(0, -8))
		from = best.global_position

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	if _done:
		return
	if explosion_radius > 0.0:
		_explode()
		return
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		var dmg := damage * _falloff()
		BossDamage.tag(weapon_id, crit_mult)
		body.take_damage(dmg, get_tree().get_first_node_in_group("player"), Vector2.RIGHT.rotated(rotation) * knockback)
		if crit or dmg >= STRONG_HIT:
			HitFx.hitstop()
		if stun > 0.0 and body.has_method("stun") and not body.is_in_group("boss"):
			body.stun(stun)
		var ps := get_node("/root/PlayerStats")
		if ps.lifesteal > 0.0:
			ps.heal(dmg * ps.lifesteal)
		if chain > 0:
			_chain_from(body)
		if pierce > 0:
			pierce -= 1
			return
	elif body.has_method("hit_by_bullet"):  # barriles y cajas rompibles (RoomObstacles)
		body.hit_by_bullet(damage, Vector2.RIGHT.rotated(rotation))
	_done = true  # queue_free es diferido: otro cuerpo en el mismo paso de fisica recibia el golpe entero
	queue_free()
