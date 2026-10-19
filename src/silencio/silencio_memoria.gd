class_name SilencioMemoria
extends SilencioSala

## S7. SALA DE MEMORIA / contemplacion (diseno_E3_silencio.md, seccion 6; "la sala mas cuidada del juego").
## Tras el jefe, por la puerta de la derecha. Estado de CONTEMPLACION (src/core/contemplation_mode.gd): sin
## enemigos, botin, logros, numeros flotantes, contadores ni temporizador; el arma se baja sola y no dispara
## ni hace dash; se camina a ~90 px/s; el HUD se oculta salvo la pausa y "Como buscar ayuda". Sin musica,
## sin narrador. Un cartel al entrar: "Esta sala no es para jugar. Puedes salir cuando quieras."
##
## LA SALA: recinto amplio de piedra gris (28x14 tiles). 24 NICHOS con velas apagadas (12 en el muro norte,
## a los lados del panel, y 12 en el sur) y una mesa larga al centro con 12 LUGARES PARA FLORES. Un panel de
## piedra MUDO en el muro norte, salvo el dato de escala (decision 6 de 9.1; texto fijo, grabado). Sin
## nombres reales ni casos. Un solo boton de interaccion: "Encender vela" (en un nicho) y "Dejar flor" (en la
## mesa).
##  - Vela: el heroe se agacha, enciende y queda quieto 1 s (2 s en total). Cada nicho, una sola vez.
##  - Flor: se apoya y se queda. 12 lugares. Sin contador.
##  - LUZ QUE CRECE: la sala parte en 8% de luz; cada vela suma luz calida (un foco de ~110 px y un tramo del
##    ambiente, con transicion de 3 s). Con las 24 queda ~65%: nunca luz plena.
## Si no enciendes ninguna, nada pasa: la sala sigue y la puerta esta abierta. Nadie queda "incompleto".
##
## EL DATO DE ESCALA (6.3): una sola vez, grabado en el panel, texto fijo sin animacion: cifra de ONU Mujeres
## y UNODC (Femicides in 2024, 25-nov-2025) con sus matices ("mujeres y ninas", "su pareja o un familiar",
## "cerca de"). REVISAR la redaccion con la revisora. Ninguna vela equivale a una persona ni a una cifra.
##
## SALIDA SIN APURO (6.5): la puerta del fondo (derecha) esta abierta desde el inicio, con una luz tenue de
## afuera. Cruzar toma ~19 s a la velocidad lenta (esa es la pausa; no hay espera forzada). Junto a la puerta,
## el panel "Como buscar ayuda" (el universal del reino: SilencioAviso.open_ayuda).
##
## MEMORIAL (7.4): cuando el reino se transforma (Silencio.liberado) la sala NO se borra: queda al fondo de
## la Plaza como "Memorial", con las 24 velas ENCENDIDAS (todas, no solo las del jugador, para no medir
## participacion) y las flores que dejo el jugador. Mantiene las reglas de contemplacion en cada visita.
## Cartel: "Memorial. Entra cuando quieras." El dato sigue grabado.
##
## SONIDO: sin musica; faltan el tono de sala grave, los pasos con eco, el fosforo y la llama, el roce de la
## flor y el gozne (no hay audios adecuados en assets/audio): se deja el silencio. Sin subtitulos aun.

const INTERACTABLE := preload("res://src/items/interactable.gd")
const DIR := "res://assets/sprites/silencio/"
const W := 1792.0
const H := 896.0
const LIGHT_START := 0.08
const LIGHT_FULL := 0.65
const LIGHT_SECS := 3.0
const CANDLE_COUNT := 24
const NORTH_Y := 90.0          # los pies de los nichos del muro norte
const SOUTH_Y := 878.0
const TABLE := Vector2(896, 470)   # centro de la mesa
const TABLE_SIZE := Vector2(416, 40)
const PANEL_TL := Vector2(686, 30)
const PANEL_SIZE := Vector2(420, 132)
const SLOT_X0 := 17.0          # primer lugar de flor (x desde el borde izquierdo de la mesa)
const SLOT_STEP := 34.0
const HELP_AT := Vector2(1690, 330)

