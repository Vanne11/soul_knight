class_name ContemplationMode
extends RefCounted

## ESTADO DE CONTEMPLACION (diseno_E3_silencio.md, 6.1): lo usa la sala de memoria de Las Tierras del
## Silencio (S7, src/silencio/silencio_memoria.gd), tambien como "Memorial" del reino liberado. Mientras
## esta activo:
##  - no hay enemigos, botin, logros, numeros flotantes, contadores ni temporizador (la sala no los crea;
##    ademas FloatingTextManager ignora todo texto flotante);
##  - el arma se baja sola (1,2 s: se desvanece y se guarda; Silencio.stash_weapon) y NO dispara ni hace
##    dash (Player._handle_attack / _handle_dash lo consultan);
##  - el heroe camina lento: WALK_SPEED px/s (Player._handle_movement; el normal ronda 250). REVISAR el valor
##    probandolo con personas (decision 8 de 9.1);
##  - el HUD se oculta; solo quedan el boton "Como buscar ayuda" (SilencioHud) y la pausa;
##  - sin musica (el reino no tiene) y sin narrador.
## Nada se guarda por vela: no hay contadores ni progreso. Se sale cuando se quiera: la puerta esta abierta.

const WALK_SPEED := 90.0
const LOWER_SECS := 1.2

static var active := false
static var _tween: Tween = null


## Entra en contemplacion (main = el nodo "main"). Idempotente.
static func begin(main: Node) -> void:
	if active:
		return
	active = true
	var tree := main.get_tree()
	var hud := main.get_node_or_null("HUD")
	if hud is CanvasLayer:
		hud.visible = false
	for h in tree.get_nodes_in_group(Silencio.GROUP_HUD):
		h.set_contemplation(true)
	_lower_weapon(main.player)


## Sale de contemplacion: devuelve el HUD y el arma. Idempotente.
static func end(main: Node) -> void:
	if not active:
		return
	active = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	if main == null or not is_instance_valid(main):
		return
	var hud := main.get_node_or_null("HUD")
	if hud is CanvasLayer:
		hud.visible = true
	for h in main.get_tree().get_nodes_in_group(Silencio.GROUP_HUD):
		h.set_contemplation(false)
	var player: Player = main.player
	if player != null and is_instance_valid(player):
		player.weapon_pivot.modulate.a = 1.0
		Silencio.restore_weapon(player)


## Limpia el estado sin tocar nada de la escena (al generar otro piso o salir al menu).
static func reset() -> void:
	active = false
	_tween = null


## El arma se baja sola: se desvanece en LOWER_SECS y queda guardada (no dispara).
static func _lower_weapon(player: Player) -> void:
	if player == null or player.current_weapon == null:
		return
	var pivot := player.weapon_pivot
	_tween = player.create_tween()
	_tween.tween_property(pivot, "modulate:a", 0.0, LOWER_SECS).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func():
		if active and is_instance_valid(player):
			Silencio.stash_weapon(player)
			pivot.modulate.a = 1.0)
