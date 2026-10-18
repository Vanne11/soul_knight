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
	add_to_group("floating_text_mgr")


## `position` es de mundo. `is_number` distingue danos de avisos (ambos 16 px).
func spawn(position: Vector2, text: String, color: Color = Color.WHITE, is_crit: bool = false, font_size: int = 0) -> void:
	if _active >= MAX_ACTIVE:
		return
	var ft := _get_from_pool()
	if ft.get_parent() == null:
		add_child(ft)
	_active += 1
	ft.setup(self, position, text, color, is_crit, true, font_size)


## Texto con tamano propio (debilidades/resistencias de jefes): `size` >= 24 va en negrita.
func spawn_styled(position: Vector2, text: String, color: Color, size: int) -> void:
	if _active >= MAX_ACTIVE:
		return
	var ft := _get_from_pool()
	if ft.get_parent() == null:
		add_child(ft)
	_active += 1
	ft.setup(self, position, text, color, false, true)
	HudStyle.style_label(ft, size, color, size >= 24)
	ft.reset_size()
	ft.size = ft.get_minimum_size()
	if size >= 24:
		ft.lifetime = 1.4
		ft.rise_px = 60.0


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
