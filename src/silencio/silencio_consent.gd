class_name SilencioConsent
extends SilencioSala

## S5. Consentimiento: "Cinco puertas" (diseno_E3, secciones 3 y 4). Un pasillo con cinco puertas en fila
## (una por idea: libre, reversible, informado, entusiasta, especifico) y una sexta a un costado (la
## puerta cerrada: quien no puede decidir no puede consentir). Una silueta junto a cada puerta, con un
## objeto cotidiano. Las estaciones son opcionales y en cualquier orden; la salida esta abierta desde el
## principio; nada se desbloquea, no hay barra de progreso ni "5/5".
##
## REGLAS (no se negocian): respetar un "no" NO da nada (ni llave, ni cofre, ni sonido de "bien"): la
## silueta respeta y sigue. Insistir NO abre nada y el juego lo nombra; "Insistir" no es un boton (solo
## existe "Preguntar", y tras un no la silueta repite que no y se aleja). No hay exito ni fracaso: solo
## una frase neutra. Ningun objeto es sexual; la mecanica ensena la logica del consentimiento.
##
## LAS TRES MECANICAS (diseno 4.2):
##  A "Preguntar y escuchar" (estaciones 2, 3, 4): la silueta responde Si claro / No / silencio / duda,
##    al azar en cada entrada a la zona. Seguir y Parar. Ver _ask, _seguir y _parar.
##  B "El si que se gasta" (estacion 5): sello "Si" con barra de 5 s; "Usar tambien su mochila" no estaba
##    incluido; "Usar el si de ayer" no obliga a nada hoy. La estacion 2 usa el mismo sello: a mitad del
##    trayecto la silueta dice "Para" y el sello se rompe.
##  C "Coro de presion" (estacion 1): tu eres a quien piden; Si y No siempre disponibles.
## La estacion 3 ("Decir para qué": sello entero o agrietado), la 4 (dos siluetas, una con el cuerpo hacia ti
## y otra hacia atras) y la 6 (silueta dormida: Preguntar, Irte, Quedarte cerca, Avisar) estan en _items.
##
## Se elige con SilencioOpciones (raton, [E] o Tab). El cartel de salida dice las 5 ideas al dejar la sala.

const INTERACTABLE := preload("res://src/items/interactable.gd")
const ZONE_HALF := 150.0
const POST_Y := 200.0
const DOOR_Y := 196.0
const LANTERN_SECS := 5.0
const STATIONS := [
	{"id": "libre", "x": 200.0},
	{"id": "reversible", "x": 480.0},
	{"id": "informado", "x": 760.0},
	{"id": "entusiasta", "x": 1060.0},
	{"id": "especifico", "x": 1380.0},
]
const P6 := Vector2(1560, 400)   # la silueta dormida (estacion 6)
const CHORUS := [Vector2(78, 208), Vector2(128, 192), Vector2(274, 192), Vector2(326, 208)]
const CHORUS_LINES := ["SIL_S5_COR_1", "SIL_S5_COR_2", "SIL_S5_COR_3"]

var _opts: SilencioOpciones
var _sello: SilencioSello
var _ring: Ring
var _st: Dictionary = {}        # id -> estado de la estacion
var _active := ""               # id de la estacion en la que estas
var _lore_done := false
var _fin_done := false
var _walker := ""               # estacion cuya silueta camina contigo (reversible)
var _walk_t := 0.0
var _lamp_on := false
var _lamp_glow: Sprite2D


