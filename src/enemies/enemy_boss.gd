extends CharacterBody2D
class_name EnemyBoss

const ITEM_PICKUP_SCENE := preload("res://src/items/item_pickup.tscn")
const PROJECTILE := preload("res://src/enemies/projectile_enemy.tscn")
const MINION := preload("res://src/enemies/enemy_swarmer.tscn")

## Base de los jefes de piso. Cada jefe hereda de aqui (src/enemies/bosses/boss_*.gd) y
## define SU lista de ataques por fase (_attack_pool) y los ataques como corrutinas
## (func atk_xxx() -> void, con `if not await _wait(t): return` tras cada espera:
## false = el ataque se cancelo por cambio de fase o muerte).
## Reglas de diseno (estilo Gungeon):
## - todo ataque AVISA antes de golpear (parpadeo + zona en el suelo, 0.5-0.9 s);
## - tras los ataques fuertes queda AGOTADO: esa es la ventana para pegarle (x1.5);
## - 3 fases (66% / 33%): cada una cambia la lista de ataques y aprieta los tiempos.
## Las frases salen de lines.json: boss<piso>_intro/_phase2/_phase3/_death/_after.

@export var enemy_name: String = "JEFE"
@export var max_health: float = 600.0
@export var move_speed: float = 70.0
@export var damage: float = 16.0
@export var drop_table: Array[Dictionary] = []

enum State { INTRO, IDLE, ATTACK, TIRED, TRANSITION, DEAD }

## Avisos para quien anime o mida al jefe (el animador, el bot): nada depende de ellas.
signal telegraph_started(secs: float)
signal attack_released(attack_name: StringName)
signal channel_started(challenge: StringName)
signal channel_ended(cut: bool)

## MOTOR DINAMICO (J1): apagado por defecto; cada jefe lo enciende en su _ready (por ahora solo
## Doña Cera). Encendido: reposo corto, avisos acotados por fase (0.65/0.5/0.4 s), combos de
## 2-3 ataques en fase 2-3 sin pausa, balas mas rapidas, defensa durante la cura y resumen
## "[boss-stats]" al terminar la pelea.
var dynamic := false
var rest_min := 0.8
var rest_max := 1.3
## Velocidad de las balas del abanico base.
var bullet_speed := 230.0
## Tope del aviso por fase en modo dinamico (cada jefe lo ajusta).
var tele_caps := [0.65, 0.5, 0.4]
## Ataques que le quedan encadenar antes de volver al reposo.
var _combo_left := 0

## Dano extra que recibe agotado (antes x2: demasiado).
const TIRED_MULT := 1.5
## Tope de bichos invocados vivos a la vez.
const MINION_CAP := 6
const PHASE2_AT := 0.66
const PHASE3_AT := 0.33

## Vida segun el piso: antes 450+150*piso, muy corta para lo que dura el combate.
## Solo para pruebas del bot (--boss-hp=1,1,12,12,12): multiplicador de vida por piso.
static var test_hp_mults: Array = []

static func health_for_floor(floor_n: int) -> float:
	var m := 1.0
	if floor_n - 1 < test_hp_mults.size():
		m = float(test_hp_mults[floor_n - 1])
	return (1000.0 + 450.0 * floor_n) * m


## Script propio de cada jefe, por la variante de sprite (fd.boss).
static func script_path(variant: String) -> String:
	return "res://src/enemies/bosses/boss_%s.gd" % variant.trim_prefix("boss_")


var current_health: float = 600.0
var current_phase: int = 1
var state: State = State.INTRO
var target: Node2D = null
## Mientras es true el jefe no recibe dano (escudos).
var invuln := false

var _timer: float = 0.0
var _gen := 0  # sube al cancelar: las corrutinas de ataque viejas se rinden
var _last_attack: StringName = &""
var _floor: int = 1
## Reino del jefe en el orden fijo (1 Selva .. 5 Palacio), igual para todos los heroes: elige
## sus frases (boss<n>_*). _floor es la posicion en la ruta y escala la dificultad.
var _canon: int = 1
var _hit_done := false
var _charge_dir: Vector2 = Vector2.ZERO
var _arena: Rect2 = Rect2()
var _arena_ok := false
var _shield_msg_cd := 0.0
## Distancia que quiere mantener con el jugador al reposicionarse.
var keep_min := 170.0
var keep_max := 300.0
var _orbit := 1.0
var _orbit_t := 0.0
## Recuperacion interrumpible ("racha"): veces que le quedan, si toca en la proxima pausa,
## si esta canalizando y cuanto dano ha recibido canalizando.
var _channels_left := 1
var _channels_total := 1
var _chan_cd := 6.0
var _chan_pending := false
var _channeling := false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var _ge: Node = get_node("/root/GlobalEvents")


