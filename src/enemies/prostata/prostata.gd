class_name Prostata
extends RefCounted

## Utilidades de LA PROSTATA (etapa R): enemigos Goteo Tardio, Madrugador Nocturno y PSA
## Sospechoso, y la jefa La Glandula Callada. Textos de burbuja en locale/prostata.csv (claves
## PRO_*) y frases del narrador en assets/data/narrator/prostata.json.
##
## Eventos de codice (LoreDatabase.custom_event, tipo CUSTOM = 10): enter_prostata (al entrar al
## reino; abre loc_prostata) y prostata_skene (al caer la jefa con Vulvalquiria; abre skene_glandulas).
## Los enemigos y la jefa se desbloquean solos por nombre: KILL_ENEMY ("Goteo Tardío", "Madrugador
## Nocturno", "PSA Sospechoso") y BOSS_KILL ("LA GLÁNDULA CALLADA").

const REGION := "prostata"
static var _registered := false
static var _entered_key := ""
static var _ambient_key := ""


## Personalidades nuevas para el componente de IA (se llama desde el _ready de cada enemigo).
static func ensure() -> void:
	if _registered:
		return
	_registered = true
	# Goteo: cansado, no se enfurece por nada. Vulvalquiria lo adelanta: ella no espera.
	EnemyPersonalities.register("goteo", {
		"courage": 0.5, "detect_mult": 1.2,
		"hero": {"vulvalquiria": {"speed_mult": 1.1}, "ornitorrinco": {"detect_mult": 0.9}},
	})
	# Madrugador: llega en bandada y se enfurece si cae un colega (le arruinaron el sueno).
	EnemyPersonalities.register("madrugador", {
		"courage": 0.7, "detect_mult": 1.5, "rage_ally": true, "rage_time": 6.0, "rage_speed": 1.25,
		"hero": {"ornitorrinco": {"confuse": true}},
	})
	# PSA: terco y sin miedo; sube la cifra y con ella la furia.
	EnemyPersonalities.register("psa", {"courage": 0.9, "detect_mult": 1.2})


static func hero() -> String:
	var rm = Engine.get_main_loop().root.get_node_or_null("RunManager")
	return String(rm.character) if rm != null and "character" in rm else "pitocles"


## Burbuja sobre el enemigo con el texto PRO_<CLAVE> (con %s opcional).
static func say(e: Node, key: String, secs := 2.0, arg = null) -> void:
	var ai = e.get("ai")
	if ai == null or not is_instance_valid(ai):
		return
	var em = ai.get("_emote")
	if em == null or not is_instance_valid(em):
		return
	var txt := Loc.tr_or("PRO_" + key.to_upper(), key)
	if arg != null and txt.contains("%s"):
		txt = txt % str(arg)
	em.say(txt, secs)


static func icon(e: Node, name: String, secs := 1.1) -> void:
	var ai = e.get("ai")
	if ai != null and is_instance_valid(ai):
		ai._emote_icon(name, secs)


## Comentario del narrador al limpiar la sala (evento de assets/data/narrator/prostata.json).
static func note(event: String) -> void:
	EnemyAI._note(event)


static func floating(at: Vector2, text: String, color: Color) -> void:
	var ge = Engine.get_main_loop().root.get_node_or_null("GlobalEvents")
	if ge != null:
		ge.show_floating_text.emit(at, text, color)


## Desbloqueo del codice (ver arriba).
static func codex(id: String) -> void:
	var ld = Engine.get_main_loop().root.get_node_or_null("LoreDatabase")
	if ld != null:
		ld.custom_event(id)


## Frase del narrador propia del heroe: "<evento>_<heroe>" (si existe).
static func say_hero(event: String) -> void:
	var nar = Engine.get_main_loop().root.get_node_or_null("Narrator")
	var key := "%s_%s" % [event, hero()]
	if nar != null and nar.has_lines(key):
		nar.say(key)


static func alive_in_group(tree: SceneTree, group: String) -> int:
	var n := 0
	for g in tree.get_nodes_in_group(group):
		if is_instance_valid(g) and not g.is_queued_for_deletion() and float(g.get("current_health")) > 0.0:
			n += 1
	return n


## Gancho de main._enter_room: codice del reino (una vez por piso) y un comentario ambiente
## en la primera sala tranquila (el narrador baja la voz; maximo una frase por piso).
static func on_enter_room(host: Node, room: Room) -> void:
	var rm = host.get_node_or_null("/root/RunManager")
	if rm == null or rm.floor_region(rm.current_floor) != REGION:
		return
	var key := "%s:%s" % [rm.current_seed, rm.current_floor]
	if _entered_key != key:
		_entered_key = key
		codex("enter_prostata")
	if _ambient_key != key and room.room_type in [Room.RoomType.SHOP, Room.RoomType.TREASURE, Room.RoomType.REST, Room.RoomType.LORE]:
		_ambient_key = key
		var nar = host.get_node_or_null("/root/Narrator")
		if nar != null and nar.has_lines("prostata_ambient"):
			nar.say_first("prostata_ambient")


## "Las 3 a. m.": la sala se oscurece y vuelve. Devuelve el nodo (se borra solo).
static func night(host: Node, hold := 0.9, alpha := 0.72) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0.02, 0.02, 0.09, 0.0)
	layer.add_child(rect)
	var main := host.get_tree().get_first_node_in_group("main")
	var parent: Node = main if main != null else host.get_tree().current_scene
	parent.add_child(layer)
	parent.move_child(layer, mini(1, parent.get_child_count() - 1))
	var tw := layer.create_tween()
	tw.tween_property(rect, "color:a", alpha, 0.3)
	tw.tween_interval(hold)
	tw.tween_property(rect, "color:a", 0.0, 0.8)
	tw.tween_callback(layer.queue_free)
