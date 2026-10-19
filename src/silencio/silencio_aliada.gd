class_name SilencioAliada
extends Node2D

## VOZ ALIADA de la pelea contra "El Pacto de Silencio" (diseno_E3, 5.7): una silueta con luz propia
## que aparece en el borde cuando cortas una cura (luz 2 del circulo). Lanza un pulso de sonido cada 6 s
## contra el Pacto (dano "sonido"). El manto puede CUBRIRLA (no pulsa mientras esta cubierta); se descubre
## golpeando un objeto de ruido cercano. En el "coro" (luz 3) todas hablan a la vez: pulsos x2 durante 8 s.
## Sin vida, sin dano al heroe, sin que los errores del jugador la apaguen.

const PERIOD := 6.0
const CHORUS_PERIOD := 2.0
const NEAR_NOISE := 220.0   ## un objeto de ruido a esta distancia que suene la descubre

var boss: Node = null
var covered := false
var _t := 2.5               ## el primer pulso sale pronto
var _fig: SilencioFigura
var _light: PointLight2D
var _pulse := 0.0
var _uncover := 0.0         ## segundos que le quedan descubierta tras un anillo


func _ready() -> void:
	add_to_group("sil_aliada")
	z_index = 2
	_fig = SilencioFigura.make("pie_a", Vector2.ZERO, Color(1.25, 1.2, 1.05))
	add_child(_fig)
	_light = LightKit.make_light(Color(1.0, 0.86, 0.55), 0.5, 1.4, false)
	_light.remove_from_group(LightKit.GROUP_DARK)
	_light.position = Vector2(0, -26)
	add_child(_light)
	material = LightKit.unshaded_material()


## Un anillo de ruido cerca la descubre del manto (unos segundos).
func note_ring(ring_pos: Vector2) -> void:
	if global_position.distance_to(ring_pos) <= NEAR_NOISE:
		_uncover = 4.0


func _physics_process(delta: float) -> void:
	_pulse = maxf(0.0, _pulse - delta)
	_uncover = maxf(0.0, _uncover - delta)
	var in_cover := boss != null and boss.has_method("is_covered") and bool(boss.is_covered(global_position))
	covered = in_cover and _uncover <= 0.0
	_fig.modulate = Color(0.45, 0.45, 0.5) if covered else Color(1.25, 1.2, 1.05)
	_light.enabled = not covered
	if covered or boss == null or not is_instance_valid(boss):
		queue_redraw()
		return
	_t -= delta
	if _t <= 0.0:
		var chorus: bool = bool(boss.get("chorus_on"))
		_t = CHORUS_PERIOD if chorus else PERIOD
		_pulse = 0.6
		boss.ally_pulse(self, 2.0 if chorus else 1.0)
	queue_redraw()


func _draw() -> void:
	if _pulse > 0.0:
		var k := 1.0 - _pulse / 0.6
		draw_arc(Vector2(0, -26), 20.0 + 70.0 * k, 0.0, TAU, 36, Color(1.0, 0.9, 0.6, 0.7 * (1.0 - k)), 2.0)
	if not covered:
		draw_circle(Vector2(0, -26), 5.0, Color(1.0, 0.9, 0.6, 0.55))