func _ready() -> void:
	ActorFx.setup_actor(self, animated_sprite)
	current_health = max_health
	add_to_group("enemy")
	add_to_group("boss")
	_floor = RunManager.region_index(get_node("/root/RunManager").current_floor) + 1  # reino 1..5 (el jefe es de la 2a etapa)
	_canon = RunManager.canon_region_index(get_node("/root/RunManager").current_floor) + 1
	hurtbox.area_entered.connect(_on_hurtbox_entered)
	hitbox.add_to_group("enemy_attack")
	hitbox.monitorable = false
	hitbox.monitoring = true
	# Curas: tantas como el numero de piso (jefe 1 = 1 ... jefe 5 = 5).
	_channels_total = _floor
	_channels_left = _floor
	_chan_cd = 6.0
	_timer = 2.2
	_say("intro")
	_emit_health()
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not target or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player")
		if not target:
			return
	_timer -= delta
	_shield_msg_cd = maxf(0.0, _shield_msg_cd - delta)
	if dynamic:
		_stats_tick(delta)
	if not _channeling:
		_chan_cd = maxf(0.0, _chan_cd - delta)
	match state:
		State.INTRO, State.TRANSITION:
			velocity = Vector2.ZERO
			animated_sprite.offset.x = sin(_timer * 80.0) * 2.0 if state == State.TRANSITION else 0.0
			if _timer <= 0.0:
				animated_sprite.offset.x = 0.0
				animated_sprite.modulate = Color.WHITE
				_go_idle()
		State.IDLE:
			_idle_move(delta)
			if _timer <= 0.0:
				_start_attack()
		State.TIRED:
			velocity = velocity.lerp(Vector2.ZERO, 6.0 * delta)
			if _timer <= 0.0:
				animated_sprite.modulate = Color.WHITE
				_go_idle()
	_tick(delta)
	if state in [State.IDLE, State.TIRED, State.INTRO, State.TRANSITION]:
		_update_animation()
	move_and_slide()


# ---------------------------------------------------------------- ganchos para cada jefe
## Lista de ataques disponibles (nombres de funciones atk_*) segun la fase.
## Repite un nombre para que salga mas a menudo.
func _attack_pool() -> Array:
	return [&"atk_fan", &"atk_charge"]


## Se llama cada frame de fisica (menos muerto): comportamientos pasivos.
func _tick(_delta: float) -> void:
	pass


## Al entrar en una fase nueva (ya cancelado todo y con los proyectiles limpios).
func _on_phase(_n: int) -> void:
	pass


## Al morir (antes de la animacion de muerte).
func _on_death() -> void:
	pass


## Reposicionamiento con intencion: mantiene una banda de distancia, rodea al jugador
## y se aparta de los muros. (Antes solo avanzaba si estabas a mas de 180 px, y un
## jugador que se quedaba cerca lo dejaba plantado.)
func _idle_move(delta: float) -> void:
	var to_t: Vector2 = target.global_position - global_position
	var d := to_t.length()
	_orbit_t -= delta
	if _orbit_t <= 0.0:
		_orbit = -_orbit
		_orbit_t = RNG.randf_range(1.5, 3.0)
	var n := to_t.normalized()
	var dir := Vector2.ZERO
	if d > keep_max:
		dir = n
	elif d < keep_min:
		dir = -n * 0.7 + n.orthogonal() * _orbit * 0.7
	else:
		dir = n.orthogonal() * _orbit
	var a := arena()
	var edge := minf(minf(global_position.x - a.position.x, a.end.x - global_position.x), minf(global_position.y - a.position.y, a.end.y - global_position.y))
	if edge < 120.0:
		dir += (a.get_center() - global_position).normalized() * 1.3
	velocity = dir.normalized() * move_speed


## Camina hacia un punto (para colocarse antes de un ataque). false = cancelado.
func _walk_to(pos: Vector2, secs := 1.2, speed := 0.0) -> bool:
	var sp := speed if speed > 0.0 else move_speed * 2.0
	var t := 0.0
	while t < secs and global_position.distance_to(pos) > 24.0:
		velocity = (pos - global_position).normalized() * sp
		if not await _frame():
			return false
		t += 1.0 / 60.0
	velocity = Vector2.ZERO
	return true


## Siguiente ataque de un combo (solo motor dinamico). Cada jefe lo afina; por defecto, el pool.
func _combo_next() -> StringName:
	var options := _attack_pool()
	return options[RNG.randi_range(0, options.size() - 1)]


## Cuantos ataques EXTRA encadena tras uno normal (0 en fase 1).
func _combo_len() -> int:
	return 0 if current_phase < 2 else RNG.randi_range(0, current_phase - 1)


func _pick_attack() -> StringName:
	if dynamic and _combo_left > 0 and not _chan_pending:
		_combo_left -= 1
		return _combo_next()
	# Curarse: al cambiar de fase o con la vida baja (mitad), con enfriamiento.
	if _channels_left > 0 and _chan_cd <= 0.0 and (_chan_pending or current_health < max_health * 0.5):
		_chan_pending = false
		_channels_left -= 1
		_chan_cd = 16.0
		_ge.boss_charges_changed.emit(_channels_left, _channels_total)
		_combo_left = 0
		return &"atk_canalizar"
	if dynamic:
		_combo_left = _combo_len()
	var options := _attack_pool().filter(func(x): return x != _last_attack)
	if options.is_empty():
		options = _attack_pool()
	return options[RNG.randi_range(0, options.size() - 1)]


# ---------------------------------------------------------------- maquina de ataques
func _start_attack() -> void:
	var a := _pick_attack()
	_last_attack = a
	state = State.ATTACK
	velocity = Vector2.ZERO
	_gen += 1
	var g := _gen
	attack_released.emit(a)
	await Callable(self, a).call()
	if g == _gen and state == State.ATTACK:
		if dynamic and _combo_left > 0:
			_start_attack()  # combo: sin pausa al siguiente
			return
		_go_idle()


