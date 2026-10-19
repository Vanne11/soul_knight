class_name SilencioRuido
extends StaticBody2D

## OBJETO DE RUIDO de la arena de "El Pacto de Silencio" (diseno_E3, 5.3): 2 campanas colgantes, 2 ollas
## sobre un tendedero y 1 vidrio grande, en el borde. Se activan GOLPEANDOLOS (con un tiro, un ataque o el
## grito/escudo/pico del heroe): emiten un anillo de luz blanca de `ring_r` px (120 de base, 160 con la luz
## 1 del circulo) durante 2 s y se rearman a los 6 s. No se rompen ni sueltan botin. Mientras suena, los
## golpes que le das al Pacto desde dentro del anillo cuentan como "sonido" (ver boss_pacto_silencio.gd).
##
## Esta en el grupo "enemy" (como BossBreakable) para que las balas y las habilidades del heroe lo traten
## como algo que se puede golpear; no cuenta para limpiar la sala ni hace dano.

signal rung(obj: SilencioRuido)

const GROUP := "sil_ruido"
const RING_SECS := 2.0
const REARM_SECS := 6.0
const DIR := "res://assets/sprites/silencio/"

var kind := "campana"       ## "campana", "olla" o "vidrio"
var ring_r := 120.0
var loud := false           ## true en "Nadie dijo": el anillo brilla mas (el juego esta en silencio)
var current_health := 1.0   ## solo para que las habilidades del heroe lo vean como algo golpeable
var max_health := 1.0
var ringing := 0.0
var rearm := 0.0

var _sprite := Sprite2D.new()
var _light: PointLight2D
var _flash := 0.0
var _t := 0.0
var _mat := LightKit.unshaded_material()


func _ready() -> void:
	add_to_group("enemy")
	add_to_group(GROUP)
	collision_layer = 0
	set_collision_layer_value(2, true)
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 26.0 if kind != "vidrio" else 30.0
	cs.shape = sh
	cs.position = Vector2(0, -22)
	add_child(cs)
	var tex: Texture2D = load(DIR + kind + ".png")
	_sprite.texture = tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -tex.get_height() * 0.5)
	add_child(_sprite)
	z_index = 1
	material = _mat  # el anillo y los puntos se dibujan sin luces: se leen siempre
	_sprite.material = null
	_light =LightKit.make_light(Color(1.0, 0.97, 0.9), 0.85, 2.2, false)
	_light.remove_from_group(LightKit.GROUP_DARK)  # propia: no se apaga con la penumbra de la sala
	_light.position = Vector2(0, -22)
	_light.enabled = false
	add_child(_light)


## Se puede golpear ahora (no esta sonando ni rearmandose).
func armed() -> bool:
	return ringing <= 0.0 and rearm <= 0.0


func take_damage(_amount: float, _source: Node = null, _kb: Vector2 = Vector2.ZERO) -> float:
	_flash = 0.12
	if armed():
		strike()
	return 0.0


## El grito de Vulvalquiria (HeroAbility.scare) lo hace sonar.
func scare(_seconds: float, _from: Vector2) -> void:
	take_damage(0.0)


func die(_killer: Node = null) -> void:
	pass  # no se rompe


func strike() -> void:
	ringing = RING_SECS
	rearm = REARM_SECS
	_light.enabled = true
	Sound.play("enemy_hit")
	rung.emit(self)


## true si el punto (global) esta dentro del anillo ahora.
func covers(p: Vector2) -> bool:
	return ringing > 0.0 and p.distance_to(global_position + Vector2(0, -22)) <= ring_r


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	if ringing > 0.0:
		ringing = maxf(0.0, ringing - delta)
		if ringing <= 0.0:
			_light.enabled = false
	if rearm > 0.0:
		rearm = maxf(0.0, rearm - delta)
	_sprite.modulate = Color(1.6, 1.6, 1.6) if _flash > 0.0 or ringing > 0.0 else (Color.WHITE if armed() else Color(0.75, 0.75, 0.8))
	if ringing > 0.0:
		_sprite.position.x = sin(_t * 70.0) * 1.5 * (ringing / RING_SECS)  # un temblor corto
	else:
		_sprite.position.x = 0.0
	queue_redraw()


func _draw() -> void:
	var c := Vector2(0, -22)
	if ringing > 0.0:
		var k := 1.0 - ringing / RING_SECS
		var r := ring_r * clampf(k * 6.0, 0.0, 1.0)  # el anillo se abre rapido y se queda
		var a := clampf(ringing / (RING_SECS * 0.5), 0.0, 1.0)
		var w := Color(1, 1, 1, (0.9 if loud else 0.7) * a)
		draw_circle(c, r, Color(1, 1, 1, 0.07 * a))
		draw_arc(c, r, 0.0, TAU, 48, w, 3.0 if loud else 2.0)
	elif rearm > 0.0:
		# rearmandose: un arco fino que se completa
		var f := 1.0 - rearm / REARM_SECS
		draw_arc(c + Vector2(0, -30), 7.0, -PI * 0.5, -PI * 0.5 + TAU * f, 16, Color(0.8, 0.8, 0.86, 0.55), 1.5)
	else:
		# armado: un punto claro sobre el objeto (se lee tambien en la penumbra)
		var p := 0.55 + 0.35 * sin(_t * 4.0)
		draw_circle(c + Vector2(0, -32), 3.0, Color(1, 1, 1, p))
