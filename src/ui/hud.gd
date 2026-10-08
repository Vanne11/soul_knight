extends CanvasLayer
class_name HUD

## Main HUD managing all UI bars and item slots

@onready var health_bar: UIBar = $Root/VBoxContainer/TopBars/HealthBar
@onready var shield_bar: UIBar = $Root/VBoxContainer/TopBars/ShieldBar
@onready var stamina_bar: UIBar = $Root/VBoxContainer/TopBars/StaminaBar
@onready var intox_bar: UIBar = $Root/VBoxContainer/TopBars/IntoxicationBar
@onready var item_slots: Array[ItemSlot] = [
	$Root/VBoxContainer/BottomArea/ItemSlots/Slot1,
	$Root/VBoxContainer/BottomArea/ItemSlots/Slot2,
	$Root/VBoxContainer/BottomArea/ItemSlots/Slot3,
	$Root/VBoxContainer/BottomArea/ItemSlots/Slot4
]
@onready var floor_label: Label = $Root/VBoxContainer/BottomArea/FloorInfo
@onready var intox_label: Label = $Root/VBoxContainer/BottomArea/IntoxicationLabel

var _stats: PlayerStats
var _events: GlobalEvents
var _runs: RunManager

func _ready() -> void:
	_setup_bars()
	_setup_slots()
	
	_stats = get_node("/root/PlayerStats")
	_events = get_node("/root/GlobalEvents")
	_runs = get_node("/root/RunManager")
	
	_stats.health_changed.connect(_on_health_changed)
	_stats.shields_changed.connect(_on_shields_changed)
	_stats.stamina_changed.connect(_on_stamina_changed)
	_stats.intoxication_changed.connect(_on_intoxication_changed)
	_events.item_picked_up.connect(_on_item_picked_up)
	_events.inventory_changed.connect(_refresh_slots)
	_runs.run_started.connect(_on_run_started)
	_events.boss_health_changed.connect(_on_boss_health_changed)
	_events.floor_completed.connect(func(_f): _update_floor_label())
	_events.coins_changed.connect(func(_c): _update_floor_label())
	_events.hormones_changed.connect(_update_floor_label)
	_build_boss_bar()
	add_child(Minimap.new())
	_update_floor_label()
	
	# Initial update
	_stats.emit_all_signals()
	_refresh_slots()

func _setup_bars() -> void:
	health_bar.label_text = "VIDA"
	health_bar.bar_color = Color(0.9, 0.2, 0.2)
	
	shield_bar.label_text = "ESCUDO"
	shield_bar.bar_color = Color(0.2, 0.6, 1.0)
	
	stamina_bar.label_text = "ESTAMINA"
	stamina_bar.bar_color = Color(0.9, 0.8, 0.2)
	
	intox_bar.label_text = "TOXICIDAD"
	intox_bar.bar_color = Color(0.8, 0.2, 0.8)

func _setup_slots() -> void:
	var keys = ["1", "2", "3", "4"]
	for i in range(item_slots.size()):
		item_slots[i].setup(i, keys[i])

func _on_health_changed(current: float, max: float) -> void:
	health_bar.update_bar(current, max)

func _on_shields_changed(current: float, max: float) -> void:
	shield_bar.update_bar(current, max)

func _on_stamina_changed(current: float, max: float) -> void:
	stamina_bar.update_bar(current, max)

func _on_intoxication_changed(level: float, tier: int) -> void:
	var max_intox = get_node("/root/PlayerStats").max_intoxication
	intox_bar.update_bar(level, max_intox)
	
	var tier_names = ["SOBRIO", "ACHISPADO", "BORRACHO", "BLACKOUT"]
	var tier_colors = [
		Color(0.5, 1, 0.5),
		Color(1, 0.9, 0.3),
		Color(1, 0.6, 0.2),
		Color(1, 0.3, 1)
	]
	
	intox_label.text = tier_names[tier]
	intox_label.add_theme_color_override("font_color", tier_colors[tier])
	
	# Visual feedback on tier change
	if tier == 3:
		intox_bar.set_color(Color(1, 0.2, 1))
	elif tier == 2:
		intox_bar.set_color(Color(1, 0.5, 0.2))
	elif tier == 1:
		intox_bar.set_color(Color(1, 0.8, 0.3))
	else:
		intox_bar.set_color(Color(0.8, 0.2, 0.8))

func _on_item_picked_up(item: Variant, qty: int) -> void:
	if "mejora" in item.tags:
		return  # las mejoras de la tienda son permanentes, no ocupan casilla
	# Try to add to existing slot or find empty
	for slot in item_slots:
		if slot.item_id == item.id:
			slot.set_item(item.id, slot.quantity + qty)
			return
	
	for slot in item_slots:
		if slot.item_id == "":
			slot.set_item(item.id, qty)
			return
	
	# Inventory full - drop on ground (handled by pickup logic)

func _refresh_slots() -> void:
	# Could sync with actual inventory system later
	pass

func _on_run_started(_seed: int) -> void:
	_update_floor_label()

## El HUD nace despues de run_started, asi que antes siempre ponia "SEMILLA: 0".
func _update_floor_label() -> void:
	var n: int = _runs.current_floor
	var horm: Array = _runs.hormones.keys().filter(func(h): return _runs.hormones[h])
	floor_label.text = "PISO %d: %s  |  MONEDAS %d  |  HORMONAS: %s" % [n, _runs.floor_data().name, _runs.coins,
		", ".join(horm) if not horm.is_empty() else "ninguna"]

var _boss_bar: ProgressBar
var _boss_label: Label

func _build_boss_bar() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = 112  # debajo de la fila del piso, no encima
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_label = Label.new()
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.add_theme_font_size_override("font_size", 20)
	_boss_label.add_theme_color_override("font_color", Color("c84a4a"))
	_boss_label.add_theme_color_override("font_outline_color", Color("0d0b0f"))
	_boss_label.add_theme_constant_override("outline_size", 6)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(600, 16)
	_boss_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("0d0b0f")
	bg.border_color = Color("b08d4a")
	bg.set_border_width_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("a83232")
	_boss_bar.add_theme_stylebox_override("background", bg)
	_boss_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_boss_label)
	box.add_child(_boss_bar)
	box.visible = false
	add_child(box)

func _on_boss_health_changed(boss_name: String, current: float, max_hp: float) -> void:
	_boss_label.text = boss_name
	_boss_bar.max_value = max_hp
	_boss_bar.value = current
	_boss_bar.get_parent().visible = current > 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Absolute get_node() is invalid once the node has left the tree,
		# so use the cached autoload references and guard each connection.
		if not is_instance_valid(_stats):
			return
		for pair in [
			[_stats.health_changed, _on_health_changed],
			[_stats.shields_changed, _on_shields_changed],
			[_stats.stamina_changed, _on_stamina_changed],
			[_stats.intoxication_changed, _on_intoxication_changed],
		]:
			if pair[0].is_connected(pair[1]):
				pair[0].disconnect(pair[1])
		if is_instance_valid(_events):
			if _events.item_picked_up.is_connected(_on_item_picked_up):
				_events.item_picked_up.disconnect(_on_item_picked_up)
			if _events.inventory_changed.is_connected(_refresh_slots):
				_events.inventory_changed.disconnect(_refresh_slots)
		if is_instance_valid(_runs) and _runs.run_started.is_connected(_on_run_started):
			_runs.run_started.disconnect(_on_run_started)