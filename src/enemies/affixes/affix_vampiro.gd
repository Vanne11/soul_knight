extends Affix

## Vampiro: cuando te hace dano se cura el 60% de lo que te quito (sin pasar de su vida maxima).
## Atribucion: el golpe se le acredita si esta a menos de REACH_MELEE (o de REACH_RANGED si dispara).
## El dano no trae quien lo hizo: si hay varios vampiros en rango, la cura se reparte entre ellos.

const HEAL_FRAC := 0.6
const REACH_MELEE := 200.0
const REACH_RANGED := 650.0


func setup() -> void:
	add_to_group("affix_vampiro")
	get_node("/root/GlobalEvents").player_damaged.connect(_on_player_damaged)


func _in_reach() -> bool:
	if _dead or host == null or not is_instance_valid(host) or float(host.get("current_health")) <= 0.0:
		return false
	return dist_to_player() <= (REACH_RANGED if host is EnemyRanged else REACH_MELEE)


func _on_player_damaged(amount: float, _src: Node) -> void:
	if amount <= 0.0 or not _in_reach():
		return
	var sharing := get_tree().get_nodes_in_group("affix_vampiro").filter(func(v): return v._in_reach()).size()
	var mx := float(host.get("max_health"))
	var cur := float(host.get("current_health"))
	if cur <= 0.0:
		return
	var gain := minf(mx - cur, amount * HEAL_FRAC / maxf(sharing, 1))
	if gain <= 0.5:
		return
	host.set("current_health", cur + gain)
	say("+%d" % int(round(gain)), Vector2(0, -44))
	if tag != null:
		tag.flash(Affixes.color_of(id))
