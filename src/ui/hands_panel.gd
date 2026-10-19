class_name HandsPanel
extends PanelContainer

## Panel de "MANOS" (abajo a la derecha): lo que haces con cada mano y con que tecla/boton.
##  - MANO DER.: el arma actual (icono, nombre, municion o calor) + glifo de "attack"; sin arma, puno.
##  - MANO IZQ.: escudo/alas/espolon ("guard") y grito/huevo ("ability") segun el heroe, cada uno con
##    su glifo; el que tiene recarga (AbilityGauge) se apaga y muestra su barrita mientras recarga.
## El dash no va aqui: su glifo y cargas van junto a la barra de estamina (dash_hint.gd).
## Los iconos son act_*.png en assets/sprites/ui/glyphs (tools/gen_input_glyphs.py): cambiar un PNG basta.
## Solo LEE al jugador (arma, _ammo, _heat, _dash_left...). Textos: locale/teclas.csv.
## H vuelve a mostrar la ayuda de teclas (KeyHelp); F1 es el menu de depuracion.

const ICON_DIR := "res://assets/sprites/ui/glyphs/"
const ACT_ICONS := {
	"GLYPH_GUARD_PITOCLES": "shield", "GLYPH_GUARD_VULVALQUIRIA": "wings", "GLYPH_GUARD_ORNITORRINCO": "spur",
	"GLYPH_ABILITY_VULVALQUIRIA": "scream", "GLYPH_ABILITY_ORNITORRINCO": "egg",
}
const DIM := Color(0.42, 0.4, 0.48)
const NAME_W := 96.0  # ancho de la columna del nombre del arma
const TXT := 8  # tamano de texto del panel (compacto; multiplo de 8, sin difuminar)
const BAR_W := 44.0  # ancho de las barritas de calor/recarga
const FADE_ALPHA := 0.25  # transparencia cuando el heroe pasa por debajo (como las cajas del narrador)
const FADE_MARGIN := 12.0
const BASE_ALPHA := 0.92
const MARGIN := 8.0  # separacion con el borde de la pantalla
const LIFT_GAP := 6.0  # aire entre el panel y la caja del narrador cuando lo deja encima
const LIFT_SPEED := 10.0  # suavizado de la subida/bajada (mayor = mas rapido)

var _player: Player
var _w_icon: TextureRect
var _w_name: Label
var _w_ammo: Label
var _w_heat: ColorRect
var _w_sig := ""
var _acts: Array = []  # {icon, bar, action}
var _help: KeyHelp
var _lift := 0.0  # px que sube el panel para no quedar bajo las cajas del narrador


func _init() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_right = -MARGIN
	offset_bottom = -MARGIN


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", HudStyle.panel_box(5))
	modulate.a = BASE_ALPHA
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_build_right(v)
	_build_left(v)
	var pause := InputGlyphs.labeled("pause", "GLYPH_PAUSE", Color(0.7, 0.66, 0.76), TXT)
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
	r.add_theme_constant_override("separation", 4)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _build_right(v: Control) -> void:
	_title(v, "GLYPH_HAND_R")
	var r := _row()
	_w_icon = _icon(24)
	r.add_child(_w_icon)
	var g := InputGlyph.new()
	g.action = "attack"
	r.add_child(g)
	var t := VBoxContainer.new()
	t.add_theme_constant_override("separation", 0)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_w_name = HudStyle.pixel_label("", TXT, HudStyle.CREAM)
	_w_name.custom_minimum_size.x = NAME_W
	# nombres largos: hasta dos lineas, nunca recortado a medias
	_w_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_w_name.max_lines_visible = 2
	_w_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_w_ammo = HudStyle.pixel_label("", TXT, HudStyle.GOLD)
	_w_heat = ColorRect.new()
	_w_heat.custom_minimum_size = Vector2(BAR_W, 3)
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
		var ic := _icon(20)
		ic.texture = load(ICON_DIR + "act_%s.png" % ACT_ICONS.get(h[1], "shield"))
		r.add_child(ic)
		var g := InputGlyph.new()
		g.action = h[0]
		r.add_child(g)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(HudStyle.pixel_label(h[1], TXT, HudStyle.CREAM))
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(BAR_W, 3)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.color = Color("ffd75a")
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.visible = false
		col.add_child(bar)
		r.add_child(col)
		v.add_child(r)
		_acts.append({"icon": ic, "bar": bar, "action": h[0], "main": h[0] == main_action})


