extends Control
## Interfaz: corazones, armadura, barra de energia y mensajes.
##
## El HUD no conoce al jugador: se entera de todo por el autoload Events.
## Eso permite cambiar de personaje, reiniciar la partida o tener varios
## jugadores sin tocar una linea de esta clase.

@export var heart_texture: Texture2D
@export var shield_texture: Texture2D

@onready var hearts: HBoxContainer = %Hearts
@onready var shields: HBoxContainer = %Shields
@onready var energy_bg: ColorRect = %EnergyBG
@onready var energy_fill: ColorRect = %EnergyFill
@onready var weapon_label: Label = %WeaponLabel
@onready var toast: Label = %Toast
@onready var death_panel: Control = %DeathPanel

const DIM := Color(1.0, 1.0, 1.0, 0.16)

var player: Player


func _ready() -> void:
	Events.player_spawned.connect(_on_player_spawned)
	Events.player_stats_changed.connect(_refresh)
	Events.player_died.connect(func() -> void: death_panel.show())
	Events.message.connect(show_message)

	toast.modulate.a = 0.0
	death_panel.hide()


func _on_player_spawned(new_player: Node2D) -> void:
	player = new_player as Player
	death_panel.hide()
	_build_icons()
	_refresh()
	if player.weapon.data != null:
		weapon_label.text = player.weapon.data.display_name


## Crea un icono por punto maximo de vida / armadura. Solo hace falta
## rehacerlo cuando cambian los maximos (una mejora permanente, por ejemplo).
func _build_icons() -> void:
	_fill_row(hearts, heart_texture, player.health.max_hp)
	_fill_row(shields, shield_texture, player.health.max_armor)


func _fill_row(row: HBoxContainer, texture: Texture2D, count: int) -> void:
	for child in row.get_children():
		child.queue_free()
	for i in count:
		var icon := TextureRect.new()
		icon.texture = texture
		icon.custom_minimum_size = Vector2(10, 10)
		icon.stretch_mode = TextureRect.STRETCH_KEEP
		row.add_child(icon)


## Repinta el estado actual. Es barato: solo cambia el alpha de cada icono.
func _refresh() -> void:
	if player == null or not is_instance_valid(player):
		return

	var hp := player.health.hp
	for i in hearts.get_child_count():
		(hearts.get_child(i) as TextureRect).modulate = Color.WHITE if i < hp else DIM

	var armor := floori(player.health.armor)
	for i in shields.get_child_count():
		(shields.get_child(i) as TextureRect).modulate = Color.WHITE if i < armor else DIM

	var ratio: float = clampf(player.energy / player.max_energy, 0.0, 1.0)
	energy_fill.size = Vector2(roundf(energy_bg.size.x * ratio), energy_bg.size.y)


func show_message(text: String, seconds: float = 1.6) -> void:
	toast.text = text
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.15)
	tween.tween_interval(seconds)
	tween.tween_property(toast, "modulate:a", 0.0, 0.4)
