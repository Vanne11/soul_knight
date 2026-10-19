class_name InputGlyphs
extends RefCounted

## Glifos de entrada: "que tecla/boton hace esto" leyendo el InputMap (asi respeta project.godot
## y futuros remapeos). Sin autoload: la clase es estatica y crea sola un vigilante (Watcher)
## colgado de la raiz que recuerda el ULTIMO dispositivo tocado:
##   - teclado/raton: InputEventKey o InputEventMouseButton (el movimiento del raton no cuenta);
##   - mando: InputEventJoypadButton o un eje que pase de 0.5 (no cuenta el ruido del stick).
## Cambia en vivo y avisa por `InputGlyphs.watcher().device_changed`.
##
## Uso:
##   InputGlyph (src/ui/input_glyph.gd)   Control con `action`, se redibuja solo al cambiar.
##   InputGlyphs.text("ability")          "[F]" / "(B)" para Labels.
##   InputGlyphs.bbcode("interact")       para RichTextLabel: imagen (mando/raton) o tecla en caja.
##   InputGlyphs.localize(texto)          cambia los "[E]" de un texto por el glifo de "interact".
##   InputGlyphs.labeled("ability", "TXT")  HBox con glifo + etiqueta traducida.
## Arte: assets/sprites/ui/glyphs (sale de tools/gen_input_glyphs.py), a 2x como el resto del HUD.
## Textos: locale/teclas.csv.

const DIR := "res://assets/sprites/ui/glyphs/"
const SCALE := 2
## Acciones que no existen en el InputMap pero tienen tecla fija (mapa: M, ver minimap.gd).
const FIXED_KEYS := {"map": KEY_M, "map_tab": KEY_TAB}
## Y su boton de mando (pestanas del mapa grande: L1/R1 las cambian, se muestra RB).
const FIXED_PADS := {"map_tab": JOY_BUTTON_RIGHT_SHOULDER}
const PAD_ICONS := {
	JOY_BUTTON_A: "pad_a", JOY_BUTTON_B: "pad_b", JOY_BUTTON_X: "pad_x", JOY_BUTTON_Y: "pad_y",
	JOY_BUTTON_BACK: "pad_back", JOY_BUTTON_START: "pad_start",
	JOY_BUTTON_LEFT_SHOULDER: "pad_lb", JOY_BUTTON_RIGHT_SHOULDER: "pad_rb",
	JOY_BUTTON_DPAD_UP: "pad_dpad_up", JOY_BUTTON_DPAD_DOWN: "pad_dpad_down",
	JOY_BUTTON_DPAD_LEFT: "pad_dpad_left", JOY_BUTTON_DPAD_RIGHT: "pad_dpad_right",
}
const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "BACK", JOY_BUTTON_START: "START",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-UP", JOY_BUTTON_DPAD_DOWN: "D-DOWN",
	JOY_BUTTON_DPAD_LEFT: "D-LEFT", JOY_BUTTON_DPAD_RIGHT: "D-RIGHT",
}
## Teclas con nombre propio (clave de teclas.csv); el resto sale de OS.get_keycode_string.
const KEY_NAMES := {
	KEY_SPACE: "GLYPH_KEY_SPACE", KEY_ESCAPE: "GLYPH_KEY_ESC", KEY_ENTER: "GLYPH_KEY_ENTER",
	KEY_KP_ENTER: "GLYPH_KEY_ENTER", KEY_TAB: "GLYPH_KEY_TAB", KEY_SHIFT: "GLYPH_KEY_SHIFT",
	KEY_CTRL: "GLYPH_KEY_CTRL", KEY_ALT: "GLYPH_KEY_ALT", KEY_BACKSPACE: "GLYPH_KEY_BACK",
}
const KEY_SHORT := {KEY_UP: "^", KEY_DOWN: "v", KEY_LEFT: "<", KEY_RIGHT: ">"}

static var _w: Node = null
static var _tex_cache := {}


## Vigilante del dispositivo. Se crea al primer uso y cuelga de la raiz (deferred: el primer
## uso suele ser en un _ready, con el arbol ocupado).
static func watcher() -> Node:
	if _w == null or not is_instance_valid(_w):
		_w = Watcher.new()
		var tree := Engine.get_main_loop() as SceneTree
		tree.root.add_child.call_deferred(_w)
	return _w


static func is_pad() -> bool:
	return watcher().pad


## Para pruebas o un ajuste del jugador: fuerza "pad" o "keyboard" (y avisa).
static func force_device(pad: bool) -> void:
	watcher().set_pad(pad)


## Descripcion del glifo de una accion para el dispositivo actual (o el forzado con `pad`):
## {kind: "tex"|"key"|"none", tex: Texture2D, label: String}. Si la accion no tiene nada para
## ese dispositivo, cae al otro (p.ej. el mapa, que solo tiene tecla).
static func glyph(action: String, pad := is_pad()) -> Dictionary:
	var g := _lookup(action, pad)
	if g.kind == "none":
		g = _lookup(action, not pad)
	return g


