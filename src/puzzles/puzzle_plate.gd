extends Area2D
class_name PuzzlePlate

## Placa de acertijo en pixel art, una por reino (tools/gen_puzzle_art.py). Se hunde al
## pisarla (la textura "down" y el glifo bajan 3 px) y sube al soltarla. Emite `stepped`
## al entrar el jugador y `released` al salir. `watch_player=false` para placas que solo
## se hunden por codigo (pedestales, flores...): `set_pressed()`.

signal stepped(plate: PuzzlePlate)
signal released(plate: PuzzlePlate)

const DIR := "res://assets/sprites/environment/puzzles/"
const SINK := 3.0
static var _tex_cache: Dictionary = {}

var cell := Vector2i.ZERO     # celda o indice que le pone quien la crea
var tag := -1                 # etiqueta libre (color de seta, simbolo de sello...)
var pressed := false
var _kingdom := "neutral"
var _base: Sprite2D
var _glyph: Sprite2D
var _over: Sprite2D           # capa extra (mosaico de censura)
var _inside := 0


static func load_tex(name: String) -> Texture2D:
	if not _tex_cache.has(name):
		var path := DIR + name + ".png"
		_tex_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[name]


func setup(kingdom: String, watch_player := true, shape_half := 10.0) -> PuzzlePlate:
	_kingdom = kingdom if kingdom in ["neutral", "pene", "vulva", "mixto", "censura"] else "neutral"
	collision_layer = 0
	collision_mask = 1 if watch_player else 0  # el jugador
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2.ONE * shape_half * 2.0
	add_child(shape)
	_base = Sprite2D.new()
	_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_base)
	_glyph = Sprite2D.new()
	_glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_glyph)
	if watch_player:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	_refresh()
	return self


## Glifo (seta, sello, flor...) encima de la placa; dy sube/baja el dibujo.
func set_glyph(name: String, dy := -4.0) -> void:
	_glyph.texture = load_tex(name)
	_glyph.position = Vector2(0, dy)
	_glyph.set_meta("dy", dy)
	_refresh()


func set_overlay(name: String) -> void:
	if _over == null:
		_over = Sprite2D.new()
		_over.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_over)
	_over.texture = load_tex(name)
	_refresh()


func overlay() -> Sprite2D:
	return _over


func glyph() -> Sprite2D:
	return _glyph


func base() -> Sprite2D:
	return _base


func set_pressed(v: bool) -> void:
	if v == pressed:
		return
	pressed = v
	_refresh()


func _refresh() -> void:
	if _base == null:
		return
	_base.texture = load_tex("plate_%s_%s" % [_kingdom, "down" if pressed else "up"])
	var d := SINK if pressed else 0.0
	_glyph.position.y = float(_glyph.get_meta("dy", -4.0)) + d
	if _over:
		_over.position.y = d


## Destello breve (memoria, aciertos): brilla sobre blanco y vuelve.
func flash(color := Color(1.6, 1.6, 1.6), secs := 0.5) -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate", color, 0.05)
	tw.tween_property(self, "modulate", Color.WHITE, secs)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_inside += 1
	if _inside == 1:
		set_pressed(true)
		stepped.emit(self)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_inside = maxi(0, _inside - 1)
	if _inside == 0:
		set_pressed(false)
		released.emit(self)
