extends CanvasLayer

## Controles tactiles (F4): dos sticks flotantes (izquierda = mover, derecha = apuntar y
## disparar al arrastrar) y botones de dash, habilidad, guardia, interactuar, pausa y ranuras
## 1-4. Solo se ven en partida y solo si hay pantalla tactil (o primer toque), o si Ajustes
## los fuerza ("Controles tactiles": Auto / Si / No). Todo se alimenta como acciones del
## InputMap (Input.action_press) y con Player.aim_override, igual que el bot de pruebas, asi
## el resto del juego no sabe que hay un dedo en vez de un teclado.
## Tambien pausa la partida al perder el foco de la ventana / pasar la app a segundo plano.

const STICK_R := 96.0  # radio de la base del stick
const DEADZONE := 0.18
const AIM_FIRE := 0.35  # el stick de apuntar dispara pasando de este recorrido
const BAND := 84.0  # alto reservado al HUD: ningun stick nace ahi
const ALPHA_IDLE := 0.34
const ALPHA_DOWN := 0.7
const COLOR_RING := Color("f0c04a")
const COLOR_FILL := Color("1a0b26")

## Acciones que este modulo pudo dejar pulsadas (se sueltan al ocultarse).
const HELD := ["move_left", "move_right", "move_up", "move_down", "attack", "dash", "ability", "guard", "interact",
	"slot_1", "slot_2", "slot_3", "slot_4"]

var _pad: Control
var _touched := false  # hubo un toque real (modo Auto en dispositivos sin deteccion)
var _was_active := false
var _mouse_events: Dictionary = {}  # accion -> eventos de raton quitados mientras hay toque
var _shown := false

## Dedos activos: indice -> {"kind": "move"|"aim"|"btn", "origin": Vector2, "pos": Vector2, "btn": String}
var _fingers: Dictionary = {}
var _aim_dir := Vector2.RIGHT
var _move_vec := Vector2.ZERO
var _aim_vec := Vector2.ZERO
var _btn_down: Dictionary = {}  # id de boton -> true


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pad = Control.new()
	_pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pad.draw.connect(_draw_pad)
	add_child(_pad)
	_pad.visible = false


# ---------------------------------------------------------------- estado
## Controles tactiles encendidos segun Ajustes y el dispositivo.
func is_active() -> bool:
	match Settings.touch_mode:
		1:
			return true
		2:
			return false
	return DisplayServer.is_touchscreen_available() or _touched


func _in_run() -> bool:
	var rm := get_node_or_null("/root/RunManager")
	return get_tree().get_first_node_in_group("main") != null and get_tree().get_first_node_in_group("player") != null \
		and rm != null and rm.run_active


func _process(_delta: float) -> void:
	var active := is_active()
	if active != _was_active:
		_was_active = active
		_set_emulation(active)
	var show := active and _in_run() and not get_tree().paused
	if show != _shown:
		_shown = show
		_pad.visible = show
		if not show:
			_release_all()
	if not show:
		return
	_update_player()
	_pad.queue_redraw()


## Con toque activo el raton emulado no debe disparar/guardar (los toques sobre los
## botones tambien llegan como clic) y, en PC, el raton hace de dedo para poder probar.
func _set_emulation(on: bool) -> void:
	if on:
		for a in ["attack", "guard"]:
			if _mouse_events.has(a):
				continue
			var keep: Array = []
			var removed: Array = []
			for e in InputMap.action_get_events(a):
				if e is InputEventMouseButton:
					removed.append(e)
				else:
					keep.append(e)
			_mouse_events[a] = removed
			InputMap.action_erase_events(a)
			for e in keep:
				InputMap.action_add_event(a, e)
		if not DisplayServer.is_touchscreen_available():
			Input.emulate_touch_from_mouse = true  # solo pruebas en PC
	else:
		for a in _mouse_events:
			for e in _mouse_events[a]:
				InputMap.action_add_event(a, e)
		_mouse_events.clear()
		Input.emulate_touch_from_mouse = false


