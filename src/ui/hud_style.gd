class_name HudStyle

## Piezas compartidas del HUD pixel art (arte en assets/sprites/ui/hud, sale de
## tools/gen_ui_art.py). Todo a 2x: 1 pixel de arte = 2x2 en pantalla.

const DIR := "res://assets/sprites/ui/hud/"
const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/Silkscreen-Bold.ttf")
const GOLD := Color("f0c04a")
const CREAM := Color("fff1d6")
const SHADOW := Color("0d0b0f")


static func tex(name: String) -> Texture2D:
	return load(DIR + name + ".png")


## Caja 9-slice dorada (narrador, minimapa...). Margen de arte 4 px = 8 en pantalla.
static func panel_box(content_margin := 12.0) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex("panel")
	sb.set_texture_margin_all(8)
	sb.set_content_margin_all(content_margin)
	return sb


## Texto pixel: Silkscreen a multiplos de 8 + sombra dura de 2 px (sin difuminar).
static func pixel_label(text: String, size := 16, color := CREAM, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	style_label(l, size, color, bold)
	return l


static func style_label(l: Control, size := 16, color := CREAM, bold := false) -> void:
	l.add_theme_font_override("font", FONT_BOLD if bold else FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", SHADOW)
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func icon(name: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex("icon_" + name)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	return t


## Boton pixel art (9-slice, margen 3 px de arte).
static func button_box(state: String) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex("btn_" + state)
	sb.set_texture_margin_all(6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	return sb


## Tema de menus (principal, muerte, eleccion de heroe): botones dorados,
## Silkscreen y cajas 9-slice. El nodo que lo use debe ir con filtro NEAREST.
static func menu_theme() -> Theme:
	var t := Theme.new()
	for st in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "Button", button_box(st))
	t.set_stylebox("focus", "Button", button_box("hover"))
	t.set_font("font", "Button", FONT_BOLD)
	t.set_font_size("font_size", "Button", 16)
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color("fff1a8"))
	t.set_color("font_focus_color", "Button", Color("fff1a8"))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color("6e6878"))
	t.set_stylebox("panel", "PanelContainer", panel_box(16))
	return t


## Botones con vida: el raton les da el foco (asi el teclado y el raton marcan
## el mismo), flechita al tener el foco y un tono al pulsar.
static func juice_button(b: Button) -> void:
	var base := b.text
	b.mouse_entered.connect(func(): if not b.disabled: b.grab_focus())
	b.focus_entered.connect(func(): b.text = "> " + base + " <")
	b.focus_exited.connect(func(): b.text = base)
	b.pressed.connect(func(): Sound.play("pickup"))
