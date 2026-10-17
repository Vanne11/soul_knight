extends Node
class_name ItemSlots

## Las 4 ranuras de objetos (teclas 1-4, cruceta del mando) y los efectos de lo que se
## guarda en ellas. Es un hijo del jugador (ItemSlots.of(player) lo crea si falta).
##
## - Objetos de ranura (custom_data.slot = true, ver ItemDatabase): al recogerlos NO se aplican,
##   se guardan (se apilan hasta max_stack) y se usan con 1-4. Con las 4 ranuras ocupadas por otros
##   objetos se usan al instante, como antes de que existieran las ranuras.
## - Maldiciones (custom_data.curse = true): ocupan una ranura hasta que la quitas con una llave.
## - Pasivos (reliquias, armas): no ocupan ranura.
## - Sets por reino: 3 objetos distintos del mismo reino (afinidad pene/vulva, o su etiqueta
##   masculino/femenino) dan un bonus; el heroe de ese reino lo recibe x1.5 (ornitorrinco x1.25).

signal changed

const COUNT := 4
const SET_SIZE := 3
## Llaves que abren la jaula maldita (se gasta la primera que lleves).
const CURSE_KEYS := ["key_bloody", "key_drunk", "key_crystal", "key_master"]
## Bonus de set: multiplicadores (stat -> mult) o sumas ("crit_chance": suma).
const SETS := {
	"pene": {"mods": {"damage": 1.10, "crit_chance": 0.05}, "color": "6ec6ff"},
	"vulva": {"mods": {"fire_rate": 1.10, "stamina_regen": 1.20}, "color": "ff7ac0"},
}
const ADDITIVE_STATS := ["crit_chance", "lifesteal"]

## [{"id": String, "qty": int}] o {} si esta vacia. Las maldiciones llevan "applied".
var slots: Array = []
var player: Node
var _stats: Node
var _db: Node
var _sets_on := {}  # reino -> [[stat, valor aplicado]]
var _chafe_left := 0.0
var _chafe_mult := 1.0
var _squeak_t := 3.0
var _narr_pending: Array[String] = []
var last_used := -1  # ultima ranura usada (para el destello del HUD)
var uses := 0  # veces que se uso una ranura (para pruebas)


static func of(p: Node) -> ItemSlots:
	var m := p.get_node_or_null("ItemSlots") as ItemSlots
	if m == null:
		m = ItemSlots.new()
		m.name = "ItemSlots"
		p.add_child(m)
	return m


static func find(p: Node) -> ItemSlots:
	return p.get_node_or_null("ItemSlots") as ItemSlots if p else null


func _init() -> void:
	for _i in COUNT:
		slots.append({})


func _ready() -> void:
	player = get_parent()
	_stats = get_node("/root/PlayerStats")
	_db = get_node("/root/ItemDatabase")
	get_node("/root/GlobalEvents").item_picked_up.connect(_on_picked)


# ------------------------------------------------------------------ consultas
## Reino de un objeto ("pene", "vulva" o "" si es neutral): afinidad y, si no, etiqueta.
static func kingdom_of(item) -> String:
	if "hormona" in item.tags:
		return ""
	var aff: String = item.custom_data.get("affinity", "")
	if aff == "pene" or aff == "vulva":
		return aff
	if "masculino" in item.tags:
		return "pene"
	if "femenino" in item.tags:
		return "vulva"
	return ""


## Objetos distintos del reino recogidos en la partida (cuentan aunque ya los hayas gastado).
func set_count(kingdom: String) -> int:
	var n := 0
	for id in player.collected_items:
		var it = _db.get_item(id)
		if it != null and kingdom_of(it) == kingdom:
			n += 1
	return n


func set_active(kingdom: String) -> bool:
	return _sets_on.has(kingdom)


func has_curse() -> bool:
	for s in slots:
		if not s.is_empty() and s.has("applied"):
			return true
	return false


func free_slot() -> int:
	for i in COUNT:
		if slots[i].is_empty():
			return i
	return -1


func slot_of(item_id: String) -> int:
	for i in COUNT:
		if not slots[i].is_empty() and slots[i].id == item_id:
			return i
	return -1


## Por que no se puede recoger este objeto ("" = se puede). Lo consultan item_pickup y shop_item.
static func pickup_block(p: Node, item) -> String:
	var m := find(p)
	if m == null:
		return ""
	if m.has_curse() and (item.custom_data.get("hormone", "") != "" or "hormona" in item.tags):
		return "FX_CAGE_NO_HORMONE"
	if item.custom_data.get("curse", false) and m.free_slot() < 0:
		return "FX_CURSE_NO_SLOT"
	return ""