var _niches: Array = []     # {pos, spr, light, it, lit}
var _slots: Array = []      # Sprite2D de la flor dejada, o null
var _flower_it: Node = null
var _busy := false
var _lit_n := 0
var _memorial := false
var _halo: PointLight2D = null
var _door_local := Vector2(W, H * 0.5)


func build() -> void:
	_door_local = _find_east_door()
	_niche_row(true)
	_niche_row(false)
	# el panel mudo del muro norte, con el dato grabado
	var panel := sprite("panel_mudo", PANEL_TL, false)
	panel.z_index = 1
	_engrave()
	# una luz suave fija sobre el panel: el dato tiene que poder leerse aunque la sala este casi a oscuras
	var pl := LightKit.make_light(Color(1.0, 0.95, 0.85), 0.55, 2.6, false)
	pl.remove_from_group(LightKit.GROUP_DARK)
	pl.enabled = true
	pl.position = PANEL_TL + PANEL_SIZE * 0.5 + Vector2(0, 40)
	room.props_node.add_child(pl)
	_decor.append(pl)
	# la mesa de las flores y sus 12 lugares
	var t := sprite("mesa_flores", TABLE - Vector2(TABLE_SIZE.x * 0.5, TABLE_SIZE.y * 0.5), false)
	t.z_index = 1
	solid(Rect2(TABLE - TABLE_SIZE * 0.5 + Vector2(0, 6), TABLE_SIZE - Vector2(0, 12)))
	_slots.resize(12)
	_slots.fill(null)
	_flower_it = _interactable(TABLE + Vector2(0, 44.0), 150.0, tr("SIL_MEM_FLOR"), _leave_flower)
	_stone_doors()
	# una luz muy suave sobre la mesa: las flores se tienen que ver aunque la sala este casi a oscuras
	var tl := LightKit.make_light(Color(1.0, 0.92, 0.8), 0.3, 2.2, false)
	tl.remove_from_group(LightKit.GROUP_DARK)
	tl.enabled = true
	tl.position = TABLE
	room.props_node.add_child(tl)
	_decor.append(tl)
	# la luz tenue de afuera, junto a la puerta, y el panel "Como buscar ayuda"
	var out := LightKit.make_light(Color(1.0, 0.92, 0.75), 0.55, 2.4, false)
	out.remove_from_group(LightKit.GROUP_DARK)
	out.enabled = true
	out.position = _door_local + Vector2(-70, 0)
	room.props_node.add_child(out)
	_decor.append(out)
	var sign_ := sprite("panel_ayuda", _door_local + Vector2(-110, -66))
	sign_.z_index = 1
	_interactable(_door_local + Vector2(-110, -42), 70.0, tr("SIL_S6_TELEFONO"), func(): Silencio.ayuda())
	# un foco muy leve sobre el heroe: sin el, con 8% de luz no se veria por donde se camina
	_halo = LightKit.make_light(Color(0.95, 0.93, 1.0), 0.5, 1.15, false)
	_halo.remove_from_group(LightKit.GROUP_DARK)
	_halo.enabled = true


## Las puertas de esta sala no son las de madera del juego: marcos de piedra. La de la derecha, abierta a una
## luz tenue de afuera; la de la izquierda, un hueco oscuro. (Solo se cambia el dibujo: la puerta es la misma.)
func _stone_doors() -> void:
	for d in room.doors.values():
		if d.sprite == null:
			continue
		d.sprite.visible = false
		var horizontal: bool = d.get_direction_name() in ["left", "right"]
		var sz := Vector2(128, 120) if horizontal else Vector2(120, 128)
		var at: Vector2 = d.global_position - room.global_position - sz * 0.5
		var frame := ColorRect.new()
		frame.color = Color("706e70")
		frame.position = at
		frame.size = sz
		frame.z_index = 1
		room.props_node.add_child(frame)
		_decor.append(frame)
		var inner := ColorRect.new()
		inner.color = Color("e2d6b8") if d.get_direction_name() == "right" else Color("1c1b1f")
		inner.position = at + Vector2(10, 10)
		inner.size = sz - Vector2(20, 20)
		inner.z_index = 1
		room.props_node.add_child(inner)
		_decor.append(inner)


