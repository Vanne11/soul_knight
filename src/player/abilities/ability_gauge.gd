extends Node2D
class_name AbilityGauge

## Barrita de recarga de la habilidad del heroe, bajo el medidor del arma (que vive en y=24).
## Solo se ve mientras la habilidad se recarga o se esta usando; propia, sin tocar hud.gd.

const W := 30.0
const H := 3.0

## Teclas de cada heroe: [accion del InputMap, clave de teclas.csv]. El HUD las muestra
## como "glifo + nombre" abajo a la derecha (hud.gd) y esta barrita lleva la principal.
const HINTS := {
	"pitocles": [["guard", "GLYPH_GUARD_PITOCLES"]],
	"vulvalquiria": [["guard", "GLYPH_GUARD_VULVALQUIRIA"], ["ability", "GLYPH_ABILITY_VULVALQUIRIA"]],
	"ornitorrinco": [["guard", "GLYPH_GUARD_ORNITORRINCO"], ["ability", "GLYPH_ABILITY_ORNITORRINCO"]],
}

var ability: HeroAbility = null
var _last := ""
var _glyph: InputGlyph


## Accion de la barra: la "ability" si el heroe la tiene; si no (Pitocles), el escudo.
static func main_action(character: String) -> String:
	var hints: Array = HINTS.get(character, [])
	for h in hints:
		if h[0] == "ability":
			return "ability"
	return hints[0][0] if not hints.is_empty() else ""


func _ready() -> void:
	position = Vector2(0, 30)
	z_index = 20
	# la tecla, pegada a la barra mientras recarga (a 1x: es un adorno junto al medidor)
	_glyph = InputGlyph.new()
	_glyph.art_scale = 1
	_glyph.action = main_action(get_node("/root/RunManager").character)
	_glyph.position = Vector2(W * 0.5 + 4.0, -5.0)
	_glyph.modulate.a = 0.0
	add_child(_glyph)


func _process(_delta: float) -> void:
	if ability == null:
		return
	var sig := "%s%.2f" % [ability.gauge_visible, ability.gauge_value]
	if sig != _last:
		_last = sig
		queue_redraw()
		_glyph.modulate.a = 1.0 if ability.gauge_visible else 0.0


func _draw() -> void:
	if ability == null or not ability.gauge_visible:
		return
	var r := Rect2(-W * 0.5, 0, W, H)
	draw_rect(r.grow(1.0), Color(0, 0, 0, 0.7))
	var v := clampf(ability.gauge_value, 0.0, 1.0)
	draw_rect(Rect2(r.position, Vector2(W * v, H)), ability.gauge_color if v < 1.0 else Color.WHITE)
