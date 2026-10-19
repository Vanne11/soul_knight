class_name SilencioPasillo
extends SilencioSala

## S6. Agresion: "El pasillo", parte A, "ver y ayudar" (diseno_E3, seccion 3). CAMBIO DE TONO: 3 s de negro
## con el texto "Aqui cambia el tono."; sin musica (el reino no tiene), sin narrador y con la luz al minimo.
## NADA se muestra de la violencia: sin golpes, sin contacto, sin gritos ni respiracion; solo una postura.
##
## Pasillo largo y oscuro. A unos 20 m, dos siluetas sin rostro: una acorrala a la otra contra una pared
## (solo postura: un brazo apoyado en la pared); la otra se hace pequena y evita mirar. Al acercarte
## aparecen tres acciones, sin puntaje y sin "mejor" (SilencioOpciones):
##   - Distraer: te acercas y preguntas la hora; la silueta acorralada gana espacio y camina hacia ti.
##   - Buscar a alguien: apagas un interruptor lejano (queda en el otro extremo) que enciende la luz del
##     pasillo y una luz verde en la salida (alguien viene); la otra silueta se va.
##   - Quedarte cerca despues: la otra silueta ya se fue; te quedas a su lado, a distancia, sin tocarla, y
##     preguntas si quiere que llames a alguien. La respuesta es libre (de ella; el juego no la dirige).
## Cualquier opcion vale. Si no haces nada, el cartel dice que tambien paraliza y que no es tu culpa.
## Sin dano, sin estado de fracaso, sin recompensa. Las senales de agresion y "como buscar ayuda" estan en
## la parte B (silencio_habitacion.gd). NOTA: el diseno pide que en Agresion no haya carteles de NARRADOR
## (el narrador calla); los carteles de acta del reino (SilencioCartel) si se usan, como dice la seccion 3.

const PAIR := Vector2(1440, 236)        # la silueta acorralada, pegada a la pared
const WALL_X := 1472.0
const SWITCH_AT := Vector2(150, 78)     # el interruptor lejano, en el muro del extremo de entrada
const NEAR_R := 250.0
const FREEZE_SECS := 14.0               # sin hacer nada junto a ellas: sale el cartel de "tambien paraliza"
const TONE_SECS := 3.0

var _opts: SilencioOpciones
var _cornered: SilencioFigura
var _other: SilencioFigura
var _lamps: Array = []
var _green: Sprite2D
var _resolved := false
var _nada_done := false
var _near_t := 0.0
var _near_once := false
var _tone: CanvasLayer


func build() -> void:
	# la pared contra la que esta acorralada: un muro bajo, plano, sin detalle
	var wall := ColorRect.new()
	wall.color = Color("3b3b44")
	wall.position = Vector2(WALL_X, 118)
	wall.size = Vector2(22, 232)
	room.props_node.add_child(wall)
	_decor.append(wall)
	solid(Rect2(WALL_X, 118, 22, 232))
	_other = figure("brazo", PAIR + Vector2(-44, 2), Color(0.8, 0.8, 0.86))
	_cornered = figure("encogida", PAIR, Color(0.9, 0.9, 0.96))
	sprite("interruptor", SWITCH_AT)
	for x in [420.0, 900.0, 1380.0]:
		_lamps.append(glow(Vector2(x, 190), 300.0, Color(1.0, 0.92, 0.7)))
	_green = glow(Vector2(1610, 190), 90.0, Color(0.5, 1.0, 0.6))


func start() -> void:
	_opts = SilencioOpciones.create(main)
	_play_tone()


func stop() -> void:
	if _opts != null:
		_opts.clear()
	if _near_once and not _resolved and not _nada_done:
		_nada_done = true
		Silencio.cartel([tr("SIL_S6_NADA")], 6.0)  # (aparece en la sala que sigue)


func _exit_tree() -> void:
	for n in [_opts, _tone]:
		if n != null and is_instance_valid(n):
			n.queue_free()


