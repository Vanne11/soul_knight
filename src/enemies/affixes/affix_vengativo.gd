extends Affix

## Vengativo: si matas a otro enemigo de su sala se enfurece 6 s (usa la rabia de la propia IA:
## mas rapido y mas dano segun su personalidad) y avisa con el icono de la vena. Los que ya
## huyen, duermen o se rindieron no se enfurecen.

const RAGE_SECS := 6.0


func setup() -> void:
	get_node("/root/GlobalEvents").enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(e: Node, _killer: Node) -> void:
	if _dead or e == host or host == null or not is_instance_valid(host) or not is_instance_valid(e):
		return
	if not e.is_in_group("enemy"):
		return
	var a := ai()
	if a == null or a.mode in [EnemyAI.Mode.SLEEP, EnemyAI.Mode.SURRENDER, EnemyAI.Mode.FLEE]:
		return
	if host.has_method("find_owning_room") and host.find_owning_room() != (e.find_owning_room() if e.has_method("find_owning_room") else null):
		return
	a._enrage(RAGE_SECS, "rage")
	say(Loc.tr_or("AFFIX_VENGE", "¡Venganza!"), Vector2(0, -60))
	if tag != null:
		tag.flash(Affixes.color_of(id))
