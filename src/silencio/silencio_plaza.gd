class_name SilencioPlaza
extends SilencioSala

## PLAZA DE LA PALABRA: el reino ya transformado, "LAS TIERRAS DE LA VOZ" (nombre provisorio; diseno_E3,
## seccion 7). Se llega cruzando la puerta de la sala de memoria: la transformacion nace del jefe vencido,
## no de las velas (7.1). Al entrar se marca Silencio.liberado: la luz de todo el reino pasa a calida.
##
## COMO SE VE (7.2): paleta calida (ocre, azul pizarra suave, verde), una fila de faroles encendidos, y las
## siluetas AHORA CON CARA SIMPLE, de generos y tamanos distintos (fig_cara_*). Provisorio: falta bajar los
## muros y el cielo claro (la geometria de las salas es la de siempre).
##
## COMO SE JUEGA (7.3, lo inverso de S1-S4), sin combate:
##  - "Turno": manten [E] junto a tu banco para hablar; la barra de VOZ se llena SIN interrupciones y las
##    siluetas esperan (asienten). Al terminar ceden el turno a otras dos siluetas y TU ESPERAS (se aprende
##    a esperar, no solo a hablar). ~15-20 s, opcional, se puede repetir.
##  - Las Voces (las siluetas liberadas del Pacto, cada una con su luz) dicen una frase corta al acercarte.
##  - Una FUENTE que cura (vida y estamina, una vez), como en otros reinos liberados. Sin recompensa tematica.
##  - La puerta del lado izquierdo vuelve a la sala de memoria, que aqui es el MEMORIAL (cartel al lado de la
##    puerta). Las velas encendidas y las flores se conservan (silencio_memoria.gd).
##  - La salida (portal al siguiente piso) esta abierta desde el inicio.
## El humor vuelve suave y nunca sobre el tema: por ahora no hay chistes (pendiente).
##
## SONIDO: sin musica por ahora; faltan el coro suave de fondo y el murmullo (no hay audios adecuados).

const INTERACTABLE := preload("res://src/items/interactable.gd")
const SEAT := Vector2(768, 560)
const SPEAK_TIME := 2.5
const SPEAK_RANGE := 80.0
const FOUNTAIN := Vector2(768, 340)
const EXIT_AT := Vector2(540, 30)   # relativo al centro de la sala
const BENCHES := [Vector2(768, 196), Vector2(590, 262), Vector2(946, 262), Vector2(540, 420), Vector2(996, 420), Vector2(768, 560)]
## [cara, posicion, frase de la Voz]: de pie junto a los bancos
const VOICES := [
	[0, Vector2(738, 176), "SIL_LIB_VOZ_1"], [1, Vector2(800, 178), "SIL_LIB_VOZ_2"],
	[2, Vector2(560, 242), "SIL_LIB_VOZ_3"], [3, Vector2(976, 244), "SIL_LIB_VOZ_1"],
	[4, Vector2(508, 400), "SIL_LIB_VOZ_2"], [5, Vector2(1030, 402), "SIL_LIB_VOZ_3"],
]
const VOICE_RADIUS := 90.0

var _faces: Array = []
var _voz: SilencioVoz = null
var _hold := 0.0
var _busy := false
var _bubble: SilencioBurbuja = null
var _voice_cd: Array = []


func build() -> void:
	for b in BENCHES:
		sprite("banco_plaza", b)
		solid(Rect2(b.x - 48, b.y - 16, 96, 12))
	for v in VOICES:
		var f := figure("cara_%d" % int(v[0]), v[1])
		f.z_index = 1
		_faces.append(f)
		_voice_cd.append(0.0)
		var l := LightKit.make_light(Color(1.0, 0.88, 0.6), 0.55, 1.1, false)  # cada Voz con su luz
		l.remove_from_group(LightKit.GROUP_DARK)
		l.enabled = true
		l.position = Vector2(0, -26)
		f.add_child(l)
	var fountain := sprite("fuente", FOUNTAIN)
	fountain.z_index = 1
	solid(Rect2(FOUNTAIN.x - 44, FOUNTAIN.y - 26, 88, 30))
	_fountain_interactable()
	# la fila de faroles, encendidos
	for k in 8:
		var p := Vector2(150.0 + k * 175.0, 96.0)
		sprite("farol", p).z_index = 1
		var l := LightKit.make_light(Color(1.0, 0.9, 0.65), 0.6, 1.5, false)
		l.remove_from_group(LightKit.GROUP_DARK)
		l.enabled = true
		l.position = p + Vector2(0, -50)
		room.props_node.add_child(l)
		_decor.append(l)
	_memorial_sign()


