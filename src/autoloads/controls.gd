extends Node

## Controles reasignables (teclado/raton y mando). Fuente de verdad de "que tecla hace que":
## parte del InputMap de project.godot (los valores por defecto), aplica encima lo que el
## jugador cambio y lo guarda en user://settings.cfg, seccion [controls] (junto a los demas
## ajustes; Settings.save_settings conserva esa seccion).
##
## Cada accion tiene SLOTS_KB casillas de teclado/raton y SLOTS_PAD de mando. Un "codigo" es
## un texto corto: "k:65" tecla fisica (KEY_A), "m:1" boton del raton, "b:0" boton del mando,
## "t:4" gatillo (eje 4 = LT, 5 = RT). Los ejes de los sticks no se reasignan: se conservan
## tal cual (el stick izquierdo siempre mueve).
## El HUD lee el InputMap (InputGlyphs), asi que al cambiar aqui todo se hidrata solo;
## InputGlyphs.watcher().bindings_changed avisa a los glifos vivos.
##   Controls.set_code(accion, "kb"|"pad", casilla, codigo) -> accion que perdio ese codigo ("" si ninguna)
##   Controls.reset("kb"|"pad"|"")   restaura por defecto (vacio = todo)

signal changed

const KB := "kb"
const PAD := "pad"
const SLOTS := {KB: 3, PAD: 2}
const SECTION := "controls"
## [accion, clave de locale/controles.csv]. Orden = orden en pantalla.
const ACTIONS := [
	["move_up", "CTRL_MOVE_UP"], ["move_down", "CTRL_MOVE_DOWN"],
	["move_left", "CTRL_MOVE_LEFT"], ["move_right", "CTRL_MOVE_RIGHT"],
	["attack", "CTRL_ATTACK"], ["guard", "CTRL_GUARD"], ["ability", "CTRL_ABILITY"],
	["dash", "CTRL_DASH"], ["interact", "CTRL_INTERACT"], ["use_item", "CTRL_USE_ITEM"],
	["slot_1", "CTRL_SLOT_1"], ["slot_2", "CTRL_SLOT_2"], ["slot_3", "CTRL_SLOT_3"], ["slot_4", "CTRL_SLOT_4"],
	["map", "CTRL_MAP"], ["help", "CTRL_HELP"], ["pause", "CTRL_PAUSE"],
]
## Acciones nuevas que no estan en project.godot: [accion, codigo teclado, codigo mando]
const EXTRA_ACTIONS := [["map", "k:%d" % KEY_M, "b:%d" % JOY_BUTTON_BACK], ["help", "k:%d" % KEY_H, ""]]

var _defaults := {}  # accion -> {kb: Array[String], pad: Array[String]}
var _slots := {}     # idem, lo vigente
var _fixed := {}     # accion -> Array[InputEvent] (ejes de stick: no se tocan)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_snapshot_defaults()
	load_saved()
	for a in ACTIONS:
		_apply(a[0])


# ---------------------------------------------------------------- consulta
func label_key(action: String) -> String:
	for a in ACTIONS:
		if a[0] == action:
			return a[1]
	return action


func slots(action: String, device: String) -> Array:
	return (_slots[action][device] as Array).duplicate()


## Codigos NO vacios, en orden.
func codes(action: String, device: String) -> Array:
	return (_slots[action][device] as Array).filter(func(c): return c != "")


func is_default(action: String, device: String) -> bool:
	return _slots[action][device] == _defaults[action][device]


## Acciones que comparten el codigo `code` en ese dispositivo (para marcar conflictos).
func users_of(code: String, device: String) -> Array:
	var out := []
	for a in ACTIONS:
		if code in _slots[a[0]][device]:
			out.append(a[0])
	return out


## Conflicto vivo: la accion tiene un codigo que otra accion tambien usa.
func has_conflict(action: String, device: String) -> bool:
	for c in codes(action, device):
		if users_of(c, device).size() > 1:
			return true
	return false


func is_unassigned(action: String, device: String) -> bool:
	return codes(action, device).is_empty() and (device == KB or not _has_stick(action))


func _has_stick(action: String) -> bool:
	return not (_fixed.get(action, []) as Array).is_empty()


# ---------------------------------------------------------------- cambios
## Asigna `code` a la casilla `slot`. Si otra accion ya lo usaba en ese dispositivo se lo
## quita (devuelve su nombre para avisar). code "" = vaciar la casilla.
func set_code(action: String, device: String, slot: int, code: String) -> String:
	var stolen := ""
	if code != "":
		for a in ACTIONS:
			var other: String = a[0]
			var arr: Array = _slots[other][device]
			for i in arr.size():
				if arr[i] == code and not (other == action and i == slot):
					arr[i] = ""
					if other != action and stolen == "":
						stolen = other
					_apply(other)
	(_slots[action][device] as Array)[slot] = code
	_apply(action)
	_commit()
	return stolen