## Espera `secs` (en trozos de 0.5 s para rendirse pronto). false = ataque cancelado.
func _wait(secs: float) -> bool:
	var g := _gen
	var left := secs
	while left > 0.0:
		if not is_inside_tree():
			return false  # el arbol se libera (fin de partida): la corrutina se rinde
		var s := minf(left, 0.5)
		await get_tree().create_timer(s, true, true).timeout
		if g != _gen or state != State.ATTACK or not is_inside_tree():
			return false
		left -= s
	return true


## Un frame de fisica. false = ataque cancelado.
func _frame() -> bool:
	var g := _gen
	if not is_inside_tree():
		return false
	await get_tree().physics_frame
	return g == _gen and state == State.ATTACK and is_inside_tree()


## Aviso del jefe: parpadea y tiembla durante `secs`. `on_frame(restante)` se llama
## cada frame (para seguir al jugador con las lineas de aviso). false = cancelado.
func _tele(secs: float, col := Color(2.0, 2.0, 0.9), shake := 2.0, on_frame := Callable()) -> bool:
	if dynamic:
		secs = minf(secs, tele_caps[clampi(current_phase, 1, 3) - 1])
	telegraph_started.emit(secs)
	animated_sprite.play("attack")
	var left := secs
	while left > 0.0:
		if not await _frame():
			_reset_fx()
			return false
		left -= 1.0 / 60.0
		animated_sprite.modulate = col if int(left * 16.0) % 2 == 0 else Color.WHITE
		animated_sprite.offset.x = sin(left * 90.0) * shake
		if on_frame.is_valid():
			on_frame.call(left)
	_reset_fx()
	return true


## Lo que haya que devolver a la normalidad al volver al reposo (escala, etc.).
func _reset_idle() -> void:
	pass


func _reset_fx() -> void:
	animated_sprite.modulate = Color.WHITE
	animated_sprite.offset.x = 0.0


func _go_idle() -> void:
	_reset_idle()
	state = State.IDLE
	if dynamic:
		_timer = RNG.randf_range(rest_min, rest_max)
		return
	_timer = maxf(0.35, RNG.randf_range(0.8, 1.3) - current_phase * 0.15)


## Aturdido por algo que hizo el jugador (rompio los huevos / las hojas): corta lo que hacia.
func _stun(seconds: float) -> void:
	_gen += 1
	_reset_fx()
	_tire(seconds)
	set_meta("stunned", true)  # lo lee BossAnimator: aturdida (mareo) != agotada (recupera el aliento)
	HitFx.shake(0.35)


func _tire(seconds: float) -> void:
	_combo_left = 0
	set_meta("stunned", false)
	state = State.TIRED
	_timer = seconds
	velocity = velocity * 0.3
	animated_sprite.modulate = Color(0.6, 0.6, 0.75)
	animated_sprite.offset.x = 0.0


# ---------------------------------------------------------------- ataques comunes
## Abanico dirigido: aviso con una linea hacia ti, 2-4 salvas.
var fan_shots := 5
var fan_tint := Color(0, 0, 0, 0)

func atk_fan() -> void:
	var line := BossZone.rect(global_position, Vector2(300, 8), 0.0, 0.7, 0.05, 0.0)
	_add_hazard(line)
	var track := func(_left: float):
		if is_instance_valid(line):
			var d: Vector2 = (target.global_position - _muzzle()).normalized()
			line.global_position = _muzzle() + d * 150.0
			line.rotation = d.angle()
	if not await _tele(0.65, Color(2.0, 2.0, 0.9), 2.0, track):
		return
	var volleys := 1 + current_phase
	for v in volleys:
		_fire_fan(fan_shots + (current_phase - 1) * 2)
		if v < volleys - 1 and not await _wait(0.55 - current_phase * 0.06):
			return
	await _wait(0.25)


## Embestida: aviso largo con una franja en el suelo; agotado tras chocar.
func atk_charge() -> void:
	var lane := BossZone.rect(global_position, Vector2(600, 90), 0.0, 0.9, 0.05, 0.0, Color(1.0, 0.25, 0.2))
	_add_hazard(lane)
	_charge_dir = (target.global_position - global_position).normalized()
	var track := func(left: float):
		if left > 0.25:
			_charge_dir = (target.global_position - global_position).normalized()
		if is_instance_valid(lane):
			var ln := _ray_len(global_position + Vector2(0, -50), _charge_dir, 700.0)
			lane.size.x = ln
			lane.global_position = global_position + _charge_dir * ln * 0.5
			lane.rotation = _charge_dir.angle()
	if not await _tele(0.85, Color(2.2, 0.6, 0.6), 3.0, track):
		return
	Sound.play("dash")
	_hit_done = false
	var t := 0.0
	var hit_wall := false
	while t < 0.75:
		velocity = _charge_dir * (430.0 + current_phase * 50.0)
		if not await _frame():
			return
		_strike()
		t += 1.0 / 60.0
		if get_slide_collision_count() > 0:
			hit_wall = true
			break
	HitFx.shake(0.3 if hit_wall else 0.1)
	# Contra la pared se queda mas tiempo atontado: premio por esquivar bien.
	_tire(1.7 if hit_wall else 1.0)
	set_meta("stunned", hit_wall)  # choque contra la pared: aturdida de verdad