func _fountain_interactable() -> void:
	var it := INTERACTABLE.new()
	it.position = FOUNTAIN + Vector2(0, 40)
	it.prompt_text = tr("SIL_LIB_FUENTE")
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 70.0
	it.add_child(shape)
	it.collision_layer = 0
	it.collision_mask = 1
	it.used.connect(func(_p):
		var ps := get_node("/root/PlayerStats")
		ps.heal(ps.max_health)  # como la fuente de otros reinos liberados
		ps.current_stamina = ps.max_stamina
		ps.stamina_changed.emit(ps.current_stamina, ps.max_stamina)
		Silencio.cartel([tr("SIL_LIB_FUENTE_OK")], 2.5)
		it.finish())
	room.props_node.add_child.call_deferred(it)
	_decor.append(it)


## Cartel junto a la puerta izquierda: lo que hay al otro lado es el Memorial.
func _memorial_sign() -> void:
	var door := Vector2(0, size_px().y * 0.5)
	for d in room.doors.values():
		if d.has_method("get_direction_name") and d.get_direction_name() == "left":
			door = d.global_position - room.global_position
	var l := HudStyle.pixel_label(tr("SIL_MEM_MEMORIAL"), 12, Color("3a3238"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(150.0, 0.0)
	l.size = Vector2(150.0, 0.0)
	l.position = door + Vector2(70, -92)
	l.material = LightKit.unshaded_material()
	l.z_index = 2
	room.props_node.add_child(l)
	_decor.append(l)


func enter() -> void:
	Silencio.set_liberado(main)  # el reino ya cambio (7.1)
	super()
	if _voz == null:
		_voz = SilencioVoz.new()
		_voz.target = hero()
		add_child(_voz)


func start() -> void:
	main.open_exit(room, int(get_node("/root/RunManager").current_floor), EXIT_AT, tr("SIL_LIB_SALIDA"))
	Silencio.cartel([tr("SIL_LIB_PLAZA")], 3.0)


func stop() -> void:
	_clear_bubble()
	_hold = 0.0
	_busy = false
	if _voz != null:
		_voz.value = 0.0


func _process(delta: float) -> void:
	if not inside or _voz == null:
		return
	_voices_near(delta)
	var near := hero_near(SEAT, SPEAK_RANGE)
	Silencio.hint(tr("SIL_LIB_PLAZA_HINT") if near and not _busy else "")
	if _busy:
		_follow_hero()
		return
	if near and Input.is_action_pressed("interact"):
		_hold = minf(_hold + delta / SPEAK_TIME, 1.0)
		_show_idea()
		if _hold >= 1.0:
			_turn_done()
	else:
		_hold = maxf(0.0, _hold - delta * 1.6)
		if _hold <= 0.0:
			_clear_bubble()
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
		_bubble.label.visible_characters = 0
	_bubble.label.visible_ratio = _hold


func _clear_bubble() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null


## Tu idea sale completa, sin que nadie la corte: las siluetas asienten, ceden el turno a otras dos y esperas.
func _turn_done() -> void:
	_busy = true
	Silencio.hint("")
	if not await wait(1.2):
		return
	for f in _faces:
		f.nod(1)
	if not await wait(1.6):
		return
	_clear_bubble()
	_voz.value = 0.0
	Silencio.cartel([tr("SIL_LIB_CEDER")], 3.0)
	var order := [0, 1, 2, 3, 4, 5]
	order.shuffle()
	for k in 2:
		var i: int = order[k]
		var b := say(VOICES[i][1] - Vector2(0, 20), tr(VOICES[i][2]), 3.2)
		Silencio.hint(tr("SIL_LIB_ESPERA"))  # tu esperas
		if not await wait(4.2):
			if is_instance_valid(b):
				b.queue_free()
			return
	Silencio.hint("")
	_hold = 0.0
	_busy = false


## Una Voz dice su frase corta cuando te acercas (con enfriamiento).
func _voices_near(delta: float) -> void:
	for i in VOICES.size():
		_voice_cd[i] = maxf(0.0, float(_voice_cd[i]) - delta)
		if _busy or float(_voice_cd[i]) > 0.0:
			continue
		if hero_near(VOICES[i][1], VOICE_RADIUS):
			_voice_cd[i] = 14.0
			say(VOICES[i][1] - Vector2(0, 20), tr(VOICES[i][2]), 3.0)
