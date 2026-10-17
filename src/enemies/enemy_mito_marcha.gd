extends EnemyMito
class_name EnemyMitoMarcha

## Mito: "la marcha atras es un metodo anticonceptivo seguro". Embiste y, ANTES de acabar,
## da marcha atras... dejando atras un par de espermatozoides ("sorpresa"). Con uso tipico
## el coitus interruptus falla ~1 de cada 5 al ano (dato a validar por Vanessa).

const BACK_TIME := 0.55
const BACK_SPEED := 300.0
const MAX_MINIS := 4
const MINI_FRAMES := "res://assets/sprites/enemies/espermatozoide_sprite_frames.tres"
var _retreat_t := 0.0


func _setup_mito() -> void:
	lore_id = "ene_mito_marcha"
	truth_key = "mito_marcha_truth"
	move_speed = 150.0
	lunge_trigger = 130.0
	windup_time = 0.45
	lunge_time = 0.22
	lunge_speed = 540.0
	recover_time = 0.8


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if _retreat_t > 0.0:
		_retreat_t -= delta
		if state == State.RECOVER:
			velocity = -_lunge_dir * BACK_SPEED
	var before := state
	super._physics_process(delta)
	if before == State.LUNGE and state == State.RECOVER:
		_back_off()


func _back_off() -> void:
	_retreat_t = BACK_TIME
	_say("marcha_back", 1.6)
	var room_minis := E3a.alive_in_group(get_tree(), "mito_mini")
	for i in mini(2, MAX_MINIS - room_minis):
		var m := E3a.spawn(self, "swarmer", global_position + Vector2(RNG.randf_range(-18, 18), RNG.randf_range(-14, 14)),
			6.0, maxf(base_damage * 0.4, 2.0), MINI_FRAMES, 0.8)
		m.add_to_group("mito_mini")
	E3a.note("e3a_marcha")
