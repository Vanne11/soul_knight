extends Puzzle
class_name PuzzleStamps

## Perineo: papeleo de sellos. Cuatro sellos en el suelo (circulo, triangulo, cuadrado y
## estrella) y, enfrente, un formulario con los sellos en el orden del tramite. Nadie dice
## que hay que seguirlo: el formulario esta ahi, como en cualquier oficina. Pisar un sello
## fuera de turno estampa "RECHAZADO" en el formulario y el tramite empieza de cero.
## Dificultad: el tramite pide 3 a 5 sellos y desde la profundidad 3 puede repetir.

const SPACING := 76.0

var _seq: Array[int] = []
var _step := 0
var _plates: Array[PuzzlePlate] = []
var _papers: Array[Sprite2D] = []
var _stamp_label: Label
var _locked := false


func build() -> void:
	kind = "stamps"
	var length := clampi(3 + (depth - 1) / 2, 3, 5)
	var y_row := clampf(area.y * 0.5 - 30.0, 20.0, 44.0)
	for i in 4:
		var p := PuzzlePlate.new().setup(kingdom)
		p.position = Vector2((i - 1.5) * SPACING, y_row)
		p.tag = i
		p.set_glyph("stamp_%d" % i, -3.0)
		p.stepped.connect(_on_step)
		add_child(p)
		_plates.append(p)
	var last := -1
	for k in length:
		var v := rng.randi_range(0, 3)
		while depth < 3 and v == last:
			v = rng.randi_range(0, 3)
		_seq.append(v)
		last = v
	for k in length:
		var holder := Node2D.new()
		holder.position = Vector2((k - (length - 1) * 0.5) * 40.0, -y_row - 8.0)
		var paper := Sprite2D.new()
		paper.texture = PuzzlePlate.load_tex("paper")
		paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		holder.add_child(paper)
		var g := Sprite2D.new()
		g.texture = PuzzlePlate.load_tex("stamp_%d" % _seq[k])
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.position = Vector2(0, -6)
		holder.add_child(g)
		add_child(holder)
		_papers.append(paper)
	_stamp_label = make_label(tr("PZ_REJECTED"), 16, Color("d83a3a"))
	_stamp_label.size = Vector2(200, 24)
	_stamp_label.position = Vector2(-100, -y_row - 22.0)
	_stamp_label.rotation = deg_to_rad(-9.0)
	_stamp_label.pivot_offset = _stamp_label.size / 2
	_stamp_label.visible = false
	_stamp_label.z_index = 2
	add_child(_stamp_label)


func _on_step(plate: PuzzlePlate) -> void:
	if done or _locked:
		return
	_plan.clear()
	var i := plate.tag
	if i != _seq[_step]:
		_reject()
		return
	_papers[_step].modulate = Color(0.75, 1.1, 0.75)
	_step += 1
	Sound.play("tone_%d" % i, 0.0)
	plate.flash(Color(1.5, 1.5, 1.5), 0.3)
	if _step == _seq.size():
		for p in _plates:
			p.flash(Color(1.8, 1.8, 1.8), 1.0)
		solve()


func _reject() -> void:
	_locked = true
	Sound.play("puzzle_fail")
	Sound.play("crack")
	_stamp_label.visible = true
	_stamp_label.scale = Vector2(2.6, 2.6)
	_stamp_label.modulate = Color.WHITE
	var tw := _stamp_label.create_tween()
	tw.tween_property(_stamp_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(0.9)
	tw.tween_property(_stamp_label, "modulate:a", 0.0, 0.25)
	await tw.finished
	_stamp_label.visible = false
	for p in _papers:
		p.modulate = Color.WHITE
	_step = 0
	_locked = false
	_plan.clear()
	note_fail()


func _bot_plan(from: Vector2) -> Array:
	if _locked or _step >= _seq.size():
		return [_wp(from)]
	var target: Vector2 = _plates[_seq[_step]].position
	var lane_y: float = _plates[0].position.y + 36.0  # pasillo bajo la fila de sellos
	var route: Array = []
	if absf(from.y - _plates[0].position.y) < 30.0:
		# sobre la fila de sellos: baja al pasillo, avanza y entra por abajo (asi tambien
		# se repite un sello: hay que salir de el y volver a pisarlo)
		route.append(_wp(Vector2(from.x, lane_y)))
		route.append(_wp(Vector2(target.x, lane_y)))
	route.append(_wp(target))
	return route
