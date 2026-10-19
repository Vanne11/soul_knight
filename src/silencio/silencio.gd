class_name Silencio
extends RefCounted

## LAS TIERRAS DEL SILENCIO (nombre provisorio; Vanessa pone el definitivo): el reino de la violencia
## de genero (E3). Este archivo es el piso 1, "Superficie", y solo eso: aviso de contenido, S1 Turno,
## S2 Espacio, S3 Revision y S4 Mensajes. Diseno aprobado: diseno_E3_silencio.md (secciones 0-3).
## NO incluye S5, S6, el jefe, la sala de memoria ni la transformacion del reino (decisiones pendientes).
##
## REINO INCOMPLETO ("wip": true en assets/data/floors/80_silencio.json): no entra en la ruta normal
## (ver la cabecera de run_manager.gd). Se prueba desde F1 > "Ir al Silencio (WIP)".
##
## REGLAS (diseno_E3, seccion 0): sin bromas, sin enemigos, sin dano, sin fracaso, sin premio. El
## narrador calla en todo el reino (Narrator.say/say_raw/_enqueue consultan Silencio.active()); tampoco
## corren FloorEvents, los guinos (graffiti de Vane), el toast del codice ni la musica. Solo hay
## "carteles" (SilencioCartel: texto en pantalla, tono de acta).
##
## COMO ESTA ARMADO: el generador (DungeonGenerator) usa plan_layout()/assign_rooms() en vez del BSP:
## una cadena horizontal de salas, cada una un RoomType.SILENCIO (la 1a, START) ya "limpia" para que
## nunca se selle ni genere enemigos. Las 4 situaciones son nodos hijos de su sala (silencio_turno.gd,
## silencio_espacio.gd, silencio_revision.gd, silencio_mensajes.gd) que main._enter_room arranca con
## on_enter_room y para con on_leave_room. La luz baja un escalon por sala (CHAIN) con el ambiente de
## RoomLighting. Textos: locale/silencio.csv (SIL_*). Codice: assets/data/lore/silencio_*.tres.
##
## CIRCULO (HUD de 3 luces, tus personas de confianza): aparece en S3 y se apaga ahi. API para el jefe:
## circle_show(), circle_set(i, on), circle_relight(i), circle_is_on(i), circle_lit(). El estado dura la
## partida (se reinicia al empezar otra).
##
## TODO piso 2 "Fondo" (S5 Cinco puertas, S6 El pasillo, jefe "El Pacto de Silencio", S7 sala de
## memoria): 85_silencio_fondo.json. Mientras falte, la salida de S4 abre el portal a la siguiente parte
## de la ruta (main.open_exit) y este piso cuenta como la ultima etapa del reino.
##
## SONIDO (sin sonidos adecuados en assets/audio, se deja el silencio que permite el diseno): faltan el
## murmullo sin palabras y el corte seco de la voz (S1), los pasos de multitud apagados y el golpe sordo
## del empujon (S2), el papel y el cierre y el tono grave por cada luz que se apaga (S3), y el zumbido
## de notificaciones que se corta en la puerta (S4).

const REGION := "silencio"
## Cadena del piso 1: [clave, ancho, alto (tiles), luz ambiente 0..1]. "pasillo" = vacio. Sigue el
## diseno: la luz baja un escalon por sala (1.0 -> 0.35; S5 y S6 la llevan a 0.35 en el piso 2).
const CHAIN := [
	["entrada", 9, 5, 1.0],
	["turno", 14, 9, 1.0],
	["pasillo", 8, 5, 0.92],
	["espacio", 18, 7, 0.84],
	["pasillo", 8, 5, 0.76],
	["revision", 11, 8, 0.68],
	["pasillo", 8, 5, 0.6],
	["mensajes", 14, 10, 0.5],
]
const GAP := 4  # tiles libres entre sala y sala (las puertas teletransportan: no hay suelo entre ellas)
const GROUP_HUD := "sil_hud"

## Estado de la partida (se reinicia con cada partida, ver _sync_run).
static var circle_shown := false
static var circle_on: Array = [true, true, true]
static var _held_weapon: Item = null
static var _run_stamp := -1.0


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func _rm() -> Node:
	return _tree().root.get_node_or_null("RunManager")


## El piso n es de este reino.
static func is_floor(floor_n: int) -> bool:
	return str(RunManager.floor_at(floor_n).get("region", "")) == REGION


