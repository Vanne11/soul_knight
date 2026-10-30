class_name Arcoiria
extends RefCounted

## ARCOIRIA (nombre provisorio): el reino del Orgullo, reino de la RUTA con dos pisos (region
## "arcoiria", assets/data/floors/70_arcoiria.json y 75_arcoiria_profunda.json) y el jefe "La
## Censura que destine". Ganchos estaticos que llama main.gd; todo lo demas vive en src/arcoiria/,
## src/enemies/arcoiria/ y src/enemies/bosses/boss_destine.gd. Textos: locale/arcoiria.csv (ARC_*).
##
## LA BANDERA: cada sala que liberas suma una franja nueva (rojo, naranja, amarillo, verde, azul,
## violeta, en ese orden) como si se armara la bandera: una franja de color cruza el suelo de la sala
## (ArcoiriaBand) y se enciende en el contador del HUD (ArcoiriaFlag). La franja de cada color
## trae su PODER (assets/data/items/bandera_<color>.tres, efectos en ArcoiriaPowers); con las seis,
## la sinergia "Bandera completa" (Synergies.TABLE). El avance dura toda la partida (los dos pisos).
##
## EVENTOS DE CODICE (LoreDatabase.custom_event): reino_orgullo_entrada (al pisar el reino; abre
## las 11 entradas de hitos y conceptos; las 10 banderas se ENCUENTRAN: src/arcoiria/banderas.gd) y orgullo_vencido_<id> al vencer a cada
## enemigo-prejuicio: es_una_fase, el_armario, quien_es_el_hombre, la_etiqueta.

const REGION := "arcoiria"
const MAX_STRIPES := 6
## franja -> {id, color de la franja, color mas claro, objeto del poder}
const STRIPES := [
	{"id": "rojo", "color": Color("e84048"), "light": Color("ff8a8a"), "item": "bandera_rojo"},
	{"id": "naranja", "color": Color("ff9630"), "light": Color("ffc880"), "item": "bandera_naranja"},
	{"id": "amarillo", "color": Color("ffd640"), "light": Color("fff4a0"), "item": "bandera_amarillo"},
	{"id": "verde", "color": Color("4ebe60"), "light": Color("a0eb96"), "item": "bandera_verde"},
	{"id": "azul", "color": Color("4082e6"), "light": Color("8cbeff"), "item": "bandera_azul"},
	{"id": "violeta", "color": Color("9660dc"), "light": Color("c8a0fa"), "item": "bandera_violeta"},
]
const FLAG_GROUP := "arc_flag"

## Salas liberadas en esta partida (cuenta las de los dos pisos). Se reinicia al empezar partida.
static var liberated := 0
## Enemigos-prejuicio ya vencidos en esta partida (para no repetir el aviso de la verdad).
static var _told := {}
static var _run_stamp := -1.0


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _rm() -> Node:
	return _tree().root.get_node("RunManager")


static func is_arcoiria() -> bool:
	return str(_rm().floor_data().get("region", "")) == REGION


## Reinicia lo de la partida anterior (cada partida marca su inicio en RunManager.run_start_time).
static func _sync_run() -> void:
	var stamp := float(_rm().run_start_time)
	if stamp != _run_stamp:
		_run_stamp = stamp
		liberated = 0
		_told.clear()


static func stripe(i: int) -> Dictionary:
	return STRIPES[posmod(i, MAX_STRIPES)]


static func power_ids() -> Array:
	return STRIPES.map(func(s): return s.item)


## Cuantas franjas (poderes) tienes de verdad en la bandera del HUD (0..6).
static func stripes_lit() -> int:
	return mini(liberated, MAX_STRIPES)


static func _lore(event: String) -> void:
	_tree().root.get_node("LoreDatabase").custom_event(event)