func build() -> void:
	for s in STATIONS:
		var x: float = s.x
		sprite("puerta_s5", Vector2(x, DOOR_Y))
		_st[s.id] = {"id": s.id, "x": x, "home": Vector2(x, POST_Y), "fig": null, "state": "idle",
			"answer": "", "informed": false, "noask": 0, "extra": {}}
	_figure("libre", "pie_a", Vector2(200, POST_Y))
	_figure("reversible", "pie_b", Vector2(480, POST_Y))
	_obj("reversible", "linterna", Vector2(506, POST_Y - 4))
	_figure("informado", "pie_c", Vector2(760, POST_Y))
	_obj("informado", "nota", Vector2(786, POST_Y - 4))
	var a := _figure("entusiasta", "pie_a", Vector2(1020, POST_Y))
	var b := _figure("entusiasta", "pie_b", Vector2(1100, POST_Y))
	_st.entusiasta.fig2 = b
	_st.entusiasta.home2 = b.position
	a.z_index = 0
	_figure("especifico", "pie_a", Vector2(1380, POST_Y))
	_obj("especifico", "linterna", Vector2(1406, POST_Y - 4))
	var bag := sprite("mochila", Vector2(1352, POST_Y - 4))
	_st.especifico.extra["bag"] = bag
	# el cartel "Ayer dijo que si" sobre la puerta de la estacion 5
	var yesterday := SilencioBurbuja.create(tr("SIL_S5_AYER_CARTEL"), SilencioBurbuja.PAPER, SilencioBurbuja.INK, 96.0)
	yesterday.z_index = 3
	room.props_node.add_child(yesterday)
	yesterday.hang_over(Vector2(1380, DOOR_Y - 70))
	_decor.append(yesterday)
	# el coro de la estacion 1: 4 siluetas
	var chorus: Array = []
	for p in CHORUS:
		chorus.append(figure(["pie_b", "pie_c", "pie_a", "pie_b"][chorus.size()], p, Color(0.86, 0.87, 0.93)))
	_st.libre.extra["chorus"] = chorus
	# la sexta puerta, a un costado: cerrada, con la silueta dormida contra la pared y un vaso
	sprite("puerta_cerrada", Vector2(P6.x + 92, P6.y + 56))
	var sleeper := figure("dormida", P6, Color(0.9, 0.9, 0.96))
	sprite("vaso", P6 + Vector2(36, 2))
	_st["puerta"] = {"id": "puerta", "x": P6.x, "home": P6, "fig": sleeper, "state": "idle",
		"answer": "", "informed": false, "noask": 0, "extra": {}}
	_lamp_glow = glow(Vector2(1380, 330), 230.0, Color(1.0, 0.86, 0.5))
	_ring = Ring.new()
	_ring.visible = false
	_ring.z_index = 2
	room.props_node.add_child(_ring)
	_decor.append(_ring)


func _figure(id: String, pose: String, pos: Vector2) -> SilencioFigura:
	var f := figure(pose, pos, Color(0.94, 0.94, 1.0))
	f.z_index = 0
	_st[id].fig = f
	return f


func _obj(id: String, name: String, pos: Vector2) -> void:
	_st[id].extra["obj"] = sprite(name, pos)


func start() -> void:
	_opts = SilencioOpciones.create(main)
	_sello = SilencioSello.create(main, tr("SIL_S5_SI"))
	Silencio.cartel([tr("SIL_S5_ENTRADA")], 5.0)


func stop() -> void:
	if _opts != null:
		_opts.clear()
	_walker = ""
	_active = ""
	_ring.visible = false
	if _sello != null:
		_sello.vanish()
	# cartel de salida (aparece en la sala que sigue): las cinco ideas, una sola vez
	if started and not _fin_done:
		_fin_done = true
		Silencio.cartel([tr("SIL_S5_FIN")])
		Silencio.lore("silencio_consentimiento")


func _exit_tree() -> void:
	for n in [_opts, _sello]:
		if n != null and is_instance_valid(n):
			n.queue_free()


# ------------------------------------------------------------------ bucle
func _process(delta: float) -> void:
	if not inside or _opts == null:
		return
	var hp := hero().global_position - room.global_position
	var near := _station_at(hp)
	if near != _active:
		if _active != "":
			_leave_station(_active)
		_active = near
		if _active != "":
			_enter_station(_active)
	if _active != "":
		_tick(_st[_active], delta)
	_tick_walk(delta, hp)
	_ring.visible = _active == "libre"
	if _ring.visible:
		_ring.position = hp + Vector2(0, -16)


func _station_at(hp: Vector2) -> String:
	if hp.distance_to(P6) < 150.0:
		return "puerta"
	for s in STATIONS:
		if absf(hp.x - float(s.x)) < ZONE_HALF and hp.y > 130.0 and hp.y < 560.0 and hp.distance_to(Vector2(P6)) > 150.0:
			return s.id
	return ""


func _hero_local() -> Vector2:
	return hero().global_position - room.global_position