func _process(delta: float) -> void:
	_avoid_narrator(delta)
	_fade_near_player(delta)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	_update_weapon()
	_update_left()


## Las cajas del narrador (y avisos) salen abajo al centro y a veces llegan hasta este panel: en
## vez de taparlo, el panel sube hasta quedar justo encima mientras se solapen, con transicion suave.
## Si no se solapan (cajas estrechas, ventana ancha) no se mueve. La transparencia de las cajas
## cuando el heroe baja hasta ellas sigue siendo cosa de Narrator.
func _avoid_narrator(delta: float) -> void:
	var target := 0.0
	var box: Rect2 = Narrator.occupied_rect()
	if box.size.y > 0.0:
		var mine := Rect2(global_position.x, get_viewport_rect().size.y - MARGIN - size.y, size.x, size.y)
		if mine.position.x < box.end.x + LIFT_GAP and mine.end.x > box.position.x - LIFT_GAP:
			# lo que falta para que el borde de abajo del panel quede sobre el borde de arriba de la caja
			target = maxf(0.0, mine.end.y - box.position.y + LIFT_GAP)
	_lift = lerpf(_lift, target, 1.0 - exp(-LIFT_SPEED * delta))
	if absf(_lift - target) < 0.5:
		_lift = target
	offset_bottom = -MARGIN - _lift


## Como las cajas del narrador: si el heroe pasa por debajo del panel, se vuelve transparente
## para no taparlo (ni a lo que tenga cerca).
func _fade_near_player(delta: float) -> void:
	var target := BASE_ALPHA
	var pl := _player if _player != null and is_instance_valid(_player) else null
	if pl:
		# rectangulo del heroe en pantalla (cuerpo de ~32x48 por el zoom de la camara)
		var xf := pl.get_global_transform_with_canvas()
		var half := Vector2(16, 24) * xf.get_scale()
		if get_global_rect().grow(FADE_MARGIN).intersects(Rect2(xf.origin - half, half * 2.0)):
			target = FADE_ALPHA
	modulate.a = move_toward(modulate.a, target, delta * 4.0)


## Nombre del arma en hasta dos lineas; lo que aun sobre se corta con "...".
func _fit_name(text: String) -> void:
	_w_name.text = text


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
		_fit_name(Loc.item_name(w))
		_w_ammo.text = "%d/%d" % [ammo, mag] if mag > 0 else ""
		_w_heat.visible = mag <= 0 and cd.has("heat_per_shot") or heat > 0.02
		_w_heat.custom_minimum_size.x = maxf(2.0, BAR_W * clampf(heat, 0.0, 1.0))
		_w_heat.color = Color("ff3a2a") if _player._overheated else Color("ff9a3a")
		_w_ammo.add_theme_color_override("font_color", Color("ff5a5a") if mag > 0 and ammo <= 0 else HudStyle.GOLD)
		if first and is_instance_valid(_help):
			_help.show_help("weapon")
	else:
		_w_icon.texture = load(ICON_DIR + "act_fist.png")
		_fit_name(tr("GLYPH_FIST"))
		_w_ammo.text = ""
		_w_heat.visible = false


func _update_left() -> void:
	var ab: HeroAbility = _player.ability
	for a in _acts:
		var cooling := false
		if a.main and ab != null and ab.gauge_visible and ab.gauge_value < 1.0:
			cooling = true
			a.bar.custom_minimum_size.x = maxf(2.0, BAR_W * ab.gauge_value)
			a.bar.color = ab.gauge_color
		a.bar.visible = cooling
		a.icon.modulate = DIM if cooling else Color.WHITE


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("help") and not e.is_echo() and is_instance_valid(_help):
		_help.show_help("manual")
