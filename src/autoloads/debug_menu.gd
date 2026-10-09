extends CanvasLayer

## Modo desarrollador: F1 durante la partida abre un panel para probarlo todo
## (armas, objetos, salas, pisos, personajes, enemigos). Pausa el juego mientras
## esta abierto. Solo existe en builds de depuracion (el editor lo es; un export
## de release no).

var god_mode := false

var _panel: PanelContainer


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		if _panel:
			_close()
		elif _main():
			_open()


func _main() -> Node:
	return get_tree().get_first_node_in_group("main")


func _close() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null
	get_tree().paused = false


## Se reconstruye en cada apertura: salas y piso cambian entre una y otra.
func _open() -> void:
	get_tree().paused = true
	var main := _main()
	var rm := get_node("/root/RunManager")
	var db := get_node("/root/ItemDatabase")
	var ps := get_node("/root/PlayerStats")

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_panel.offset_right = 380
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.06, 0.95)
	bg.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", bg)
	add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)

	var room: Room = main.current_room
	_label(box, "MODO DESARROLLADOR  (F1 cierra)\nPiso %d · semilla %d · sala %s %s" % [
		rm.current_floor, rm.current_seed, Room.RoomType.keys()[room.room_type], room.grid_pos])

	_label(box, "— Jugador —")
	var god := CheckButton.new()
	god.text = "Modo dios (no recibes daño)"
	god.button_pressed = god_mode
	god.toggled.connect(func(on): god_mode = on)
	box.add_child(god)
	_row(box, {
		"Curar todo": func():
			ps.heal(ps.max_health)
			ps.restore_shields_full(),
		"+50 monedas": func(): rm.add_coins(50),
		"+100 huesos": func():
			rm.meta_currency += 100
			rm.save_meta_progression(),
		"Todas las hormonas": func():
			rm.hormones["testosterona"] = true
			rm.hormones["estrogeno"] = true
			get_node("/root/GlobalEvents").hormones_changed.emit(),
	})
	var intox := {}
	for tier in 4:
		intox["Intox %d" % tier] = func():
			ps.reduce_intoxication(ps.max_intoxication)
			ps.add_intoxication([0.0, 35.0, 65.0, 95.0][tier] * ps.max_intoxication / 100.0)
	_row(box, intox)

	_label(box, "— Objetos y armas —")
	var items := OptionButton.new()
	var ids: Array = db._items.keys()
	# armas primero, luego por nombre
	ids.sort_custom(func(a, b):
		var wa: bool = db.get_item(a).equip_slot == Item.EquipSlot.WEAPON
		var wb: bool = db.get_item(b).equip_slot == Item.EquipSlot.WEAPON
		return wa if wa != wb else a < b)
	for id in ids:
		var it = db.get_item(id)
		items.add_item("%s%s (%s)" % ["[ARMA] " if it.equip_slot == Item.EquipSlot.WEAPON else "", it.display_name, id])
		items.set_item_metadata(items.item_count - 1, id)
	box.add_child(items)
	_row(box, {"Dar objeto": func(): main.player.add_item_to_inventory(items.get_selected_metadata())})

	_label(box, "— Sala actual —")
	_row(box, {
		"Matar enemigos": func():
			for e in room.enemies_spawned.duplicate():
				if is_instance_valid(e) and e.has_method("take_damage"):
					e.take_damage(999999.0, main.player, Vector2.ZERO),
		"Abrir secretas": func():
			main.unlock_secret_rooms()
			for r in main.dungeon_generator.rooms.values():
				if r.has_meta("puzzle"):
					r.get_meta("puzzle").solve(),
		"Revelar mapa": func():
			for pos in main.dungeon_generator.rooms:
				main.visited_rooms[pos] = true,
	})
	var spawns := {}
	for t in ["melee", "ranged", "swarmer", "tank", "boss"]:
		spawns["+" + t] = _spawn_enemy.bind(["melee", "ranged", "swarmer", "tank", "boss"].find(t))
	_row(box, spawns)

	_label(box, "— Ir a sala —")
	var rooms := OptionButton.new()
	for r in main.dungeon_generator.rooms.values():
		rooms.add_item("%s %s" % [Room.RoomType.keys()[r.room_type], r.grid_pos])
		rooms.set_item_metadata(rooms.item_count - 1, r)
	box.add_child(rooms)
	_row(box, {"Ir": func():
		_close()
		main._enter_room(rooms.get_selected_metadata())})

	_label(box, "— Piso —")
	var floors := {}
	for n in range(1, RunManager.FLOORS.size() + 1):
		floors["Piso %d" % n] = func():
			_close()
			rm.current_floor = n - 1
			main._advance_to_next_floor()
	_row(box, floors)

	_label(box, "— Personaje (reinicia el piso) —")
	var chars := {}
	for c in RunManager.CHARACTERS:
		chars[RunManager.CHARACTERS[c].name] = func():
			_close()
			rm.character = c
			get_tree().change_scene_to_file("res://src/scenes/main.tscn")
	_row(box, chars)


func _spawn_enemy(t: int) -> void:
	var main := _main()
	var rm := get_node("/root/RunManager")
	var fd: Dictionary = rm.floor_data()
	var room: Room = main.current_room
	var info := {"enemy_type": t, "health": 40.0 + rm.current_floor * 10.0, "damage": 8.0 + rm.current_floor * 3.0}
	if t < 3:
		info.name = fd.names[t]
		info.frames = main._frames_path(fd.roster[t])
	elif t == 4:
		info.name = fd.boss_name
		info.frames = main._frames_path(fd.boss)
		info.health = 450.0 + rm.current_floor * 150.0
	var data: Array[Dictionary] = [info]
	room.cleared = false  # para que al matarlo la sala se vuelva a abrir
	room.spawn_points = [main.player.global_position + Vector2(160, 0)]
	room.spawn_enemies(main.ENEMY_SCENES, data)


func _label(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	parent.add_child(l)


## Fila de botones: {"texto": Callable}
func _row(parent: Control, buttons: Dictionary) -> void:
	var flow := HFlowContainer.new()
	for text in buttons:
		var b := Button.new()
		b.text = text
		b.pressed.connect(buttons[text])
		flow.add_child(b)
	parent.add_child(flow)