# ------------------------------------------------------------------ ganchos de main.gd
## Al terminar de generar un piso (main._generate_dungeon).
static func setup_floor(main: Node) -> void:
	_sync_run()
	for old in _tree().get_nodes_in_group(FLAG_GROUP):
		old.queue_free()
	if not is_arcoiria():
		ArcoiriaPowers.ensure(main.player, false)  # los poderes que traes de Arcoiria siguen contigo
		return
	_lore("reino_orgullo_entrada")
	var flag := ArcoiriaFlag.new()
	flag.add_to_group(FLAG_GROUP)
	main.add_child(flag)
	flag.set_lit(stripes_lit(), false)
	ArcoiriaPowers.ensure(main.player, true)


## main._on_room_cleared: la sala liberada suma su franja de la bandera.
static func on_room_cleared(main: Node, room: Room) -> void:
	var pw := main.player.get_node_or_null("ArcoiriaPowers") as ArcoiriaPowers
	if pw != null:
		pw.room_freed()  # rojo y azul: curan / dan escudo al liberar sala, en cualquier reino
	if not is_arcoiria() or room.room_type == Room.RoomType.BOSS or room.has_meta("arc_stripe"):
		return
	_sync_run()
	var idx := liberated
	var s := stripe(idx)
	liberated += 1
	room.set_meta("arc_stripe", idx)
	ArcoiriaBand.build(room, idx)
	var color: Color = s.color
	var ge := _tree().root.get_node("GlobalEvents")
	ge.show_floating_text.emit(main.player.global_position + Vector2(0, -52), Loc.tr_or("ARC_STRIPE_%s" % str(s.id).to_upper(), str(s.id)), color)
	Sound.play("puzzle_solve")
	for f in _tree().get_nodes_in_group(FLAG_GROUP):
		f.set_lit(stripes_lit(), true)
	if idx < MAX_STRIPES:
		# el poder de esa franja cae en la sala recien liberada
		main._spawn_pickup(room, str(s.item), room.get_center_position() + Vector2(0, 44))
		Narrator.say_first("arcoiria_franja")
	if liberated == MAX_STRIPES:
		Narrator.say_first("arcoiria_bandera")
		ge.show_floating_text.emit(main.player.global_position + Vector2(0, -74), Loc.tr_or("ARC_FLAG_COMPLETE", "¡BANDERA COMPLETA!"), Color("fff1c4"))


# ------------------------------------------------------------------ rincon de ayuda
## Cartel del arcoiris en la sala de inicio del reino: abre la entrada "Como buscar ayuda" del
## codice (assets/data/lore/como_buscar_ayuda.tres), universal y siempre opcional.
static func on_enter_room(main: Node, room: Room) -> void:
	if not is_arcoiria() or room.room_type != Room.RoomType.START or room.has_meta("arc_ayuda"):
		return
	room.set_meta("arc_ayuda", true)
	var sign_node := Node2D.new()
	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([Vector2(-3, -34), Vector2(3, -34), Vector2(3, 18), Vector2(-3, 18)])
	post.color = Color("6b4a2e")
	sign_node.add_child(post)
	var board := Polygon2D.new()
	board.polygon = PackedVector2Array([Vector2(-22, -52), Vector2(22, -52), Vector2(22, -26), Vector2(-22, -26)])
	board.color = Color("f4ecd8")
	sign_node.add_child(board)
	for i in MAX_STRIPES:
		var band := Polygon2D.new()
		var y := -52.0 + i * 4.3
		band.polygon = PackedVector2Array([Vector2(-22, y), Vector2(22, y), Vector2(22, y + 4.3), Vector2(-22, y + 4.3)])
		band.color = (STRIPES[i].color as Color)
		band.modulate = Color(1, 1, 1, 0.9)
		sign_node.add_child(band)
	var heart := Label.new()
	heart.text = "?"
	heart.add_theme_font_size_override("font_size", 14)
	heart.add_theme_color_override("font_color", Color("3a2a4a"))
	heart.position = Vector2(-4, -50)
	board.add_child(heart)
	sign_node.set_meta("foot", 18.0)
	sign_node.set_meta("half_w", 8.0)
	sign_node.set_meta("tall", true)
	sign_node.set_meta("top", -52.0)
	var pos := room.get_center_position() + Vector2(-150, 30)
	Consultorio._prop(main, room, pos, sign_node,
		func(): return Loc.tr_or("EDU_AYUDA_PROMPT", "Cartel: ¿dónde buscar ayuda?"),
		func(_p, _it): _leer_ayuda(), true)


