extends RefCounted

## Esquiva de un jugador atento contra un jefe (la usa el bot, tools/autoplay). Mira balas, zonas
## de peligro (BossZone), peligros propios del jefe (grupo "bot_hazard": bot_exit/bot_urgent) y
## simula 16 direcciones a 0.5 s: elige la que no pisa peligro, o pide un dash si no hay salida.
## Un jefe puede publicar bot_safe (Vector2) = sitio seguro (el hueco de una cortina u ola).

const SPEED := 250.0
const BULLET_R := 30.0


## Peligro (0 = nada) de estar en `q` dentro de `tau` segundos.
static func danger(q: Vector2, tau: float, bullets: Array, zones: Array, waxes: Array) -> float:
	var d := 0.0
	for b in bullets:
		# trayecto barrido de la bala en el ultimo paso de 0.1 s (a 380 px/s salta 38 px)
		var a: Vector2 = b.p + b.v * maxf(tau - 0.1, 0.0)
		var e: Vector2 = b.p + b.v * tau
		if Geometry2D.get_closest_point_to_segment(q, a, e).distance_to(q) < BULLET_R:
			d += 1.0
	for z in zones:
		var left: float = z.warn - z.t if z.phase == 0 else 0.0
		if z.phase >= 2 or left > tau + 0.05:
			continue
		var c: Vector2 = z.global_position + z.vel * maxf(tau - left, 0.0)
		if z.shape == BossZone.Shape.CIRCLE:
			if q.distance_to(c) <= z.radius + 10.0:
				d += 1.0
		else:
			var l: Vector2 = (q - c).rotated(-(z.global_rotation + z.spin * maxf(tau - left, 0.0)))
			if absf(l.x) <= z.size.x * 0.5 + 10.0 and absf(l.y) <= z.size.y * 0.5 + 10.0:
				d += 1.0
	for w in waxes:
		if w.bot_exit(q, tau + 0.05) != Vector2.ZERO:
			d += 1.0
	return d


static func plan(player: Node2D, boss: Node, pref: Vector2, dash_ready: bool, walkable: Callable) -> Dictionary:
	var tree := player.get_tree()
	var pp := player.global_position
	var bullets := []
	for b in tree.get_nodes_in_group("enemy_attack"):
		if b is ProjectileEnemy and is_instance_valid(b):
			bullets.append({"p": b.global_position, "v": Vector2.RIGHT.rotated(b.global_rotation) * b.speed})
	var zones := []
	for z in tree.get_nodes_in_group("boss_hazard"):
		if not (z is BossZone) or z.phase >= 2:
			continue
		# zonas que danan y franjas de aviso (tiras, lineas de punteria, olas): su golpe es otra zona
		if z.damage > 0.0 or (z.shape == BossZone.Shape.RECT and (z.size.y >= 60.0 or z.size.y <= 12.0) and z.warn > 0.2):
			zones.append(z)
	var waxes := tree.get_nodes_in_group("bot_hazard")
	var safe = boss.get("bot_safe")
	var want := pref
	if safe != null:
		var to_safe: Vector2 = (safe as Vector2) - pp
		want = to_safe.normalized() if to_safe.length() > 14.0 else Vector2.ZERO
	var cands: Array[Vector2] = [want]
	for i in 16:
		cands.append(Vector2.RIGHT.rotated(TAU * i / 16.0))
	var best := want
	var best_score := 1.0e9
	var pref_score := 0.0
	var now_danger := 0.0
	for tau in [0.0, 0.1, 0.2]:
		now_danger += danger(pp, tau, bullets, zones, waxes)
	for c in cands:
		var score := 0.0
		for tau in [0.1, 0.2, 0.3, 0.4, 0.5]:
			var q: Vector2 = pp + c * SPEED * tau
			if c != Vector2.ZERO and not walkable.call(q):
				score += 5.0
			score += danger(q, tau, bullets, zones, waxes) * 3.0
		if want != Vector2.ZERO:
			score += (1.0 - c.dot(want)) * 0.4  # prefiere seguir donde iba
		if c == cands[0]:
			pref_score = score
		if score < best_score:
			best_score = score
			best = c
	# sin salida caminando: el dash (con invulnerabilidad) atraviesa
	var dash := dash_ready and now_danger > 0.0 and best_score >= 3.0
	return {"dir": best, "danger": now_danger, "score": best_score, "pref_score": pref_score, "dash": dash}