## device "kb" / "pad" / "" (todo): restaura lo de project.godot.
func reset(device := "") -> void:
	for a in ACTIONS:
		for d in [KB, PAD]:
			if device == "" or device == d:
				_slots[a[0]][d] = (_defaults[a[0]][d] as Array).duplicate()
		_apply(a[0])
	_commit()


func _commit() -> void:
	save()
	changed.emit()
	InputGlyphs.watcher().bindings_changed.emit()


# ---------------------------------------------------------------- InputMap <-> codigos
func _snapshot_defaults() -> void:
	for x in EXTRA_ACTIONS:
		if not InputMap.has_action(x[0]):
			InputMap.add_action(x[0], 0.2)
			if x[1] != "":
				InputMap.action_add_event(x[0], event_from(x[1]))
			if x[2] != "":
				InputMap.action_add_event(x[0], event_from(x[2]))
	for a in ACTIONS:
		var act: String = a[0]
		var kb := []
		var pad := []
		var fixed := []
		for e in InputMap.action_get_events(act):
			var c := code_of(e)
			if c.begins_with("k:") or c.begins_with("m:"):
				kb.append(c)
			elif c.begins_with("b:") or c.begins_with("t:"):
				pad.append(c)
			else:
				fixed.append(e)
		_defaults[act] = {KB: _fit(kb, SLOTS[KB]), PAD: _fit(pad, SLOTS[PAD])}
		_slots[act] = {KB: _defaults[act][KB].duplicate(), PAD: _defaults[act][PAD].duplicate()}
		_fixed[act] = fixed


static func _fit(list: Array, n: int) -> Array:
	var out := list.slice(0, n)
	while out.size() < n:
		out.append("")
	return out


func _apply(action: String) -> void:
	InputMap.action_erase_events(action)
	for d in [KB, PAD]:
		for c in _slots[action][d]:
			if c != "":
				InputMap.action_add_event(action, event_from(c))
	for e in _fixed[action]:
		InputMap.action_add_event(action, e)


## Codigo de un evento ("" si no es reasignable).
static func code_of(e: InputEvent) -> String:
	if e is InputEventKey:
		var k: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		return "k:%d" % k if k != 0 else ""
	if e is InputEventMouseButton:
		return "m:%d" % e.button_index
	if e is InputEventJoypadButton:
		return "b:%d" % e.button_index
	if e is InputEventJoypadMotion and e.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		return "t:%d" % e.axis
	return ""


static func event_from(code: String) -> InputEvent:
	var n := int(code.substr(2))
	match code.substr(0, 1):
		"k":
			var k := InputEventKey.new()
			k.physical_keycode = n as Key
			return k
		"m":
			var m := InputEventMouseButton.new()
			m.button_index = n as MouseButton
			return m
		"b":
			var b := InputEventJoypadButton.new()
			b.button_index = n as JoyButton
			return b
		"t":
			var t := InputEventJoypadMotion.new()
			t.axis = n as JoyAxis
			t.axis_value = 1.0
			return t
	return null


# ---------------------------------------------------------------- guardado
func load_saved() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(Settings.PATH) != OK or not cfg.has_section(SECTION):
		return
	for a in ACTIONS:
		for d in [KB, PAD]:
			var key := "%s.%s" % [a[0], d]
			if not cfg.has_section_key(SECTION, key):
				continue
			var parts := str(cfg.get_value(SECTION, key)).split("|", true)
			var out := []
			for p in parts:
				# solo codigos validos del dispositivo (el archivo lo puede tocar cualquiera)
				var ok: bool = p == "" or (p.length() > 2 and p[1] == ":" and p.substr(2).is_valid_int() \
					and (p[0] in ["k", "m"] if d == KB else p[0] in ["b", "t"]))
				out.append(p if ok else "")
			_slots[a[0]][d] = _fit(out, SLOTS[d])


## Guarda solo lo que difiere del defecto (si todo es por defecto, la seccion desaparece).
func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(Settings.PATH)
	if cfg.has_section(SECTION):
		cfg.erase_section(SECTION)
	for a in ACTIONS:
		for d in [KB, PAD]:
			if not is_default(a[0], d):
				cfg.set_value(SECTION, "%s.%s" % [a[0], d], "|".join(PackedStringArray(_slots[a[0]][d])))
	cfg.save(Settings.PATH)
