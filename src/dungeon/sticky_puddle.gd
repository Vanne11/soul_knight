class_name StickyPuddle
extends Node2D

## Charco pegajoso (roadmap_nico 36): obstaculo de suelo que frena al jugador Y a los enemigos
## (SLOW = 40% de su velocidad; a los jefes la mitad). No frena durante el dash ni mientras
## Vulvalquiria planea. Uno por reino, con nombre y aspecto propios:
##   neutral  Savia Pubescente      resina ambar con burbujas
##   pene     Jarabe de Obelisco    almibar rosa palido con hilos
##   vulva    Mermelada Intima      mermelada de frambuesa con pepitas
##   mixto    Sudor de Frontera     charco turbio verdoso con gotas
##   censura  Pegamento de Sellos   cola crema con restos de sellos
## Lo coloca RoomObstacles (salas de pelea, sin tapar puertas ni spawns). Nace gris con Censor
## (material de la sala) y se colorea al liberarla. Las huellas son las de WorldFx: la sala guarda
## el charco en la meta "wet_zones" con `wet` (claves de WorldFx.LIQUID).

const SLOW := 0.4
const BOSS_SLOW := 0.2
const NAME_KEYS := {
	"neutral": "PUDDLE_NEUTRAL", "pene": "PUDDLE_PENE", "vulva": "PUDDLE_VULVA",
	"mixto": "PUDDLE_MIXTO", "censura": "PUDDLE_CENSURA",
}
## wet = tipo de liquido de las huellas; col = cuerpo, edge = borde oscuro, hi = brillo, fleck = motas.
const LOOKS := {
	"neutral": {"wet": "resina", "col": Color(0.78, 0.5, 0.12), "edge": Color(0.42, 0.24, 0.05), "hi": Color(1.0, 0.86, 0.45), "fleck": Color(0.97, 0.78, 0.3)},
	"pene": {"wet": "baba", "col": Color(1.0, 0.72, 0.8), "edge": Color(0.78, 0.4, 0.55), "hi": Color(1.0, 0.95, 0.97), "fleck": Color(1.0, 0.86, 0.9)},
	"vulva": {"wet": "mermelada", "col": Color(0.72, 0.1, 0.3), "edge": Color(0.38, 0.03, 0.15), "hi": Color(1.0, 0.55, 0.65), "fleck": Color(0.3, 0.02, 0.1)},
	"mixto": {"wet": "dudoso", "col": Color(0.5, 0.6, 0.3), "edge": Color(0.26, 0.32, 0.14), "hi": Color(0.82, 0.9, 0.55), "fleck": Color(0.75, 0.85, 0.5)},
	"censura": {"wet": "cola", "col": Color(0.92, 0.86, 0.66), "edge": Color(0.55, 0.47, 0.3), "hi": Color(1.0, 0.98, 0.88), "fleck": Color(0.62, 0.12, 0.12)},
}

var room: Room = null
var kingdom := "neutral"
var rx := 60.0
var ry := 40.0
var seed_ := 1
var _blob := PackedVector2Array()
var _flecks: Array[Vector3] = []  # x, y, radio
var _t := 0.0
var _next_draw := 0.0


static func wet_kind(king: String) -> String:
	return LOOKS.get(king, LOOKS.neutral).wet


func _ready() -> void:
	add_to_group("sticky_puddle")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var ph := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]
	for i in 30:
		var a := TAU * float(i) / 30.0
		var f := 0.86 + 0.1 * sin(2.0 * a + ph[0]) + 0.06 * sin(3.0 * a + ph[1]) + 0.04 * sin(5.0 * a + ph[2])
		_blob.append(Vector2(cos(a) * rx * f, sin(a) * ry * f))
	for i in 7:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.7
		_flecks.append(Vector3(cos(a) * rx * d, sin(a) * ry * d, rng.randf_range(2.0, 4.5)))
	queue_redraw()


func _inside(p: Vector2) -> bool:
	var d := p - global_position
	return (d.x * d.x) / (rx * rx) + (d.y * d.y) / (ry * ry) <= 1.0


func _physics_process(delta: float) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if room == null or main == null or main.current_room != room:
		return
	var pl := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if pl != null and not pl.is_dashing and not (pl.defense != null and pl.defense.floor_clean()) and not (pl.ability != null and pl.ability.get("gliding") == true) and _inside(pl.global_position):
		pl.move_and_collide(-pl.velocity * SLOW * delta)
		if not pl.has_meta("sticky_" + kingdom):
			pl.set_meta("sticky_" + kingdom, true)  # el nombre sale la primera vez de la partida
			get_node("/root/GlobalEvents").show_floating_text.emit(pl.global_position + Vector2(0, -34), tr(NAME_KEYS.get(kingdom, NAME_KEYS.neutral)), LOOKS.get(kingdom, LOOKS.neutral).hi)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is CharacterBody2D and room.is_ancestor_of(e) and float(e.get("current_health")) > 0.0 and _inside(e.global_position):
			var k := BOSS_SLOW if e.is_in_group("boss") else SLOW
			(e as CharacterBody2D).move_and_collide(-(e as CharacterBody2D).velocity * k * delta)
	_t += delta
	if _t >= _next_draw:  # brillo vivo: se repinta unas 6 veces por segundo, solo en la sala actual
		_next_draw = _t + 0.16
		queue_redraw()


func _draw() -> void:
	var look: Dictionary = LOOKS.get(kingdom, LOOKS.neutral)
	var col: Color = look.col
	var edge: Color = look.edge
	var hi: Color = look.hi
	var fleck: Color = look.fleck
	draw_colored_polygon(_scaled(1.08, Vector2(0, 2)), Color(0, 0, 0, 0.28))  # sombra de contacto
	draw_colored_polygon(_scaled(1.0, Vector2.ZERO), edge)
	draw_colored_polygon(_scaled(0.9, Vector2(0, -1)), col)
	draw_colored_polygon(_scaled(0.62, Vector2(-rx * 0.1, -ry * 0.18)), col.lightened(0.18))
	# brillos: se mueven un poco (liquido espeso que respira)
	var k := sin(_t * 1.6) * 0.5
	draw_colored_polygon(_ellipse(Vector2(-rx * 0.28 + k, -ry * 0.32), rx * 0.2, ry * 0.1), Color(hi, 0.85))
	draw_colored_polygon(_ellipse(Vector2(rx * 0.12 - k, -ry * 0.1), rx * 0.09, ry * 0.05), Color(hi, 0.6))
	for f in _flecks:
		draw_colored_polygon(_ellipse(Vector2(f.x, f.y), f.z, f.z * 0.65), Color(fleck, 0.9))
		draw_colored_polygon(_ellipse(Vector2(f.x - f.z * 0.3, f.y - f.z * 0.25), f.z * 0.35, f.z * 0.25), Color(hi, 0.8))
	# hilos que se estiran hacia fuera (pegajoso)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ + 77
	for i in 3:
		var a := rng.randf() * TAU
		var p0 := Vector2(cos(a) * rx * 0.92, sin(a) * ry * 0.92)
		var p1 := p0 + Vector2(cos(a), sin(a)) * rng.randf_range(8.0, 15.0)
		draw_line(p0, p1, Color(col, 0.85), 2.0)
		draw_circle(p1, 2.2, Color(col, 0.9))


func _scaled(s: float, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in _blob:
		out.append(p * s + off)
	return out


func _ellipse(c: Vector2, a: float, b: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 12:
		var t := TAU * float(i) / 12.0
		out.append(c + Vector2(cos(t) * a, sin(t) * b))
	return out
