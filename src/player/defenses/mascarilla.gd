extends Defense
class_name DefMascarilla

## MASCARILLA (defensa PASIVA). Inmunidad a NUBES, VAPORES y ESPORAS: se tragan sin hacerte nada las esporas del
## Polipo Callado (proyectiles cuyo dueno esta en el grupo "polipo_callado") y todo lo que se declare "vapor"
## (grupo "vapor" o meta "vapor" en el area) o llegue como estado de CLOUD_KINDS. Gancho generico para el VAPOR
## DEL POPPER (enemigo de la Puerta Trasera, aun no existe en el codigo): su nube solo tiene que consultar
## `Defense.cloud_immune(player)` o marcarse "vapor". Guino de reduccion de danos: protegerse es de adultos.

const CLOUD_KINDS := ["vapor", "nube", "esporas", "gas", "humo", "popper"]

var filtered := 0
var _flash := 0.0
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("8fd0ff")


func is_passive() -> bool:
	return true


func blocks_cloud() -> bool:
	return true


func blocks_status_kind(kind: String) -> bool:
	return kind in CLOUD_KINDS


func _is_cloud(area: Area2D) -> bool:
	if area.is_in_group("vapor") or area.has_meta("vapor"):
		return true
	var owner_node = area.get("projectile_owner")
	return owner_node != null and is_instance_valid(owner_node) and owner_node.is_in_group("polipo_callado")


func try_guard(area: Area2D, _dmg: float) -> bool:
	if not _is_cloud(area):
		return false
	if area.has_method("on_hit"):
		consume(area)
	filtered += 1
	_flash = 0.3
	text("DEF_MASK_FILTER", Color("bfe6ff"))
	Sound.play("crack", 0.1)
	return true


func _draw_tick() -> void:
	_t += get_process_delta_time()
	_flash = maxf(0.0, _flash - get_process_delta_time())
	if _flash > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if _flash <= 0.0:
		return
	draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 28, Color(0.6, 0.85, 1.0, _flash * 2.0), 2.5)