# ---------------------------------------------------------------- recuperacion interrumpible
## "Racha": el jefe se queda canalizando para curarse. Es invulnerable y la unica forma de
## cortarlo es cumplir un DESAFIO propio (cada jefe tiene un repertorio, _challenges(), y
## usa uno distinto en cada carga, en orden). Cargas = numero de piso; cada intento gasta
## una aunque lo cortes. Si cumples el desafio antes de que acabe el tiempo la cura se
## corta y el jefe queda aturdido; si no, recupera CHANNEL_HEAL de su vida maxima.
const CHANNEL_HEAL := 0.15
const CHANNEL_STUN := 3.0

var _chan_ok := false
var _chan_fail := false
var _chan_prog := 0.0
var _chan_idx := 0
var _chan_t := 0.0
var _chan_fx: BossZone = null
## Reaccion a un golpe del jugador mientras canaliza (desafios de "pegarle").
var _ch_hit_cb := Callable()
## Ayudas para el bot de pruebas (tools/autoplay): a donde ir, a donde apuntar y cuando hacer dash.
var bot_goal_pos: Variant = null
var bot_aim_pos: Variant = null
var bot_target_node: Node2D = null
var bot_dash_vec := Vector2.ZERO
var bot_dash_now := false
var _blackout: CanvasLayer = null
var _blackout_mat: ShaderMaterial = null


## Nombres (funciones ch_*) de los desafios del jefe, en el orden en que los usa.
func _challenges() -> Array:
	return []


func _channel_color() -> Color:
	return Color(1.0, 0.8, 0.3)


## true = el vortice del Satisfyer no lo arrastra (burbuja de la Hoja de Parra).
func is_suck_immune() -> bool:
	return false


func _on_channel_hit(amount: float, source: Node) -> void:
	if _chan_t < 0.4:
		return  # las balas ya en vuelo al empezar no cuentan
	if _ch_hit_cb.is_valid():
		_ch_hit_cb.call(amount, source)


func atk_canalizar() -> void:
	var list := _challenges()
	if list.is_empty():
		return
	var ch: StringName = list[_chan_idx % list.size()]
	_chan_idx += 1
	var g := _gen
	_channeling = true
	_chan_ok = false
	_chan_fail = false
	_chan_prog = 0.0
	_chan_t = 0.0
	_ch_hit_cb = Callable()
	_ch_extra = 0.0
	_reset_bot_hints()
	velocity = Vector2.ZERO
	_st_cures += 1
	channel_started.emit(ch)
	var col := _channel_color()
	var key := "BOSS_CH_" + String(ch).substr(3).to_upper()
	var fx := BossZone.circle(global_position, 95.0, 0.0, -1.0, 0.0, col)
	fx.style = BossZone.Style.CHANNEL
	fx.follow = self
	fx.follow_offset = Vector2(0, -60)
	fx.label = tr(key + "_T")
	fx.label2 = tr(key + "_D")
	_add_hazard(fx)
	_chan_fx = fx
	_float_text(tr(key + "_T"), col)
	Sound.play("suck")
	animated_sprite.play("attack")
	await Callable(self, ch).call()
	_reset_bot_hints()
	_ch_hit_cb = Callable()
	if g != _gen:
		_channeling = false
		return
	_channeling = false
	print("[boss] %s: desafio %s -> %s (%.1f s, cargas restantes %d)" % [enemy_name, ch, "CORTADA" if _chan_ok else "se cura", _chan_t, _channels_left])
	_blackout_stop()
	_reset_fx()
	_clear_hazards()
	if _chan_ok:
		_float_text(_chan_label("BREAK"), Color("ffe08a"))
		Sound.play("crack")
		_st_cuts += 1
		_stun(_cure_cut_stun())
		_on_cure_cut()
	else:
		current_health = minf(max_health, current_health + max_health * CHANNEL_HEAL)
		_emit_health()
		_float_text(_chan_label("DONE"), col)
		HitFx.shake(0.3)
		_on_cure_done()
	channel_ended.emit(_chan_ok)


## Texto flotante al cortar ("BREAK") o completar ("DONE") la cura; cada jefe puede cambiarlo.
func _chan_label(kind: String) -> String:
	return tr("BOSS_CHAN_" + kind)


## Ganchos de la cura (el jefe dinamico los usa para premiar/castigar): aturdido al cortarla,
## y que pasa cuando se corta o se completa.
func _cure_cut_stun() -> float:
	return CHANNEL_STUN


func _on_cure_cut() -> void:
	pass


func _on_cure_done() -> void:
	pass


## Defensa mientras canaliza: se llama cada frame dentro de _ch_loop (solo motor dinamico).
func _defend(_dt: float) -> void:
	pass


## Segundos extra de la cura (tocar un senuelo le regala tiempo).
var _ch_extra := 0.0


func _reset_bot_hints() -> void:
	bot_goal_pos = null
	bot_aim_pos = null
	bot_target_node = null
	bot_dash_vec = Vector2.ZERO
	bot_dash_now = false


