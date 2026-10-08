extends CanvasLayer

@onready var _game_controller = get_node("/root/GameController")

func _ready() -> void:
	_create_ui()
	_update_meta_info()

func _create_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color("2a1440")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 15)
	bg.add_child(vbox)
	
	var title = Label.new()
	title.text = "ROGUE REPRODUCTIVE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("ff4f9a"))
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "La Gran Censura: un roguelike sobre órganos, hormonas y malas decisiones"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.6, 0.7, 1))
	vbox.add_child(subtitle)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer)
	
	var start_btn = Button.new()
	start_btn.text = "NUEVA RUN"
	start_btn.custom_minimum_size = Vector2(300, 60)
	start_btn.pressed.connect(_on_start)
	vbox.add_child(start_btn)
	
	var continue_btn = Button.new()
	continue_btn.text = "CONTINUAR (WIP)"
	continue_btn.custom_minimum_size = Vector2(300, 60)
	continue_btn.disabled = true
	vbox.add_child(continue_btn)
	
	var lore_btn = Button.new()
	lore_btn.text = "LORE & BESTIARIO (WIP)"
	lore_btn.custom_minimum_size = Vector2(300, 60)
	lore_btn.disabled = true  # lore_menu.tscn aun no existe
	vbox.add_child(lore_btn)
	
	var settings_btn = Button.new()
	settings_btn.text = "AJUSTES (WIP)"
	settings_btn.custom_minimum_size = Vector2(300, 60)
	settings_btn.disabled = true  # settings_menu.tscn aun no existe
	vbox.add_child(settings_btn)
	
	var quit_btn = Button.new()
	quit_btn.text = "SALIR"
	quit_btn.custom_minimum_size = Vector2(300, 60)
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)
	
	var meta_info = Label.new()
	meta_info.text = "Moneda: 0 | Perks: 0 | Lore: 0%"
	meta_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_info.add_theme_font_size_override("font_size", 16)
	meta_info.add_theme_color_override("font_color", Color(0.6, 0.5, 0.6, 1))
	vbox.add_child(meta_info)
	
	for b in [start_btn, continue_btn, lore_btn, settings_btn, quit_btn]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.grab_focus.call_deferred()
	
	# Store references
	self.start_btn = start_btn
	self.continue_btn = continue_btn
	self.lore_btn = lore_btn
	self.settings_btn = settings_btn
	self.quit_btn = quit_btn
	self.meta_info = meta_info

var start_btn: Button
var continue_btn: Button
var lore_btn: Button
var settings_btn: Button
var quit_btn: Button
var meta_info: Label

func _update_meta_info() -> void:
	var data = _game_controller.get_run_manager().load_meta_progression()
	var currency = data["meta_currency"] if data.has("meta_currency") else 0
	var perks = data["unlocked_perks"].size() if data.has("unlocked_perks") else 0
	var lore_pct = _game_controller.get_lore_database().get_completion_percentage()
	meta_info.text = "Moneda: %d | Perks: %d | Lore: %.1f%%" % [currency, perks, lore_pct]

func _on_start() -> void:
	# historia + eleccion de personaje; la run empieza alli
	get_tree().change_scene_to_file("res://src/scenes/intro.tscn")

func _on_continue() -> void:
	pass

func _on_quit() -> void:
	get_tree().quit()