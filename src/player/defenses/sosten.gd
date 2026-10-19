extends Defense
class_name DefSosten

## SOSTEN DEPORTIVO (defensa PASIVA). Buen soporte para correr: los empujones te mueven solo KNOCKBACK x y el
## dash cuesta DASH_COST x de estamina y dura DASH_TIME x (mas ventana de esquiva). No reemplaza a la guard
## del heroe. "Cuidar el cuerpo al hacer deporte."

const KNOCKBACK := 0.4
const DASH_COST := 0.7
const DASH_TIME := 1.3


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("3fd0c0")


func is_passive() -> bool:
	return true


func knockback_mult() -> float:
	return KNOCKBACK


func dash_cost_mult() -> float:
	return DASH_COST


func dash_time_mult() -> float:
	return DASH_TIME
