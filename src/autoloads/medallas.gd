extends Node

## MEDALLAS (logros). Niveles: SONROJO (bronce) < DESTAPE (plata) < SIN PUDOR (oro). La medalla
## final, DESNUDO INTEGRAL ("¡Desnudaste el juego!"), se gana al tener TODAS las demas (el "platino").
##
## - Catalogo: assets/data/medallas.json (generado por tools/gen_medallas.py; textos en
##   locale/medallas.csv; iconos de tools/gen_medallas_art.py).
## - Progreso: user://medallas.json (ganadas con fecha + contadores), como la memoria del narrador.
## - UN SOLO PUNTO DE DESBLOQUEO: otorgar(id). Ahi se guarda, se avisa (toast) y esta el gancho
##   _publicar_plataforma(id) para Steam/itch (hoy solo la senal medalla_ganada y un print).
## - Silencio y sala de memoria: otorgar() no hace nada con ContemplationMode.active (diseno E3:
##   la contemplacion no da logros) y no hay medallas del Silencio en el catalogo.
##
## Tipos de condicion del JSON ("condicion": {"tipo": ...}):
##   jefe            {id, sin_dano?, pudor_min?}  jefe vencido (id = boss_<id>.gd; la Parra entera es "parra_entera")
##   jefes_sin_dano  {n}                          n jefes DISTINTOS vencidos sin recibir dano
##   evento          {id}                         GlobalEvents.game_event(id) (ver abajo)
##   reinos          {n}                          n reinos liberados (RunManager.liberated, sin el Silencio)
##   victoria        {heroe?, pudor_min?, dia?}   partida ganada (con ese heroe / Censura minima / partida del dia)
##   victoria_heroes {n}                          ganada con n heroes distintos
##   codice          {pct}                        % del codice
##   contador        {nombre, n}                  acertijos / muertes / partidas
##   todas           {}                           Desnudo Integral
##
## EVENTOS (GlobalEvents.game_event): llegan solos los eventos de LoreDatabase.custom_event (monte_venus,
## enter_utero, victory...), mas "puzzle_solved" (main.gd), "reino_liberado" (RunManager.liberate),
## "hoja_cae" (boss_hoja_de_parra.gd), "pacto_menor" y "pacto_mayor" (enc_pact.gd). Para
## agregar uno: get_node("/root/GlobalEvents").game_event.emit("mi_evento") y una medalla {"tipo":"evento","id":"mi_evento"}.
##
## FINAL VERDADERO (Plan 6, pendiente): cuando exista, emitir
## `GlobalEvents.game_event.emit("final_verdadero")` donde se cierre el final verdadero (run_manager.gd /
## main.gd) y agregar su medalla en tools/gen_medallas.py con {"tipo":"evento","id":"final_verdadero"}.
## (No hay medalla hoy: si la hubiera sin emisor, Desnudo Integral seria imposible.)

signal medalla_ganada(id: String)

const DATA_PATH := "res://assets/data/medallas.json"
const ICON_DIR := "res://assets/sprites/ui/medallas/"
const FINAL_ID := "desnudo_integral"
const LEVELS := ["sonrojo", "destape", "sin_pudor"]
const LEVEL_COLORS := {
	"sonrojo": Color("ff8fa8"), "destape": Color("cdd6e8"), "sin_pudor": Color("f6c945"), "platino": Color("9be8ff"),
}

## Ruta del progreso (los tests la cambian).
var save_path := "user://medallas.json"

var _defs: Array = []
var _by_id: Dictionary = {}
var _won: Dictionary = {}  # id -> fecha "AAAA-MM-DD"
var _stats := {"acertijos": 0, "muertes": 0, "partidas": 0, "heroes_ganados": [], "jefes_sin_dano": []}
var _in_boss := false
var _boss_hit := false
var _layer: CanvasLayer
var _toast: MedalToast
var _icons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_defs()
	_load_progress()
	_layer = CanvasLayer.new()
	_layer.layer = 95
	add_child(_layer)
	_toast = MedalToast.new()
	_layer.add_child(_toast)
	var ge := get_node("/root/GlobalEvents")
	ge.game_event.connect(_on_game_event)
	ge.enemy_killed.connect(_on_enemy_killed)
	ge.player_damaged.connect(_on_player_damaged)
	ge.boss_health_changed.connect(_on_boss_health)
	ge.run_started.connect(_on_run_started)
	ge.run_ended.connect(_on_run_ended)
	ge.lore_unlocked.connect(func(_id): _eval_state())
	_eval_state.call_deferred()  # abona lo que ya estaba hecho (reinos liberados, codice...)


