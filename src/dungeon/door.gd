extends Area2D
class_name Door

## Door between rooms with state machine

enum Direction { UP = 0, DOWN = 1, LEFT = 2, RIGHT = 3 }
enum State { CLOSED = 0, OPEN = 1, LOCKED = 2, SEALED = 3 }

@export var direction: Direction = 0
@export var required_intoxication_tier: int = 0
@export var required_key: String = ""

var state: State = State.CLOSED
var room: Room = null
## grid_pos de la sala a la que lleva esta puerta (lo pone el generador).
var target_pos: Vector2i = Vector2i.ZERO

signal state_changed(direction: String, state: int)
signal player_interacted()

var _dir_names = ["up", "down", "left", "right"]
var _dir_vectors = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var lock_icon: Sprite2D = $LockIcon

const _STATE_NAMES = {
	State.CLOSED: "closed",
	State.OPEN: "open",
	State.LOCKED: "locked",
	State.SEALED: "sealed",
}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	set_state(State.CLOSED)

func get_direction_name() -> String:
	return _dir_names[direction]

func set_state(new_state: State) -> void:
	state = new_state
	_update_visuals()
	state_changed.emit(get_direction_name(), int(state))

func _update_visuals() -> void:
	var path := "res://assets/sprites/environment/door_%s_%s.png" % [get_direction_name(), _STATE_NAMES[state]]
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	
	match state:
		State.CLOSED:
			lock_icon.visible = false
		State.OPEN:
			lock_icon.visible = false
		State.LOCKED:
			lock_icon.visible = true
		State.SEALED:
			lock_icon.visible = false
	
	# The shape must stay enabled in EVERY state, including OPEN. Disabling it
	# also switches off body_entered, so walking into an already open door never
	# fired player_interacted and the room could never be changed. An Area2D shape
	# never blocks movement anyway, so keeping it on costs nothing.
	collision.set_deferred("disabled", false)

func try_open(player: Node) -> bool:
	if state == State.OPEN:
		return true
	
	if state == State.LOCKED:
		if required_key != "" and player.has_method("has_item") and player.has_item(required_key):
			set_state(State.OPEN)
			return true
		elif required_intoxication_tier > 0 and get_node("/root/PlayerStats").intoxication_tier >= required_intoxication_tier:
			set_state(State.OPEN)
			get_node("/root/GlobalEvents").show_floating_text.emit(global_position, "La intoxicación abre la cerradura...", Color.MAGENTA)
			return true
		else:
			get_node("/root/GlobalEvents").show_floating_text.emit(global_position, "CERRADO. Requiere: %s" % _get_requirement_text(), Color.RED)
			return false
	
	if state == State.SEALED:
		get_node("/root/GlobalEvents").show_floating_text.emit(global_position, "SELLADO. Limpia la habitación.", Color.RED)
		return false
	
	if state == State.CLOSED:
		set_state(State.OPEN)
		return true
	
	return false

func _get_requirement_text() -> String:
	if required_key != "":
		return "Llave: %s" % required_key
	if required_intoxication_tier > 0:
		var names = ["Sober", "Tipsy", "Drunk", "Blackout"]
		return "Intoxicación: %s" % names[required_intoxication_tier]
	return "Desconocido"

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if try_open(body):
			player_interacted.emit()