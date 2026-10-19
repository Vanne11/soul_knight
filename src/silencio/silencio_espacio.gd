class_name SilencioEspacio
extends SilencioSala

## S2. Micromachismos 2: "Espacio" (diseno_E3, seccion 3). Un anden ancho con siluetas de pie, solas y en
## grupos; el carril libre es estrecho. Caminas a la puerta del fondo.
##   - Cada ~3 s una silueta cruza y te desplaza con un empujon suave (26 px; no daña, no aturde). No se
##     disculpa.
##   - Un banco de 3 asientos: una silueta ocupa 2 con sus cosas y no se mueve. Si te sientas en el libre,
##     se extiende un poco mas.
##   - Dos veces, un panel de dos caminos (A/B). Si no eliges, a los 2 s avanza solo por A. Si eliges B, el
##     panel dice "Ya lo decidimos" y te lleva por A (la puerta B esta pintada, no abre).
##   - La salida siempre abre. Llegar se siente mas lento y estrecho; nadie dijo que no pudieras pasar.
## Sin dano, sin recompensa, sin fracaso. Al llegar al fondo: cartel final y entrada de codice
## "espacio y decisiones" (evento silencio_espacio).

const INTERACTABLE := preload("res://src/items/interactable.gd")
const CROSS_EVERY := 3.0                     # s entre cruces
const CROSS_SPEED := 96.0                    # px/s de la silueta que cruza
const PUSH_DIST := 26.0                      # empujon suave
const FORK_X := [300.0, 760.0]               # donde esta cada panel
const FORK_RADIUS := 110.0                   # a esta distancia el panel espera tu eleccion
const FORK_WAIT := 2.0                       # s sin elegir y avanza solo por A
const ZONE_R := 30.0
const BENCH := Vector2(600, 372)             # centro de la base del banco; asientos a -32, 0 y +32
const FINISH_X := 1010.0                     # pasado este punto, llegaste
const CROWD := [
	["pie_a", Vector2(176, 96)], ["pie_b", Vector2(204, 112)], ["pie_c", Vector2(150, 118)],
	["pie_b", Vector2(430, 100)], ["pie_a", Vector2(462, 92)],
	["pie_c", Vector2(530, 336)], ["pie_a", Vector2(430, 318)],
	["pie_b", Vector2(880, 104)], ["pie_a", Vector2(914, 118)], ["pie_c", Vector2(896, 140)],
	["pie_a", Vector2(980, 330)], ["pie_b", Vector2(1010, 348)], ["pie_c", Vector2(1100, 112)],
	["pie_b", Vector2(240, 352)], ["pie_a", Vector2(668, 108)],
]

var _t := 0.0
var _crossers: Array = []   # {fig, dir, pushed}
var _forks: Array = []      # {x, state, wait, bubble}
var _sitter: SilencioFigura
var _bag: Sprite2D
var _seat_used := false


func build() -> void:
	for c in CROWD:
		figure(c[0], c[1], Color(0.9 + 0.02 * (absi(hash(c[1])) % 5), 0.9, 0.96))
	# banco: una silueta en el primer asiento y sus cosas en el segundo; el tercero esta libre
	sprite("banco", BENCH)
	solid(Rect2(BENCH.x - 48, BENCH.y - 18, 96, 14))
	_sitter = figure("sentada", BENCH + Vector2(-32, -2), Color(0.94, 0.94, 1.0))
	_bag = sprite("bolsa", BENCH + Vector2(0, -6))
	_bag.z_index = 1
	for x in FORK_X:
		_forks.append({"x": x, "state": "wait", "wait": 0.0, "bubble": _build_fork(x)})
	_make_sit_prop()


## Panel de dos caminos con sus dos marcas en el suelo (A arriba, B abajo) y las dos puertas: la A
## abierta (un hueco oscuro) y la B pintada (no abre).
func _build_fork(x: float) -> SilencioBurbuja:
	sprite("panel_caminos", Vector2(x, 232))
	var a := Marca.new()
	a.position = Vector2(x + 90, 188)
	a.letter = "A"
	room.props_node.add_child(a)
	var b := Marca.new()
	b.position = Vector2(x + 90, 276)
	b.letter = "B"
	room.props_node.add_child(b)
	var open_a := ColorRect.new()  # la puerta A: un hueco oscuro en el muro de arriba
	open_a.color = Color("201f24")
	open_a.position = Vector2(x + 70, 8)
	open_a.size = Vector2(40, 56)
	room.props_node.add_child(open_a)
	sprite("puerta_pintada", Vector2(x + 90, 448))  # la B: pintada contra el muro de abajo
	var bub := SilencioBurbuja.create(tr("SIL_S2_PANEL"), SilencioBurbuja.PAPER, SilencioBurbuja.INK, 96.0)
	bub.z_index = 3
	room.props_node.add_child(bub)
	bub.hang_over(Vector2(x, 172))
	return bub


