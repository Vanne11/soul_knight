extends EnemyPtBase
class_name EnemyFrasquito

## FRASQUITO MAGICO (templo de Anubis): arma de los malos en clave de REDUCCION DE DAÑOS (codice sobrio "ene_frasquito",
## marcado REVISAR para Vanessa en datos_ano.md). NO es llave de nada. Se mantiene a distancia, AVISA 0,9 s (destapado,
## tiembla y marca una zona amarillenta delante de el) y suelta VAPORES que MAREAN: la pantalla ondula y el control se
## pone torpe unos segundos (StatusEffects "mareado"). No hace daño directo con los vapores; es incomodo, no letal.
## Guiño: si en esta partida ya te cruzaste con Don Sildenafil, al aparecer el Frasquito sale la alerta
## "¡Popper + Sildenafil = NO!" (una vez por partida).

enum S { KEEP, WINDUP, BLOW, REST }

const KEEP_MIN := 170.0
const KEEP_MAX := 250.0
const WARN_COL := Color(0.85, 0.95, 0.35)
static var _alerted_seed := -1

var st := S.KEEP
var st_t := 1.6
var _dir := Vector2.RIGHT
var _line: Line2D = null


func _ready() -> void:
	drop_table = [{"item_id": "health_small", "chance": 0.25}]
	move_speed = 80.0
	super()
	add_to_group("frasquito")
	st_t = RNG.randf_range(1.2, 2.2)
	if TemploAnubis.has_met_sildenafil() and _alerted_seed != TemploAnubis.run_seed():
		_alerted_seed = TemploAnubis.run_seed()
		say("PT_POPPER_SILDENAFIL", Color("ff6a6a"))


func _physics_process(delta: float) -> void:
	if state == State.DEAD or not _has_target():
		return
	st_t -= delta
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	match st:
		S.KEEP:
			var want := Vector2.ZERO
			if d > KEEP_MAX:
				want = to_t.normalized() * move_speed
			elif d < KEEP_MIN:
				want = -to_t.normalized() * move_speed * 1.3
			else:
				want = to_t.normalized().orthogonal() * move_speed * 0.6
			velocity = velocity.lerp(want, 5.0 * delta)
			_play(&"walk")
			if st_t <= 0.0 and d < 360.0:
				st = S.WINDUP
				st_t = 0.9
				_dir = to_t.normalized()
				_show_line()
				Sound.play("aviso_zona")
				say("PT_POPPER_VAPORS", WARN_COL)
		S.WINDUP:
			velocity = Vector2.ZERO
			_play(&"attack")
			animated_sprite.offset.x = sin(st_t * 60.0) * 1.2
			if st_t <= 0.0:
				animated_sprite.offset.x = 0.0
				_blow()
		S.BLOW:
			velocity = Vector2.ZERO
			_play(&"strike")
			if st_t <= 0.0:
				st = S.REST
				st_t = 1.2
		S.REST:
			velocity = velocity.lerp(Vector2.ZERO, 6.0 * delta)
			_play(&"idle")
			if st_t <= 0.0:
				st = S.KEEP
				st_t = RNG.randf_range(2.2, 3.4)
	_face(to_t.x)
	move_and_slide()


## Linea tenue con la direccion de los vapores (el aviso).
func _show_line() -> void:
	_clear_line()
	_line = Line2D.new()
	_line.width = 26.0
	_line.default_color = Color(WARN_COL.r, WARN_COL.g, WARN_COL.b, 0.2)
	_line.add_point(Vector2(0, -18))
	_line.add_point(Vector2(0, -18) + _dir * 150.0)
	add_child(_line)


func _clear_line() -> void:
	if is_instance_valid(_line):
		_line.queue_free()
	_line = null


func _blow() -> void:
	_clear_line()
	st = S.BLOW
	st_t = 0.5
	Sound.play("suck")
	for i in 3:
		var v := PopperVapor.new()
		v.velocity = _dir.rotated((i - 1) * 0.28) * 105.0
		_spawn_container().add_child(v)
		v.global_position = global_position + Vector2(0, -20) + _dir * 14.0


func die(killer: Node = null) -> void:
	_clear_line()
	super.die(killer)
