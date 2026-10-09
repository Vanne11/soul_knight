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


func refresh_prompt() -> void:
	if _player:
		Narrator.prompt(self, _prompt_text())


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
	set_deferred("monitoring", false)


func _exit_tree() -> void:
	Narrator.clear_prompt(self)