## Busca la puerta de la derecha de la sala (local). Si no la halla, el centro del muro este.
func _find_east_door() -> Vector2:
	for d in room.doors.values():
		if d.has_method("get_direction_name") and d.get_direction_name() == "right":
			return d.global_position - room.global_position
	return Vector2(size_px().x, size_px().y * 0.5)


## Una fila de 12 nichos. Norte: 6 a cada lado del panel. Sur: repartidos por todo el muro.
func _niche_row(north: bool) -> void:
	for i in 12:
		var x: float
		if north:
			x = 130.0 + i * 100.0 if i < 6 else 1180.0 + (i - 6) * 100.0
		else:
			x = 150.0 + i * 135.0
		var y := NORTH_Y if north else SOUTH_Y
		var spr := sprite("nicho_apagado", Vector2(x, y))
		spr.z_index = 1
		var light := LightKit.make_light(Color(1.0, 0.8, 0.5), 0.0, 1.0, false)
		light.remove_from_group(LightKit.GROUP_DARK)
		light.enabled = true
		light.position = Vector2(x, y - 24.0 + (14.0 if north else -14.0))
		room.props_node.add_child(light)
		_decor.append(light)
		var idx := _niches.size()
		var it := _interactable(Vector2(x, y + (34.0 if north else -34.0)), 52.0, tr("SIL_MEM_VELA"), func(): _light_candle(idx))
		_niches.append({"pos": Vector2(x, y), "spr": spr, "light": light, "it": it, "lit": false})


## Un Interactable (E) circular. `on_use` se llama al usarlo.
func _interactable(at: Vector2, radius: float, prompt: String, on_use: Callable) -> Node:
	var it := INTERACTABLE.new()
	it.position = at
	it.prompt_text = prompt
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = radius
	it.add_child(shape)
	it.collision_layer = 0
	it.collision_mask = 1
	it.used.connect(func(_p): on_use.call())
	room.props_node.add_child.call_deferred(it)
	_decor.append(it)
	return it