# ------------------------------------------------------------------ entrar y salir de una estacion
func _enter_station(id: String) -> void:
	var st: Dictionary = _st[id]
	st.state = "idle"
	st.noask = 0
	st.answer = _roll()
	st.informed = false
	st.extra["asked"] = false
	st.extra["phase"] = 0
	if id == "libre":
		st.extra["chorus_i"] = 0
		st.extra["chorus_t"] = 0.8
		st.extra["offered"] = false
		st.extra["ring"] = 0
		st.extra["quiet"] = 0.0
		_ring.fill = 0.0
	_refresh(st)


func _leave_station(id: String) -> void:
	var st: Dictionary = _st[id]
	_opts.clear()
	_restore(st)
	if id == "libre":
		_ring.fill = 0.0


## La silueta vuelve a su sitio y postura (lo que cambio al responder se deshace al irte).
func _restore(st: Dictionary) -> void:
	for k in ["fig", "fig2"]:
		var f: SilencioFigura = st.get(k)
		if f == null or not is_instance_valid(f):
			continue
		var home: Vector2 = st.home if k == "fig" else st.home2
		if st.id == "reversible" and _walker == "reversible":
			continue  # sigue contigo hasta que diga "Para"
		var tw := create_tween().set_parallel()
		tw.tween_property(f, "position", home, 0.8)
		tw.tween_property(f, "rotation", 0.0, 0.8)
		tw.tween_property(f.sprite, "position", Vector2.ZERO, 0.4)
	if st.id == "entusiasta":
		var g: Sprite2D = st.extra.get("glow")
		if g != null:
			fade_glow(g, 0.0, 0.8)


## Respuesta al azar de una silueta: si claro, no, silencio o duda.
func _roll() -> String:
	var r := randf()
	if r < 0.4:
		return "si"
	if r < 0.6:
		return "no"
	if r < 0.8:
		return "silencio"
	return "duda"


# ------------------------------------------------------------------ opciones por estacion
func _it(key: String, cb: Callable, off := false) -> Dictionary:
	return {"text": tr(key), "cb": cb, "off": off}


func _refresh(st: Dictionary) -> void:
	_opts.set_items(_items(st))


func _items(st: Dictionary) -> Array:
	var id: String = st.id
	match id:
		"libre":
			if st.state == "done":
				return []
			return [_it("SIL_S5_SI", _libre_answer.bind(st, true)), _it("SIL_S5_NO_BTN", _libre_answer.bind(st, false))]
		"entusiasta":
			match st.state:
				"idle": return [_it("SIL_S5_PREGUNTAR", _ask_two.bind(st))]
				"asked": return [_it("SIL_S5_SEG_IZQ", _follow_two.bind(st, 0)), _it("SIL_S5_SEG_DER", _follow_two.bind(st, 1)),
					_it("SIL_S5_PARAR", _stop_two.bind(st))]
			return []
		"puerta":
			return _items_door(st)
		"especifico":
			var base := _items_a(st)
			if st.extra.get("phase", 0) >= 1:
				if st.extra.get("phase", 0) == 1:
					base.push_front(_it("SIL_S5_MOCHILA_BTN", _use_bag.bind(st)))
				base.append(_it("SIL_S5_AYER_BTN", _yesterday, true))
			return base
	return _items_a(st)


## Mecanica A: lo que se ofrece segun donde va la conversacion.
func _items_a(st: Dictionary) -> Array:
	var out: Array = []
	var ask := _it("SIL_S5_PREGUNTAR", _ask.bind(st))
	match st.state:
		"idle":
			out.append(ask)
		"answered":
			match st.answer:
				"si":
					out.append_array([_it("SIL_S5_SEGUIR", _seguir.bind(st)), _it("SIL_S5_PARAR", _parar.bind(st))])
				"no":
					out.append(_it("SIL_S5_PARAR", _parar.bind(st)))
					if st.noask < 3:
						out.append(ask)
				"silencio":
					out.append_array([_it("SIL_S5_SEGUIR", _seguir.bind(st)), _it("SIL_S5_PARAR", _parar.bind(st)), ask])
				"duda":
					out.append_array([_it("SIL_S5_SEGUIR", _seguir.bind(st)), _it("SIL_S5_PARAR", _parar.bind(st))])
		"duda_stopped":
			out.append(_it("SIL_S5_DUDA_PREG", _ask.bind(st)))
		"walking", "done":
			pass
	if st.id == "informado" and not st.informed and st.state in ["idle", "answered"]:
		out.append(_it("SIL_S5_DECIR", _say_why.bind(st)))
	return out