## Bucle comun de los desafios: dura como mucho `limit` s, o hasta cumplirse (_chan_ok) o
## fallar (_chan_fail). on_frame(delta) se llama cada frame. Termina antes si se cancela.
func _ch_loop(limit: float, on_frame := Callable()) -> void:
	_chan_t = 0.0
	while _chan_t < limit + _ch_extra and not _chan_ok and not _chan_fail:
		if not await _frame():
			return
		_chan_t += 1.0 / 60.0
		if dynamic:
			_defend(1.0 / 60.0)
		animated_sprite.modulate = Color.WHITE.lerp(_channel_color() * 1.6, 0.25 + 0.2 * sin(_chan_t * 12.0))
		if on_frame.is_valid():
			on_frame.call(1.0 / 60.0)
		if is_instance_valid(_chan_fx):
			_chan_fx.p_time = _chan_t / (limit + _ch_extra)
			_chan_fx.p_break = _chan_prog


## Crea un objeto de desafio (dibujo y logica por lambdas) en la sala.
func _make_prop(pos: Vector2, drawer: Callable, updater := Callable(), data := {}) -> BossProp:
	var p := BossProp.new()
	p.drawer = drawer
	p.updater = updater
	p.data = data
	var cont := _spawn_container()
	cont.add_child(p)
	p.global_position = pos
	return p


func _refill_stamina() -> void:
	var ps := get_node("/root/PlayerStats")
	ps.current_stamina = ps.max_stamina


## Jefe desesperado: huye del jugador por la sala (rodeando, cambiando de sentido y
## sin quedarse arrinconado en un muro). Hay que perseguirlo mientras se apunta.
var _flee_side := 1.0
var _flee_t := 0.0

func _flee(speed: float, dt: float) -> void:
	_flee_t -= dt
	if _flee_t <= 0.0:
		_flee_side = -_flee_side
		_flee_t = RNG.randf_range(1.0, 2.2)
	var away: Vector2 = global_position - target.global_position
	var dir := away.normalized()
	var to_c: Vector2 = arena().get_center() - global_position
	var tang := dir.orthogonal() * _flee_side
	var a := arena()
	var edge := minf(minf(global_position.x - a.position.x, a.end.x - global_position.x), minf(global_position.y - a.position.y, a.end.y - global_position.y))
	var w := clampf(1.0 - edge / 170.0, 0.0, 1.0)
	var v := dir * (1.0 - w) * 0.8 + to_c.normalized() * w * 1.2 + tang * 0.7
	velocity = v.normalized() * speed


func _body_center() -> Vector2:
	return global_position + Vector2(0, -60)


# --- apagon (oscuridad total salvo tu halo): comun al Aduanero y a la Hoja de Parra
func _blackout_start(halo: float, tint: Color, amount := 0.97) -> void:
	if is_instance_valid(_blackout):
		return
	_blackout = CanvasLayer.new()
	_blackout.layer = 1
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackout_mat = ShaderMaterial.new()
	_blackout_mat.shader = load("res://src/shaders/blackout.gdshader")
	_blackout_mat.set_shader_parameter("rad_a", halo)
	_blackout_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_blackout_mat.set_shader_parameter("amount", 0.0)
	rect.material = _blackout_mat
	_blackout.add_child(rect)
	var main := get_tree().get_first_node_in_group("main")
	var host: Node = main if main else get_tree().current_scene
	host.add_child(_blackout)
	host.move_child(_blackout, mini(1, host.get_child_count() - 1))
	create_tween().tween_property(_blackout_mat, "shader_parameter/amount", amount, 0.5)


func _blackout_update(boss_world: Vector2, boss_glow: float) -> void:
	if not is_instance_valid(_blackout) or target == null:
		return
	var xf := target.get_global_transform_with_canvas()
	var xb := get_global_transform_with_canvas()
	_blackout_mat.set_shader_parameter("vp_size", get_viewport().get_visible_rect().size)
	_blackout_mat.set_shader_parameter("hole_a", xf.origin + Vector2(0, -20))
	_blackout_mat.set_shader_parameter("hole_b", xb.origin + (boss_world - global_position))
	_blackout_mat.set_shader_parameter("rad_b", boss_glow)


func _blackout_stop() -> void:
	if is_instance_valid(_blackout):
		var layer := _blackout
		var mat := _blackout_mat
		var tw := layer.create_tween()
		tw.tween_property(mat, "shader_parameter/amount", 0.0, 0.3)
		tw.tween_callback(layer.queue_free)
	_blackout = null


func _exit_tree() -> void:
	_print_stats("pelea abandonada (jugador muerto o salida)")
	if is_instance_valid(_blackout):
		_blackout.queue_free()


## Apagon: el jefe vaga por la sala; solo se ve lo que tu halo ilumina y un brillo tenue
## sobre el. Hay que encontrarlo y darle `hits_needed` veces.
var _wander_pt := Vector2.ZERO
var _wander_t := 0.0
var _ch_hits := 0

func _ch_blackout(halo: float, tint: Color, hits_needed: int, glow: float, limit := 11.0) -> void:
	_blackout_start(halo, tint)
	_ch_hits = 0
	_wander_t = 0.0
	_ch_hit_cb = func(_a, _s):
		_ch_hits += 1
		_chan_prog = float(_ch_hits) / hits_needed
		Sound.play("enemy_hit")
		if _ch_hits >= hits_needed:
			_chan_ok = true
	bot_target_node = self
	await _ch_loop(limit, func(dt):
		_flee(150.0, dt)
		_blackout_update(_body_center(), glow))
	velocity = Vector2.ZERO
	_blackout_stop()