# ---------------------------------------------------------------- consulta
func defs() -> Array:
	return _defs


func get_def(id: String) -> Dictionary:
	return _by_id.get(id, {})


func is_won(id: String) -> bool:
	return _won.has(id)


func won_date(id: String) -> String:
	return str(_won.get(id, ""))


func total() -> int:
	return _defs.size()


func won_count() -> int:
	return _won.size()


## Ganadas / totales de un nivel ("sonrojo", "destape", "sin_pudor").
func level_count(level: String) -> Vector2i:
	var w := 0
	var t := 0
	for d in _defs:
		if d.nivel == level:
			t += 1
			if _won.has(d.id):
				w += 1
	return Vector2i(w, t)


## Progreso hacia Desnudo Integral: (ganadas de las demas, total de las demas).
func platinum_progress() -> Vector2i:
	var w := 0
	var t := 0
	for d in _defs:
		if d.id == FINAL_ID:
			continue
		t += 1
		if _won.has(d.id):
			w += 1
	return Vector2i(w, t)


func medal_name(id: String) -> String:
	var d := get_def(id)
	return tr(d.nombre_key) if not d.is_empty() else id


func medal_desc(id: String) -> String:
	var d := get_def(id)
	return tr(d.desc_key) if not d.is_empty() else ""


func level_name(level: String) -> String:
	return tr("MEDAL_LEVEL_" + level.to_upper())


func level_color(level: String) -> Color:
	return LEVEL_COLORS.get(level, Color.WHITE)


## Icono de la medalla (nivel + glifo de categoria); el de Desnudo Integral es propio.
func icono(id: String) -> Texture2D:
	var d := get_def(id)
	if d.is_empty():
		return null
	var key: String = "platino_final" if d.nivel == "platino" else "%s_%s" % [d.nivel, d.icono]
	if not _icons.has(key):
		_icons[key] = load(ICON_DIR + key + ".png")
	return _icons[key]


# ---------------------------------------------------------------- desbloqueo (UN SOLO PUNTO)
## Gana una medalla. Devuelve true si era nueva. Ignorada en contemplacion (Silencio / sala de memoria).
func otorgar(id: String) -> bool:
	if not _by_id.has(id) or _won.has(id):
		return false
	if ContemplationMode.active:
		return false
	_won[id] = Time.get_date_string_from_system()
	_save_progress()
	_publicar_plataforma(id)
	medalla_ganada.emit(id)
	var d: Dictionary = _by_id[id]
	if id == FINAL_ID:
		_layer.add_child(MedalFinale.new())
	else:
		_toast.show_medal(icono(id), level_name(d.nivel).to_upper(), medal_name(id), level_color(d.nivel))
		_check_platinum()
	return true


## GANCHO PARA STEAM / ITCH: aqui, y solo aqui, se avisa a la plataforma de que se gano `id`
## (p. ej. Steam.setAchievement(id); Steam.storeStats()). Los ids del JSON sirven de nombre de logro.
func _publicar_plataforma(id: String) -> void:
	print("Medalla ganada: %s" % id)


## Evento suelto que no pasa por GlobalEvents (para quien no quiera tocar el bus).
func registrar_evento(id: String) -> void:
	_on_game_event(id)


func _check_platinum() -> void:
	var p := platinum_progress()
	if p.x >= p.y:
		otorgar(FINAL_ID)


# ---------------------------------------------------------------- escucha de eventos
func _on_game_event(id: String) -> void:
	if id == "puzzle_solved":
		_stats.acertijos = int(_stats.acertijos) + 1
		_save_progress()
	for d in _defs:
		var c: Dictionary = d.condicion
		if c.tipo == "evento" and c.id == id:
			otorgar(d.id)
	_eval_state()


func _on_run_started(_seed: int) -> void:
	_in_boss = false
	_boss_hit = false
	_stats.partidas = int(_stats.partidas) + 1
	_save_progress()
	if get_node("/root/RunManager").daily_mode:
		_on_game_event("dia_jugar")
	else:
		_eval_state()


