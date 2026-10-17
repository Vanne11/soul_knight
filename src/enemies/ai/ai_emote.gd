class_name AIEmote
extends Node2D

## Emociones visibles sobre la cabeza de un enemigo: iconos pixel art ("!", "?", sudor, vena,
## "z", "...", bandera blanca, corazon) y una burbuja de texto corta con humor.
## Los iconos NO son archivos: salen de los mapas de caracteres de ICONS (solo el relleno; el
## contorno negro se genera solo) y se cachean como ImageTexture. Para un icono nuevo basta
## con anadir una entrada en ICONS. Lo crea EnemyAI; no hace falta instanciarlo a mano.

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const OUTLINE := Color(0.06, 0.03, 0.09, 1.0)
const PAL := {
	"y": Color("ffd23a"), "r": Color("e8322e"), "b": Color("4aa8ff"), "w": Color("ffffff"),
	"c": Color("bfe4ff"), "g": Color("a0a0ae"), "p": Color("ff6fa5"), "o": Color("ff9a2e"),
}
const ICONS := {
	"alert": ["yyy", "yyy", "yyy", "yyy", "yyy", "...", "yyy", "yyy"],
	"question": [".ccc.", "cc.cc", "...cc", "..cc.", ".cc..", ".....", ".cc..", ".cc.."],
	"sweat": ["..b..", "..b..", ".bbb.", ".bwb.", "bbbbb", "bbbbb", ".bbb."],
	"vein": ["..rr.rr..", ".rrr.rrr.", "rrr...rrr", "rr.....rr", ".........", "rr.....rr", "rrr...rrr", ".rrr.rrr.", "..rr.rr.."],
	"sleep": ["ccccc", "...cc", "..cc.", ".cc..", "ccccc"],
	"dots": ["gg.gg.gg", "gg.gg.gg"],
	"flag": ["gwwwww", "gwwwww", "gwwwww", "g.....", "g.....", "g.....", "g....."],
	"heart": [".pp.pp.", "ppppppp", "ppppppp", ".ppppp.", "..ppp..", "...p..."],
}
const SCALE := 2.0
const MAX_W := 96.0  ## ancho maximo de la burbuja antes de partir en lineas

static var _tex: Dictionary = {}

var _icon: Sprite2D
var _label: Label
var _icon_t := 0.0
var _label_t := 0.0
var _icon_h := 0.0


static func texture(icon_name: String) -> ImageTexture:
	if _tex.has(icon_name):
		return _tex[icon_name]
	var rows: Array = ICONS.get(icon_name, [])
	if rows.is_empty():
		return null
	var w := 0
	for r in rows:
		w = maxi(w, String(r).length())
	var h := rows.size()
	var img := Image.create_empty(w + 2, h + 2, false, Image.FORMAT_RGBA8)
	var fill := {}
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if PAL.has(ch):
				fill[Vector2i(x + 1, y + 1)] = PAL[ch]
	for p in fill:
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var q: Vector2i = p + Vector2i(dx, dy)
				if not fill.has(q) and q.x >= 0 and q.y >= 0 and q.x < w + 2 and q.y < h + 2:
					img.set_pixelv(q, OUTLINE)
	for p in fill:
		img.set_pixelv(p, fill[p])
	var t := ImageTexture.create_from_image(img)
	_tex[icon_name] = t
	return t


## top_y: y (en el espacio del enemigo) del borde superior del sprite.
func setup(top_y: float) -> void:
	position = Vector2(0, top_y - 14.0)
	z_index = 100
	_icon = Sprite2D.new()
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.scale = Vector2(SCALE, SCALE)
	_icon.visible = false
	add_child(_icon)
	_label = Label.new()
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", OUTLINE)
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_constant_override("line_spacing", -2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.visible = false
	add_child(_label)


func show_icon(icon_name: String, secs := 1.1) -> void:
	var t := texture(icon_name)
	if t == null or _icon == null:
		return
	_icon.texture = t
	_icon_h = t.get_height() * SCALE
	_icon.visible = true
	_icon.modulate.a = 1.0
	_icon_t = secs
	_icon.scale = Vector2(SCALE, SCALE) * 0.4
	var tw := create_tween()
	tw.tween_property(_icon, "scale", Vector2(SCALE, SCALE), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_place_label()


func say(text: String, secs := 2.0) -> void:
	if text == "" or _label == null:
		return
	_label.text = text
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.custom_minimum_size = Vector2.ZERO
	var natural := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	if natural > MAX_W:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size = Vector2(MAX_W, 0)
	_label.reset_size()
	_label_t = secs
	_label.visible = true
	_label.modulate.a = 1.0
	_place_label()


func clear_icon() -> void:
	_icon_t = 0.0
	if _icon:
		_icon.visible = false
	_place_label()


func _place_label() -> void:
	if _label == null:
		return
	var w := maxf(_label.get_minimum_size().x, _label.custom_minimum_size.x)
	_label.size = Vector2(w, 0.0)
	var lines := maxi(_label.get_line_count(), 1)
	var h := lines * FONT.get_height(8) + (lines - 1) * -2.0
	_label.size = Vector2(w, h)
	var icon_up := _icon_h * 0.5 + 3.0 if (_icon != null and _icon.visible) else 0.0
	_label.position = Vector2(-w * 0.5, -icon_up - h - 2.0)


func _process(delta: float) -> void:
	if _icon_t > 0.0:
		_icon_t -= delta
		if _icon_t <= 0.3 and _icon != null:
			_icon.modulate.a = maxf(_icon_t / 0.3, 0.0)
		if _icon_t <= 0.0 and _icon != null:
			_icon.visible = false
			_place_label()
	if _label_t > 0.0:
		_label_t -= delta
		if _label_t <= 0.4:
			_label.modulate.a = maxf(_label_t / 0.4, 0.0)
		if _label_t <= 0.0:
			_label.visible = false
