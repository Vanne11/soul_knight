extends Affix

## Vampiro: cuando te hace dano se cura el 60% de lo que te quito (sin pasar de su vida maxima).
## Atribucion: el golpe se le acredita si esta a menos de REACH_MELEE (o de REACH_RANGED si dispara).

const HEAL_FRAC := 0.6
const REACH_MELEE := 200.0
const REACH_RANGED := 650.0


func setup() -> void:
	get_node("/root/GlobalEvents").player_damaged.connect(_on_player_damaged)


func _on_player_damaged(amount: float, _src: Node) -> void:
	if _dead or host == null or not is_instance_valid(host) or amount <= 0.0:
		return
	var reach := REACH_RANGED if host is EnemyRanged else REACH_MELEE
	if dist_to_player() > reach:
		return
	var mx := float(host.get("max_health"))
	var cur := float(host.get("current_health"))
	if cur <= 0.0:
		return
	var gain := minf(mx - cur, amount * HEAL_FRAC)
	if gain <= 0.5:
		return
	host.set("current_health", cur + gain)
	say("+%d" % int(round(gain)), Vector2(0, -44))
	if tag != null:
		tag.flash(Affixes.color_of(id))
