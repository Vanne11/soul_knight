extends PanelContainer
class_name UIBar

## Reusable stat bar (health, shields, stamina, intoxication)

@export var bar_color: Color = Color.RED
@export var label_text: String = "STAT"

var _current: float = 100.0
var _max: float = 100.0

@onready var fill: TextureRect = $Background/Fill
@onready var label: Label = $Background/Label

func _ready() -> void:
	label.text = label_text
	fill.modulate = bar_color
	update_bar(_current, _max)

func update_bar(current: float, max: float) -> void:
	_current = current
	_max = max
	var pct = 0.0 if max <= 0 else clamp(current / max, 0.0, 1.0)
	fill.size = Vector2(get_rect().size.x * pct, get_rect().size.y)
	label.text = "%s: %.0f/%.0f" % [label_text, current, max]

func set_color(color: Color) -> void:
	bar_color = color
	fill.modulate = color