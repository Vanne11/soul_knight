extends Node2D
class_name BossProp

## Objeto generico de los desafios de canalizacion de los jefes. Cada desafio le da su
## propio dibujo (drawer(prop)) y su logica por frame (updater(prop, delta)); el estado va
## en el diccionario `data` (compartido por referencia con las lambdas del desafio).
## Nace gris (Censor) y no usa luces: se lee tambien en la penumbra.

var drawer := Callable()
var updater := Callable()
var data := {}
var t := 0.0

var _mat := ShaderMaterial.new()
var _room: Node = null


func _ready() -> void:
	add_to_group(BossZone.GROUP)
	_mat.shader = BossZone.CENSOR_UNSHADED
	material = _mat
	var n: Node = get_parent()
	while n != null and not (n is Room):
		n = n.get_parent()
	_room = n
	_mat.set_shader_parameter("color_amount", Censor.amount(_room) if _room else 1.0)
	z_index = 3


func _physics_process(delta: float) -> void:
	t += delta
	_mat.set_shader_parameter("color_amount", Censor.amount(_room) if _room else 1.0)
	if updater.is_valid():
		updater.call(self, delta)
	queue_redraw()


func _draw() -> void:
	if drawer.is_valid():
		drawer.call(self)
