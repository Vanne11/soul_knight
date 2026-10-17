extends EnemyMito
class_name EnemyMitoMano

## Mito: "te van a salir pelos en la mano" (Mano Peluda). Una mano que trepa y salta desde
## lejos; con cada golpe que recibe le brota MAS pelo (puro teatro: ya no pica mas fuerte, no
## cambia nada: justo como el mito). La verdad (a validar por Vanessa): masturbarse no causa
## pelos en las palmas, ceguera ni nada parecido; es una practica comun y sana.

const MAX_HAIR := 5
var hair := 0
var _hair_t := 0.0
var _ov: E3aOverlay = null


func _ready() -> void:
	super._ready()
	_ov = E3aOverlay.new()
	_ov.draw_cb = _draw_hair
	add_child(_ov)


func _setup_mito() -> void:
	lore_id = "ene_mito_mano"
	truth_key = "mito_mano_truth"
	move_speed = 150.0
	lunge_trigger = 230.0
	windup_time = 0.5
	lunge_time = 0.3
	lunge_speed = 640.0
	recover_time = 0.9


func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	var dealt := super.take_damage(amount, source, kb)
	if state != State.DEAD and hair < MAX_HAIR:
		hair += 1
		_ov.queue_redraw()
		if hair == 3:
			_say("mano_hair", 2.0)
	return dealt


func _physics_process(delta: float) -> void:
	_hair_t += delta
	if hair > 0 and _ov != null:
		_ov.queue_redraw()
	super._physics_process(delta)


func _draw_hair(c: Node2D) -> void:
	if hair <= 0 or state == State.DEAD:
		return
	# mechones que brotan de la palma (se menean un poco)
	var flip := -1.0 if animated_sprite.flip_h else 1.0
	for i in hair:
		var bx := (-10.0 + i * 5.0) * flip
		var sway := sin(_hair_t * 5.0 + i) * 1.5
		var top := Vector2(bx + sway, -34.0 - (i % 2) * 3.0)
		c.draw_line(Vector2(bx, -26.0), top, Color(0.05, 0.03, 0.04), 3.0)
		c.draw_line(Vector2(bx, -26.0), top, Color(0.32, 0.2, 0.12), 1.6)