## Se esta jugando una partida en este reino (y no en un menu con el piso viejo en memoria).
static func active() -> bool:
	var rm := _rm()
	return rm != null and bool(rm.run_active) and is_floor(int(rm.current_floor))


static func _sync_run() -> void:
	var rm := _rm()
	var stamp := float(rm.run_start_time) if rm else 0.0
	if stamp != _run_stamp:
		_run_stamp = stamp
		circle_shown = false
		circle_on = [true, true, true]
		_held_weapon = null


static func lore(event: String) -> void:
	_tree().root.get_node("LoreDatabase").custom_event(event)


# ------------------------------------------------------------------ trazado (DungeonGenerator)
## Cadena horizontal: {rects (Rect2 en tiles), edges (pares de grid_pos consecutivos), keys}.
static func plan_layout() -> Dictionary:
	var rects: Array = []
	var edges: Array = []
	var keys: Array = []
	var x := 0
	for c in CHAIN:
		var r := Rect2(x, 0, int(c[1]), int(c[2]))
		rects.append(r)
		keys.append(c[0])
		x += int(c[1]) + GAP
	for i in range(rects.size() - 1):
		edges.append([Vector2i(rects[i].position), Vector2i(rects[i + 1].position)])
	return {"rects": rects, "edges": edges, "keys": keys}


## Tipos y luz de cada sala. Todas nacen limpias: sin enemigos, sin sellos, sin recompensa.
static func assign_rooms(gen: DungeonGenerator, plan: Dictionary) -> void:
	for i in plan.rects.size():
		var room: Room = gen.rooms[Vector2i(plan.rects[i].position)]
		room.room_type = Room.RoomType.START if i == 0 else Room.RoomType.SILENCIO
		room.cleared = true
		room.set_meta("silencio", plan.keys[i])
		room.set_meta("sil_light", float(CHAIN[i][3]))
	gen.main_path = gen.rooms.keys()


## Ambiente (CanvasModulate) de una sala: de gris tibio a negro azulado segun su luz.
static func ambient(room: Room) -> Color:
	var l: float = room.get_meta("sil_light", 1.0)
	var t := clampf((l - 0.35) / 0.65, 0.0, 1.0)
	return Color(l * lerpf(0.78, 1.0, t), l * lerpf(0.86, 0.98, t), l * lerpf(1.0, 0.94, t))


# ------------------------------------------------------------------ ganchos de main.gd
## Al terminar de generar un piso (main._generate_dungeon). Dentro del reino: aviso y HUD; fuera, limpia.
static func setup_floor(main: Node) -> void:
	_sync_run()
	restore_weapon(main.player)
	for old in _tree().get_nodes_in_group(GROUP_HUD):
		old.queue_free()
	if not active():
		return
	Narrator.hush()
	var hud := SilencioHud.new()
	hud.add_to_group(GROUP_HUD)
	main.add_child(hud)
	SilencioAviso.open_aviso(main)


## main._enter_room: viste la sala (suelo plano gris tibio) y arranca su situacion, si la tiene.
static func on_enter_room(main: Node, room: Room, _entry_door: Door) -> void:
	if not room.has_meta("silencio"):
		return
	_dress(room)
	var key: String = room.get_meta("silencio")
	if not room.has_meta("sil_sala"):
		var made := _make_sala(key)
		if made == null:
			return  # entrada y pasillos: salas vacias
		room.set_meta("sil_sala", made)
		made.setup(main, room)
		room.add_child(made)
	var sala: SilencioSala = room.get_meta("sil_sala")
	sala.enter()


## main._enter_room, antes de salir de la sala actual.
static func on_leave_room(_main: Node, room: Room) -> void:
	var sala = room.get_meta("sil_sala") if room.has_meta("sil_sala") else null
	if sala != null and is_instance_valid(sala):
		sala.leave()


static func _make_sala(key: String) -> SilencioSala:
	match key:
		"turno": return SilencioTurno.new()
		"espacio": return SilencioEspacio.new()
		"revision": return SilencioRevision.new()
		"mensajes": return SilencioMensajes.new()
	return null