func _on_run_ended(victory: bool, _floor: int, _stats_run: Dictionary) -> void:
	_in_boss = false
	var rm := get_node("/root/RunManager")
	if not victory:
		_stats.muertes = int(_stats.muertes) + 1
		_save_progress()
		_eval_state()
		return
	var hero: String = rm.character
	if hero not in _stats.heroes_ganados:
		_stats.heroes_ganados.append(hero)
		_save_progress()
	for d in _defs:
		var c: Dictionary = d.condicion
		if c.tipo != "victoria":
			continue
		if c.has("heroe") and c.heroe != hero:
			continue
		if int(c.get("pudor_min", 0)) > Censura.level:
			continue
		if bool(c.get("dia", false)) and not rm.daily_mode:
			continue
		otorgar(d.id)
	_eval_state()


func _on_boss_health(_name: String, _cur: float, _max: float) -> void:
	if not _in_boss:  # primera barra de la pelea: empieza la cuenta de "sin recibir dano"
		_in_boss = true
		_boss_hit = false


func _on_player_damaged(amount: float, _source: Node) -> void:
	if _in_boss and amount > 0.0:
		_boss_hit = true


func _on_enemy_killed(enemy: Node, _killer: Node) -> void:
	if not enemy.is_in_group("boss"):
		return
	var id := boss_id(enemy)
	var flawless := _in_boss and not _boss_hit
	_in_boss = false
	if id == "":
		return
	if id == "hoja_de_parra":
		id = "parra_entera"  # la Hoja solo emite su muerte al caer la 2a forma (la 1a es el evento "hoja_cae")
	if flawless and id not in _stats.jefes_sin_dano:
		_stats.jefes_sin_dano.append(id)
		_save_progress()
	for d in _defs:
		var c: Dictionary = d.condicion
		if c.tipo != "jefe" or c.id != id:
			continue
		if bool(c.get("sin_dano", false)) and not flawless:
			continue
		if int(c.get("pudor_min", 0)) > Censura.level:
			continue
		otorgar(d.id)
	_eval_state()


## Id del jefe segun su script (boss_<id>.gd); "" si no se sabe.
static func boss_id(boss: Node) -> String:
	var sc: Script = boss.get_script()
	if sc == null:
		return ""
	return sc.resource_path.get_file().get_basename().trim_prefix("boss_")


## Condiciones "de estado": se reevaluan tras cada evento (reinos, codice, contadores...).
func _eval_state() -> void:
	var rm := get_node("/root/RunManager")
	var reinos := 0
	for r in rm.liberated:
		if r != "silencio":
			reinos += 1
	var pct: float = get_node("/root/LoreDatabase").get_completion_percentage()
	for d in _defs:
		if _won.has(d.id):
			continue
		var c: Dictionary = d.condicion
		match str(c.tipo):
			"reinos":
				if reinos >= int(c.n):
					otorgar(d.id)
			"codice":
				if pct >= float(c.pct):
					otorgar(d.id)
			"contador":
				if int(_stats.get(c.nombre, 0)) >= int(c.n):
					otorgar(d.id)
			"jefes_sin_dano":
				if _stats.jefes_sin_dano.size() >= int(c.n):
					otorgar(d.id)
			"victoria_heroes":
				if _stats.heroes_ganados.size() >= int(c.n):
					otorgar(d.id)


# ---------------------------------------------------------------- datos y guardado
func _load_defs() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not (data is Dictionary):
		push_error("Medallas: no se pudo leer %s" % DATA_PATH)
		return
	for d in data.get("medallas", []):
		_defs.append(d)
		_by_id[d.id] = d


func _load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not (data is Dictionary):
		return
	var won = data.get("won", {})
	if won is Dictionary:
		for id in won:
			if _by_id.has(id):
				_won[id] = str(won[id])
	var st = data.get("stats", {})
	if st is Dictionary:
		for k in ["acertijos", "muertes", "partidas"]:
			_stats[k] = int(st.get(k, 0))
		for k in ["heroes_ganados", "jefes_sin_dano"]:
			var arr = st.get(k, [])
			_stats[k] = arr if arr is Array else []


func _save_progress() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"won": _won, "stats": _stats}))


## SOLO PARA PRUEBAS / depuracion: borra todo el progreso de medallas.
func reset_progress() -> void:
	_won.clear()
	_stats = {"acertijos": 0, "muertes": 0, "partidas": 0, "heroes_ganados": [], "jefes_sin_dano": []}
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
