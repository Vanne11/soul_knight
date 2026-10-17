class_name KeyHelp
extends PanelContainer

## Ayuda breve y NO bloqueante con glifos: "[glifo] Atacar · [glifo] Dash · [glifo] Guardia ...".
## Sale al empezar la primera partida y al recoger la primera arma (cada motivo una sola vez, se
## guarda en user://teclas_ayuda.cfg); se va sola a los 12 s o al usar cualquiera de las acciones
## (pasado 1.5 s de gracia). H la muestra de nuevo cuando quieras (reason "manual", sin guardar).
## Los glifos siguen al dispositivo (mando/teclado). Textos: locale/teclas.csv.

const PATH := "user://teclas_ayuda.cfg"
const LIFE := 12.0
const GRACE := 1.5
const ACTIONS := ["attack", "dash", "interact"]

var _t := 0.0
var _row: HBoxContainer


## Olvida lo ya mostrado (para un futuro boton "ver ayuda de teclas" en Ajustes/pausa).
static func reset_seen() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func _seen(reason: String) -> bool:
	var cf := ConfigFile.new()
	return cf.load(PATH) == OK and bool(cf.get_value("seen", reason, false))


static func _mark(reason: String) -> void:
	var cf := ConfigFile.new()
	cf.load(PATH)
	cf.set_value("seen", reason, true)
	cf.save(PATH)


func _init() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = HUD.BAND + 8


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_stylebox_override("panel", HudStyle.panel_box(8))
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 18)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	set_process(false)


## reason: "start", "weapon" (una vez cada uno) o "manual" (siempre).
func show_help(reason: String) -> void:
	if reason != "manual":
		if _seen(reason):
			return
		_mark(reason)
	for c in _row.get_children():
		c.queue_free()
	var rm := get_node("/root/RunManager")
	var hints: Array = AbilityGauge.HINTS.get(rm.character, [])
	var items: Array = [["attack", "GLYPH_HELP_ATTACK"], ["dash", "GLYPH_HELP_DASH"]]
	for h in hints:
		items.append([h[0], "GLYPH_HELP_GUARD" if h[0] == "guard" else "GLYPH_HELP_ABILITY"])
	items.append(["interact", "GLYPH_HELP_INTERACT"])
	for it in items:
		var b := InputGlyphs.labeled(it[0], it[1], HudStyle.CREAM, 16)
		b.alignment = BoxContainer.ALIGNMENT_BEGIN
		_row.add_child(b)
	_t = 0.0
	modulate.a = 1.0
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	_t += delta
	var used := false
	if _t > GRACE:
		for a in ACTIONS + ["guard", "ability"]:
			if InputMap.has_action(a) and Input.is_action_just_pressed(a):
				used = true
	if used or _t > LIFE:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func(): visible = false)
		set_process(false)
