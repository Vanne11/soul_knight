class_name SilencioTurno
extends SilencioSala

## S1. Micromachismos 1: "Turno" (diseno_E3, seccion 3). Una mesa larga, 6 siluetas sentadas y tu en un
## extremo, con una barra de VOZ bajo el heroe. Manten "hablar" (interactuar) junto a tu silla: aparece
## tu idea y la barra se llena (2.5 s).
##   Intentos 1-3: una silueta te interrumpe a mitad (en un punto distinto cada vez), tu burbuja se corta
##   y habla ella; luego otra silueta dice tu idea con otras palabras y la mesa responde "Buena idea".
##   Tu burbuja original queda tachada.
##   Intento 4: sale completo; la mesa espera y asiente. Sin premio.
## El patron es fijo: insistir no cambia nada. Sin dano, sin recompensa, sin fracaso. Al cerrar el 4.o
## intento: cartel final y entrada de codice "micromachismo" (evento silencio_turno).

const SEAT := Vector2(284, 346)       # donde hablas (extremo izquierdo de la mesa)
const TABLE := Rect2(332, 316, 256, 48)
const SPEAK_TIME := 2.5               # s con la tecla apretada para llenar la barra
const SPEAK_RANGE := 70.0
## Punto de la barra (0..1) donde te cortan cada uno de los 3 primeros intentos.
const CUT_AT := [0.36, 0.58, 0.8]
## Quien te interrumpe y quien repite tu idea en cada intento (indices de _seats).
const INTERRUPTER := [1, 4, 0]
const REPEATER := [3, 2, 5]
const SEAT_POS := [Vector2(372, 326), Vector2(460, 326), Vector2(548, 326),     # frente a ti, tras la mesa
	Vector2(408, 398), Vector2(516, 398),                                          # de espaldas, de este lado
	Vector2(624, 368)]                                                             # cabecera
const SEAT_POSE := ["sentada", "sentada", "sentada", "espalda", "espalda", "sentada"]
## Un tono apenas distinto por silueta (ninguna es igual a otra, ninguna tiene rasgos).
const TINTS := [Color(0.96, 0.96, 1.0), Color(0.88, 0.9, 0.96), Color(1, 1, 1), Color(0.92, 0.92, 0.98), Color(0.98, 0.96, 0.96), Color(0.9, 0.9, 0.94)]

var _seats: Array = []
var _attempt := 0
var _hold := 0.0
var _busy := false
var _bubble: SilencioBurbuja = null
var _bubbles: Array = []
var _voz: SilencioVoz = null


func build() -> void:
	sprite("silla", SEAT + Vector2(0, 8))
	for p in SEAT_POS:
		sprite("silla", p + Vector2(0, 8))
	_seats.resize(SEAT_POS.size())
	for i in [0, 1, 2, 5]:  # tras la mesa y en la cabecera: la mesa tapa un poco a los de enfrente
		_seats[i] = figure(SEAT_POSE[i], SEAT_POS[i], TINTS[i])
	sprite("mesa_larga", TABLE.position, false)
	solid(Rect2(TABLE.position + Vector2(0, 6), TABLE.size - Vector2(0, 14)))
	for i in [3, 4]:  # de este lado, de espaldas: se dibujan sobre la mesa
		_seats[i] = figure(SEAT_POSE[i], SEAT_POS[i], TINTS[i])


func start() -> void:
	_voz = SilencioVoz.new()
	_voz.target = hero()
	add_child(_voz)


func stop() -> void:
	_clear_bubbles()
	_hold = 0.0
	_busy = false
	if _voz != null:
		_voz.value = 0.0


func _process(delta: float) -> void:
	if not inside or _voz == null:
		return
	var near := hero_near(SEAT, SPEAK_RANGE)
	Silencio.hint(tr("SIL_S1_HINT") if near and not _busy else "")
	if _busy:
		_follow_hero()
		return
	if near and Input.is_action_pressed("interact"):
		_hold = minf(_hold + delta / SPEAK_TIME, 1.0)
		_show_idea()
		if _attempt < CUT_AT.size() and _hold >= CUT_AT[_attempt]:
			_interrupted()
		elif _hold >= 1.0:
			_said_it_all()
	else:
		_hold = maxf(0.0, _hold - delta * 1.6)
		if _hold <= 0.0 and _bubble != null:
			_clear_bubbles()
	_voz.value = _hold
	_follow_hero()


func _follow_hero() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.hang_over(hero().global_position - room.global_position + Vector2(0, -34))


func _show_idea() -> void:
	if _bubble == null or not is_instance_valid(_bubble):
		_bubble = SilencioBurbuja.create(tr("SIL_S1_IDEA"))
		_bubble.z_index = 3
		room.props_node.add_child(_bubble)
		_bubbles.append(_bubble)
		_bubble.label.visible_characters = 0
	_bubble.label.visible_ratio = _hold


func _clear_bubbles() -> void:
	for b in _bubbles:
		if is_instance_valid(b):
			b.queue_free()
	_bubbles.clear()
	_bubble = null


func _head(i: int) -> Vector2:
	return SEAT_POS[i] + Vector2(0, -40)


## Te cortan: tu burbuja queda a medias, habla otra silueta y una tercera dice tu idea con otras palabras.
func _interrupted() -> void:
	_busy = true
	var k := _attempt
	_attempt += 1
	Silencio.hint("")
	var idea := tr("SIL_S1_IDEA")
	_bubble.label.visible_ratio = 1.0
	_bubble.label.text = idea.substr(0, int(idea.length() * _hold)).strip_edges() + "—"
	_voz.cut = 1.0
	_hold = 0.0
	var mine := _bubble
	if not await wait(0.7):
		return
	_bubbles.append(say(_head(INTERRUPTER[k]), tr("SIL_S1_CORTA_%d" % (k + 1)), 0.0))
	if not await wait(2.4):
		return
	_bubbles.append(say(_head(REPEATER[k]), tr("SIL_S1_REPITE_%d" % (k + 1)), 0.0))
	if not await wait(1.5):
		return
	for i in 2:
		_bubbles.append(say(_head((REPEATER[k] + 1 + i * 2) % 6), tr("SIL_S1_BUENA"), 0.0))
	if is_instance_valid(mine):
		mine.strike()
	if not await wait(2.6):
		return
	_clear_bubbles()
	_voz.value = 0.0
	_busy = false


## Cuarto intento (y los siguientes): sale completo; la mesa espera y asiente. Sin premio.
func _said_it_all() -> void:
	_busy = true
	_attempt = maxi(_attempt, CUT_AT.size() + 1)
	Silencio.hint("")
	if not await wait(1.4):
		return
	for f in _seats:
		f.nod()
	if not await wait(2.2):
		return
	_clear_bubbles()
	_hold = 0.0
	_voz.value = 0.0
	_busy = false
	conclude([tr("SIL_S1_CARTEL_1"), tr("SIL_S1_CARTEL_2"), tr("SIL_S1_CARTEL_3")], "silencio_turno")
