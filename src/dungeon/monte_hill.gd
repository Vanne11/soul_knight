class_name MonteHill
extends Node2D

## La loma del Monte de Venus (sala de src/dungeon/monte_venus.gd), al estilo A Link to the Past:
## dos MESETAS planas, una sobre otra. Arriba de cada una hay suelo normal (el heroe camina sobre
## suelo, no sobre un dibujo) y de cada borde cuelga una PARED de tierra con colision. Solo se sube
## por las RAMPAS (el heroe va al 70%), y se baja saltando por las repisas (un solo sentido, en arco).
## Las matas de VELLO tapan los pies y se mecen al pasar (al 85%): no se cortan, el vello es normal.
## Algunas rampas estan tapadas con cera endurecida de Dona Cera (WaxBlock, sin danio): se rompe a
## golpes y disparos y el camino queda abierto.
##
## Todo en coordenadas locales de la loma (esquina arriba-izquierda). El orden de dibujo es por y:
## lo que se levanta del suelo (borde norte, matas, cera, nota) se dibuja sobre el heroe (z_index 2)
## mientras sus pies estan por encima de la base de la pieza, y bajo el en caso contrario. Las
## paredes, rampas y bordes laterales son suelo: siempre bajo el heroe.
## Arte: tools/gen_monte_venus_art2.py -> assets/sprites/environment/monte/

signal ramp_entered

const DIR := "res://assets/sprites/environment/monte/"
const SIZE := Vector2(400, 276)
const FACE := 40.0  # alto de la pared de tierra bajo cada meseta
const RIM := 14.0  # alto del borde de pasto
const EDGE := 8.0  # grosor de los muros invisibles que siguen el borde
const RAMP_W := 44.0  # ancho libre de una rampa (entre sus troncos)
const RAMP_SLOW := 0.7
const TUFT_SLOW := 0.85
const FOOT := 12.0  # los pies del heroe respecto a su origen (mitad de su caja de colision)
const HOP_HOLD := 0.15  # segundos empujando hacia abajo en una repisa antes de saltar
## Mesetas de abajo a arriba. top = suelo pisable; ramps = [x del centro, tapada con cera];
## ledge = [x del centro, ancho] de la repisa por donde se salta hacia abajo.
const PLATEAUS := [
	{"top": Rect2(0, 0, 400, 236), "grass": "grass_b", "wall": "ramp_wood", "ramps": [[48.0, false], [352.0, true]], "ledge": [200.0, 48.0]},
	{"top": Rect2(92, 50, 216, 96), "grass": "grass_a", "wall": "ramp_stone", "ramps": [[146.0, true], [254.0, true]], "ledge": [200.0, 40.0]},
]
## Donde crecen las matas: [rectangulo, cuantas].
const PATCHES := [
	[Rect2(8, 56, 70, 140), 9], [Rect2(322, 56, 70, 140), 9], [Rect2(84, 198, 232, 30), 8], [Rect2(8, 8, 384, 26), 6],
]
const TUFTS := ["tuft_a", "tuft_b", "tuft_c", "tuft_d", "tuft_e"]
const TUFT_FEET := Vector2(15.0, 9.0)  # elipse (radio x, y) donde un heroe "esta en la mata"

var summit := Rect2()  # suelo de la cima (locales)
var _body := StaticBody2D.new()
var _sorted: Array = []  # [nodo, y de la base]
var _ramp_zones: Array[Rect2] = []
var _ledges: Array[Dictionary] = []  # zone, land
var _tufts: Array[Dictionary] = []  # node, base
var _wax: Array = []  # WaxBlock (se liberan al romperse)
var _hold := 0.0
var _said := {}


static func build(room: Room) -> MonteHill:
	var hill := MonteHill.new()
	hill.name = "MonteLoma"
	hill.position = (room.get_center_position() - SIZE * 0.5).round()
	var ref := room.get_node_or_null("Decor")
	room.add_child(hill)
	room.move_child(hill, (ref.get_index() if ref else room.walls_tilemap.get_index()) + 1)
	hill._build(hash([room.grid_pos, "monte_vello"]))
	return hill


static func _tex(name: String) -> Texture2D:
	return load(DIR + name + ".png")


func _build(seed_: int) -> void:
	_body.name = "Muros"
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	for i in PLATEAUS.size():
		_plateau(PLATEAUS[i], i)
	var up: Rect2 = PLATEAUS[PLATEAUS.size() - 1].top
	summit = up
	_decor(up)
	_grow_tufts(seed_)


