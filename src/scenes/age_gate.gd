extends CanvasLayer
## Arranque del juego: logo de C&B Studio (con jingle) que se disuelve hacia la
## pantalla de clasificacion 16+, y de ahi al menu principal. La primera vez que se abre
## (Settings.locale_chosen falso) entre el logo y el 16+ se elige el idioma.
## Una tecla o toque durante el logo salta al 16+; durante el 16+ va al menu.
## El 16+ se cierra con tecla, clic, toque o boton de mando, o solo a los ~5 s.
## Una vez por arranque: es la main_scene, asi que al volver al menu desde una
## partida no reaparece. El autoplay arranca su propia escena y no pasa por aqui.

const MENU_SCENE := "res://src/scenes/save_slots.tscn"  # primero el espacio de guardado (SaveSlots), luego el menu
const LOGO_TEX := preload("res://assets/sprites/ui/studio_logo.png")
const DISSOLVE := preload("res://src/shaders/dissolve.gdshader")
const LOGO_FADE_IN := 0.6
const LOGO_HOLD := 2.0
const DISSOLVE_TIME := 0.9
const FADE_IN := 0.4
const FADE_OUT := 0.3
const AUTO_CLOSE := 5.0
const BG := Color("0d0b0f")
const STUDIO_GREEN := Color("bfe8a0")

enum Phase { LOGO, DISSOLVING, LANGUAGE, RATING, CLOSING }

var _root: Control
var _logo_layer: Control
var _logo_mat: ShaderMaterial
var _phase := Phase.LOGO
var _seq: Tween

func _ready() -> void:
	_create_ui()
	_create_logo()
	# El audio puede estar bloqueado en la web hasta el primer input: no pasa nada.
	Sound.music("studio_jingle", false)
	_logo_layer.modulate.a = 0.0
	_seq = create_tween()
	_seq.tween_property(_logo_layer, "modulate:a", 1.0, LOGO_FADE_IN)
	_seq.tween_interval(LOGO_HOLD)
	_seq.tween_callback(_start_dissolve)

## Logo del estudio sobre fondo oscuro, encima del 16+ (que asoma al disolverse).
func _create_logo() -> void:
	_logo_layer = Control.new()
	_logo_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_logo_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_layer.theme = HudStyle.menu_theme()
	add_child(_logo_layer)

	_logo_mat = ShaderMaterial.new()
	_logo_mat.shader = DISSOLVE

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.material = _logo_mat
	_logo_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	# ilustracion (no pixel art): filtro lineal; ~45% de la altura de la pantalla
	var h := get_viewport().get_visible_rect().size.y * 0.45
	var logo := TextureRect.new()
	logo.texture = LOGO_TEX
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(h, h)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.material = _logo_mat
	box.add_child(logo)

	var name_lbl := HudStyle.pixel_label("C&B Studio", 32, STUDIO_GREEN, true)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.material = _logo_mat
	box.add_child(name_lbl)

## El logo se disuelve y deja ver el 16+; al terminar arranca la cuenta de cierre.
func _start_dissolve() -> void:
	if _phase != Phase.LOGO:
		return
	_phase = Phase.DISSOLVING
	if not Settings.locale_chosen:
		_root.hide()  # el 16+ aun no esta en el idioma del jugador: que no asome tras el logo
	if _seq:
		_seq.kill()
	_seq = create_tween()
	_seq.tween_method(func(v: float) -> void: _logo_mat.set_shader_parameter("progress", v), 0.0, 1.0, DISSOLVE_TIME)
	_seq.tween_callback(_rating_shown)

func _rating_shown() -> void:
	_logo_layer.hide()
	if not Settings.locale_chosen:
		_show_language()
		return
	_phase = Phase.RATING
	# Cierre automatico; si ya se cerro a mano, _close ignora la llamada.
	get_tree().create_timer(AUTO_CLOSE).timeout.connect(_close)

func _create_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = HudStyle.menu_theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(760, 0)
	box.add_theme_constant_override("separation", 28)
	center.add_child(box)

	var big := HudStyle.pixel_label(tr("AGE_RATING"), 160, HudStyle.GOLD, true)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(big)

	var desc := HudStyle.pixel_label(tr("AGE_DESC"), 22, HudStyle.CREAM)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(desc)

	# aviso chico, anclado abajo
	var hint := HudStyle.pixel_label(tr("AGE_CONTINUE"), 14, HudStyle.CREAM)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -56
	hint.offset_bottom = -24
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hint)

## Eleccion de idioma (solo la primera vez): un boton por idioma, con el foco en el del sistema.
## Al elegir, el 16+ se rehace ya traducido.
func _show_language() -> void:
	_phase = Phase.LANGUAGE
	_root.hide()
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.theme = HudStyle.menu_theme()
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	# el titulo va en todos los idiomas: todavia no sabemos cual lee el jugador
	var title := HudStyle.pixel_label("IDIOMA · LANGUAGE · LANGUE · IDIOMA", 24, HudStyle.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var focus: Button = null
	for l in Settings.LOCALES:
		var b := Button.new()
		b.text = l[1]
		b.custom_minimum_size = Vector2(420, 48)
		HudStyle.juice_button(b)
		b.pressed.connect(func():
			Settings.set_locale(l[0])
			layer.queue_free()
			_root.queue_free()
			_create_ui()
			_rating_shown())
		box.add_child(b)
		if focus == null or l[0] == Settings.locale:
			focus = b
	focus.grab_focus.call_deferred()

func _input(event: InputEvent) -> void:
	if _phase == Phase.LANGUAGE:
		return  # los botones de idioma reciben la tecla, el clic o el mando
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		get_viewport().set_input_as_handled()
		if _phase == Phase.LOGO:
			_start_dissolve()
		elif _phase == Phase.DISSOLVING:
			_seq.kill()  # salta la disolucion y deja el 16+ limpio
			_rating_shown()
		else:
			_close()

func _close() -> void:
	if _phase == Phase.CLOSING or _phase == Phase.LOGO:
		return
	_phase = Phase.CLOSING
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	await tw.finished
	get_tree().change_scene_to_file(MENU_SCENE)
