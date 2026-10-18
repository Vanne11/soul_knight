class_name Pit
extends RefCounted

## Ayudantes de los FOSOS (celdas PIT de src/dungeon/room_shapes.gd) y del agua profunda (WATER).
##   - Jugador: caer y reaparecer lo hace player.gd (usa kind_at, flash_screen, safe_spot).
##   - Enemigos: caen si los EMPUJAN (src/enemies/pit_fall.gd); caminando los ven como pared.
##   - fall_ghost: copia del sprite que se encoge y se oscurece al caer (enemigos).
## Todo en coordenadas globales de entrada; el tipo de celda sale de la sala (Room.cell_kind).

const META_HOLES := "pit_holes"
const FALL_TIME := 0.35


## Sala (Room) que contiene al nodo (para actores que cuelgan de ella), o null.
static func room_of(node: Node) -> Room:
	var n: Node = node.get_parent() if node != null else null
	while n != null:
		if n is Room:
			return n
		n = n.get_parent()
	return null


## true si la sala tiene algun foso o laguna (se calcula una vez y se guarda en la sala).
static func has_holes(room: Room) -> bool:
	if room == null or room.shape_cells.is_empty():
		return false
	if room.has_meta(META_HOLES):
		return room.get_meta(META_HOLES)
	var any := false
	for c in room.shape_cells:
		if c == RoomShapes.PIT or c == RoomShapes.WATER:
			any = true
			break
	room.set_meta(META_HOLES, any)
	return any


## Tipo de la celda bajo un punto global (RoomShapes.FLOOR/WALL/PIT/WATER/LOW; -1 fuera).
static func kind_at(room: Room, global_pos: Vector2) -> int:
	var p := global_pos - room.global_position
	return room.cell_kind(Vector2i(floori(p.x / 64.0), floori(p.y / 64.0)))


## Destello rojo de pantalla (al reaparecer tras caer). No toca la viñeta de ScreenFx.
static func flash_screen(host: Node, secs := 0.5) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color(0.9, 0.04, 0.06, 0.0)
	layer.add_child(r)
	host.get_tree().root.add_child(layer)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.38, 0.06)
	tw.tween_property(r, "color:a", 0.0, secs)
	tw.tween_callback(layer.queue_free)


## Copia del fotograma actual de `spr` que cae por el hueco en `at` (global): se encoge, gira un
## poco y se oscurece (azul si es agua). Cuelga de `parent` y se borra sola.
static func fall_ghost(spr: AnimatedSprite2D, parent: Node, at: Vector2, water := false) -> void:
	if spr == null or spr.sprite_frames == null or parent == null:
		return
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	if tex == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	g.flip_h = spr.flip_h
	g.offset = spr.offset
	g.scale = spr.global_scale.abs()
	g.z_index = 1
	parent.add_child(g)
	g.global_position = at
	var end_col := Color(0.05, 0.1, 0.25, 0.0) if water else Color(0.04, 0.03, 0.05, 0.0)
	var tw := g.create_tween().set_parallel(true)
	tw.tween_property(g, "scale", g.scale * 0.15, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(g, "modulate", end_col, FALL_TIME)
	tw.tween_property(g, "rotation", 0.9 if not spr.flip_h else -0.9, FALL_TIME)
	tw.chain().tween_callback(g.queue_free)