# ------------------------------------------------------------------ mesetas
func _plateau(p: Dictionary, idx: int) -> void:
	var top: Rect2 = p.top
	var face_y := top.end.y
	# suelo: pasto en baldosas sin costuras
	_tiled(_tex(p.grass), top)
	# bordes: norte (se dibuja delante del heroe que pasa por detras), oeste y este
	var north := _tiled(_tex("rim_north"), Rect2(top.position, Vector2(top.size.x, RIM)))
	_sorted.append([north, top.position.y + RIM])
	for side in 2:
		var x := top.position.x if side == 0 else top.end.x - 16.0
		var rim := Node2D.new()
		rim.position = Vector2(x, top.position.y)
		_tiled(_tex("rim_side_top"), Rect2(0, 0, 16, 10), rim)
		_tiled(_tex("rim_side_mid"), Rect2(0, 10, 16, top.size.y - 32.0), rim)
		var bot := Sprite2D.new()
		bot.texture = _tex("rim_side_bot")
		bot.centered = false
		bot.position = Vector2(0, top.size.y - 22.0)
		rim.add_child(bot)
		if side == 1:
			rim.scale.x = -1.0
			rim.position.x += 16.0
		add_child(rim)
	# la pared de tierra: tiras de 128 px que se alternan, recortadas al ancho de la meseta
	var face := Node2D.new()
	var x0 := top.position.x
	var n := 0
	while x0 < top.end.x - 0.5:
		var w := minf(128.0, top.end.x - x0)
		var s := Sprite2D.new()
		s.texture = _tex("wall_a" if n % 2 == 0 else "wall_b")
		s.centered = false
		s.region_enabled = true
		s.region_rect = Rect2(0, 0, w, FACE)
		s.position = Vector2(x0, face_y)
		face.add_child(s)
		x0 += 128.0
		n += 1
	add_child(face)
	# colision: contorno exterior y la cara, con un hueco por rampa
	_wall(Rect2(top.position.x - EDGE, top.position.y - EDGE, top.size.x + EDGE * 2.0, EDGE))
	_wall(Rect2(top.position.x - EDGE, top.position.y - EDGE, EDGE, top.size.y + FACE + EDGE))
	_wall(Rect2(top.end.x, top.position.y - EDGE, EDGE, top.size.y + FACE + EDGE))
	var gaps: Array = []
	for r in p.ramps:
		gaps.append([r[0] - RAMP_W * 0.5, r[0] + RAMP_W * 0.5])
	gaps.sort_custom(func(a, b): return a[0] < b[0])
	var from := top.position.x
	for g in gaps:
		_wall(Rect2(from, face_y, g[0] - from, FACE))
		from = g[1]
	_wall(Rect2(from, face_y, top.end.x - from, FACE))
	for r in p.ramps:
		_ramp(p, r[0], face_y, r[1])
	_ledge(p, face_y, idx)


func _ramp(p: Dictionary, cx: float, face_y: float, waxed: bool) -> void:
	var s := Sprite2D.new()
	s.texture = _tex(p.wall)
	s.centered = false
	s.position = Vector2(cx - 32.0, face_y - 6.0)
	add_child(s)
	_ramp_zones.append(Rect2(cx - RAMP_W * 0.5, face_y - 8.0, RAMP_W, FACE + 22.0))
	if not waxed:
		return
	var w := WaxBlock.hardened(Vector2(cx, face_y + 30.0), 28.0, _tex("wax"), _tex("wax_broken"), _tex("wax_crumbs"))
	add_child(w)
	_wax.append(w)
	_sorted.append([w, face_y + 44.0])


## Repisa: tramo de pared sin rampa; empujando hacia abajo encima de ella se salta a la meseta de abajo.
func _ledge(p: Dictionary, face_y: float, idx: int) -> void:
	var cx: float = p.ledge[0]
	var w: float = p.ledge[1]
	var top: Rect2 = p.top
	for i in 3:  # tres chevrones que parpadean en cascada
		var c := Polygon2D.new()
		c.polygon = PackedVector2Array([Vector2(-7, 0), Vector2(0, 5), Vector2(7, 0), Vector2(7, 3), Vector2(0, 8), Vector2(-7, 3)])
		c.color = Color(1.0, 0.95, 0.75, 0.85)
		c.position = Vector2(cx + (i - 1) * 12.0, face_y - 18.0 + absf(i - 1) * -2.0)
		add_child(c)
		var tw := c.create_tween().set_loops()
		tw.tween_interval(i * 0.15)
		tw.tween_property(c, "modulate:a", 0.25, 0.4)
		tw.tween_property(c, "modulate:a", 1.0, 0.4)
		tw.tween_interval(0.5 - i * 0.15)
	var land_y := face_y + FACE + 24.0
	_ledges.append({"zone": Rect2(cx - w * 0.5, face_y - 22.0, w, 22.0), "land": Vector2(cx, land_y)})


