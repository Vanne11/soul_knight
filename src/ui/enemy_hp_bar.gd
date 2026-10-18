class_name EnemyHpBar
extends Node2D

## Barra de vida sobre la cabeza de un enemigo: aparece en cuanto le quitas vida (llena no se ve)
## y se va al morir. La cuelgan los _ready de las bases de enemigo (Enemy, EnemySwarmer,
## EnemyRanged, EnemyTank). Los jefes no la llevan: ya tienen la barra grande del HUD.

const WIDTH := 30.0
const HEIGHT := 4.0
const GAP := 6.0  # px por encima de la cabeza
const BG := Color(0.05, 0.02, 0.06, 0.85)
const FILL := Color("e43b44")

var _enemy: Node2D
var _spr: AnimatedSprite2D
var _ratio := 1.0


static func attach(enemy: Node2D) -> void:
	var bar := EnemyHpBar.new()
	bar._enemy = enemy
	bar._spr = enemy.get_node_or_null("AnimatedSprite2D")
	bar.z_index = 50
	bar.visible = false
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # que la luz de la sala no la apague
	bar.material = mat
	enemy.add_child(bar)


func _process(_delta: float) -> void:
	var mx := float(_enemy.max_health)
	var hp := float(_enemy.current_health)
	visible = mx > 0.0 and hp > 0.0 and hp < mx
	if not visible:
		return
	position.y = _head_y() - GAP - HEIGHT
	var r := clampf(hp / mx, 0.0, 1.0)
	if r != _ratio:
		_ratio = r
		queue_redraw()


## Borde de arriba del sprite (frame 0 de "idle", para que no salte con cada animacion).
func _head_y() -> float:
	if _spr == null or _spr.sprite_frames == null:
		return -40.0
	var anim := &"idle" if _spr.sprite_frames.has_animation(&"idle") else _spr.animation
	var tex := _spr.sprite_frames.get_frame_texture(anim, 0)
	if tex == null:
		return -40.0
	return _spr.position.y + (_spr.offset.y - tex.get_height() * 0.5) * absf(_spr.scale.y)


func _draw() -> void:
	draw_rect(Rect2(-WIDTH * 0.5 - 1.0, -1.0, WIDTH + 2.0, HEIGHT + 2.0), BG)
	draw_rect(Rect2(-WIDTH * 0.5, 0.0, WIDTH * _ratio, HEIGHT), FILL)
