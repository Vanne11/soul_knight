class_name MapMetroid
extends CanvasLayer

## Mapa a pantalla completa estilo Metroid (tecla M / Select del mando). PAUSA el juego mientras
## esta abierto y lo restaura al cerrar. Al abrirse muestra el MUNDO completo ~1 s y la camara hace
## zoom y paneo al reino actual y luego al piso (cualquier tecla salta al final). Despues se navega:
## flechas/WASD/stick/arrastre = panear; rueda, +/-, gatillos = zoom mundo <-> reino <-> piso.
##
## El arte sale de assets/data/world_map.json (tools/gen_world_map.py, el mismo script que el SVG de
## diseno): reinos con su color, plantillas de salas con los iconos del SVG, puertas, candados,
## ascensor, tuneles y retratos de jefe (sprites reales, EnemyArt). El piso actual se dibuja con las
## salas REALES de la partida (generador de mazmorra), reveladas como el minimapa. Solo LEE estado.

const CELL := 50.0  # px de SVG por celda del JSON
const BG := Color("0c1430")
const GRID := Color("1a2850")
const INK := Color("0a0e22")
const PAPER := Color("e8eeff")
const GOLD := Color("ffd75a")
const FIXED := Color("ff961e")
const CHOICE := Color("ffe146")
const SEAL_RED := Color("c2323c")
const RAINBOW := ["ff5a5a", "ffaa3c", "ffe646", "64d26e", "50aaff", "a06ef0"]
const KINDS := ["inicio", "combate", "minijefe", "jefe", "tienda", "acertijo", "cofre", "descanso", "trampa", "lore", "secreta", "antro"]
const KIND_NAMES := {"inicio": "MAP_ROOM_START", "combate": "MAP_ROOM_COMBAT", "minijefe": "MAP_ROOM_MINIBOSS", "jefe": "MAP_ROOM_BOSS",
	"tienda": "MAP_ROOM_SHOP", "acertijo": "MAP_ROOM_PUZZLE", "cofre": "MAP_ROOM_TREASURE", "descanso": "MAP_ROOM_REST",
	"trampa": "MAP_ROOM_TRAP", "lore": "MAP_ROOM_LORE", "secreta": "MAP_ROOM_SECRET", "antro": "MAP_ROOM_INTOXICATION"}
const ROOM_KIND := {Room.RoomType.START: "inicio", Room.RoomType.COMBAT: "combate", Room.RoomType.MINIBOSS: "minijefe",
	Room.RoomType.BOSS: "jefe", Room.RoomType.SHOP: "tienda", Room.RoomType.PUZZLE: "acertijo", Room.RoomType.TREASURE: "cofre",
	Room.RoomType.REST: "descanso", Room.RoomType.TRAP: "trampa", Room.RoomType.LORE: "lore", Room.RoomType.SECRET: "secreta",
	Room.RoomType.INTOXICATION: "antro", Room.RoomType.SILENCIO: "lore"}
const FADE_IN := 0.35
const T_HOLD := 1.15   # el mundo completo antes de moverse
const T_A := 1.4       # mundo -> reino
const T_GAP := 0.3
const T_B := 1.3       # reino -> piso
const T_TOTAL := T_HOLD + T_A + T_GAP + T_B

static var _open: MapMetroid = null
static var _tex_cache: Dictionary = {}

@onready var _rm: Node = get_node("/root/RunManager")
var _wm := WorldMap.new()
var _d: Dictionary = {}
var _view: Control
var _vs := Vector2(1280, 720)
var _prev_paused := false
var _t := 0.0
var _intro := true
var _closing := false
var _legend := false  # arranca oculta: tapaba el titulo del reino al hacer zoom (L la muestra)
var _blink := true
var _pulse := 0.0

var _cam := Vector2.ZERO    # centro de la camara en px de mundo
var _zoom := 0.3
var _tcam := Vector2.ZERO   # objetivos (la camara los sigue suave)
var _tzoom := 0.3
var _z_w := 0.3
var _z_r := 1.2
var _z_p := 2.8
var _cam_w := Vector2.ZERO
var _cam_r := Vector2.ZERO
var _cam_p := Vector2.ZERO
var _floor_rect := Rect2()  # rect del piso real en px de mundo (centrado en su plantilla)
var _have_target := false
var _drag := false
var _btn_close := Rect2()
var _btn_zin := Rect2()
var _btn_zout := Rect2()
var _hero_color := Color("ff4646")
var _box := StyleBoxFlat.new()


## Abre el mapa (si no hay otro sistema que ya pause el juego). start_at: -1 = animacion de entrada,
## 0/1/2 = directo a mundo / reino / piso (capturas y pruebas).
static func open(host: Node, start_at := -1) -> MapMetroid:
	if _open != null and is_instance_valid(_open):
		return _open
	if host.get_tree().paused:
		return null
	var m := MapMetroid.new()
	m.set_meta("start_at", start_at)
	host.add_child(m)
	return m


static func is_open() -> bool:
	return _open != null and is_instance_valid(_open)


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_open = self
	_prev_paused = get_tree().paused
	get_tree().paused = true
	_d = WorldMap.data()
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_view.modulate.a = 0.0
	_view.draw.connect(_on_draw)
	add_child(_view)
	_vs = get_viewport().get_visible_rect().size
	_compute_targets()
	_cam = _cam_w
	_zoom = _z_w
	_tcam = _cam
	_tzoom = _zoom
	var sa := int(get_meta("start_at", -1))
	if sa >= 0:
		_intro = false
		_go(sa)
		_cam = _tcam
		_zoom = _tzoom
		_t = FADE_IN


func _exit_tree() -> void:
	if _open == self:
		_open = null


# ------------------------------------------------------------------ camara y objetivos

func _compute_targets() -> void:
	var rm := get_node_or_null("/root/RunManager")
	if rm == null or _d.is_empty():
		return
	_wm.refresh(rm)
	var g: Dictionary = _d.grid
	var wsz := Vector2(float(g.w), float(g.h)) * CELL
	_z_w = minf((_vs.x * 0.97) / wsz.x, (_vs.y - 76.0) / wsz.y)
	_cam_w = wsz * 0.5 + Vector2(0, -6)
	var r := WorldMap.region_data(_wm.cur)
	if r.is_empty():
		_cam_r = _cam_w
		_cam_p = _cam_w
		_z_r = _z_w
		_z_p = _z_w * 4.0
		return
	var rsz := Vector2(float(r.w), float(r.h)) * CELL
	_z_r = minf((_vs.x * 0.9) / rsz.x, (_vs.y - 120.0) / rsz.y)
	_cam_r = (Vector2(float(r.x), float(r.y)) * CELL) + rsz * 0.5
	var pc := _piso_center(r)
	_cam_p = pc
	var cw := float(_d.piso_cell.cw) * CELL
	_z_p = _vs.x * 0.42 / cw
	var fsz := Vector2(_vs.x * 0.86, _vs.y - 130.0) / _z_p
	_floor_rect = Rect2(pc - fsz * 0.5, fsz)
	_have_target = true


func _piso_idx(r: Dictionary) -> int:
	var st := 1
	if _rm.run_active or not RunManager.route_floors.is_empty():
		st = RunManager.floor_stage(_rm.current_floor)
	return clampi(st, 1, maxi(1, (r.piso_list as Array).size())) - 1


func _piso_center(r: Dictionary) -> Vector2:
	var pl: Array = r.piso_list
	if pl.is_empty():
		return (Vector2(float(r.x), float(r.y)) + Vector2(float(r.w), float(r.h)) * 0.5) * CELL
	var p: Dictionary = pl[_piso_idx(r)]
	return (Vector2(float(p.x), float(p.y)) + Vector2(float(_d.piso_cell.cw), float(_d.piso_cell.ch)) * 0.5) * CELL


## Salta a un nivel: 0 mundo, 1 reino, 2 piso.
func _go(level: int) -> void:
	match level:
		0:
			_tcam = _cam_w
			_tzoom = _z_w
		1:
			_tcam = _cam_r
			_tzoom = _z_r
		_:
			_tcam = _cam_p
			_tzoom = _z_p


func _level_now() -> int:
	if _tzoom < _z_r * 0.8:
		return 0
	if _tzoom < _z_p * 0.8:
		return 1
	return 2


func _ease(u: float) -> float:
	return u * u * (3.0 - 2.0 * u)


## Zoom hacia un punto sin que se "salga" de pantalla: la camara avanza segun la inversa del zoom.
func _blend(ca: Vector2, za: float, cb: Vector2, zb: float, u: float) -> void:
	u = _ease(clampf(u, 0.0, 1.0))
	var z := exp(lerpf(log(za), log(zb), u))
	var den := 1.0 / za - 1.0 / zb
	var f := u if absf(den) < 0.00001 else (1.0 / za - 1.0 / z) / den
	_zoom = z
	_cam = ca.lerp(cb, f)
	_tzoom = _zoom
	_tcam = _cam


