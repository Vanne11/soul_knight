class_name SilencioMensajes
extends SilencioSala

## S4. Acoso: "Mensajes" (diseno_E3, seccion 3). Un salon oscuro con un solo punto de luz: tu. Llegan
## burbujas de texto desde los costados ("¿Donde estas?", "¿Con quien?", "Responde.", "Estoy esperando."),
## y cada una tiñe un poco el borde de la pantalla.
##   - Responder (interactuar) quita una burbuja y llegan dos. Ignorarlas tampoco las frena: imposible
##     vaciarlas.
##   - Tras la 3.a burbuja, el minimapa muestra "Te siguen": un punto que avanza detras de ti.
##   - La salida (el portal al resto de la ruta) abre desde el principio. Si caminas sin responder, las
##     burbujas se acumulan pero no frenan nada: no hay forma correcta. El cartel lo dice.
##   - Un boton "Como buscar ayuda" siempre visible en la sala.
## Sin dano, sin recompensa, sin fracaso. Entrada de codice "acoso y control: los mensajes" (evento
## silencio_mensajes).

const MESSAGES := ["SIL_S4_MSG_1", "SIL_S4_MSG_2", "SIL_S4_MSG_3", "SIL_S4_MSG_4"]
const FIRST_AT := 2.0         # s hasta el primer mensaje
const EVERY := 3.2            # s entre mensajes
const ANSWER_ECHO := [0.5, 1.1]  # al responder llegan dos: a estos segundos
const FOLLOW_AFTER := 3       # con la 3.a burbuja empieza "Te siguen"
const FOLLOW_LAG := 16        # muestras (0.1 s) de distancia entre tu y el punto que te sigue
const CARTEL_AT := 15.0       # s hasta el cartel final
const HALO := 170.0           # radio (pantalla, px) del punto de luz
const EXIT_AT := Vector2(200, 0)  # el portal, a la derecha del centro de la sala

var _hud: SilencioMensajesHud
var _halo: CanvasLayer
var _halo_mat: ShaderMaterial
var _help_layer: CanvasLayer
var _t := 0.0
var _next := 0.0
var _msg_i := 0
var _echo: Array = []          # segundos pendientes de las burbujas que llegan al responder
var _trail: Array = []         # donde has estado (local de la sala), una muestra cada 0.1 s
var _trail_t := 0.0
var _portal_pos := Vector2.ZERO
var _following := false


func build() -> void:
	pass  # el salon esta vacio: la oscuridad es el decorado


func start() -> void:
	_t = 0.0
	_next = FIRST_AT
	_hud = SilencioMensajesHud.new()
	main.add_child(_hud)
	_start_halo()
	_start_help_button()
	# la salida abre desde el principio (no hay nada que hacer para ganarla)
	main.open_exit(room, int(get_node("/root/RunManager").current_floor), EXIT_AT, tr("SIL_S4_SALIDA"))
	_portal_pos = room.get_center_position() + EXIT_AT


func stop() -> void:
	_set_active(false)


func enter() -> void:
	super()
	_set_active(true)


## La sala se libera con el piso (portal de salida): la oscuridad y los mensajes no pasan al siguiente.
func _exit_tree() -> void:
	for n in [_hud, _halo, _help_layer]:
		if n != null and is_instance_valid(n):
			n.queue_free()


func _set_active(on: bool) -> void:
	for n in [_hud, _halo, _help_layer]:
		if n != null and is_instance_valid(n):
			n.visible = on
	if on:
		Silencio.hint(tr("SIL_S4_HINT"))


