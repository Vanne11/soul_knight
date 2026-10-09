extends Control
class_name Minimap

## Minimapa del piso (esquina superior derecha, bajo la franja del HUD). Salas
## pisadas en color, vecinas sin pisar como "?", la actual parpadea. M lo agranda.
## Si el jugador pasa por debajo se vuelve casi transparente para no tapar.

const SMALL := Vector2(210, 140)
const BIG := Vector2(720, 420)  # deja libre el cuadro del narrador
const ROOM_NAMES := {
	Room.RoomType.COMBAT: "Combate", Room.RoomType.SHOP: "Tienda", Room.RoomType.LORE: "Inscripción",
	Room.RoomType.TREASURE: "Tesoro", Room.RoomType.REST: "Descanso",
	Room.RoomType.TRAP: "Trampa", Room.RoomType.PUZZLE: "Acertijo", Room.RoomType.SECRET: "Secreta",
	Room.RoomType.BOSS: "Jefe", Room.RoomType.INTOXICATION: "Antro", Room.RoomType.MINIBOSS: "Minijefe",
	Room.RoomType.START: "Inicio",
}
## Letra dentro de la sala en el mapa (las que no salen aqui no llevan marca).
const ICONS := {Room.RoomType.SHOP: "$", Room.RoomType.BOSS: "J", Room.RoomType.START: "I",
	Room.RoomType.MINIBOSS: "M", Room.RoomType.SECRET: "?", Room.RoomType.TREASURE: "T",
	Room.RoomType.REST: "+", Room.RoomType.LORE: "i", Room.RoomType.PUZZLE: "P"}

var _big := false
var _font: Font
var _label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_outline_color", Color("0d0b0f"))
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)
	_resize()

func _resize() -> void:
	var s := BIG if _big else SMALL
	if _big:
		set_anchors_preset(Control.PRESET_CENTER)
		offset_left = -s.x / 2; offset_right = s.x / 2
		offset_top = -s.y / 2 - 40; offset_bottom = s.y / 2 - 40
	else:
		set_anchors_preset(Control.PRESET_TOP_RIGHT)
		offset_left = -s.x - 10; offset_right = -10
		offset_top = HUD.BAND + 6; offset_bottom = HUD.BAND + 6 + s.y
	_label.position = Vector2(0, s.y + 2)
	_label.size = Vector2(s.x, 20)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		_big = not _big
		_resize()

func _process(delta: float) -> void:
	queue_redraw()
	var target := 1.0
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p and not _big and get_global_rect().grow(40).has_point(p.get_global_transform_with_canvas().origin):
		target = 0.25
	modulate.a = move_toward(modulate.a, target, delta * 4.0)

func _draw() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main == null or main.dungeon_generator == null or main.dungeon_generator.rooms.is_empty():
		return
	var gen: DungeonGenerator = main.dungeon_generator
	var visited: Dictionary = main.visited_rooms
	var current: Room = main.current_room

	# Lo que se conoce: lo pisado y sus vecinos directos.
	var known := {}
	for pos in visited:
		known[pos] = true
		for n in gen.room_graph.get(pos, []):
			known[n] = true

	# Encaja todo el piso (no solo lo conocido) para que el mapa no "salte".
	var bounds := Rect2i()
	var first := true
	for pos in gen.rooms:
		var r := Rect2i(pos, gen.room_sizes.get(pos, Vector2i(8, 6)))
		bounds = r if first else bounds.merge(r)
		first = false
	var box := size - Vector2(12, 12)
	var k: float = minf(box.x / bounds.size.x, box.y / bounds.size.y)
	var origin := Vector2(6, 6) + (box - Vector2(bounds.size) * k) / 2 - Vector2(bounds.position) * k

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.06, 0.85))
	draw_rect(Rect2(Vector2.ZERO, size), Color("b08d4a"), false, 2.0)

	var rect_of := func(pos: Vector2i) -> Rect2:
		return Rect2(origin + Vector2(pos) * k, Vector2(gen.room_sizes.get(pos, Vector2i(8, 6))) * k)

	# Pasillos entre salas conocidas.
	for pos in known:
		for n in gen.room_graph.get(pos, []):
			if known.has(n) and (visited.has(pos) or visited.has(n)):
				draw_line(rect_of.call(pos).get_center(), rect_of.call(n).get_center(), Color(0.7, 0.65, 0.55, 0.6), 2.0)

	var blink := int(Time.get_ticks_msec() / 400) % 2 == 0
	for pos in known:
		var room: Room = gen.rooms[pos]
		var r: Rect2 = rect_of.call(pos).grow(-1)
		var fill: Color
		if room == current:
			fill = Color("f2ead6") if blink else Color("ffc93c")
		elif visited.has(pos):
			fill = Color(0.45, 0.75, 0.45) if room.cleared or room.enemies_spawned.is_empty() else Color(0.8, 0.4, 0.4)
		else:
			fill = Color(0.42, 0.42, 0.48)
		draw_rect(r, fill)
		draw_rect(r, Color("0d0b0f"), false, 1.0)
		# Tienda y jefe se ven en cuanto conoces la sala; el resto, al pisarla.
		var icon: String = ICONS.get(room.room_type, "")
		if not visited.has(pos) and room.room_type not in [Room.RoomType.SHOP, Room.RoomType.BOSS]:
			icon = "?"
		if icon != "":
			var fs := int(clampf(r.size.y * 0.6, 9, 28))
			var col := Color("ff5050") if icon == "J" else (Color("ffd700") if icon == "$" else Color("0d0b0f"))
			if room == current:
				col = Color("0d0b0f")  # sobre el amarillo de "estas aqui" no se veia
			draw_string(_font, Vector2(r.position.x, r.get_center().y + fs * 0.35), icon, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)

	if current:
		_label.text = "Sala: %s   [M] mapa" % ROOM_NAMES.get(current.room_type, "?")
