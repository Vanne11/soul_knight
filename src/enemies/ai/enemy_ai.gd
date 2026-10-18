class_name EnemyAI
extends Node

## Componente de IA con PERSONALIDAD para enemigos (hijo del enemigo). No reemplaza la
## maquina de estados de cada enemigo: la envuelve. Cada frame el enemigo pregunta
## `ai.control(delta)`; si devuelve true la IA ya movio al enemigo (dormido, huyendo, rendido,
## patrullando...) y el enemigo se salta su logica; si devuelve false sigue como siempre.
## Que personalidad tiene cada enemigo y como se asigna una nueva: enemy_personalities.gd.
##
## Eventos de burbuja (EnemyPersonalities.SAY): alert, lost, flee, back, surrender, wake,
## alarm, rage, ally_died, doubt, provoked, startle, hero_confused, hero_friend, shell,
## inspect, stamp, abort, discharge, recharged, resent, grudge, split, hide, race,
## hazard_wary, hazard_dive, hazard_ouch.
##
## PELIGROS DE SALA (trampas, fuego, barriles): ver _physics_process / _hazard_gate. La IA se ejecuta
## DESPUES del movimiento del enemigo y le impide ENTRAR en una zona peligrosa (RoomUtil.hazard_zones):
## lo desliza por el borde (rodea), espera a que se desarmen los pinchos y si estaba dentro lo saca.
## Los rabiosos a veces se lanzan sin mirar, los tanques pisan la cera, los cobardes dan mas margen.

enum Mode { CALM, SLEEP, GRAZE, FLEE, SURRENDER, SEARCH, SHELL, DISCHARGE, INSPECT, BURST,
		RETURN, PATROL, COVER, PAUSE }

const SNEAK_MULT := 2.5  ## golpe a un dormido (critico por sorpresa)
const SPEED_PROPS := ["move_speed", "strafe_speed", "charge_speed", "lunge_speed", "dart_speed"]
## Estados del enemigo en los que esta "comprometido" con un ataque: la IA no lo interrumpe.
const COMMITTED := ["WINDUP", "LUNGE", "AIM", "DART", "CHARGE_WINDUP", "CHARGING", "STUNNED", "RECOVER"]

static var _pending_comments: Array[String] = []
static var _hooked := false

var enemy: Node2D
var mode: Mode = Mode.CALM
var personality := "normal"
var variant := ""
var hero := "pitocles"
var p: Dictionary = {}
var target: Node2D = null

var _inited := false
var _dead := false
var _home := Vector2.ZERO
var _emote: AIEmote = null
var _sprite: AnimatedSprite2D = null
var _base: Dictionary = {}
var _dist := INF
var _alerted := false
var _last_seen := Vector2.ZERO
var _mode_t := 0.0
var _say_cd := 0.0
var _emote_cd := 0.0
var _group_peak := 1
var _shaken := false
# estados "overlay"
var _rage_t := 0.0
var _enraged := false
var _grudge := false
var _resentful := false
var _ignored_t := 0.0
var _flee_count := 0
var _flee_heal := false
var _flee_dir := Vector2.ZERO
var _flee_origin := Vector2.INF  ## si no es INF, huye de ese punto en vez del jugador
var _flee_len := 0.0
var _flee_bias := 0.0
var _stuck_t := 0.0
var _startled := false
var _surrendered := false
var _cover_cd := 0.0
var _cover_t := 0.0
var _shell_cd := 0.0
var _shots := 0
var _prev_charging := 0.0
var _still_t := 0.0
var _inspect_cd := 0.0
var _inspect_phase := 0
var _burst_cd := 1.0
var _burst_dir := Vector2.ZERO
var _burst_speed := 1.0
var _next_burst_cd := 1.0
var _wp := 0
var _wp_t := 0.0
var _graze_dir := Vector2.ZERO
var _graze_t := 0.0
var _alive_t := 0.0
var _is_clone := false
var _split_done := false
var _flank_side := 1.0
var _race_mult := 1.0
var _race_leader := false
var _first_sight_done := false
var _tint_phase := 0.0
var _speed_applied := -1.0
var _dmg_applied := 1.0
# peligros de sala
const HZ_PIN_MAX := 1.6   ## s pegado al borde de una zona antes de perder la paciencia y cruzar
var _hz_prev := Vector2.INF
var _hz_pinned := 0.0
var _hz_ignore := 0.0
var _hz_dive_t := -1.0   ## s desde que se lanzo a un peligro sin mirar (-1 = no)
var _hz_roll: Dictionary = {}
var _hz_side := 1.0
var _hz_say_cd := 0.0
var _caged_t := 0.0
static var hazard_avoid := true  ## interruptor de pruebas: false = ignora los peligros como antes


## Punto de entrada: lo llaman los enemigos desde su _ready. Devuelve null si el enemigo no
## usa IA ("none").
static func attach(e: Node2D) -> EnemyAI:
	var existing := e.get_node_or_null("EnemyAI")
	if existing is EnemyAI:
		return existing
	var id := EnemyPersonalities.resolve(e)
	if id == "none":
		return null
	if not EnemyPersonalities.exists(id):
		push_warning("EnemyAI: personalidad desconocida '%s' en %s, uso 'normal'" % [id, e.name])
		id = "normal"
	var ai := EnemyAI.new()
	ai.name = "EnemyAI"
	ai.enemy = e
	ai.personality = id
	e.add_child(ai)
	return ai


