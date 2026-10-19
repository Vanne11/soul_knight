class_name IrisDoor
extends "res://src/items/interactable.gd"

## "Puerta biologica" de la entrada de servicio del Perineo, camino al TEMPLO DE ANUBIS (reino secreto "puerta_trasera"):
## un iris organico en la pared NORTE de la sala del jefe del Perineo, flanqueado por dos estatuas de Anubis
## (templo_anubis.gd). Arte: assets/sprites/environment/iris_door/ (AnimatedSprite2D: idle, shake, open, opened);
## si faltara, cae al dibujo por codigo de siempre (_draw), que se conserva como respaldo.
##
## SECRETO (decision de Nico): se abre SOLO si el heroe le DISPARA con el Lubricante a Base de Agua y ademas LLEVA
## CONDONES (TemploAnubis.has_condoms). Con lubricante sin condones tiembla y no se abre, sin explicar por que.
## Nada lo explica: solo guiños (graffiti, frases de la Matrona y de Dona Ventanilla, codice criptico).
## Hasta que no vences al jefe (armed) tampoco se abre. Abierta, hace "boca de pez" y al cruzarla (E o caminando
## hacia ella) emite `entered`: main.gd te manda por el tobogan al reino (routes.json "detours").
## "can_open" false (routes.json "open": false) la deja sellada para siempre.

signal opened
signal entered

enum S { CLOSED, OPENING, OPEN }
const FRAMES := "res://assets/sprites/environment/iris_door/iris_door_sprite_frames.tres"
const SPRITE_SCALE := 1.4
const LUBE_R := 84.0      # un disparo de lubricante que revienta a esta distancia "le da" a la puerta
const R := 34.0           # radio del iris dibujado por codigo (respaldo), px
const FOLDS := 14         # pliegues radiales (respaldo)
const TOUCH_R := 40.0     # a esta distancia del centro "la tocas"
const FLESH := Color("e9928f")
const FLESH_LIGHT := Color("f6b6ac")
const FLESH_DARK := Color("b8605f")
const LINE := Color("4a1a24")

## 0 cerrada .. 1 abierta (solo el respaldo dibujado por codigo la usa).
var open_amount := 0.0
var wall_dir := "down"    # pared donde esta ("up", "down", "left", "right")
var armed := false        # main.gd la arma al vencer al jefe: antes de eso no se abre
var can_open := true      # false: sellada para siempre (routes.json "detours"."open": false)
var state := S.CLOSED

var _t := 0.0
var _shake := 0.0
var _touch_cd := 0.0
var _tween: Tween
var _spr: AnimatedSprite2D = null


func _ready() -> void:
	prompt_text = tr("PAS_SEALED")
	# area de aproximidad: un circulo grande delante de la puerta (hacia dentro de la sala)
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 78.0
	shape.position = _inward() * 30.0
	add_child(shape)
	collision_layer = 0
	collision_mask = 1
	super._ready()
	add_to_group("iris_door")
	z_index = 1
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED  # se lee tambien en la sala a oscuras
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(FRAMES):
		_spr = AnimatedSprite2D.new()
		_spr.sprite_frames = load(FRAMES)
		_spr.scale = Vector2.ONE * SPRITE_SCALE
		_spr.use_parent_material = true
		add_child(_spr)
		_spr.play("idle")
		_spr.animation_finished.connect(_on_anim_done)


func _inward() -> Vector2:
	return {"down": Vector2.UP, "up": Vector2.DOWN, "left": Vector2.RIGHT, "right": Vector2.LEFT}[wall_dir]


## E: cerrada no hace nada (solo tiembla); abierta, la cruzas.
func _use(_player: Node) -> void:
	if state == S.OPEN:
		_enter()
	else:
		_touch()


func refresh_prompt() -> void:
	if _player:
		Narrator.prompt(self, prompt_text)  # solo el aviso, sin "[E] ..."


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	_touch_cd -= delta
	_shake = maxf(_shake - delta * 2.2, 0.0)
	if _player != null and is_instance_valid(_player):
		var d := (_player as Node2D).global_position.distance_to(global_position)
		if state == S.CLOSED and d < TOUCH_R + 14.0 and _touch_cd <= 0.0:
			_touch()
		elif state == S.OPEN and d < TOUCH_R + 6.0:
			_enter()
	if _spr == null:
		queue_redraw()


## Un tiron de la puerta: tiembla (y si `msg`, flota "Sellada."). Sin explicar nunca por que no se abre.
func _touch(msg := true) -> void:
	if _touch_cd > 0.0 or state != S.CLOSED:
		return
	_touch_cd = 1.4
	_shake = 1.0
	Sound.play("locked")
	if _spr != null:
		_spr.play("shake")
	if msg:
		get_node("/root/GlobalEvents").show_floating_text.emit(global_position + _inward() * 36.0, tr("PAS_SEALED_TOUCH"), Color("ff8f8f"))