func _process(delta: float) -> void:
	if not inside or _hud == null:
		return
	_t += delta
	Silencio.hint(tr("SIL_S4_HINT"))
	# llegan mensajes sin parar, respondas o no
	if _t >= _next:
		_next += EVERY
		_receive()
	for i in range(_echo.size() - 1, -1, -1):
		_echo[i] -= delta
		if _echo[i] <= 0.0:
			_echo.remove_at(i)
			_receive()
	# responder: interactuar (si no hay otra cosa a mano, como la salida)
	if Input.is_action_just_pressed("interact") and Narrator.prompt_owner == null:
		_hud.answer()
		_echo.append_array(ANSWER_ECHO)
	_update_trail(delta)
	_update_halo()
	if _t >= CARTEL_AT:
		conclude([tr("SIL_S4_CARTEL_1"), tr("SIL_S4_CARTEL_2"), tr("SIL_S4_CARTEL_3")], "silencio_mensajes")


func _receive() -> void:
	_hud.receive(tr(MESSAGES[_msg_i % MESSAGES.size()]))
	_msg_i += 1
	if _msg_i >= FOLLOW_AFTER:
		_following = true


func _update_trail(delta: float) -> void:
	_trail_t -= delta
	if _trail_t > 0.0:
		return
	_trail_t = 0.1
	_trail.append(hero().global_position - room.global_position)
	if _trail.size() > FOLLOW_LAG + 1:
		_trail.pop_front()


## Minimapa: "Te siguen" y un punto que avanza detras de ti (Silencio.draw_minimap lo llama).
func draw_follower(canvas: Control, room_rect: Rect2) -> void:
	if not _following or _trail.is_empty():
		return
	var rs := size_px()
	var p: Vector2 = _trail[0]
	var at := room_rect.position + Vector2(p.x / rs.x * room_rect.size.x, p.y / rs.y * room_rect.size.y)
	canvas.draw_circle(at, 6.0, Color(0.95, 0.95, 0.98, 0.3))
	canvas.draw_circle(at, 3.5, Color("f2f1ed"))
	canvas.draw_string(HudStyle.FONT, Vector2(10, canvas.size.y - 10), tr("SIL_S4_TE_SIGUEN"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f2f1ed"))


## Un solo punto de luz: tu. La pantalla casi negra salvo el halo del heroe y un brillo tenue en la
## salida (misma tecnica que el apagon de los jefes: src/shaders/blackout.gdshader).
func _start_halo() -> void:
	_halo = CanvasLayer.new()
	_halo.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo_mat = ShaderMaterial.new()
	_halo_mat.shader = load("res://src/shaders/blackout.gdshader")
	_halo_mat.set_shader_parameter("rad_a", HALO)
	_halo_mat.set_shader_parameter("rad_b", 44.0)
	_halo_mat.set_shader_parameter("tint", Vector3(0.01, 0.015, 0.03))
	_halo_mat.set_shader_parameter("amount", 0.0)
	rect.material = _halo_mat
	_halo.add_child(rect)
	main.add_child(_halo)
	main.move_child(_halo, mini(1, main.get_child_count() - 1))  # bajo el HUD, sobre el mundo
	create_tween().tween_property(_halo_mat, "shader_parameter/amount", 0.95, 1.2)


func _update_halo() -> void:
	var to_screen := get_viewport().get_canvas_transform()
	_halo_mat.set_shader_parameter("vp_size", get_viewport().get_visible_rect().size)
	_halo_mat.set_shader_parameter("hole_a", to_screen * (hero().global_position + Vector2(0, -10)))
	_halo_mat.set_shader_parameter("hole_b", to_screen * to_world(_portal_pos))


## El boton "Como buscar ayuda", grande y a la vista en esta sala (ademas del boton siempre visible).
func _start_help_button() -> void:
	_help_layer = CanvasLayer.new()
	_help_layer.layer = 7
	var b := Button.new()
	b.text = tr("SIL_AYUDA_BOTON")
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", HudStyle.FONT)
	b.add_theme_font_size_override("font_size", 16)
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.grow_horizontal = Control.GROW_DIRECTION_BOTH
	b.grow_vertical = Control.GROW_DIRECTION_BEGIN
	b.offset_bottom = -70
	b.custom_minimum_size = Vector2(300, 40)
	b.pressed.connect(Silencio.ayuda)
	_help_layer.add_child(b)
	main.add_child(_help_layer)
