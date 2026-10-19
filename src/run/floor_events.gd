extends Node
class_name FloorEvents

## Eventos de piso al azar y contrarreloj opcional (etapa 6b).
## Un unico sitio donde preguntar: `FloorEvents.active("calor")`. main.gd crea el nodo con
## `FloorEvents.setup(...)` al generar cada piso; los ganchos del resto del juego son de 1-2 lineas:
##   main._generate_enemy_data_for_room  extra_enemies() / force_elite(room, i)
##   shop_item.price_for                 price_mult()
##   minimap._draw                       hide_map()
## Eventos (anunciados con cartel grande y frase corta; nunca en el piso 1):
##   inspeccion  "Inspeccion general": todas las salas de pelea con al menos un elite.
##   calor       "Ola de calor": enemigos (x1.25) y jugador (x1.2) mas rapidos.
##   censura     "Censura total": sin minimapa.
##   espuma      "Fiesta de espuma": el suelo resbala en todo el piso.
##   luz         "Corte de luz": todas las salas en penumbra.
##   rebajas     "Dia de rebajas": tienda a mitad de precio, pero un enemigo mas por sala.
## Contrarreloj: en la sala de inicio hay un reloj de pared (interactuar = aceptar, y sale el
## cronometro). Llegar a la sala del jefe antes del limite da monedas (aceptado o no). Si lo
## aceptaste y tardas, llega "la Censura": un enemigo mas por sala y el mundo palidece. Sin mas castigo.

const EVENTS := {
	"inspeccion": {"min_floor": 3, "weight": 1.0, "color": "ff7a4a"},
	"calor": {"min_floor": 2, "weight": 1.2, "color": "ffb03c"},
	"censura": {"min_floor": 2, "weight": 0.9, "color": "d8d8e6"},
	"espuma": {"min_floor": 2, "weight": 1.1, "color": "7ad8ff"},
	"luz": {"min_floor": 2, "weight": 1.1, "color": "8a8aa8"},
	"rebajas": {"min_floor": 2, "weight": 1.0, "color": "ffd75a"},
}
const ENEMY_SPEED_MULT := 1.25
const PLAYER_SPEED_MULT := 1.2
const SLIP_ACCEL := 420.0  # igual que "lubricado" (mod_room.gd)
const TRIAL_SECONDS_PER_ROOM := 35.0

## Evento activo del piso ("" = ninguno) y estado de la contrarreloj. Estaticos: se consultan sin nodo.
static var current := ""
static var trial_state := ""  # "" | "offered" | "accepted" | "won" | "late"
static var _instance: FloorEvents = null
## Pruebas: fuerza un evento ("calor"...) en todo piso, tambien el 1.
static var test_force := ""

var main: Node
var rooms: Dictionary = {}
var trial_limit := 0.0
var trial_time := 0.0
var _clock_placed := false
var _slip_vel := Vector2.ZERO
var _timer_box: PanelContainer
var _timer_label: Label
var _timer_bar: ColorRect
var _clock: WallClock
var _tag_label: Label
var _grey_layer: CanvasLayer


# ------------------------------------------------------------------ consulta (estatica)
static func active(id: String) -> bool:
	return current == id


static func hide_map() -> bool:
	return current == "censura"


static func price_mult() -> float:
	return 0.5 if current == "rebajas" else 1.0


## Enemigos extra por sala (Dia de rebajas, y la Censura si te pasaste del tiempo).
static func extra_enemies() -> int:
	return (1 if current == "rebajas" else 0) + (1 if trial_state == "late" else 0)


## true si el enemigo i de la sala debe ser elite por el evento (Inspeccion general: el primero).
static func force_elite(room: Room, i: int) -> bool:
	return current == "inspeccion" and i == 0 and room.room_type in [Room.RoomType.COMBAT, Room.RoomType.INTOXICATION, Room.RoomType.TRAP]


## Probabilidad de evento por piso: 0 en el 1, de ahi sube 6% por piso (tope 55%).
static func chance_for(floor_n: int) -> float:
	return 0.0 if floor_n <= 1 else clampf(0.10 + 0.06 * (floor_n - 1), 0.0, 0.55)


## Evento del piso (determinista por semilla y piso; no toca RNG). "" = sin evento.
static func roll(floor_n: int, run_seed: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, floor_n, "floor_event"])
	if rng.randf() >= chance_for(floor_n):
		return ""
	var opts := {}
	for id in EVENTS:
		if floor_n >= int(EVENTS[id].min_floor):
			opts[id] = float(EVENTS[id].weight)
	if opts.is_empty():
		return ""
	var total := 0.0
	for w in opts.values():
		total += w
	var r := rng.randf() * total
	for id in opts:
		r -= opts[id]
		if r <= 0.0:
			return id
	return opts.keys().back()


