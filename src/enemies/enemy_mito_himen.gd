extends EnemyMito
class_name EnemyMitoHimen

## Mito: "el himen demuestra la virginidad" (Himen-Certificador). Va con un sello y un escudo
## de "membrana" que se rompe con CUALQUIER golpe (como en la vida real: con un golpe de
## nada, un deporte o sin motivo, y no prueba nada). Al romperse queda indefenso y avergonzado:
## "eso no prueba NADA". La verdad (a validar por Vanessa): el himen no es un sello ni un
## certificado, y su aspecto varia mucho; no sirve para saber nada sobre nadie.

var membrane := true
var _ring_t := 0.0
var _ov: E3aOverlay = null


func _ready() -> void:
	super._ready()
	_ov = E3aOverlay.new()
	_ov.draw_cb = _draw_membrane
	add_child(_ov)


func _setup_mito() -> void:
	lore_id = "ene_mito_himen"
	truth_key = "mito_himen_truth"
	move_speed = 105.0
	lunge_trigger = 95.0
	windup_time = 0.55
	lunge_time = 0.24
	lunge_speed = 500.0
	recover_time = 0.9


func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if state == State.DEAD:
		return 0.0
	if membrane:
		# el primer golpe, sea cual sea, rompe la membrana y no hace dano a la vida
		membrane = false
		_ov.queue_redraw()
		HitFx.flash(animated_sprite)
		_say("himen_pop", 2.4)
		E3a.floating(global_position + Vector2(0, -40), Loc.tr_or("E3A_FX_POP", "*pop*"), Color("bfe4ff"))
		E3a.icon(self, "sweat", 1.2)
		return 0.0
	return super.take_damage(amount, source, kb)


func _physics_process(delta: float) -> void:
	_ring_t += delta
	if membrane and _ov != null:
		_ov.queue_redraw()
	super._physics_process(delta)


func _draw_membrane(c: Node2D) -> void:
	if not membrane or state == State.DEAD:
		return
	# burbuja translucida alrededor: el "certificado de pureza" que no vale nada
	var r := 27.0 + sin(_ring_t * 4.0) * 1.2
	c.draw_circle(Vector2(0, -8), r, Color(0.75, 0.9, 1.0, 0.16))
	c.draw_arc(Vector2(0, -8), r, 0.0, TAU, 28, Color(0.8, 0.95, 1.0, 0.85), 1.6)
	c.draw_arc(Vector2(0, -8), r - 4.0, PI * 1.1, PI * 1.5, 8, Color(1, 1, 1, 0.8), 1.4)
