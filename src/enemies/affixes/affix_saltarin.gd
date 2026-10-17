extends Affix

## Saltarin: cada INTERVAL s se reposiciona. Aviso de 0.8 s: parpadea y aparece un aro cian en el
## DESTINO (a 120-230 px de ti, siempre sobre suelo libre). No salta si esta atacando o la IA lo
## controla. Tras reaparecer no ataca de inmediato (cooldown de ataque).

const INTERVAL := 5.5
const WARN := 0.8

var _cd := 3.0
var _warn := -1.0
var _dest := Vector2.ZERO


func tick(delta: float) -> void:
	if _warn >= 0.0:
		_warn -= delta
		var spr = host.get("animated_sprite")
		if spr is AnimatedSprite2D:
			spr.self_modulate = Color(0.6, 1.8, 1.8, 0.45) if int(_warn * 16.0) % 2 == 0 else Color.WHITE
		if _warn < 0.0:
			if spr is AnimatedSprite2D:
				spr.self_modulate = Color.WHITE
			jump()
		return
	_cd -= delta
	if _cd > 0.0 or busy() or dist_to_player() > 650.0:
		return
	var d := pick_dest()
	if d == Vector2.INF:
		_cd = 1.0
		return
	_dest = d
	_warn = WARN
	var m := AffixMarker.new()
	m.color = Affixes.color_of(id)
	m.life = WARN + 0.2
	container().add_child(m)
	m.global_position = _dest
	if tag != null:
		tag.flash(Affixes.color_of(id))


func pick_dest() -> Vector2:
	var p := player()
	if p == null:
		return Vector2.INF
	for _i in 10:
		var pos := p.global_position + Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * RNG.randf_range(120.0, 230.0)
		if free_spot(pos, 16.0):
			return pos
	return Vector2.INF


func jump() -> void:
	_cd = INTERVAL
	if float(host.get("current_health")) <= 0.0:
		return
	host.global_position = _dest
	if "velocity" in host:
		host.velocity = Vector2.ZERO
	if "_attack_timer" in host:
		host.set("_attack_timer", maxf(float(host.get("_attack_timer")), 0.6))
	say("*pof*", Vector2(0, -52))
