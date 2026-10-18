class_name UteroConsulta
extends Node2D

## La CONSULTA DE LA DOCTORA V. (guino a la autora): sala tranquila de Trompas de Falopio con un
## cartel en la puerta y la PUERTA DEL CUELLO UTERINO, que se abre con un Turno (objeto "turno").
## Al abrirla, RunManager.insert_utero() mete El Utero tras Trompas. Se dibuja en codigo (sin arte
## externo): arco de carne con pliegues que laten, marco de madera, cartel y un escritorio.

var is_open := false
var _t := 0.0
var _sign: Label
var _sub: Label


static func build(main: Node, room: Room) -> void:
	if room.has_meta("consulta_built"):
		return
	room.set_meta("consulta_built", true)
	var visual := UteroConsulta.new()
	visual.is_open = RunManager.utero_inserted  # (--force-utero o ya abierta)
	var pos: Vector2 = room.get_center_position() + Vector2(0, -50)
	var prompt := main.tr("UTERO_PROMPT_OPEN") if visual.is_open else main.tr("UTERO_PROMPT_DOOR")
	main._add_prop(room, pos, visual, prompt, func(_p, it):
		if visual.is_open:
			RoomUtil.popup(visual.global_position + Vector2(0, -80), main.tr("UTERO_ALREADY_OPEN"), Color("ff8fb0"))
			return
		if not Utero.owns_turno(main):
			RoomUtil.popup(visual.global_position + Vector2(0, -80), main.tr("UTERO_NEED_TURNO"), Color("ff8fb0"))
			Sound.play("locked")
			Narrator.say_first("utero_sin_turno")
			return
		main.player.collected_items.erase(Utero.TURNO)
		RunManager.insert_utero()
		visual.open()
		it.finish()
		Sound.play("puzzle_solve")
		Narrator.toast(main.tr("UTERO_OPENED_T"), main.tr("UTERO_OPENED_D"), "ff8fb0")
		Narrator.say("utero_turno_ok", {}, true)
		main.get_node("/root/LoreDatabase").custom_event("utero_turno")
		print("[utero] Turno entregado: El Utero queda tras Trompas (ruta: %d pisos)" % RunManager.route_size()))
	Narrator.say_first("utero_consulta")


func _ready() -> void:
	# cartel colgado sobre el arco y subtitulo en el marco
	_sign = HudStyle.pixel_label(tr("UTERO_SIGN"), 11, Color("3a1a14"), false)
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.position = Vector2(-96, -142)
	_sign.size = Vector2(192, 36)
	_sign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_sign)
	_sub = HudStyle.pixel_label(tr("UTERO_SIGN_SUB"), 9, Color("f2ead6"), true)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.position = Vector2(-90, 56)
	_sub.size = Vector2(180, 24)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_sub)
	set_meta("tall", true)
	z_index = 1


func open() -> void:
	is_open = true


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var wood := Color("6b4226")
	var wood_hi := Color("93603a")
	var dark := Color("2a1410")
	# cartel (placa de madera con dos cadenas)
	draw_line(Vector2(-70, -108), Vector2(-70, -90), dark, 2.0)
	draw_line(Vector2(70, -108), Vector2(70, -90), dark, 2.0)
	draw_rect(Rect2(-100, -146, 200, 40), wood_hi)
	draw_rect(Rect2(-100, -146, 200, 40), dark, false, 3.0)
	draw_rect(Rect2(-95, -141, 190, 30), Color("e9d9b6"))
	# marco del arco
	draw_rect(Rect2(-44, -96, 88, 150), wood)
	draw_rect(Rect2(-44, -96, 88, 150), dark, false, 3.0)
	# interior: carne con pliegues que laten (elipses concentricas)
	var pulse := 0.5 + 0.5 * sin(_t * (3.2 if is_open else 1.6))
	var base := Color(0.95, 0.42, 0.52) if is_open else Color(0.62, 0.2, 0.28)
	draw_rect(Rect2(-34, -86, 68, 130), base.darkened(0.45))
	for i in 5:
		var k := float(i) / 4.0
		var rad := Vector2(30.0 - k * 22.0 + pulse * 2.0, 58.0 - k * 38.0 + pulse * 3.0)
		_ellipse(Vector2(0, -22), rad, base.lerp(Color(1.0, 0.75, 0.8), k * (0.7 if is_open else 0.35)))
	if is_open:
		_ellipse(Vector2(0, -22), Vector2(7.0, 12.0 + pulse * 3.0), Color(1.0, 0.92, 0.8))  # el cuello se abre
	else:
		draw_rect(Rect2(-34, -30, 68, 10), dark)  # tabla atravesada
		draw_rect(Rect2(-34, -30, 68, 10), wood_hi, false, 2.0)
		draw_circle(Vector2(0, -25), 4.0, Color("d9b84a"))  # candado
	# escritorio de la doctora, a un lado
	draw_rect(Rect2(-150, 8, 70, 30), wood)
	draw_rect(Rect2(-150, 8, 70, 30), dark, false, 2.0)
	draw_rect(Rect2(-142, 0, 20, 8), Color("e9d9b6"))  # papeles
	draw_arc(Vector2(-102, 4), 8.0, PI, TAU, 12, Color("9ad8e8"), 2.0)  # estetoscopio


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
