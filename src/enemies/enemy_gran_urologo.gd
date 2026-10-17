extends EnemyDedo
class_name EnemyGranUrologo

## El Gran Urologo (minijefe): una mano entera de dedos. Misma regla que el Dedo (solo te hace
## dano por la espalda) pero grande, aguantador y con DEDOS que le obedecen: al bajar de 66% y
## de 33% de vida suelta dos Dedos para que te rodeen entre todos. Con tres frentes abiertos
## hay que girar de verdad.

const SIZE := 1.9
const HEALTH_MULT := 4.0
const DAMAGE_MULT := 1.25
const SUMMON_AT := [0.66, 0.33]
const MAX_FINGERS := 3
var _summons_done := 0


func _setup() -> void:
	super._setup()
	personality = "gigante3a"
	max_health *= HEALTH_MULT
	damage *= DAMAGE_MULT
	move_speed = 110.0
	windup_time = 0.6
	recover_time = 0.9


func _ready() -> void:
	super._ready()
	_grow(SIZE)
	E3a.say(self, "gran_urologo_intro", 2.8)


func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	var dealt := super.take_damage(amount, source, kb)
	if state != State.DEAD and _summons_done < SUMMON_AT.size() \
			and current_health / maxf(max_health, 1.0) <= SUMMON_AT[_summons_done]:
		_summons_done += 1
		_summon_fingers()
	return dealt


func _summon_fingers() -> void:
	E3a.say(self, "gran_urologo_summon", 2.4)
	var n := mini(2, MAX_FINGERS - E3a.alive_in_group(get_tree(), "dedo_invocado"))
	for i in n:
		var ang := RNG.randf_range(0.0, TAU)
		var f := E3a.spawn(self, "dedo", global_position + Vector2.from_angle(ang) * 70.0,
			maxf(max_health * 0.06, 15.0), base_damage * 0.9)
		f.add_to_group("dedo_invocado")