func _skip_intro() -> void:
	_intro = false
	_go(2 if _have_target else 0)
	_cam = _tcam
	_zoom = _tzoom


# ------------------------------------------------------------------ cierre y entrada

func _close() -> void:
	if _closing:
		return
	_closing = true


func _finish_close() -> void:
	get_tree().paused = _prev_paused
	_open = null
	queue_free()


func _input(event: InputEvent) -> void:
	if _closing:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k == KEY_M or k == KEY_ESCAPE:
			_close()
		elif _intro:
			_skip_intro()
		elif k == KEY_L:
			_legend = not _legend
		elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
			_cycle_level()
		elif k == KEY_EQUAL or k == KEY_KP_ADD or k == KEY_PLUS:
			_zoom_by(1.35, _vs * 0.5)
		elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
			_zoom_by(1.0 / 1.35, _vs * 0.5)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		var b: int = event.button_index
		if b == JOY_BUTTON_B or b == JOY_BUTTON_BACK or b == JOY_BUTTON_START:
			_close()
		elif _intro:
			_skip_intro()
		elif b == JOY_BUTTON_Y:
			_legend = not _legend
		elif b == JOY_BUTTON_A:
			_cycle_level()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if _intro:
				_skip_intro()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom_by(1.25, mb.position)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_by(1.0 / 1.25, mb.position)
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				if _btn_close.has_point(mb.position):
					_close()
				elif _btn_zin.has_point(mb.position):
					_zoom_by(1.35, _vs * 0.5)
				elif _btn_zout.has_point(mb.position):
					_zoom_by(1.0 / 1.35, _vs * 0.5)
				else:
					_drag = true
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _drag and not _intro:
		_tcam -= (event as InputEventMouseMotion).relative / _zoom
		_cam = _tcam
		get_viewport().set_input_as_handled()


func _cycle_level() -> void:
	var l := _level_now()
	_go(0 if l >= 2 else l + 1)


func _zoom_by(f: float, at: Vector2) -> void:
	var nz := clampf(_tzoom * f, _z_w * 0.9, maxf(_z_p, _z_w))
	_tcam += (at - _vs * 0.5) * (1.0 / _tzoom - 1.0 / nz)
	_tzoom = nz
	_clamp_cam()


func _clamp_cam() -> void:
	var g: Dictionary = _d.get("grid", {"w": 56, "h": 40})
	var wsz := Vector2(float(g.w), float(g.h)) * CELL
	_tcam = _tcam.clamp(Vector2(-60, -60), wsz + Vector2(60, 60))


# ------------------------------------------------------------------ bucle

func _process(delta: float) -> void:
	_t += delta
	_blink = int(_t * 2.5) % 2 == 0
	_pulse = 0.5 + 0.5 * sin(_t * 3.0)
	if _closing:
		_view.modulate.a = move_toward(_view.modulate.a, 0.0, delta * 6.0)
		if _view.modulate.a <= 0.01:
			_finish_close()
		return
	_view.modulate.a = clampf(_t / FADE_IN, 0.0, 1.0)
	_vs = get_viewport().get_visible_rect().size
	if _intro:
		_run_intro()
	else:
		_poll_input(delta)
		var k := 1.0 - exp(-delta * 9.0)
		_zoom = exp(lerpf(log(_zoom), log(_tzoom), k))
		_cam = _cam.lerp(_tcam, k)
	_view.queue_redraw()


func _run_intro() -> void:
	if not _have_target:
		_intro = false
		return
	var t := _t
	if t < T_HOLD:
		_blend(_cam_w, _z_w, _cam_w, _z_w, 0.0)
	elif t < T_HOLD + T_A:
		_blend(_cam_w, _z_w, _cam_r, _z_r, (t - T_HOLD) / T_A)
	elif t < T_HOLD + T_A + T_GAP:
		_blend(_cam_r, _z_r, _cam_r, _z_r, 0.0)
	elif t < T_TOTAL:
		_blend(_cam_r, _z_r, _cam_p, _z_p, (t - T_HOLD - T_A - T_GAP) / T_B)
	else:
		_intro = false
		_go(2)
		_cam = _tcam
		_zoom = _tzoom


func _poll_input(delta: float) -> void:
	var mv := Vector2(
		Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
	if Input.is_physical_key_pressed(KEY_A):
		mv.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		mv.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		mv.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		mv.y += 1.0
	for pad in Input.get_connected_joypads():
		var s := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		if s.length() > 0.25:
			mv += s
		mv += Vector2(float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT)),
				float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP)))
		var zi := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT)
		var zo := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT)
		if zi > 0.3:
			_zoom_by(exp(delta * 1.6 * zi), _vs * 0.5)
		if zo > 0.3:
			_zoom_by(exp(-delta * 1.6 * zo), _vs * 0.5)
	if Input.is_physical_key_pressed(KEY_PAGEUP):
		_zoom_by(exp(delta * 1.6), _vs * 0.5)
	if Input.is_physical_key_pressed(KEY_PAGEDOWN):
		_zoom_by(exp(-delta * 1.6), _vs * 0.5)
	if mv != Vector2.ZERO:
		_tcam += mv.limit_length(1.0) * 520.0 / _zoom * delta
		_clamp_cam()


# ------------------------------------------------------------------ utilidades de dibujo

func _s(wp: Vector2) -> Vector2:
	return (wp - _cam) * _zoom + _vs * 0.5


func _sc(x: float, y: float) -> Vector2:  # celdas -> pantalla
	return _s(Vector2(x, y) * CELL)


func _rc(x: float, y: float, w: float, h: float) -> Rect2:  # celdas -> pantalla
	return Rect2(_sc(x, y), Vector2(w, h) * CELL * _zoom)


func _col(hex: String, a := 1.0) -> Color:
	return Color(Color(hex), a)


func _tx(s: String, pos: Vector2, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := true, bold := false) -> void:
	var f: Font = HudStyle.FONT_BOLD if bold else HudStyle.FONT
	if outline:
		_view.draw_string_outline(f, pos, s, align, width, size, maxi(2, size / 5), INK)
	_view.draw_string(f, pos, s, align, width, size, col)


func _tx_c(s: String, c: Vector2, size: int, col: Color, outline := true, bold := true) -> void:
	var f: Font = HudStyle.FONT_BOLD if bold else HudStyle.FONT
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_tx(s, c + Vector2(-w * 0.5, size * 0.36), size, col, HORIZONTAL_ALIGNMENT_LEFT, -1, outline, bold)


func _boxr(rc: Rect2, fill: Color, border: Color, bw: float, radius: float) -> void:
	_box.bg_color = fill
	_box.border_color = border
	_box.set_border_width_all(int(roundf(bw)))
	_box.set_corner_radius_all(int(roundf(radius)))
	_box.anti_aliasing = false
	_view.draw_style_box(_box, rc)


func _dashed_rect(rc: Rect2, col: Color, w: float, dash := 6.0) -> void:
	var a := rc.position
	var b := rc.position + Vector2(rc.size.x, 0)
	var c := rc.end
	var d := rc.position + Vector2(0, rc.size.y)
	for seg in [[a, b], [b, c], [c, d], [d, a]]:
		_view.draw_dashed_line(seg[0], seg[1], col, w, dash)


func _star(c: Vector2, r: float, col: Color, inner := 0.45) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var ang := -PI / 2.0 + k * PI / 5.0
		var rr := r * (1.0 if k % 2 == 0 else inner)
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	_view.draw_colored_polygon(pts, col)


func _seal(c: Vector2, rad: float) -> void:
	_view.draw_circle(c, rad, Color.WHITE)
	_view.draw_circle(c, rad - maxf(1.0, rad * 0.18), SEAL_RED)
	_star(c, rad * 0.65, Color("ffe146"))


func _alert(c: Vector2, s: float, tone := FIXED) -> void:
	var tri := PackedVector2Array([c + Vector2(0, -s), c + Vector2(-s, s * 0.8), c + Vector2(s, s * 0.8)])
	_view.draw_colored_polygon(tri, Color(tone, 0.55 + 0.4 * _pulse))
	_view.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), INK, 1.5)
	_view.draw_line(c + Vector2(0, -s * 0.4), c + Vector2(0, s * 0.2), INK, maxf(1.5, s * 0.2))


