class_name ArcoiriaPowers
extends Node

## Los PODERES DE COLORES de Arcoiria: un objeto por franja de la bandera (assets/data/items/
## bandera_<color>.tres). Los numeros fijos (vida, escudo, dano) los pone el propio objeto al
## recogerlo; lo que hace falta vigilar vive aqui, un efecto por color y cada uno con su significado:
##   rojo      VIDA          +vida maxima, y curas un poco al liberar cada sala
##   naranja   SANACION      regeneras vida sola si llevas unos segundos sin recibir dano
##   amarillo  LUZ           tu halo es mas grande y cada tanto el pulso de luz REVELA a los enemigos
##   verde     NATURALEZA    espinas: si te golpean, brotan y hieren a lo que tienes cerca
##   azul      SERENIDAD     +escudo y regeneracion de escudo; al liberar una sala, escudo lleno
##   violeta   ESPIRITU      +dano y un fuego fatuo que cada tanto busca al enemigo mas cercano
## Con las seis, la sinergia "Bandera completa" (Synergies.TABLE) y un pulso arcoiris de adorno.
## Es hijo del jugador (Arcoiria.setup_floor lo crea; los poderes se miran en collected_items).

const HEAL_ON_CLEAR := 2.0
const REGEN_AFTER := 3.0
const REGEN_RATE := 0.45
const REVEAL_EVERY := 7.0
const REVEAL_SECS := 3.0
const THORNS_RADIUS := 105.0
const THORNS_DAMAGE := 14.0
const WISP_EVERY := 5.0
const WISP_RANGE := 440.0
const WISP_DAMAGE := 22.0
const HALO_MULT := 1.35

var player: Node2D
var _ps: Node
var _ge: Node
var _since_hit := 0.0
var _regen_acc := 0.0
var _reveal_t := 3.0
var _wisp_t := 2.5
var _pulse_t := 2.0
var _pulse_i := 0
var _halo_done := false
var _halo_base := 1.0


## Lo crea si falta. force = false: solo si ya traes algun poder (pisos de otros reinos).
static func ensure(p: Node, force: bool) -> void:
	if p == null or p.get_node_or_null("ArcoiriaPowers") != null:
		return
	if not force and not _has_any(p):
		return
	var n := ArcoiriaPowers.new()
	n.name = "ArcoiriaPowers"
	p.add_child(n)


static func _has_any(p: Node) -> bool:
	for id in Arcoiria.power_ids():
		if p.collected_items.has(id):
			return true
	return false


func _ready() -> void:
	player = get_parent() as Node2D
	_ps = get_node("/root/PlayerStats")
	_ge = get_node("/root/GlobalEvents")
	_ge.player_damaged.connect(_on_player_damaged)


func _exit_tree() -> void:
	_restore_halo()
	if _ge != null and _ge.player_damaged.is_connected(_on_player_damaged):
		_ge.player_damaged.disconnect(_on_player_damaged)


func has(color: String) -> bool:
	return player != null and player.collected_items.has("bandera_" + color)


func complete() -> bool:
	for id in Arcoiria.power_ids():
		if not player.collected_items.has(id):
			return false
	return true


## Arcoiria.on_room_cleared lo llama al liberar cualquier sala (de cualquier reino).
func room_freed() -> void:
	if has("rojo"):
		_ps.heal(HEAL_ON_CLEAR)
	if has("azul"):
		_ps.restore_shields_full()


func _on_player_damaged(_amount: float, _source: Node) -> void:
	_since_hit = 0.0
	if has("verde"):
		var at := player.global_position
		Arcoiria.ring(at, Arcoiria.STRIPES[3].color, THORNS_RADIUS)
		Arcoiria.burst(at, THORNS_RADIUS, THORNS_DAMAGE * float(_ps.damage_modifier), player)


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or get_tree().paused:
		return
	_since_hit += delta
	if has("naranja") and _since_hit >= REGEN_AFTER and float(_ps.current_health) < float(_ps.max_health):
		_regen_acc += REGEN_RATE * delta
		if _regen_acc >= 1.0:
			_ps.heal(floorf(_regen_acc))
			_regen_acc -= floorf(_regen_acc)
	_halo_step()
	if has("amarillo"):
		_reveal_t -= delta
		if _reveal_t <= 0.0:
			_reveal_t = REVEAL_EVERY
			_reveal_pulse()
	if has("violeta"):
		_wisp_t -= delta
		if _wisp_t <= 0.0:
			_wisp_t = WISP_EVERY
			_wisp()
	if complete():
		_pulse_t -= delta
		if _pulse_t <= 0.0:
			_pulse_t = 2.4
			Arcoiria.ring(player.global_position, Arcoiria.stripe(_pulse_i).color, 46.0, 0.7)
			_pulse_i += 1


## Luz: el halo del heroe (lo pone RoomLighting en el meta "rl_own") crece una vez.
func _halo_step() -> void:
	var l = player.get_meta("rl_own", null)
	if has("amarillo") and not _halo_done and l is PointLight2D and is_instance_valid(l):
		_halo_done = true
		_halo_base = (l as PointLight2D).texture_scale
		(l as PointLight2D).texture_scale = _halo_base * HALO_MULT


func _restore_halo() -> void:
	if _halo_done and player != null and is_instance_valid(player):
		var l = player.get_meta("rl_own", null)
		if l is PointLight2D and is_instance_valid(l):
			(l as PointLight2D).texture_scale = _halo_base
	_halo_done = false


func _reveal_pulse() -> void:
	Arcoiria.ring(player.global_position, Arcoiria.STRIPES[2].color, 260.0, 0.6)
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("reveal"):
			e.reveal(REVEAL_SECS)


## Fuego fatuo: busca al enemigo mas cercano al alcance y le pega (ignora lo que lo proteja).
func _wisp() -> void:
	var best: Node2D = null
	var best_d := WISP_RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or not (e is Node2D) or e.is_queued_for_deletion():
			continue
		if float(e.get("current_health")) <= 0.0:
			continue
		var d: float = (e as Node2D).global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = e
	if best == null:
		return
	var col: Color = Arcoiria.STRIPES[5].color
	Arcoiria.ring(player.global_position, col, 36.0, 0.3)
	var target := best
	get_tree().create_timer(0.25).timeout.connect(func():
		if is_instance_valid(target) and not target.is_queued_for_deletion() and target.has_method("take_damage"):
			Arcoiria.ring(target.global_position, col, 60.0, 0.4)
			target.take_damage(WISP_DAMAGE * float(_ps.damage_modifier), player, Vector2.ZERO))
