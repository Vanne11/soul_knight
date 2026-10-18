extends Enemy3a
class_name EnemyGranCandado

## El Gran Candado (minijefe; idea de Vanessa): guardian de una sala secreta. Cerrado es casi
## inmune (el golpe rebota: clank). Solo se abre, y se deja pegar, cuando acaba de embestir y
## esta agotado: esa es tu ventana. Al bajar de 50% suelta dos Jaulas Carcelera.
## Su embestida te enjaula como la jaula comun. Gancho en main: ver informe (sala secreta).

const SIZE := 1.9
const HEALTH_MULT := 6.0
const DAMAGE_MULT := 1.2
const CLOSED_MULT := 0.1
const CAGE_TIME := 3.0
var open := false
var _summoned := false
var _clank_cd := 0.0


func _setup() -> void:
	personality = "gigante3a"
	max_health *= HEALTH_MULT
	damage *= DAMAGE_MULT
	move_speed = 95.0
	lunge_trigger = 190.0
	windup_time = 0.75
	lunge_time = 0.3
	lunge_speed = 560.0
	recover_time = 2.0
	attack_cooldown = 0.8


func _ready() -> void:
	super._ready()
	_grow(SIZE)
	E3a.say(self, "candado_intro", 2.6)


func _physics_process(delta: float) -> void:
	_clank_cd = maxf(0.0, _clank_cd - delta)
	var was_open := open
	open = state == State.RECOVER or state == State.STUNNED
	if open != was_open and state != State.DEAD:
		animated_sprite.modulate = Color(1.6, 1.4, 0.6) if open else Color.WHITE
		if open:
			E3a.say(self, "candado_open", 1.6)
	super._physics_process(delta)


func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if state == State.DEAD:
		return 0.0
	if not open:
		if _clank_cd <= 0.0:
			_clank_cd = 0.6
			E3a.floating(global_position + Vector2(0, -50), "CLANK", Color("c8c8d8"))
			Sound.play("locked", 0.1)
		amount *= CLOSED_MULT
	kb = Vector2.ZERO  # pesa demasiado: no lo empujas ni se rompe su ventana de agotado
	var dealt := super.take_damage(amount, source, kb)
	if not _summoned and state != State.DEAD and current_health / maxf(max_health, 1.0) <= 0.5:
		_summoned = true
		E3a.say(self, "candado_summon", 2.4)
		for i in 2:
			var a := Vector2.from_angle(PI * (0.5 + i)) * 90.0
			var at := global_position + a
			var room := find_owning_room()
			if room != null:
				at = room.clamp_global(at)  # junto a un muro la escolta nacia dentro de el
			var j := E3a.spawn(self, "jaula", at, maxf(max_health * 0.05, 20.0), base_damage * 0.8)
			j.enemy_name = "Jaula"
	return dealt


func _on_player_hit(p: Node) -> void:
	var st := StatusEffects.of(p)
	if st != null:
		st.apply("enjaulado", CAGE_TIME, self)
		E3a.note("e3a_jaula")
