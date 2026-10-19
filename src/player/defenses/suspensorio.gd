extends Defense
class_name DefSuspensorio

## SUSPENSORIO BLINDADO (defensa). Pasivo: reduce el dano CUERPO A CUERPO que te llega de FRENTE
## (enemigo cerca y delante del apuntado) a PASSIVE_MULT. MANTENER "guard": te agachas tras el casco y el
## golpe frontal baja a BRACE_MULT; caminas lento y no disparas. No hace nada contra proyectiles
## (para eso estan el diafragma o el condon) ni contra golpes por la espalda.

const PASSIVE_MULT := 0.6
const BRACE_MULT := 0.2
const WALK_MULT := 0.7
const MELEE_RANGE := 95.0
const FRONT_DOT := 0.1

var reduced := 0.0
var _proj := false
var _flash := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("8fa8d0")


func is_passive() -> bool:
	return false


func speed_mult() -> float:
	return WALK_MULT if guarding else 1.0


func can_attack() -> bool:
	return not guarding


func _physics_process(_d: float) -> void:
	if player == null:
		return
	guarding = guard_held()


## Solo marca si lo que entra es un proyectil (no lo bloquea).
func try_guard(area: Area2D, _dmg: float) -> bool:
	_proj = is_projectile(area)
	return false


func filter_hit(dmg: float) -> float:
	var was_proj := _proj
	_proj = false
	if was_proj or dmg <= 0.0:
		return dmg
	var e := nearest_enemy(MELEE_RANGE, FRONT_DOT)
	if e == null:
		return dmg
	var out := dmg * (BRACE_MULT if guarding else PASSIVE_MULT)
	reduced += dmg - out
	_flash = 0.25
	text("DEF_JOCK_BLOCK", Color("a8c0e8"))
	Sound.play("crack", 0.1)
	return out


func _draw_tick() -> void:
	_flash = maxf(0.0, _flash - get_process_delta_time())
	if _flash > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if not guarding and _flash <= 0.0:
		return
	var a: float = player._aim.angle()
	var col := Color("dbe6ff") if _flash > 0.0 else Color("8fa8d0")
	draw_arc(Vector2.ZERO, 18.0, a - 0.7, a + 0.7, 12, Color(0, 0, 0, 0.8), 6.0)
	draw_arc(Vector2.ZERO, 18.0, a - 0.7, a + 0.7, 12, col, 4.0)