## Abre (si hiciera falta) y muestra la entrada de codice "Como buscar ayuda". Sin limite de usos.
static func _leer_ayuda() -> void:
	var lore := _tree().root.get_node("LoreDatabase")
	lore.unlock_entry("como_buscar_ayuda")
	var entry = lore.get_entry("como_buscar_ayuda")
	if entry == null:
		return
	Sound.play("puzzle_solve")
	Narrator.say_raw(Loc.tr_or("EDU_AYUDA_SAY", "%s: %s") % [Loc.lore_title(entry), Loc.lore_text(entry)])


# ------------------------------------------------------------------ enemigos-prejuicio
## Burbuja sobre el enemigo con el texto ARC_<CLAVE> (con %s opcional). Usa la burbuja de la IA si hay.
static func say(e: Node, key: String, secs := 2.0) -> void:
	var txt := Loc.tr_or("ARC_" + key.to_upper(), key)
	var ge := _tree().root.get_node("GlobalEvents")
	ge.show_floating_text.emit((e as Node2D).global_position + Vector2(0, -52), txt, Color("ffe08a"))


## Un prejuicio cae: abre su entrada del codice y, la primera vez de la partida, dice la verdad corta
## (aviso del narrador + texto flotante). id: es_una_fase | el_armario | quien_es_el_hombre | la_etiqueta.
static func vencido(e: Node, id: String) -> void:
	_sync_run()
	_lore("orgullo_vencido_" + id)
	if _told.has(id):
		return
	_told[id] = true
	var up := id.to_upper()
	var ge := _tree().root.get_node("GlobalEvents")
	ge.show_floating_text.emit((e as Node2D).global_position + Vector2(0, -44), Loc.tr_or("ARC_VENCIDO", "PREJUICIO ROTO"), Color("7fe0a0"))
	Narrator.toast(Loc.tr_or("ARC_VERDAD_TITULO", "LA VERDAD"), Loc.tr_or("ARC_VERDAD_" + up, id), "7fe0a0")


## Anillo de color que se expande (efecto de espinas, etiquetas rotas...). Se borra solo.
static func ring(at: Vector2, color: Color, radius: float, secs := 0.45) -> void:
	var main := _tree().get_first_node_in_group("main")
	if main == null:
		return
	var r := ArcoiriaRing.new()
	r.color = color
	r.radius = radius
	r.secs = secs
	main.add_child(r)
	r.global_position = at


## Daño a los enemigos vivos en un radio. Devuelve cuantos tocó.
static func burst(at: Vector2, radius: float, amount: float, source: Node = null) -> int:
	var n := 0
	for e in _tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D) or e.is_queued_for_deletion():
			continue
		if float(e.get("current_health")) <= 0.0:
			continue
		if (e as Node2D).global_position.distance_to(at) <= radius and e.has_method("take_damage"):
			e.take_damage(amount, source, Vector2.ZERO)
			n += 1
	return n


## El dash rompe las etiquetas pegadas: cada una explota en un anillo que hace dano extra.
static func rip_labels(player: Node2D, n: int) -> void:
	var pos := player.global_position
	var dmg := 16.0 * n * float(_tree().root.get_node("PlayerStats").damage_modifier)
	ring(pos, Color("ffd23a"), 70.0 + 22.0 * n, 0.4)
	burst(pos, 70.0 + 22.0 * n, dmg, player)
	_tree().root.get_node("GlobalEvents").show_floating_text.emit(pos + Vector2(0, -40), Loc.tr_or("ARC_ETIQUETAS_ROTAS", "¡ETIQUETAS ROTAS!"), Color("ffd23a"))
	Sound.play("crack")