func _update_player() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not "aim_override" in p:
		return
	if _aim_vec.length() > DEADZONE:
		_aim_dir = _aim_vec.normalized()
	elif _move_vec.length() > DEADZONE:
		_aim_dir = _move_vec.normalized()  # sin apuntar, mira hacia donde caminas
	p.aim_override = _aim_dir


# ---------------------------------------------------------------- diseno
func _size() -> Vector2:
	return get_viewport().get_visible_rect().size


## Botones: id -> [centro, radio, accion, clave de texto]. Se recalcula con el tamano de pantalla.
func _buttons() -> Dictionary:
	var s := _size()
	var b := {
		"dash": [Vector2(s.x - 410, s.y - 165), 54.0, "dash", "TOUCH_DASH"],
		"ability": [Vector2(s.x - 360, s.y - 285), 46.0, "ability", "TOUCH_ABILITY"],
		"guard": [Vector2(s.x - 475, s.y - 255), 46.0, "guard", "TOUCH_GUARD"],
		"interact": [Vector2(s.x - 60, s.y - 270), 44.0, "interact", "TOUCH_INTERACT"],
		"pause": [Vector2(s.x - 40, 262), 24.0, "pause", "TOUCH_PAUSE"],
	}
	for i in 4:
		b["slot_%d" % (i + 1)] = [Vector2(40 + i * 62, s.y - 400), 27.0, "slot_%d" % (i + 1), "%d" % (i + 1)]
	return b


func _button_at(pos: Vector2) -> String:
	var bs := _buttons()
	for id in bs:
		if pos.distance_to(bs[id][0]) <= bs[id][1] * 1.2:
			return id
	return ""


## Zona de un stick nuevo, o "" si el toque cae fuera (HUD, narrador, centro).
func _stick_zone(pos: Vector2) -> String:
	var s := _size()
	if pos.y < BAND:
		return ""
	if Narrator._panel.visible and Narrator._panel.get_global_rect().grow(8).has_point(pos):
		return ""
	if pos.x < s.x * 0.42 and pos.y > s.y * 0.3:
		return "move"
	if pos.x > s.x * 0.5 and pos.y > s.y * 0.3:
		return "aim"
	return ""


# ---------------------------------------------------------------- entrada
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and Settings.touch_mode == 0 and not _touched:
		_touched = true  # primer toque real: aparecen los controles
	if not _shown:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, event.position)


func _touch_down(idx: int, pos: Vector2) -> void:
	var btn := _button_at(pos)
	if btn != "":
		_fingers[idx] = {"kind": "btn", "btn": btn, "pos": pos, "origin": pos}
		_press(btn, true)
		return
	var zone := _stick_zone(pos)
	if zone == "":
		return
	for f in _fingers.values():
		if f.kind == zone:
			return  # ese stick ya tiene dedo
	_fingers[idx] = {"kind": zone, "pos": pos, "origin": pos}
	_apply_sticks()


func _touch_drag(idx: int, pos: Vector2) -> void:
	if not _fingers.has(idx):
		return
	_fingers[idx].pos = pos
	_apply_sticks()


func _touch_up(idx: int) -> void:
	if not _fingers.has(idx):
		return
	var f: Dictionary = _fingers[idx]
	_fingers.erase(idx)
	if f.kind == "btn":
		_press(f.btn, false)
	else:
		_apply_sticks()


## Recalcula los vectores de ambos sticks y los vuelca a las acciones.
func _apply_sticks() -> void:
	_move_vec = Vector2.ZERO
	_aim_vec = Vector2.ZERO
	for f in _fingers.values():
		if f.kind == "move":
			_move_vec = ((f.pos - f.origin) / STICK_R).limit_length(1.0)
		elif f.kind == "aim":
			_aim_vec = ((f.pos - f.origin) / STICK_R).limit_length(1.0)
	var mv := _move_vec if _move_vec.length() > DEADZONE else Vector2.ZERO
	_axis("move_left", "move_right", mv.x)
	_axis("move_up", "move_down", mv.y)
	_set_action("attack", _aim_vec.length() > AIM_FIRE, 1.0)