static func _lookup(action: String, pad: bool) -> Dictionary:
	var events: Array = []
	if FIXED_KEYS.has(action):
		var k := InputEventKey.new()
		k.physical_keycode = FIXED_KEYS[action]
		events = [k] if not pad else []
		if pad and FIXED_PADS.has(action):
			var b := InputEventJoypadButton.new()
			b.button_index = FIXED_PADS[action]
			events = [b]
	elif InputMap.has_action(action):
		events = InputMap.action_get_events(action)
	if pad:
		for e in events:
			if e is InputEventJoypadButton:
				var t := _tex(PAD_ICONS.get(e.button_index, ""))
				return {"kind": "tex", "tex": t, "label": PAD_NAMES.get(e.button_index, "?")} if t \
					else {"kind": "key", "tex": null, "label": PAD_NAMES.get(e.button_index, "?")}
		for e in events:
			if e is InputEventJoypadMotion and e.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
				var lt: bool = e.axis == JOY_AXIS_TRIGGER_LEFT
				return {"kind": "tex", "tex": _tex("pad_lt" if lt else "pad_rt"), "label": "LT" if lt else "RT"}
	else:
		for e in events:
			if e is InputEventMouseButton:
				var which := ""
				match e.button_index:
					MOUSE_BUTTON_LEFT: which = "left"
					MOUSE_BUTTON_RIGHT: which = "right"
				if which != "":
					return {"kind": "tex", "tex": _tex("mouse_" + which), "label": tr_key("GLYPH_MOUSE_" + which.to_upper())}
			elif e is InputEventKey:
				return {"kind": "key", "tex": null, "label": key_name(e)}
	return {"kind": "none", "tex": null, "label": ""}


static func tr_key(key: String) -> String:
	var node := Engine.get_main_loop() as SceneTree
	return node.root.tr(key) if node else key


## Nombre corto de la tecla de un evento (siguiendo la distribucion del teclado del jugador).
static func key_name(e: InputEventKey) -> String:
	var code: int = e.keycode
	if e.physical_keycode != 0 and DisplayServer.get_name() != "headless":
		code = DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode)
		if code == 0:
			code = e.physical_keycode
	elif code == 0:
		code = e.physical_keycode
	if KEY_NAMES.has(code):
		return tr_key(KEY_NAMES[code])
	if KEY_SHORT.has(code):
		return KEY_SHORT[code]
	return OS.get_keycode_string(code).to_upper()


static func _tex(name: String) -> Texture2D:
	if name == "":
		return null
	if not _tex_cache.has(name):
		_tex_cache[name] = load(DIR + name + ".png")
	return _tex_cache[name]


static func keycap_tex() -> Texture2D:
	return _tex("key_cap")


## Texto plano para Labels: "[F]", "[CLIC DER]", "(A)".
static func text(action: String, pad := is_pad()) -> String:
	var g := glyph(action, pad)
	if g.kind == "none":
		return ""
	if g.tex != null and g.label in ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "START", "BACK"]:
		return "(%s)" % g.label
	return "[%s]" % g.label


## BBCode para RichTextLabel: imagen del glifo (mando/raton) o la tecla en caja clara.
static func bbcode(action: String, pad := is_pad(), height := 20) -> String:
	var g := glyph(action, pad)
	if g.kind == "none":
		return ""
	if g.tex != null:
		var t: Texture2D = g.tex
		var w := int(round(float(t.get_width()) / t.get_height() * height))
		return "[img=%dx%d]%s[/img]" % [w, height, t.resource_path]
	return "[bgcolor=#e8dcc0][color=#0d0b0f] %s [/color][/bgcolor]" % g.label


## Sustituye "[E]" (la forma vieja de los textos) por el glifo de "interact".
static func localize(txt: String) -> String:
	if txt.contains("[E]"):
		return txt.replace("[E]", bbcode("interact"))
	return txt


## HBox "glifo + etiqueta" para el HUD (clave de teclas.csv ya traducida por el Label).
static func labeled(action: String, label_key: String, color := Color("fff1d6"), font_size := 16) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_END
	var g := InputGlyph.new()
	g.action = action
	box.add_child(g)
	var l := HudStyle.pixel_label(label_key, font_size, color)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(l)
	# sin glifo (accion sin nada que mostrar) tampoco etiqueta
	g.visibility_changed.connect(func(): l.visible = g.visible)
	return box


## Vigilante: ultimo dispositivo usado.
class Watcher extends Node:
	signal device_changed(pad: bool)
	var pad := false

	func _init() -> void:
		name = "InputGlyphsWatcher"
		process_mode = Node.PROCESS_MODE_ALWAYS
		pad = false

	func set_pad(v: bool) -> void:
		if v != pad:
			pad = v
			device_changed.emit(pad)

	func _input(e: InputEvent) -> void:
		if e is InputEventJoypadButton and e.pressed:
			set_pad(true)
		elif e is InputEventJoypadMotion and absf(e.axis_value) > 0.5:
			set_pad(true)
		elif e is InputEventKey and e.pressed:
			set_pad(false)
		elif e is InputEventMouseButton and e.pressed:
			set_pad(false)
