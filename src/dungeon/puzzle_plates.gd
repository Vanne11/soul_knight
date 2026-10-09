extends Node2D

## Puzzle de memoria: cuatro baldosas se encienden en orden y hay que pisarlas
## en el mismo orden. Al resolverlo emite solved (main.gd abre las salas secretas).

signal solved

const COLORS := [Color("e0525a"), Color("5aa0e0"), Color("e0c95a"), Color("6ad07a")]
const DIM := Color(0.3, 0.3, 0.3)
const SPACING := 140.0

var length := 3
var _seq: Array[int] = []
var _step := 0
var _busy := false
var _done := false
var _plates: Array[ColorRect] = []


func _ready() -> void:
	for i in COLORS.size():
		var area := Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 1  # el jugador
		area.position = Vector2((i % 2 - 0.5) * SPACING, (i / 2 - 0.5) * SPACING)
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(48, 48)
		area.add_child(shape)
		var rect := ColorRect.new()
		rect.size = Vector2(56, 56)
		rect.position = -rect.size / 2
		rect.color = COLORS[i]
		rect.modulate = DIM
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(rect)
		add_child(area)
		_plates.append(rect)
		area.body_entered.connect(_on_step.bind(i))
	for i in length:
		_seq.append(RNG.randi_range(0, COLORS.size() - 1))
	play()


## Muestra la secuencia. Mientras suena no se puede pisar.
func play() -> void:
	if _done or _busy:
		return
	_busy = true
	_step = 0
	await get_tree().create_timer(1.0).timeout
	for i in _seq:
		Sound.play("tone_%d" % i, 0.0)
		var tw := _plates[i].create_tween()
		tw.tween_property(_plates[i], "modulate", Color.WHITE, 0.05)
		tw.tween_interval(0.4)
		tw.tween_property(_plates[i], "modulate", DIM, 0.15)
		await tw.finished
		await get_tree().create_timer(0.15).timeout
	_busy = false


func solve() -> void:
	if _done:
		return
	_done = true
	for p in _plates:
		p.modulate = Color.WHITE
	Sound.play("puzzle_solve")
	solved.emit()


func _on_step(body: Node, i: int) -> void:
	if _done or _busy or not body.is_in_group("player"):
		return
	if i != _seq[_step]:
		for p in _plates:
			p.create_tween().tween_property(p, "modulate", DIM, 0.5).from(Color(1, 0.2, 0.2))
		Narrator.say("puzzle_fail")
		Sound.play("puzzle_fail")
		play()
		return
	_step += 1
	Sound.play("tone_%d" % i, 0.0)
	if _step == _seq.size():
		solve()
		return
	_plates[i].create_tween().tween_property(_plates[i], "modulate", DIM, 0.4).from(Color.WHITE)
