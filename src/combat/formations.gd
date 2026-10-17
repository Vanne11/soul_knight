class_name Formations
extends RefCounted

## Formaciones de enemigos (las usa waves.gd): grupos con logica hechos con los bichos del piso
## (ids de EnemyRegistry que ya trae _generate_enemy_data_for_room), no bichos sueltos.
##
## Cada enemigo tiene un ROL segun su "enemy_type":
##   "frente"   cuerpo a cuerpo (melee, its, huincha...)       -> primera fila, hacia el centro
##   "tanque"   tank (Hemorroide Fronteriza)                   -> abre la primera fila
##   "enjambre" swarmer (grupos de 2-3)                        -> primera fila, mas separados
##   "fondo"    tiradores y control de zona (ranged, taser...) -> segunda fila, pegados a su puerta
##
## Formaciones (cual toca lo decide waves.gd con el sorteo de la oleada):
##   GRUPO      frente/tanque/enjambre delante, tiradores detras (tanque + tiradores,
##              enjambre + tiradores) en UNA entrada.
##   PINZA      dos GRUPOS en entradas opuestas (puertas o bordes lejanos entre si).
##   EMBOSCADA  un GRUPO en la puerta por la que entraste, cuando ya te alejaste (a tu espalda).
## La IA (src/enemies/ai/) no se toca: cada bicho conserva su personalidad.

const SHOOTERS := ["ranged", "taser", "mordaza", "venda", "sonda", "espinilla"]

const ROW_FRONT := 80.0     # la fila de delante esta tanto mas adentro que la de atras
const ROW_STEP := 46.0      # separacion entre filas cuando una fila se llena
const LATERAL := 46.0       # separacion lateral entre bichos de una fila
const LATERAL_SWARM := 60.0 # los enjambres traen su propio reparto (+28 px) y piden mas aire
const PER_ROW := 3


static func role(entry: Dictionary) -> String:
	var t := str(entry.get("enemy_type", EnemyRegistry.FALLBACK))
	if t == "tank":
		return "tanque"
	if t == "swarmer":
		return "enjambre"
	if t in SHOOTERS:
		return "fondo"
	return "frente"


## true si hay con que armar un GRUPO (algo delante y algo detras).
static func can_group(entries: Array) -> bool:
	var back := 0
	for e in entries:
		if role(e) == "fondo":
			back += 1
	return back >= 1 and entries.size() - back >= 1


## Ancla de una puerta: los bichos aparecen pegados a ella, mirando hacia adentro.
## {base: fila de atras (global), inward: unitario hacia el centro, front: desfase de la
## fila delantera, door: la puerta}
static func door_anchor(door: Door) -> Dictionary:
	var inward := Vector2.DOWN
	match door.get_direction_name():
		"down": inward = Vector2.UP
		"left": inward = Vector2.RIGHT
		"right": inward = Vector2.LEFT
	return {"base": door.global_position + inward * 70.0, "inward": inward, "front": ROW_FRONT, "door": door}


## Ancla de un borde libre (punto de aparicion de la sala): el frente mira al centro.
static func point_anchor(pos: Vector2, center: Vector2) -> Dictionary:
	var inward := (center - pos).normalized() if pos.distance_to(center) > 1.0 else Vector2.DOWN
	return {"base": pos, "inward": inward, "front": 50.0, "door": null}


## Posiciones (globales) de entries[idxs] colocadas en formacion sobre el ancla.
## Escribe out[idx] = posicion. Delante: tanque al medio, luego enjambre y frente; detras: tiradores.
static func place(entries: Array, idxs: Array, anchor: Dictionary, out: Dictionary) -> void:
	var front: Array = []
	var back: Array = []
	for i in idxs:
		var r := role(entries[i])
		if r == "fondo":
			back.append(i)
		elif r == "tanque":
			front.push_front(i)
		else:
			front.append(i)
	if front.is_empty():  # solo tiradores: una sola fila
		front = back
		back = []
	var inward: Vector2 = anchor.inward
	var side := inward.orthogonal()
	var base: Vector2 = anchor.base
	_rows(entries, front, base + inward * float(anchor.front), side, inward, out)
	_rows(entries, back, base, side, -inward, out)


## Reparte la lista en filas de PER_ROW centradas; las filas que sobran se apilan hacia `grow`.
static func _rows(entries: Array, list: Array, origin: Vector2, side: Vector2, grow: Vector2, out: Dictionary) -> void:
	var row := 0
	var k := 0
	while k < list.size():
		var n := mini(PER_ROW, list.size() - k)
		for j in n:
			var i: int = list[k + j]
			var step := LATERAL_SWARM if role(entries[i]) == "enjambre" else LATERAL
			out[i] = origin + side * ((float(j) - float(n - 1) * 0.5) * step) + grow * (float(row) * ROW_STEP)
		k += n
		row += 1