## Iconos de sala (los del SVG): s = medio lado; col = tinta; bg = color de la sala (para ojos, etc.).
func _icon(kind: String, c: Vector2, s: float, col: Color, bg: Color) -> void:
	var w := maxf(1.5, s * 0.28)
	match kind:
		"inicio":
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.6), c + Vector2(s * 0.65, 0), c + Vector2(-s * 0.5, s * 0.6)]), col)
		"combate":
			_view.draw_line(c + Vector2(-s * 0.6, -s * 0.6), c + Vector2(s * 0.6, s * 0.6), col, w)
			_view.draw_line(c + Vector2(s * 0.6, -s * 0.6), c + Vector2(-s * 0.6, s * 0.6), col, w)
		"minijefe":
			_view.draw_circle(c + Vector2(0, -s * 0.12), s * 0.62, col)
			_view.draw_rect(Rect2(c + Vector2(-s * 0.3, s * 0.3), Vector2(s * 0.6, s * 0.38)), col)
			_view.draw_circle(c + Vector2(-s * 0.24, -s * 0.12), s * 0.17, bg)
			_view.draw_circle(c + Vector2(s * 0.24, -s * 0.12), s * 0.17, bg)
		"jefe":
			_star(c, s * 0.8, col)
		"tienda":
			_tx_c("$", c, int(s * 1.7), col, false)
		"acertijo":
			_tx_c("?", c, int(s * 1.7), col, false)
		"trampa":
			_tx_c("!", c, int(s * 1.7), col, false)
		"cofre":
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.75), c + Vector2(s * 0.6, 0), c + Vector2(0, s * 0.75), c + Vector2(-s * 0.6, 0)]), col)
		"descanso":
			_view.draw_circle(c + Vector2(-s * 0.28, -s * 0.22), s * 0.36, col)
			_view.draw_circle(c + Vector2(s * 0.28, -s * 0.22), s * 0.36, col)
			_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.62, -s * 0.05), c + Vector2(s * 0.62, -s * 0.05), c + Vector2(0, s * 0.66)]), col)
		"lore":
			for i in 3:
				_view.draw_line(c + Vector2(-s * 0.55, (i - 1) * s * 0.42), c + Vector2(s * 0.55, (i - 1) * s * 0.42), col, w)
		"secreta":
			var pts := PackedVector2Array()
			for k in 8:
				var ang := -PI / 2.0 + k * PI / 4.0
				pts.append(c + Vector2(cos(ang), sin(ang)) * s * (0.8 if k % 2 == 0 else 0.25))
			_view.draw_colored_polygon(pts, col)
		"antro":
			var pts2 := PackedVector2Array()
			for i in 9:
				var u := i / 8.0
				pts2.append(c + Vector2(lerpf(-s * 0.65, s * 0.65, u), sin(u * TAU) * s * 0.3))
			_view.draw_polyline(pts2, col, w)
		"especial":
			_star(c, s * 0.85, col)


## Sala en el estilo del SVG: relleno del reino, borde claro (grueso en inicio/jefe), iconos en tinta.
func _room(rc: Rect2, kind: String, r: Dictionary, a := 1.0, guard := false, cleared_tint := 0.0) -> void:
	var sala := _col(str(r.sala), a)
	if cleared_tint > 0.0:
		sala = sala.lerp(Color("c85050", a), cleared_tint)
	var bw := maxf(1.0, 3.0 * _zoom)
	var bc := Color(PAPER, a)
	if kind == "minijefe":
		bc = Color(CHOICE, a)
		bw = maxf(1.0, 5.0 * _zoom)
	elif kind == "inicio" or kind == "jefe":
		bw = maxf(1.0, 6.0 * _zoom)
		bc = Color(Color.WHITE, a)
	bw = minf(bw, minf(rc.size.x, rc.size.y) * 0.1)
	var rad := minf(rc.size.x, rc.size.y) * 0.14
	_boxr(rc, sala, bc, bw, rad)
	if guard or kind == "secreta":
		_dashed_rect(rc, Color(INK, a * 0.8), maxf(1.0, 2.0 * _zoom), 4.0)
	var s := minf(rc.size.x, rc.size.y) * 0.36
	if s >= 2.6:
		_icon(kind, rc.get_center(), s, _col(str(r.ico), a), sala)


# ------------------------------------------------------------------ dibujo principal

func _on_draw() -> void:
	_view.draw_rect(Rect2(Vector2.ZERO, _vs), BG)
	if _d.is_empty():
		return
	var rm := get_node_or_null("/root/RunManager")
	if rm == null:
		return
	_wm.refresh(rm)
	var ch: String = _rm.character if _rm.character != "" else "pitocles"
	_hero_color = _col(str(_d.heroes.get(ch, "ff4646")))
	_draw_grid()
	_draw_tunnels()
	_draw_elevator()
	var fa := _floor_alpha()
	_draw_routes()
	for r in _d.regions:
		_draw_region(r, fa)
	_draw_routes(true)
	for r in _d.regions:
		_draw_boss(r)
	for r in _d.regions:
		_draw_title(r)
	for door in _d.doors:
		_draw_door(door)
	_draw_hero_marker(fa)
	if fa > 0.01:
		_draw_floor(fa)
	_draw_ui(fa)


func _floor_alpha() -> float:
	if not _have_target:
		return 0.0
	return smoothstep(_z_p * 0.62, _z_p * 0.92, _zoom)


func _draw_grid() -> void:
	var step := 60.0 * _zoom
	while step < 14.0:
		step *= 2.0
	var org := _s(Vector2.ZERO)
	var x0 := fmod(org.x, step)
	var y0 := fmod(org.y, step)
	if x0 < 0.0:
		x0 += step
	if y0 < 0.0:
		y0 += step
	var x := x0
	while x < _vs.x:
		_view.draw_line(Vector2(x, 0), Vector2(x, _vs.y), GRID, 1.0)
		x += step
	var y := y0
	while y < _vs.y:
		_view.draw_line(Vector2(0, y), Vector2(_vs.x, y), GRID, 1.0)
		y += step


func _draw_tunnels() -> void:
	for tn in _d.tunnels:
		var ring: bool = tn.kind == "anillo"
		for line in tn.lines:
			var pts := PackedVector2Array()
			for p in line:
				pts.append(_sc(p[0], p[1]))
			if ring:
				_view.draw_polyline(pts, Color("ffe9a0"), maxf(3.0, 34.0 * _zoom))
				_view.draw_polyline(pts, Color("3a2f6a"), maxf(1.5, 27.0 * _zoom))
			else:
				_view.draw_polyline(pts, PAPER, maxf(3.0, 40.0 * _zoom))
				_view.draw_polyline(pts, Color("2a3a70"), maxf(1.5, 33.0 * _zoom))


func _draw_elevator() -> void:
	var e: Dictionary = _d.elevator
	var rc := _rc(e.x, e.y, e.w, e.h)
	var lit := _wm.reached("utero")
	_boxr(rc, Color("0e4659", 0.8 if lit else 0.45), Color("78ebff", 0.95 if lit else 0.5), maxf(2.0, 4.0 * _zoom), 6.0 * _zoom)
	var n := 4
	for i in n:
		var y := rc.position.y + rc.size.y * (i + 0.5) / n
		var c := rc.get_center().x
		var s := maxf(3.0, 26.0 * _zoom)
		_view.draw_colored_polygon(PackedVector2Array([Vector2(c, y - s), Vector2(c - s, y + s * 0.6), Vector2(c + s, y + s * 0.6)]), Color("96f0ff", 0.8 if lit else 0.35))


