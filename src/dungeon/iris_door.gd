class_name IrisDoor
extends "res://src/items/interactable.gd"

## "Puerta biologica" SELLADA (la entrada de servicio del Perineo, camino a la Puerta Trasera): un iris
## organico rosado-carne con pliegues radiales que convergen al centro, como una compuerta de iris de
## ciencia ficcion pero de tejido. Dibujado por codigo (contorno oscuro, caricaturesco). Va en una pared.
##
## Cerrada: "respira" (pulso lento de escala y brillo). Al acercarte sale el aviso "Esto esta sellado."
## (cuadro de proximidad, como cualquier interactuable) y se va al alejarte; al tocarla tiembla, suena
## sordo y flota "Sellada.". No tiene ningun uso (no es una puerta de verdad: no cruza).
##
## Para ABRIRLA en el futuro: open() anima los pliegues (se retraen y el hueco crece); despues main.gd
## la cambia por una Door normal hacia el pasillo (hoy lo decide routes.json "detours"."open").

const R := 40.0           # radio del iris, px
const FOLDS := 14         # pliegues radiales
const TOUCH_R := 46.0     # a esta distancia del centro "la tocas"
const FLESH := Color("e9928f")
const FLESH_LIGHT := Color("f6b6ac")
const FLESH_DARK := Color("b8605f")
const LINE := Color("4a1a24")

## 0 cerrada .. 1 abierta (los pliegues se retraen).
var open_amount := 0.0
var wall_dir := "down"    # pared donde esta ("up", "down", "left", "right")

var _t := 0.0
var _shake := 0.0
var _touch_cd := 0.0
var _tween: Tween


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
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _inward() -> Vector2:
	return {"down": Vector2.UP, "up": Vector2.DOWN, "left": Vector2.RIGHT, "right": Vector2.LEFT}[wall_dir]


## E no hace nada: la puerta esta sellada (el cuadro de proximidad solo avisa).
func _use(_player: Node) -> void:
	_touch()


func refresh_prompt() -> void:
	if _player:
		Narrator.prompt(self, prompt_text)  # solo el aviso, sin "[E] ..."


func _process(delta: float) -> void:
	super._process(delta)
	_t += delta
	_touch_cd -= delta
	_shake = maxf(_shake - delta * 2.2, 0.0)
	if _player != null and is_instance_valid(_player) and open_amount < 0.05:
		if (_player as Node2D).global_position.distance_to(global_position) < TOUCH_R + 14.0 and _touch_cd <= 0.0:
			_touch()
	queue_redraw()


func _touch() -> void:
	if _touch_cd > 0.0 or open_amount > 0.05:
		return
	_touch_cd = 1.4
	_shake = 1.0
	Sound.play("locked")
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position + _inward() * 36.0, tr("PAS_SEALED_TOUCH"), Color("ff8f8f"))


## Animacion de apertura (los pliegues se retraen). Para cuando se decida la condicion.
func open(time := 1.4) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "open_amount", 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw() -> void:
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
