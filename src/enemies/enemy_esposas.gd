extends Enemy3a
class_name EnemyEsposas

## Esposas peludas (bondage; idea de Vanessa): si te alcanzan te ESPOSAN a ellas (cadena corta,
## no puedes disparar) hasta que las mates... o las aturdas con embestida/espolon, machaques
## ataque/dash/interactuar para soltarte, o pasen 5 s. Dura poco a proposito: es una molestia
## con ganas, no una trampa mortal. Mientras estas esposado te arrastra la cadena.

const CUFF_TIME := 5.0


func _setup() -> void:
	personality = "bondage"
	move_speed = 125.0
	lunge_trigger = 125.0
	windup_time = 0.5
	lunge_time = 0.24
	lunge_speed = 520.0
	recover_time = 0.7


func _on_player_hit(p: Node) -> void:
	var st := StatusEffects.of(p)
	if st != null and st.apply("esposado", CUFF_TIME, self):
		_say("esposas_caught", 2.4)
		E3a.note("e3a_esposas")