## Linea de BBCode del cuadro de objeto: avisa de que va a una ranura o de que esta maldito.
static func hint_line(item) -> String:
	if item.custom_data.get("curse", false):
		return "\n[font_size=12][color=#c05a5a]%s[/color][/font_size]" % TranslationServer.translate("PICKUP_CURSE_HINT")
	if item.custom_data.get("slot", false):
		return "\n[font_size=12][color=#9be8ff]%s[/color][/font_size]" % TranslationServer.translate("PICKUP_SLOT_HINT")
	return ""


func status_lines() -> Array[String]:
	var out: Array[String] = []
	for k in SETS:
		var n := set_count(k)
		if n > 0:
			var nm := tr("SET_%s_NAME" % k.to_upper())
			out.append(tr("HUD_SET_ON") % nm if set_active(k) else tr("HUD_SET_PROGRESS") % [nm, mini(n, SET_SIZE), SET_SIZE])
	if _chafe_left > 0.0:
		out.append("%s %ds" % [tr("STATUS_CHAFE"), ceili(_chafe_left)])
	return out


# ------------------------------------------------------------------ guardar
func _on_picked(item: Variant, _qty: int) -> void:
	if item == null or player == null:
		return
	if item.custom_data.get("slot", false):
		if not _store(item):
			_toast(tr("FX_SLOT_FULL"), Color("ffd75a"))
			use_item(item)
	elif item.custom_data.get("curse", false):
		_equip_curse(item)
	_queue_narration("item_get_" + item.id)
	_recount_sets()


func _store(item: Item) -> bool:
	var cap := maxi(1, item.max_stack)
	for i in COUNT:  # primero se apila en una ranura del mismo objeto que aun tenga hueco
		if not slots[i].is_empty() and slots[i].id == item.id and not slots[i].has("applied") and slots[i].qty < cap:
			slots[i].qty += 1
			_changed()
			return true
	var f := free_slot()
	if f < 0:
		return false
	slots[f] = {"id": item.id, "qty": 1}
	_changed()
	return true


func _equip_curse(item: Item) -> void:
	var i := free_slot()
	if i < 0:
		i = COUNT - 1  # solo por depuracion: el pickup normal ya lo impide
	var boost: float = player.affinity_boost(item)
	var applied: Array = []
	for m in item.custom_data.get("passive_mods", []):
		var v := float(m.value) * boost
		_stats.apply_stat_mod(String(m.stat), v)
		applied.append([String(m.stat), v])
	for e in item.custom_data.get("use_effects", []):
		_apply_effect(item, e, boost)
	slots[i] = {"id": item.id, "qty": 1, "applied": applied}
	_toast(tr("FX_CURSED"), Color("c05a5a"))
	_changed()


# ------------------------------------------------------------------ usar
func use_slot(i: int) -> bool:
	if i < 0 or i >= COUNT or slots[i].is_empty():
		return false
	var s: Dictionary = slots[i]
	var item = _db.get_item(s.id)
	if item == null:
		slots[i] = {}
		_changed()
		return false
	if s.has("applied"):
		return _try_free_from_curse(i, item)
	last_used = i
	use_item(item)
	s.qty -= 1
	if s.qty <= 0:
		slots[i] = {}
	_changed()
	return true


## Aplica los efectos de un objeto de ranura (afinidad del heroe incluida).
func use_item(item: Item) -> void:
	uses += 1
	var boost: float = player.affinity_boost(item)
	if boost > 1.0:
		_toast(tr("FX_AFFINITY_FIT"), Color("ffd75a"), -58.0)
	for e in item.custom_data.get("use_effects", []):
		_apply_effect(item, e, boost)
	var chafe: Dictionary = item.custom_data.get("chafe", {})
	if not chafe.is_empty():
		_start_chafe(float(chafe.speed), float(chafe.seconds))
	_toast(Loc.item_name(item), Color("9be8ff"))
	Sound.play("pickup")
	get_node("/root/GlobalEvents").item_used.emit(item)
	_queue_narration("item_use_" + item.id)


