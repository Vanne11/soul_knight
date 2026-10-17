extends Node2D
class_name BossZone

## Zona de peligro de los jefes: AVISO (contorno que parpadea y se va llenando) ->
## ACTIVA (hace dano si el jugador esta dentro) -> se desvanece. Sin fisica: el
## dano se mide por geometria, asi vale para circulos, barras y cruces que giran.
## Nace gris (Censor) y se colorea cuando la sala se libera; no usa luces para que
## el aviso se lea siempre, tambien en la penumbra.

enum Shape { CIRCLE, RECT }
enum Style { NORMAL, BAR, PIXEL, SHIELD, CHANNEL }

const CENSOR_UNSHADED := preload("res://src/shaders/censor_unshaded.gdshader")
const GROUP := "boss_hazard"

signal went_active

var shape := Shape.CIRCLE
var style := Style.NORMAL
var radius := 60.0
## RECT: x = largo, y = ancho (centrado en la posicion).
var size := Vector2(300.0, 60.0)
var warn := 0.8
## < 0: dura hasta que alguien la quite.
var active := 0.3
var fade := 0.3
var damage := 10.0
var color := Color(1.0, 0.3, 0.25)
var vel := Vector2.ZERO
var spin := 0.0
## true: un solo golpe por activacion. false: cada vez que acaban los i-frames.
var one_hit := true
## Sigue a este nodo (escudo).
var follow: Node2D = null
var follow_offset := Vector2.ZERO
## Cuanto se agranda la zona al medir si el jugador la toca.
var margin := 10.0
## CHANNEL: progreso del tiempo (0..1), lo que queda de la barra de interrumpir (1..0) y su texto.
var p_time := 0.0
var p_break := 1.0
var label := ""
var label2 := ""

var phase := 0  # 0 aviso, 1 activa, 2 desvanece
var t := 0.0
var _hit := false
var _mat := ShaderMaterial.new()
var _room: Node = null
var _seed := 0.0


static func circle(pos: Vector2, r: float, warn_: float, active_: float, dmg: float, col := Color(1.0, 0.3, 0.25)) -> BossZone:
	var z := BossZone.new()
	z.radius = r
	z.warn = warn_
	z.active = active_
	z.damage = dmg
	z.color = col
	z.position = pos
	return z


static func rect(pos: Vector2, size_: Vector2, rot: float, warn_: float, active_: float, dmg: float, col := Color(1.0, 0.3, 0.25)) -> BossZone:
	var z := BossZone.new()
	z.shape = Shape.RECT
	z.size = size_
	z.rotation = rot
	z.warn = warn_
	z.active = active_
	z.damage = dmg
	z.color = col
	z.position = pos
	return z


func _ready() -> void:
	add_to_group(GROUP)
	_seed = float(get_instance_id() % 997)
	_mat.shader = CENSOR_UNSHADED
	material = _mat
	var n: Node = get_parent()
	while n != null and not (n is Room):
		n = n.get_parent()
	_room = n
	_sync_censor()
	if style == Style.PIXEL or style == Style.BAR:
		z_index = 40  # por encima de actores y balas
	elif style == Style.SHIELD or style == Style.CHANNEL:
		z_index = 3


func _sync_censor() -> void:
	var a := Censor.amount(_room) if _room else 1.0
	_mat.set_shader_parameter("color_amount", a)


func _physics_process(delta: float) -> void:
	t += delta
	if follow != null:
		if not is_instance_valid(follow):
			queue_free()
			return
		global_position = follow.global_position + follow_offset
	if phase >= 1:
		global_position += vel * delta
	rotation += spin * delta
	match phase:
		0:
			if t >= warn:
				phase = 1
				t = 0.0
				went_active.emit()
		1:
			if active >= 0.0 and t >= active:
				phase = 2
				t = 0.0
			else:
				_check_damage()
		2:
			if t >= fade:
				queue_free()
	_sync_censor()
	queue_redraw()


func is_active() -> bool:
	return phase == 1


## Apaga la zona ya (se desvanece).
func dismiss() -> void:
	if phase < 2:
		phase = 2
		t = 0.0


