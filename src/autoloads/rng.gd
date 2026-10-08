extends Node
class_name RNG

## Seeded random number generator for deterministic procedural generation
## Usage: RNG.randomize(seed) -> RNG.randi() / RNG.randf() / RNG.randf_range(min, max)

static var _seed: int = 0
static var _state: int = 0

static func randomize(seed: int = 0) -> void:
	if seed == 0:
		seed = Time.get_ticks_msec()
	_seed = seed
	_state = seed
	print("RNG seeded: %d" % seed)

static func randi() -> int:
	_state = (_state * 1103515245 + 12345) & 0x7fffffff
	return _state

## OJO: dentro de esta clase hay que escribir RNG.randi()/RNG.randf(). Sin el
## prefijo, GDScript llama a los randi()/randf() GLOBALES (sin semilla) y la
## misma semilla daba mazmorras distintas.
static func randf() -> float:
	return RNG.randi() / 2147483647.0

static func randf_range(min: float, max: float) -> float:
	return min + RNG.randf() * (max - min)

static func randi_range(min: int, max: int) -> int:
	if max < min:
		var tmp := min
		min = max
		max = tmp
	# Nada de randi() % n: en un LCG de modulo 2^31 los bits bajos se repiten
	# con periodo corto (el ultimo alterna 0/1) y con n par habia indices que
	# no salian nunca: el cofre "de arma" podia no encontrar ningun arma.
	return mini(max, min + int(RNG.randf() * (max - min + 1)))

static func get_seed() -> int:
	return _seed

static func set_state(state: int) -> void:
	_state = state

static func get_state() -> int:
	return _state

## Weighted random pick from dictionary {item: weight}
static func weighted_pick(weights: Dictionary) -> Variant:
	var total := 0.0
	for w in weights.values():
		total += w
	var r := RNG.randf() * total
	var acc := 0.0
	for k in weights.keys():
		acc += weights[k]
		if r <= acc:
			return k
	return weights.keys().front()

## Shuffle array in place (Fisher-Yates)
static func shuffle(array: Array) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := RNG.randi_range(0, i)
		var tmp: Variant = array[i]
		array[i] = array[j]
		array[j] = tmp