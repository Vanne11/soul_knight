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
	var old := state
	state = new_state
	_update_visuals()
	if old != new_state and (new_state == State.OPEN or new_state == State.SEALED):
		_animate_change(new_state == State.SEALED)
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
			get_node("/root/GlobalEvents").show_floating_text.emit(global_position, tr("DOOR_INTOX_OPENS"), Color.MAGENTA)
			return true
		else:
			get_node("/root/GlobalEvents").show_floating_text.emit(global_position, tr("DOOR_LOCKED") % _get_requirement_text(), Color.RED)
			Sound.play("locked")
			if required_key == "" and required_intoxication_tier == 0:
				Narrator.say_first("door_secret")
			return false
	
	if state == State.SEALED:
		get_node("/root/GlobalEvents").show_floating_text.emit(global_position, tr("DOOR_SEALED"), Color.RED)
		return false
	
	if state == State.CLOSED:
		set_state(State.OPEN)
		return true
	
	return false

## Solo presentacion (roadmap 58): la puerta se estira/golpea al abrirse o sellarse, con
## un destello y polvo. Solo si la sala es la actual (al generar el piso no se anima).
var _anim_tween: Tween
func _animate_change(sealing: bool) -> void:
	var main := get_tree().get_first_node_in_group("main") if is_inside_tree() else null
	if main == null or main.current_room == null or main.current_room != room:
		return
	var out: Vector2 = _dir_vectors[direction]
	# a lo largo del eje de la puerta: sellar la aplasta contra el marco, abrir la estira y la relaja
	var along := Vector2(1.0, 0.0) if out.y != 0.0 else Vector2(0.0, 1.0)
	var start := Vector2.ONE + along * (0.14 if sealing else -0.12)
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	sprite.scale = start
	sprite.modulate = Color(1.9, 1.9, 1.9) if not sealing else Color(1.5, 1.2, 1.2)
	_anim_tween = create_tween().set_parallel(true)
	_anim_tween.tween_property(sprite, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)
	_spawn_dust(out, sealing)

func _spawn_dust(out: Vector2, sealing: bool) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 14 if sealing else 9
	p.lifetime = 0.5
	p.explosiveness = 0.9
	p.direction = -out  # hacia dentro de la sala
	p.spread = 70.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 60.0
	p.damping_min = 40.0
	p.damping_max = 70.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.78, 0.72, 0.66, 0.55)
	p.position = out * 30.0
	p.z_index = 4
	p.material = LightKit.unshaded_material()
	add_child(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)

## Cartel sobre la puerta con lo que hay detras ("" lo quita). Va hacia dentro
## de la sala para que no lo corte la camara.
var _hint: Label
func set_hint(text: String, color := Color("f2ead6")) -> void:
	if _hint == null:
		_hint = Label.new()
		_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hint.size = Vector2(160, 40)
		_hint.add_theme_font_size_override("font_size", 11)
		_hint.add_theme_color_override("font_outline_color", Color("0d0b0f"))
		_hint.add_theme_constant_override("outline_size", 5)
		_hint.z_index = 5
		_hint.material = LightKit.unshaded_material()  # legible tambien en sala en penumbra
		_hint.position = _dir_vectors[direction] * -52.0 - _hint.size / 2
		add_child(_hint)
	_hint.text = text
	_hint.add_theme_color_override("font_color", color)
	_hint.visible = text != ""

func _get_requirement_text() -> String:
	if required_key != "":
		return tr("DOOR_REQ_KEY") % required_key
	if required_intoxication_tier > 0:
		return tr("DOOR_REQ_INTOX") % tr("INTOX_TIER_%d" % required_intoxication_tier).capitalize()
	return tr("DOOR_REQ_PUZZLE")

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if try_open(body):
			player_interacted.emit()