## 3 s de negro con "Aqui cambia el tono." El heroe espera quieto; sin narrador ni sonido.
func _play_tone() -> void:
	_tone = CanvasLayer.new()
	_tone.layer = 70
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tone.add_child(black)
	var l := HudStyle.pixel_label(tr("SIL_S6_TONO"), 28, Color("e4e0d8"))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	black.add_child(l)
	main.add_child(_tone)
	hero().velocity = Vector2.ZERO
	hero().set_physics_process(false)
	var tw := create_tween()
	tw.tween_interval(TONE_SECS - 0.5)
	tw.tween_property(black, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		if is_instance_valid(hero()):
			hero().set_physics_process(true)
		if is_instance_valid(_tone):
			_tone.queue_free())


func _process(delta: float) -> void:
	if not inside or _opts == null or _tone != null and is_instance_valid(_tone):
		return
	var hp := hero().global_position - room.global_position
	var near := hp.distance_to(PAIR) < NEAR_R
	if near and not _resolved:
		_near_once = true
		_opts.set_items([
			{"text": tr("SIL_S6_DISTRAER"), "cb": _distract},
			{"text": tr("SIL_S6_BUSCAR"), "cb": _find_someone},
			{"text": tr("SIL_S6_QUEDAR"), "cb": _stay_close}])
		_near_t += delta
		if _near_t >= FREEZE_SECS and not _nada_done:
			_nada_done = true
			Silencio.cartel([tr("SIL_S6_NADA")], 6.0)
	else:
		_opts.clear()


func _say_at(pos: Vector2, key: String, secs := 3.0) -> void:
	say(pos + Vector2(0, -58), tr(key), secs)


func _hero_local() -> Vector2:
	return hero().global_position - room.global_position


## Se cierra la situacion: se quitan las opciones y sale la frase de como ayudar (sin premio).
func _resolve(delay: float) -> void:
	_resolved = true
	_opts.clear()
	await get_tree().create_timer(delay).timeout
	if inside:
		Silencio.cartel([tr("SIL_S6_AYUDAR")], 7.0)


func _distract() -> void:
	_resolve(5.0)
	await Silencio.carry(hero(), to_world(PAIR + Vector2(-96, 58)), 0.9)
	_say_at(_hero_local(), "SIL_S6_HORA", 3.0)
	await get_tree().create_timer(1.4).timeout
	if not inside:
		return
	# la silueta acorralada gana espacio y camina hacia ti
	create_tween().tween_property(_cornered, "position", _hero_local() + Vector2(34, 2), 2.4).set_trans(Tween.TRANS_SINE)


func _find_someone() -> void:
	_resolve(9.0)
	await Silencio.carry(hero(), to_world(SWITCH_AT + Vector2(0, 62)), 2.4)
	if not inside:
		return
	set_light(0.72)
	for g in _lamps:
		fade_glow(g, 0.55, 2.0)
	fade_glow(_green, 0.9, 2.0)  # alguien viene: luz verde en la salida
	_other_leaves()


## La otra silueta se va por el pasillo, despacio, y se pierde en la sala.
func _other_leaves() -> void:
	var tw := create_tween()
	tw.tween_property(_other, "position:x", 900.0, 6.0)
	tw.tween_property(_other, "modulate:a", 0.0, 1.2)
	tw.tween_callback(_other.hide)


func _stay_close() -> void:
	_resolve(8.0)
	_other_leaves()  # "despues": la otra silueta ya se fue
	await Silencio.carry(hero(), to_world(PAIR + Vector2(-74, 52)), 1.1)
	await get_tree().create_timer(1.6).timeout
	if not inside:
		return
	_say_at(_hero_local(), "SIL_S6_LLAMAR", 3.4)
	await get_tree().create_timer(3.2).timeout
	if inside:
		_say_at(_cornered.position, "SIL_S6_RESP_SI" if randf() < 0.5 else "SIL_S6_RESP_NO", 3.0)
