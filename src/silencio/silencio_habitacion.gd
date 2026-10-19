class_name SilencioHabitacion
extends SilencioSala

## S6. Agresion: "El pasillo", parte B, "para ti" (diseno_E3, seccion 3): la puerta siguiente. Una
## habitacion con un telefono sin pantalla y el circulo de luces del HUD (tus 3 personas de confianza,
## apagadas desde S3). Al acercarte al telefono se enciende una luz del circulo y se abre el panel "Como
## buscar ayuda" (universal: sin numeros ni selector de pais). Sin puzzle: la ayuda siempre esta ahi; el
## telefono se puede usar cuantas veces quieras ([E]).
##
## Textos (carteles de acta, sin narrador): las senales de agresion, "Es violencia. No es tu culpa." y,
## junto al telefono, la frase sobre irse. Sin dano, sin fracaso, sin recompensa. Entrada de codice
## "senales de agresion" (evento silencio_agresion).
##
## REVISAR (decision 5 de la seccion 9.1): la frase SIL_S6_RIESGO ("Si piensas irte, planealo con apoyo:
## es un momento de riesgo.") debe validarla la persona u ONG revisora antes de publicar. Base: Campbell
## et al. 2003 (la separacion eleva el riesgo). Sin culpar: no se le pide a quien sufre violencia que "evite"
## nada.
##
## Deja la luz 0 del circulo ENCENDIDA (Silencio.circle_relight(0)); las otras dos siguen apagadas.

const INTERACTABLE := preload("res://src/items/interactable.gd")
const TABLE := Vector2(380, 250)
const PHONE := Vector2(380, 232)
const NEAR_R := 120.0

var _glow: Sprite2D
var _lit := false


func build() -> void:
	sprite("puerta_adentro", Vector2(64, 76))  # la puerta, con el picaporte hacia adentro
	sprite("escritorio", TABLE)
	solid(Rect2(TABLE.x - 48, TABLE.y - 38, 96, 34))
	sprite("telefono", PHONE)  # sin pantalla: apagado
	_glow = glow(PHONE + Vector2(0, -6), 130.0, Color(1.0, 0.88, 0.55), 0.35)
	var it := INTERACTABLE.new()
	it.position = TABLE + Vector2(0, 14)
	it.prompt_text = tr("SIL_S6_TELEFONO")
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 64.0
	it.add_child(shape)
	it.collision_layer = 0
	it.collision_mask = 1
	it.used.connect(func(_p): Silencio.ayuda())
	room.props_node.add_child.call_deferred(it)


func start() -> void:
	Silencio.circle_show()
	Silencio.lore("silencio_agresion")
	Silencio.cartel([tr("SIL_S6_SENALES"), tr("SIL_S6_VIOLENCIA")])


func _process(_delta: float) -> void:
	if not inside or _lit:
		return
	if hero_near(PHONE, NEAR_R):
		_lit = true
		_light_one()


## Se enciende una luz del circulo, sale la frase sobre irse y se abre el panel de ayuda.
func _light_one() -> void:
	Silencio.circle_relight(0)
	fade_glow(_glow, 0.7, 1.5)
	Silencio.cartel([tr("SIL_S6_RIESGO")], 6.0)  # REVISAR con la revisora (ver la cabecera)
	await get_tree().create_timer(2.4).timeout
	if inside:
		Silencio.ayuda()
