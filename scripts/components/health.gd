class_name Health
extends Node
## Componente de vida, armadura e invulnerabilidad.
##
## Se cuelga como nodo hijo de cualquier actor (jugador o enemigo). El resto
## del juego solo necesita saber una cosa: "si este cuerpo tiene un hijo
## llamado Health, se le puede hacer dano". Eso es COMPOSICION: en vez de una
## jerarquia de herencia gigante (Entidad -> SerVivo -> Enemigo -> ...),
## se ensamblan capacidades como piezas de lego.
##
## La armadura imita la de Soul Knight: absorbe el dano antes que la vida y se
## regenera sola tras unos segundos sin recibir golpes. Es lo que permite que
## el juego sea exigente sin ser injusto.

signal changed                                        ## Vida/armadura cambiaron.
signal damaged(amount: int, from_position: Vector2)    ## Golpe recibido.
signal died                                            ## La vida llego a 0.

@export var max_hp: int = 5

@export_group("Armadura")
@export var max_armor: int = 0
## Segundos sin recibir dano antes de que la armadura empiece a regenerarse.
@export var armor_regen_delay: float = 4.0
## Puntos de armadura por segundo una vez empieza la regeneracion.
@export var armor_regen_rate: float = 1.2

@export_group("Invulnerabilidad")
## Segundos de gracia tras un golpe (evita perder toda la vida de una pasada).
@export var invuln_time: float = 0.45

var hp: int
var armor: float          ## Float para que la regeneracion sea suave.
var is_dead: bool = false

var _since_damage: float = 999.0
var _invuln_left: float = 0.0


func _ready() -> void:
	hp = max_hp
	armor = float(max_armor)


func _process(delta: float) -> void:
	_invuln_left = maxf(_invuln_left - delta, 0.0)
	if is_dead or max_armor <= 0:
		return

	_since_damage += delta
	if _since_damage >= armor_regen_delay and armor < float(max_armor):
		armor = minf(armor + armor_regen_rate * delta, float(max_armor))
		changed.emit()


## Aplica dano. Devuelve true si el golpe conto (false si era invulnerable).
func take_damage(amount: int, from_position: Vector2 = Vector2.ZERO) -> bool:
	if is_dead or amount <= 0 or _invuln_left > 0.0:
		return false

	_invuln_left = invuln_time
	_since_damage = 0.0

	# La armadura absorbe primero, en puntos enteros.
	var left := amount
	var usable := floori(armor)
	if usable > 0:
		var absorbed := mini(usable, left)
		armor -= float(absorbed)
		left -= absorbed
	if left > 0:
		hp = maxi(hp - left, 0)

	damaged.emit(amount, from_position)
	changed.emit()

	if hp <= 0:
		is_dead = true
		died.emit()
	return true


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	changed.emit()


## Concede invulnerabilidad temporal (la esquiva del jugador la usa).
func grant_invulnerability(seconds: float) -> void:
	_invuln_left = maxf(_invuln_left, seconds)


func is_invulnerable() -> bool:
	return _invuln_left > 0.0