## Gancho de main._generate_dungeon (justo tras RoomLighting.setup_floor): elige el evento,
## aplica lo que va por sala (penumbra) y crea el nodo que anuncia y vigila. `force` (pruebas).
static func setup(main_: Node, rooms_: Dictionary, floor_n: int, run_seed: int, force := "") -> FloorEvents:
	if is_instance_valid(_instance):
		_instance.get_parent().remove_child(_instance)
		_instance.free()
	if Silencio.is_floor(floor_n):
		current = ""  # Las Tierras del Silencio: sin eventos de piso, ni reloj, ni humor (diseno_E3, regla 1)
		trial_state = ""
		return null
	current = force if force != "" else (test_force if test_force != "" else roll(floor_n, run_seed))
	trial_state = "offered"
	var fe := FloorEvents.new()
	fe.name = "FloorEvents"
	fe.main = main_
	fe.rooms = rooms_
	fe.trial_limit = TRIAL_SECONDS_PER_ROOM * rooms_.size()
	_instance = fe
	if current == "luz":
		for r in rooms_.values():
			r.is_dark = true
	main_.add_child(fe)
	return fe


## Gancho de main._enter_room (al final): reloj de la sala de inicio y llegada al jefe.
static func on_room_enter(room: Room) -> void:
	if is_instance_valid(_instance):
		_instance._room_entered(room)


# ------------------------------------------------------------------ nodo
func _ready() -> void:
	process_physics_priority = 20  # despues del jugador (el patinaje se suma tras su movimiento)
	_apply_player_speed(true)
	get_tree().node_added.connect(_on_node_added)
	if current != "":
		get_tree().create_timer(2.8).timeout.connect(_announce)
		_make_tag()


func _exit_tree() -> void:
	_apply_player_speed(false)


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _apply_player_speed(on: bool) -> void:
	var pl := _player()
	if pl == null or not ("move_speed" in pl):
		return
	if not pl.has_meta("fe_base_speed"):
		pl.set_meta("fe_base_speed", pl.move_speed)
	var base: float = pl.get_meta("fe_base_speed")
	pl.move_speed = base * (PLAYER_SPEED_MULT if (on and current == "calor") else 1.0)


## Ola de calor: todo enemigo que nace (oleadas, dinamicas, llaves...) va mas rapido.
func _on_node_added(n: Node) -> void:
	if current == "calor" and n is CharacterBody2D:
		_speed_up.call_deferred(n)


func _speed_up(n: Node) -> void:
	if is_instance_valid(n) and n.is_in_group("enemy") and not n.has_meta("fe_fast") and "move_speed" in n:
		n.set_meta("fe_fast", true)
		n.move_speed *= ENEMY_SPEED_MULT


func _physics_process(delta: float) -> void:
	# Fiesta de espuma: patinaje (misma tecnica que el modificador "lubricado" de mod_room.gd).
	if current != "espuma" or main == null or main.get("current_room") == null:
		return
	var pl := _player() as CharacterBody2D
	if pl == null:
		return
	var rd := RoomDirector.of(get_tree())
	if rd != null and rd.effective_kind(main.current_room) == "lubricado" and rd.started.has(main.current_room):
		return  # ya patina por su cuenta: no se suma
	if pl.get("is_dashing"):
		_slip_vel = pl.velocity
		return
	var want := pl.velocity
	_slip_vel = _slip_vel.move_toward(want, SLIP_ACCEL * delta)
	var extra := _slip_vel - want
	if extra.length_squared() > 1.0:
		pl.move_and_collide(extra * delta)


func _process(delta: float) -> void:
	if trial_state in ["offered", "accepted"] and main != null and not main.floor_completed:
		trial_time += delta
		if is_instance_valid(_clock):
			_clock.set_progress(trial_time / maxf(trial_limit, 1.0))
		if trial_state == "accepted":
			_update_timer()
			if trial_time >= trial_limit:
				_trial_late()
	elif _timer_box != null:
		_timer_box.visible = false


# ------------------------------------------------------------------ anuncio
func _make_tag() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 39
	_tag_label = HudStyle.pixel_label(tr("EVT_TAG") % tr("EVT_%s_NAME" % current.to_upper()), 14, Color(EVENTS[current].color))
	_tag_label.position = Vector2(14, HUD.BAND + 8)
	layer.add_child(_tag_label)
	add_child(layer)


func _announce() -> void:
	if current == "" or main == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 41
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var color := Color(EVENTS[current].color)
	var title := HudStyle.pixel_label(tr("EVT_%s_NAME" % current.to_upper()), 64, color, true)
	var phrase := HudStyle.pixel_label(tr("EVT_%s_PHRASE" % current.to_upper()), 24, HudStyle.CREAM, true)
	for l in [title, phrase]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("shadow_offset_x", 4)
		l.add_theme_constant_override("shadow_offset_y", 4)
		box.add_child(l)
	# desplazado hacia abajo: la tarjeta del piso ocupa el centro
	box.offset_top = 150
	layer.add_child(box)
	add_child(layer)
	Sound.play("room_clear")
	Narrator.say("event_" + current)
	var tw := box.create_tween()
	box.modulate.a = 0.0
	tw.tween_property(box, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.4)
	tw.tween_property(box, "modulate:a", 0.0, 0.7)
	tw.tween_callback(layer.queue_free)


