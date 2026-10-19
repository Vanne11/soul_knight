class_name UteroConsulta
extends Node2D

## La CONSULTA DE LA DOCTORA V. (guino a la autora): recepcion de la sala de inicio del Utero.
## Un cartel colgado, el escritorio de la doctora y su estetoscopio. Hablarle no cuesta nada:
## te recibe (sin turno, sin cobrar) y suelta una frase. Se dibuja en codigo (sin arte externo).

var _sign: Label
var _sub: Label


static func build(main: Node, room: Room) -> void:
	if room.has_meta("consulta_built"):
		return
	room.set_meta("consulta_built", true)
	var visual := UteroConsulta.new()
	var pos: Vector2 = room.get_center_position() + Vector2(0, -70)
	main._add_prop(room, pos, visual, main.tr("UTERO_PROMPT_TALK"), func(_p, _it):
		RoomUtil.popup(visual.global_position + Vector2(0, -80), main.tr("UTERO_DOCTORA_SAYS"), Color("ff8fb0"))
		Sound.play("puzzle_solve")
		main.get_node("/root/LoreDatabase").custom_event("utero_consulta"))
	Narrator.say_first("utero_consulta")


func _ready() -> void:
	# cartel colgado y subtitulo debajo
	_sign = HudStyle.pixel_label(tr("UTERO_SIGN"), 11, Color("f2ead6"), true)
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.position = Vector2(-96, -158)
	_sign.size = Vector2(192, 28)
	_sign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_sign)
	_sub = HudStyle.pixel_label(tr("UTERO_SIGN_SUB"), 9, Color("ff9fb8"), true)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.position = Vector2(-92, -131)
	_sub.size = Vector2(184, 22)
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_sub)
	set_meta("tall", true)
	z_index = 1
	TallProp.attach(self, Rect2(-100, -162, 200, 176))  # el heroe pasa por detras del escritorio


func _draw() -> void:
	var wood := Color("6b4226")
	var wood_hi := Color("93603a")
	var dark := Color("2a1410")
	# cartel (placa de madera con dos cadenas)
	draw_line(Vector2(-70, -108), Vector2(-70, -60), dark, 2.0)
	draw_line(Vector2(70, -108), Vector2(70, -60), dark, 2.0)
	draw_rect(Rect2(-100, -162, 200, 56), wood_hi)
	draw_rect(Rect2(-100, -162, 200, 56), dark, false, 3.0)
	draw_rect(Rect2(-95, -157, 190, 46), Color("3a1a14"))
	# escritorio de la doctora
	draw_rect(Rect2(-45, -20, 90, 34), wood)
	draw_rect(Rect2(-45, -20, 90, 34), dark, false, 2.0)
	draw_rect(Rect2(-36, -28, 24, 8), Color("e9d9b6"))  # papeles
	draw_arc(Vector2(18, -24), 8.0, PI, TAU, 12, Color("9ad8e8"), 2.0)  # estetoscopio
