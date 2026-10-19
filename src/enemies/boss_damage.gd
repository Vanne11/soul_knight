class_name BossDamage
extends RefCounted

## Dano contra jefes (plan J1c/J1d): sin criticos, tope por golpe y por segundo, el bumeran
## pega menos al volver, y tipos de dano con debilidades/resistencias por jefe (tabla en
## assets/data/boss_damage.json) mas el golpe MATCH (heroe + arma + jefe).
## Se engancha en EnemyBoss.take_damage (adjust antes de aplicar, popup para el numero, on_death).
## Las armas avisan con BossDamage.tag(...) justo antes de take_damage (mismo frame): id del arma,
## cuanto se multiplico por critico y tipo de dano. Un golpe sin tag cuenta como sin tipo ni critico.

## true = solo los jefes con entrada en la tabla (hoy Doña Cera) reciben tope, sin critico y tipos.
## false = los 12 jefes reciben tope y sin critico (los tipos siguen pidiendo tabla).
const ONLY_TABLE_BOSSES := true
const HIT_CAP_PCT := 0.035      ## tope por golpe: % de la vida maxima
const SEC_CAP_PCT := 0.04       ## tope por segundo (ventana deslizante): % de la vida maxima (~60 dps en Cera; un arma normal hace 25-40)
const WINDOW := 1.0
const MIN_PASS := 0.15          ## aunque se pase del tope por segundo, pasa esta fraccion del golpe
const BOOMERANG_RETURN_MULT := 0.25  ## la vuelta del bumeran contra jefes
const MATCH_STUN := 1.4
const MATCH_CD := 9.0           ## enfriamiento del MATCH (nada de stunlock)
const WEAK_LABEL_CD := 1.0
const RESIST_LABEL_CD := 1.6
const TABLE_PATH := "res://assets/data/boss_damage.json"
const COL_WEAK := Color("ff8a1f")
const COL_RESIST := Color("9a9aa6")
const COL_MATCH := Color("ff4fd8")

## Imprime cada golpe y el resumen al morir (el bot lo activa con --boss-dmg=1).
static var debug := false

static var _table: Dictionary = {}
static var _loaded := false
static var _tag_frame := -1
static var _tag_weapon := ""
static var _tag_crit := 1.0
static var _tag_type := ""
static var _items := {}


static func _now() -> float:
	return Engine.get_physics_frames() / float(Engine.physics_ticks_per_second)


static func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).root


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(TABLE_PATH, FileAccess.READ)
	if f == null:
		return
	var j = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		_table = j


## Datos del arma (custom_data) por id; {} si no existe.
static func _wdata(weapon_id: String) -> Dictionary:
	if weapon_id == "":
		return {}
	if not _items.has(weapon_id):
		var it = _root().get_node("ItemDatabase").get_item(weapon_id)
		_items[weapon_id] = it.custom_data if it != null else {}
	return _items[weapon_id]


## Las armas llaman esto justo antes de take_damage. crit_mult = factor por el que se
## multiplico el dano por critico (1.0 = no fue critico). dmg_type "" = el del arma.
static func tag(weapon_id: String, crit_mult := 1.0, dmg_type := "") -> void:
	_tag_frame = Engine.get_physics_frames()
	_tag_weapon = weapon_id
	_tag_crit = maxf(crit_mult, 1.0)
	_tag_type = dmg_type if dmg_type != "" else String(_wdata(weapon_id).get("dmg_type", ""))


## Id del arma que lleva el jugador (para armas que no guardan su id).
static func weapon_of(player: Node) -> String:
	if player != null and "current_weapon" in player and player.current_weapon != null:
		return String(player.current_weapon.id)
	return ""


static func _key(boss: Node) -> String:
	if boss.has_meta("bd_key"):
		return boss.get_meta("bd_key")
	var k := ""
	var s = boss.get_script()
	if s != null:
		k = String(s.resource_path).get_file().get_basename().trim_prefix("boss_")
	boss.set_meta("bd_key", k)
	return k


static func entry(boss: Node) -> Dictionary:
	_load()
	return _table.get(_key(boss), {})


## Este jefe recibe el tratamiento?
static func applies(boss: Node) -> bool:
	if not ONLY_TABLE_BOSSES:
		return true
	_load()
	return _table.has(_key(boss))


static func _state(boss: Node) -> Dictionary:
	if not boss.has_meta("bd"):
		boss.set_meta("bd", {"win": [], "max_raw": 0.0, "max_hit": 0.0, "max_wpn": "", "crits": 0,
			"cuts": 0, "weak": 0, "resist": 0, "match": 0, "match_t": -99.0, "lbl_w": -99.0,
			"lbl_r": -99.0, "said_w": false, "said_r": false, "kind": "", "match_now": false, "mult": 1.0})
	return boss.get_meta("bd")


