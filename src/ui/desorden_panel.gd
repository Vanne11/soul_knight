class_name DesordenPanel
extends PanelContainer

## Panel del post-juego "Desordenes": avisa de los reinos que siguen sin liberar (progreso
## permanente, RunManager.liberated) y ofrece (a) cambiar de heroe, (b) seguir con el mismo o
## (c) terminar por ahora. Lo usan la pantalla de victoria (game_over.gd) y el menu principal.
## La logica de la ruta de rescate vive en RunManager.begin_rescue; aqui solo se pide y se cambia de escena.

## El jugador eligio (c): quien lo creo decide si lo cierra o lo deja.
signal closed


## Nombres de los reinos pendientes, separados por comas.
static func pending_names(rm: Node) -> String:
	return ", ".join(rm.pending_regions().map(func(r): return Loc.region_name_id(str(r))))


## null si no queda ningun desorden.
static func create(rm: Node) -> DesordenPanel:
	if rm.pending_regions().is_empty():
		return null
	var p := DesordenPanel.new()
	p._build(rm)
	return p


func _build(rm: Node) -> void:
	add_theme_stylebox_override("panel", HudStyle.panel_box(16))
	custom_minimum_size = Vector2(360, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := HudStyle.pixel_label(tr("DESORDEN_TITULO") % pending_names(rm), 16, HudStyle.GOLD, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 330
	box.add_child(title)
	_button(box, tr("DESORDEN_CAMBIAR"), tr("DESORDEN_CAMBIAR_TIP"), func(): _change_hero(rm))
	_button(box, tr("DESORDEN_MISMO"), tr("DESORDEN_MISMO_TIP"), func(): _same_hero(rm))
	_button(box, tr("DESORDEN_TERMINAR"), tr("DESORDEN_TERMINAR_TIP"), func(): closed.emit())


func _button(parent: Control, text: String, tip: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	HudStyle.juice_button(b)
	parent.add_child(b)


## (a) Eleccion de otro heroe (intro.gd se salta la historia y deshabilita al actual).
func _change_hero(rm: Node) -> void:
	rm.rescue_requested = true
	rm.rescue_new_hero = true
	rm.rescue_swap_from = rm.character
	Transition.change_scene("res://src/scenes/intro.tscn")


## (b) El mismo heroe, ya: start_new_run arma la ruta de rescate y cruza en paz lo liberado.
func _same_hero(rm: Node) -> void:
	rm.rescue_requested = true
	rm.rescue_new_hero = false
	rm.rescue_swap_from = ""
	rm.start_new_run()
	Transition.change_scene("res://src/scenes/main.tscn")
