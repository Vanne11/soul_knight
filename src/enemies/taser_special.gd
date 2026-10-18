class_name TaserSpecial
extends RefCounted

## El Dildo Electrico (arma "dildo_taser") es un arma especial de UN piso: solo la suelta el
## primer Dildo Electrico que muere en Vulvania (etapa 1), una vez por partida. Fuera de ahi no
## sale de cofres, tienda ni mercado (tag "exclusivo", ver ItemDatabase.get_random_item).
## El piso se identifica por region/etapa, no por numero (el orden de los reinos cambia por heroe).
## Estado por partida: se reinicia solo cuando cambia RunManager.run_start_time.

const ITEM_ID := "dildo_taser"
const REGION := "vulvania"

static var _run_key := -1.0
static var _forced := false
static var _dropped := false


static func _sync() -> void:
	var key: float = Engine.get_main_loop().root.get_node("RunManager").run_start_time
	if key != _run_key:
		_run_key = key
		_forced = false
		_dropped = false


static func is_special_floor(floor_n: int) -> bool:
	return RunManager.floor_region(floor_n) == REGION and RunManager.floor_stage(floor_n) == 1


## Elige el indice de enemigo de una sala de combate: en el piso especial, el primer bicho
## garantizado es un Dildo Electrico (types[i] == "taser"), si el piso lo tiene. Si sale uno
## natural, tambien cuenta como garantizado.
static func pick_index(t: int, types: Array, floor_n: int) -> int:
	_sync()
	if _forced or not is_special_floor(floor_n):
		return t
	if types[t] == "taser":
		_forced = true
		return t
	var i := types.find("taser")
	if i < 0:
		return t
	_forced = true
	return i


## true una sola vez por partida: el primer Dildo Electrico muerto en el piso especial.
static func claim_drop(floor_n: int) -> bool:
	_sync()
	if _dropped or not is_special_floor(floor_n):
		return false
	_dropped = true
	return true
