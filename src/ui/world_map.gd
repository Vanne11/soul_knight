class_name WorldMap
extends RefCounted

## Pestana "Mundo" del mapa grande (ver minimap.gd): dibuja assets/data/world_map.json (sale de
## tools/gen_world_map.py, en celdas de cuadricula) con _draw, sin sprites. Solo LEE el estado de
## la ruta (RunManager: route_regions, seal_regions, seals(), next_options()); no decide nada.

const FILE := "res://assets/data/world_map.json"
const GRAY := Color(0.42, 0.42, 0.48)
const INK := Color("0d0b0f")
const GOLD := Color("ffd75a")
const FIXED := Color("ff961e")
const CHOICE := Color("ffe146")
const TUNNEL := Color(0.45, 0.5, 0.78)
const SEAL_RED := Color("c2323c")
const RAINBOW := ["ff5a5a", "ffaa3c", "ffe646", "64d26e", "50aaff", "a06ef0"]

static var _data: Dictionary = {}
var _font: Font = HudStyle.FONT

# estado de la ruta (se recalcula en cada draw; es barato)
var _route: Array = []
var _exist: Array = []
var _opts: Array = []
var _cur := ""
var _back := ""
var _center: Array = []
var _body: Array = []
var _blink := true
var _pulse := 0.0
var _o := Vector2.ZERO
var _s := Vector2.ONE


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(FILE, FileAccess.READ)
		if f:
			var j = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				_data = j
	return _data


static func tr_(key: String) -> String:
	return TranslationServer.translate(key)


## Region donde esta el jugador ahora ("utero" si esta en el piso secreto).
static func current_region(rm: Node) -> String:
	var fd: Dictionary = rm.floor_data()
	return "utero" if str(fd.get("id", "")) == "utero" else str(fd.get("region", ""))


## Nombre del reino: el de siempre si existe en FLOORS (Loc.region_name_id) o la clave de mapa_mundo.csv.
static func region_label(r: Dictionary) -> String:
	if str(r.id) in RunManager.regions():
		return Loc.region_name_id(str(r.id))
	return Loc.tr_or(str(r.name_key), str(r.name))


func draw(ci: CanvasItem, rect: Rect2, rm: Node) -> void:
	var d := data()
	if d.is_empty():
		return
	_refresh(rm)
	var g: Dictionary = d.grid
	_s = Vector2(rect.size.x / float(g.w), rect.size.y / float(g.h))
	_o = rect.position
	var t := Time.get_ticks_msec() / 1000.0
	_blink = int(t * 2.5) % 2 == 0
	_pulse = 0.5 + 0.5 * sin(t * 3.0)

	for tn in d.tunnels:
		for line in tn.lines:
			var pts := PackedVector2Array()
			for p in line:
				pts.append(_pt(p[0], p[1]))
			ci.draw_polyline(pts, INK, 5.0)
			ci.draw_polyline(pts, TUNNEL, 3.0)
	for r in d.regions:
		_draw_region(ci, r)
	_draw_elevator(ci, d.elevator)
	for door in d.doors:
		_draw_door(ci, door)
	for r in d.regions:
		_draw_name(ci, r)
		_draw_overlays(ci, r)
	_draw_hud(ci, rect)


func _refresh(rm: Node) -> void:
	_route = RunManager.route_regions
	_exist = RunManager.regions()
	_opts = RunManager.next_options()
	_cur = current_region(rm)
	_back = str(_route.back()) if not _route.is_empty() else _cur
	_center = RunManager.ROUTES.get("center", [])
	_body = RunManager.ROUTES.get("body", [])


func _pt(x: float, y: float) -> Vector2:
	return _o + Vector2(x * _s.x, y * _s.y)