## El dato de escala grabado en el panel (texto fijo, sin animacion, sin sonido). Tres lineas.
func _engrave() -> void:
	var lines := [tr("SIL_MEM_DATO_1"), tr("SIL_MEM_DATO_2"), tr("SIL_MEM_FUENTE")]
	var y := PANEL_TL.y + 16.0
	for k in lines.size():
		var l := HudStyle.pixel_label(lines[k], 14 if k < 2 else 12, Color("e6e0d2") if k < 2 else Color("bcb6aa"))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(PANEL_SIZE.x - 36.0, 0.0)
		l.size = Vector2(PANEL_SIZE.x - 36.0, 0.0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(PANEL_TL.x + 18.0, y)
		l.material = LightKit.unshaded_material()  # un texto grabado: se lee siempre, sin brillo
		l.z_index = 2
		room.props_node.add_child(l)
		_decor.append(l)
		y += (58.0 if k == 0 else 26.0)


# ---------------------------------------------------------------- entrar y salir
func start() -> void:
	pass  # la sala no "arranca" nada: espera


## Cada visita (tambien al volver desde la Plaza): contemplacion, el cartel y, en el Memorial, las velas.
func enter() -> void:
	super()
	ContemplationMode.begin(main)
	if halo_ok():
		_halo.position = Vector2.ZERO
		if _halo.get_parent() != hero():
			if _halo.get_parent() != null:
				_halo.get_parent().remove_child(_halo)
			hero().add_child(_halo)
	if Silencio.liberado and not _memorial:
		_memorial = true
		await get_tree().process_frame  # los Interactable se suman a la sala en diferido (build)
		_become_memorial()
	await get_tree().process_frame
	_restore_flowers()
	Silencio.cartel([tr("SIL_MEM_MEMORIAL") if Silencio.liberado else tr("SIL_MEM_UMBRAL")], 4.0)


func halo_ok() -> bool:
	return _halo != null and is_instance_valid(_halo) and hero() != null


func leave() -> void:
	super()
	ContemplationMode.end(main)
	if halo_ok() and _halo.get_parent() != null:
		_halo.get_parent().remove_child(_halo)
	_busy = false
	var h := hero()
	if h != null:
		h.set_physics_process(true)


# ---------------------------------------------------------------- velas
func _light_candle(i: int) -> void:
	var n: Dictionary = _niches[i]
	if bool(n.lit) or _busy:
		return
	_busy = true
	n.it.finish()
	_crouch(2.0)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	_set_lit(i, 1.4)
	_lit_n += 1
	_update_ambient(LIGHT_SECS)
	await get_tree().create_timer(1.0).timeout
	_busy = false


## El nicho i queda encendido: la vela cambia de dibujo y su luz sube (fade segundos).
func _set_lit(i: int, fade: float) -> void:
	var n: Dictionary = _niches[i]
	n.lit = true
	(n.spr as Sprite2D).texture = SilencioFigura.tex("nicho_encendido")
	var l := n.light as PointLight2D
	if fade <= 0.0:
		l.energy = 0.55
		return
	create_tween().tween_property(l, "energy", 0.55, fade)


## Luz de la sala segun las velas encendidas: de 8% a ~65% con las 24. `secs` = transicion.
func _update_ambient(secs: float) -> void:
	var l := lerpf(LIGHT_START, LIGHT_FULL, float(_lit_n) / CANDLE_COUNT)
	room.set_meta("sil_light", l)
	main._lighting.ambient_secs = secs
	main._lighting.paint(room, false, secs > 0.0)
	main._lighting.ambient_secs = 1.2


## El heroe se agacha y queda quieto `secs` s (sin control; la sala no apura a nadie).
func _crouch(secs: float) -> void:
	var h := hero()
	h.velocity = Vector2.ZERO
	h.set_physics_process(false)
	var spr := h.animated_sprite
	var base := spr.scale
	var tw := create_tween()
	tw.tween_property(spr, "scale:y", base.y * 0.84, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(maxf(secs - 0.8, 0.0))
	tw.tween_property(spr, "scale:y", base.y, 0.4).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if is_instance_valid(h):
		spr.scale = base
		h.set_physics_process(true)


# ---------------------------------------------------------------- flores
func _slot_pos(k: int) -> Vector2:
	return Vector2(TABLE.x - TABLE_SIZE.x * 0.5 + SLOT_X0 + k * SLOT_STEP, TABLE.y - 2.0)


func _put_flower(k: int) -> void:
	var s := Sprite2D.new()
	s.texture = load(DIR + "flor_%d.png" % ((k * 5 + 3) % 12))
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.offset = Vector2(0, -s.texture.get_height() * 0.5)
	s.position = _slot_pos(k)
	s.z_index = 2
	room.props_node.add_child(s)
	_decor.append(s)
	_slots[k] = s


## El heroe apoya una flor en el lugar libre mas cercano y se queda un momento. Sin contador.
func _leave_flower() -> void:
	if _busy:
		return
	var best := -1
	var bd := INF
	var hx := hero().global_position.x - room.global_position.x
	for k in 12:
		if _slots[k] == null and absf(_slot_pos(k).x - hx) < bd:
			bd = absf(_slot_pos(k).x - hx)
			best = k
	if best < 0:
		return
	_busy = true
	_crouch(1.4)
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return
	_put_flower(best)
	Silencio.mem_flowers.append(best)
	if not _slots.has(null) and _flower_it != null:
		_flower_it.finish()
	await get_tree().create_timer(0.7).timeout
	_busy = false


## Las flores que dejo el jugador siguen ahi (tambien al volver desde la Plaza).
func _restore_flowers() -> void:
	for k in Silencio.mem_flowers:
		if _slots[int(k)] == null:
			_put_flower(int(k))
	if not _slots.has(null) and _flower_it != null and is_instance_valid(_flower_it):
		_flower_it.finish()


## Memorial: el reino se transformo. Las 24 velas encendidas (de golpe) y la luz de ~65%.
func _become_memorial() -> void:
	for i in _niches.size():
		if not bool(_niches[i].lit):
			(_niches[i].it as Node).finish()
			_set_lit(i, 0.0)
	_lit_n = CANDLE_COUNT
	_update_ambient(0.0)
