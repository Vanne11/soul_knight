class_name UteroFx
extends Node

## Hijo de main mientras estas en El Utero (src/utero/utero.gd lo crea y lo libera):
##  - tinte de pantalla por fase (apagado a un tercio mientras la sala siga censurada: gris);
##  - cartel de fase al entrar (nombre + lo que cambia) y frase del narrador;
##  - buffs de fase (ovulacion: el heroe corre mas) que se devuelven al salir de la fase/piso;
##  - lanza las dinamicas de cada fase en sus salas de pelea;
##  - reacciones por heroe (biblia, seccion 5): Pitocles, calambres; Ornitorrinco, un huevo;
##    Vulvalquiria, por fin un nivel que no aburre.

const COLORS := [
	Color(0.9, 0.08, 0.14, 0.20),   # menstruacion: marea roja
	Color(0.55, 0.95, 0.45, 0.10),  # folicular: todo florece
	Color(1.0, 0.45, 0.75, 0.13),   # ovulacion: celo
	Color(0.5, 0.3, 0.8, 0.18),     # lutea: SPM
	Color(0.85, 0.05, 0.1, 0.24),   # Dona Regla
]
const TITLE_COLORS := ["ff5a6e", "9be86a", "ff8ac8", "b894ff"]
const OVULATION_SPEED := 1.15
const VULVAL_DAMAGE := 1.12

var main: Node
var _layer: CanvasLayer
var _tint: ColorRect
var _target := Color(0, 0, 0, 0)
var _cur := -1
var _announced := {}
var _mods: Array = []        # [stat, multiplicador] de la fase actual
var _hero_mods: Array = []   # buffs del heroe para todo el piso
var _room: Room = null
var _t := 0.0
var _hero_done := false
var _cramp_t := -1.0
var _spasm := false
var _frozen_scale := -1.0
var _hero := ""


func _ready() -> void:
	_hero = str(get_node("/root/RunManager").character)
	_layer = CanvasLayer.new()
	_layer.layer = 2  # sobre el mundo, bajo el HUD
	add_child(_layer)
	_tint = ColorRect.new()
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = Color(0, 0, 0, 0)
	_layer.add_child(_tint)


func _exit_tree() -> void:
	_clear_mods()
	for m in _hero_mods:
		get_node("/root/PlayerStats").apply_stat_mod(m[0], 1.0 / float(m[1]))
	_hero_mods.clear()
	if _spasm:
		_spasm = false
		get_node("/root/PlayerStats").apply_stat_mod("speed", 1.0 / 0.45)
	if _frozen_scale > 0.0:
		Engine.time_scale = _frozen_scale
		_frozen_scale = -1.0
	Utero.phase = -1


func _process(delta: float) -> void:
	_t += delta
	var lit := true
	if _room != null and is_instance_valid(_room):
		lit = _room.cleared or _room.room_type in main.CALM_ROOMS
	var want := _target
	want.a *= 1.0 if lit else 0.5  # mientras la sala siga censurada, solo un asomo de color
	if _cur == 0 or _cur == 4:
		want.a *= 0.88 + 0.12 * sin(_t * 1.7)  # la marea sube y baja
	_tint.color = _tint.color.lerp(want, clampf(delta * 3.0, 0.0, 1.0))
	if _cur == 0 and _hero == "pitocles" and _cramp_t >= 0.0:
		_cramp_t -= delta
		if _cramp_t <= 0.0:
			_cramp()


# ------------------------------------------------------------------ entrar en una sala
func enter_room(room: Room, door: Door) -> void:
	_room = room
	var p := Utero.phase_of(room)
	if p >= 0 and p != _cur:
		_change_phase(p)
	_launch(room, door)
	if not _hero_done:
		_hero_done = true
		_hero_intro()


func _change_phase(p: int) -> void:
	_clear_mods()
	_cur = p
	Utero.phase = p
	_target = COLORS[clampi(p, 0, COLORS.size() - 1)]
	if p == 2:
		_add_mod("speed", OVULATION_SPEED)
	if p < 4 and not _announced.has(p):
		_announced[p] = true
		_banner(p)
		get_node("/root/LoreDatabase").custom_event("utero_fase_" + Utero.PHASE_NAMES[p])
		_say_later("utero_fase_%d" % (p + 1))
	if p == 0 and _hero == "pitocles" and _cramp_t < 0.0:
		_cramp_t = 7.0


func _add_mod(stat: String, mult: float) -> void:
	get_node("/root/PlayerStats").apply_stat_mod(stat, mult)
	_mods.append([stat, mult])


func _clear_mods() -> void:
	for m in _mods:
		get_node("/root/PlayerStats").apply_stat_mod(m[0], 1.0 / float(m[1]))
	_mods.clear()


