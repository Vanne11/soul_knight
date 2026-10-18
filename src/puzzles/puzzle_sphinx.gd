extends Puzzle
class_name PuzzleSphinx

## Esfinge de Penelandia (acertijo de palabras, sobre todo en el reino del pene). Una esfinge con
## una corona sospechosa te pregunta adivinanzas con doble sentido; se responde con E y se
## elige con el cuadro del narrador (como el Mito o Verdad). La respuesta buena siempre es la
## inocente. Una mala reinicia la tanda (con otras preguntas); tras varios fallos la Esfinge se
## apiada y pone la buena primera (asi tampoco se atasca el bot, que siempre marca la opcion 1).
## Dificultad: de 3 a 5 preguntas. Textos en locale/acertijos2.csv (PZ_SPH_*).

const INTERACTABLE := preload("res://src/items/interactable.gd")
const POOL := 8
const PITY_AFTER := 3   # fallos tras los que la respuesta buena sale primero

var _count := 3
var _round: Array[int] = []   # preguntas de esta tanda
var _step := 0
var _busy := false
var _sphinx: Sprite2D
var _it: Area2D


func build() -> void:
	kind = "sphinx"
	_count = clampi(3 + depth / 3, 3, 5)
	_sphinx = make_sprite("sphinx", Vector2(0, -56), 0)
	LightKit.add_contact_shadow(_sphinx, 34.0, 24.0).position = Vector2(0, 26)
	_it = Area2D.new()
	_it.set_script(INTERACTABLE)
	_it.prompt_text = tr("PZ_SPH_ASK")
	_it.position = Vector2(0, -22)
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 52.0
	_it.add_child(shape)
	_it.collision_layer = 0
	_it.collision_mask = 1
	_it.used.connect(_on_use)
	add_child(_it)
	_new_round()


func _new_round() -> void:
	var ids: Array[int] = []
	for i in POOL:
		ids.append(i + 1)
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := ids[i]
		ids[i] = ids[j]
		ids[j] = t
	_round = ids.slice(0, _count)
	_step = 0


func _process(delta: float) -> void:
	if not _busy:
		idle_hint(delta, 30.0)


func _on_use(_pl: Node) -> void:
	if done or _busy:
		return
	idle_reset()
	_ask()


func _ask() -> void:
	var q := _round[_step]
	var order := [0, 1, 2]
	if fails < PITY_AFTER:
		for i in range(2, 0, -1):
			var j := rng.randi_range(0, i)
			var t: int = order[i]
			order[i] = order[j]
			order[j] = t
	elif fails == PITY_AFTER and _step == 0 and not has_meta("pity_said"):
		set_meta("pity_said", true)
		Narrator.say_raw(tr("PZ_SPH_PITY"))
	var opts: Array = order.map(func(a): return tr("PZ_SPH_Q%d_A%d" % [q, a]))
	_busy = true
	Narrator.choose(tr("PZ_SPH_TITLE") % tr("PZ_SPH_Q%d" % q), opts)
	var pick: int = await Narrator.chosen
	_busy = false
	if not is_inside_tree() or done:
		return
	_plan.clear()
	if order[pick] == 0:
		_right()
	else:
		_wrong(q)


func _right() -> void:
	_step += 1
	Sound.play("tone_%d" % rng.randi_range(0, 3), 0.0)
	_sphinx.create_tween().tween_property(_sphinx, "modulate", Color(1.4, 1.3, 1.0), 0.1)
	_sphinx.create_tween().tween_property(_sphinx, "modulate", Color.WHITE, 0.5).set_delay(0.15)
	if _step >= _round.size():
		Narrator.say_raw(tr("PZ_SPH_DONE"))
		_it.finish()
		solve()
	else:
		Narrator.say_raw(tr("PZ_SPH_OK_%d" % mini(_step, 5)))


func _wrong(q: int) -> void:
	Sound.play("puzzle_fail")
	_sphinx.create_tween().tween_property(_sphinx, "modulate", Color.WHITE, 0.5).from(Color(1.0, 0.45, 0.45))
	Narrator.say_raw(tr("PZ_SPH_Q%d_W" % q))
	Narrator.say_raw(tr("PZ_SPH_BAD"))
	_new_round()
	note_fail()


func _bot_plan(_from: Vector2) -> Array:
	return [_wp(Vector2(0, -22), true)]
