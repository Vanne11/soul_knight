extends Node
class_name TallProp

## Profundidad por orden de Y para todo lo alto (obstaculos, columnas, estatuas, carteles, el reloj...).
## Se cuelga de un nodo con `TallProp.attach(nodo, caja)`; `caja` es el dibujo del objeto en
## coordenadas locales del nodo y su borde inferior es la BASE (el punto de orden).
##  - Quien tenga los pies mas ARRIBA que la base (esta detras) y pise la caja ensanchada: el objeto
##    sube a z_index +2 y se dibuja por delante.
##  - Si ese alguien es el heroe y el objeto es alto, ademas se vuelve semitransparente (FADE_ALPHA)
##    mientras lo tape, para no perderlo de vista.
##  - Con los pies mas abajo que la base (delante) el nodo vuelve a su z_index y el heroe va encima.
## Cuentan el grupo "player" y los de "enemy" y "enemy_attack" (balas). Cada fotograma se leen una sola
## vez las posiciones para todos los TallProp. El monte de Venus lleva su propio orden (monte_hill.gd).

const FEET := 12.0         # de la posicion de un actor a sus pies
const MARGIN := 12.0       # holgura lateral de la caja
const FADE_ALPHA := 0.45
const FADE_SPEED := 6.0
const FADE_MIN_H := 36.0   # solo los objetos tan altos como esto se vuelven transparentes
const FRONT_Z := 2

static var _frame := -1
static var _player := Vector2.INF
static var _others: Array[Vector2] = []

var target: Node2D
var box := Rect2()
var fade := true
var _base_z := 0
var _started := false


## Engancha el orden por Y a `target`. `box`: dibujo del objeto en coordenadas locales de `target`.
static func attach(target_: Node2D, box_: Rect2, fade_ := true) -> TallProp:
	var tp := TallProp.new()
	tp.name = "TallProp"
	tp.target = target_
	tp.box = box_
	tp.fade = fade_ and box_.size.y >= FADE_MIN_H
	target_.add_child(tp)
	return tp


## Caja de un Sprite2D / AnimatedSprite2D / Polygon2D en SU espacio local (con offset y centered).
static func own_rect(n: Node2D) -> Rect2:
	var tex: Texture2D = null
	var off := Vector2.ZERO
	var centered := false
	if n is Sprite2D:
		var s := n as Sprite2D
		tex = s.texture
		off = s.offset
		centered = s.centered
	elif n is AnimatedSprite2D and (n as AnimatedSprite2D).sprite_frames:
		var a := n as AnimatedSprite2D
		tex = a.sprite_frames.get_frame_texture(a.animation, 0)
		off = a.offset
		centered = a.centered
	elif n is Polygon2D and not (n as Polygon2D).polygon.is_empty():
		var pts := (n as Polygon2D).polygon
		var r := Rect2(pts[0], Vector2.ZERO)
		for pt in pts:
			r = r.expand(pt)
		return r
	if tex == null:
		return Rect2()
	return Rect2(off - (tex.get_size() * 0.5 if centered else Vector2.ZERO), tex.get_size())


## Caja de un Sprite2D en coordenadas de su padre (para engancharlo al padre).
static func box_of(s: Sprite2D) -> Rect2:
	var r := own_rect(s)
	return Rect2(s.position + r.position * s.scale, r.size * s.scale)


## Engancha el orden por Y a un prop interactivo `it` (Interactable) con el dibujo `visual` dentro:
## la caja sale de sus Polygon2D / Sprite2D / AnimatedSprite2D. No hace nada si el visual no es
## "tall" (los de suelo, como los portales, van planos), salvo con `force`, o si no tiene dibujo medible.
static func attach_visual(it: Node2D, visual: Node2D, force := false) -> void:
	if not (force or visual.has_meta("tall")) or it.has_node("TallProp"):
		return
	var r := own_rect(it) if visual == it else _bounds(visual, visual.position)
	if r.size.x > 0.0 and r.size.y > 0.0:
		attach(it, r)


## Union (solo traslaciones) de lo que dibuja `n` y sus hijos, en el espacio del padre de `n` + `at`.
static func _bounds(n: Node2D, at: Vector2) -> Rect2:
	var r := Rect2()
	var found := false
	var own := own_rect(n)
	if own.size.x > 0.0:
		r = Rect2(own.position * n.scale + at, own.size * n.scale)
		found = true
	for c in n.get_children():
		if c is Node2D and not (c is Light2D):
			var cr := _bounds(c as Node2D, at + (c as Node2D).position)
			if cr.size.x > 0.0:
				r = r.merge(cr) if found else cr
				found = true
	return r


static func _refresh(tree: SceneTree) -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	_frame = f
	_player = Vector2.INF
	_others.clear()
	var pl := tree.get_first_node_in_group("player") as Node2D
	if pl:
		_player = pl.global_position + Vector2(0.0, FEET)
	for g in ["enemy", "enemy_attack"]:
		for n in tree.get_nodes_in_group(g):
			if n is Node2D and (n as Node2D).is_visible_in_tree():
				_others.append((n as Node2D).global_position + Vector2(0.0, FEET))


func _process(delta: float) -> void:
	if target == null or not target.is_inside_tree():
		return
	if not _started:
		_started = true
		_base_z = target.z_index
	_refresh(get_tree())
	var zone := box.grow_individual(MARGIN, 0.0, MARGIN, 0.0)
	var hero_behind := _behind(_player, zone)
	var behind := hero_behind
	if not behind:
		for p in _others:
			if _behind(p, zone):
				behind = true
				break
	var z := _base_z + (FRONT_Z if behind else 0)
	if target.z_index != z:
		target.z_index = z
	if fade:
		var a := target.modulate.a
		var goal := FADE_ALPHA if hero_behind else 1.0
		if not is_equal_approx(a, goal):
			target.modulate.a = move_toward(a, goal, delta * FADE_SPEED)


## true si los pies (globales) estan detras de la base y dentro de la zona del dibujo.
func _behind(feet_global: Vector2, zone: Rect2) -> bool:
	if feet_global == Vector2.INF:
		return false
	var f := target.to_local(feet_global)
	return f.y < zone.end.y and zone.has_point(f)
