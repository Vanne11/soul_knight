extends CanvasLayer
class_name FloatingTextManager

## Numeros de dano y textos flotantes. Es un CanvasLayer de UI (no escala con la
## camara) para que la fuente pixel quede nitida; cada FloatingText proyecta su
## posicion de mundo a pantalla. Pool de labels: nada se instancia por numero.

const MAX_ACTIVE := 60

var floating_text_scene: PackedScene = preload("res://src/ui/floating_text.tscn")
var _pool: Array[FloatingText] = []
var _active := 0


func _ready() -> void:
	# Sobre el mundo; el HUD (misma capa, despues en el arbol) queda encima.
	layer = 1


## `position` es de mundo. `is_number` distingue danos de avisos (ambos 16 px).
func spawn(position: Vector2, text: String, color: Color = Color.WHITE, is_crit: bool = false, font_size: int = 0) -> void:
	if _active >= MAX_ACTIVE:
		return
	var ft := _get_from_pool()
	if ft.get_parent() == null:
		add_child(ft)
	_active += 1
	ft.setup(self, position, text, color, is_crit, true, font_size)


func _get_from_pool() -> FloatingText:
	while _pool.size() > 0:
		var ft: FloatingText = _pool.pop_back()
		if is_instance_valid(ft):
			return ft
	var n: FloatingText = floating_text_scene.instantiate()
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return n


func return_to_pool(ft: FloatingText) -> void:
	if not is_instance_valid(ft):
		return
	_active = maxi(_active - 1, 0)
	if ft.get_parent() != null:
		ft.get_parent().remove_child(ft)
	_pool.append(ft)
