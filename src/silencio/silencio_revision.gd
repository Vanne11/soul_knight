class_name SilencioRevision
extends SilencioSala

## S3. Control: "Revision" (diseno_E3, seccion 3). Un cuarto con un escritorio y una silueta sentada de
## espaldas con una linterna baja; lampara de escritorio de luz amarilla.
##   1. Al entrar se abre sola tu pantalla de INVENTARIO (SilencioInventario): un cursor ajeno recorre tus
##      armas y objetos, cada uno con una pregunta. Esc no la cierra los primeros 8 s.
##   2. Te guardan el arma: queda en gris y fuera de tu mano hasta cruzar la puerta (nunca se pierde:
##      Silencio.restore_weapon, que tambien corre al salir por cualquier lado y al cambiar de piso).
##   3. Aparece por primera vez el CIRCULO en el HUD: 3 luces, tus personas de confianza. Mientras la
##      silueta revisa, se apagan de a una (y la lampara baja con ellas).
##   4. Puedes ignorarla y salir. Si le hablas, solo repite la pregunta.
## Sin dano, sin recompensa, sin fracaso. Cartel final y entrada de codice "senales de control"
## (evento silencio_revision).

const INTERACTABLE := preload("res://src/items/interactable.gd")
const DESK := Vector2(352, 168)       # base del escritorio
const WATCHER := Vector2(352, 214)    # la silueta sentada de espaldas
const LAMP := Vector2(316, 150)

var _glow: Sprite2D
var _cone: Polygon2D
var _bubble: SilencioBurbuja
var _t := 0.0


func build() -> void:
	sprite("escritorio", DESK)
	solid(Rect2(DESK.x - 48, DESK.y - 38, 96, 34))
	sprite("silla", WATCHER + Vector2(0, 6))
	var who := figure("espalda", WATCHER, Color(0.9, 0.9, 0.96))
	who.z_index = 0
	sprite("lampara", LAMP)
	# la linterna baja: un cono tenue hacia el suelo, a la derecha de la silueta
	_cone = Polygon2D.new()
	_cone.polygon = PackedVector2Array([Vector2(0, 0), Vector2(-34, 74), Vector2(34, 74)])
	_cone.color = Color(1.0, 0.95, 0.75, 0.1)
	_cone.position = WATCHER + Vector2(30, -6)
	_cone.material = LightKit.unshaded_material()
	room.props_node.add_child(_cone)
	_decor.append(_cone)
	# resplandor de la lampara: amarillo, aditivo, se apaga con el circulo
	_glow = Sprite2D.new()
	var g := GradientTexture2D.new()
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	g.width = 128
	g.height = 128
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 0.86, 0.45, 0.55), Color(1.0, 0.86, 0.45, 0.0)])
	g.gradient = grad
	_glow.texture = g
	_glow.scale = Vector2(2.6, 2.6)
	_glow.position = LAMP + Vector2(0, -12)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow.material = mat
	room.props_node.add_child(_glow)
	_decor.append(_glow)
	var it := INTERACTABLE.new()  # hablarle: solo repite la pregunta
	it.position = WATCHER + Vector2(0, 8)
	it.prompt_text = tr("SIL_S3_HABLAR")
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 46.0
	it.add_child(shape)
	it.collision_layer = 0
	it.collision_mask = 1
	it.used.connect(func(_p): _repeat_question())
	room.props_node.add_child.call_deferred(it)


func start() -> void:
	await get_tree().create_timer(0.7).timeout
	if not inside:
		return
	var inv := SilencioInventario.open(main, hero())
	await inv.closed
	var lines := [tr("SIL_S3_CARTEL_1"), tr("SIL_S3_CARTEL_2"), tr("SIL_S3_CARTEL_3")]
	if Silencio.weapon_held() != null:
		lines.push_front(tr("SIL_S3_DEVUELVEN"))  # el cartel lo dice: no se pierde, se devuelve al salir
	conclude(lines, "silencio_revision")


## Al salir, por la puerta que sea, te devuelven lo que te guardaron.
func stop() -> void:
	Silencio.restore_weapon(hero())
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()


func _repeat_question() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = say(WATCHER + Vector2(0, -46), tr("SIL_S3_PREGUNTA"), 3.0)


func _process(delta: float) -> void:
	_t += delta
	# la lampara baja con el circulo: 3 luces = plena, 0 = casi apagada
	var want := 0.25 + 0.75 * float(Silencio.circle_lit()) / 3.0 if Silencio.circle_shown else 1.0
	_glow.modulate.a = move_toward(_glow.modulate.a, want, delta * 0.5)
	_cone.rotation = sin(_t * 0.7) * 0.18
