extends Affix

## Pegajoso: si lo tocas (a menos de 46 px) te ralentiza un 40% durante 1.5 s (se renueva
## mientras sigas pegado). Los objetos con inmunidad "slow" te protegen y el dash lo esquiva.
## Sin dano propio: es una trampa para el movimiento; el aviso son las gotas verdes y el icono.

const REACH := 46.0
const SLOW := 0.6
const SECS := 1.5


func tick(_delta: float) -> void:
	if dist_to_player() > REACH:
		return
	var ps := get_node("/root/PlayerStats")
	var p := player()
	if ("is_dashing" in p and p.is_dashing) or ps.has_item_immunity("slow"):
		return
	if not ps.has_meta("sticky_on"):
		ps.speed_modifier *= SLOW
		ps.set_meta("sticky_on", true)
		say(Loc.tr_or("AFFIX_STICK", "¡Pegajoso!"), Vector2(0, -44))
		ps.get_tree().create_timer(SECS).timeout.connect(unstick.bind(ps))
	ps.set_meta("sticky_until", Time.get_ticks_msec() + int(SECS * 1000.0))


## Estatica y atada al PlayerStats (no al enemigo): se restaura aunque el afijo ya no exista.
static func unstick(ps: Node) -> void:
	if not is_instance_valid(ps) or not ps.has_meta("sticky_on"):
		return
	var left := int(ps.get_meta("sticky_until", 0)) - Time.get_ticks_msec()
	if left > 0:
		ps.get_tree().create_timer(left / 1000.0 + 0.02).timeout.connect(unstick.bind(ps))
		return
	ps.speed_modifier /= SLOW
	ps.remove_meta("sticky_on")
