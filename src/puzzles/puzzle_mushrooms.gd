extends Puzzle
class_name PuzzleMushrooms

## Selva Pubica: memoria con setas. Cuatro setas sobre placas; al entrar en la sala brillan
## en un orden (y suena un tono cada una). Nadie dice que hay que repetirlo: pisar una seta
## la hace sonar, y si no es la que tocaba, las esporas se disipan y vuelven a brillar.
## Dificultad: la secuencia crece con la profundidad (3 a 6 pasos).

const NAMES := ["roja", "azul", "amarilla", "verde"]
const GLOW := [Color(1.9, 1.2, 1.2), Color(1.2, 1.5, 1.9), Color(1.9, 1.8, 1.1), Color(1.2, 1.9, 1.3)]

var length := 3
var _seq: Array[int] = []
var _step := 0
var _busy := false
var _plates: Array[PuzzlePlate] = []
var _gen := 0  # invalida una secuencia a medio mostrar si hay otra nueva


func build() -> void:
	kind = "mushrooms"
	length = clampi(3 + (depth - 1) / 2, 3, 6)
	var hx := clampf(area.x * 0.5 - 24.0, 60.0, 104.0)
	var hy := clampf(area.y * 0.5 - 22.0, 44.0, 72.0)
	var spots := [Vector2(-hx, 0), Vector2(hx, 0), Vector2(0, -hy), Vector2(0, hy)]
	for i in 4:
		var p := PuzzlePlate.new().setup(kingdom)
		p.position = spots[i]
		p.tag = i
		p.set_glyph("mushroom_%d" % i, -8.0)
		p.stepped.connect(_on_step)
		add_child(p)
		_plates.append(p)
	for i in length:
		_seq.append(rng.randi_range(0, 3))
	play()


## Muestra la secuencia. Mientras suena no se puede pisar.
func play() -> void:
	if done or _busy:
		return
	_busy = true
	_step = 0
	_plan.clear()
	_gen += 1
	var g := _gen
	await get_tree().create_timer(1.0).timeout
	for i in _seq:
		if g != _gen or not is_inside_tree():
			return
		_glow(i, 0.45)
		await get_tree().create_timer(0.62).timeout
	if g == _gen:
		_busy = false
		_plan.clear()


func replay() -> void:
	play()


func _glow(i: int, secs: float) -> void:
	Sound.play("tone_%d" % i, 0.0)
	var g := _plates[i].glyph()
	var tw := g.create_tween()
	tw.tween_property(g, "modulate", GLOW[i], 0.05)
	tw.tween_interval(secs)
	tw.tween_property(g, "modulate", Color.WHITE, 0.15)
	var tp := _plates[i].create_tween()
	tp.tween_property(_plates[i].base(), "modulate", Color(1.5, 1.5, 1.5), 0.05)
	tp.tween_interval(secs)
	tp.tween_property(_plates[i].base(), "modulate", Color.WHITE, 0.15)


func _on_step(plate: PuzzlePlate) -> void:
	if done or _busy:
		return
	var i := plate.tag
	if i != _seq[_step]:
		for p in _plates:
			p.create_tween().tween_property(p, "modulate", Color.WHITE, 0.5).from(Color(1.0, 0.35, 0.35))
		Sound.play("puzzle_fail")
		note_fail()
		play()
		return
	_step += 1
	_plan.clear()
	_glow(i, 0.12)
	if _step == _seq.size():
		for p in _plates:
			p.flash(Color(1.8, 1.8, 1.8), 1.0)
		solve()


func hint(level: int, _args := {}) -> void:
	# la pista final nombra los colores en orden (como antes, pero solo tras fallar)
	super(level, {"seq": " → ".join(_seq.map(func(s): return tr("PZ_MUSH_%d" % s)))})


func _bot_plan(from: Vector2) -> Array:
	if _busy:
		return [_wp(Vector2.ZERO)]  # mira la secuencia desde el centro
	if _step >= _seq.size():
		return []
	var target: Vector2 = _plates[_seq[_step]].position
	if from.distance_to(target) < 20.0:
		return [_wp(Vector2.ZERO), _wp(target)]  # misma seta dos veces: hay que salir y volver a entrar
	return [_wp(target)]