## Interactuable en el asiento libre del banco.
func _make_sit_prop() -> void:
	var it := INTERACTABLE.new()
	it.position = BENCH + Vector2(32, -14)
	it.prompt_text = tr("SIL_S2_SENTARTE")
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 34.0
	it.add_child(shape)
	it.collision_layer = 0
	it.collision_mask = 1
	it.used.connect(func(p):
		if _seat_used:
			return
		_seat_used = true
		it.finish()
		_sit(p))
	room.props_node.add_child.call_deferred(it)


## Te sientas en el asiento libre: la silueta se extiende un poco mas (sus cosas tambien).
func _sit(p: Node) -> void:
	await Silencio.carry(p, to_world(BENCH + Vector2(32, -20)), 0.35)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sitter, "position:x", _sitter.position.x + 12.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sitter.sprite, "scale", Vector2(1.14, 1.0), 1.6)
	tw.tween_property(_bag, "position:x", _bag.position.x + 20.0, 1.6).set_trans(Tween.TRANS_SINE)


func start() -> void:
	_t = 1.5  # el primer cruce llega pronto


func stop() -> void:
	for c in _crossers:
		if is_instance_valid(c.fig):
			c.fig.queue_free()
	_crossers.clear()


func _process(delta: float) -> void:
	if not inside:
		return
	var hp := hero().global_position - room.global_position
	_t -= delta
	if _t <= 0.0:
		_t = CROSS_EVERY
		if hp.x > 130.0 and hp.x < FINISH_X + 60.0:
			_spawn_crosser(hp)
	_step_crossers(delta, hp)
	for f in _forks:
		_step_fork(f, delta, hp)
	if hp.x >= FINISH_X:
		conclude([tr("SIL_S2_CARTEL_1"), tr("SIL_S2_CARTEL_2")], "silencio_espacio")


## Una silueta entra por arriba o por abajo y cruza el anden justo por donde pasas.
func _spawn_crosser(hp: Vector2) -> void:
	var dir := 1.0 if randf() < 0.5 else -1.0
	var x := clampf(hp.x + randf_range(-14.0, 14.0), 90.0, 1060.0)
	var from_y := 28.0 if dir > 0.0 else size_px().y - 28.0
	var fig := figure(["pie_a", "pie_b", "pie_c"][randi() % 3], Vector2(x, from_y), Color(0.92, 0.92, 0.98))
	fig.z_index = 1
	_crossers.append({"fig": fig, "dir": dir, "pushed": false})


func _step_crossers(delta: float, hp: Vector2) -> void:
	for c in _crossers.duplicate():
		var fig: SilencioFigura = c.fig
		fig.position.y += c.dir * CROSS_SPEED * delta
		if not c.pushed and absf(fig.position.x - hp.x) < 24.0 and absf(fig.position.y - hp.y) < 30.0:
			c.pushed = true
			Silencio.push(hero(), Vector2(0, c.dir), PUSH_DIST)
		if fig.position.y < 12.0 or fig.position.y > size_px().y - 12.0:
			fig.queue_free()
			_crossers.erase(c)


func _step_fork(f: Dictionary, delta: float, hp: Vector2) -> void:
	if f.state == "done":
		return
	var x: float = f.x
	var in_a := hp.distance_to(Vector2(x + 90, 188)) < ZONE_R
	var in_b := hp.distance_to(Vector2(x + 90, 276)) < ZONE_R
	if in_a:
		f.state = "done"  # elegiste A: caminas
		return
	if in_b:
		f.state = "done"
		f.bubble.set_text(tr("SIL_S2_YA_LO_DECIDIMOS"))
		_take_a(x)
		return
	if hp.distance_to(Vector2(x, 232)) < FORK_RADIUS and hp.x < x + 60.0:
		f.wait += delta
		if f.wait >= FORK_WAIT:
			f.state = "done"
			_take_a(x)
	else:
		f.wait = 0.0


## Te lleva por A (la unica que abre): sin dano y sin poder impedirlo.
func _take_a(x: float) -> void:
	await get_tree().create_timer(0.6).timeout
	if inside:
		Silencio.carry(hero(), to_world(Vector2(x + 190, 224)), 1.1)


## Marca de suelo de una opcion (A o B).
class Marca extends Node2D:
	var letter := "A"

	func _draw() -> void:
		draw_rect(Rect2(-28, -28, 56, 56), Color(0.9, 0.88, 0.82, 0.16))
		draw_rect(Rect2(-28, -28, 56, 56), Color(0.9, 0.88, 0.82, 0.55), false, 1.0)
		draw_string(HudStyle.FONT_BOLD, Vector2(-8, 8), letter, HORIZONTAL_ALIGNMENT_CENTER, 16, 24, Color(0.92, 0.9, 0.84, 0.8))
