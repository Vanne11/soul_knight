class_name CorridorEncounter
extends RefCounted

## ENCUENTROS ALEATORIOS en los pasillos entre reinos (guino a Pokemon). Al empezar un pasillo se sortea
## (por semilla, ~30%) si habra uno y cuando (entre el 20% y el 55% del camino). Al llegar ahi: destellos y
## franjas blancas/negras (~0,8 s), un "¡!" sobre el heroe y el cartel "¡Ha aparecido un <NOMBRE> salvaje!";
## despues sale un CorridorPest (src/dungeon/corridor_pest.gd) detras del heroe. Se huye corriendo hasta el
## final del pasillo o se vence (poca recompensa). Sin combate de verdad: solo es muy, muy incomodo.
##
## Para pruebas: CorridorEncounter.force = "<tipo>" (o "random") lo fuerza siempre; chance = 0 los apaga.

const CHANCE := 0.30
static var chance := CHANCE
static var force := ""   # "" = por probabilidad; "random" o un tipo = siempre


## {types: [..2-4 bichos, a veces mezclados], at} o {} si este pasillo no trae encuentro.
static func roll(seed_: int, from_r: String, to_r: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_, from_r, to_r, "encuentro"])
	if force == "none":
		return {}
	if force == "" and rng.randf() >= chance:
		return {}
	var type_: String = CorridorPest.TYPES[rng.randi_range(0, CorridorPest.TYPES.size() - 1)]
	if force != "" and force != "random" and force in CorridorPest.TYPES:
		type_ = force
	var types: Array = [type_]
	for i in rng.randi_range(1, 3):  # 2-4 en total
		types.append(CorridorPest.TYPES[rng.randi_range(0, CorridorPest.TYPES.size() - 1)] if rng.randf() < 0.6 else type_)
	return {"type": type_, "types": types, "at": rng.randf_range(0.2, 0.5)}


## Corre el encuentro (await). `main` es la escena principal; el heroe queda quieto durante la intro.
static func run(main: Node, types: Array) -> void:
	var player: Node2D = main.player
	var room: Room = main.current_room
	player.set_physics_process(false)
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	for t in types:
		_unlock_codex(main, str(t))
	var layer := CanvasLayer.new()
	layer.layer = 96
	var fx := Flash.new()
	layer.add_child(fx)
	main.add_child(layer)
	Sound.play("aviso_zona")
	# "¡!" sobre el heroe
	var ge := main.get_node("/root/GlobalEvents")
	ge.show_floating_text.emit(player.global_position + Vector2(0, -46), "¡!", Color("ffd75a"))
	await fx.play(0.8)
	# cartel
	var name_ := CorridorPest.tr_name(str(types[0]))
	var banner := _banner(tr_("PAS_ENC_APPEARED") % name_ if types.size() == 1 else tr_("PAS_ENC_APPEARED_MANY") % name_)
	layer.add_child(banner)
	await main.get_tree().create_timer(1.5).timeout
	banner.queue_free()
	layer.queue_free()
	if not is_instance_valid(main) or not main.corridor_active or room == null or not is_instance_valid(room):
		return
	# salen por el camino: unos detras del heroe (te persiguen) y otros delante (se plantan en tu camino)
	var dir_ := Director.new()
	dir_.room = room
	dir_.player = player
	dir_.types = types
	room.add_child(dir_)
	player.set_physics_process(true)


static func tr_(key: String) -> String:
	return TranslationServer.translate(key)


static func _unlock_codex(main: Node, type_: String) -> void:
	main.get_node("/root/LoreDatabase").custom_event("pest_" + type_)  # codice


