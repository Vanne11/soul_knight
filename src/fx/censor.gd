class_name Censor
extends RefCounted

## Censura gris -> color por sala (mecanica de la autora: la sala es gris hasta liberarla).
## Con arte propio por piso ya no se tine con modulate: un shader desatura y la
## liberacion lo devuelve al color real. Un material por sala (guardado en la sala).
##
## Uso: Censor.apply(room, nodo) en todo lo que deba nacer gris (TileMaps, decoracion).
## Los hijos de un nodo con el material pueden usar use_parent_material = true.
## main.gd llama a Censor.set_colored(room, colored, animate) al pintar la sala.

const SHADER := preload("res://src/shaders/censor.gdshader")
const META := "censor_mat"
const TIME := 1.2


static func material_for(room: Node) -> ShaderMaterial:
	if room.has_meta(META):
		return room.get_meta(META)
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("color_amount", 0.0)
	room.set_meta(META, m)
	return m


static func apply(room: Node, node: CanvasItem) -> void:
	node.material = material_for(room)


static func set_colored(room: Node, colored: bool, animate := false) -> void:
	var m := material_for(room)
	var v := 1.0 if colored else 0.0
	if animate and room.is_inside_tree():
		room.create_tween().tween_property(m, "shader_parameter/color_amount", v, TIME)
	else:
		m.set_shader_parameter("color_amount", v)


static func amount(room: Node) -> float:
	return float(material_for(room).get_shader_parameter("color_amount"))