func _apply_effect(item: Item, e: Dictionary, boost: float) -> void:
	match int(e.type):
		3:
			_stats.restore_shields_full()
		4:
			if e.get("custom_data", {}).get("cleanse", false):
				_stats.clear_contagion()
				player.stop_allergy()
		7:
			ItemActions.run(player, item, e.get("custom_data", {}), boost)
		17, 18:
			var d: Dictionary = e.duplicate()
			d.duration = float(e.duration) * boost
			_stats.apply_item_effect(d)
		_:
			player.apply_item_effect(e, boost)


## Prueba para el bot: usa el primer objeto de ranura con esa etiqueta.
func use_first_with_tag(tag: String) -> bool:
	for i in COUNT:
		if slots[i].is_empty() or slots[i].has("applied"):
			continue
		var it = _db.get_item(slots[i].id)
		if it != null and tag in it.tags:
			return use_slot(i)
	return false


func _try_free_from_curse(i: int, item: Item) -> bool:
	for k in CURSE_KEYS:
		if player.collected_items.has(k):
			player.collected_items.erase(k)
			for a in slots[i].applied:
				_stats.apply_stat_mod(String(a[0]), -float(a[1]))
			_stats.current_shields = minf(_stats.current_shields, _stats.max_shields)
			_stats.shields_changed.emit(_stats.current_shields, _stats.max_shields)
			slots[i] = {}
			_toast(tr("FX_CURSE_FREED"), Color("7fe0a0"))
			_queue_narration("item_curse_freed")
			Sound.play("door")
			_changed()
			return true
	_toast(tr("FX_CURSE_NEEDS_KEY"), Color("c05a5a"))
	Sound.play("locked")
	return false


# ------------------------------------------------------------------ roce de la toalla de malla
func _start_chafe(mult: float, seconds: float) -> void:
	if _chafe_left > 0.0:
		_chafe_left = maxf(_chafe_left, seconds)
		return
	_chafe_mult = mult
	_chafe_left = seconds
	_stats.apply_stat_mod("speed", mult)


func _end_chafe() -> void:
	_chafe_left = 0.0
	_stats.apply_stat_mod("speed", 1.0 / _chafe_mult)
	_chafe_mult = 1.0


# ------------------------------------------------------------------ sets
func _recount_sets() -> void:
	for k in SETS:
		if _sets_on.has(k) or set_count(k) < SET_SIZE:
			continue
		var probe := Item.new()
		probe.custom_data = {"affinity": k}
		var boost: float = player.affinity_boost(probe)
		var applied: Array = []
		for stat in SETS[k].mods:
			var m: float = SETS[k].mods[stat]
			var v: float = m * boost if stat in ADDITIVE_STATS else maxf(0.2, 1.0 + (m - 1.0) * boost)
			_stats.apply_stat_mod(stat, v)
			applied.append([stat, v])
		_sets_on[k] = applied
		var nm := tr("SET_%s_NAME" % k.to_upper())
		_toast(tr("FX_SET_COMPLETE") % nm, Color(SETS[k].color), -62.0)
		Narrator.toast(nm, tr("SET_%s_DESC" % k.to_upper()), SETS[k].color)
		_queue_narration("item_set_" + k)
		_changed()


# ------------------------------------------------------------------ bucle
func _process(delta: float) -> void:
	if player == null or get_tree().paused:
		return
	for i in COUNT:
		if Input.is_action_just_pressed("slot_%d" % (i + 1)) and not Narrator.ate_input():
			use_slot(i)
	if _chafe_left > 0.0:
		_chafe_left -= delta
		if _chafe_left <= 0.0 or _stats.guard_hits <= 0:
			_end_chafe()
	# traje de latex: rechina al caminar (solo texto y un tono; el sonido propio, mas adelante)
	if player.collected_items.has("latex_suit") and player.velocity.length() > 60.0:
		_squeak_t -= delta
		if _squeak_t <= 0.0:
			_squeak_t = RNG.randf_range(2.5, 5.0)
			_toast(tr("FX_LATEX_SQUEAK"), Color("b9b9d0"), -22.0)
			Sound.play("tone_1", 0.3)
	if not _narr_pending.is_empty() and not Narrator._in_combat():
		Narrator.say_first(_narr_pending.pop_front())


func _queue_narration(event: String) -> void:
	if Narrator.has_lines(event) and event not in _narr_pending:
		_narr_pending.append(event)


func _toast(text: String, color: Color, dy := -46.0) -> void:
	get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, dy), text, color)


func _changed() -> void:
	changed.emit()
	get_node("/root/GlobalEvents").inventory_changed.emit()