func _ready() -> void:
	var rm := get_node_or_null("/root/RunManager")
	if rm != null and "character" in rm:
		hero = String(rm.character)
	variant = EnemyPersonalities.variant_of(enemy)
	p = EnemyPersonalities.params(personality, hero)
	var spr = enemy.get("animated_sprite")
	if spr is AnimatedSprite2D:
		_sprite = spr
		_emote = AIEmote.new()
		enemy.add_child(_emote)
		_emote.setup(_sprite_top())
	for prop in SPEED_PROPS:
		if prop in enemy:
			_base[prop] = float(enemy.get(prop))
	_base["damage"] = float(enemy.get("damage")) if "damage" in enemy else 0.0
	if "detection_range" in enemy:
		enemy.detection_range = float(enemy.detection_range) * float(p.detect_mult)
	_flank_side = 1.0 if RNG.randf() < 0.5 else -1.0
	_hz_side = _flank_side
	process_physics_priority = 90  # despues de que el enemigo se mueva
	_burst_cd = RNG.randf_range(0.6, 2.0)
	_is_clone = bool(enemy.get_meta("ai_clone", false))
	_split_done = _is_clone
	_hook_narrator()
	if p.sleep:
		mode = Mode.SLEEP
	elif p.passive:
		mode = Mode.GRAZE


static func _hook_narrator() -> void:
	if _hooked:
		return
	var ge = Engine.get_main_loop().root.get_node_or_null("GlobalEvents")
	if ge == null:
		return
	_hooked = true
	ge.room_cleared.connect(_on_room_cleared)


## Al limpiar la sala (ya no hay combate) el narrador comenta una de las cosas raras que paso.
static func _on_room_cleared(_room: Node = null) -> void:  # RunManager.clear_room emite sin sala
	if _pending_comments.is_empty():
		return
	var ev: String = _pending_comments[RNG.randi_range(0, _pending_comments.size() - 1)]
	_pending_comments.clear()
	var nar = Engine.get_main_loop().root.get_node_or_null("Narrator")
	if nar != null and nar.has_lines(ev):
		nar.say(ev)


static func _note(ev: String) -> void:
	if ev not in _pending_comments:
		_pending_comments.append(ev)


func _sprite_top() -> float:
	var tex: Texture2D = null
	if _sprite.sprite_frames != null:
		var anim: StringName = _sprite.animation if _sprite.sprite_frames.has_animation(_sprite.animation) else "idle"
		if _sprite.sprite_frames.has_animation(anim):
			tex = _sprite.sprite_frames.get_frame_texture(anim, 0)
	var th: float = tex.get_height() if tex != null else 32.0
	return _sprite.position.y + (_sprite.offset.y - th * 0.5) * absf(_sprite.scale.y)


# ======================================================================= API para el enemigo

## true = la IA movio al enemigo este frame; el enemigo debe saltarse su logica
## (y llamar move_and_slide()).
func control(delta: float) -> bool:
	if _dead or enemy == null or not is_instance_valid(enemy):
		return false
	if not _inited:
		_inited = true
		_home = enemy.global_position
	if _caged_t > 0.0:  # jaula caida encima: quieto y sin atacar
		_caged_t -= delta
		enemy.velocity = Vector2.ZERO
		if _caged_t <= 0.0:
			_clear_commit()
		return true
	_acquire_target()
	_dist = enemy.global_position.distance_to(target.global_position) if target != null else INF
	_mode_t += delta
	_say_cd = maxf(0.0, _say_cd - delta)
	_emote_cd = maxf(0.0, _emote_cd - delta)
	_cover_cd = maxf(0.0, _cover_cd - delta)
	_shell_cd = maxf(0.0, _shell_cd - delta)
	_inspect_cd = maxf(0.0, _inspect_cd - delta)
	_group_peak = maxi(_group_peak, _allies().size() + 1)
	_tick_status(delta)
	_think(delta)
	return _act(delta)


## Se llama ANTES de restar la vida. Devuelve el dano final (golpe por sorpresa a dormidos).
func on_damage(amount: float, source: Node = null) -> float:
	amount = Affixes.filter_damage(enemy, amount, source)  # afijos de elite (blindado absorbe)
	if _dead:
		return amount
	_ignored_t = 0.0
	if _hz_dive_t >= 0.0 and _hz_dive_t < 3.0:  # se lanzo sin mirar y se lo comio
		_hz_dive_t = -1.0
		_say("hazard_ouch")
		_note("ti_dive")
	if _resentful:
		_resentful = false
	var src_pos := _source_pos(source)
	match mode:
		Mode.SLEEP:
			amount *= SNEAK_MULT
			_note("ia_dormido")
			_wake(true)
		Mode.GRAZE:
			if p.startle_range > 0.0:
				_startle()
			else:
				_provoke(true)
		Mode.SURRENDER, Mode.FLEE:
			pass
		_:
			if not _alerted:
				_set_alert(true)
	_set_alert_silent()
	if p.rage_on_hit and not _enraged:
		_enrage(p.rage_time, "rage")
	elif p.rage_behind and not _enraged and enemy is Node2D and _hit_from_behind(src_pos):
		_enrage(p.rage_time, "rage")
	if p.grudge and not _grudge:
		_grudge = true
		if "detection_range" in enemy:
			enemy.detection_range = float(enemy.detection_range) * 3.0
		_emote_icon("vein")
		_say("grudge")
	if p.alarm and mode != Mode.SLEEP:
		_raise_alarm()
	if p.shell and _shell_cd <= 0.0 and mode == Mode.CALM and _dist > 140.0:
		_clear_commit()
		_enter(Mode.SHELL)
		_shell_cd = 3.5
		_say("shell")
	return amount


## Se llama al empezar a morir. Avisa a los companeros (moral, rabia).
func on_death() -> void:
	if _dead:
		return
	_dead = true
	if _emote != null and is_instance_valid(_emote):
		_emote.queue_free()
	if _surrendered:
		_note("ia_rendido")
	for a in _allies():
		a.on_ally_death(self)


