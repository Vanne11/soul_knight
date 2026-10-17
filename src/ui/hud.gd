extends CanvasLayer
class_name HUD

## HUD: una franja fija arriba, fuera del area de juego (main.gd baja la camara
## BAND pixeles para que la sala empiece debajo).

const BAND := 72

@onready var health_bar: UIBar = $Band/Row/Bars/Top/HealthBar
@onready var shield_bar: UIBar = $Band/Row/Bars/Top/ShieldBar
@onready var stamina_bar: UIBar = $Band/Row/Bars/Bottom/StaminaBar
@onready var intox_bar: UIBar = $Band/Row/Bars/Bottom/IntoxicationBar
@onready var item_slots: Array[ItemSlot] = [$Band/Row/Slots/Slot1, $Band/Row/Slots/Slot2, $Band/Row/Slots/Slot3, $Band/Row/Slots/Slot4]
@onready var floor_label: Label = $Band/Row/Info/FloorInfo
@onready var intox_label: Label = $Band/Row/IntoxicationLabel
@onready var _purse: HBoxContainer = $Band/Row/Info/Purse
var _coin_label: Label
var _horm_box: HBoxContainer
var _contagion_label: Label  # contagio de ITS (picazon / ardor)
## Estados temporales de objetos (regeneracion, buffs, guardia...): lista bajo la franja.
var _status_label: Label
var _status_cache := ""
var _last_hp := -1.0

var _stats: PlayerStats
var _events: GlobalEvents
var _runs: RunManager

func _ready() -> void:
	# franja pixel art: tela morada + ribete dorado (tile de 64 px)
	var bg := StyleBoxTexture.new()
	bg.texture = HudStyle.tex("band")
	bg.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	bg.content_margin_left = 8
	bg.content_margin_right = 12
	bg.content_margin_top = 1
	bg.content_margin_bottom = 11
	$Band.add_theme_stylebox_override("panel", bg)
	$Band/Row/Portrait/Frame.texture = HudStyle.tex("portrait_frame")
	HudStyle.style_label(floor_label, 16)
	HudStyle.style_label(intox_label, 16, Color(0.5, 1, 0.5), true)
	_purse.add_child(HudStyle.icon("coin"))
	_coin_label = HudStyle.pixel_label("0", 16, HudStyle.GOLD)
	_purse.add_child(_coin_label)
	_horm_box = HBoxContainer.new()
	_horm_box.add_theme_constant_override("separation", 2)
	_horm_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_purse.add_child(_horm_box)
	_contagion_label = HudStyle.pixel_label("", 14, Color("c8e04a"))
	_contagion_label.visible = false
	_purse.add_child(_contagion_label)
	_setup_bars()
	_setup_slots()
	_status_label = HudStyle.pixel_label("", 14, Color("9be8ff"))
	_status_label.position = Vector2(10, BAND + 6)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_label)
	
	_stats = get_node("/root/PlayerStats")
	_events = get_node("/root/GlobalEvents")
	_runs = get_node("/root/RunManager")
	
	_stats.health_changed.connect(_on_health_changed)
	_stats.shields_changed.connect(_on_shields_changed)
	_stats.stamina_changed.connect(_on_stamina_changed)
	_stats.intoxication_changed.connect(_on_intoxication_changed)
	_stats.contagion_changed.connect(_on_contagion_changed)
	_events.item_picked_up.connect(_on_item_picked_up)
	_events.inventory_changed.connect(_refresh_slots)
	_runs.run_started.connect(_on_run_started)
	_events.boss_health_changed.connect(_on_boss_health_changed)
	_events.boss_charges_changed.connect(_on_boss_charges_changed)
	_events.floor_completed.connect(func(_f): _update_floor_label())
	_events.coins_changed.connect(func(_c): _update_floor_label())
	_events.hormones_changed.connect(_update_floor_label)
	_events.blessings_changed.connect(_update_blessings)
	_build_boss_bar()
	_build_blessings()
	add_child(Minimap.new())
	_update_floor_label()
	_update_portrait()
	
	# Initial update
	_stats.emit_all_signals()
	_refresh_slots()

