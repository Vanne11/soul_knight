extends CanvasLayer
## Pantalla de clasificacion 16+ al arrancar el juego, antes del menu principal.
## Se cierra con cualquier tecla, clic, toque o boton de mando, o sola a los ~5 s.
## Una vez por arranque: es la main_scene, asi que al volver al menu desde una
## partida no reaparece. El autoplay arranca su propia escena y no pasa por aqui.

const MENU_SCENE := "res://src/scenes/main_menu.tscn"
const FADE_IN := 0.4
const FADE_OUT := 0.3
const AUTO_CLOSE := 5.0
const BG := Color("0d0b0f")

var _root: Control
var _closing := false

func _ready() -> void:
	_create_ui()
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, FADE_IN)
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

func _input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo
	elif event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventJoypadButton:
		pressed = event.pressed
	if pressed:
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	await tw.finished
	get_tree().change_scene_to_file(MENU_SCENE)
