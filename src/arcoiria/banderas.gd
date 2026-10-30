class_name Banderas
extends RefCounted

## MAPA DE LAS BANDERAS (Nico 2026-10-29): las 10 banderas del Orgullo (entradas de codice categoria
## ORGULLO, assets/data/lore/bandera_*.tres) ya no se abren todas al entrar a Arcoiria: cada una es una
## BANDERA PERDIDA que hay que encontrar por los reinos. setup_floor (main._generate_dungeon) esconde a
## veces una en una sala del piso (siempre en Arcoiria; en el resto con CHANCE), elegida al azar entre las
## que faltan: ninguna bandera va atada a un reino del cuerpo (seria asociar identidades con organos).
## Al recogerla: su entrada del codice (evento "bandera_hallada_<id>") y el reino donde aparecio
## (Medallas.anotar_bandera). Con las 10: medalla "banderas_todas" ({"tipo": "banderas"}).
## La seccion "Mapa de las banderas" del codice (src/ui/flag_album.gd) muestra las encontradas y las que faltan.
## "Encontrada" = recogida en el mundo (Medallas guarda el reino), NO la entrada del codice abierta: las
## partidas de antes abrieron las 10 al entrar a Arcoiria y asi tambien tienen que buscarlas (el codice se queda).
## Ni en el Silencio (sin premios) ni en los tramos en paz.

const IDS := ["bandera_arcoiris", "bandera_progress", "bandera_trans", "bandera_bi", "bandera_lesbica",
	"bandera_pan", "bandera_asexual", "bandera_nobinaria", "bandera_intersex", "bandera_intersex_inclusiva"]
## Probabilidad de que un piso fuera de Arcoiria esconda una bandera.
const CHANCE := 0.35
## Salas donde prefiere esconderse (si el piso no tiene ninguna, va a una de combate).
const HIDING := [Room.RoomType.SECRET, Room.RoomType.TREASURE, Room.RoomType.LORE, Room.RoomType.PUZZLE, Room.RoomType.REST]


static func _lore_db() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("LoreDatabase")


static func is_found(id: String) -> bool:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Medallas").bandera_donde(id) != ""


static func found() -> Array:
	return IDS.filter(func(id): return is_found(id))


static func setup_floor(main: Node) -> void:
	if Silencio.active():
		return
	var pending: Array = IDS.filter(func(id): return not is_found(id))
	if pending.is_empty():
		return
	var rm = main.get_node("/root/RunManager")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([rm.current_seed, rm.current_floor, "banderas"])
	if not Arcoiria.is_arcoiria() and rng.randf() >= CHANCE:
		return
	var rooms: Array = main.dungeon_generator.rooms.values()
	var spots: Array = rooms.filter(func(r): return r.room_type in HIDING)
	if spots.is_empty():
		spots = rooms.filter(func(r): return r.room_type == Room.RoomType.COMBAT)
	if spots.is_empty():
		return
	# en Arcoiria, la primera que falta es la del arcoiris (la bandera del reino)
	var id: String = "bandera_arcoiris" if Arcoiria.is_arcoiria() and "bandera_arcoiris" in pending \
		else pending[rng.randi_range(0, pending.size() - 1)]
	var room: Room = spots[rng.randi_range(0, spots.size() - 1)]
	var pos := room.get_center_position() + Vector2(rng.randf_range(90.0, 150.0) * (1 if rng.randf() < 0.5 else -1), -80)
	var region: String = rm.floor_region(rm.current_floor)
	main._add_prop(room, pos, _visual(id), tr_static("FLAG_PICK_PROMPT"), func(_p, it):
		it.finish()
		it.queue_free()
		_pick(main, id, region))


static func _pick(main: Node, id: String, region: String) -> void:
	main.get_node("/root/Medallas").anotar_bandera(id, region)  # antes del codice: la medalla mira el total al abrirse
	_lore_db().custom_event("bandera_hallada_" + id.trim_prefix("bandera_"))
	Sound.play("puzzle_solve")
	var e = _lore_db().get_entry(id)
	var name: String = Loc.lore_title(e) if e else id
	var n := found().size()
	main.get_node("/root/GlobalEvents").show_floating_text.emit(main.player.global_position + Vector2(0, -52), name, Color("ffd640"))
	if n >= IDS.size():
		Narrator.toast(tr_static("FLAG_MAP_DONE_TITLE"), tr_static("FLAG_MAP_DONE_BODY"), "ff4f9a")
	else:
		Narrator.toast(tr_static("FLAG_FOUND_TITLE") % name, tr_static("FLAG_FOUND_BODY") % [n, IDS.size()], "ffd640")


## Mastil con la bandera (el sprite de su entrada del codice) que flamea suave.
static func _visual(id: String) -> Node2D:
	var root := Node2D.new()
	root.set_meta("tall", true)
	var pole := Polygon2D.new()
	pole.color = Color("8a6a48")
	pole.polygon = PackedVector2Array([Vector2(-2, -64), Vector2(2, -64), Vector2(2, 12), Vector2(-2, 12)])
	root.add_child(pole)
	var knob := Polygon2D.new()
	knob.color = Color("f0c04a")
	knob.polygon = PackedVector2Array([Vector2(-4, -70), Vector2(4, -70), Vector2(4, -63), Vector2(-4, -63)])
	root.add_child(knob)
	var e = _lore_db().get_entry(id)
	var tex: Texture2D = e.sprite if e else null
	if tex:
		var flag := Sprite2D.new()
		flag.texture = tex
		flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var k := 36.0 / maxf(1.0, tex.get_width())
		flag.scale = Vector2(k, k)
		flag.centered = false
		flag.position = Vector2(2, -63)
		root.add_child(flag)
		flag.tree_entered.connect(func():  # el tween necesita el arbol (el prop entra diferido a la sala)
			var tw := flag.create_tween().set_loops()
			tw.tween_property(flag, "skew", 0.12, 0.7).set_trans(Tween.TRANS_SINE)
			tw.tween_property(flag, "skew", -0.06, 0.7).set_trans(Tween.TRANS_SINE), CONNECT_ONE_SHOT)
	return root


static func tr_static(key: String) -> String:
	return TranslationServer.translate(key)
