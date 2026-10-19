class_name SilencioInventario
extends CanvasLayer

## Pantalla de INVENTARIO que se abre SOLA en S3 "Revision" (diseno_E3, seccion 3): un cursor ajeno
## recorre tus armas y objetos y cada uno trae la misma pregunta. Te guardan el arma: queda en gris y
## no la tienes en la mano hasta cruzar la puerta; nunca se pierde (Silencio.stash_weapon / restore_weapon).
## Mientras revisan, el CIRCULO del HUD se apaga de a una luz (el HUD queda sobre esta pantalla).
## Esc no la cierra los primeros 8 s; despues si, y sola se cierra al rato. Pausa el juego.
##
## Capa 4: encima del HUD de siempre y por debajo del HUD del Silencio (capa 6), que lleva el circulo.

signal closed

const LOCK_SECS := 8.0        # Esc no cierra antes
const MIN_SECS := 9.0         # duracion minima de la revision
const ROW_SECS := 1.4         # lo que tarda el cursor en cada objeto
const START_AT := 0.9
const AUTO_CLOSE_AFTER := 3.0 # tras acabar la revision
const MAX_ROWS := 7
const LIGHTS_AT := [0.25, 0.55, 0.85]  # fraccion de la revision en que se apaga cada luz del circulo

var player: Player
var _rows: Array = []        # {id, label, icon, weapon}
var _row_nodes: Array = []
var _cursor: ColorRect
var _question: Label
var _stash_note: Label
var _close_hint: Label
var _t := 0.0
var _dur := MIN_SECS
var _was_paused := false
var _lights_off := 0
var _stashed := false


static func open(main: Node, player_: Player) -> SilencioInventario:
	var inv := SilencioInventario.new()
	inv.player = player_
	main.add_child(inv)
	return inv


func _ready() -> void:
	layer = 4
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	_collect()
	_dur = maxf(MIN_SECS, START_AT + _rows.size() * ROW_SECS + 1.5)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.04, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("3b3937")
	sb.border_color = Color("8d8984")
	sb.set_border_width_all(1)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 440
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_text(tr("SIL_S3_INVENTARIO"), 24, Color("e4e0d8")))
	for r in _rows:
		var row := _make_row(r)
		box.add_child(row)
		_row_nodes.append(row)
	_cursor = ColorRect.new()  # el cursor ajeno: un marco, sin color de aviso
	_cursor.color = Color(0.9, 0.88, 0.82, 0.13)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.visible = false
	panel.add_child(_cursor)
	_question = _text("", 16, Color("e4e0d8"))
	_question.custom_minimum_size.y = 40
	box.add_child(_question)
	_stash_note = _text("", 16, Color("e4e0d8"))
	box.add_child(_stash_note)
	_close_hint = _text("", 8, Color("a8a49c"))
	box.add_child(_close_hint)
	Silencio.circle_show()


func _text(txt: String, size: int, col: Color) -> Label:
	var l := HudStyle.pixel_label(txt, size, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	return l


## El arma (si la llevas) y tus objetos, sin monedas ni repetidos, como mucho MAX_ROWS.
func _collect() -> void:
	var db := get_node("/root/ItemDatabase")
	if player.current_weapon != null:
		_rows.append({"id": player.current_weapon.id, "item": player.current_weapon, "weapon": true})
	for id in player.collected_items:
		var item = db.get_item(id)
		if item == null or "moneda" in item.tags or (player.current_weapon != null and id == player.current_weapon.id):
			continue
		if _rows.size() < MAX_ROWS and not _rows.any(func(r): return r.id == id):
			_rows.append({"id": id, "item": item, "weapon": item.equip_slot == Item.EquipSlot.WEAPON})
	if _rows.is_empty():
		_rows.append({"id": "", "item": null, "weapon": false})


func _make_row(r: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if r.item != null and r.item.sprite != null:
		icon.texture = r.item.sprite
	row.add_child(icon)
	var name_l := _text(Loc.item_name(r.item) if r.item != null else tr("SIL_S3_VACIO"), 16, Color("e4e0d8"))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.name = "Name"
	row.add_child(name_l)
	var state := _text("", 8, Color("a8a49c"))
	state.autowrap_mode = TextServer.AUTOWRAP_OFF
	state.name = "State"
	row.add_child(state)
	return row


func _process(delta: float) -> void:
	_t += delta
	var k := (_t - START_AT) / ROW_SECS
	var idx := int(floor(k))
	if _t >= START_AT and idx < _rows.size():
		var row: Control = _row_nodes[idx]
		_cursor.visible = true
		_cursor.position = row.global_position - _cursor.get_parent().global_position - Vector2(6, 2)
		_cursor.size = row.size + Vector2(12, 4)
		_question.text = tr("SIL_S3_PREGUNTA")
		if _rows[idx].weapon and not _stashed and k - float(idx) > 0.55:
			_stash(idx)
	elif idx >= _rows.size():
		_cursor.visible = false
	while _lights_off < LIGHTS_AT.size() and _t >= LIGHTS_AT[_lights_off] * _dur:
		Silencio.circle_set(_lights_off, false)  # se apagan de a una mientras revisan
		_lights_off += 1
	_close_hint.text = tr("SIL_S3_CERRAR") if _t >= LOCK_SECS else ""
	if _t >= _dur + AUTO_CLOSE_AFTER:
		_close()


## El arma queda en gris y fuera de tu mano. Se devuelve al cruzar la puerta; el texto lo dice.
func _stash(idx: int) -> void:
	_stashed = true
	Silencio.stash_weapon(player)
	var row: Control = _row_nodes[idx]
	row.modulate = Color(0.55, 0.55, 0.58)
	(row.get_node("State") as Label).text = tr("SIL_S3_GUARDADO")
	_stash_note.text = tr("SIL_S3_DEVUELVEN")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if _t >= LOCK_SECS:
			_close()


func _close() -> void:
	# Cualquier luz que faltara por apagarse se apaga ahora: el circulo ya no esta completo.
	while _lights_off < LIGHTS_AT.size():
		Silencio.circle_set(_lights_off, false)
		_lights_off += 1
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()