## Suelo propio de la sala: una capa plana de gris tibio con juntas muy tenues (provisorio). Va sobre el
## suelo de siempre y bajo los muros y los objetos, como las capas de suelo de las dinamicas de sala.
static func _dress(room: Room) -> void:
	if room.has_meta("sil_dressed"):
		return
	room.set_meta("sil_dressed", true)
	var floor_art := SilencioSuelo.new()
	floor_art.name = "SilencioSuelo"
	floor_art.size = Vector2(room.floor_tilemap.get_used_rect().size) * 64.0
	floor_art.kind = str(room.get_meta("silencio"))
	room.add_child(floor_art)
	room.move_child(floor_art, room.floor_tilemap.get_index() + 1)


# ------------------------------------------------------------------ pantalla: carteles y avisos
## Cartel de acta (texto en pantalla, sin ironia). secs 0 = segun el largo del texto.
static func cartel(lines: Array, secs := 0.0) -> void:
	SilencioCartel.show_lines(lines, secs)


## Linea fija sobre el centro inferior ("" la quita): lo que se hace en la sala (mantener E, responder...).
static func hint(text: String) -> void:
	for h in _tree().get_nodes_in_group(GROUP_HUD):
		h.set_hint(text)


## El panel "Como buscar ayuda" (entrada de codice como_buscar_ayuda). Siempre disponible en el reino.
static func ayuda() -> void:
	var main := _tree().get_first_node_in_group("main")
	if main != null:
		SilencioAviso.open_ayuda(main)


# ------------------------------------------------------------------ el circulo (HUD de 3 luces)
## API del circulo para el jefe: lo muestra (S3 lo estrena), apaga o vuelve a encender cada luz.
static func circle_show() -> void:
	circle_shown = true
	for h in _tree().get_nodes_in_group(GROUP_HUD):
		h.circle_refresh(true)


static func circle_set(i: int, on: bool) -> void:
	circle_on[clampi(i, 0, 2)] = on
	for h in _tree().get_nodes_in_group(GROUP_HUD):
		h.circle_refresh(false)


static func circle_relight(i: int) -> void:
	circle_set(i, true)


static func circle_is_on(i: int) -> bool:
	return bool(circle_on[clampi(i, 0, 2)])


static func circle_lit() -> int:
	return circle_on.filter(func(v): return v).size()


# ------------------------------------------------------------------ el arma que te guardan (S3)
## Guarda el arma del heroe (la deja "en gris": sin arma en la mano) hasta devolverla. Nunca se pierde:
## restore_weapon la devuelve al salir de la sala, al generar cualquier piso y desde el menu de depuracion.
static func stash_weapon(player: Player) -> Item:
	if _held_weapon != null or player.current_weapon == null:
		return _held_weapon
	_held_weapon = player.current_weapon
	player.current_weapon = null
	player.weapon_sprite.texture = null
	player.weapon_pivot.visible = false
	return _held_weapon


static func restore_weapon(player: Player) -> bool:
	if _held_weapon == null or player == null:
		return false
	var item := _held_weapon
	_held_weapon = null
	player.equip_weapon(item)
	player.weapon_pivot.visible = true
	return true


static func weapon_held() -> Item:
	return _held_weapon


# ------------------------------------------------------------------ movimiento sin dano
## Empuja al heroe `dist` px en `dir` durante `secs` sin danar ni aturdir (choca con los muros).
static func push(player: Player, dir: Vector2, dist: float, secs := 0.25) -> void:
	var tw := player.create_tween()
	var last := [0.0]
	tw.tween_method(func(k: float):
		player.move_and_collide(dir.normalized() * dist * (k - float(last[0])))
		last[0] = k, 0.0, 1.0, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Lleva al heroe hasta `to` (global) en `secs`, sin que pueda impedirlo; despues le devuelve el control.
static func carry(player: Player, to: Vector2, secs: float) -> void:
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	var tw := player.create_tween()
	tw.tween_property(player, "global_position", to, secs).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	if is_instance_valid(player):
		player.set_physics_process(true)


## Minimapa (Minimap._draw, tras las salas): en S4, "Te siguen", un punto que avanza detras del heroe.
static func draw_minimap(canvas: Control, room_rect: Rect2, room: Room) -> void:
	if room == null or not room.has_meta("sil_sala"):
		return
	var sala: SilencioSala = room.get_meta("sil_sala")
	if sala is SilencioMensajes:
		(sala as SilencioMensajes).draw_follower(canvas, room_rect)