func contains(p: Vector2) -> bool:
	if shape == Shape.CIRCLE:
		return p.distance_to(global_position) <= radius + margin
	var l := (p - global_position).rotated(-global_rotation)
	return absf(l.x) <= size.x * 0.5 + margin and absf(l.y) <= size.y * 0.5 + margin


func _check_damage() -> void:
	if damage <= 0.0 or (one_hit and _hit):
		return
	var tg := get_tree().get_first_node_in_group("player")
	if tg == null:
		return
	if contains(tg.global_position) and tg.has_method("receive_hit"):
		if tg.receive_hit(damage):
			_hit = true


# ------------------------------------------------------------------ dibujo
func _draw() -> void:
	match style:
		Style.PIXEL:
			_draw_pixel()
		Style.SHIELD:
			_draw_shield()
		Style.CHANNEL:
			_draw_channel()
		Style.BAR:
			_draw_bar()
		_:
			_draw_normal()


func _draw_normal() -> void:
	var pulse := 0.65 + 0.35 * sin(t * 24.0)
	var white := Color(1, 1, 1)
	if phase == 0:
		var p := clampf(t / maxf(warn, 0.01), 0.0, 1.0)
		var edge := Color(color.lerp(white, 0.6), 0.55 + 0.45 * pulse)
		var fill := Color(color, 0.10 + 0.22 * p)
		if shape == Shape.CIRCLE:
			draw_circle(Vector2.ZERO, radius, fill)
			draw_circle(Vector2.ZERO, radius * p, Color(color, 0.35))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, edge, 3.0)
		else:
			var r := Rect2(-size * 0.5, size)
			draw_rect(r, fill)
			draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y * 0.5 * p), Vector2(size.x, size.y * p)), Color(color, 0.35))
			draw_rect(r, edge, false, 3.0)
			if vel.length() > 1.0:
				_chevrons(Color(color.lerp(white, 0.7), 0.5 + 0.4 * pulse))
	else:
		var a := 1.0 if phase == 1 else 1.0 - clampf(t / maxf(fade, 0.01), 0.0, 1.0)
		var fillc := Color(color.lerp(white, 0.15), 0.78 * a)
		var core := Color(white, 0.55 * a)
		if shape == Shape.CIRCLE:
			draw_circle(Vector2.ZERO, radius, fillc)
			draw_circle(Vector2.ZERO, radius * 0.6, core)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(white, a), 3.0)
		else:
			var r := Rect2(-size * 0.5, size)
			draw_rect(r, fillc)
			draw_rect(Rect2(-size * 0.5 + Vector2(0, size.y * 0.25), Vector2(size.x, size.y * 0.5)), core)
			draw_rect(r, Color(white, a), false, 3.0)


## Flechas en el sentido del avance (barras que se mueven).
func _chevrons(col: Color) -> void:
	var d := vel.rotated(-global_rotation).normalized()
	var perp := d.orthogonal()
	var span: float = size.y if absf(d.x) >= 0.5 else size.x
	var n := maxi(int(span / 70.0), 1)
	for i in n:
		var c := perp * ((i + 0.5) * span / n - span * 0.5)
		var tip := c + d * 16.0
		draw_line(tip, tip - d * 14.0 + perp * 12.0, col, 3.0)
		draw_line(tip, tip - d * 14.0 - perp * 12.0, col, 3.0)