## Otro aliado murio cerca.
func on_ally_death(dead: EnemyAI) -> void:
	if _dead or mode == Mode.SLEEP or mode == Mode.SURRENDER:
		return
	if p.rage_ally:
		_enrage(p.rage_time, "ally_died")
		_note("ia_rabia")
		return
	if mode == Mode.FLEE or _shaken or p.courage >= 1.0:
		return
	var left := _allies().size() + 1
	var dead_hp: float = float(dead.enemy.get("max_health")) if dead.enemy != null else 0.0
	var leader_dead := _group_peak >= 2 and dead_hp > 0.0 and dead_hp >= _max_ally_health()
	var half_gone := _group_peak >= 3 and left <= int(ceil(_group_peak / 2.0))
	if not (leader_dead or half_gone):
		return
	if RNG.randf() <= p.courage:
		return
	_shaken = true
	if RNG.randf() < 0.5:
		_flee_heal = false
		_clear_commit()
		_enter(Mode.FLEE)
		_mode_t = -(p.flee_time * 0.7)
		_flee_dir = Vector2.ZERO
		_emote_icon("sweat")
		_say("flee")
	else:
		_pause(0.9, "question")
		_say("doubt")


## Atrapado bajo una jaula (trap_room.gd): ni se mueve ni ataca durante `seconds`.
func cage(seconds: float) -> void:
	if _dead or mode == Mode.SURRENDER:
		return
	_clear_commit()
	_caged_t = maxf(_caged_t, seconds)
	_emote_icon("dots", seconds)


## Susto (grito de Vulvalquiria): huye del punto `from`. Los valientes (courage 1) lo resisten a medias.
func scare(seconds: float, from: Vector2) -> void:
	if _dead or mode == Mode.SURRENDER:
		return
	var secs := seconds * (0.5 if p.courage >= 1.0 else 1.0)
	_flee_heal = false
	_flee_origin = from
	_flee_len = secs
	_clear_commit()
	_alerted = true
	_enter(Mode.FLEE)
	_emote_icon("sweat")
	_say("flee")


## Aturdimiento (embestida de Pitocles): se queda quieto.
func stun(seconds: float) -> void:
	if _dead or mode == Mode.SURRENDER:
		return
	if mode == Mode.SLEEP:
		_alerted = true
	_pause(seconds, "dots")


## Despierta a un dormido (alarma de otro enemigo).
func wake_by_alarm(pos: Vector2) -> void:
	if _dead:
		return
	_last_seen = pos
	if mode == Mode.SLEEP:
		_wake(false)
	elif mode == Mode.GRAZE and p.provoke_range > 0.0:
		_provoke(false)
	elif not _alerted:
		_alerted = true
		_emote_icon("alert")


# ======================================================================= pensar / transiciones

func _tick_status(delta: float) -> void:
	# rabia
	if _enraged and not p.rage_permanent:
		_rage_t -= delta
		if _rage_t <= 0.0:
			_enraged = false
			_emote_icon("sweat", 0.8)
	if _enraged and _emote_cd <= 0.0 and mode != Mode.SLEEP:
		_emote_icon("vein", 0.9)
		_emote_cd = 3.0
	# rencor por ser ignorado
	if p.resent_time > 0.0 and mode == Mode.CALM and _alerted:
		_ignored_t += delta
		if _ignored_t >= p.resent_time and not _resentful:
			_resentful = true
			_emote_icon("vein")
			_say("resent")
			_note("ia_resentida")
	# carrera de espermatozoides
	if p.race and mode == Mode.CALM and target != null:
		_update_race()
	else:
		_race_mult = 1.0
	_apply_stats()
	_apply_tint(delta)
	if mode == Mode.FLEE and _emote_cd <= 0.0:
		_emote_icon("sweat", 0.7)
		_emote_cd = 0.9
	elif mode == Mode.SLEEP and _emote_cd <= 0.0:
		_emote_icon("sleep", 1.4)
		_emote_cd = 1.8
	elif mode == Mode.SURRENDER and _emote_cd <= 0.0:
		_emote_icon("flag", 1.6)
		_emote_cd = 2.0


func _think(delta: float) -> void:
	if target == null:
		return
	var ratio: float = float(enemy.current_health) / maxf(float(enemy.max_health), 1.0)
	# transiciones por vida (no interrumpen dormidos ni rendidos)
	if mode != Mode.SLEEP and mode != Mode.SURRENDER and mode != Mode.FLEE:
		if p.surrender_hp > 0.0 and ratio <= p.surrender_hp and not _surrendered:
			_surrender()
			return
		if p.flee_hp > 0.0 and ratio <= p.flee_hp and _flee_count < p.flee_max:
			_flee_count += 1
			_flee_heal = true
			_clear_commit()
			_enter(Mode.FLEE)
			_emote_icon("sweat")
			_say("flee")
			_note("ia_cobarde")
			return
	match mode:
		Mode.SLEEP:
			if _dist <= p.wake_range:
				_wake(false)
		Mode.GRAZE:
			if p.startle_range > 0.0 and _dist <= p.startle_range and not _startled:
				_startle()
			elif p.provoke_range > 0.0 and _dist <= p.provoke_range:
				_provoke(false)
			elif p.friend and not _first_sight_done and _dist <= 260.0:
				_first_sight_done = true
				_emote_icon("heart", 1.6)
				_say("hero_friend")
				_note("ia_amigo")
		Mode.FLEE:
			_think_flee(delta)
		Mode.SEARCH:
			_think_search()
		Mode.SHELL:
			if _mode_t >= 1.0:
				_enter(Mode.CALM)
		Mode.DISCHARGE:
			if _mode_t >= p.recharge_time:
				_shots = 0
				_enter(Mode.CALM)
				_emote_icon("alert", 0.8)
				_say("recharged")
		Mode.PAUSE:
			if _mode_t >= _burst_cd:
				_enter(Mode.CALM)
		Mode.BURST:
			if _mode_t >= _burst_cd:
				_enter(Mode.CALM)
				_burst_cd = _next_burst_cd
		Mode.INSPECT:
			_think_inspect()
		Mode.RETURN:
			var in_zone: bool = target.global_position.distance_to(_home) <= p.territory
			if in_zone:
				_enter(Mode.CALM)
		Mode.PATROL:
			if _dist <= p.patrol_sight:
				_enter(Mode.CALM)
				_set_alert(true)
				_say("alert")
		Mode.COVER:
			_think_cover(delta)
		Mode.CALM:
			_think_calm(delta)