static func _banner(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -190
	panel.offset_bottom = -110
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f4f0e0")
	sb.border_color = Color("1a1020")
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_color_override("font_color", Color("1a1020"))
	lab.add_theme_font_size_override("font_size", 26)
	panel.add_child(lab)
	return panel


## Transicion clasica de encuentro: destellos blanco/negro y franjas que cruzan la pantalla.
class Flash extends Control:
	var _t := 0.0
	var _dur := 0.8
	var _playing := false
	signal done

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func play(dur: float) -> void:
		_dur = dur
		_t = 0.0
		_playing = true
		await done

	func _process(delta: float) -> void:
		if not _playing:
			return
		_t += delta
		queue_redraw()
		if _t >= _dur + 0.25:
			_playing = false
			done.emit()

	func _draw() -> void:
		var s := get_viewport_rect().size
		var k := _t / _dur
		if k < 0.5:
			# destellos: cuatro parpadeos blanco/negro
			var step := int(k / 0.5 * 8.0)
			var col := Color(1, 1, 1, 0.8) if step % 2 == 0 else Color(0, 0, 0, 0.8)
			draw_rect(Rect2(Vector2.ZERO, s), col)
		elif k < 1.0:
			# franjas horizontales que entran por los lados
			var u := (k - 0.5) / 0.5
			var bars := 12
			var h := s.y / bars
			for i in bars:
				var w := s.x * u
				var col2 := Color(0, 0, 0, 0.95) if i % 2 == 0 else Color(1, 1, 1, 0.95)
				if i % 2 == 0:
					draw_rect(Rect2(0, i * h, w, h), col2)
				else:
					draw_rect(Rect2(s.x - w, i * h, w, h), col2)
		else:
			# se retiran
			var u2 := clampf((k - 1.0) / 0.3125, 0.0, 1.0)
			var bars2 := 12
			var h2 := s.y / bars2
			for i in bars2:
				var w2 := s.x * (1.0 - u2)
				var col3 := Color(0, 0, 0, 0.95) if i % 2 == 0 else Color(1, 1, 1, 0.95)
				if i % 2 == 0:
					draw_rect(Rect2(s.x - w2, i * h2, w2, h2), col3)
				else:
					draw_rect(Rect2(0, i * h2, w2, h2), col3)


## Lleva el encuentro: reparte los bichos (persiguen / bloquean), prepara la emboscada del final del pasillo
## y los retira pasado un tope de tiempo (nunca traba a nadie, ni al bot).
class Director extends Node:
	const MAX_SECS := 30.0
	const AMBUSH_AT := 0.78
	var room: Room
	var player: Node2D
	var types: Array = []
	var pests: Array = []
	var _t := 0.0
	var _ambushed := false
	var _done := false

	func _ready() -> void:
		var cl: PackedVector2Array = room.get_meta("corridor_cl")
		var j := _idx(player.global_position - room.global_position, cl)
		for i in types.size():
			var behind := i % 2 == 0
			var k := clampi(j - 5 - i if behind else j + 5 + i, 0, cl.size() - 1)
			_spawn(str(types[i]), cl[k], "chase" if behind else "guard")

	func _idx(local: Vector2, cl: PackedVector2Array) -> int:
		var best := 0
		var bd := INF
		for i in cl.size():
			var d := cl[i].distance_squared_to(local)
			if d < bd:
				bd = d
				best = i
		return best

	func _spawn(t: String, local: Vector2, mode: String) -> void:
		var p := CorridorPest.create(t, room, player)
		p.mode = mode
		room.add_child(p)
		p.global_position = room.global_position + local
		pests.append(p)

	func _process(delta: float) -> void:
		if _done or not is_instance_valid(room) or not is_instance_valid(player):
			return
		_t += delta
		var cl: PackedVector2Array = room.get_meta("corridor_cl")
		var prog := Corridor.progress(room, player.global_position - room.global_position)
		# emboscada: si corres, delante del final aparecen dos mas
		if not _ambushed and prog >= AMBUSH_AT:
			_ambushed = true
			var n := cl.size()
			for i in 2:
				_spawn(str(types[i % types.size()]), cl[maxi(n - 6 - i * 2, 0)], "guard")
			get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -46), "¡!", Color("ffd75a"))
			Sound.play("aviso_zona")
		if _t >= MAX_SECS:
			_done = true
			for p in pests:
				if is_instance_valid(p):
					p.retreat()
			for b in get_tree().get_nodes_in_group("chat_bubble"):
				b.queue_free()
			get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -46), tr("PAS_ENC_BORED"), Color("c8c8d8"))
