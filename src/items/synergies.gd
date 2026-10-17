extends Node
class_name Synergies

## Sinergias con nombre (etapa 6d): combos arma + bendicion, arma + objeto, bendicion +
## bendicion y set + heroe que, al cumplirse, activan un efecto extra y avisan UNA vez por
## partida con un texto flotante.
##
## Un unico sitio: la tabla TABLE de abajo. El efecto se consulta en el codigo de combate con
## una linea:  if Synergies.has("descarga_nacional"): ...   (ver player.gd, puddle.gd...).
## Las sinergias de solo estadisticas llevan "mods" y se aplican/quitan solas.
##
## Es un hijo del jugador (Synergies.of(player) lo crea si falta), como ItemSlots. Reevalua al
## cambiar bendiciones (blessings_changed), al coger objetos (item_picked_up, inventory_changed),
## al cambiar de arma (player.equip_weapon -> refresh()) y 2 veces por segundo por si cambia un
## set de reino. Textos en locale/armas_sinergias.csv: SYN_<ID>_NAME / _DESC / _COND.
##
## Requisitos de una entrada (todos deben cumplirse):
##   weapon: id de arma equipada   blessings: ids (nivel >= 1)   items: ids recogidos
##   hero: ids de heroe (cualquiera)   sets: reinos con set de objetos activo
## "any": [req, req] = basta con que se cumpla una de las alternativas.
const TABLE := {
	"descarga_nacional": {"weapon": "shotgun_pelvic", "blessings": ["calibre"]},
	"vibracion_sostenida": {"weapon": "smg_vibrator", "blessings": ["ciclo"]},
	"doble_penetracion": {"weapon": "whip", "blessings": ["penetracion"]},
	"piel_de_seda": {"weapon": "laser_depilador", "blessings": ["ciclo"]},
	"siempre_vuelve": {"weapon": "boomerang_silicona", "blessings": ["embestida"]},
	"tension_acumulada": {"weapon": "ballesta_tantrica", "blessings": ["testosterona"]},
	"fiesta_sorpresa": {"weapon": "canon_confeti", "blessings": ["descarga"]},
	"chancla_materna": {"weapon": "chancleta_voladora", "blessings": ["orgullo"]},
	"spa_improvisado": {"weapon": "globos_agua", "blessings": ["regla"]},
	"doble_proteccion": {"weapon": "preservativo_atrapabalas", "items": ["relic_condom"]},
	"lubricacion_eficiente": {"weapon": "satisfyer", "items": ["relic_lube"]},
	"corte_y_fuga": {"blessings": ["filo", "escurridiza"]},
	"orgullo_de_casa": {"any": [
		{"hero": ["pitocles"], "sets": ["pene"]},
		{"hero": ["vulvalquiria"], "sets": ["vulva"]},
	], "mods": {"damage": 1.08, "fire_rate": 1.08}},
	"todo_incluido": {"hero": ["ornitorrinco"], "sets": ["pene", "vulva"],
		"mods": {"damage": 1.12, "crit_chance": 0.06}},
}
const COLOR := Color("ffd75a")

## id -> true de las sinergias activas AHORA (consulta estatica: Synergies.has).
static var _active: Dictionary = {}
## Las que ya se han avisado esta partida (no se repite el aviso al romper y recuperar).
static var _announced: Dictionary = {}

var player: Node
var _applied: Dictionary = {}  # id -> mods aplicados a PlayerStats
var _sig := ""
var _poll := 0.0


static func has(id: String) -> bool:
	return _active.has(id)


## Ids activos en el orden de la tabla.
static func active_ids() -> Array:
	return TABLE.keys().filter(func(k): return _active.has(k))


static func discovered_count() -> int:
	return _announced.size()


static func of(p: Node) -> Synergies:
	var m := p.get_node_or_null("Synergies") as Synergies
	if m == null:
		m = Synergies.new()
		m.name = "Synergies"
		p.add_child(m)
	return m


## Nombre / descripcion / condicion traducidos de una sinergia.
static func text(id: String, field: String) -> String:
	return Loc.tr_or("SYN_%s_%s" % [id.to_upper(), field.to_upper()], id)


func _ready() -> void:
	player = get_parent()
	_active = {}
	_announced = {}
	var ge := get_node("/root/GlobalEvents")
	ge.blessings_changed.connect(refresh)
	ge.item_picked_up.connect(func(_i, _q): refresh())
	ge.inventory_changed.connect(refresh)
	refresh()


func _process(delta: float) -> void:
	_poll += delta
	if _poll >= 0.5:
		_poll = 0.0
		if _signature() != _sig:
			refresh()


func _exit_tree() -> void:
	_active = {}


# ------------------------------------------------------------------ evaluacion
func _weapon_id() -> String:
	var w = player.get("current_weapon")
	return w.id if w != null else ""


func _signature() -> String:
	var rm := get_node("/root/RunManager")
	var slots := ItemSlots.find(player)
	return "%s|%s|%d|%s%s" % [_weapon_id(), str(rm.blessings), player.collected_items.size(),
		slots != null and slots.set_active("pene"), slots != null and slots.set_active("vulva")]


func _req_ok(req: Dictionary) -> bool:
	var rm := get_node("/root/RunManager")
	if req.has("weapon") and _weapon_id() != req.weapon:
		return false
	if req.has("blessings"):
		for b in req.blessings:
			if rm.blessing(b) <= 0:
				return false
	for it in req.get("items", []):
		if not player.collected_items.has(it):
			return false
	if req.has("hero") and not (rm.character in req.hero):
		return false
	if req.has("sets"):
		var slots := ItemSlots.find(player)
		for k in req.sets:
			if slots == null or not slots.set_active(k):
				return false
	return true


func _ok(def: Dictionary) -> bool:
	if def.has("any"):
		for alt in def.any:
			if _req_ok(alt):
				return true
		return false
	return _req_ok(def)


## Reevalua la tabla: activa/desactiva efectos y avisa las nuevas (una vez por partida).
func refresh() -> void:
	_sig = _signature()
	var now := {}
	for id in TABLE:
		if _ok(TABLE[id]):
			now[id] = true
	for id in _active.keys():
		if not now.has(id):
			_revert(id)
	for id in now:
		if not _active.has(id):
			_apply(id)
	_active = now


func _apply(id: String) -> void:
	var mods: Dictionary = TABLE[id].get("mods", {})
	if not mods.is_empty():
		var ps := get_node("/root/PlayerStats")
		for stat in mods:
			ps.apply_stat_mod(stat, mods[stat])
		_applied[id] = mods
	if not _announced.has(id):
		_announced[id] = true
		_announce(id)


func _revert(id: String) -> void:
	if not _applied.has(id):
		return
	var ps := get_node("/root/PlayerStats")
	for stat in _applied[id]:
		var v: float = _applied[id][stat]
		if stat in ItemSlots.ADDITIVE_STATS:
			ps.apply_stat_mod(stat, -v)
		else:
			ps.apply_stat_mod(stat, 1.0 / v)
	_applied.erase(id)


func _announce(id: String) -> void:
	var ge := get_node("/root/GlobalEvents")
	var pos: Vector2 = player.global_position
	ge.show_floating_text.emit(pos + Vector2(0, -52), tr("FX_SYNERGY") % text(id, "name"), COLOR)
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(player):
			ge.show_floating_text.emit(player.global_position + Vector2(0, -36), text(id, "desc"), Color("fff1c4")))
	var s := get_node_or_null("/root/Sound")
	if s != null:
		s.play("puzzle_solve")
	ge.lore_unlock_requested.emit("sinergias_lore")