func _think_calm(delta: float) -> void:
	var committed := _committed()
	_alive_t += delta
	# descarga (enemigos de distancia que se quedan sin pila): cuenta las salvas disparadas
	if p.overload_shots > 0:
		var ch = enemy.get("_charging")
		if ch != null:
			var fired: bool = _prev_charging > 0.0 and float(ch) <= 0.0
			_prev_charging = float(ch)
			if fired:
				_shots += 1
				if _shots >= p.overload_shots:
					_clear_commit()
					_enter(Mode.DISCHARGE)
					_emote_icon("dots", p.recharge_time)
					_say("discharge")
					_note("ia_descarga")
					return
	# primera deteccion
	if not _alerted and _dist <= _detect():
		if p.patrol and _dist > p.patrol_sight:
			pass
		else:
			_set_alert(true)
			if p.alarm:
				_raise_alarm()
			elif _hero_confuses() and not _first_sight_done:
				_first_sight_done = true
				_pause(0.8, "question")
				_say("hero_confused")
				_note("ia_confuso")
				return
			elif not committed:
				_say("alert", 0.35)
	_cover_enter_check()
	if mode != Mode.CALM:
		return
	# perdio al jugador
	if _alerted and _dist > _detect() * 1.5 and p.search > 0.0 and not committed:
		_alerted = false
		_enter(Mode.SEARCH)
		_emote_icon("question", 1.4)
		_say("lost")
		return
	if committed:
		return
	# espasmos / tropiezos
	if (p.spasm or p.confuse) and _alerted:
		_burst_cd -= delta
		if _burst_cd <= 0.0:
			_start_burst()
			return
	# territorial
	if p.territory > 0.0:
		var in_zone: bool = target.global_position.distance_to(_home) <= p.territory
		var far: bool = enemy.global_position.distance_to(_home) > p.territory * 1.6
		if not in_zone and (far or not _enraged):
			_enter(Mode.RETURN)
			return
	# patrulla
	if p.patrol and not _alerted:
		_enter(Mode.PATROL)
		return
	# inspeccion burocratica
	if p.inspect_wait > 0.0 and _inspect_cd <= 0.0 and _alerted:
		var tv = target.get("velocity")
		if tv != null and (tv as Vector2).length() < 14.0:
			_still_t += delta
		else:
			_still_t = 0.0
		if _still_t >= p.inspect_wait and _dist <= 420.0:
			_still_t = 0.0
			_clear_commit()
			_inspect_phase = 0
			_enter(Mode.INSPECT)
			return
	else:
		_still_t = 0.0
	# multiplicacion de pixeles
	if p.split_time > 0.0 and not _split_done and _alive_t >= p.split_time and _alerted:
		_split()


func _think_flee(delta: float) -> void:
	# acorralado: pelea de vuelta enfurecido
	var rv: Vector2 = enemy.get_real_velocity() if enemy is CharacterBody2D else Vector2.ZERO
	if rv.length() < 25.0:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	if _stuck_t > 0.7 and _dist < 170.0:
		_enter(Mode.CALM)
		_enrage(3.0, "rage")
		return
	if _mode_t >= _flee_len:
		if _flee_heal:
			enemy.current_health = minf(float(enemy.max_health), float(enemy.current_health) + float(enemy.max_health) * p.flee_heal)
			_emote_icon("alert", 0.9)
			_say("back")
		_enter(Mode.CALM)


func _think_search() -> void:
	if _dist <= _detect():
		_alerted = true
		_enter(Mode.CALM)
		_emote_icon("alert")
		return
	if _mode_t >= p.search + 2.0:
		_enter(Mode.CALM)


func _think_inspect() -> void:
	if _inspect_phase == 0:
		# se acerca; si te mueves antes de llegar, aborta
		if _dist <= 95.0:
			_inspect_phase = 1
			_mode_t = 0.0
			_emote_icon("question", 1.8)
			_say("inspect", 1.8)
		elif _target_moving():
			_abort_inspect()
	elif _inspect_phase == 1:
		if _target_moving():
			_abort_inspect()
		elif _mode_t >= (1.7 if hero != "ornitorrinco" else 3.0):
			_inspect_phase = 2
			_mode_t = 0.0
			_say("stamp", 1.8)
			_note("ia_inspeccion")
	elif _inspect_phase == 2 and _mode_t >= 1.0:
		_inspect_cd = 6.0
		_enter(Mode.CALM)


func _abort_inspect() -> void:
	_say("abort")
	_inspect_cd = 4.0
	_enter(Mode.CALM)


func _target_moving() -> bool:
	var tv = target.get("velocity")
	return tv != null and (tv as Vector2).length() > 60.0


func _think_cover(delta: float) -> void:
	_cover_t += delta
	var buddy := _cover_buddy()
	var near_limit := 110.0 if p.hide else 170.0
	if buddy == null or _dist <= near_limit or _cover_t > 5.0:
		_cover_cd = 4.0
		_enter(Mode.CALM)


