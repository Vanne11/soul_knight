class_name DashHint
extends Control

## Glifo de "dash" (Espacio / A) en el extremo derecho de la barra de estamina (el dash gasta
## estamina) y, a su izquierda, puntitos con las cargas (Vulvalquiria tiene 2). Los puntos se
## apagan al gastarse; todo se apaga sin estamina suficiente. Solo lee al jugador.

var _glyph: InputGlyph
var _pips: HBoxContainer
var _n := 0
var _player: Player


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips = HBoxContainer.new()
	_pips.add_theme_constant_override("separation", 3)
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pips)
	_glyph = InputGlyph.new()
	_glyph.action = "dash"
	add_child(_glyph)
	_glyph.resized.connect(_place)
	resized.connect(_place)
	# el numero de la barra pasa a la izquierda: a la derecha va el glifo
	var bar := get_parent() as UIBar
	if bar and bar.label:
		bar.label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		bar.label.add_theme_constant_override("line_spacing", 0)
	_place()


func _place() -> void:
	if _glyph == null:
		return
	var s := _glyph.size
	_glyph.position = Vector2(size.x - s.x - 4.0, (size.y - s.y) * 0.5)
	_pips.position = Vector2(_glyph.position.x - 6.0 - _pips.size.x, (size.y - 10.0) * 0.5)


func _process(_d: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		if _player == null:
			return
	var cap := maxi(1, _player.dash_charges)
	if cap != _n:
		_n = cap
		for c in _pips.get_children():
			c.queue_free()
		for i in cap:
			var p := ColorRect.new()
			p.custom_minimum_size = Vector2(10, 10)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pips.add_child(p)
		_pips.size = Vector2.ZERO
		_pips.reset_size()
		_place.call_deferred()
	var ps := get_node("/root/PlayerStats")
	var ok: bool = ps.current_stamina >= _player.dash_stamina_cost * ps.dash_cost_modifier
	for i in _pips.get_child_count():
		var on: bool = i < _player._dash_left
		(_pips.get_child(i) as ColorRect).color = (Color("fff1d6") if ok else Color("8a8a95")) if on else Color(0.1, 0.07, 0.1, 0.9)
	_glyph.modulate = Color.WHITE if ok and _player._dash_left > 0 else Color(0.5, 0.5, 0.55)