# ------------------------------------------------------------------ adorno de la cima
func _decor(up: Rect2) -> void:
	var c := up.get_center()
	var ring := Sprite2D.new()
	ring.texture = _tex("summit")
	ring.position = c + Vector2(0, 2)
	add_child(ring)
	var note := Sprite2D.new()  # la nota de Dona Cera, clavada en su estaca
	note.texture = _tex("note")
	note.centered = false
	note.offset = Vector2(-15, -44)
	note.position = c + Vector2(52, 24)
	add_child(note)
	_sorted.append([note, note.position.y])
	for off in [Vector2(-96, 18), Vector2(60, -34)]:
		var st := Sprite2D.new()
		st.texture = _tex("stone")
		st.position = c + off
		add_child(st)


func _grow_tufts(seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var spots: Array[Vector2] = []
	for patch in PATCHES:
		var r: Rect2 = patch[0]
		var put := 0
		var tries := 0
		while put < patch[1] and tries < 80:
			tries += 1
			var at := r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y)
			if spots.any(func(s: Vector2): return s.distance_to(at) < 22.0):
				continue
			if _ramp_zones.any(func(z: Rect2): return z.grow(14.0).has_point(at)):
				continue  # las rampas no se tapan
			spots.append(at)
			put += 1
			_tuft(at, TUFTS[rng.randi_range(0, TUFTS.size() - 1)], rng.randf() < 0.5)


func _tuft(at: Vector2, name: String, flip: bool) -> void:
	var root := Node2D.new()
	root.position = at
	var s := Sprite2D.new()
	s.texture = _tex(name)
	s.centered = false
	s.offset = Vector2(-s.texture.get_width() * 0.5, -s.texture.get_height() + 2.0)
	s.flip_h = flip
	root.add_child(s)
	add_child(root)
	_sorted.append([root, at.y])
	_tufts.append({"node": root, "busy": false})


# ------------------------------------------------------------------ piezas
## Textura repetida sobre `r` (baldosas sin costuras o tiras). Cuelga de `parent` o de la loma.
func _tiled(tex: Texture2D, r: Rect2, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, r.size)
	s.position = r.position
	(parent if parent != null else self).add_child(s)
	return s


func _wall(r: Rect2) -> void:
	if r.size.x <= 0.5 or r.size.y <= 0.5:
		return
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	_body.add_child(cs)


# ------------------------------------------------------------------ vida
func _physics_process(delta: float) -> void:
	var pl := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if pl == null or pl.is_hopping():
		return
	var at := to_local(pl.global_position)
	_sort(at.y + FOOT)
	var foot := at + Vector2(0, FOOT - 4.0)
	var slow := 1.0
	for z in _ramp_zones:
		if z.has_point(foot):
			slow = RAMP_SLOW
			if not _said.has("ramp"):
				_said["ramp"] = true
				ramp_entered.emit()
	for t in _tufts:
		var node: Node2D = t.node
		var d := foot - node.position
		if absf(d.x) < TUFT_FEET.x and absf(d.y + 4.0) < TUFT_FEET.y:
			slow = minf(slow, TUFT_SLOW)
			_sway(t, signf(pl.velocity.x) if absf(pl.velocity.x) > 1.0 else 1.0)
			_hint("vello", pl, "MONTE_VELLO", Color("c98a4b"))
	if slow < 1.0:
		pl.set_terrain_slow(slow)
	for w in _wax:
		if is_instance_valid(w) and w.position.distance_to(foot) < 70.0:
			_hint("cera", pl, "MONTE_CERA_HINT", Color("ffc84a"))
	_check_ledges(pl, foot, delta)


## Pared/mata delante del heroe (sus pies estan por encima de la base) = se dibuja sobre el.
func _sort(feet_y: float) -> void:
	for it in _sorted:
		var node = it[0]  # sin tipo: la cera rota ya esta liberada
		if not is_instance_valid(node):
			continue
		var z := 2 if feet_y < float(it[1]) else 0
		if node.z_index != z:
			node.z_index = z


## La mata se dobla al paso del heroe y vuelve con rebote; no se corta ni se destruye.
func _sway(t: Dictionary, dir: float) -> void:
	if t.busy:
		return
	t.busy = true
	var node: Node2D = t.node
	var tw := node.create_tween()
	tw.tween_property(node, "rotation", 0.22 * dir, 0.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): t.busy = false)


func _check_ledges(pl: CharacterBody2D, foot: Vector2, delta: float) -> void:
	var on_edge := false
	for l in _ledges:
		if l.zone.has_point(foot):
			on_edge = true
			_hint("salto", pl, "MONTE_SALTO", Color("fff2c0"))
			if Input.get_action_strength("move_down") > 0.5:
				_hold += delta
				if _hold >= HOP_HOLD and pl.hop(to_global(l.land)):
					_hold = 0.0
					Sound.play("crack", 0.1)
	if not on_edge:
		_hold = 0.0


## Texto flotante la primera vez (una por tema y sala).
func _hint(id: String, pl: Node2D, key: String, color: Color) -> void:
	if _said.has(id):
		return
	_said[id] = true
	get_node("/root/GlobalEvents").show_floating_text.emit(pl.global_position + Vector2(0, -34), tr(key), color)
