class_name Affix
extends Node

## Base de un afijo de elite: nodo hijo del enemigo. Las subclases (affix_<id>.gd) sobreescriben
## pre_setup() (antes del _ready del enemigo: aqui se tocan estadisticas, la IA copia luego sus
## bases), setup() (una vez, ya con el enemigo listo), tick(delta) (cada frame de fisica, solo
## vivo), filter_damage() y on_death().

## Modos de IA en los que el enemigo esta activo y hostil (el resto: dormido, pastando/neutral,
## huyendo, rendido, caparazon, descarga, inspeccion, rafaga, cobertura).
const CALM_MODES := [EnemyAI.Mode.CALM, EnemyAI.Mode.SEARCH, EnemyAI.Mode.PATROL, EnemyAI.Mode.PAUSE, EnemyAI.Mode.RETURN]

var id := ""
var tag: AffixTag = null
var host: Node2D = null
var _dead := false
var _ready_done := false


func _ready() -> void:
	host = get_parent() as Node2D
	pre_setup()


func pre_setup() -> void:
	pass


func setup() -> void:
	pass


func tick(_delta: float) -> void:
	pass


func filter_damage(amount: float, _source: Node) -> float:
	return amount


func on_death() -> void:
	pass


func _physics_process(delta: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	if not _ready_done:
		_ready_done = true
		setup()
	if _dead:
		return
	if float(host.get("current_health")) <= 0.0:
		_dead = true
		if tag != null and not tag.ids.is_empty() and tag.ids[0] == id:  # una sola vez por elite: desbloquea el codice
			get_node("/root/LoreDatabase").custom_event("elite")
		on_death()
		return
	tick(delta)


# ------------------------------------------------------------------ utilidades
func player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func dist_to_player() -> float:
	var p := player()
	return host.global_position.distance_to(p.global_position) if p != null else INF


func ai() -> EnemyAI:
	var a = host.get("ai")
	return a if a is EnemyAI else null


## True si el enemigo esta en pleno ataque (aviso/embestida/disparo) o la IA lo controla
## (dormido, huyendo, rendido...): ahi un afijo activo seria injusto o romperia la personalidad.
func busy() -> bool:
	var e = host.get("State")
	if e is Dictionary:
		var nm = e.find_key(host.get("state"))
		if nm != null and String(nm) in EnemyAI.COMMITTED:
			return true
	var a := ai()
	if a != null and a.mode not in CALM_MODES:
		return true
	return false


func container() -> Node:
	if host.has_method("_spawn_container"):
		return host._spawn_container()
	return host.get_parent()


func say(text: String, offset := Vector2(0, -52)) -> void:
	get_node("/root/GlobalEvents").show_floating_text.emit(host.global_position + offset, text, Affixes.color_of(id))


func in_room(pos: Vector2) -> bool:
	var room = host.find_owning_room() if host.has_method("find_owning_room") else null
	if room == null:
		return true
	var fl: TileMap = room.floor_tilemap
	return fl != null and fl.get_cell_source_id(0, fl.local_to_map(fl.to_local(pos))) != -1


## Punto libre de paredes/obstaculos (capa 1) y dentro del suelo de la sala.
func free_spot(pos: Vector2, radius := 14.0) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	for off in [Vector2.ZERO, Vector2(radius, 0), Vector2(-radius, 0), Vector2(0, radius), Vector2(0, -radius)]:
		if not in_room(pos + off):
			return false
		q.position = pos + off
		if not host.get_world_2d().direct_space_state.intersect_point(q, 1).is_empty():
			return false
	return true