func _on_contagion_changed(kind: String, seconds: float) -> void:
	_contagion_label.visible = kind != ""
	if kind != "":
		_contagion_label.text = "%s %ds" % [tr("HUD_CONTAGION_" + kind.to_upper()), ceili(seconds)]
func _process(_delta: float) -> void:
	if _stats == null or _status_label == null:
		return
	var lines: Array[String] = []
	for st in _stats.active_statuses():
		var t: String = tr(st.key)
		if int(st.get("count", 1)) > 1:
			t += " x%d" % int(st.count)
		if st.left >= 0.0:
			t += " %ds" % ceili(st.left)
		lines.append(t)
	var txt := "\n".join(lines)
	if txt != _status_cache:
		_status_cache = txt
		_status_label.text = txt

func _setup_bars() -> void:
	health_bar.set_icon("heart")
	health_bar.set_color(Color("e43b44"))
	shield_bar.set_icon("shield")
	shield_bar.set_color(Color("3a9ee8"))
	stamina_bar.set_icon("bolt")
	stamina_bar.set_color(Color("f2c53d"))
	intox_bar.set_icon("bottle")
	intox_bar.set_color(Color("c046d4"))

func _setup_slots() -> void:
	var keys = ["1", "2", "3", "4"]
	for i in range(item_slots.size()):
		item_slots[i].setup(i, keys[i])

func _on_health_changed(current: float, max: float) -> void:
	health_bar.update_bar(current, max)
	if _last_hp >= 0.0 and current < _last_hp:
		health_bar.pulse_icon()
	_last_hp = current

func _on_shields_changed(current: float, max: float) -> void:
	shield_bar.update_bar(current, max)
	shield_bar.visible = max > 0.0  # se empieza sin escudo: no ocupa sitio hasta ganarlo

func _on_stamina_changed(current: float, max: float) -> void:
	stamina_bar.update_bar(current, max)

func _on_intoxication_changed(level: float, tier: int) -> void:
	var max_intox = get_node("/root/PlayerStats").max_intoxication
	intox_bar.update_bar(level, max_intox)
	
	var tier_colors = [
		Color(0.5, 1, 0.5),
		Color(1, 0.9, 0.3),
		Color(1, 0.6, 0.2),
		Color(1, 0.3, 1)
	]
	
	intox_label.text = tr("INTOX_TIER_%d" % tier)
	intox_label.add_theme_color_override("font_color", tier_colors[tier])
	
	# Visual feedback on tier change
	intox_bar.set_color([Color("c046d4"), Color("f2c53d"), Color("f08a2a"), Color("ff3df0")][tier])

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
	var fd: Dictionary = _runs.floor_data()
	floor_label.text = tr("HUD_FLOOR") % [n, Loc.floor_name(fd)]
	floor_label.add_theme_color_override("font_color", fd.get("tint", HudStyle.CREAM))
	_coin_label.text = str(_runs.coins)
	# hormonas conseguidas: su frasco, a tamano real del arte del objeto
	for c in _horm_box.get_children():
		c.queue_free()
	for h in _runs.hormones:
		if _runs.hormones[h]:
			var t := TextureRect.new()
			t.texture = load("res://assets/sprites/items/hormone_%s.png" % h)
			t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			t.tooltip_text = tr("HUD_HORMONE_" + str(h).to_upper())
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_horm_box.add_child(t)