func _items_door(st: Dictionary) -> Array:
	match st.state:
		"idle":
			return [_it("SIL_S5_PREGUNTAR", _door_ask.bind(st)), _it("SIL_S5_IRTE", _door_leave.bind(st)),
				_it("SIL_S5_QUEDAR", _door_stay.bind(st))]
		"near":
			var out: Array = []
			if not st.extra.get("lamp", false):
				out.append(_it("SIL_S5_AVISAR", _door_alert.bind(st)))
			out.append(_it("SIL_S5_IRTE", _door_leave.bind(st)))
			return out
	return []


# ------------------------------------------------------------------ mecanica A
func _say_fig(st: Dictionary, key: String, secs := 2.6, second := false) -> void:
	var f: SilencioFigura = st.fig2 if second else st.fig
	# al costado, a la altura del pecho: arriba la tapa el HUD (la camara va a 2x y sigue al heroe)
	var dx := 82.0 if (second or st.id != "entusiasta") else -82.0
	say(f.position + Vector2(dx, -20), tr(key), secs)


func _say_hero(key: String, secs := 2.6) -> void:
	say(_hero_local() + Vector2(0, -56), tr(key), secs)


func _first_lore() -> void:
	if not _lore_done:
		_lore_done = true
		Silencio.lore("silencio_consentimiento")


func _ask(st: Dictionary) -> void:
	_first_lore()
	if st.id == "especifico" and st.state == "idle" and st.extra.get("phase", 0) == 0:
		_ask_lantern(st)
		return
	var f: SilencioFigura = st.fig
	if st.state == "duda_stopped":
		st.answer = ["si", "no"][randi() % 2]  # con otra frase responde de verdad
		_say_hero("SIL_S5_DUDA_PREG")
	elif st.state == "answered" and st.answer == "no":
		st.noask += 1  # repetir la pregunta tras un no: sigue siendo no
		_step_away(st, 16.0)
		_say_fig(st, "SIL_S5_R_NO")
		Silencio.cartel([tr("SIL_S5_NO_REP")], 4.0)
		_refresh(st)
		return
	if st.id == "especifico" and st.extra.get("phase", 0) >= 1:
		_say_hero("SIL_S5_PEDIR_MOCHILA")
	st.state = "answered"
	st.extra["asked"] = true
	match st.answer:
		"si":
			_say_fig(st, "SIL_S5_R_SI")
		"no":
			_say_fig(st, "SIL_S5_R_NO")
			Silencio.cartel([tr("SIL_S5_NO")], 4.0)
		"silencio":
			create_tween().tween_property(f.sprite, "position:y", 4.0, 0.5)  # queda quieta, cabeza baja
		"duda":
			_say_fig(st, "SIL_S5_R_DUDA")
	_refresh(st)


func _seguir(st: Dictionary) -> void:
	var f: SilencioFigura = st.fig
	match st.answer:
		"si":
			_on_yes(st)
		"silencio":
			_step_away(st, 20.0)
			Silencio.cartel([tr("SIL_S5_SILENCIO")], 4.0)
			st.state = "done"
		"duda":
			var away := _away_dir(f)
			create_tween().tween_property(f, "rotation", away * 0.22, 0.6)  # cede con el cuerpo hacia atras
			set_light(float(room.get_meta("sil_light", 0.5)) - 0.06)  # la luz de la sala baja un punto
			Silencio.cartel([tr("SIL_S5_DUDA")], 4.0)
			st.state = "done"
	_refresh(st)


func _parar(st: Dictionary) -> void:
	var f: SilencioFigura = st.fig
	match st.answer:
		"silencio":
			create_tween().tween_property(f.sprite, "position:y", 0.0, 0.5)  # levanta la cabeza
			st.state = "idle"
		"duda":
			st.state = "duda_stopped"
		_:
			st.state = "done"
	_refresh(st)


