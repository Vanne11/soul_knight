extends ProjectileEnemy
class_name ProjectileSpark

## Chispa electrica del Dildo Electrico: mismo dano y velocidad que el proyectil
## normal (lo fijan quien dispara); cambia el aspecto: nucleo que parpadea, luz
## electrica sin sombras y una estela de chispitas.

const SPARK_CYAN := Color(0.47, 0.94, 1.0)

var _glow: PointLight2D = null
var _flick := 0.0


func _ready() -> void:
	super._ready()
	var old := get_node_or_null("Glow")  # el brillo verde del proyectil base
	if old:
		old.queue_free()
	_glow = ActorFx.add_glow(self, SPARK_CYAN, 0.8, 0.45)
	_add_trail()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_flick += delta * 40.0
	var k := 0.65 + 0.35 * absf(sin(_flick) * cos(_flick * 0.37))
	if is_instance_valid(_glow):
		_glow.energy = 0.8 * k
	$Sprite.modulate = Color(1, 1, 1).lerp(Color(1.6, 1.6, 1.8), 1.0 - k)
	$Sprite.scale = Vector2.ONE * (1.0 if int(_flick * 0.5) % 2 == 0 else 0.85)


## Estela: chispitas que se quedan en el mundo (no siguen al proyectil) y se apagan.
func _add_trail() -> void:
	var p := CPUParticles2D.new()
	p.amount = 14
	p.lifetime = 0.28
	p.local_coords = false
	p.direction = Vector2.LEFT
	p.spread = 70.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 70.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.95, 0.55, 1), SPARK_CYAN, Color(0.2, 0.5, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	p.color_ramp = g
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	add_child(p)
