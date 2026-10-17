extends Node2D
class_name AbilityGauge

## Barrita de recarga de la habilidad del heroe, bajo el medidor del arma (que vive en y=24).
## Solo se ve mientras la habilidad se recarga o se esta usando; propia, sin tocar hud.gd.

const W := 30.0
const H := 3.0

var ability: HeroAbility = null
var _last := ""


func _ready() -> void:
	position = Vector2(0, 30)
	z_index = 20


func _process(_delta: float) -> void:
	if ability == null:
		return
	var sig := "%s%.2f" % [ability.gauge_visible, ability.gauge_value]
	if sig != _last:
		_last = sig
		queue_redraw()


func _draw() -> void:
	if ability == null or not ability.gauge_visible:
		return
	var r := Rect2(-W * 0.5, 0, W, H)
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.7))
	var v := clampf(ability.gauge_value, 0.0, 1.0)
	draw_rect(Rect2(r.position, Vector2(W * v, H)), ability.gauge_color if v < 1.0 else Color.WHITE)