func _on_yes(st: Dictionary) -> void:
	st.state = "done"
	match st.id:
		"reversible":
			_walker = "reversible"
			_walk_t = 0.0
			st.state = "walking"
			_sello.start(LANTERN_SECS)
		"informado":
			_sello.start(LANTERN_SECS, not st.informed)
			if not st.informed:
				Silencio.cartel([tr("SIL_S5_INFO")], 4.0)
		"especifico":
			pass  # la mochila: un si a eso tambien, sin sello ni premio


func _say_why(st: Dictionary) -> void:
	st.informed = true
	_say_hero("SIL_S5_NOTA", 3.5)
	_refresh(st)


## Pasos hacia atras de la silueta (se aleja de quien pregunta, hasta 60 px de su sitio).
func _step_away(st: Dictionary, px: float) -> void:
	var f: SilencioFigura = st.fig
	var home: Vector2 = st.home
	var x := clampf(f.position.x + _away_dir(f) * px, home.x - 60.0, home.x + 60.0)
	create_tween().tween_property(f, "position:x", x, 0.4)


func _away_dir(f: Node2D) -> float:
	return 1.0 if f.position.x >= _hero_local().x else -1.0


## Reversible: la silueta camina contigo; a mitad del trayecto dice "Para" y el sello se rompe.
func _tick_walk(delta: float, hp: Vector2) -> void:
	if _walker != "reversible":
		return
	var st: Dictionary = _st["reversible"]
	var f: SilencioFigura = st.fig
	_walk_t += delta
	var want := hp + Vector2(-42.0, -6.0)
	f.position = f.position.move_toward(want, 110.0 * delta)
	var obj: Sprite2D = st.extra.get("obj")
	if obj != null:
		obj.position = f.position + Vector2(26, -4)
	if _walk_t >= LANTERN_SECS * 0.5:
		_walker = ""
		_say_fig(st, "SIL_S5_PARA", 3.0)
		_sello.shatter()
		Silencio.cartel([tr("SIL_S5_REV")], 4.5)
		st.state = "done"
		var tw := create_tween()
		tw.tween_interval(1.5)
		tw.tween_property(f, "position", st.home, 1.4)
		if obj != null:
			tw.parallel().tween_property(obj, "position", st.home + Vector2(26, -4), 1.4)
		if _active == "reversible":
			_refresh(st)


# ------------------------------------------------------------------ estacion 5: el si que se gasta
func _ask_lantern(st: Dictionary) -> void:
	_say_hero("SIL_S5_PEDIR_LINTERNA")
	_say_fig(st, "SIL_S5_R_SI")
	st.extra["phase"] = 1
	st.state = "idle"
	st.answer = "si"
	_sello.start(LANTERN_SECS)
	var obj: Sprite2D = st.extra.get("obj")
	if obj != null:
		var tw := create_tween()
		tw.tween_property(obj, "position", _hero_local() + Vector2(16, -26), 0.5)
		tw.tween_interval(LANTERN_SECS - 0.5)
		tw.tween_property(obj, "position", st.home + Vector2(26, -4), 0.6)
	_refresh(st)


## "Usar tambien su mochila": el si era para la linterna. Sin castigo: el sello se va y la frase lo dice.
func _use_bag(st: Dictionary) -> void:
	_say_fig(st, "SIL_S5_ESPEC_NO")
	_sello.vanish()
	Silencio.cartel([tr("SIL_S5_ESPEC")], 4.5)
	st.extra["phase"] = 2
	_refresh(st)


## "Usar el si de ayer" (apagado): un si de antes no obliga a nada hoy. No hace nada.
func _yesterday() -> void:
	Silencio.cartel([tr("SIL_S5_AYER")], 4.5)