func _cover_enter_check() -> void:
	if (not p.hide and not p.guard) or _cover_cd > 0.0 or not _alerted or _committed():
		return
	if _dist <= (110.0 if p.hide else 170.0):
		return
	if _cover_buddy() != null:
		_cover_t = 0.0
		_enter(Mode.COVER)
		if p.hide:
			_say("hide")


## Aliado detras del cual esconderse (hide: el mas cercano) o al que cubrir (guard: uno de distancia).
func _cover_buddy() -> Node2D:
	var best: Node2D = null
	var bd := INF
	for a in _allies():
		if p.guard and not ("preferred_distance" in a.enemy):
			continue
		var d := enemy.global_position.distance_to(a.enemy.global_position)
		if d < bd and d < 600.0:
			bd = d
			best = a.enemy
	return best


# ======================================================================= peligros de sala

func _physics_process(delta: float) -> void:
	if _dead or enemy == null or not is_instance_valid(enemy) or not (enemy is CharacterBody2D):
		return
	if _hz_dive_t >= 0.0:
		_hz_dive_t += delta
		if _hz_dive_t > 3.0:
			_hz_dive_t = -1.0
	_hz_say_cd = maxf(0.0, _hz_say_cd - delta)
	var cur := enemy.global_position
	var prev := _hz_prev
	_hz_prev = cur
	if not hazard_avoid or prev == Vector2.INF or mode == Mode.SLEEP or mode == Mode.SURRENDER or _caged_t > 0.0:
		return
	var zones := RoomUtil.hazard_zones(get_tree())
	if zones.is_empty():
		_hz_pinned = 0.0
		return
	if _hz_ignore > 0.0:
		_hz_ignore -= delta
		return
	var fixed := _hazard_gate(zones, prev, cur, delta)
	if fixed != cur:
		(enemy as CharacterBody2D).move_and_collide(fixed - cur)
		_hz_pinned += delta
		if _hz_pinned > HZ_PIN_MAX:  # paciencia agotada: cruza (los pinchos y el fuego quedan a su cuenta)
			_hz_pinned = 0.0
			_hz_ignore = 1.2
	else:
		_hz_pinned = maxf(0.0, _hz_pinned - delta * 2.0)


## Posicion corregida: no entra en zonas peligrosas desde fuera (se desliza por el borde hacia el lado
## del objetivo) y, si ya estaba dentro de una activa, deshace su paso y sale en linea recta.
func _hazard_gate(zones: Array, prev: Vector2, cur: Vector2, delta: float) -> Vector2:
	var pos := cur
	var coward: bool = float(p.hazard_caution) > 1.0
	var horizon := 1.1 if coward else 0.45
	var margin_k: float = float(p.hazard_caution)
	for z in zones:
		var c: Vector2 = z.c
		var ar: float = float(z.get("ar", z.r)) * margin_k
		if pos.distance_to(c) > ar + 60.0 and prev.distance_to(c) > ar + 60.0:
			continue
		if not z.active and float(z.soon) > horizon:
			continue
		var kind: String = z.kind
		if kind == "puddle" and (enemy is EnemyTank or personality == "gigante"):
			continue  # los tanques pisan la cera sin miedo
		if Time.get_ticks_msec() - int(enemy.get_meta("pushed_ms", -1000)) < 220:
			continue  # lo empuja un ventilador: el entorno manda
		if _committed():
			continue  # embistiendo / en retroceso: no se frena a mitad de ataque
		var key := "%s_%d_%d" % [kind, int(c.x / 8.0), int(c.y / 8.0)]
		var d_cur := pos.distance_to(c)
		var now := Time.get_ticks_msec()
		if not _hz_roll.has(key) or now - int(_hz_roll[key][1]) > 4000:
			if _hz_roll.size() > 12:
				_hz_roll.clear()
			var reckless := _hz_is_reckless(kind)
			_hz_roll[key] = [reckless, now]
			if reckless:
				_hz_dive_t = 0.0
				_emote_icon("vein")
				_say("hazard_dive")
			elif coward and _hz_say_cd <= 0.0 and RNG.randf() < 0.35:
				_hz_say_cd = 8.0
				_emote_icon("sweat")
				_say("hazard_wary")
				_note("ti_avoid")
		if _hz_roll[key][0]:
			continue  # imprudente: se lanza igual
		var d_prev := prev.distance_to(c)
		if d_prev >= ar and d_cur < ar:
			# entra desde fuera: queda en el borde y resbala por el lado del objetivo
			var radial := (pos - c).normalized() if d_cur > 0.5 else (prev - c).normalized()
			var tang := radial.orthogonal()
			var side := _hz_side
			if target != null:
				var want := target.global_position - pos
				var dot := tang.dot(want)
				if absf(dot) > 12.0:
					side = signf(dot)
					_hz_side = side
			pos = c + radial * (ar + 0.5) + tang * side * float(enemy.move_speed) * 0.85 * delta
		elif d_prev < ar and z.active:
			# ya estaba dentro: deshace el paso y sale por el camino mas corto
			var out := (prev - c).normalized() if prev.distance_to(c) > 0.5 else Vector2.RIGHT.rotated(RNG.randf() * TAU)
			pos = prev + out * float(enemy.move_speed) * 1.1 * delta
	return pos


## Se lanza sin mirar? Rabiosos y enfurecidos a veces; el resto no. Los barriles y las jaulas
## (avisos de menos de 1 s) no se desafian por gusto.
func _hz_is_reckless(kind: String) -> bool:
	var chance: float = float(p.reckless)
	if _enraged or p.rage_permanent:
		chance = maxf(chance, 0.7)
	if kind == "barrel":
		chance *= 0.3
	return chance > 0.0 and RNG.randf() < chance


