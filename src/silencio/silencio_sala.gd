class_name SilencioSala
extends Node2D

## Base de las salas de situacion del Silencio (S1 Turno, S2 Espacio, S3 Revision, S4 Mensajes). Cuelga
## de su Room (se libera con el piso) y la crea Silencio.on_enter_room. Contrato:
##  - setup(main, room): la crea; entonces arma su decorado (build) una sola vez.
##  - enter(): el heroe entra a la sala. La 1a vez llama a start() (la situacion arranca); las demas
##    solo retoma el proceso. leave(): el heroe sale (stop()).
##  - Nunca hay dano, fracaso ni premio: la sala solo muestra lo que pasa. Cuando la situacion cierra
##    llama a conclude(cartel, evento de codice): el cartel final y la entrada del codice (sin cifras).

var main: Node
var room: Room
var started := false
var concluded := false
var inside := false
var _decor: Array = []


func setup(main_: Node, room_: Node) -> void:
	main = main_
	room = room_ as Room
	build()


## Decorado de la sala (se llama una vez, al crearla). En local de la sala; el piso lo pone Silencio.
func build() -> void:
	pass


## La situacion arranca (primera vez que entras).
func start() -> void:
	pass


## Dejas la sala (o el juego la apaga): recoge lo que haya puesto en pantalla.
func stop() -> void:
	pass


func enter() -> void:
	inside = true
	set_process(true)
	if not started:
		started = true
		start()


func leave() -> void:
	inside = false
	Silencio.hint("")
	stop()


func hero() -> Player:
	return main.player


func size_px() -> Vector2:
	return Vector2(room.floor_tilemap.get_used_rect().size) * 64.0


## Posicion de mundo de un punto local de la sala.
func to_world(p: Vector2) -> Vector2:
	return room.global_position + p


## true si el heroe esta dentro de `radius` px del punto local `p`.
func hero_near(p: Vector2, radius: float) -> bool:
	return hero().global_position.distance_to(to_world(p)) <= radius


## Dibujo suelto del decorado (sobre el suelo, bajo el heroe). pos = esquina superior izquierda... salvo
## `feet`: entonces pos es el centro de la base del dibujo.
func sprite(name: String, pos: Vector2, feet := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SilencioFigura.tex(name)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	if feet:
		s.offset = Vector2(0, -s.texture.get_height() * 0.5)
	else:
		s.centered = false
	room.props_node.add_child(s)
	_decor.append(s)
	return s


func figure(pose: String, pos: Vector2, tint := Color.WHITE) -> SilencioFigura:
	var f := SilencioFigura.make(pose, pos, tint)
	room.props_node.add_child(f)
	_decor.append(f)
	return f


## Cuerpo macizo (mesa, escritorio, banco): el heroe no lo atraviesa. rect en local de la sala.
func solid(rect: Rect2) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	b.position = rect.get_center()
	var c := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = rect.size
	c.shape = sh
	b.add_child(c)
	room.add_child(b)
	_decor.append(b)
	return b


## Burbuja colgada sobre el punto local `at` (la cabeza de quien habla). secs 0 = se queda.
func say(at: Vector2, text: String, secs: float, paper := SilencioBurbuja.PAPER) -> SilencioBurbuja:
	var b := SilencioBurbuja.create(text, paper)
	room.props_node.add_child(b)
	b.z_index = 3
	b.hang_over(at)
	if secs > 0.0:
		get_tree().create_timer(secs).timeout.connect(func():
			if is_instance_valid(b):
				b.queue_free())
	return b


## Cartel final de la situacion y entrada de codice. Una sola vez.
func conclude(lines: Array, lore_event: String) -> void:
	if concluded:
		return
	concluded = true
	Silencio.cartel(lines)
	Silencio.lore(lore_event)


## Espera `secs` mientras la sala siga viva y el heroe dentro (false = abandona la secuencia).
func wait(secs: float) -> bool:
	await get_tree().create_timer(secs).timeout
	return is_inside_tree() and inside