func _axis(neg: String, pos: String, v: float) -> void:
	_set_action(neg, v < 0.0, -v)
	_set_action(pos, v > 0.0, v)


func _set_action(action: String, on: bool, strength: float) -> void:
	if on:
		Input.action_press(action, clampf(strength, 0.0, 1.0))
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _press(id: String, down: bool) -> void:
	var bs := _buttons()
	if not bs.has(id):
		return
	var action: String = bs[id][2]
	_btn_down[id] = down
	if action == "pause":
		if down:
			var e := InputEventAction.new()
			e.action = "pause"
			e.pressed = true
			Input.parse_input_event(e)
			var r := InputEventAction.new()
			r.action = "pause"
			Input.parse_input_event(r)
		return
	_set_action(action, down, 1.0)


func _release_all() -> void:
	_fingers.clear()
	_btn_down.clear()
	_move_vec = Vector2.ZERO
	_aim_vec = Vector2.ZERO
	for a in HELD:
		if Input.is_action_pressed(a):
			Input.action_release(a)
	var p := get_tree().get_first_node_in_group("player")
	if p != null and "aim_override" in p:
		p.aim_override = Vector2.ZERO


# ---------------------------------------------------------------- dibujo
func _draw_pad() -> void:
	var s := _size()
	_draw_stick(Vector2(190, s.y - 240), "move")
	_draw_stick(Vector2(s.x - 210, s.y - 235), "aim")
	var bs := _buttons()
	for id in bs:
		var down: bool = _btn_down.get(id, false)
		var c: Vector2 = bs[id][0]
		var r: float = bs[id][1]
		_pad.draw_circle(c, r, Color(COLOR_FILL, 0.55 if down else ALPHA_IDLE))
		_pad.draw_arc(c, r, 0.0, TAU, 40, Color(COLOR_RING, ALPHA_DOWN if down else 0.55), 3.0, true)
		var label := tr(bs[id][3])
		var fs := 16 if label.length() <= 4 else 13
		var font := HudStyle.FONT_BOLD
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_pad.draw_string(font, c + Vector2(-w * 0.5, fs * 0.38), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(HudStyle.CREAM, 0.95 if down else 0.8))


func _draw_stick(idle_center: Vector2, kind: String) -> void:
	var finger = null
	for f in _fingers.values():
		if f.kind == kind:
			finger = f
	var c := idle_center
	var knob := idle_center
	var a := ALPHA_IDLE
	if finger != null:
		c = finger.origin
		knob = c + (finger.pos - c).limit_length(STICK_R)
		a = ALPHA_DOWN
	_pad.draw_circle(c, STICK_R, Color(COLOR_FILL, a * 0.7))
	_pad.draw_arc(c, STICK_R, 0.0, TAU, 48, Color(COLOR_RING, a), 3.0, true)
	var hot: bool = kind == "aim" and _aim_vec.length() > AIM_FIRE
	_pad.draw_circle(knob, STICK_R * 0.42, Color("ff4f9a", a + 0.1) if hot else Color(HudStyle.CREAM, a))


# ---------------------------------------------------------------- foco
## Pausa al perder el foco de la ventana o pasar a segundo plano (movil), en todas las
## plataformas. El chiste de fourth_wall.gd sigue en pie: espera (hasta 90 s) a que cierres
## el menu para decir "volviste".
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT and what != NOTIFICATION_APPLICATION_PAUSED:
		return
	_release_all()
	var main := get_tree().get_first_node_in_group("main")
	if main == null or not _in_run() or get_tree().paused or get_tree().get_first_node_in_group("pause_menu") != null:
		return
	var cs := get_tree().current_scene
	if "--bot" in OS.get_cmdline_user_args() or (cs != null and "autoplay" in cs.scene_file_path):
		return  # el bot de pruebas no se detiene por perder el foco
	if "_ending" in main and main._ending:
		return
	PauseMenu.open(main)
