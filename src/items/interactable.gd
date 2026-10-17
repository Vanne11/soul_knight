extends Area2D

## Algo que se usa con E (interactuar): al acercarte sale su cuadro, con el estilo
## del narrador, y E lo activa. Si hay varios cerca, responde el ultimo al que
## te acercaste. Los hijos cambian _prompt_text() y _use(); o, sin heredar, se
## rellena prompt_text y se escucha used.

signal used(player: Node)

var prompt_text := ""
var _player: Node = null


func _ready() -> void:
	if get_child_count() == 0 or not get_children().any(func(c): return c is CollisionShape2D):
		var shape := CollisionShape2D.new()
		shape.shape = CircleShape2D.new()
		shape.shape.radius = 30.0
		add_child(shape)
		collision_layer = 0
		collision_mask = 1  # el jugador
	add_to_group("interactable")
	# si el jugador cambia de teclado a mando con el cuadro abierto, que cambie el glifo
	InputGlyphs.watcher().device_changed.connect(func(_p): if _player and Narrator.prompt_owner == self: refresh_prompt())
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node) -> void:
	if body.is_in_group("player"):
		_player = body
		refresh_prompt()


func _on_exit(body: Node) -> void:
	if body == _player:
		_player = null
		Narrator.clear_prompt(self)
		_handoff()


## Si queda otro interactuable con el jugador encima, que vuelva a mostrar su cuadro:
## antes, al recoger un objeto pegado a otro, el segundo no respondia a E hasta salir
## y volver a entrar.
func _handoff() -> void:
	if Narrator.prompt_owner != null:
		return
	for n in get_tree().get_nodes_in_group("interactable"):
		if n != self and is_instance_valid(n) and n.get("_player") != null and n.is_processing():
			n.refresh_prompt()
			return


func refresh_prompt() -> void:
	if _player:
		Narrator.prompt(self, InputGlyphs.localize(_prompt_text()))


func _prompt_text() -> String:
	return prompt_text


func _process(_delta: float) -> void:
	if _player and Narrator.prompt_owner == self and Input.is_action_just_pressed("interact"):
		_use(_player)


func _use(player: Node) -> void:
	used.emit(player)


## Ya no se puede usar (recogido, vendido, bebido...).
func finish() -> void:
	Narrator.clear_prompt(self)
	_player = null
	set_process(false)
	_handoff()
	set_deferred("monitoring", false)


func _exit_tree() -> void:
	Narrator.clear_prompt(self)