# ------------------------------------------------------------------ estacion 4: dos siluetas
func _ask_two(st: Dictionary) -> void:
	_first_lore()
	var a: SilencioFigura = st.fig
	var b: SilencioFigura = st.fig2
	_say_fig(st, "SIL_S5_R_SI", 3.0)
	_say_fig(st, "SIL_S5_R_DUDA", 3.0, true)
	var hx := _hero_local().x
	# la primera: cuerpo hacia ti y luz calida; la segunda dice "bueno" con el cuerpo hacia atras
	create_tween().tween_property(a, "rotation", (1.0 if hx > a.position.x else -1.0) * 0.12, 0.5)
	create_tween().tween_property(b, "rotation", (-1.0 if hx > b.position.x else 1.0) * 0.2, 0.5)
	var g := glow(a.position + Vector2(0, -26), 90.0, Color(1.0, 0.82, 0.5))
	st.extra["glow"] = g
	fade_glow(g, 0.7, 0.8)
	st.state = "asked"
	_refresh(st)


func _follow_two(st: Dictionary, which: int) -> void:
	if which == 1:
		var b: SilencioFigura = st.fig2
		create_tween().tween_property(b, "rotation", _away_dir(b) * 0.3, 0.6)
	Silencio.cartel([tr("SIL_S5_ENTUS")], 4.5)
	st.state = "done"
	_refresh(st)


func _stop_two(st: Dictionary) -> void:
	st.state = "done"
	_refresh(st)


# ------------------------------------------------------------------ estacion 1: coro de presion
func _libre_answer(st: Dictionary, yes: bool) -> void:
	_first_lore()
	var ring: int = st.extra.get("ring", 0)
	if yes:
		if ring > 0:
			Silencio.cartel([tr("SIL_S5_LIBRE_SI")], 4.5)
	else:
		_say_fig(st, "SIL_S5_COR_1")  # insiste una vez mas; nada te obliga
		Silencio.cartel([tr("SIL_S5_LIBRE_NO")], 4.5)
	st.state = "done"
	_refresh(st)


func _tick(st: Dictionary, delta: float) -> void:
	if st.id != "libre" or st.state == "done":
		return
	var ex: Dictionary = st.extra
	if not ex.offered:
		ex.offered = true
		_say_fig(st, "SIL_S5_ABRAZO", 3.0)
	ex.chorus_t -= delta
	if ex.chorus_i < CHORUS_LINES.size():
		if ex.chorus_t <= 0.0:
			var chorus: Array = ex.chorus
			var f: SilencioFigura = chorus[ex.chorus_i % chorus.size()]
			say(f.position + Vector2(-70.0 if ex.chorus_i % 2 == 0 else 70.0, -20), tr(CHORUS_LINES[ex.chorus_i]), 2.2)
			ex.chorus_i += 1
			ex.ring = ex.chorus_i
			create_tween().tween_property(_ring, "fill", float(ex.chorus_i) / float(CHORUS_LINES.size()), 0.6)
			ex.chorus_t = 1.6
	else:
		ex.quiet += delta  # el anillo esta lleno y no has respondido
		if ex.quiet >= 7.0:
			ex.quiet = -9999.0
			Silencio.cartel([tr("SIL_S5_LIBRE_CALLA")], 4.5)


# ------------------------------------------------------------------ estacion 6: la puerta cerrada
func _door_ask(st: Dictionary) -> void:
	_first_lore()
	_say_fig(st, "SIL_S5_SINRESP", 3.0)
	Silencio.cartel([tr("SIL_S5_NOPUEDE")], 6.0)


func _door_leave(st: Dictionary) -> void:
	st.state = "away"
	_refresh(st)


func _door_stay(st: Dictionary) -> void:
	st.state = "near"
	Silencio.carry(hero(), to_world(P6 + Vector2(-58, 26)), 0.8)
	_refresh(st)


## Avisar a alguien de confianza: se enciende una luz en el pasillo. Sin premio.
func _door_alert(st: Dictionary) -> void:
	st.extra["lamp"] = true
	fade_glow(_lamp_glow, 0.55, 2.5)
	_refresh(st)


## Aro de presion alrededor del heroe (estacion 1): se llena con cada frase del coro.
class Ring extends Node2D:
	var fill := 0.0:
		set(v):
			fill = v
			queue_redraw()

	func _draw() -> void:
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 40, Color(0.78, 0.74, 0.66, 0.25), 2.0)
		if fill > 0.0:
			draw_arc(Vector2.ZERO, 30.0, -PI * 0.5, -PI * 0.5 + TAU * fill, 40, Color(0.9, 0.86, 0.78, 0.85), 3.0)
