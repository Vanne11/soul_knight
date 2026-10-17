extends Enemy3a
class_name EnemyJaula

## Jaula Carcelera (Palacio de la Censura; idea de Vanessa): salta encima y te ENJAULA unos
## segundos: sin disparar ni dash y casi sin poder moverte. Machaca ataque/dash/interactuar
## para salir antes. El aviso es largo y se ve (se agacha y tiembla) para poder esquivarla.
##   Pitocles      es duro: rompe los barrotes mas rapido (jaula mas corta).
##   Ornitorrinco  la ve venir por electrorrecepcion: aviso mas largo.

const CAGE_TIME := 3.5
var cage_time := CAGE_TIME


func _setup() -> void:
	personality = "bondage"
	move_speed = 110.0
	lunge_trigger = 200.0
	windup_time = 0.65
	lunge_time = 0.34
	lunge_speed = 600.0
	recover_time = 1.2
	match hero:
		"pitocles":
			cage_time = 2.7
		"ornitorrinco":
			windup_time = 0.9


func _on_player_hit(p: Node) -> void:
	var st := StatusEffects.of(p)
	if st != null and st.apply("enjaulado", cage_time, self):
		_say("jaula_caught", 2.4)
		E3a.note("e3a_jaula")
		# se queda "encima" un rato, de trofeo
		state = State.RECOVER
		_state_timer = cage_time * 0.7
		velocity = Vector2.ZERO
