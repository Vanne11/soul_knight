class_name AffixTag
extends Node2D

## Cartel del elite con afijos, dibujado en codigo (sin arte): iconos pixel 7x7 de cada afijo
## sobre la cabeza, barra del escudo (blindado), y el nombre compuesto ("Testiculo Errante
## [Vengativo]") que aparece al nacer y cada vez que lo golpeas. Hijo del enemigo, no se voltea
## con el sprite. Tambien dibuja el brillo de cada afijo (burbuja del escudo, destello del espejo).

const FONT := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const PX := 2.0  ## tamano de cada pixel del icono
const NAME_SHOW := 3.5
const NAME_HIT := 2.0

var ids: Array = []
var affix_nodes: Array = []
var _t := 0.0
var _name_t := NAME_SHOW
var _flash := 0.0
var _flash_col := Color.WHITE
var _enemy: Node2D = null
var _top := -40.0
var _name_cache := ""
var _locale := ""


func _ready() -> void:
	z_index = 20
	_enemy = get_parent() as Node2D
	var ge := get_node_or_null("/root/GlobalEvents")
	if ge != null:
		ge.enemy_damaged.connect(_on_enemy_damaged)
	_t = randf() * TAU


func _on_enemy_damaged(e: Node, _amount: float, _src: Node) -> void:
	if e == _enemy:
		_name_t = maxf(_name_t, NAME_HIT)


## Destello breve del cartel (un afijo hizo algo: rompio el escudo, refleja, salta...).
func flash(col: Color) -> void:
	_flash = 0.35
	_flash_col = col


func affix(id: String) -> Node:
	for n in affix_nodes:
		if is_instance_valid(n) and n.get("id") == id:
			return n
	return null


func _process(delta: float) -> void:
	_t += delta
	_name_t = maxf(0.0, _name_t - delta)
	_flash = maxf(0.0, _flash - delta)
	_update_top()
	queue_redraw()


func _update_top() -> void:
	var spr = _enemy.get("animated_sprite") if _enemy != null else null
	if spr is AnimatedSprite2D and spr.sprite_frames != null:
		var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
		if tex != null:
			_top = spr.position.y + spr.offset.y * spr.scale.y - tex.get_height() * absf(spr.scale.y) * 0.5 - 6.0


func _draw() -> void:
	var n := ids.size()
	var total_w := n * 7.0 * PX + (n - 1) * 3.0
	var x0 := -total_w * 0.5
	var y := _top - 7.0 * PX
	# brillo de cada afijo bajo los iconos
	_draw_glows()
	for i in n:
		var id: String = ids[i]
		var col := Affixes.color_of(id)
		if _flash > 0.0 and int(_t * 30.0) % 2 == 0:
			col = col.lerp(Color.WHITE, 0.7)
		_draw_icon(Affixes.DEFS[id].icon, Vector2(x0 + i * (7.0 * PX + 3.0), y), col)
	# barra del escudo
	var bl = affix("blindado")
	if bl != null and float(bl.get("shield")) > 0.0:
		var frac := clampf(float(bl.get("shield")) / maxf(1.0, float(bl.get("shield_max"))), 0.0, 1.0)
		var w := maxf(28.0, total_w)
		var r := Rect2(-w * 0.5, y + 7.0 * PX + 2.0, w, 4.0)
		draw_rect(r.grow(1.0), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(r.position, Vector2(w * frac, r.size.y)), Color("5fb0ff"))
		draw_rect(Rect2(r.position, Vector2(w * frac, 1.0)), Color("c8e6ff"))
	# nombre compuesto
	if _name_t > 0.0 and _enemy != null:
		var txt := _full_name()
		var a := clampf(_name_t / 0.6, 0.0, 1.0)
		var sz := 8
		var ts := FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
		var pos := Vector2(-ts.x * 0.5, y - 4.0)
		draw_string_outline(FONT, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, 3, Color(0, 0, 0, a))
		draw_string(FONT, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(1, 0.92, 0.85, a))


func _full_name() -> String:
	var loc := TranslationServer.get_locale()
	if _name_cache == "" or loc != _locale:
		_locale = loc
		_name_cache = Affixes.full_name(String(_enemy.get("enemy_name")), ids)
	return _name_cache


func _draw_icon(rows: Array, pos: Vector2, col: Color) -> void:
	var light := col.lerp(Color.WHITE, 0.45)
	# borde oscuro para que se lea sobre cualquier suelo
	for ry in rows.size():
		var row: String = rows[ry]
		for rx in row.length():
			if row[rx] != ".":
				draw_rect(Rect2(pos + Vector2(rx, ry) * PX - Vector2(1, 1), Vector2(PX + 2, PX + 2)), Color(0, 0, 0, 0.75))
	for ry in rows.size():
		var row: String = rows[ry]
		for rx in row.length():
			var c: String = row[rx]
			if c == ".":
				continue
			draw_rect(Rect2(pos + Vector2(rx, ry) * PX, Vector2(PX, PX)), light if c == "o" else col)


func _draw_glows() -> void:
	var feet := Vector2(0, 8)
	var h := absf(_top) * 0.5
	if ids.has("blindado"):
		var bl = affix("blindado")
		if bl != null and float(bl.get("shield")) > 0.0:
			var a := 0.16 + 0.06 * sin(_t * 4.0)
			draw_circle(Vector2(0, -h * 0.4), h + 8.0, Color(0.37, 0.69, 1.0, a))
			draw_arc(Vector2(0, -h * 0.4), h + 8.0, 0.0, TAU, 28, Color(0.6, 0.85, 1.0, 0.55), 1.5)
	if ids.has("reflector"):
		# destello que cruza el cuerpo: el espejo
		var s := fposmod(_t * 0.7, 1.6)
		if s < 0.5:
			var cx := lerpf(-h, h, s / 0.5)
			draw_line(Vector2(cx - 5, -h * 1.1), Vector2(cx + 5, -h * 0.1), Color(1, 1, 1, 0.75), 2.0)
	if ids.has("venenoso"):
		for i in 3:
			var ph := fposmod(_t * 0.8 + i * 0.33, 1.0)
			draw_circle(feet + Vector2(sin(i * 2.1 + _t) * 14.0, -ph * 26.0), 2.0 * (1.0 - ph) + 0.5, Color(0.56, 0.86, 0.16, 0.8 * (1.0 - ph)))
	if ids.has("pegajoso"):
		for i in 3:
			var ph := fposmod(_t * 0.5 + i * 0.33, 1.0)
			draw_circle(Vector2((i - 1) * 12.0, 4 + ph * 8.0), 2.0, Color(0.72, 0.91, 0.29, 0.8 * (1.0 - ph * 0.5)))
	if ids.has("rapido"):
		for i in 2:
			var ph := fposmod(_t * 3.0 + i * 0.5, 1.0)
			draw_line(Vector2(-14 - ph * 8, -h * 0.5 + i * 8), Vector2(-24 - ph * 8, -h * 0.5 + i * 8), Color(1, 0.82, 0.23, 0.6 * (1.0 - ph)), 1.5)