# ======================================================================= actuar

func _act(delta: float) -> bool:
	if target == null and mode != Mode.SLEEP and mode != Mode.SURRENDER:
		return false
	match mode:
		Mode.SLEEP, Mode.SURRENDER, Mode.SHELL, Mode.DISCHARGE, Mode.PAUSE:
			enemy.velocity = Vector2.ZERO
			if mode == Mode.SURRENDER or mode == Mode.DISCHARGE:
				_face(target)
			return true
		Mode.GRAZE:
			_graze(delta)
			return true
		Mode.FLEE:
			_flee_move(delta)
			return true
		Mode.SEARCH:
			if _arrive(_last_seen, 0.6) < 12.0:
				enemy.velocity = Vector2.ZERO
			return true
		Mode.INSPECT:
			if _inspect_phase == 0:
				_arrive(target.global_position, 1.0)
			else:
				enemy.velocity = Vector2.ZERO
				_face(target)
			return true
		Mode.BURST:
			enemy.velocity = _burst_dir * float(enemy.move_speed) * _burst_speed
			_anim(_burst_dir)
			return true
		Mode.RETURN:
			if _arrive(_home, 0.6) < 14.0:
				enemy.velocity = Vector2.ZERO
				_face(target)
			return true
		Mode.PATROL:
			var route := _route()
			_wp_t += delta
			if _arrive(route[_wp % 4], 0.5) < 12.0 or _wp_t > 4.0:  # 4 s sin llegar: pasa a la siguiente esquina
				_wp += 1
				_wp_t = 0.0
			return true
		Mode.COVER:
			var buddy := _cover_buddy()
			if buddy == null:
				return false
			var goal: Vector2
			if p.hide:
				goal = buddy.global_position + (buddy.global_position - target.global_position).normalized() * 70.0
			else:
				goal = buddy.global_position + (target.global_position - buddy.global_position).normalized() * 100.0
			if _arrive(goal, 0.85) < 14.0:
				enemy.velocity = Vector2.ZERO
				_face(target)
			return true
		Mode.CALM:
			return _act_calm()
	return false


func _act_calm() -> bool:
	# flanquear: rodearte por los lados antes de embestir (solo cuerpo a cuerpo)
	if p.flank and enemy is Enemy and _alerted and _dist > 190.0 and _dist <= _detect() and not _committed():
		var to_t := target.global_position - enemy.global_position
		var side := to_t.normalized().orthogonal() * _flank_side
		var goal := target.global_position - to_t.normalized() * 60.0 + side * 190.0
		_arrive(goal, 1.0)
		return true
	return false


func _graze(delta: float) -> void:
	_graze_t -= delta
	if _graze_t <= 0.0 or _graze_dir == Vector2.ZERO:
		_graze_dir = Vector2.from_angle(RNG.randf_range(0.0, TAU)) if RNG.randf() < 0.75 else Vector2.ZERO
		_graze_t = RNG.randf_range(0.9, 2.4)
	enemy.velocity = _graze_dir * float(enemy.move_speed) * 0.3
	_anim(_graze_dir if _graze_dir != Vector2.ZERO else Vector2.ZERO)


func _flee_move(_delta: float) -> void:
	var src: Vector2 = target.global_position if _flee_origin == Vector2.INF else _flee_origin
	var away := (enemy.global_position - src).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	var on_wall: bool = enemy is CharacterBody2D and (enemy as CharacterBody2D).is_on_wall()
	if on_wall:
		_flee_bias = (PI * 0.45) * (1.0 if RNG.randf() < 0.5 else -1.0)
	elif _flee_bias != 0.0 and _flee_dir == Vector2.ZERO:
		_flee_bias = 0.0
	var dir := away.rotated(_flee_bias)
	enemy.velocity = dir * float(enemy.move_speed) * 1.25
	_flee_dir = dir
	_anim(dir)


func _route() -> Array[Vector2]:
	var pts: Array[Vector2] = [_home + Vector2(-110, -80), _home + Vector2(110, -80), _home + Vector2(110, 80), _home + Vector2(-110, 80)]
	# junto a un muro (o en una sala con forma) las esquinas caian dentro de la pared y la patrulla se quedaba pegada
	var room = enemy.find_owning_room() if enemy.has_method("find_owning_room") else null
	if room != null:
		for i in pts.size():
			pts[i] = room.clamp_global(pts[i], 30.0)
	return pts


## Camina hacia pos; devuelve la distancia restante.
func _arrive(pos: Vector2, frac: float) -> float:
	var to := pos - enemy.global_position
	var d := to.length()
	if d < 8.0:
		enemy.velocity = Vector2.ZERO
		return d
	var dir := to / d
	enemy.velocity = dir * float(enemy.move_speed) * frac
	_anim(dir)
	return d


func _anim(dir: Vector2) -> void:
	if enemy.has_method("_update_animation"):
		enemy._update_animation(dir)


func _face(t: Node2D) -> void:
	if t != null and enemy.has_method("_update_animation"):
		enemy._update_animation(Vector2(t.global_position.x - enemy.global_position.x, 0.0))


# ======================================================================= acciones de estado

func _enter(m: Mode) -> void:
	var was := mode
	mode = m
	if m == Mode.FLEE and _flee_len <= 0.0:
		_flee_len = p.flee_time
	if m != Mode.FLEE:
		_flee_origin = Vector2.INF
		_flee_len = 0.0
	_mode_t = 0.0
	_stuck_t = 0.0
	if was in [Mode.FLEE, Mode.SURRENDER, Mode.SHELL, Mode.DISCHARGE, Mode.PAUSE, Mode.SLEEP,
			Mode.COVER, Mode.BURST, Mode.INSPECT, Mode.GRAZE, Mode.SEARCH, Mode.RETURN, Mode.PATROL] \
			and m == Mode.CALM:
		_reset_enemy_state()
	if m == Mode.CALM and _emote != null and was == Mode.SLEEP:
		_emote.clear_icon()


