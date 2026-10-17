class_name Consultorio
extends RefCounted

## Consultorio de la Dra. Preventina en las salas de descanso: cura el contagio (gratis),
## vende prevencion (preservativo de bolsillo y vacuna VPH) y un poster con guiño. Todo se
## usa con E y solo si quieres; nada se impone. Lo construye Main._build_calm_room (REST).

const PROP := preload("res://src/edu/edu_prop.gd")


static func build(main: Node, room: Room) -> void:
	var c := room.get_center_position()
	var cfg := Edu.consultorio_cfg()
	_prop(main, room, c + Vector2(-140, -30), _doctor_visual(),
		func(): return Edu.t("EDU_DOC_PROMPT_SICK" if Edu.ps().contagion_time > 0.0 else "EDU_DOC_PROMPT_OK"),
		func(_p, it):
			if Edu.ps().contagion_time > 0.0:
				Edu.ps().clear_contagion()
				Sound.play("room_clear")
				Narrator.say("edu_cura")
			else:
				var fact := Edu.next_fact()
				if fact != "":
					Narrator.say_raw("%s: %s" % [Edu.t("EDU_DOC_NAME"), fact])
			it.finish())
	_prop(main, room, c + Vector2(-140, -110), _poster_visual(),
		func(): return Edu.t("EDU_POSTER_PROMPT"),
		func(_p, it):
			Narrator.say_raw(Edu.t("EDU_POSTER_SAY"))
			it.finish())
	var cp: int = Edu.price(int(cfg.get("preservativo", {}).get("precio", 6)))
	var secs: float = float(cfg.get("preservativo", {}).get("inmunidad_seg", 150.0))
	_prop(main, room, c + Vector2(-210, 30), _box_visual(Color("e87fa8")),
		func(): return Edu.t("EDU_CONDOM_PROMPT" if Edu.rm().coins >= cp else "EDU_CONDOM_POOR") % cp,
		func(p, it):
			if not _pay(cp, p):
				return
			Edu.ps().apply_item_effect({"type": 18, "duration": secs})
			Narrator.say("edu_condon")
			it.finish())
	var vp: int = Edu.price(int(cfg.get("vacuna_vph", {}).get("precio", 15)))
	_prop(main, room, c + Vector2(-140, 50), _syringe_visual(),
		func():
			if Edu.ps().vph_vaccinated:
				return Edu.t("EDU_VAX_DONE")
			return Edu.t("EDU_VAX_PROMPT" if Edu.rm().coins >= vp else "EDU_VAX_POOR") % vp,
		func(p, it):
			if Edu.ps().vph_vaccinated:
				Narrator.say("edu_vacuna_ya")
				return
			if not _pay(vp, p):
				return
			Edu.ps().vph_vaccinated = true
			Narrator.toast(Edu.t("EDU_VAX_TOAST"), "", "7fe0a0")
			Narrator.say("edu_vacuna")
			it.finish())


## Cobra; si no alcanza, la Dra. lo dice con gracia y no pasa nada.
static func _pay(price: int, player: Node) -> bool:
	if Edu.rm().coins < price:
		Sound.play("poor")
		Narrator.say("edu_pobre")
		return false
	Edu.rm().add_coins(-price)
	Edu.ge().show_floating_text.emit(player.global_position + Vector2(0, -46), "-%d $" % price, Color("ffd75a"))
	Sound.play("buy")
	return true


static func _prop(main: Node, room: Room, pos: Vector2, visual: Node2D, prompt: Callable, on_use: Callable) -> void:
	var it := PROP.new()
	it.position = pos
	it.prompt_fn = prompt
	it.add_child(visual)
	main._prop_shadow(it, visual)
	it.used.connect(on_use.bind(it))
	room.props_node.add_child.call_deferred(it)


static func poly(pts: Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(pts)
	p.color = color
	return p


static func _doctor_visual() -> Node2D:
	var n := Node2D.new()
	n.set_meta("tall", true)
	n.add_child(poly([Vector2(-14, 24), Vector2(-16, -6), Vector2(-8, -14), Vector2(8, -14), Vector2(16, -6), Vector2(14, 24)], Color("f2f0ea")))  # bata
	n.add_child(poly([Vector2(-4, -10), Vector2(4, -10), Vector2(0, 8)], Color("8fd0c0")))  # escote
	n.add_child(poly([Vector2(-9, -26), Vector2(9, -26), Vector2(10, -14), Vector2(-10, -14)], Color("e0b090")))  # cabeza
	n.add_child(poly([Vector2(-11, -28), Vector2(11, -28), Vector2(11, -22), Vector2(-11, -22)], Color("5a3a2a")))  # pelo
	n.add_child(poly([Vector2(-2, 0), Vector2(2, 0), Vector2(2, 4), Vector2(6, 4), Vector2(6, 8), Vector2(2, 8), Vector2(2, 12), Vector2(-2, 12), Vector2(-2, 8), Vector2(-6, 8), Vector2(-6, 4), Vector2(-2, 4)], Color("d84a4a")))  # cruz
	return n


static func _box_visual(color: Color) -> Node2D:
	var n := Node2D.new()
	n.add_child(poly([Vector2(-14, 10), Vector2(-14, -8), Vector2(14, -8), Vector2(14, 10)], color))
	n.add_child(poly([Vector2(-14, -8), Vector2(-10, -14), Vector2(10, -14), Vector2(14, -8)], color.lightened(0.25)))
	n.add_child(poly([Vector2(-6, -2), Vector2(6, -2), Vector2(6, 2), Vector2(-6, 2)], Color("fff4e0")))
	return n


static func _syringe_visual() -> Node2D:
	var n := Node2D.new()
	n.add_child(poly([Vector2(-16, 6), Vector2(-16, -2), Vector2(10, -2), Vector2(10, 6)], Color("cfe8f0")))
	n.add_child(poly([Vector2(-12, 4), Vector2(-12, 0), Vector2(2, 0), Vector2(2, 4)], Color("7fe0a0")))
	n.add_child(poly([Vector2(10, 1), Vector2(22, 2), Vector2(10, 3)], Color("c9c2b0")))
	n.add_child(poly([Vector2(-20, -5), Vector2(-16, -5), Vector2(-16, 9), Vector2(-20, 9)], Color("c9c2b0")))
	return n


static func _poster_visual() -> Node2D:
	var n := Node2D.new()
	n.set_meta("flat", true)
	n.add_child(poly([Vector2(-14, 14), Vector2(-14, -16), Vector2(14, -16), Vector2(14, 14)], Color("efe3b8")))
	n.add_child(poly([Vector2(-10, -12), Vector2(10, -12), Vector2(10, -8), Vector2(-10, -8)], Color("b08d4a")))
	for i in 4:
		n.add_child(poly([Vector2(-10, -3 + i * 5), Vector2(10 - i * 4, -3 + i * 5), Vector2(10 - i * 4, -1 + i * 5), Vector2(-10, -1 + i * 5)], Color("8a8494")))
	return n