## Clones: `n` reinas (la real es el propio jefe, que se coloca en uno de los puntos). Solo la
## real tiene sombra de contacto y proyectada por las antorchas. Pegarle a la real corta la
## cura; una falsa explota en algo leve.
func _ch_clones(n: int, limit := 11.0) -> void:
	var c := arena().get_center()
	var ang0 := RNG.randf_range(0.0, TAU)
	var spots: Array[Vector2] = []
	for i in n:
		spots.append(clamp_to_arena(c + Vector2.RIGHT.rotated(ang0 + i * TAU / n) * 210.0, 110.0))
	var real := RNG.randi_range(0, n - 1)
	for p in spots:
		_add_hazard(BossZone.circle(p, 48.0, 0.7, 0.05, 0.0, _channel_color()))
	if not await _wait(0.7):
		return
	global_position = spots[real]
	velocity = Vector2.ZERO
	var tex := animated_sprite.sprite_frames.get_frame_texture("idle", 0)
	for i in n:
		if i == real:
			continue
		var f := BossBreakable.new()
		f.kind = BossBreakable.Kind.FAKE
		f.enemy_name = "Falsa"
		f.max_health = 6.0
		f.life = -1.0
		f.tex = tex
		f.tex_scale = animated_sprite.scale
		f.tex_flip = animated_sprite.flip_h
		f.color = _channel_color()
		_spawn_container().add_child(f)
		f.global_position = spots[i]
		f.broken.connect(func(b): _fake_pop(b.global_position))
	_ch_hit_cb = func(_a, _s):
		_chan_ok = true
	bot_target_node = self
	await _ch_loop(limit)


func _fake_pop(pos: Vector2) -> void:
	var z := BossZone.circle(pos, 60.0, 0.4, 0.15, damage * 0.3, _channel_color())
	_add_hazard(z)


# ---------------------------------------------------------------- estadisticas de la pelea
var _st_t := 0.0
var _st_threat := 0.0
var _st_atk := 0.0
var _st_hits := 0
var _st_cures := 0
var _st_cuts := 0
var _st_minions := 0
var _st_iframes := 0.0
var _st_done := false
var _st_by := {}  # golpes al jugador por ataque


## Nombre de lo que acaba de pegar al jugador fuera de un ataque (para el resumen de la pelea).
func _hit_source() -> String:
	return "pasivo/reposo"


## Amenaza = el jefe tiene un ataque activo (los jefes dinamicos lo afinan: pasivos, etc.).
func _is_threatening() -> bool:
	return state == State.ATTACK


func _stats_tick(delta: float) -> void:
	if state in [State.INTRO, State.TRANSITION]:
		return
	_st_t += delta
	if _is_threatening():
		_st_threat += delta
	if state == State.ATTACK:
		_st_atk += delta
	var ifr := float(target.get("_iframes"))
	if ifr > _st_iframes + 0.3:
		_st_hits += 1
		var k := String(_last_attack) if state == State.ATTACK else _hit_source()
		_st_by[k] = int(_st_by.get(k, 0)) + 1
		if OS.has_environment("BOSS_DEBUG"):
			print("[boss-hit] t=%.1f fase=%d %s dist=%.0f gotas=%d vel_jug=%.0f" % [_st_t, current_phase, k, target.global_position.distance_to(global_position), get_tree().get_nodes_in_group("gota_cera").size(), (target as CharacterBody2D).velocity.length()])
	_st_iframes = ifr


## Resumen de la pelea para el bot (una sola vez por jefe).
func _print_stats(result: String) -> void:
	if not dynamic or _st_done or _st_t < 0.5:
		return
	_st_done = true
	print("[boss-stats] %s | %s | duracion=%.1f s | ataque_activo=%.0f%% | solo_ataque=%.0f%% | golpes_al_jugador=%d | curas_intentadas=%d | curas_cortadas=%d | esbirros=%d | fase_final=%d | golpes_por=%s" % [
		enemy_name, result, _st_t, 100.0 * _st_threat / maxf(_st_t, 0.01), 100.0 * _st_atk / maxf(_st_t, 0.01), _st_hits, _st_cures, _st_cuts, _st_minions, current_phase, _st_by])


# ---------------------------------------------------------------- utilidades de combate

func _muzzle() -> Vector2:
	return global_position + Vector2(0, -50)


## Pega a quien solapa el hitbox AHORA (una vez por embestida). No se usa area_entered
## porque al apagar monitorable Godot no borra el solape y el siguiente ataque
## a quemarropa nunca generaba un "enter" nuevo.
func _strike() -> void:
	if _hit_done:
		return
	for b in hitbox.get_overlapping_bodies():
		if b.has_method("receive_hit") and b.receive_hit(damage):
			_hit_done = true


func _drift() -> void:
	var to_target: Vector2 = target.global_position - global_position
	velocity = to_target.normalized() * move_speed if to_target.length() > 180.0 else Vector2.ZERO


## Bala del jefe. mult = fraccion del dano del jefe.
func _fire(angle: float, speed: float, mult := 0.7, tint := Color(0, 0, 0, 0)) -> ProjectileEnemy:
	var p := PROJECTILE.instantiate()
	p.damage = damage * mult
	p.speed = speed
	p.projectile_owner = self
	p.lifetime = 6.0
	p.tint = tint if tint.a > 0.0 else fan_tint
	_spawn_container().add_child(p)
	p.global_rotation = angle
	p.global_position = _muzzle() + Vector2.RIGHT.rotated(angle) * 30.0
	return p