func _draw_region(r: Dictionary, fa: float) -> void:
	var id := str(r.id)
	var rc := _rc(r.x, r.y, r.w, r.h)
	if rc.end.x < 0 or rc.end.y < 0 or rc.position.x > _vs.x or rc.position.y > _vs.y:
		return
	var voz := _wm.voz(r)
	var col := _col(str(r.color_lib if voz else r.color))
	var bw := maxf(2.0, 4.0 * _zoom)
	var rad := 22.0 * _zoom
	if _wm.is_missing(id):
		_boxr(rc, Color(col, 0.07), Color(col, 0.0), 0, rad)
		_dashed_rect(rc, Color(col, 0.7), bw)
		_tx_c("?", rc.get_center() + Vector2(0, 8), int(clampf(70.0 * _zoom, 24, 160)), Color(col, 0.8))
		_rainbow(r, rc)
		return
	var vis := _wm.visited(id)
	var libd := id in _wm.lib or voz
	if libd:
		_boxr(rc, Color(col, 0.42), col, bw, rad)
	elif vis:
		_boxr(rc, Color(col, 0.2), col, bw, rad)
	else:
		var gray := Color(0.42, 0.42, 0.5)
		var tomado := _wm.is_taken(id)  # plan 6: lo tomo la copia de seguridad del Algoritmo: tono rojo + alerta
		if tomado:
			gray = Color(0.8, 0.2, 0.26)
		_boxr(rc, Color(gray, 0.3 if tomado else 0.16), Color(gray, 0.0), 0, rad)
		_dashed_rect(rc, Color(gray, 0.9 if tomado else 0.8), bw, 8.0)
		if id in _wm.opts:
			_boxr(rc.grow(3), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.25 + 0.5 * _pulse), 2, rad)
		if tomado:
			_alert(Vector2(rc.end.x - 24.0 * _zoom - 8, rc.position.y + 22.0 * _zoom + 8), clampf(30.0 * _zoom, 10, 28), SEAL_RED)
		elif _wm.is_disorder(id):
			_alert(Vector2(rc.end.x - 24.0 * _zoom - 8, rc.position.y + 22.0 * _zoom + 8), clampf(24.0 * _zoom, 8, 22))
		var big := int(clampf(110.0 * _zoom, 28, 200))
		_tx_c("?", rc.position + Vector2(rc.size.x * 0.34, rc.size.y * 0.58), big, Color(gray, 0.75))
		_rainbow(r, rc)
		return
	# visitado / liberado: TUS salas en los pisos que recorriste (RunManager.floor_maps), el piso actual
	# en vivo y silueta "?" en los que no pisaste. Un reino liberado en otra partida, sin foto en esta,
	# muestra la plantilla del SVG.
	var cur_piso := _piso_idx(r) if id == _wm.cur else -1
	var pl: Array = r.piso_list
	for i in pl.size():
		var p: Dictionary = pl[i]
		var key := "%s:%d" % [id, int(p.n)]
		var done := i < cur_piso or (id != _wm.cur and _wm.boss_defeated(id))
		if i == cur_piso:
			var host := get_tree().get_first_node_in_group("main")
			if host != null and host.dungeon_generator != null and not host.dungeon_generator.rooms.is_empty():
				_draw_snap(r, p, snapshot(host), 1.0 - fa, false)
		elif _rm.floor_maps.has(key):
			_draw_snap(r, p, _rm.floor_maps[key], 1.0, done)
		elif libd:
			_draw_cluster(r, p, 1.0, done)
		else:
			_draw_unknown_piso(p)
	if r.has("stairs"):
		_stairs(r.stairs)
	if r.has("hill"):
		_hill(r)
	_rainbow(r, rc)
	if r.has("color_lib"):
		_silencio_icon(rc, voz)


func _rainbow(r: Dictionary, rc: Rect2) -> void:
	if not r.rainbow:
		return
	var w := (rc.size.x - 4.0) / RAINBOW.size()
	for i in RAINBOW.size():
		_view.draw_rect(Rect2(rc.position + Vector2(2 + i * w, 2), Vector2(w, maxf(2.0, 5.0 * _zoom))), Color(RAINBOW[i]))


func _draw_cluster(r: Dictionary, p: Dictionary, a: float, done: bool) -> void:
	if a <= 0.01:
		return
	var pc: Dictionary = _d.piso_cell
	var tpl: Array = _d.templates[p.t]
	var unit := float(pc.unit)
	var pitch := float(pc.pitch)
	var aa := a * (0.8 if done else 1.0)
	var org := Vector2(float(p.x), float(p.y))
	var types := {}
	for t in tpl:
		types[Vector2i(int(t[0]), int(t[1]))] = str(t[2])
	var lw := maxf(1.5, 10.0 * _zoom)
	for k in types:
		var c := Vector2(k) * pitch + Vector2(unit, unit) * 0.5
		for nb in [Vector2i(1, 0), Vector2i(0, 1)]:
			if types.has(k + nb):
				_view.draw_line(_sc(org.x + c.x, org.y + c.y), _sc(org.x + c.x + nb.x * pitch, org.y + c.y + nb.y * pitch), Color(PAPER, aa), lw)
	for k in types:
		var kind: String = types[k]
		if kind == "calma":
			kind = str(p.calm)
		var rc := _rc(org.x + k.x * pitch, org.y + k.y * pitch, unit, unit)
		_room(rc, kind, r, aa, kind == "jefe" and bool(p.guard))
	# etiqueta "Piso N"
	if _zoom > 0.9:
		var lp := _sc(org.x, org.y - 0.2)
		_tx(tr("MM_PISO") % int(p.n), lp, int(clampf(22.0 * _zoom, 12, 30)), Color(1, 1, 1, aa), HORIZONTAL_ALIGNMENT_LEFT, -1, true, false)


## Bajada al piso siguiente: una ficha con una escalera de perfil que baja hacia la derecha y una
## flecha (antes eran 4 barras crecientes y parecía la señal del teléfono).
func _stairs(st: Dictionary) -> void:
	var c := _sc(st.x, st.y + 0.0) + Vector2(0, 6) * _zoom
	var s := 44.0 * _zoom
	var box := Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s))
	_boxr(box, FIXED, Color.WHITE, maxf(1.0, 3.0 * _zoom), 8.0 * _zoom)
	var n := 4
	var w := s * 0.64 / n
	var o := box.position + Vector2(s * 0.18, s * 0.82)  # pie de la escalera (abajo a la izquierda)
	var pts := PackedVector2Array([o])
	for k in n:  # peldaños que suben hacia la derecha
		pts.append(o + Vector2(w * k, -w * (k + 1)))
		pts.append(o + Vector2(w * (k + 1), -w * (k + 1)))
	pts.append(o + Vector2(w * n, 0))
	_view.draw_colored_polygon(pts, INK)
	var lw := maxf(1.0, 2.0 * _zoom)
	for k in n:  # canto blanco de cada peldaño
		_view.draw_line(o + Vector2(w * k, -w * (k + 1)), o + Vector2(w * (k + 1), -w * (k + 1)), Color.WHITE, lw)
	var ax := box.position.x + s * 0.27  # flecha "bajar" en el hueco de arriba a la izquierda
	var top := box.position.y + s * 0.16
	var bot := box.position.y + s * 0.5
	_view.draw_line(Vector2(ax, top), Vector2(ax, bot - s * 0.06), INK, maxf(1.5, 3.0 * _zoom))
	_view.draw_colored_polygon(PackedVector2Array([Vector2(ax - s * 0.1, bot - s * 0.1), Vector2(ax + s * 0.1, bot - s * 0.1), Vector2(ax, bot + s * 0.02)]), INK)


func _hill(r: Dictionary) -> void:
	var h: Dictionary = r.hill
	var base_y := float(h.y) + float(h.h)
	for i in 3:
		var rc := _rc(float(h.x) + i * 0.76, base_y - (i + 1) * 0.84, 0.72, (i + 1) * 0.84)
		_boxr(rc, Color("ffe9a0"), Color.WHITE, maxf(1.0, 3.0 * _zoom), 5.0 * _zoom)
	_star(_sc(float(h.x) + 1.9, base_y - 2.52 - 0.36), maxf(4.0, 20.0 * _zoom), CHOICE)


## Icono del reino del Silencio: ventana cerrada (estado "silencio") o faro encendido con una vela pequena.
func _silencio_icon(rc: Rect2, voz: bool) -> void:
	var u := clampf(_zoom, 0.3, 3.0)
	var c := Vector2(rc.end.x - 26.0 * _zoom - 6, rc.position.y + 34.0 * _zoom + 6)
	var k := u * 1.2
	if not voz:
		_view.draw_rect(Rect2(c + Vector2(-9, -11) * k, Vector2(18, 22) * k), INK)
		_view.draw_rect(Rect2(c + Vector2(-7, -9) * k, Vector2(14, 18) * k), Color(0.32, 0.32, 0.4))
		_view.draw_line(c + Vector2(0, -9) * k, c + Vector2(0, 9) * k, INK, 2.0)
		_view.draw_line(c + Vector2(-7, 0) * k, c + Vector2(7, 0) * k, INK, 1.5)
		return
	var warm := Color("ffd98a")
	_view.draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 11) * k, c + Vector2(5, 11) * k, c + Vector2(2, -4) * k, c + Vector2(-2, -4) * k]), Color(0.94, 0.9, 0.82))
	_view.draw_rect(Rect2(c + Vector2(-4, -10) * k, Vector2(8, 6) * k), warm)
	_view.draw_circle(c + Vector2(0, -7) * k, 8.0 * k, Color(warm, 0.22 + 0.12 * _pulse))
	var v := c + Vector2(0, 24) * k
	_view.draw_rect(Rect2(v + Vector2(-2, -3) * k, Vector2(4, 7) * k), Color(0.94, 0.9, 0.82))
	_view.draw_circle(v + Vector2(0, -5) * k, 2.2 * k, warm)


