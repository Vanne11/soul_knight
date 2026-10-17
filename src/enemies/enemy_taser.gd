extends EnemyRanged
class_name EnemyTaser

## Dildo Electrico: enemigo a distancia. Misma IA y mismos numeros que el
## EnemyRanged (carga, ventana para esquivar, 3 disparos en abanico); solo cambia
## el proyectil (chispas electricas) y un chisporroteo mientras carga.

const SPARK_SCENE := preload("res://src/enemies/projectile_spark.tscn")


func _ready() -> void:
	projectile_scene = SPARK_SCENE
	super._ready()


func _attack() -> void:
	var was_idle := _charging <= 0.0 and _fire_timer <= 0.0 and target != null
	super._attack()
	if was_idle and _charging > 0.0:
		_crackle()


## Chisporroteo en la punta mientras carga: el aviso, ademas del parpadeo.
func _crackle() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(0, -34)
	p.amount = 18
	p.lifetime = charge_time * 0.6
	p.one_shot = false
	p.emitting = true
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.95, 0.55, 1), ProjectileSpark.SPARK_CYAN, Color(0.2, 0.5, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = g
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	add_child(p)
	var glow := ActorFx.add_glow(self, ProjectileSpark.SPARK_CYAN, 0.9, 0.5)
	glow.position = Vector2(0, -34)
	get_tree().create_timer(charge_time).timeout.connect(func():
		if is_instance_valid(p): p.queue_free()
		if is_instance_valid(glow): glow.queue_free())