func _rect(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(_pt(x, y), Vector2(w * _s.x, h * _s.y))


func _visited(id: String) -> bool:
	return id in _route or id == _cur or (id == "utero" and RunManager.utero_inserted)


## Reino "pasado": visitado, o inexistente (aun por disenar) con un reino posterior del centro visitado.
func _reached(id: String) -> bool:
	if _visited(id):
		return true
	var i := _center.find(id)
	if i < 0 or id in _exist:
		return false
	for c in _center.slice(i + 1):
		if _visited(str(c)):
			return true
	return false


func _is_missing(id: String) -> bool:
	return id not in _exist and not (id == "utero" and RunManager.utero_inserted)


func _draw_region(ci: CanvasItem, r: Dictionary) -> void:
	var id := str(r.id)
	var rc := _rect(r.x, r.y, r.w, r.h)
	var col := Color(str(r.color))
	if _is_missing(id):
		# silueta punteada con "?": existe en el diseno pero aun no en el juego
		ci.draw_rect(rc, Color(col, 0.07))
		_dashed_rect(ci, rc, Color(col, 0.75))
		_text(ci, "?", rc.get_center() + Vector2(0, 10), rc.size.x, 32, Color(col, 0.8), true)
		if r.rainbow:
			_rainbow_strip(ci, rc)
		return
	if _visited(id):
		ci.draw_rect(rc, Color(col, 0.28))
		ci.draw_rect(rc, col, false, 2.0)
	else:
		ci.draw_rect(rc, Color(GRAY, 0.22))
		ci.draw_rect(rc, GRAY, false, 2.0)
		if id in _opts:
			ci.draw_rect(rc.grow(2), Color(1, 1, 1, 0.25 + 0.45 * _pulse), false, 2.0)
	if r.rainbow:
		_rainbow_strip(ci, rc)


## Nombres al final (encima del ascensor y las puertas): visitado en blanco, "?" apagado, siguiente
## opcion legible y el resto censurado con una barra.
func _draw_name(ci: CanvasItem, r: Dictionary) -> void:
	var id := str(r.id)
	var rc := _rect(r.x, r.y, r.w, r.h)
	var col := Color(str(r.color))
	var pos := rc.position + Vector2(5 + float(r.get("label_dx", 0.0)) * _s.x, 17)
	if _is_missing(id):
		_text(ci, region_label(r), pos, -1, 16, Color(col, 0.7))
	elif _visited(id):
		_text(ci, region_label(r), pos, -1, 16, Color.WHITE)
	elif id in _opts:
		_text(ci, region_label(r), pos, -1, 16, Color(0.85, 0.85, 0.9))
	else:
		var w := _font.get_string_size(region_label(r), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		ci.draw_rect(Rect2(pos + Vector2(0, -13), Vector2(w, 12)), Color(0.12, 0.12, 0.15))


func _text(ci: CanvasItem, s: String, pos: Vector2, width: float, size: int, col: Color, centered := false) -> void:
	var al := HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	var p := pos - Vector2(width / 2.0, 0) if centered else pos
	ci.draw_string(_font, p + Vector2(2, 2), s, al, width, size, INK)
	ci.draw_string(_font, p, s, al, width, size, col)


func _dashed_rect(ci: CanvasItem, rc: Rect2, col: Color) -> void:
	var a := rc.position
	var b := rc.position + Vector2(rc.size.x, 0)
	var c := rc.end
	var d := rc.position + Vector2(0, rc.size.y)
	for seg in [[a, b], [b, c], [c, d], [d, a]]:
		ci.draw_dashed_line(seg[0], seg[1], col, 2.0, 5.0)


func _rainbow_strip(ci: CanvasItem, rc: Rect2) -> void:
	var w := (rc.size.x - 4.0) / RAINBOW.size()
	for i in RAINBOW.size():
		ci.draw_rect(Rect2(rc.position + Vector2(2 + i * w, 2), Vector2(w, 3)), Color(RAINBOW[i]))


func _draw_elevator(ci: CanvasItem, e: Dictionary) -> void:
	var rc := _rect(e.x, e.y, e.w, e.h)
	var lit := _reached("utero")
	ci.draw_rect(rc, Color("0e4659", 0.5 if lit else 0.3))
	ci.draw_rect(rc, Color("78ebff", 0.9 if lit else 0.45), false, 2.0)
	var n := 4
	for i in n:
		var y := rc.position.y + rc.size.y * (i + 0.5) / n
		var c := rc.get_center().x
		ci.draw_colored_polygon(PackedVector2Array([Vector2(c, y - 5), Vector2(c - 5, y + 3), Vector2(c + 5, y + 3)]), Color("96f0ff", 0.7 if lit else 0.35))


## "used" / "possible" / "idle" segun la ruta. Solo lectura.
func _door_state(door: Dictionary) -> String:
	var fr := str(door["from"])
	var to := str(door["to"])
	var next_c := str(_opts[0]) if _opts.size() == 1 and str(_opts[0]) in _center else ""
	if door.kind == "eleccion":
		var i := _route.find(fr)
		if i >= 0 and i + 1 < _route.size() and str(_route[i + 1]) in _body:
			return "used"
		if fr == _back and not _opts.is_empty() and str(_opts[0]) in _body:
			return "possible"
		return "idle"
	if fr in _body:  # puerta del cuerpo al centro (candado de sellos)
		var last_body := ""
		for r in _route:
			if str(r) in _body:
				last_body = str(r)
		if fr == last_body and _reached(to):
			return "used"
		if fr == _back and next_c != "":
			return "possible"
		return "idle"
	if _reached(to) and _reached(fr):
		return "used"
	# tramo del centro hacia el siguiente reino: se ilumina el camino que viene
	if next_c != "" and _center.find(to) <= _center.find(next_c) and (_center.find(fr) >= _center.find(_back) or _back in _body):
		return "possible"
	return "idle"


func _draw_door(ci: CanvasItem, door: Dictionary) -> void:
	var st := _door_state(door)
	var base: Color = FIXED if door.kind == "fija" else CHOICE
	var a := 0.4
	if st == "used":
		a = 1.0
	elif st == "possible":
		a = 0.55 + 0.45 * _pulse
	var c := _pt(door.x, door.y)
	var dir := _dir(str(door.dir))
	var sz := Vector2(10, 14) if dir.x == 0 else Vector2(14, 10)
	var rc := Rect2(c - sz / 2, sz)
	ci.draw_rect(rc, Color(base, a))
	ci.draw_rect(rc, Color.WHITE if st == "used" else Color(INK, 0.9), false, 2.0 if st == "used" else 1.0)
	var perp := Vector2(-dir.y, dir.x)
	if door.kind == "fija":
		ci.draw_colored_polygon(PackedVector2Array([c + dir * 4, c - dir * 2 + perp * 3, c - dir * 2 - perp * 3]), Color(INK, 0.9))
	else:
		ci.draw_line(c - dir * 3, c + dir * 3, Color(INK, 0.9), 1.5)
		ci.draw_line(c + dir * 3, c + perp * 3, Color(INK, 0.9), 1.5)
		ci.draw_line(c + dir * 3, c - perp * 3, Color(INK, 0.9), 1.5)
	if int(door.seals) > 0:
		var open := RunManager.seals() >= RunManager.seals_needed()
		var off := Vector2(0, -15) if dir.x != 0 else Vector2(15, 0)
		_lock(ci, c + off, open, a if st != "idle" else 0.7)


func _lock(ci: CanvasItem, c: Vector2, open: bool, a: float) -> void:
	var body := Color("5fe08a") if open else FIXED
	ci.draw_arc(c + Vector2(0, -2 if not open else -5), 3.5, PI, TAU * (1.0 if not open else 0.92), 10, Color(0.95, 0.95, 1, a), 2.0)
	ci.draw_rect(Rect2(c + Vector2(-5, -2), Vector2(10, 7)), Color(body, a))
	ci.draw_rect(Rect2(c + Vector2(-5, -2), Vector2(10, 7)), INK, false, 1.0)


func _dir(d: String) -> Vector2:
	match d:
		"r": return Vector2.RIGHT
		"l": return Vector2.LEFT
		"u": return Vector2.UP
	return Vector2.DOWN


func _draw_overlays(ci: CanvasItem, r: Dictionary) -> void:
	var id := str(r.id)
	var rc := _rect(r.x, r.y, r.w, r.h)
	# sello ganado: junto al jefe del reino
	if id in RunManager.seal_regions:
		var b: Dictionary = r.boss
		_seal(ci, _pt(b.x + 0.7, b.y + 0.6) + Vector2(0, 2), 8.0)
	# el heroe: punto parpadeante en su reino actual
	if id == _cur:
		var p := rc.get_center() + Vector2(0, 8)
		ci.draw_circle(p, 7.0, INK)
		ci.draw_circle(p, 5.5, Color("f2ead6") if _blink else GOLD)
		ci.draw_circle(p, 2.0, INK)


func _seal(ci: CanvasItem, c: Vector2, rad: float) -> void:
	ci.draw_circle(c, rad, Color.WHITE)
	ci.draw_circle(c, rad - 1.5, SEAL_RED)
	var pts := PackedVector2Array()
	for k in 10:
		var ang := -PI / 2 + k * PI / 5
		var rr := (rad - 3.0) * (1.0 if k % 2 == 0 else 0.45)
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	ci.draw_colored_polygon(pts, Color("ffe146"))


## Esquinas libres: leyenda arriba a la izquierda y contador de sellos arriba a la derecha.
func _draw_hud(ci: CanvasItem, rect: Rect2) -> void:
	var need := RunManager.seals_needed()
	var have := RunManager.seals()
	var txt := tr_("MAPA_SELLOS") % [have, need]
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var x := rect.end.x - w - 4
	_text(ci, txt, Vector2(x, rect.position.y + 16), -1, 16, GOLD if have >= need else HudStyle.CREAM)
	for i in need:
		var c := Vector2(x - 12 - (need - 1 - i) * 18.0, rect.position.y + 10)
		if i < have:
			_seal(ci, c, 7.0)
		else:
			ci.draw_arc(c, 6.5, 0, TAU, 14, GRAY, 2.0)
	# leyenda
	var lx := rect.position.x + 4
	var ly := rect.position.y + 6
	var items := [["hero", "MAPA_LEY_AQUI"], ["fija", "MAPA_LEY_FIJA"], ["choice", "MAPA_LEY_ELECCION"], ["lock", "MAPA_LEY_CANDADO"]]
	for i in items.size():
		var c := Vector2(lx + 8, ly + 8 + i * 20)
		match items[i][0]:
			"hero":
				ci.draw_circle(c, 6.0, INK)
				ci.draw_circle(c, 4.5, GOLD)
				ci.draw_circle(c, 1.6, INK)
			"fija":
				ci.draw_rect(Rect2(c - Vector2(7, 5), Vector2(14, 10)), FIXED)
				ci.draw_rect(Rect2(c - Vector2(7, 5), Vector2(14, 10)), INK, false, 1.0)
			"choice":
				ci.draw_rect(Rect2(c - Vector2(7, 5), Vector2(14, 10)), CHOICE)
				ci.draw_rect(Rect2(c - Vector2(7, 5), Vector2(14, 10)), INK, false, 1.0)
			"lock":
				_lock(ci, c + Vector2(0, -1), false, 1.0)
		_text(ci, tr_(items[i][1]), Vector2(lx + 22, ly + 14 + i * 20), -1, 16, Color(0.85, 0.82, 0.74))
