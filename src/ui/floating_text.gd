extends Label
class_name FloatingText

## Floating text for damage numbers, item pickups, etc.

var lifetime: float = 1.5
var velocity: Vector2 = Vector2.UP * 50
var fade_delay: float = 0.5
var _timer: float = 0.0

@onready var tween: Tween = null

func setup(text: String, color: Color = Color.WHITE, is_crit: bool = false) -> void:
	self.text = text
	add_theme_color_override("font_color", color)
	add_theme_font_size_override("font_size", 14 if is_crit else 10)
	add_theme_color_override("font_outline_color", Color(1, 0.8, 0) if is_crit else Color(0.05, 0.04, 0.06))
	add_theme_constant_override("outline_size", 3)
	
	_timer = 0.0
	
	# Build the tween lazily: creating it in _ready() without appending any
	# tweener logs "started with no Tweeners".
	tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 60, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime).set_delay(fade_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(queue_free)

func _process(delta: float) -> void:
	_timer += delta