## Ajusta el golpe `amount` que recibe `boss`. Devuelve el dano final.
static func adjust(boss: Node, amount: float, _source: Node) -> float:
	var st := _state(boss)
	var raw := amount
	var wid := ""
	var cm := 1.0
	var dt := ""
	if _tag_frame == Engine.get_physics_frames():
		wid = _tag_weapon
		cm = _tag_crit
		dt = _tag_type
		_tag_frame = -1
	st["kind"] = ""
	st["match_now"] = false
	st["mult"] = 1.0
	if raw > st["max_raw"]:
		st["max_raw"] = raw
	if not applies(boss):
		return amount
	var mx: float = boss.max_health
	if cm > 1.0:  # sin criticos contra jefes
		amount /= cm
		st["crits"] += 1
	var capped := false
	var cap := mx * HIT_CAP_PCT
	if amount > cap:
		amount = cap
		capped = true
	var now := _now()
	var win: Array = st["win"]
	while not win.is_empty() and now - float(win[0][0]) > WINDOW:
		win.pop_front()
	var used := 0.0
	for w in win:
		used += float(w[1])
	var room := mx * SEC_CAP_PCT - used
	if amount > room:
		amount = maxf(room, amount * MIN_PASS)
		capped = true
	if capped:
		st["cuts"] += 1
	win.append([now, amount])
	# tipo de dano
	var e := entry(boss)
	var m := 1.0
	if dt != "":
		if e.get("weak", {}).has(dt):
			m = float(e["weak"][dt])
			st["kind"] = "weak"
			st["weak"] += 1
		elif e.get("resist", {}).has(dt):
			m = float(e["resist"][dt])
			st["kind"] = "resist"
			st["resist"] += 1
	if st["kind"] == "weak" and _is_match(e, wid, dt) and now - float(st["match_t"]) >= MATCH_CD:
		st["match_t"] = now
		st["match_now"] = true
		st["match"] += 1
	amount *= m
	st["mult"] = m
	if amount > st["max_hit"]:
		st["max_hit"] = amount
		st["max_wpn"] = wid if wid != "" else ("tipo:" + dt if dt != "" else "sin_etiqueta")
	if debug:
		print("[boss-dmg] %s tipo=%s crudo=%.1f -> %.1f%s%s%s" % [wid if wid != "" else "-", dt, raw, amount,
			" (crit x%.2f anulado)" % cm if cm > 1.0 else "", " TOPE" if capped else "",
			" " + String(st["kind"]) + (" MATCH" if st["match_now"] else "")])
	return amount


## MATCH = el tipo es debilidad Y (el arma es del reino del heroe O la tabla pega heroe+tipo).
static func _is_match(e: Dictionary, wid: String, dt: String) -> bool:
	var rm := _root().get_node("RunManager")
	var hero: String = rm.character
	if dt in e.get("match", {}).get(hero, []):
		return true
	var aff := String(_wdata(wid).get("affinity", ""))
	var kingdom := String(rm.character_data().get("kingdom", ""))
	return aff != "" and aff != "neutral" and aff == kingdom


## Numero de dano (y marcas de debilidad/resistencia/match). Reemplaza al show_damage_number normal.
static func popup(boss: Node, amount: float, tired: bool) -> void:
	var pos: Vector2 = boss.global_position + Vector2(0, -150)
	var st := _state(boss)
	var kind: String = st["kind"]
	if not applies(boss) or kind == "":
		boss.get("_ge").show_damage_number.emit(pos, amount, tired)
		return
	var now := _now()
	var e := entry(boss)
	if kind == "weak":
		_styled(pos, "%.0f" % amount, COL_WEAK, 24)
		if bool(st["match_now"]):
			_styled(pos + Vector2(0, -34), boss.tr("BOSSDMG_MATCH"), COL_MATCH, 32)
			_root().get_node("Sound").play("puzzle_solve", 0.05)
			HitFx.shake(0.5)
			HitFx.hitstop()
			Callable(BossDamage, "_stun_match").bind(boss, MATCH_STUN).call_deferred()
		elif now - float(st["lbl_w"]) >= WEAK_LABEL_CD:
			st["lbl_w"] = now
			_styled(pos + Vector2(0, -30), boss.tr(String(e.get("label_weak", "BOSSDMG_WEAK"))), COL_WEAK, 16)
		if not st["said_w"] and e.has("line_weak"):
			st["said_w"] = true
			boss._float_text(boss.tr(String(e["line_weak"])), Color("ffe08a"), Vector2(0, -215))
	else:
		_styled(pos, "%.0f" % amount, COL_RESIST, 12)
		if now - float(st["lbl_r"]) >= RESIST_LABEL_CD:
			st["lbl_r"] = now
			_styled(pos + Vector2(0, -22), boss.tr(String(e.get("label_resist", "BOSSDMG_RESIST"))), COL_RESIST, 12)
		if not st["said_r"] and e.has("line_resist"):
			st["said_r"] = true
			boss._float_text(boss.tr(String(e["line_resist"])), Color("cfd6e6"), Vector2(0, -215))


## Aturdido corto del MATCH (diferido: la fase puede haber cambiado en el mismo golpe).
static func _stun_match(boss: Node, secs: float) -> void:
	if is_instance_valid(boss) and boss.state in [boss.State.IDLE, boss.State.ATTACK]:
		boss._stun(secs)


static func _styled(pos: Vector2, text: String, col: Color, size: int) -> void:
	var mgr = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("floating_text_mgr")
	if mgr != null:
		mgr.spawn_styled(pos, text, col, size)


## Pista antes del jefe: la tienda del piso del jefe vende su arma debil (si la tabla la define).
static func shop_hint(floor_data: Dictionary, default_id: String) -> String:
	_load()
	var e: Dictionary = _table.get(String(floor_data.get("boss", "")).trim_prefix("boss_"), {})
	return String(e.get("hint_weapon", default_id))


static func on_death(boss: Node) -> void:
	if not debug:
		return
	var st := _state(boss)
	print("[boss-dmg] golpe max %.1f con %s (crudo max %.1f), criticos anulados %d, recortes por tope %d, debilidad %d, resistencia %d, match %d" % [
		st["max_hit"], st["max_wpn"], st["max_raw"], st["crits"], st["cuts"], st["weak"], st["resist"], st["match"]])