## Retrato del personaje en su marco (recorte de la cara, a 1:1).
func _update_portrait() -> void:
	var path := "res://assets/sprites/player/%s/portrait.png" % _runs.character
	if not ResourceLoader.exists(path):
		return
	var at := AtlasTexture.new()
	at.atlas = load(path)
	at.region = Rect2(8, 14, 48, 48)
	var face: TextureRect = $Band/Row/Portrait/Face
	face.texture = at
	# fondo del hueco: el color del reino del personaje
	var bg := ColorRect.new()
	bg.color = {"pene": Color("1d3550"), "vulva": Color("4a1838"), "ninguno": Color("1f3a24")}.get(_runs.character_data().kingdom, Color("2a1838"))
	bg.position = face.position
	bg.size = face.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Band/Row/Portrait.add_child(bg)
	$Band/Row/Portrait.move_child(bg, 0)

## Tu build: bendiciones con su nivel, en el color de su reino. Arriba a la izquierda.
var _blessings: RichTextLabel

func _build_blessings() -> void:
	_blessings = RichTextLabel.new()
	_blessings.bbcode_enabled = true
	_blessings.fit_content = true
	_blessings.scroll_active = false
	_blessings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blessings.position = Vector2(10, BAND + 6)
	_blessings.size = Vector2(260, 0)
	_blessings.add_theme_font_override("normal_font", HudStyle.FONT)
	_blessings.add_theme_font_size_override("normal_font_size", 16)
	_blessings.add_theme_color_override("font_shadow_color", HudStyle.SHADOW)
	_blessings.add_theme_constant_override("shadow_offset_x", 2)
	_blessings.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_blessings)
	_update_blessings()

func _update_blessings() -> void:
	var colors := {"pene": "6ec6ff", "vulva": "ff7ac0", "mixto": "ffc93c"}
	var lines := []
	for id in _runs.blessings:
		var b: Dictionary = RunManager.BLESSINGS[id]
		lines.append("[color=#%s]%s %d[/color]" % [colors[b.kingdom], Loc.blessing(id, "name"), _runs.blessings[id]])
	_blessings.text = "\n".join(lines)

var _boss_bar: UIBar
var _boss_label: Label
var _boss_pips: HBoxContainer

func _build_boss_bar() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.offset_left = -300
	box.offset_right = 300
	box.offset_top = BAND + 6
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_label = HudStyle.pixel_label("", 24, Color("ff5a5a"), true)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_bar = (load("res://src/ui/bar.tscn") as PackedScene).instantiate()
	_boss_bar.custom_minimum_size = Vector2(600, 28)
	box.add_child(_boss_label)
	box.add_child(_boss_bar)
	_boss_pips = HBoxContainer.new()
	_boss_pips.alignment = BoxContainer.ALIGNMENT_CENTER
	_boss_pips.add_theme_constant_override("separation", 6)
	_boss_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_boss_pips)
	_boss_bar.set_icon("skull")
	_boss_bar.set_color(Color("c8283a"))
	box.visible = false
	add_child(box)

## Curas que le quedan al jefe (cada intento de canalizar gasta una).
func _on_boss_charges_changed(left: int, total: int) -> void:
	for c in _boss_pips.get_children():
		c.queue_free()
	if total <= 0:
		return
	var lbl := HudStyle.pixel_label(tr("BOSS_CHARGES"), 14, Color("ffe08a"), true)
	_boss_pips.add_child(lbl)
	for i in total:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(16, 16)
		r.color = Color("ffd23f") if i < left else Color(0.15, 0.1, 0.12, 0.8)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_boss_pips.add_child(r)


func _on_boss_health_changed(boss_name: String, current: float, max_hp: float) -> void:
	_boss_label.text = Loc.enemy_name(boss_name)
	_boss_bar.update_bar(current, max_hp)
	_boss_bar.get_parent().visible = current > 0.0

func _notification(what: int) -> void:
	# cambio de idioma en plena partida (Ajustes desde la pausa): rehacer los textos
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and is_instance_valid(_runs):
		_update_floor_label()
		intox_label.text = tr("INTOX_TIER_%d" % _stats.intoxication_tier)
		return
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