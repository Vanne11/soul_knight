extends Node
class_name FloatingTextManager

## Manages spawning and pooling of floating text

var floating_text_scene: PackedScene = preload("res://src/ui/floating_text.tscn")
var _pool: Array[FloatingText] = []

func spawn(position: Vector2, text: String, color: Color = Color.WHITE, is_crit: bool = false) -> void:
	var ft := _get_from_pool()
	# Parent to this manager, not get_tree().current_scene: current_scene is
	# null when the tree is driven from a script and wrong across scene changes.
	if ft.get_parent() == null:
		add_child(ft)
	ft.global_position = position
	ft.setup(text, color, is_crit)

func _get_from_pool() -> FloatingText:
	while _pool.size() > 0:
		var ft: FloatingText = _pool.pop_back()
		if is_instance_valid(ft):
			return ft
	return floating_text_scene.instantiate()

func return_to_pool(ft: FloatingText) -> void:
	if not is_instance_valid(ft):
		return
	if ft.get_parent() != null:
		ft.get_parent().remove_child(ft)
	_pool.append(ft)