# ------------------------------------------------------------------ jefes, titulos, puertas, ruta

func _boss_tex(variant: String) -> Texture2D:
	if variant == "":
		return null
	if _tex_cache.has(variant):
		return _tex_cache[variant]
	var t: Texture2D = null
	var path := EnemyArt.frames(variant)
	if ResourceLoader.exists(path):
		var sf := load(path) as SpriteFrames
		if sf != null:
			var an := "idle"
			if not sf.has_animation(an):
				var names := sf.get_animation_names()
				an = String(names[0]) if names.size() > 0 else ""
			if an != "" and sf.get_frame_count(an) > 0:
				t = sf.get_frame_texture(an, 0)
	if t == null:
		var f := EnemyArt.file(variant, variant + "_idle_00.png")
		if ResourceLoader.exists(f):
			t = load(f)
	_tex_cache[variant] = t
	return t


func _hero_tex(hero: String) -> Texture2D:
	var key := "hero:" + hero
	if not _tex_cache.has(key):
		var p := "res://assets/sprites/player/%s/idle_00.png" % hero
		_tex_cache[key] = load(p) if ResourceLoader.exists(p) else null
	return _tex_cache[key]


func _draw_boss(r: Dictionary) -> void:
	var id := str(r.id)
	var b: Dictionary = r.boss
	var rc := _rc(b.x, b.y, b.w, b.h)
	if rc.end.x < 0 or rc.end.y < 0 or rc.position.x > _vs.x or rc.position.y > _vs.y:
		return
	var col := _col(str(r.color))
	var vis := _wm.visited(id)
	var libd := id in _wm.lib or _wm.voz(r)
	var missing := _wm.is_missing(id)
	var tomado := _wm.is_taken(id)  # plan 6: el retrato es el del jefe que lo tomo
	var defeated := _wm.boss_defeated(id) and not tomado
	var bw := maxf(2.0, 4.0 * _zoom)
	var frame := Color.WHITE
	if tomado:
		frame = SEAL_RED
	elif defeated:
		frame = Color("78d28c")
	elif not vis and not libd:
		frame = Color(0.6, 0.6, 0.72)
	_boxr(rc, Color(INK, 0.6), frame, bw, 14.0 * _zoom)
	var tex := _boss_tex(str(_wm.taken[id].variant) if tomado else str(r.boss_variant))
	var known := (vis or libd or tomado) and not missing
	if tex != null:
		var inner := rc.grow(-rc.size.x * 0.1)
		var sz := tex.get_size()
		var sc := minf(inner.size.x / sz.x, inner.size.y / sz.y)
		var ds := sz * sc
		var tr_rect := Rect2(inner.get_center() - ds * 0.5, ds)
		var mod := Color.WHITE
		if not known:
			mod = Color(0.02, 0.03, 0.08, 0.95)  # silueta
		elif defeated:
			mod = Color(0.55, 0.6, 0.6, 0.85)
		_view.draw_texture_rect(tex, tr_rect, false, mod)
	else:
		_pend_figure(rc, known)
	if not known:
		_tx_c("?", rc.get_center() + Vector2(0, rc.size.y * 0.02), int(clampf(rc.size.y * 0.55, 14, 120)), Color(0.86, 0.86, 0.95, 0.9))
	elif defeated:
		var cc := rc.get_center()
		var q := minf(rc.size.x, rc.size.y) * 0.34
		var w := maxf(2.0, 7.0 * _zoom)
		_view.draw_line(cc + Vector2(-q, -q), cc + Vector2(q, q), Color(SEAL_RED, 0.9), w)
		_view.draw_line(cc + Vector2(q, -q), cc + Vector2(-q, q), Color(SEAL_RED, 0.9), w)
	# sello: ganado (lleno) o por ganar (anillo)
	if bool(r.boss_seal) and not missing:
		var sc2 := rc.position + Vector2(22.0, 22.0) * _zoom + Vector2(2, 2)
		var rad := maxf(6.0, 17.0 * _zoom)
		if id in RunManager.seal_regions:
			_seal(sc2, rad)
		elif vis:
			_view.draw_arc(sc2, rad - 1.0, 0, TAU, 16, Color(0.66, 0.66, 0.74), 2.0)
	# nombre del jefe (solo si se acerca la camara o ya lo conoces)
	if _zoom > 0.75 and not missing:
		var name_s := tr(str(r.boss_name_key)) if known else "?"
		if name_s == str(r.boss_name_key):
			name_s = str(r.boss_name)
		if tomado:
			name_s = Loc.enemy_name(str(_wm.taken[id].name))
		if bool(r.boss_pend) and known:
			name_s += " · " + tr("MM_POR_DISENAR")
		var fs := int(clampf(18.0 * _zoom, 11, 22))
		var f: Font = HudStyle.FONT_BOLD
		var w := f.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0
		var reg := _rc(r.x, r.y, r.w, r.h)
		var px := clampf(rc.get_center().x - w * 0.5, reg.position.x + 4.0, maxf(reg.position.x + 4.0, reg.end.x - w - 4.0))
		var pr := Rect2(Vector2(px, rc.end.y - 2.0), Vector2(w, fs + 10.0))
		_boxr(pr, INK, PAPER, 2, 8.0)
		_tx(name_s, pr.position + Vector2(8, fs + 3), fs, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, false, true)


func _pend_figure(rc: Rect2, known: bool) -> void:
	var c := rc.get_center()
	var k := rc.size.y / 120.0
	var col := Color(0.58, 0.6, 0.66, 0.9) if known else Color(0.02, 0.03, 0.08, 0.95)
	_view.draw_circle(c + Vector2(0, -22) * k, 16.0 * k, col)
	_boxr(Rect2(c + Vector2(-24, -4) * k, Vector2(48, 44) * k), col, Color(0, 0, 0, 0), 0, 11.0 * k)


func _draw_title(r: Dictionary) -> void:
	var id := str(r.id)
	var rc := _rc(r.x, r.y, r.w, r.h)
	if rc.end.x < 0 or rc.end.y < 0 or rc.position.x > _vs.x or rc.position.y > _vs.y:
		return
	var voz := _wm.voz(r)
	var col := _col(str(r.color))
	var fs := int(clampf(28.0 * _zoom, 12, 40))
	var pos := rc.position + Vector2(maxf(5.0, 24.0 * _zoom) + float(r.get("label_dx", 0.0)) * CELL * _zoom, maxf(fs + 3.0, 38.0 * _zoom))
	var txt := WorldMap.region_label(r, voz)
	var c := Color.WHITE
	if _wm.is_missing(id):
		c = Color(col, 0.8)
	elif _wm.is_taken(id):
		c = Color("ff7a7a")
	elif _wm.visited(id) or id in _wm.lib or voz:
		c = Color.WHITE
	elif _wm.is_disorder(id) or id in _wm.opts:
		c = Color(0.82, 0.82, 0.9)
	else:
		txt = "???"
		c = Color(0.62, 0.62, 0.72)
	_tx(txt, pos, fs, c, HORIZONTAL_ALIGNMENT_LEFT, -1, true, true)
	if _wm.is_taken(id) and _zoom > 0.4:
		var wt := HudStyle.FONT_BOLD.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_tx(tr("P6_MM_TOMADO"), pos + Vector2(wt + 10, 0), maxi(10, fs / 2), Color("ff5a5a"), HORIZONTAL_ALIGNMENT_LEFT, -1, true, false)
	if id in _wm.lib and not _wm.is_missing(id) and _zoom > 0.4:
		var w := HudStyle.FONT_BOLD.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_tx(tr("MM_LIBERADO"), pos + Vector2(w + 10, 0), maxi(10, fs / 2), Color("78d28c"), HORIZONTAL_ALIGNMENT_LEFT, -1, true, false)


func _dir_angle(d: String) -> float:
	match d:
		"r": return 0.0
		"d": return PI * 0.5
		"l": return PI
	return PI * 1.5


