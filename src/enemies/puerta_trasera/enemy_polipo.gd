extends EnemyPtBase
class_name EnemyPolipo

## POLIPO CALLADO (PT-17/29: muchos problemas no dan sintomas; el tamizaje busca antes de que los haya). No se mueve y no hace
## NADA: esta casi invisible (solo un contorno punteado en el suelo). Mientras nadie lo revisa CRECE: tras 11 s se hace grande y
## suelta anillos de esporas. REVISARLO es acercarte (a menos de 130 px) ~1 s, o pegarle: se ve, se queda tranquilo
## ("¡Revisado a tiempo!") y queda debil (mitad de vida). Moraleja: mejor mirar a tiempo que esperar sintomas.

enum S { HIDDEN, GROWN, CHECKED }

const CHECK_R := 130.0
const CHECK_T := 0.9
const GROW_T := 11.0
const HIDDEN_A := 0.16

var st := S.HIDDEN
var _check := 0.0
var _grow := 0.0
var _spore_t := 2.0
var _base_scale := Vector2.ONE
var _warn_t := 0.0


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.5}]
	move_speed = 0.0
	super()
	add_to_group("polipo_callado")
	_base_scale = animated_sprite.scale
	animated_sprite.modulate = Color(1, 1, 1, HIDDEN_A)


func _physics_process(delta: float) -> void:
	if state == State.DEAD or not _has_target():
		return
	velocity = Vector2.ZERO
	var d := global_position.distance_to(target.global_position)
	match st:
		S.HIDDEN, S.GROWN:
			if d < CHECK_R:
				_check += delta
				if _check >= CHECK_T:
					_checked(true)
			else:
				_check = maxf(0.0, _check - delta * 0.5)
			if st == S.HIDDEN:
				_grow += delta
				animated_sprite.modulate.a = HIDDEN_A + 0.06 * (0.5 + 0.5 * sin(_grow * 2.0))
				if _grow >= GROW_T:
					st = S.GROWN
					animated_sprite.scale = _base_scale * 1.35
					animated_sprite.modulate = Color(1, 1, 1, 0.75)
					say("PT_POLIPO_GREW", Color("ffb0c8"))
					_spore_t = 1.2
			else:
				_spore_t -= delta
				if _spore_t > 0.0 and _spore_t < 0.7:
					animated_sprite.modulate = Color(1.7, 1.2, 1.5) if int(_spore_t * 20.0) % 2 == 0 else Color(1, 1, 1, 0.75)
					_play(&"attack")
				if _spore_t <= 0.0:
					animated_sprite.modulate = Color(1, 1, 1, 0.75)
					_play(&"strike")
					shoot_ring(8, 150.0, damage * 0.6, Color(1.0, 0.7, 0.85), RNG.randf() * TAU)
					_spore_t = 2.6
		S.CHECKED:
			_play(&"idle")
	_face(target.global_position.x - global_position.x)
	queue_redraw()


## Revisado: se ve, se calma y queda debil.
func _checked(by_walking: bool) -> void:
	if st == S.CHECKED:
		return
	st = S.CHECKED
	animated_sprite.scale = _base_scale
	animated_sprite.modulate = Color.WHITE
	current_health = minf(current_health, max_health * 0.5)
	if by_walking:
		say("PT_POLIPO_CHECKED", Color("9be37a"))
	Sound.play("pickup")
	_play(&"idle")


func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if st != S.CHECKED and current_health - amount > 0.0:
		_checked(false)
	return super.take_damage(amount, source, Vector2.ZERO)


func reveal(_seconds: float) -> void:
	_checked(false)


func _draw() -> void:
	if st == S.CHECKED:
		return
	# contorno punteado: "aqui hay algo que mirar" + anillo de revision que se llena al acercarte
	var r := 26.0 if st == S.HIDDEN else 34.0
	var a := 0.35 + 0.2 * sin(Time.get_ticks_msec() / 300.0)
	for i in 16:
		var ang := TAU * float(i) / 16.0
		if i % 2 == 0:
			draw_arc(Vector2(0, -20), r, ang, ang + TAU / 32.0, 4, Color(1.0, 0.75, 0.85, a), 2.0)
	if _check > 0.0:
		draw_arc(Vector2(0, -20), r + 6.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(_check / CHECK_T, 0.0, 1.0), 24, Color(0.6, 1.0, 0.7, 0.9), 3.0)
