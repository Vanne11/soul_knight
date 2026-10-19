class_name MitoVerdad
extends RefCounted

## Mito o Verdad opcional en las salas de lore: una placa que enseña una afirmacion al
## acercarte y dos piedras (VERDAD / MITO) para responder si quieres. Acertar da unas
## monedas; fallar, solo la explicacion con humor. Ignorarlo no cuesta nada ni bloquea nada.

const PROP := preload("res://src/edu/edu_prop.gd")
const REWARD := 3


static func build(main: Node, room: Room) -> void:
	var q := Edu.next_mito_verdad()
	if q.is_empty():
		return
	var c := room.get_center_position()
	var props: Array = []
	var answer := func(said_true: bool):
		if props.is_empty() or not is_instance_valid(props[0]) or not props[0].is_processing():
			return
		var player := room.get_tree().get_first_node_in_group("player")
		if said_true == q.es_verdad:
			Edu.rm().add_coins(REWARD)
			Sound.play("buy")
			if player:
				Edu.ge().show_floating_text.emit(player.global_position + Vector2(0, -46), "+%d $" % REWARD, Color("ffd75a"))
			Narrator.say("edu_mito_ok")
		else:
			Narrator.say("edu_mito_mal")
		Narrator.say_raw(q.explicacion)
		for p in props:
			if is_instance_valid(p):
				p.finish()
	props.append(_prop(main, room, c + Vector2(125, -40), Consultorio._sprite_visual(room, "placa", 50, false, 20.0, true),
		func(): return Edu.t("EDU_MV_ASK") % q.pregunta, Callable(), true))
	props.append(_prop(main, room, c + Vector2(90, 40), Consultorio._sprite_visual(room, "piedra_verdad", 26, false, 8.0),
		func(): return Edu.t("EDU_MV_TRUE"), func(_p, _it): answer.call(true)))
	props.append(_prop(main, room, c + Vector2(160, 40), Consultorio._sprite_visual(room, "piedra_mito", 26, false, 8.0),
		func(): return Edu.t("EDU_MV_MYTH"), func(_p, _it): answer.call(false)))


static func _prop(main: Node, room: Room, pos: Vector2, visual: Node2D, prompt: Callable, on_use: Callable, badge := false) -> Node:
	var it := PROP.new()
	it.has_badge = badge
	it.badge_y = Consultorio._top_of(visual) - 12.0
	it.position = pos
	it.prompt_fn = prompt
	it.add_child(visual)
	Consultorio.dress(room, it, visual)
	if on_use.is_valid():
		it.used.connect(on_use.bind(it))
	room.props_node.add_child.call_deferred(it)
	return it
