extends Node2D
class_name WallClock

## Reloj de pie del contrarreloj opcional (floor_events). Pixel art de tools/gen_clock_art.py.
## El origen es el pie de la peana. Animado: segundero a saltos, pendulo con dos pelotas doradas,
## el cucu que sale de vez en cuando y, mientras la contrarreloj esta ofrecida, un pulso calido
## y un destello que llaman a tocarlo. Tras aceptar, la aguja grande marca el tiempo gastado.

const ART := "res://assets/sprites/clock/"
const SWING_DEG := 14.0
const SWING_PERIOD := 2.0
const CUCKOO_EVERY := 7.0

var offered := true     # llama la atencion (pulso y destello)
var progress := 0.0     # 0..1 del tiempo gastado de la contrarreloj
var _t := 0.0
var _sec_hand: Sprite2D
var _min_hand: Sprite2D
var _hour_hand: Sprite2D
var _pendulum: Sprite2D
var _leaf_l: Sprite2D
var _leaf_r: Sprite2D
var _bird: Sprite2D
var _glint: Sprite2D
var _last_sec := -1
var _cuckoo_t := 3.0
var _cuckoo_busy := false

const DIAL := Vector2(0, -35)
const BODY_POS := Vector2(-20, -62)


func _tex(n: String) -> Texture2D:
	return load(ART + n + ".png")


## Sprite con el pivote (px del dibujo) en el origen del nodo, para que gire sobre el.
func _spr(n: String, pivot := Vector2.ZERO) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex(n)
	s.centered = false
	s.offset = -pivot
	add_child(s)
	return s


func _init() -> void:
	set_meta("foot", 2.0)
	set_meta("half_w", 20.0)
	set_meta("tall", true)
	var body := _spr("body")
	body.position = BODY_POS
	_pendulum = _spr("pendulum", Vector2(8, 0))
	_pendulum.position = Vector2(0, -19)
	_bird = _spr("bird", Vector2(5, 9))
	_bird.position = Vector2(0, -51)
	_bird.visible = false
	_leaf_l = _spr("leaf_l")
	_leaf_l.position = Vector2(-4, -57)
	_leaf_r = _spr("leaf_r", Vector2(4, 0))
	_leaf_r.position = Vector2(4, -57)
	_hour_hand = _spr("hand_hour", Vector2(5, 7))
	_hour_hand.position = DIAL
	_min_hand = _spr("hand_min", Vector2(5, 9))
	_min_hand.position = DIAL
	_sec_hand = _spr("hand_sec", Vector2(5, 10))
	_sec_hand.position = DIAL
	_glint = _spr("glint", Vector2(3, 3))
	_glint.position = DIAL + Vector2(-5, -6)
	_glint.modulate.a = 0.0
	_update_hands()


## Gris mientras la region esta censurada, color al liberarla (como el resto de props).
func dress(room: Node) -> void:
	for c in get_children():
		if c is CanvasItem:
			Censor.apply(room, c)
	LightKit.add_contact_shadow(self, 24.0, 3.0)


func set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	# pendulo
	_pendulum.rotation = deg_to_rad(SWING_DEG) * sin(_t * TAU / SWING_PERIOD)
	# segundero a saltos
	var s := int(_t)
	if s != _last_sec:
		_last_sec = s
		_update_hands()
	# pulso calido y destello mientras esta ofrecido
	if offered:
		var k := 0.5 + 0.5 * sin(_t * 3.2)
		modulate = Color(1.0 + 0.22 * k, 1.0 + 0.16 * k, 1.0 + 0.04 * k)
		var g := fposmod(_t, 2.6) / 2.6
		_glint.modulate.a = clampf(sin(g * PI) * 1.4 - 0.2, 0.0, 1.0)
		_glint.scale = Vector2.ONE * (0.6 + 0.6 * sin(g * PI))
	else:
		modulate = Color.WHITE
		_glint.modulate.a = 0.0
	# cucu
	_cuckoo_t -= delta
	if _cuckoo_t <= 0.0 and not _cuckoo_busy:
		_cuckoo_t = CUCKOO_EVERY + randf() * 3.0
		_cuckoo()


func _update_hands() -> void:
	var sec := int(_t) % 60
	_sec_hand.rotation = deg_to_rad(sec * 6.0)
	# 10:10 de catalogo mientras se ofrece; luego la grande da la vuelta con el tiempo gastado
	_min_hand.rotation = deg_to_rad(60.0) if offered else progress * TAU
	_hour_hand.rotation = deg_to_rad(-60.0) + (0.0 if offered else progress * TAU / 12.0)


## Las puertecitas se abren, sale el pajarito, canta (se agita) y vuelve a entrar.
func _cuckoo() -> void:
	_cuckoo_busy = true
	_bird.visible = true
	_bird.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_leaf_l, "scale:x", 0.1, 0.12)
	tw.tween_property(_leaf_r, "scale:x", 0.1, 0.12)
	tw.chain().tween_property(_bird, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_bird, "rotation", 0.25, 0.1)
	tw.chain().tween_property(_bird, "rotation", -0.25, 0.2)
	tw.chain().tween_property(_bird, "rotation", 0.25, 0.2)
	tw.chain().tween_property(_bird, "rotation", 0.0, 0.1)
	tw.chain().tween_property(_bird, "scale", Vector2(0.3, 0.3), 0.15)
	tw.chain().tween_callback(func():
		_bird.visible = false
		_cuckoo_busy = false)
	tw.chain().tween_property(_leaf_l, "scale:x", 1.0, 0.12)
	tw.parallel().tween_property(_leaf_r, "scale:x", 1.0, 0.12)