func _draw_bar() -> void:
	var r := Rect2(-size * 0.5, size)
	if phase == 0:
		var p := clampf(t / maxf(warn, 0.01), 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(t * 26.0)
		draw_rect(r, Color(1, 1, 1, 0.06 + 0.12 * p))
		# la barra "se dibuja" desde el centro hacia afuera segun se acerca el golpe
		draw_rect(Rect2(Vector2(-size.x * 0.5, -size.y * 0.5 * p), Vector2(size.x, size.y * p)), Color(0, 0, 0, 0.55))
		draw_rect(r, Color(1, 1, 1, 0.5 + 0.5 * pulse), false, 3.0)
	else:
		var a := 1.0 if phase == 1 else 1.0 - clampf(t / maxf(fade, 0.01), 0.0, 1.0)
		draw_rect(r, Color(0.02, 0.02, 0.03, a))
		draw_rect(r, Color(1, 1, 1, a), false, 3.0)
		# franjas blancas del "CENSURADO"
		var x := -size.x * 0.5
		while x < size.x * 0.5:
			draw_line(Vector2(x, -size.y * 0.5), Vector2(x + size.y * 0.5, size.y * 0.5), Color(1, 1, 1, 0.16 * a), 6.0)
			x += 46.0


func _draw_pixel() -> void:
	var r := Rect2(-size * 0.5, size)
	var cell := 22.0
	var nx := int(ceil(size.x / cell))
	var ny := int(ceil(size.y / cell))
	if phase == 0:
		var p := clampf(t / maxf(warn, 0.01), 0.0, 1.0)
		var pulse := 0.5 + 0.5 * sin(t * 22.0)
		draw_rect(r, Color(1, 1, 1, 0.08 + 0.2 * p))
		draw_rect(r, Color(1, 1, 1, 0.5 + 0.5 * pulse), false, 3.0)
		for i in nx:
			for j in ny:
				if fposmod(float(i * 7 + j * 3) * 0.137 + _seed * 0.01, 1.0) < p * 0.6:
					draw_rect(Rect2(r.position + Vector2(i, j) * cell, Vector2(cell, cell)), Color(0.5, 0.5, 0.5, 0.35))
	else:
		var a := 1.0 if phase == 1 else 1.0 - clampf(t / maxf(fade, 0.01), 0.0, 1.0)
		var frame := floorf(t * 7.0)
		for i in nx:
			for j in ny:
				var v := fposmod(sin(float(i) * 12.9898 + float(j) * 78.233 + frame * 3.17 + _seed) * 43758.5453, 1.0)
				var g := 0.22 + 0.62 * v
				var cs := Vector2(minf(cell, size.x - i * cell), minf(cell, size.y - j * cell))
				draw_rect(Rect2(r.position + Vector2(i, j) * cell, cs), Color(g, g, g, 0.94 * a))
		draw_rect(r, Color(1, 1, 1, 0.6 * a), false, 2.0)


func _draw_shield() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.12 + 0.08 * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color.lerp(Color.WHITE, 0.5), 0.6 + 0.3 * pulse), 4.0)
	for i in 6:
		var a := t * 0.8 + i * TAU / 6.0
		draw_arc(Vector2.ZERO, radius + 7.0, a, a + 0.35, 6, Color(1, 1, 1, 0.7), 3.0)


func _draw_channel() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.14 + 0.12 * pulse))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(color.lerp(Color.WHITE, 0.5), 0.5 + 0.4 * pulse), 3.0)
	# anillo exterior que se llena: cuando se completa, el jefe recupera la vida
	draw_arc(Vector2.ZERO, radius + 12.0, -PI * 0.5, -PI * 0.5 + TAU * p_time, 48, Color(1, 1, 1, 0.95), 6.0)
	# barra de progreso del desafio y su texto (debajo del jefe: arriba lo tapa el HUD)
	var w := 150.0
	var bar := Rect2(Vector2(-w * 0.5, radius - 40.0), Vector2(w, 14.0))
	draw_rect(bar.grow(3.0), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(bar.position, Vector2(w * clampf(p_break, 0.0, 1.0), bar.size.y)), Color(1.0, 0.85, 0.2, 1.0))
	draw_rect(bar, Color(1, 1, 1, 0.9), false, 2.0)
	var f := ThemeDB.fallback_font
	var y := bar.position.y + bar.size.y + 22.0
	var sx := get_global_transform_with_canvas().origin.x
	if label != "":
		var sz := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		draw_string_outline(f, Vector2(clampf(-sz.x * 0.5, 16.0 - sx, 1264.0 - sx - sz.x), y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0))
		draw_string(f, Vector2(clampf(-sz.x * 0.5, 16.0 - sx, 1264.0 - sx - sz.x), y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1))
		y += 20.0
	if label2 != "":
		var sz2 := f.get_string_size(label2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string_outline(f, Vector2(clampf(-sz2.x * 0.5, 16.0 - sx, 1264.0 - sx - sz2.x), y), label2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0))
		draw_string(f, Vector2(clampf(-sz2.x * 0.5, 16.0 - sx, 1264.0 - sx - sz2.x), y), label2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.95, 0.8))