func _pause(secs: float, icon: String) -> void:
	_clear_commit()
	_burst_cd = secs
	_enter(Mode.PAUSE)
	_emote_icon(icon, secs)


func _start_burst() -> void:
	if p.confuse:
		_burst_dir = Vector2.from_angle(RNG.randf_range(0.0, TAU))
		_burst_speed = 0.55
		_burst_cd = RNG.randf_range(0.7, 1.1)
		_emote_icon("question", 0.9)
		_enter(Mode.BURST)
		_mode_t = 0.0
		_next_burst_cd = RNG.randf_range(2.5, 5.0)  # espera hasta el proximo tropiezo
	else:
		_burst_dir = Vector2.from_angle(RNG.randf_range(0.0, TAU))
		_burst_speed = 1.6
		_burst_cd = RNG.randf_range(0.22, 0.42)
		_enter(Mode.BURST)
		_next_burst_cd = RNG.randf_range(0.5, 1.8)


func _wake(by_hit: bool) -> void:
	_alerted = true
	_enter(Mode.CALM)
	_emote_icon("alert")
	_say("wake")
	if p.wake_rage and by_hit:
		_enrage(p.rage_time, "rage")


func _provoke(by_hit: bool) -> void:
	_alerted = true
	_enter(Mode.CALM)
	_emote_icon("alert")
	_say("provoked")
	if p.rage_permanent:
		_enrage(p.rage_time, "rage")
	if p.provoke_group:
		for a in _allies():
			if a.variant == variant and a.mode == Mode.GRAZE and enemy.global_position.distance_to(a.enemy.global_position) < 320.0:
				a._provoke(false)
	_alerted = true
	if by_hit:
		_note("ia_pasivo")


func _startle() -> void:
	_startled = true
	_alerted = true
	_flee_heal = false
	_clear_commit()
	_enter(Mode.FLEE)
	_emote_icon("alert")
	_say("startle")
	_note("ia_asustado")


func _set_alert(loud: bool) -> void:
	if _alerted:
		return
	_alerted = true
	_last_seen = target.global_position if target != null else enemy.global_position
	if loud:
		_emote_icon("alert")


func _set_alert_silent() -> void:
	if target != null:
		_last_seen = target.global_position
	_alerted = true


func _surrender() -> void:
	_surrendered = true
	_clear_commit()
	_enter(Mode.SURRENDER)
	_emote_icon("flag", 1.6)
	_say("surrender", 2.6)
	if enemy.has_method("_drop_loot"):
		enemy._drop_loot()
		var empty: Array[Dictionary] = []
		enemy.drop_table = empty


func _enrage(secs: float, event: String) -> void:
	_enraged = true
	_rage_t = secs
	_emote_icon("vein")
	_say(event)
	_emote_cd = 3.0


func _raise_alarm() -> void:
	if _say_cd > 0.0 and _emote_cd > 0.0:
		return
	_emote_icon("alert", 1.4)
	_say("alarm", 2.2)
	_say_cd = 6.0
	_note("ia_alarma")
	var pos := target.global_position if target != null else enemy.global_position
	for a in _allies():
		if enemy.global_position.distance_to(a.enemy.global_position) <= p.alarm_radius:
			a.wake_by_alarm(pos)


func _update_race() -> void:
	var rivals: Array = []
	for a in _allies():
		if a.p.race and a.mode == Mode.CALM:
			rivals.append(a)
	var mine := _dist
	var ahead := 0
	for a in rivals:
		if a._dist < mine:
			ahead += 1
	# el que va primero acelera; el segundo, algo; el resto, nada (y se estorban solos)
	_race_mult = 1.25 if ahead == 0 and not rivals.is_empty() else (1.1 if ahead == 1 else 1.0)
	var leader := ahead == 0 and not rivals.is_empty()
	if leader and not _race_leader and _alerted and _say_cd <= 0.0:
		_say("race", 1.4)
		_say_cd = 5.0
	_race_leader = leader


func _split() -> void:
	_split_done = true
	var same := 0
	for a in _allies():
		if a.variant == variant:
			same += 1
	if same >= 5 or enemy.scene_file_path == "":
		return
	var scn := load(enemy.scene_file_path) as PackedScene
	if scn == null:
		return
	var clone: Node2D = scn.instantiate()
	clone.set_meta("ai_clone", true)
	clone.enemy_name = enemy.enemy_name
	clone.max_health = maxf(float(enemy.max_health) * 0.5, 1.0)
	clone.damage = _base["damage"]
	if "move_speed" in enemy:
		clone.move_speed = _base.get("move_speed", clone.move_speed)
	var empty: Array[Dictionary] = []
	clone.drop_table = empty
	if _sprite != null:
		clone.get_node("AnimatedSprite2D").sprite_frames = _sprite.sprite_frames
		clone.get_node("AnimatedSprite2D").scale = _sprite.scale
	var parent := enemy.get_parent()
	if parent == null:
		clone.queue_free()
		return
	parent.add_child(clone)
	var room = enemy.call("find_owning_room") if enemy.has_method("find_owning_room") else null
	var at: Vector2 = enemy.global_position + Vector2(RNG.randf_range(-26, 26), RNG.randf_range(-20, 20))
	if room != null:
		at = room.clamp_global(at, 18.0)  # pegado a un muro el clon nacia dentro de la pared y quedaba inalcanzable
	clone.global_position = at
	if room != null and "enemies_spawned" in room:
		room.enemies_spawned.append(clone)
	_emote_icon("alert", 0.9)
	_say("split")
	_note("ia_multiplica")