func _draw_door(door: Dictionary) -> void:
	var st := _wm.door_state(door)
	var base: Color = FIXED if door.kind == "fija" else CHOICE
	var a := 0.45
	if st == "used":
		a = 1.0
	elif st == "possible":
		a = 0.55 + 0.45 * _pulse
	var c := _sc(door.x, door.y)
	var z := _zoom
	if c.x < -80 or c.y < -80 or c.x > _vs.x + 80 or c.y > _vs.y + 80:
		return
	var ang := _dir_angle(str(door.dir))
	_view.draw_set_transform(c, ang, Vector2(z, z))
	var bc := Color.WHITE if st == "used" else Color(INK, 0.9)
	var bwid := 3.0 if st == "used" else 2.0
	if door.kind == "fija":
		_view.draw_rect(Rect2(-30, -19, 60, 38), Color(base, a))
		_view.draw_rect(Rect2(-30, -19, 60, 38), bc, false, bwid)
		_view.draw_colored_polygon(PackedVector2Array([Vector2(4, -11), Vector2(20, 0), Vector2(4, 11)]), Color(INK, 0.9))
		_view.draw_rect(Rect2(-24, -3, 14, 11), Color(INK, 0.9))
		_view.draw_arc(Vector2(-17, -3), 4.0, PI, TAU, 8, Color(INK, 0.9), 3.0)
	else:
		_view.draw_rect(Rect2(-30, -19, 60, 38), Color(base, a))
		_view.draw_rect(Rect2(-30, -19, 60, 38), bc, false, bwid)
		var ink := Color(INK, 0.95)
		_view.draw_line(Vector2(-20, 0), Vector2(-2, 0), ink, 5.0)
		_view.draw_line(Vector2(-2, 0), Vector2(12, -10), ink, 5.0)
		_view.draw_line(Vector2(-2, 0), Vector2(12, 10), ink, 5.0)
		_view.draw_colored_polygon(PackedVector2Array([Vector2(12, -15), Vector2(22, -10), Vector2(14, -3)]), ink)
		_view.draw_colored_polygon(PackedVector2Array([Vector2(12, 15), Vector2(22, 10), Vector2(14, 3)]), ink)
	_view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if int(door.seals) > 0:
		var open := RunManager.seals() >= RunManager.seals_needed()
		var off := Vector2(0, 40) * z
		_lock_tag(c + off, open, 0.6 + 0.4 * (1.0 if st != "idle" else 0.5), "2×")


func _lock_tag(c: Vector2, open: bool, a: float, txt: String) -> void:
	var fs := int(clampf(20.0 * _zoom, 10, 22))
	var w := HudStyle.FONT_BOLD.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var body := Color("5fe08a") if open else FIXED
	var k := maxf(0.8, fs / 16.0)
	var rc := Rect2(c + Vector2(-(w + 22 * k) * 0.5, -9 * k), Vector2(w + 22 * k, 18 * k))
	_boxr(rc, Color(INK, 0.9 * a), Color(PAPER, a), 1, 4)
	var lc := rc.position + Vector2(8 * k, 9 * k)
	_view.draw_arc(lc + Vector2(0, -2 * k), 3.0 * k, PI, TAU * (1.0 if not open else 0.92), 8, Color(0.95, 0.95, 1, a), maxf(1.0, k))
	_view.draw_rect(Rect2(lc + Vector2(-4 * k, -2 * k), Vector2(8 * k, 6 * k)), Color(body, a))
	_tx(txt, rc.position + Vector2(16 * k, 13 * k), fs, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_LEFT, -1, false, true)


func _draw_routes(over := false) -> void:
	var ra := 0.35 if over else 0.95
	# tramos del eje (ascensor -> Utero -> Prostata -> Silencio -> Palacio) en el color del heroe
	var ejes: Array = _d.get("eje_routes", [])
	var need := ["utero", "utero", "prostata", "silencio"]
	var need2 := ["utero", "prostata", "silencio", "palacio"]
	for i in mini(ejes.size(), 4):
		if _wm.reached(need2[i]) and _wm.reached(need[i]):
			var pts := PackedVector2Array()
			for p in ejes[i]:
				pts.append(_sc(p[0], p[1]))
			_view.draw_polyline(pts, INK, maxf(4.0, 12.0 * _zoom))
			_view.draw_polyline(pts, _hero_color, maxf(2.5, 7.0 * _zoom))
	# recorrido del heroe: del jefe de cada reino al del siguiente (codo vertical-horizontal), bajo los retratos
	var rr: Array = _wm.route
	var anchors: Array = []
	for id in rr:
		var r := WorldMap.region_data(str(id))
		if r.is_empty():
			continue
		var b: Dictionary = r.boss
		anchors.append(Vector2(float(b.x) + float(b.w) * 0.5, float(b.y) + float(b.h) * 0.5))
	if anchors.size() >= 2:
		var pts2 := PackedVector2Array()
		for i in anchors.size():
			var a: Vector2 = anchors[i]
			if i > 0:
				var p0: Vector2 = anchors[i - 1]
				pts2.append(_sc(p0.x, a.y))
			pts2.append(_sc(a.x, a.y))
		if not over:
			_view.draw_polyline(pts2, Color(INK, 0.6), maxf(3.0, 8.0 * _zoom))
		for i in pts2.size() - 1:
			_view.draw_dashed_line(pts2[i], pts2[i + 1], Color(_hero_color, ra), maxf(2.0, 4.5 * _zoom), maxf(6.0, 16.0 * _zoom))
	# bandera de inicio del heroe
	for s in _d.starts:
		if str(s.hero) != _rm.character:
			continue
		var c := _sc(float(s.x), float(s.y))
		var t := _hero_tex(str(s.hero))
		var k := maxf(0.6, 2.0 * _zoom)
		if t != null:
			var sz := t.get_size() * k
			_view.draw_texture_rect(t, Rect2(c - Vector2(sz.x * 0.5, sz.y * 0.8), sz), false)
		var fx := c.x + 22.0 * k
		_view.draw_line(Vector2(fx, c.y - 40 * k), Vector2(fx, c.y + 10 * k), Color.WHITE, maxf(1.5, 4.0 * _zoom))
		_view.draw_colored_polygon(PackedVector2Array([Vector2(fx, c.y - 40 * k), Vector2(fx + 28 * k, c.y - 30 * k), Vector2(fx, c.y - 20 * k)]), Color("eb2828"))


## En un pasillo entre reinos: la ficha sale del jefe del reino de origen, hacia el destino (sobre el mapa del mundo).
func _corridor_marker(main: Node) -> Vector2:
	var c: Dictionary = main._corridor
	var ra := WorldMap.region_data(str(c.get("from", "")))
	var rb := WorldMap.region_data(str(c.get("to", "")))
	if ra.is_empty() or rb.is_empty():
		return _piso_center(WorldMap.region_data(_wm.cur))
	var ca := _piso_center(ra)
	var cb := _piso_center(rb)
	var pa := _s(ca)
	var pb := _s(cb)
	var col := Color("ffc93c")
	_view.draw_line(pa, pb, INK, maxf(4.0, 10.0 * _zoom))
	_view.draw_dashed_line(pa, pb, col, maxf(2.5, 5.0 * _zoom), maxf(6.0, 14.0 * _zoom))
	return ca.lerp(cb, main.corridor_progress())


func _draw_hero_marker(fa: float) -> void:
	var main := get_tree().get_first_node_in_group("main")
	var transit: bool = main != null and main.get("corridor_active") == true
	if (fa > 0.6 and not transit) or not _have_target:
		return
	var p := _s(_piso_center(WorldMap.region_data(_wm.cur)))
	if transit:
		p = _s(_corridor_marker(main))
	var rad := clampf(26.0 * _zoom, 8, 30)
	_view.draw_circle(p, rad * (1.0 + 0.3 * _pulse), Color(GOLD, 0.25))
	_view.draw_circle(p, rad * 0.5 + 2.0, INK)
	_view.draw_circle(p, rad * 0.5, Color("f2ead6") if _blink else GOLD)
	_view.draw_circle(p, rad * 0.2, INK)


# ------------------------------------------------------------------ piso real

static func _kind_of(room: Room) -> String:
	if MonteVenus.is_monte(room):
		return "especial"
	return str(ROOM_KIND.get(room.room_type, "combate"))


## Clave "<reino>:<etapa>" de un piso: la de RunManager.floor_maps y la de piso_list[].n del mapa.
static func floor_key(floor_n: int) -> String:
	return "%s:%d" % [RunManager.floor_region(floor_n), RunManager.floor_stage(floor_n)]


## Foto compacta del piso actual de main: las salas que conoces (pisadas y sus vecinas) con su tipo y
## si las pisaste, y los pasillos que ya recorriste. Celdas del generador. La guarda main al bajar de piso.
static func snapshot(host: Node) -> Dictionary:
	var gen: DungeonGenerator = host.dungeon_generator
	var visited: Dictionary = host.visited_rooms
	var known := {}
	for pos in visited:
		known[pos] = true
		for n in gen.room_graph.get(pos, []):
			known[n] = true
	var rooms := []
	var idx := {}
	for pos in known:
		if not gen.rooms.has(pos):
			continue
		var sz: Vector2i = gen.room_sizes.get(pos, Vector2i(8, 6))
		idx[pos] = rooms.size()
		rooms.append([pos.x, pos.y, sz.x, sz.y, _kind_of(gen.rooms[pos]), visited.has(pos)])
	var edges := []
	for pos in idx:
		for n in gen.room_graph.get(pos, []):
			if idx.has(n) and (visited.has(pos) or visited.has(n)) and (pos as Vector2i) < (n as Vector2i):
				edges.append([idx[pos], idx[n]])
	return {"rooms": rooms, "edges": edges}


