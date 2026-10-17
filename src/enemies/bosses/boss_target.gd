extends StaticBody2D
class_name BossTarget

## Blanco de los desafios de los jefes alternativos (pastillas, papeles, cookies...): el
## jugador lo rompe a tiros. Esta en el grupo "enemy" para que las balas (y el bot) lo traten
## como un enemigo, pero no cuenta para limpiar la sala. El dibujo lo pone el desafio
## (drawer(blanco)); nace gris (Censor) y se colorea al liberar la sala, como BossBreakable.

signal broken(b: BossTarget)

var enemy_name := "Blanco"
var max_health := 12.0
var current_health := 12.0
var drawer := Callable()
## Logica por frame (movimiento): tick_cb(blanco, delta).
var tick_cb := Callable()
var radius := 24.0
var data := {}
var t := 0.0

var _flash := 0.0
var _dead := false
var _mat := ShaderMaterial.new()
var _room: Node = null


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss_breakable")
	collision_layer = 0
	set_collision_layer_value(2, true)
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = radius
	cs.shape = sh
	add_child(cs)
	current_health = max_health
	_mat.shader = BossZone.CENSOR_UNSHADED
	material = _mat
	var n: Node = get_parent()
	while n != null and not (n is Room):
		n = n.get_parent()
	_room = n
	z_index = 2


func _physics_process(delta: float) -> void:
	if _dead:
		return
	t += delta
	_flash = maxf(0.0, _flash - delta)
	_mat.set_shader_parameter("color_amount", Censor.amount(_room) if _room else 1.0)
	if tick_cb.is_valid():
		tick_cb.call(self, delta)
	queue_redraw()


func is_alive() -> bool:
	return not _dead


func is_flashing() -> bool:
	return _flash > 0.0


func take_damage(amount: float, _source: Node = null, _kb: Vector2 = Vector2.ZERO) -> float:
	if _dead:
		return 0.0
	current_health -= amount
	_flash = 0.12
	Sound.play("enemy_hit")
	if current_health <= 0.0:
		_dead = true
		HitFx.shake(0.15)
		broken.emit(self)
		set_deferred("collision_layer", 0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
		tw.tween_property(self, "modulate:a", 0.0, 0.15)
		tw.chain().tween_callback(queue_free)
	return amount


func die(_killer: Node = null) -> void:
	if _dead:
		return
	_dead = true
	queue_free()


func _draw() -> void:
	if drawer.is_valid():
		drawer.call(self)
