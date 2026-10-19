class_name TemploAnubis
extends RefCounted

## EL TEMPLO DE ANUBIS (id interno "puerta_trasera"): ayudas del desvio secreto del Perineo.
##  - has_condoms(): la condicion SECRETA de la puerta biologica (junto al disparo de lubricante, ver iris_door.gd).
##  - flank(): decora la puerta con DOS ESTATUAS DE ANUBIS, una inscripcion de jeroglificos mudos en el umbral
##    y el graffiti mudo (un condon y una gotita), el guiño que nunca explica nada.
## Arte: assets/sprites/environment/decor/anubis_*.png (tools/gen_anubis_art.py).

const DIR := "res://assets/sprites/environment/decor/"
## Cualquier condon vale: arma (Globocondon, lanzapreservativos, atrapabalas) o reliquia (Preservativo).
const CONDOM_ITEMS := ["globocondon", "launcher_condom", "preservativo_atrapabalas", "relic_condom"]


## true si el heroe lleva algun condon: objeto de los de arriba (en mano, mochila o ranura) o el
## preservativo del consultorio (inmunidad temporal).
static func has_condoms(tree: SceneTree) -> bool:
	var p := tree.get_first_node_in_group("player")
	if p == null:
		return false
	if "collected_items" in p:
		for id in CONDOM_ITEMS:
			if p.collected_items.has(id):
				return true
	var ps := tree.root.get_node_or_null("PlayerStats")
	if ps != null and float(ps.get("_infect_immune_left")) > 0.0:
		return true
	return false


## Guiño: Don Sildenafil (jefe o sus pastillitas) ya aparecio en ESTA partida (se compara con la semilla de la partida).
static var _sildenafil_seed := -1


static func run_seed() -> int:
	return int((Engine.get_main_loop() as SceneTree).root.get_node("RunManager").current_seed)


static func met_sildenafil() -> void:
	_sildenafil_seed = run_seed()


static func has_met_sildenafil() -> bool:
	return _sildenafil_seed != -1 and _sildenafil_seed == run_seed()


static func _tex(name: String) -> Texture2D:
	var path := DIR + name + ".png"
	return load(path) if ResourceLoader.exists(path) else null


static func _prop(parent: Node, name: String, feet: Vector2, flip := false) -> void:
	var tex := _tex(name)
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.flip_h = flip
	s.position = feet - Vector2(tex.get_width() * 0.5, tex.get_height())
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_index = 1
	parent.add_child(s)


## Flanquea una puerta biologica (en la pared norte) con dos estatuas, la inscripcion muda y el graffiti.
static func flank(iris: Node2D, parent: Node) -> void:
	var c := iris.position
	_prop(parent, "anubis_statue", c + Vector2(-92, 44))
	_prop(parent, "anubis_statue", c + Vector2(92, 44), true)
	_prop(parent, "anubis_inscripcion", c + Vector2(0, 112))
	var g := Graffiti.new()
	g.position = c + Vector2(-168, 14)
	parent.add_child(g)


## Cartel mudo junto a la puerta: un condon y una gotita (sin letras: no explica nada).
class Graffiti extends Node2D:
	func _ready() -> void:
		z_index = 1
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		var ink := Color("2a1a10")
		draw_rect(Rect2(-17, -22, 34, 44), ink)
		draw_rect(Rect2(-15, -20, 30, 40), Color("e8d8b0"))
		draw_rect(Rect2(-15, -20, 30, 5), Color("c9b080"))
		# el condon: sobrecito cuadrado con aro
		draw_rect(Rect2(-12, -10, 14, 14), ink)
		draw_rect(Rect2(-11, -9, 12, 12), Color("5ec8d8"))
		draw_arc(Vector2(-5, -3), 3.2, 0.0, TAU, 14, ink, 1.4)
		# la gotita
		var drop := PackedVector2Array([Vector2(8, 2), Vector2(12, 9), Vector2(11, 14), Vector2(8, 16), Vector2(5, 14), Vector2(4, 9)])
		draw_colored_polygon(drop, Color("3a8fe0"))
		draw_polyline(drop + PackedVector2Array([drop[0]]), ink, 1.2)
		draw_circle(Vector2(7, 11), 1.2, Color(1, 1, 1, 0.8))
		# cinta
		draw_rect(Rect2(-6, -25, 12, 5), Color(0.9, 0.85, 0.6, 0.7))
