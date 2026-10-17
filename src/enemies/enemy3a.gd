class_name E3a
extends RefCounted

## Utilidades de los enemigos de la Etapa 3a (Huincha, Dedo, Jaula, bondage, Sonda, Ego, mitos).
## Los textos viven en locale/enemigos3a.csv (claves E3A_*) y las frases del narrador en
## assets/data/narrator/enemigos3a.json. Las personalidades de IA se registran aqui (una vez).

static var _registered := false


## Personalidades nuevas para el componente de IA (src/enemies/ai/). Se llama desde el _ready
## de cada enemigo antes de super._ready().
static func ensure() -> void:
	if _registered:
		return
	_registered = true
	# Huincha: se rige por la logica propia por heroe (enemy_huincha.gd); la IA solo da moral.
	EnemyPersonalities.register("medidor", {
		"courage": 0.6,
		"hero": {"vulvalquiria": {"speed_mult": 1.1}},
	})
	# Dedo del Urologo: te rodea. Con el Ornitorrinco se pierde (no sabe cual es su "atras").
	EnemyPersonalities.register("urologo", {
		"courage": 0.8, "detect_mult": 1.3,
		"hero": {"vulvalquiria": {"speed_mult": 1.12}, "ornitorrinco": {"confuse": true}},
	})
	# Sonda uretral: monomaniaca, no se distrae. El Ornitorrinco la ve venir de lejos (electro).
	EnemyPersonalities.register("sonda", {
		"courage": 0.9, "detect_mult": 1.2,
		"hero": {"ornitorrinco": {"detect_mult": 0.8}},
	})
	# Bondage: caricatura de la censura/represion. Duros de moral.
	EnemyPersonalities.register("bondage", {"courage": 0.75})
	# Ego Inflado: el hincha-globos. Solo se enfrenta si estas cerca.
	EnemyPersonalities.register("ego", {"courage": 0.35})
	# Mitos: se rinden al conocer la verdad (cerca de morir sueltan el botin).
	EnemyPersonalities.register("mito", {
		"courage": 0.4, "surrender_hp": 0.15,
		"hero": {"ornitorrinco": {"confuse": true}},
	})
	EnemyPersonalities.register("gigante3a", {"courage": 1.0})


static func hero() -> String:
	var rm = Engine.get_main_loop().root.get_node_or_null("RunManager")
	return String(rm.character) if rm != null and "character" in rm else "pitocles"


static func player_of(e: Node) -> Node2D:
	var t = e.get("target")
	if t is Node2D and is_instance_valid(t) and t.is_in_group("player"):
		return t
	var pl := e.get_tree().get_nodes_in_group("player")
	return pl[0] if pl.size() > 0 else null


## Burbuja sobre el enemigo con el texto E3A_<clave> (con %s opcional).
static func say(e: Node, key: String, secs := 2.0, arg = null) -> void:
	var ai = e.get("ai")
	if ai == null or not is_instance_valid(ai):
		return
	var em = ai.get("_emote")
	if em == null or not is_instance_valid(em):
		return
	var txt := Loc.tr_or("E3A_" + key.to_upper(), key)
	if arg != null and txt.contains("%s"):
		txt = txt % str(arg)
	em.say(txt, secs)


static func icon(e: Node, name: String, secs := 1.1) -> void:
	var ai = e.get("ai")
	if ai != null and is_instance_valid(ai):
		ai._emote_icon(name, secs)


## Comentario del narrador al limpiar la sala (evento de assets/data/narrator/enemigos3a.json).
static func note(event: String) -> void:
	EnemyAI._note(event)


static func floating(at: Vector2, text: String, color: Color) -> void:
	var ge = Engine.get_main_loop().root.get_node_or_null("GlobalEvents")
	if ge != null:
		ge.show_floating_text.emit(at, text, color)


## Mito roto: avisa de la verdad y desbloquea su entrada del codice.
static func reveal_truth(e: Node, lore_id: String, truth_key: String) -> void:
	floating(e.global_position + Vector2(0, -44), Loc.tr_or("E3A_MITO_BROKEN", "MITO ROTO"), Color("7fe0a0"))
	say(e, truth_key, 3.2)
	note("e3a_mito")
	var ld = Engine.get_main_loop().root.get_node_or_null("LoreDatabase")
	if ld != null:
		ld.unlock_entry(lore_id)


## Cuantos enemigos vivos hay en un grupo (limita invocaciones).
static func alive_in_group(tree: SceneTree, group: String) -> int:
	var n := 0
	for g in tree.get_nodes_in_group(group):
		if is_instance_valid(g) and not g.is_queued_for_deletion() and float(g.get("current_health")) > 0.0:
			n += 1
	return n


## Instancia una escena de enemigo del registro, la deja con valores propios y la mete en la sala.
static func spawn(parent_enemy: Enemy, id: String, at: Vector2, health: float, dmg: float, frames := "", scl := 1.0) -> Node:
	var scn := EnemyRegistry.scene(id)
	var e := scn.instantiate()
	e.max_health = health
	e.damage = dmg
	if frames != "" and ResourceLoader.exists(frames):
		e.get_node("AnimatedSprite2D").sprite_frames = load(frames)
	if scl != 1.0:
		e.get_node("AnimatedSprite2D").scale *= scl
	if parent_enemy.get("ai") != null:
		e.set_meta("e3a_spawned", true)
	var cont: Node = parent_enemy._spawn_container()
	cont.add_child(e)
	e.global_position = at
	var room = parent_enemy.find_owning_room()
	if room != null and "enemies_spawned" in room:
		room.enemies_spawned.append(e)
	return e