## Un piso con TUS salas (foto de snapshot) encajado en la celda del piso del SVG.
func _draw_snap(r: Dictionary, p: Dictionary, snap: Dictionary, a: float, done: bool) -> void:
	var rooms: Array = snap.get("rooms", [])
	if a <= 0.01 or rooms.is_empty():
		return
	var pc: Dictionary = _d.piso_cell
	var box := _rc(float(p.x), float(p.y), float(pc.cw), float(pc.ch))
	var b := Rect2()
	for i in rooms.size():
		var q: Array = rooms[i]
		var rr := Rect2(float(q[0]), float(q[1]), float(q[2]), float(q[3]))
		b = rr if i == 0 else b.merge(rr)
	var k := minf(box.size.x / maxf(b.size.x, 1.0), box.size.y / maxf(b.size.y, 1.0))
	var org := box.position + (box.size - b.size * k) * 0.5 - b.position * k
	var aa := a * (0.8 if done else 1.0)
	var rect_of := func(q: Array) -> Rect2:
		return Rect2(org + Vector2(float(q[0]), float(q[1])) * k, Vector2(float(q[2]), float(q[3])) * k).grow(-k * 0.6)
	var lw := maxf(1.0, k * 0.5)
	for e in snap.get("edges", []):
		_view.draw_line(rect_of.call(rooms[e[0]]).get_center(), rect_of.call(rooms[e[1]]).get_center(), Color(PAPER, aa), lw)
	for q in rooms:
		var rc: Rect2 = rect_of.call(q)
		if bool(q[5]) or str(q[4]) in ["tienda", "jefe"]:
			_room_big(rc, str(q[4]), r, aa, 0.0, false, false)
		else:
			_dashed_rect(rc, Color(0.7, 0.7, 0.8, 0.7 * aa), maxf(1.0, 1.5 * _zoom), 4.0)
	if _zoom > 0.9:
		_tx(tr("MM_PISO") % int(p.n), _sc(float(p.x), float(p.y) - 0.2), int(clampf(22.0 * _zoom, 12, 30)), Color(1, 1, 1, aa), HORIZONTAL_ALIGNMENT_LEFT, -1, true, false)


## Piso que no pisaste en esta partida: silueta con "?" (el mapa se llena explorando, como en Metroid).
func _draw_unknown_piso(p: Dictionary) -> void:
	var pc: Dictionary = _d.piso_cell
	var box := _rc(float(p.x), float(p.y), float(pc.cw), float(pc.ch))
	var gray := Color(0.7, 0.7, 0.8)
	_boxr(box, Color(gray, 0.06), Color(gray, 0.0), 0, 8.0 * _zoom)
	_dashed_rect(box, Color(gray, 0.55), maxf(1.0, 2.0 * _zoom), 8.0)
	_tx_c("?", box.get_center() + Vector2(0, 6.0 * _zoom), int(clampf(60.0 * _zoom, 12, 90)), Color(gray, 0.7))
	if _zoom > 0.9:
		_tx(tr("MM_PISO") % int(p.n), _sc(float(p.x), float(p.y) - 0.2), int(clampf(22.0 * _zoom, 12, 30)), Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, true, false)


func _draw_floor(fa: float) -> void:
	var r := WorldMap.region_data(_wm.cur)
	if r.is_empty():
		return
	_view.draw_rect(Rect2(Vector2.ZERO, _vs), Color(INK, 0.82 * fa))  # apaga el mundo alrededor del piso
	var tl := _s(_floor_rect.position)
	var panel := Rect2(tl, _floor_rect.size * _zoom)
	var col := _col(str(r.color_lib if _wm.voz(r) else r.color))
	_boxr(panel, Color(INK, 0.97 * fa), Color(col, fa), maxf(2.0, 4.0 * _zoom), 18.0 * _zoom)
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.get("corridor_active") == true:
		var cc: Dictionary = main._corridor
		_tx_c("%s  >>>  %s" % [Loc.region_name_id(str(cc.get("from", ""))), Loc.region_name_id(str(cc.get("to", "")))], panel.get_center() + Vector2(0, -14), 22, Color(1, 1, 1, fa), true, true)
		_tx_c(tr("PAS_TRANSIT"), panel.get_center() + Vector2(0, 18), 16, Color(GOLD, fa), true, false)
		return
	if main == null or main.dungeon_generator == null or main.dungeon_generator.rooms.is_empty():
		_tx_c(tr("MM_SIN_PISO"), panel.get_center(), 16, Color(1, 1, 1, fa), false, false)
		return
	if FloorEvents.hide_map():
		_tx_c(tr("MAP_CENSORED"), panel.get_center(), 20, Color("d8d8e6", fa), false, true)
		return
	var gen: DungeonGenerator = main.dungeon_generator
	var visited: Dictionary = main.visited_rooms
	var current: Room = main.current_room
	var known := {}
	for pos in visited:
		known[pos] = true
		for n in gen.room_graph.get(pos, []):
			known[n] = true
	var revealed: bool = main.has_meta("map_revealed_floor") and main.get_meta("map_revealed_floor") == _rm.current_floor
	if revealed:
		for pos in gen.rooms:
			known[pos] = true
	var bounds := Rect2i()
	var first := true
	for pos in gen.rooms:
		var rr := Rect2i(pos, gen.room_sizes.get(pos, Vector2i(8, 6)))
		bounds = rr if first else bounds.merge(rr)
		first = false
	var inner := panel.grow(-maxf(14.0, panel.size.y * 0.06))
	inner.position.y += 4
	var k: float = minf(inner.size.x / bounds.size.x, inner.size.y / bounds.size.y)
	var origin := inner.position + (inner.size - Vector2(bounds.size) * k) * 0.5 - Vector2(bounds.position) * k
	var rect_of := func(pos: Vector2i) -> Rect2:
		var sz: Vector2i = gen.room_sizes.get(pos, Vector2i(8, 6))
		return Rect2(origin + Vector2(pos) * k, Vector2(sz) * k).grow(-k * 0.35)
	var lw := clampf(k * 0.5, 3.0, 12.0)
	for pos in known:
		for n in gen.room_graph.get(pos, []):
			if known.has(n) and (visited.has(pos) or visited.has(n)) and (pos as Vector2i) < (n as Vector2i):
				_view.draw_line(rect_of.call(pos).get_center(), rect_of.call(n).get_center(), Color(PAPER, 0.8 * fa), lw)
	for pos in known:
		var room: Room = gen.rooms[pos]
		var rc: Rect2 = rect_of.call(pos)
		var kind := _kind_of(room)
		var seen: bool = visited.has(pos) or revealed
		var is_cur: bool = room == current
		if not seen and kind not in ["tienda", "jefe"]:
			# vecina sin pisar: contorno punteado con "?"
			_boxr(rc, Color(0.42, 0.42, 0.5, 0.18 * fa), Color(0, 0, 0, 0), 0, 6)
			_dashed_rect(rc, Color(0.7, 0.7, 0.8, 0.8 * fa), 2.0, 6.0)
			_tx_c("?", rc.get_center(), int(clampf(rc.size.y * 0.5, 10, 40)), Color(0.8, 0.8, 0.9, fa), false, true)
			continue
		var tint := 0.0
		if visited.has(pos) and not (room.cleared or room.enemies_spawned.is_empty()):
			tint = 0.45
		if not visited.has(pos):
			tint = 0.0
		_room_big(rc, kind, r, fa, tint, room.room_type == Room.RoomType.BOSS and not RunManager.floor_has_boss(_rm.current_floor), room.has_meta("elite_room"))
		if not visited.has(pos):
			_view.draw_rect(rc, Color(0.1, 0.1, 0.18, 0.35 * fa))
		if is_cur:
			_boxr(rc.grow(3), Color(0, 0, 0, 0), Color("f2ead6", fa) if _blink else Color(GOLD, fa), 4, 8)
	if current:
		Silencio.draw_minimap(_view, rect_of.call(current.grid_pos), current)
		var rc2: Rect2 = rect_of.call(current.grid_pos)
		var ht := _hero_tex(_rm.character)
		var hs := clampf(rc2.size.y * 0.7, 16, 80)
		if ht != null:
			var asp := ht.get_size().x / ht.get_size().y
			_view.draw_texture_rect(ht, Rect2(rc2.get_center() - Vector2(hs * asp * 0.5, hs * 0.55), Vector2(hs * asp, hs)), false)
		elif ht == null:
			_view.draw_circle(rc2.get_center(), hs * 0.3, GOLD if _blink else Color.WHITE)
		var rname: String = tr("MAP_ROOM_ELITE") if current.has_meta("elite_room") else tr(Minimap.ROOM_NAMES.get(current.room_type, "?"))
		var nm := "%s · %s" % [Loc.floor_name(_rm.floor_data(), true), rname]
		_tx(nm, Vector2(panel.position.x + 16, panel.end.y - 12), 14, Color(1, 1, 1, fa), HORIZONTAL_ALIGNMENT_LEFT, -1, true, true)


