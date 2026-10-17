extends CanvasLayer
class_name BossIntro

## Presentacion del jefe a pantalla completa: la primera vez que entras a su sala se ve la
## ilustracion (assets/sprites/ui/bosses/<jefe>.png, tools/gen_boss_art.py) con su nombre en
## fuente pixel unos 2.5 s. Pausa el arbol (como el narrador) y se salta con cualquier tecla.

const SHOW_TIME := 2.5
const GRACE := 0.35  # evita saltarla sin querer con la tecla que abrio la puerta
static var _seen: Dictionary = {}

var _t := 0.0
var _root: Control


## Gancho para main._enter_room: muestra la presentacion si la sala es la del jefe y es su primera vez.
static func on_enter_room(host: Node, room: Room) -> void:
	if room == null or room.room_type != Room.RoomType.BOSS or room.cleared:
		return
	var rm := host.get_node("/root/RunManager")
	var key := "%s:%s:%s" % [rm.current_seed, rm.current_floor, room.grid_pos]
	if _seen.has(key):
		return
	var fl: Dictionary = rm.floor_data()
	var bv := BossPicker.pick(fl, rm.current_seed, rm.current_floor)  # original o alternativo (6c)
	var path := "res://assets/sprites/ui/bosses/%s.png" % bv.variant
	if not ResourceLoader.exists(path):
		return
	_seen[key] = true
	var layer := BossIntro.new()
	layer.layer = 90
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(layer)
	layer._build(load(path), Loc.enemy_name(bv.name))


func _build(tex: Texture2D, boss_name: String) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.modulate.a = 0.0
	add_child(_root)
	var art := TextureRect.new()
	art.texture = tex
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(art)
	var name_box := Control.new()
	name_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_box.offset_top = -150
	name_box.offset_bottom = -50
	name_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(name_box)
	for l in [[Vector2(4, 4), Color("1a0b26")], [Vector2.ZERO, Color("ff3b4a")]]:
		var t := HudStyle.pixel_label(boss_name, 40, l[1], true)
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.position += l[0]
		name_box.add_child(t)
	get_tree().paused = true
	Sound.play("crack")


func _process(delta: float) -> void:
	_t += delta
	_root.modulate.a = clampf(minf(_t / 0.3, (SHOW_TIME + 0.3 - _t) / 0.3), 0.0, 1.0)
	if _t >= SHOW_TIME + 0.3:
		_close()


func _input(event: InputEvent) -> void:
	if _t < GRACE:
		return
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if is_queued_for_deletion():
		return
	get_tree().paused = false
	queue_free()