## Bala disparada desde un punto cualquiera.
func _fire_from(pos: Vector2, angle: float, speed: float, mult := 0.7, tint := Color(0, 0, 0, 0), life := 6.0) -> ProjectileEnemy:
	var p := PROJECTILE.instantiate()
	p.damage = damage * mult
	p.speed = speed
	p.projectile_owner = self
	p.lifetime = life
	p.tint = tint if tint.a > 0.0 else fan_tint
	_spawn_container().add_child(p)
	p.global_rotation = angle
	p.global_position = pos
	return p


func _fire_fan(shots: int) -> void:
	var base: float = (target.global_position - _muzzle()).angle()
	for i in range(shots):
		_fire(base + (i - (shots - 1) / 2.0) * 0.17, bullet_speed)


## Anade una zona de peligro a la sala. Devuelve la misma zona.
## La posicion con la que se creo la zona (BossZone.circle/rect) es GLOBAL.
func _add_hazard(z: BossZone) -> BossZone:
	var gp := z.position
	_spawn_container().add_child(z)
	z.global_position = gp
	return z


## Zona de aviso sin dano (linea o circulo que solo informa).
func _warn_line(from: Vector2, dir: Vector2, length: float, width: float, secs: float, col := Color(1.0, 0.3, 0.25)) -> BossZone:
	var z := BossZone.rect(from + dir * length * 0.5, Vector2(length, width), dir.angle(), secs, 0.05, 0.0, col)
	_add_hazard(z)
	return z


## Largo libre desde `from` en la direccion `dir` hasta un muro (max `max_len`).
func _ray_len(from: Vector2, dir: Vector2, max_len: float) -> float:
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * max_len, 1)
	var res := get_world_2d().direct_space_state.intersect_ray(q)
	if res:
		return from.distance_to(res.position) - 6.0
	return max_len


## Interior de la sala (global), medido con rayos desde el centro hasta los muros.
func arena() -> Rect2:
	if _arena_ok:
		return _arena
	var room := find_owning_room()
	var c := global_position
	if room:
		c = room.global_position + room.get_center_position()
	var space := get_world_2d().direct_space_state
	var ext := {}
	for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var q := PhysicsRayQueryParameters2D.create(c, c + d * 1500.0, 1)
		var res := space.intersect_ray(q)
		ext[d] = (c.distance_to(res.position) if res else 600.0)
	_arena = Rect2(c - Vector2(ext[Vector2.LEFT], ext[Vector2.UP]), Vector2(ext[Vector2.LEFT] + ext[Vector2.RIGHT], ext[Vector2.UP] + ext[Vector2.DOWN]))
	_arena_ok = true
	return _arena


func arena_point(margin := 70.0) -> Vector2:
	var a := arena().grow(-margin)
	return _on_floor(Vector2(RNG.randf_range(a.position.x, a.end.x), RNG.randf_range(a.position.y, a.end.y)))


func clamp_to_arena(p: Vector2, margin := 70.0) -> Vector2:
	var a := arena().grow(-margin)
	return _on_floor(Vector2(clampf(p.x, a.position.x, a.end.x), clampf(p.y, a.position.y, a.end.y)))


## En una sala con forma (octogono, cruz...) el rectangulo de la arena incluye esquinas de muro: el punto
## se lleva al suelo pisable (si no, huevos, clones y hojas aparecian dentro de la pared y el jefe se
## teletransportaba a ella y salia por el otro lado).
func _on_floor(p: Vector2) -> Vector2:
	var room := find_owning_room()
	return room.snap_global(p, 22.0) if room != null else p


## Invoca bichos hasta el tope. Devuelve cuantos salieron.
func _spawn_minions(positions: Array, hp := 12.0, dmg := 8.0, label := "Espermatozoide", scene: PackedScene = null) -> int:
	var made := 0
	for p in positions:
		if get_tree().get_nodes_in_group("boss_minion").size() >= MINION_CAP:
			break
		var m := (scene if scene != null else MINION).instantiate()
		m.max_health = hp
		m.damage = dmg
		m.enemy_name = label
		m.add_to_group("boss_minion")
		_spawn_container().add_child(m)
		m.global_position = p
		made += 1
	_st_minions += made
	return made


func _minion_count() -> int:
	return get_tree().get_nodes_in_group("boss_minion").size()


func _float_text(text: String, col: Color, offset := Vector2(0, -170)) -> void:
	_ge.show_floating_text.emit(global_position + offset, text, col)


# ---------------------------------------------------------------- vida / fases
func take_damage(amount: float, source: Node = null, _kb: Vector2 = Vector2.ZERO) -> float:
	if state in [State.DEAD, State.INTRO, State.TRANSITION]:
		return 0.0
	if _channeling:
		_on_channel_hit(amount, source)
		HitFx.flash(animated_sprite, 0.05)
		return 0.0
	if invuln:
		HitFx.flash(animated_sprite, 0.06)
		if _shield_msg_cd <= 0.0:
			_shield_msg_cd = 0.9
			_float_text(tr("BOSS_SHIELD"), Color("9fd8ff"))
		return 0.0
	amount = BossDamage.adjust(self, amount, source)  # sin criticos, topes y tipos (boss_damage.gd)
	# Agotado recibe mas dano: aprende a esperar el momento.
	if state == State.TIRED:
		amount *= TIRED_MULT
	current_health -= amount
	_emit_health()
	HitFx.flash(animated_sprite)
	HitFx.shake(0.18)  # golpe al jefe: sacudida corta
	_ge.enemy_damaged.emit(self, amount, source)
	BossDamage.popup(self, amount, state == State.TIRED)
	if current_health <= 0.0:
		die(source)
	elif current_phase == 1 and current_health <= max_health * PHASE2_AT:
		_enter_phase(2)
	elif current_phase == 2 and current_health <= max_health * PHASE3_AT:
		_enter_phase(3)
	elif Censura.has("jefe_furia") and not _furia and current_phase == 3 and current_health <= max_health * 0.15:
		_enter_furia()  # Censura: fase extra de furia al 15%
	return amount


