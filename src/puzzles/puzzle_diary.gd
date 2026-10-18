extends Puzzle
class_name PuzzleDiary

## Diario intimo (acertijo creativo, cualquier reino). Un diario con corazon y candado de tres
## ruedas numericas. Los tres numeros estan escritos en hojas arrancadas pegadas al muro de
## OTRAS salas del piso (las mas cercanas por puertas, sin jefe ni secretas); cada hoja lleva
## unos corazoncitos que dicen a que rueda corresponde. Nadie lo explica. Si el piso no tiene
## salas de sobra, las hojas que falten se pegan en esta misma sala, tras la pared del fondo.
## Dificultad: con la profundidad las hojas se buscan mas lejos (mas puertas de distancia).
## El bot, que no sabe de paginas, gira las ruedas hasta el codigo (como los demas, no se atasca).

const DIAL := preload("res://src/puzzles/dial_post.gd")
const FAR_TYPES := [Room.RoomType.COMBAT, Room.RoomType.TREASURE, Room.RoomType.REST,
		Room.RoomType.LORE, Room.RoomType.TRAP, Room.RoomType.INTOXICATION, Room.RoomType.START]

var _code: Array[int] = []
var _dials: Array = []
var _book: Sprite2D
var _turns := 0
var _pages: Array = []   # [{room, node}] (para limpiar al resolver no hace falta, quedan de decoracion)


func build() -> void:
	kind = "diary"
	for i in 3:
		_code.append(rng.randi_range(0, 9))
	_book = make_sprite("diary_closed", Vector2(0, -34), 0)
	LightKit.add_contact_shadow(_book, 20.0, 14.0).position = Vector2(0, 14)
	for i in 3:
		var d = Area2D.new()
		d.set_script(DIAL)
		d.index = i
		d.position = Vector2((i - 1) * 46.0, 18.0)
		d.prompt_text = tr("PZ_ROTATE")
		d.turned.connect(_on_turn)
		gray(d)
		add_child(d)
		_dials.append(d)
	_place_pages()


## Reparte las 3 hojas: salas cercanas distintas si las hay; si no, aqui mismo.
func _place_pages() -> void:
	var rooms := _other_rooms()
	var here := room_node()
	for i in 3:
		var r: Room = rooms[i] if i < rooms.size() else here
		_stick_page(r, i, r == here)


## Salas candidatas, de mas cerca a mas lejos en puertas; `depth` decide cuantas del principio
## se saltan (en pisos altos, mas lejos), y se mezclan un poco entre si.
func _other_rooms() -> Array:
	var main := get_tree().get_first_node_in_group("main") if is_inside_tree() else null
	var here := room_node()
	if main == null or here == null or not "dungeon_generator" in main:
		return []
	var gen = main.dungeon_generator
	var graph: Dictionary = gen.room_graph
	var dist := {here.grid_pos: 0}
	var order: Array[Vector2i] = []
	var queue: Array[Vector2i] = [here.grid_pos]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for nb in graph.get(cur, []):
			if not dist.has(nb):
				dist[nb] = dist[cur] + 1
				order.append(nb)
				queue.append(nb)
	var cands: Array = []
	for pos in order:
		var r: Room = gen.rooms.get(pos)
		if r != null and r.room_type in FAR_TYPES:
			cands.append(r)
	var skip := clampi((depth - 1) / 3, 0, maxi(0, cands.size() - 3))
	cands = cands.slice(skip)
	var pool := cands.slice(0, mini(cands.size(), 6))
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pool[i]
		pool[i] = pool[j]
		pool[j] = t
	return pool.slice(0, 3)


func _stick_page(room: Room, idx: int, same_room: bool) -> void:
	# En el muro izquierdo: el de arriba queda bajo el HUD y las puertas estan en el centro.
	var rect := room.floor_tilemap.get_used_rect()
	var c := room.get_center_position()
	var left := room.floor_tilemap.map_to_local(rect.position).x - 32.0
	var half_h := rect.size.y * 32.0
	var dy := clampf(half_h * 0.35, 40.0, 90.0)
	var y := c.y + (-dy if rng.randf() < 0.5 else dy) + rng.randf_range(-10.0, 10.0)
	if same_room:
		y = c.y + [-100.0, -62.0, 70.0][idx]
	var page := Node2D.new()
	page.name = "DiaryPage%d" % idx
	page.set_meta("diary_page", idx)
	var spr := Sprite2D.new()
	spr.texture = PuzzlePlate.load_tex("diary_page")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.rotation = rng.randf_range(-0.07, 0.07)
	Censor.apply(room, spr)
	page.add_child(spr)
	var num := Label.new()
	num.text = str(_code[idx])
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.size = Vector2(24, 18)
	num.position = Vector2(-12, -13)
	HudStyle.style_label(num, 16, Color("b02a1e"), true)
	num.add_theme_constant_override("shadow_offset_x", 0)
	num.add_theme_constant_override("shadow_offset_y", 0)
	num.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Censor.apply(room, num)
	page.add_child(num)
	for i in idx + 1:  # corazoncitos: de que rueda es
		var h := ColorRect.new()
		h.color = Color("e0525a")
		h.size = Vector2(3, 3)
		h.position = Vector2(-(idx * 5.0) / 2.0 - 1.5 + i * 5.0, 5.0)
		page.add_child(h)
	page.position = Vector2(left - 10.0, y)
	page.z_index = 1
	room.props_node.add_child(page)
	_pages.append({"room": room, "node": page})


func _process(delta: float) -> void:
	idle_hint(delta)


func _on_turn(_dial: Node) -> void:
	if done:
		return
	idle_reset()
	_turns += 1
	_plan.clear()
	Sound.play("crack", 0.1)
	for i in 3:
		if _dials[i].digit != _code[i]:
			if _turns % 12 == 0:  # dando vueltas sin ton ni son: pista
				note_fail()
			return
	_open()


func _open() -> void:
	for d in _dials:
		d.finish()
	_book.texture = PuzzlePlate.load_tex("diary_open")
	_book.create_tween().tween_property(_book, "modulate", Color(1.6, 1.5, 1.2), 0.1)
	_book.create_tween().tween_property(_book, "modulate", Color.WHITE, 0.9).set_delay(0.2)
	solve()


func _bot_plan(_from: Vector2) -> Array:
	for i in 3:
		if _dials[i].digit != _code[i]:
			return [_wp(_dials[i].position, true)]
	return []
