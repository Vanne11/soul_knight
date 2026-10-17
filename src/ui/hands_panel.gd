class_name HandsPanel
extends PanelContainer

## Panel de "MANOS" (abajo a la derecha): lo que haces con cada mano y con que tecla/boton.
##  - MANO DER.: el arma actual (icono, nombre, municion o calor) + glifo de "attack"; sin arma, puno.
##  - MANO IZQ.: escudo/alas/espolon ("guard") y grito/huevo ("ability") segun el heroe, cada uno con
##    su glifo; el que tiene recarga (AbilityGauge) se apaga y muestra su barrita mientras recarga.
## El dash no va aqui: su glifo y cargas van junto a la barra de estamina (dash_hint.gd).
## Los iconos son act_*.png en assets/sprites/ui/glyphs (tools/gen_input_glyphs.py): cambiar un PNG basta.
## Solo LEE al jugador (arma, _ammo, _heat, _dash_left...). Textos: locale/teclas.csv.
## F1 vuelve a mostrar la ayuda de teclas (KeyHelp).

const ICON_DIR := "res://assets/sprites/ui/glyphs/"
const ACT_ICONS := {
	"GLYPH_GUARD_PITOCLES": "shield", "GLYPH_GUARD_VULVALQUIRIA": "wings", "GLYPH_GUARD_ORNITORRINCO": "spur",
	"GLYPH_ABILITY_VULVALQUIRIA": "scream", "GLYPH_ABILITY_ORNITORRINCO": "egg",
}
const DIM := Color(0.42, 0.4, 0.48)

var _player: Player
var _w_icon: TextureRect
var _w_name: Label
var _w_ammo: Label
var _w_heat: ColorRect
var _w_sig := ""
var _acts: Array = []  # {icon, bar, action}
var _help: KeyHelp


func _init() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -8
	offset_bottom = -8


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", HudStyle.panel_box(8))
	modulate.a = 0.92
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_build_right(v)
	_build_left(v)
	var pause := InputGlyphs.labeled("pause", "GLYPH_PAUSE", Color(0.7, 0.66, 0.76), 14)
	v.add_child(pause)
	_help = KeyHelp.new()
	get_parent().add_child.call_deferred(_help)
	_help.show_help.call_deferred("start")


func _title(v: Control, key: String) -> void:
	v.add_child(HudStyle.pixel_label(key, 8, Color("b08d4a")))


func _icon(size: float) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = Vector2(size, size)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_right(v: Control) -> void:
	_title(v, "GLYPH_HAND_R")
	var r := _row()
	_w_icon = _icon(32)
	r.add_child(_w_icon)
	var g := InputGlyph.new()
	g.action = "attack"
	r.add_child(g)
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 0)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_w_name = HudStyle.pixel_label("", 16, HudStyle.CREAM)
	_w_name.custom_minimum_size.x = 110
	_w_name.clip_text = true
	_w_ammo = HudStyle.pixel_label("", 16, HudStyle.GOLD)
	_w_heat = ColorRect.new()
	_w_heat.custom_minimum_size = Vector2(60, 4)
	_w_heat.color = Color("ff7a3a")
	_w_heat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_w_heat.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	t.add_child(_w_name)
	t.add_child(_w_ammo)
	t.add_child(_w_heat)
	r.add_child(t)
	v.add_child(r)


func _build_left(v: Control) -> void:
	var rm := get_node("/root/RunManager")
	var hints: Array = AbilityGauge.HINTS.get(rm.character, [])
	if hints.is_empty():
		return
	_title(v, "GLYPH_HAND_L")
	var main_action := AbilityGauge.main_action(rm.character)
	for h in hints:
		var r := _row()
		var ic := _icon(28)
		ic.texture = load(ICON_DIR + "act_%s.png" % ACT_ICONS.get(h[1], "shield"))
		r.add_child(ic)
		var g := InputGlyph.new()
		g.action = h[0]
		r.add_child(g)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(HudStyle.pixel_label(h[1], 16, HudStyle.CREAM))
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(60, 4)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.color = Color("ffd75a")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		col.add_child(bar)
		r.add_child(col)
		v.add_child(r)
		_acts.append({"icon": ic, "bar": bar, "action": h[0], "main": h[0] == main_action})


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	_update_weapon()
	_update_left()


func _update_weapon() -> void:
	var w: Item = _player.current_weapon
	var cd: Dictionary = w.custom_data if w else {}
	var mag := int(cd.get("magazine", 0))
	var ammo: int = _player._ammo
	var heat: float = _player._heat / Player.HEAT_MAX
	var sig := "%s|%d|%d|%d|%s" % [w.id if w else "", mag, ammo, int(heat * 20.0), _player._overheated]
	if sig == _w_sig:
		return
	var first := w != null and (_w_sig == "" or _w_sig.begins_with("|"))
	_w_sig = sig
	if w:
		_w_icon.texture = w.sprite if w.sprite else load(ICON_DIR + "act_fist.png")
		_w_name.text = Loc.item_name(w)
		_w_ammo.text = "%d/%d" % [ammo, mag] if mag > 0 else ""
		_w_heat.visible = mag <= 0 and cd.has("heat_per_shot") or heat > 0.02
		_w_heat.custom_minimum_size.x = maxf(2.0, 60.0 * clampf(heat, 0.0, 1.0))
		_w_heat.color = Color("ff3a2a") if _player._overheated else Color("ff9a3a")
		_w_ammo.add_theme_color_override("font_color", Color("ff5a5a") if mag > 0 and ammo <= 0 else HudStyle.GOLD)
		if first and is_instance_valid(_help):
			_help.show_help("weapon")
	else:
		_w_icon.texture = load(ICON_DIR + "act_fist.png")
		_w_name.text = tr("GLYPH_FIST")
		_w_ammo.text = ""
		_w_heat.visible = false


func _update_left() -> void:
	var ab: HeroAbility = _player.ability
	for a in _acts:
		var cooling := false
		if a.main and ab != null and ab.gauge_visible and ab.gauge_value < 1.0:
			cooling = true
			a.bar.custom_minimum_size.x = maxf(2.0, 60.0 * ab.gauge_value)
			a.bar.color = ab.gauge_color
		a.bar.visible = cooling
		a.icon.modulate = DIM if cooling else Color.WHITE


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.physical_keycode == KEY_F1 and is_instance_valid(_help):
		_help.show_help("manual")
