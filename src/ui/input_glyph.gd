class_name InputGlyph
extends Control

## Glifo de una accion del InputMap ("ability", "slot_1"...). Se redibuja solo al cambiar el
## dispositivo (teclado/raton <-> mando) y se esconde si la accion no tiene nada que mostrar.
## Arte a 2x (1 px de arte = 2x2). Ver input_glyphs.gd.

@export var action := "":
	set(v):
		action = v
		if is_node_ready():
			_refresh()
@export var art_scale := InputGlyphs.SCALE

var _g := {"kind": "none", "tex": null, "label": ""}
var _w := 0.0
var _font_size := 16


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	InputGlyphs.watcher().device_changed.connect(func(_p): _refresh())
	_refresh()


func _refresh() -> void:
	_g = InputGlyphs.glyph(action)
	_font_size = 8 * art_scale
	var s := float(art_scale)
	match _g.kind:
		"tex":
			var t: Texture2D = _g.tex
			custom_minimum_size = Vector2(t.get_width(), t.get_height()) * s
		"key":
			var tw := HudStyle.FONT.get_string_size(_g.label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
			# ancho en pixeles de arte enteros, minimo cuadrado
			var art_w := maxf(14.0, ceilf((tw + 6.0 * s) / s))
			custom_minimum_size = Vector2(art_w, 14.0) * s
		_:
			custom_minimum_size = Vector2.ZERO
	size = custom_minimum_size
	visible = _g.kind != "none"
	tooltip_text = ""
	queue_redraw()


func _draw() -> void:
	var s := float(art_scale)
	match _g.kind:
		"tex":
			var t: Texture2D = _g.tex
			draw_texture_rect(t, Rect2(Vector2.ZERO, Vector2(t.get_width(), t.get_height()) * s), false)
		"key":
			var tex := InputGlyphs.keycap_tex()
			if tex == null:
				return
			var sb := StyleBoxTexture.new()
			sb.texture = tex
			sb.set_texture_margin_all(4)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
			draw_style_box(sb, Rect2(Vector2.ZERO, size / s))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var f := HudStyle.FONT
			var tw := f.get_string_size(_g.label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
			var asc := f.get_ascent(_font_size)
			var cap := 5.0 * s  # Silkscreen: mayuscula de 5 px de arte
			var base := (size.y - 3.0 * s - cap) * 0.5 + (cap if asc > cap else asc)
			draw_string(f, Vector2((size.x - tw) * 0.5, round(base) + 1.0), _g.label, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, HudStyle.SHADOW)