func _room_big(rc: Rect2, kind: String, r: Dictionary, a: float, tint: float, guard: bool, elite: bool) -> void:
	var k := "combate" if kind == "especial" else kind
	_room(rc, k, r, a, guard, tint)
	if kind == "especial":
		_view.draw_rect(rc, Color("ffe9a0", 0.55 * a))
		_icon("especial", rc.get_center(), minf(rc.size.x, rc.size.y) * 0.36, Color(INK, a), Color("ffe9a0"))
	if elite:
		_boxr(rc, Color(0, 0, 0, 0), Color("ff3a1a", a), 4, 6)


# ------------------------------------------------------------------ interfaz (en pantalla)

func _draw_ui(fa: float) -> void:
	var vs := _vs
	# barra superior
	_view.draw_rect(Rect2(0, 0, vs.x, 40), Color(INK, 0.92))
	_view.draw_line(Vector2(0, 40), Vector2(vs.x, 40), Color(PAPER, 0.5), 2.0)
	_tx(tr("MM_TITULO"), Vector2(14, 28), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, true, true)
	var lvl := _level_label(fa)
	_tx(lvl, Vector2(14 + HudStyle.FONT_BOLD.get_string_size(tr("MM_TITULO"), HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 24, 27), 16, Color("bed0f5"), HORIZONTAL_ALIGNMENT_LEFT, -1, true, false)
	# sellos
	var need := RunManager.seals_needed()
	var have := RunManager.seals()
	var txt := tr("MAPA_SELLOS") % [have, need]
	var tw := HudStyle.FONT.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_btn_close = Rect2(vs.x - 40, 6, 30, 28)
	var x := _btn_close.position.x - tw - 14
	_tx(txt, Vector2(x, 27), 16, GOLD if have >= need else HudStyle.CREAM, HORIZONTAL_ALIGNMENT_LEFT, -1, true, false)
	for i in need:
		var c := Vector2(x - 14 - (need - 1 - i) * 20.0, 20)
		if i < have:
			_seal(c, 8.0)
		else:
			_view.draw_arc(c, 7.0, 0, TAU, 14, Color(0.5, 0.5, 0.6), 2.0)
	_boxr(_btn_close, Color(0.4, 0.1, 0.14), PAPER, 2, 4)
	_view.draw_line(_btn_close.position + Vector2(8, 7), _btn_close.end - Vector2(8, 7), Color.WHITE, 3.0)
	_view.draw_line(_btn_close.position + Vector2(_btn_close.size.x - 8, 7), _btn_close.position + Vector2(8, _btn_close.size.y - 7), Color.WHITE, 3.0)
	# zoom +/-
	_btn_zin = Rect2(vs.x - 44, vs.y - 112, 32, 32)
	_btn_zout = Rect2(vs.x - 44, vs.y - 74, 32, 32)
	for b in [[_btn_zin, "+"], [_btn_zout, "-"]]:
		_boxr(b[0], Color(INK, 0.9), PAPER, 2, 4)
		_tx_c(b[1], b[0].get_center(), 22, Color.WHITE, false, true)
	# barra inferior de ayuda
	_view.draw_rect(Rect2(0, vs.y - 28, vs.x, 28), Color(INK, 0.92))
	var hint := tr("MM_SALTAR") if _intro else (tr("MM_AYUDA_PAD") if Input.get_connected_joypads().size() > 0 else tr("MM_AYUDA"))
	_tx_c(hint, Vector2(vs.x * 0.5, vs.y - 14), 12, Color("bed0f5"), false, false)
	if _legend and not _intro:
		_draw_legend()


func _level_label(fa: float) -> String:
	var rm := get_node_or_null("/root/RunManager")
	if _intro or rm == null:
		return tr("MM_NIVEL_MUNDO")
	if fa > 0.5:
		return tr("MM_NIVEL_PISO") % [Loc.floor_name(_rm.floor_data(), true), RunManager.floor_stage(_rm.current_floor)]
	if _zoom > _z_r * 0.75:
		var best := ""
		for r in _d.regions:
			var rc := Rect2(Vector2(float(r.x), float(r.y)) * CELL, Vector2(float(r.w), float(r.h)) * CELL)
			if rc.has_point(_cam):
				best = WorldMap.region_label(r, _wm.voz(r))
		if best != "":
			return tr("MM_NIVEL_REINO") % best
	return tr("MM_NIVEL_MUNDO")


func _draw_legend() -> void:
	var rh := 20.0
	var cw := 128.0
	var panel := Rect2(10, 50, cw * 2 + 14, 10 * rh + 48)
	_boxr(panel, Color("080c1e", 0.93), PAPER, 2, 8)
	_tx(tr("MM_LEY_TITULO"), panel.position + Vector2(10, 21), 13, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, false, true)
	var demo: Dictionary = {"sala": "6ec6ff", "ico": "0b2a40"}
	var zoom_keep := _zoom
	_zoom = 0.4
	var y0 := panel.position.y + 30
	for i in KINDS.size():
		var k: String = KINDS[i]
		var col := i / 6
		var row := i % 6
		var x := panel.position.x + 8 + col * cw
		_room(Rect2(x, y0 + row * rh + 1, 17, 17), k, demo)
		_tx(tr(KIND_NAMES[k]), Vector2(x + 24, y0 + row * rh + 14), 11, Color("dce4ff"), HORIZONTAL_ALIGNMENT_LEFT, cw - 30, false, false)
	_zoom = zoom_keep
	var items := ["fija", "choice", "lock", "seal", "lift", "hero", "dead"]
	var y1 := y0 + 6 * rh + 8
	for i in items.size():
		var item: String = items[i]
		var col := i % 2
		var x := panel.position.x + 8 + col * cw
		var y := y1 + (i / 2) * rh
		var c := Vector2(x + 9, y + 9)
		var label := ""
		match item:
			"fija":
				_view.draw_rect(Rect2(c - Vector2(8, 5), Vector2(16, 10)), FIXED)
				_view.draw_rect(Rect2(c - Vector2(8, 5), Vector2(16, 10)), Color.WHITE, false, 1.0)
				label = "MAPA_LEY_FIJA"
			"choice":
				_view.draw_rect(Rect2(c - Vector2(8, 5), Vector2(16, 10)), CHOICE)
				_view.draw_rect(Rect2(c - Vector2(8, 5), Vector2(16, 10)), INK, false, 1.0)
				label = "MAPA_LEY_ELECCION"
			"lock":
				_view.draw_rect(Rect2(c + Vector2(-6, -2), Vector2(12, 9)), FIXED)
				_view.draw_arc(c + Vector2(0, -2), 4.0, PI, TAU, 8, Color.WHITE, 2.0)
				label = "MAPA_LEY_CANDADO"
			"seal":
				_seal(c, 8.0)
				label = "MM_LEY_SELLO"
			"lift":
				_view.draw_rect(Rect2(c - Vector2(8, 8), Vector2(16, 16)), Color("0e4659"))
				_view.draw_rect(Rect2(c - Vector2(8, 8), Vector2(16, 16)), Color("78ebff"), false, 1.5)
				_view.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(-5, 4), c + Vector2(5, 4)]), Color("96f0ff"))
				label = "MM_LEY_ASCENSOR"
			"hero":
				_view.draw_dashed_line(c - Vector2(9, 0), c + Vector2(9, 0), _hero_color, 3.0, 5.0)
				label = "MM_LEY_RUTA"
			"dead":
				_view.draw_line(c + Vector2(-7, -7), c + Vector2(7, 7), SEAL_RED, 3.0)
				_view.draw_line(c + Vector2(7, -7), c + Vector2(-7, 7), SEAL_RED, 3.0)
				label = "MM_VENCIDO"
		_tx(tr(label), Vector2(x + 24, y + 14), 11, Color("dce4ff"), HORIZONTAL_ALIGNMENT_LEFT, cw - 30, false, false)
