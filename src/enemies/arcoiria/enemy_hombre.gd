extends EnemyPrejuicio
class_name EnemyHombre

## "¿Y QUIEN ES EL HOMBRE?": la pregunta que cree que todo se divide en dos. Entero (¿?) persigue y
## embiste normal. Al bajar al 60% de vida se PARTE EN DOS MITADES (¿ azul y ? rosa), cada una con la
## mitad de su vida, que dejan de ir por ti y SE BUSCAN entre si. Si se juntan, se FUSIONAN de nuevo
## y se CURAN: hay que separarlas a tiros y rematarlas antes. Rozarte les duele menos que
## reencontrarse (tocan, pero no persiguen). Si una cae, la otra se queda sola y furiosa (te
## persigue). Cada pareja puede fusionarse como mucho MAX_MERGES veces.
## Verdad: una pareja no es copia de un guion; nadie tiene que "ser el hombre".

const SPLIT_AT := 0.6
const MAX_MERGES := 2
const MERGE_DIST := 26.0
const MERGE_HEAL := 0.25         ## de la vida maxima del entero
const SEEK_MULT := 1.35
const TOUCH_CD := 0.9
const TOUCH_MULT := 0.7
const FRAMES_L := "res://assets/sprites/enemies/hombre_l_sprite_frames.tres"
const FRAMES_R := "res://assets/sprites/enemies/hombre_r_sprite_frames.tres"
const FRAMES_WHOLE := "res://assets/sprites/enemies/hombre_sprite_frames.tres"

var half := ""                   ## "" = entero, "l" o "r" = mitad suelta
var partner: EnemyHombre = null
var full_max := 0.0              ## vida maxima del entero (la comparten las dos mitades)
var merges_left := MAX_MERGES
var _touch_t := 0.0
var _merging := false


func _setup_prejuicio() -> void:
	prej_id = "quien_es_el_hombre"
	move_speed = 118.0
	lunge_trigger = 105.0
	windup_time = 0.5
	lunge_time = 0.22
	lunge_speed = 480.0
	recover_time = 0.7


func _ready() -> void:
	super()
	if full_max <= 0.0:
		full_max = max_health
	_touch_t = RNG.randf_range(0.0, 0.4)


func _physics_process(delta: float) -> void:
	if state == State.DEAD or _merging:
		return
	if half != "" and partner != null and is_instance_valid(partner) and partner.state != State.DEAD:
		_seek_partner(delta)
		return
	super(delta)


# ------------------------------------------------------------------ partirse
func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	var dealt := super(amount, source, kb)
	if half == "" and state != State.DEAD and merges_left > 0 and current_health > 0.0 \
			and current_health <= max_health * SPLIT_AT:
		_split()
	return dealt


func _split() -> void:
	var room := find_owning_room()
	if room == null:
		return
	var hp := current_health * 0.5
	full_max = max_health
	# esta se queda como mitad izquierda; la derecha nace pegada a ella
	var scn := EnemyRegistry.scene("hombre")
	var other := scn.instantiate() as EnemyHombre
	other.half = "r"
	other.max_health = hp
	other.damage = damage
	other.full_max = full_max
	other.merges_left = merges_left
	other.enemy_name = enemy_name
	other.get_node("AnimatedSprite2D").sprite_frames = load(FRAMES_R)
	_spawn_container().add_child(other)
	other.global_position = room.clamp_global(global_position + Vector2(34.0, 0.0), 18.0)
	room.enemies_spawned.append(other)
	other.max_health = hp  # _ready aplico el multiplicador de Censura: la mitad lleva justo la mitad
	other.current_health = hp
	half = "l"
	max_health = hp
	current_health = hp
	animated_sprite.sprite_frames = load(FRAMES_L)
	animated_sprite.play("idle")
	other.partner = self
	partner = other
	state = State.CHASE
	_state_timer = 0.0
	Arcoiria.ring(global_position, Color("c8a0fa"), 70.0, 0.4)
	Arcoiria.say(self, "hombre_parte", 2.0)
	HitFx.shake(0.25)


# ------------------------------------------------------------------ buscarse y fusionarse
func _seek_partner(delta: float) -> void:
	_touch_t -= delta
	var to: Vector2 = partner.global_position - global_position
	velocity = to.normalized() * move_speed * SEEK_MULT
	if absf(to.x) > 1.0:
		animated_sprite.flip_h = to.x < 0.0
	var anim := "walk" if velocity.length() > 10.0 else "idle"
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)
	move_and_slide()
	# rozar al jugador duele (poco): no las persigue pero tampoco se las puede ignorar
	if _touch_t <= 0.0:
		for b in hitbox.get_overlapping_bodies():
			if b.has_method("receive_hit") and b.receive_hit(damage * TOUCH_MULT):
				_touch_t = TOUCH_CD
				break
	if half == "l" and merges_left > 0 and to.length() <= MERGE_DIST:
		_merge()


func _merge() -> void:
	if _merging or partner == null or not is_instance_valid(partner):
		return
	_merging = true
	var other := partner
	other._merging = true
	var hp := minf(full_max, current_health + other.current_health + full_max * MERGE_HEAL)
	half = ""
	partner = null
	max_health = full_max
	current_health = hp
	merges_left -= 1
	animated_sprite.sprite_frames = load(FRAMES_WHOLE)
	animated_sprite.play("idle")
	other._vencido = true  # se funde: no es una muerte, no cuenta como prejuicio vencido
	var room := find_owning_room()
	if room != null:
		room.enemies_spawned.erase(other)
	other.queue_free()
	_merging = false
	state = State.CHASE
	Arcoiria.ring(global_position, Color("fff1c4"), 80.0, 0.5)
	Arcoiria.say(self, "hombre_junta", 2.0)
	HitFx.flash(animated_sprite, 0.12)
