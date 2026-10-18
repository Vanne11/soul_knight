extends RefCounted
class_name PuzzleFactory

## Elige y monta el acertijo de la sala PUZZLE (lo llama main._build_puzzle).
## Un acertijo propio por reino; a veces uno creativo (luz y espejos) en su lugar.
## Reino: SIEMPRE de RunManager.floor_data().kingdom (nunca del indice de piso).

const SIGNATURE := {
	"neutral": preload("res://src/puzzles/puzzle_mushrooms.gd"),   # Selva: memoria con setas
	"pene": preload("res://src/puzzles/puzzle_statues.gd"),        # Penelandia: Sokoban de estatuas
	"vulva": preload("res://src/puzzles/puzzle_flowers.gd"),       # Vulvania: flores Lights Out
	"mixto": preload("res://src/puzzles/puzzle_stamps.gd"),        # Perineo: papeleo de sellos
	"censura": preload("res://src/puzzles/puzzle_uncensor.gd"),    # Palacio: descensurar
}
const CREATIVE := [
	preload("res://src/puzzles/puzzle_mirrors.gd"),   # luz y espejos
	preload("res://src/puzzles/puzzle_shadows.gd"),   # tapar una placa con tu sombra
	preload("res://src/puzzles/puzzle_golf.gd"),      # minigolf con un testiculo
	preload("res://src/puzzles/puzzle_tracks.gd"),    # huellas en el barro
	preload("res://src/puzzles/puzzle_diary.gd"),     # diario intimo (numeros en otras salas)
]
## Creativos que ademas salen con mas ganas en un reino concreto (se suman a CREATIVE).
const EXTRA := {
	"pene": [preload("res://src/puzzles/puzzle_sphinx.gd"), preload("res://src/puzzles/puzzle_sphinx.gd")],  # Esfinge de Penelandia
	"neutral": [preload("res://src/puzzles/puzzle_tracks.gd")],
	"vulva": [preload("res://src/puzzles/puzzle_diary.gd")],
	"mixto": [preload("res://src/puzzles/puzzle_shadows.gd")],
	"censura": [preload("res://src/puzzles/puzzle_golf.gd")],
}
## Probabilidad de que la sala sea un acertijo creativo en vez del del reino.
const CREATIVE_CHANCE := 0.45
## Margen que se deja libre desde el borde de la sala (muro, puerta y por donde se entra).
const MARGIN := Vector2(128.0, 112.0)


## Dificultad por profundidad: UNICO punto a tocar cuando los pisos se mezclen (10 pisos,
## dos etapas por reino). Hoy es el numero de piso; mas adelante, por ejemplo,
## 2 * reino + etapa. Los acertijos solo leen este numero (1 = el mas facil).
static func depth() -> int:
	return RunManager.depth_i(int(Engine.get_main_loop().root.get_node("/root/RunManager").current_floor))


static func kingdom() -> String:
	return str(Engine.get_main_loop().root.get_node("/root/RunManager").floor_data().get("kingdom", "neutral"))


## Monta el acertijo en la sala (no lo anade a ningun nodo: lo hace quien llama).
static func create(room: Room, seed_value: int, kingdom_id := "", depth_n := -1) -> Puzzle:
	var k := kingdom_id if kingdom_id != "" else kingdom()
	var d := depth_n if depth_n >= 0 else depth()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var script: GDScript = SIGNATURE.get(k, SIGNATURE.neutral)
	if rng.randf() < CREATIVE_CHANCE:
		var pool: Array = CREATIVE + EXTRA.get(k, [])
		script = pool[rng.randi_range(0, pool.size() - 1)]
	return create_of(script, room, rng, k, d)


static func create_of(script: GDScript, room: Room, rng: RandomNumberGenerator, k: String, d: int) -> Puzzle:
	var pz: Puzzle = script.new()
	pz.kingdom = k
	pz.depth = maxi(1, d)
	pz.rng = rng
	var rect := room.floor_tilemap.get_used_rect()
	pz.area = (Vector2(rect.size) * 64.0 - MARGIN * 2.0).max(Vector2(192.0, 144.0))
	pz.position = room.get_center_position()
	return pz  # build() corre solo al entrar en el arbol (Puzzle._ready)