## Narrador sin pisar el combate (en pelea Narrator.say se pierde): espera a que haya calma.
func _say_later(event: String) -> void:
	for _i in 120:
		if not is_inside_tree():
			return
		if not Narrator._in_combat():
			Narrator.say(event, {}, true)  # importante: sale siempre
			return
		await get_tree().create_timer(0.5).timeout


func _banner(p: int) -> void:
	await get_tree().create_timer(0.7).timeout
	if not is_inside_tree():
		return
	var layer := CanvasLayer.new()
	layer.layer = 40
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_bottom = -300.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := Label.new()
	title.text = tr("UTERO_PHASE_%d" % (p + 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HudStyle.style_label(title, 40, Color(TITLE_COLORS[p]), true)
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	var sub := Label.new()
	sub.text = tr("UTERO_PHASE_%d_D" % (p + 1))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	HudStyle.style_label(sub, 18, HudStyle.CREAM, true)
	box.add_child(title)
	box.add_child(sub)
	layer.add_child(box)
	add_child(layer)
	box.modulate.a = 0.0
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.0)
	tw.tween_property(box, "modulate:a", 0.0, 0.7)
	tw.tween_callback(layer.queue_free)


# ------------------------------------------------------------------ dinamicas de fase
func _launch(room: Room, _door: Door) -> void:
	if room.cleared or room.has_meta("utero_dyn") or room.has_meta("elite_room") or room.room_type not in Utero.FIGHT:
		return
	if not main._has_real_weapon():
		return
	var p := Utero.phase_of(room)
	room.set_meta("utero_dyn", true)
	match p:
		1:
			_dyn("res://src/utero/utero_folliculos.gd", "folliculos", room)
		2:
			_dyn("res://src/rooms/mod_room.gd", "celo", room)  # en celo: enemigos mas rapidos, botin extra
			if room.has_meta("utero_ovulo"):
				_dyn("res://src/utero/utero_ovulo.gd", "ovulo", room)


func _dyn(path: String, kind: String, room: Room) -> void:
	var d: RoomDynamic = load(path).new()
	d.main = main
	d.room = room
	d.kind = kind
	d.name = "Dyn_" + kind
	room.set_meta("dyn_done", true)  # el director de salas no suma otra dinamica encima
	room.add_child.call_deferred(d)


# ------------------------------------------------------------------ reacciones por heroe
func _hero_intro() -> void:
	await get_tree().create_timer(3.2).timeout
	if not is_inside_tree():
		return
	match _hero:
		"vulvalquiria":
			_hero_mods.append(["damage", VULVAL_DAMAGE])
			get_node("/root/PlayerStats").apply_stat_mod("damage", VULVAL_DAMAGE)
			RoomUtil.popup(main.player.global_position + Vector2(0, -60), tr("UTERO_FIN"), Color("ffd75a"))
			_say_later("utero_react_vulvalquiria")
		"ornitorrinco":
			_egg()


## Pitocles: calambres por primera vez. Cada pocos segundos se dobla un instante (mas lento).
## La primera vez el narrador calla por respeto (su frase es justo ese silencio).
func _cramp() -> void:
	_cramp_t = randf_range(6.0, 9.0)
	if _spasm:
		return
	_spasm = true
	get_node("/root/PlayerStats").apply_stat_mod("speed", 0.45)
	RoomUtil.popup(main.player.global_position + Vector2(0, -60), tr("UTERO_AY"), Color("ff8a9a"))
	Sound.play("enemy_hit")
	if not _announced.has("cramp"):
		_announced["cramp"] = true
		Narrator._queue.clear()
		_say_later("utero_react_pitocles")
	await get_tree().create_timer(0.8).timeout
	if _spasm:
		_spasm = false
		get_node("/root/PlayerStats").apply_stat_mod("speed", 1.0 / 0.45)


## Ornitorrinco: pone un huevo. Todo se detiene un instante y nadie entiende nada.
func _egg() -> void:
	var pl: Node2D = main.player
	var room: Room = main.current_room
	if room != null:
		var local: Vector2 = pl.global_position - room.global_position + Vector2(28, 8)
		main._spawn_pickup(room, "huevo_suerte", local)
	RoomUtil.popup(pl.global_position + Vector2(0, -60), tr("UTERO_EGG_PLOP"), Color("ffe08a"))
	Sound.play("crack")
	_say_later("utero_react_ornitorrinco")
	_frozen_scale = Engine.time_scale
	Engine.time_scale = 0.06
	await get_tree().create_timer(1.1, true, false, true).timeout  # el tiempo real: el mundo esta congelado
	if _frozen_scale > 0.0:
		Engine.time_scale = _frozen_scale
		_frozen_scale = -1.0
	RoomUtil.popup(pl.global_position + Vector2(0, -90), tr("UTERO_APPLAUSE"), Color("f2ead6"))