func _on_anim_done() -> void:
	if _spr == null:
		return
	match _spr.animation:
		&"shake":
			_spr.play("idle")
		&"open":
			state = S.OPEN
			_spr.play("opened")
			prompt_text = tr("TA_IRIS_ENTER")
			if _player:
				refresh_prompt()
			Narrator.say("templo_puerta")
			opened.emit()


## Un disparo de LUBRICANTE revento cerca de las puertas biologicas (lo llama special_shots.gd). Abre si hay condones.
static func lube_burst(tree: SceneTree, pos: Vector2) -> void:
	for n in tree.get_nodes_in_group("iris_door"):
		if is_instance_valid(n) and n is IrisDoor and (n as Node2D).global_position.distance_to(pos) < LUBE_R:
			(n as IrisDoor).hit_lube()


func hit_lube() -> void:
	if state != S.CLOSED:
		return
	if armed and can_open and TemploAnubis.has_condoms(get_tree()):
		open()
	else:
		_touch(false)  # tiembla y nada mas


## Animacion de apertura: boca de pez (el arte) o, sin arte, los pliegues se retraen.
func open(time := 1.4) -> void:
	if state != S.CLOSED:
		return
	state = S.OPENING
	Sound.play("door")
	get_tree().create_timer(0.5).timeout.connect(func(): Sound.play("suck"))
	get_node("/root/LoreDatabase").custom_event("templo_anubis_puerta")  # codice criptico
	if _spr != null:
		_spr.play("open")
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "open_amount", 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.finished.connect(func():
		state = S.OPEN
		prompt_text = tr("TA_IRIS_ENTER")
		opened.emit())


func _enter() -> void:
	if state == S.OPEN:
		entered.emit()


func _draw() -> void:
	if _spr != null:
		return
	var breathe := 1.0 + 0.035 * sin(_t * 1.7) + 0.012 * sin(_t * 4.1)
	var off := Vector2.ZERO
	if _shake > 0.0:
		off = Vector2(sin(_t * 70.0), cos(_t * 83.0)) * 2.5 * _shake
	var bright := 0.94 + 0.08 * sin(_t * 1.7)
	var rad := R * breathe
	var hole := 3.0 + (rad - 8.0) * open_amount     # el hueco central crece al abrir
	draw_set_transform(off, 0.0, Vector2.ONE)
	# marco de piel y contorno oscuro
	draw_circle(Vector2.ZERO, rad + 6.0, LINE)
	draw_circle(Vector2.ZERO, rad + 3.0, FLESH_DARK * bright)
	draw_circle(Vector2.ZERO, rad, FLESH * bright)
	# pliegues: cuñas que convergen al centro, alternando tono; al abrir se acortan hacia afuera
	for i in FOLDS:
		var a0 := TAU * float(i) / FOLDS
		var a1 := TAU * float(i + 1) / FOLDS
		var am := (a0 + a1) * 0.5
		var tw := 0.12 * sin(_t * 1.7 + float(i))          # cada pliegue respira un poco distinto
		var inner := hole + 2.0
		var pts := PackedVector2Array([
			Vector2.from_angle(a0 + 0.04 + tw * 0.2) * inner,
			Vector2.from_angle(a0 + 0.05) * (rad - 3.0),
			Vector2.from_angle(am) * (rad - 1.0 + 2.0 * tw),
			Vector2.from_angle(a1 - 0.05) * (rad - 3.0),
			Vector2.from_angle(a1 - 0.04 - tw * 0.2) * inner,
			Vector2.from_angle(am) * (inner + 1.5),
		])
		var col := (FLESH_LIGHT if i % 2 == 0 else FLESH) * bright
		col.a = 1.0
		draw_colored_polygon(pts, col)
		# arruga del pliegue (linea oscura hacia el centro)
		draw_line(Vector2.from_angle(a0) * (inner + 1.0), Vector2.from_angle(a0 + 0.02) * (rad - 2.0), LINE, 1.6)
	# anillo exterior de tejido y centro
	draw_arc(Vector2.ZERO, rad - 1.0, 0.0, TAU, 48, FLESH_DARK, 2.0)
	draw_circle(Vector2.ZERO, hole + 1.5, LINE)
	if open_amount < 0.3:
		# rosetón cerrado: unas rayitas que cierran el centro
		for i in 6:
			draw_line(Vector2.ZERO, Vector2.from_angle(TAU * float(i) / 6.0 + 0.3) * (hole + 3.0), Color("7a2a3a"), 1.5)
	# brillo humedo
	draw_circle(Vector2(-rad * 0.35, -rad * 0.4), 3.5, Color(1, 1, 1, 0.45))
	draw_circle(Vector2(-rad * 0.22, -rad * 0.52), 1.8, Color(1, 1, 1, 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
