class_name ExplosionFx
extends Node2D

## Explosion en area del Lanzapreservativos: onda que se expande hasta el radio REAL del
## dano (asi se ve a quien alcanza), borde punteado que se desvanece, chispas y luz.
## Solo presentacion: el dano lo aplica PlayerBullet._explode().

var radius := 70.0
const LIFE := 0.5
var _t := 0.0

func _ready() -> void:
	z_index = 5
	var p := CPUParticles2D.new()
	p.amount = 26
	p.lifetime = 0.45
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = true
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = radius * 0.5
	p.initial_velocity_max = radius * 1.5
	p.damping_min = radius
	p.damping_max = radius * 2.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 0.9, 1), Color(1.0, 0.55, 0.8, 0.9), Color(0.9, 0.3, 0.6, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	p.color_ramp = g
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	add_child(p)
	var l := ActorFx.add_glow(self, Color(1.0, 0.55, 0.8), 1.4, radius / 40.0)
	var tw := create_tween()
	tw.tween_property(l, "energy", 0.0, 0.35)

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / LIFE, 0.0, 1.0)
	var out := 1.0 - pow(1.0 - clampf(_t / 0.18, 0.0, 1.0), 2.0)  # la onda sale rapido
	var fade := 1.0 - k
	# disco y onda
	draw_circle(Vector2.ZERO, radius * out, Color(1.0, 0.5, 0.78, 0.28 * fade))
	draw_circle(Vector2.ZERO, radius * 0.45 * (1.0 - k * 0.6), Color(1.0, 0.95, 0.85, 0.8 * fade * fade))
	draw_arc(Vector2.ZERO, radius * out, 0.0, TAU, 48, Color(1.0, 0.8, 0.92, 0.9 * fade), 3.0)
	# borde punteado del area real
	if k < 0.7:
		var a := 0.7 * (1.0 - k / 0.7)
		for i in 24:
			var a0 := TAU * i / 24.0
			draw_arc(Vector2.ZERO, radius, a0, a0 + TAU / 48.0, 4, Color(1.0, 0.4, 0.7, a), 2.0)