# ======================================================================= utilidades

func _acquire_target() -> void:
	# senuelos (huevo del Ornitorrinco): atraen a los enemigos cercanos mientras existan
	var decoy: Node2D = null
	var bd := 520.0
	for d in get_tree().get_nodes_in_group("decoy"):
		if d is Node2D and is_instance_valid(d) and not d.is_queued_for_deletion():
			var dd := enemy.global_position.distance_to((d as Node2D).global_position)
			if dd < bd:
				bd = dd
				decoy = d
	if decoy != null:
		target = decoy
		enemy.set("target", decoy)
		return
	if target != null and (not is_instance_valid(target) or target.is_in_group("decoy")):
		target = null
	if target != null and is_instance_valid(target):
		return
	var t = enemy.get("target")
	if t != null and is_instance_valid(t) and not t.is_in_group("decoy"):
		target = t
		return
	var pl := get_tree().get_nodes_in_group("player")
	target = pl[0] if pl.size() > 0 else null
	if target != null:
		enemy.set("target", target)


func _detect() -> float:
	return float(enemy.detection_range) if "detection_range" in enemy else 450.0


func _allies() -> Array[EnemyAI]:
	var out: Array[EnemyAI] = []
	var parent := enemy.get_parent()
	if parent == null:
		return out
	for e in parent.get_children():
		if e == enemy or not is_instance_valid(e) or e.is_queued_for_deletion():
			continue
		var ai := e.get_node_or_null("EnemyAI")
		if ai is EnemyAI and not ai._dead:
			out.append(ai)
	return out


func _max_ally_health() -> float:
	var m := 0.0
	for a in _allies():
		m = maxf(m, float(a.enemy.get("max_health")))
	return m


func _committed() -> bool:
	var ch = enemy.get("_charging")
	if ch != null and float(ch) > 0.0:
		return true
	if not ("state" in enemy):
		return false
	var names := _state_name()
	return names in COMMITTED


## Devuelve al enemigo a un estado limpio (sin aviso/embestida a medias).
func _clear_commit() -> void:
	_reset_enemy_state()


func _reset_enemy_state() -> void:
	if "state" in enemy and not _is_dead_state():
		enemy.state = 0
	for prop in ["_charging", "_windup_timer", "_charge_duration_timer", "_state_timer"]:
		if prop in enemy:
			enemy.set(prop, 0.0)
	if "_is_charging" in enemy:
		enemy._is_charging = false
	if _sprite != null:
		_sprite.modulate = Color.WHITE
		_sprite.offset.x = 0.0


func _is_dead_state() -> bool:
	return _state_name() == "DEAD"


## Nombre del estado actual del enemigo (cada clase tiene su propio enum State).
func _state_name() -> String:
	var scr = enemy.get_script()
	while scr != null:
		var consts: Dictionary = scr.get_script_constant_map()
		if consts.has("State") and consts["State"] is Dictionary:
			var key = (consts["State"] as Dictionary).find_key(int(enemy.state))
			return String(key) if key != null else ""
		scr = scr.get_base_script()
	return ""


func _hero_confuses() -> bool:
	return bool(p.confuse)


func _source_pos(source: Node) -> Vector2:
	if source is Node2D:
		return (source as Node2D).global_position
	return target.global_position if target != null else enemy.global_position


func _hit_from_behind(src: Vector2) -> bool:
	var facing := -1.0 if (_sprite != null and _sprite.flip_h) else 1.0
	return (src.x - enemy.global_position.x) * facing < -4.0


func _speed_mult() -> float:
	var m: float = p.speed_mult * _race_mult
	if _enraged:
		m *= p.rage_speed
	if _grudge:
		m *= 1.15
	return m


func _apply_stats() -> void:
	var m := _speed_mult()
	if absf(m - _speed_applied) > 0.001:
		_speed_applied = m
		for prop in _base:
			if prop != "damage":
				enemy.set(prop, _base[prop] * m)
	var dm := 1.15 if _resentful else 1.0
	if absf(dm - _dmg_applied) > 0.001:
		_dmg_applied = dm
		if "damage" in enemy:
			enemy.damage = _base["damage"] * dm


func _apply_tint(delta: float) -> void:
	if _sprite == null:
		return
	_tint_phase += delta * 9.0
	var c := Color.WHITE
	if mode == Mode.SLEEP:
		c = Color(0.62, 0.68, 0.95)
	elif mode == Mode.SHELL:
		c = Color(0.72, 0.72, 0.88)
	elif mode == Mode.DISCHARGE:
		c = Color(0.55, 0.6, 0.7)
	elif mode == Mode.SURRENDER:
		c = Color(0.85, 0.85, 0.95)
	elif _enraged:
		var k := 0.5 + 0.5 * sin(_tint_phase)
		c = Color(1.45, 0.5 + 0.15 * k, 0.5 + 0.15 * k)
	elif _resentful:
		c = Color(1.2, 0.6, 1.3)
	elif _grudge:
		c = Color(1.25, 0.8, 0.8)
	_sprite.self_modulate = Color(c.r, c.g, c.b, _sprite.self_modulate.a)


func _emote_icon(icon: String, secs := 1.1) -> void:
	if _emote != null and is_instance_valid(_emote):
		_emote.show_icon(icon, secs)


func _say(event: String, secs := 2.0) -> void:
	if _emote == null or not is_instance_valid(_emote):
		return
	if _say_cd > 0.0 and event not in ["flee", "surrender", "alarm"]:
		return
	var text := EnemyPersonalities.say_text(variant, event)
	if text == "":
		return
	_emote.say(text, secs)
	_say_cd = maxf(_say_cd, 1.2)
