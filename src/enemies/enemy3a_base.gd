extends Enemy
class_name Enemy3a

## Base de los enemigos cuerpo a cuerpo de la Etapa 3a: la misma maquina de estados de Enemy
## (persigue -> AVISA -> embiste -> agotado) con tres ganchos nuevos:
##   _on_player_hit(player)   el golpe llego (no lo esquivo): aqui van los estados/efectos.
##   hero                     id del heroe elegido (matices propios por heroe).
##   _start_lunge()           los que "lanzan" algo (correa, red) lo reutilizan como fin del aviso.
## Las personalidades de IA se registran en E3a.ensure().

var hero := "pitocles"
var base_damage := 6.0


func _ready() -> void:
	E3a.ensure()
	hero = E3a.hero()
	_setup()
	super._ready()
	base_damage = damage


## Cada enemigo ajusta aqui sus numeros (antes de que la IA lea la velocidad base).
func _setup() -> void:
	pass


func _on_player_hit(_player: Node) -> void:
	pass


## Igual que Enemy._strike, pero avisa del golpe conectado.
func _strike() -> void:
	if _hit_done:
		return
	for b in hitbox.get_overlapping_bodies():
		if b.has_method("receive_hit") and b.receive_hit(damage):
			_hit_done = true
			_on_player_hit(b)


func _say(key: String, secs := 2.0, arg = null) -> void:
	E3a.say(self, key, secs, arg)


func _player() -> Node2D:
	return E3a.player_of(self)


## Agranda el cuerpo (minijefes): sprite y formas de colision/golpe.
func _grow(k: float) -> void:
	animated_sprite.scale *= k
	for n in ["CollisionShape2D"]:
		var c := get_node_or_null(n)
		if c is Node2D:
			c.scale *= k
	for a in [hurtbox, hitbox]:
		if a != null:
			for c in a.get_children():
				if c is Node2D:
					(c as Node2D).scale *= k
