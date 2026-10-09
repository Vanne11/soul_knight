extends CanvasLayer

@onready var title: Label = $Panel/VBoxContainer/Title
@onready var stats: Label = $Panel/VBoxContainer/Stats
@onready var retry_btn: Button = $Panel/VBoxContainer/Buttons/RetryBtn
@onready var menu_btn: Button = $Panel/VBoxContainer/Buttons/MenuBtn
@onready var quit_btn: Button = $Panel/VBoxContainer/Buttons/QuitBtn

@onready var _game_controller: GameController = get_node("/root/GameController")

func _ready() -> void:
	var run_data = _game_controller.get_run_manager().get_run_data()
	var floor = run_data.floor if run_data.has("floor") else 1
	var kills = run_data.enemies_killed if run_data.has("enemies_killed") else 0
	var time_sec = int(run_data.time) if run_data.has("time") else 0
	
	var insults = [
		"MORISTE, CABRÓN",
		"SE TE CAYÓ EL PENE",
		"VUELVE AL ÚTERO",
		"HASTA MI ABUELA LO HACE MEJOR",
		"EL HÍGADO TE LLORA",
		"PAQUETE DE LECHE DERRAME",
		"ERROR 404: SKILL NOT FOUND"
	]
	title.text = insults[RNG.randi_range(0, insults.size() - 1)]
	if _game_controller.get_run_manager().last_run_victory:
		title.text = "LO HICISTE. ¿Y AHORA QUÉ?"
	var rm = _game_controller.get_run_manager()
	stats.text = "Piso: %d\nEnemigos: %d\nTiempo: %ds\n\n+%d HUESOS  (total %d: gástalos en Mejoras del menú)" % [
		floor, kills, time_sec, rm.last_huesos, rm.meta_currency]
	
	retry_btn.pressed.connect(_on_retry)
	menu_btn.pressed.connect(_on_menu)
	quit_btn.pressed.connect(_on_quit)

func _on_retry() -> void:
	_game_controller.get_run_manager().start_new_run()
	get_tree().change_scene_to_file("res://src/scenes/main.tscn")

func _on_menu() -> void:
	get_tree().change_scene_to_file("res://src/scenes/main_menu.tscn")

func _on_quit() -> void:
	get_tree().quit()