## Censura (regla "furia"): al 15% de vida el jefe se enfurece: mas rapido, pega mas y ataca antes.
var _furia := false
func _enter_furia() -> void:
	_furia = true
	move_speed *= 1.35
	damage *= 1.25
	if state == State.IDLE:
		_timer = minf(_timer, 0.4)
	HitFx.shake(0.4)
	animated_sprite.modulate = Color(2.0, 0.4, 0.4)
	_ge.show_floating_text.emit(global_position + Vector2(0, -160), tr("CENSURA_FURIA"), Color("ff4f9a"))


func _enter_phase(n: int) -> void:
	_cancel_attack()
	current_phase = n
	_chan_pending = _channels_left > 0
	state = State.TRANSITION
	_timer = 1.8
	invuln = false
	HitFx.shake(0.55)
	animated_sprite.modulate = Color(1.8, 0.5, 0.5)
	_say("phase%d" % n)
	_clear_bullets()
	_on_phase(n)


## Rinde las corrutinas de ataque en curso y limpia lo que dejaron en la sala.
func _cancel_attack() -> void:
	_combo_left = 0
	_gen += 1
	_channeling = false
	_ch_hit_cb = Callable()
	_reset_bot_hints()
	_blackout_stop()
	velocity = Vector2.ZERO
	_reset_fx()
	_clear_hazards()


func die(killer: Node = null) -> void:
	if state == State.DEAD:
		return
	_cancel_attack()
	state = State.DEAD
	BossDamage.on_death(self)
	current_health = 0.0
	invuln = false
	_emit_health()
	_clear_bullets()
	_on_death()
	_print_stats("jefe derrotado")
	for m in get_tree().get_nodes_in_group("boss_minion"):
		if is_instance_valid(m) and m.has_method("die"):
			m.die(null)
	HitFx.shake(0.9)
	HitFx.hitstop()
	_say("death")
	_say("after")
	animated_sprite.modulate = Color.WHITE
	animated_sprite.play("death")
	set_collision_layer_value(2, false)
	await get_tree().create_timer(1.4).timeout
	_drop_loot()
	_ge.enemy_killed.emit(self, killer)
	get_node("/root/RunManager").total_enemies_killed += 1
	queue_free()


func _clear_bullets() -> void:
	for p in _spawn_container().get_children():
		if p is ProjectileEnemy:
			p.queue_free()


## Zonas, huevos, hojas y mitades del jefe.
func _clear_hazards() -> void:
	for g in [BossZone.GROUP, "boss_breakable"]:
		for n in get_tree().get_nodes_in_group(g):
			if is_instance_valid(n):
				n.queue_free()


func _emit_health() -> void:
	_ge.boss_health_changed.emit(enemy_name, maxf(current_health, 0.0), max_health)


func _say(suffix: String) -> void:
	var key := "boss%d_%s" % [_canon, suffix]
	if Narrator.has_lines(key):
		Narrator.say(key)


# ---------------------------------------------------------------- utilidades
func _update_animation() -> void:
	if has_node(BossAnimator.NAME):
		return  # los jefes con animador (src/enemies/boss_animator.gd) eligen sus cuadros ahi
	var anim := "walk" if velocity.length() > 10.0 else "idle"
	if animated_sprite.animation != anim:
		animated_sprite.play(anim)
	if absf(velocity.x) > 1.0:
		animated_sprite.flip_h = velocity.x < 0.0


func _on_hurtbox_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		take_damage(float(area.damage) if "damage" in area else 10.0, area.get_parent())


func _drop_loot() -> void:
	for drop in drop_table:
		if RNG.randf() < drop.chance:
			var pickup = ITEM_PICKUP_SCENE.instantiate()
			pickup.item_id = drop.item_id
			# El contenedor es la sala (Node2D desplazado): en su espacio local, no en el global
			# (antes la sala se sumaba dos veces y el botin caia fuera del mapa).
			pickup.position = RoomUtil.snap_drop(_drop_container(), _drop_container().to_local(global_position + Vector2(RNG.randf_range(-50, 50), RNG.randf_range(-30, 30))))
			_drop_container().add_child.call_deferred(pickup)


func find_owning_room() -> Room:
	var node: Node = get_parent()
	while node != null:
		if node is Room:
			return node
		node = node.get_parent()
	return null


func _drop_container() -> Node:
	var room := find_owning_room()
	return room.get_drop_container() if room else get_tree().current_scene


func _spawn_container() -> Node:
	var room := find_owning_room()
	return room.get_spawn_container() if room else get_tree().current_scene