# ------------------------------------------------------------------ contrarreloj
func _room_entered(room: Room) -> void:
	if room.room_type == Room.RoomType.START and not _clock_placed:
		_clock_placed = true
		_place_clock(room)
	elif room.room_type == Room.RoomType.BOSS and trial_state in ["offered", "accepted"]:
		_trial_won(room)


func _place_clock(room: Room) -> void:
	# reloj de pie animado (src/fx/wall_clock.gd): pixel art, pulso mientras se ofrece
	var visual := WallClock.new()
	visual.dress(room)
	_clock = visual
	var spot: Vector2 = RoomUtil.free_spot(main, room, room.get_center_position() + Vector2(-150, -70))
	if spot == Vector2.INF:
		spot = room.get_center_position() + Vector2(-150, -70)
	main._add_prop(room, spot, visual, tr("TT_PROMPT") % _fmt(trial_limit), _accept_trial)
	Narrator.toast(tr("TT_OFFER_TITLE"), tr("TT_OFFER_BODY") % _fmt(trial_limit), "ffd75a")
	Narrator.say("trial_offer")


func _accept_trial(_p, it) -> void:
	if trial_state != "offered":
		return
	trial_state = "accepted"
	Sound.play("buy")
	it.finish()
	Narrator.toast(tr("TT_ACCEPT_TITLE"), tr("TT_ACCEPT_BODY") % _fmt(maxf(trial_limit - trial_time, 0.0)), "ffd75a")
	if is_instance_valid(_clock):
		_clock.offered = false
	if _timer_box == null:
		_build_timer()
	_update_timer()


## Contador con el estilo del HUD: panel dorado, icono de reloj, tiempo en fuente pixel y una
## barra fina de lo que queda. Nodo propio (no toca hud.gd).
func _build_timer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 39
	_timer_box = PanelContainer.new()
	_timer_box.add_theme_stylebox_override("panel", HudStyle.panel_box(6.0))
	_timer_box.position = Vector2(10, HUD.BAND + 34)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_timer_box.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var ico := HudStyle.icon("clock")
	ico.custom_minimum_size = Vector2(26, 26)
	row.add_child(ico)
	_timer_label = HudStyle.pixel_label("", 24, Color("ffd75a"), true)
	row.add_child(_timer_label)
	_timer_bar = ColorRect.new()
	_timer_bar.custom_minimum_size = Vector2(0, 6)
	_timer_bar.color = Color("ffd75a")
	var back := Control.new()
	back.custom_minimum_size = Vector2(0, 6)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.07, 0.9)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.add_child(bg)
	back.add_child(_timer_bar)
	col.add_child(back)
	layer.add_child(_timer_box)
	add_child(layer)


func _update_timer() -> void:
	if _timer_box == null:
		return
	_timer_box.visible = true
	var left := maxf(trial_limit - trial_time, 0.0)
	_timer_label.text = _fmt(left)
	var frac := clampf(left / maxf(trial_limit, 1.0), 0.0, 1.0)
	var back_w := _timer_box.size.x - 20.0
	_timer_bar.size = Vector2(maxf(back_w * frac, 0.0), 6.0)
	var col := Color("ffd75a")
	if left <= 12.0:
		# ultimos segundos: parpadeo en rojo, mas rapido cuanto menos queda
		var blink := fposmod(left, 1.0) > 0.5
		col = Color("ff4a4a") if blink else Color("ffb0a0")
		_timer_box.scale = Vector2.ONE * (1.0 + (0.06 if blink else 0.0))
	elif left < 30.0:
		col = Color("ff9a5a")
		_timer_box.scale = Vector2.ONE
	else:
		_timer_box.scale = Vector2.ONE
	_timer_label.add_theme_color_override("font_color", col)
	_timer_bar.color = col


func _fmt(sec: float) -> String:
	return "%d:%02d" % [int(sec) / 60, int(sec) % 60]


func _trial_won(room: Room) -> void:
	var accepted := trial_state == "accepted"
	trial_state = "won"
	if is_instance_valid(_clock):
		_clock.offered = false
	var d: int = RunManager.depth_i(get_node("/root/RunManager").current_floor)
	var n: int = 6 + 2 * d if accepted else 4 + d
	var pl := _player()
	var center := room.to_local(pl.global_position) if pl else room.get_center_position()
	RoomUtil.coins(main, room, n, center + Vector2(0, 70))  # el jugador puede estar pegado a un muro: coins() lo lleva a suelo libre
	Sound.play("floor_complete")
	Narrator.toast(tr("TT_WIN_TITLE"), tr("TT_WIN_BODY") % n, "ffd75a")
	Narrator.say("trial_win")


func _trial_late() -> void:
	trial_state = "late"
	Narrator.toast(tr("TT_LATE_TITLE"), tr("TT_LATE_BODY"), "d8d8e6")
	Narrator.say("trial_late")
	Sound.play("door")
	_grey_layer = CanvasLayer.new()
	_grey_layer.layer = 38
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0.55, 0.55, 0.62, 0.0)
	_grey_layer.add_child(rect)
	add_child(_grey_layer)
	rect.create_tween().tween_property(rect, "color:a", 0.14, 3.0)
	if _timer_box != null:
		_timer_box.visible = false
