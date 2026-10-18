class_name AmbientAudio
extends Node

## Ambiente sonoro del piso (roadmap 60-62). Main lo añade con una linea en _ready:
##   add_child(AmbientAudio.new())
## Todo sale por el bus "SFX": asi respeta el volumen de efectos de Ajustes (a 0 se
## silencia, F2 lo calla todo) y no hace falta tocar Settings ni el menu. La musica
## sigue en su bus aparte; el ambiente va muy por debajo (cama -22 dB o menos).
##   - Cama: bucle largo por reino (selva, marmol, organico, aduana, palacio).
##   - Eventos: gota / eco de marmol / murmullo / sello lejano / papeles, a intervalos
##     al azar; mas presentes en sala oscura y tranquila, mas raros en combate.
##   - Antorchas: AudioStreamPlayer2D con atenuacion, solo las N mas cercanas.
##   - Pasos: segun el suelo del reino; chapoteo en charcos; nada durante el dash
##     (el propio dash ya suena con Sound.play("dash")).
## Sin el RNG autoload: usa su propio RandomNumberGenerator (el sonido no afecta al juego).
## Los .wav salen de tools/gen_ambient_audio.py.

const DIR := "res://assets/audio/ambient/"
const BUS := "SFX"

## Cama: volumen base por reino (dB sobre el bus SFX).
const BED_DB := {"neutral": -25.0, "pene": -27.0, "vulva": -24.0, "mixto": -33.0, "censura": -24.0, "prostata": -30.0}
const BED_DARK_BONUS := 2.0
const BED_CALM_BONUS := 2.0
const BED_COMBAT_DB := -8.0  # en combate sin despejar la cama baja casi del todo
const BED_FADE_DB_S := 14.0  # velocidad de los cambios de volumen (dB/s)
const SILENT_DB := -60.0

## Eventos puntuales por reino: [prefijo del sonido, peso].
const EVENTS := {
	"neutral": [["amb_drip", 1.0]],
	"pene": [["amb_marble", 1.0]],
	"vulva": [["amb_organic", 1.0]],
	"mixto": [["amb_stamp", 0.65], ["amb_paper", 0.35]],
	"censura": [["amb_paper", 0.7], ["amb_stamp", 0.3]],
	"prostata": [["amb_drip", 0.55], ["amb_paper", 0.45]],
}
const EVENT_DB := -20.0
const EVENT_GAP := Vector2(5.0, 11.0)  # segundos entre eventos (sala tranquila)
const EVENT_POOL := 3

## Antorchas.
const TORCH_N := 3  # a lo sumo estas a la vez (las mas cercanas)
const TORCH_DB := -17.0
const TORCH_MAX_DIST := 360.0
const TORCH_ATTEN := 1.8

## Pasos: suelo por reino y volumen por suelo.
const STEP_KIND := {"neutral": "dirt", "pene": "marble", "vulva": "organic", "mixto": "cobble", "censura": "tile", "prostata": "tile"}
const STEP_DB := {"dirt": -17.0, "marble": -19.0, "organic": -17.0, "cobble": -17.0, "tile": -18.0}
const STRIDE := 78.0  # px por paso: la cadencia sale sola de la velocidad real
const MIN_SPEED := 25.0  # px/s por debajo no hay pasos (contra una pared, quieto)
const SPLASH_DB := -14.0
const STEP_POOL := 3
const TICK := 0.2  # cada cuanto se reevalua sala, cama y antorchas

var _rng := RandomNumberGenerator.new()
var _sounds: Dictionary = {}  # nombre -> AudioStream
var _variants: Dictionary = {}  # prefijo -> Array[String]
var _last_variant: Dictionary = {}

var _main: Node = null
var _room: Room = null
var _kingdom := ""
var _dead := false

var _bed: AudioStreamPlayer
var _bed_name := ""  # lo que suena
var _bed_target_db := SILENT_DB
var _bed_want := ""  # lo que toca sonar

var _events: Array[AudioStreamPlayer] = []
var _event_next := 0
var _event_in := 6.0

var _torches: Array[AudioStreamPlayer2D] = []
var _torch_of: Array = []  # antorcha (Node2D) asignada a cada reproductor
var _tick_in := 0.0

var _steps: Array[AudioStreamPlayer] = []
var _step_next := 0
var _last_pos := Vector2.ZERO
var _have_pos := false
var _stride_acc := 0.0
var _was_dashing := false
var _puddles: Dictionary = {}  # Room -> Array[Dictionary] {c: Vector2, r: Vector2}


func _ready() -> void:
	name = "AmbientAudio"
	process_mode = Node.PROCESS_MODE_ALWAYS  # para parar y reanudar con la pausa
	_rng.randomize()
	for file in ResourceLoader.list_directory(DIR):
		if file.ends_with(".wav"):
			var key := file.get_basename()
			_sounds[key] = load(DIR + file)
			var prefix := key.substr(0, key.rfind("_")) if key.ends_with("_0") or key.ends_with("_1") or key.ends_with("_2") else key
			if not _variants.has(prefix):
				_variants[prefix] = []
			_variants[prefix].append(key)
	for key in ["torch_loop", "bed_neutral", "bed_pene", "bed_vulva", "bed_mixto", "bed_censura", "bed_prostata"]:
		_make_loop(key)

	_bed = AudioStreamPlayer.new()
	_bed.bus = BUS
	_bed.volume_db = SILENT_DB
	add_child(_bed)
	for i in EVENT_POOL:
		_events.append(_new_player())
	for i in STEP_POOL:
		_steps.append(_new_player())
	for i in TORCH_N:
		var p := AudioStreamPlayer2D.new()
		p.bus = BUS
		p.stream = _sounds.get("torch_loop")
		p.volume_db = TORCH_DB
		p.max_distance = TORCH_MAX_DIST
		p.attenuation = TORCH_ATTEN
		add_child(p)
		_torches.append(p)
		_torch_of.append(null)
	get_node("/root/GlobalEvents").player_died.connect(func(): _dead = true)


func _new_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = BUS
	add_child(p)
	return p


func _make_loop(key: String) -> void:
	var s := _sounds.get(key) as AudioStreamWAV
	if s == null:
		return
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)


## Un sonido al azar de la familia (sin repetir el ultimo).
func _pick(prefix: String) -> String:
	var list: Array = _variants.get(prefix, [])
	if list.is_empty():
		return ""
	if list.size() == 1:
		return list[0]
	var pick: String = list[_rng.randi() % list.size()]
	if pick == _last_variant.get(prefix, ""):
		pick = list[(list.find(pick) + 1) % list.size()]
	_last_variant[prefix] = pick
	return pick


func _process(delta: float) -> void:
	var paused := get_tree().paused
	for p in _all_players():
		p.stream_paused = paused
	if paused:
		return
	if _main == null:
		_main = get_tree().get_first_node_in_group("main")
		if _main == null:
			return
	if _main.current_room != _room:
		_set_room(_main.current_room)
	if _room == null:
		return
	_tick_in -= delta
	if _tick_in <= 0.0:
		_tick_in = TICK
		_update_bed_target()
		_update_torches()
	_update_bed(delta)
	_update_events(delta)
	_update_steps(delta)


func _all_players() -> Array:
	var all: Array = [_bed]
	all.append_array(_events)
	all.append_array(_steps)
	all.append_array(_torches)
	return all


# ------------------------------------------------------------------ sala / reino
func _set_room(room: Room) -> void:
	_room = room
	_have_pos = false  # el salto de una sala a otra no cuenta como andar
	_stride_acc = 0.0
	_kingdom = String(get_node("/root/RunManager").floor_data().get("kingdom", ""))
	_event_in = _rng.randf_range(2.0, 5.0)  # al entrar, pronto un detalle de ambiente
	_tick_in = 0.0
	for i in _torches.size():  # las antorchas de la sala anterior ya no suenan
		_torches[i].stop()
		_torch_of[i] = null


## Sala sin combate pendiente (despejada o de las que no tienen enemigos).
func _is_calm() -> bool:
	if _room == null:
		return true
	if _room.cleared:
		return true
	return _room.room_type != Room.RoomType.COMBAT and _room.room_type != Room.RoomType.TRAP \
		and _room.room_type != Room.RoomType.BOSS and _room.room_type != Room.RoomType.MINIBOSS \
		and _room.room_type != Room.RoomType.INTOXICATION


# ------------------------------------------------------------------ cama
func _update_bed_target() -> void:
	_bed_want = "bed_" + _kingdom if _sounds.has("bed_" + _kingdom) else ""
	if _dead or _bed_want == "":
		_bed_target_db = SILENT_DB
		return
	var db: float = BED_DB.get(_kingdom, -26.0)
	if _room.is_dark:
		db += BED_DARK_BONUS
	if _is_calm():
		db += BED_CALM_BONUS
	else:
		db += BED_COMBAT_DB
	_bed_target_db = db


func _update_bed(delta: float) -> void:
	var step := BED_FADE_DB_S * delta
	if _bed_name != _bed_want:
		# toca cambiar de cama (otro piso): baja, cambia y sube
		_bed.volume_db = move_toward(_bed.volume_db, SILENT_DB, step * 2.0)
		if _bed.volume_db <= SILENT_DB + 1.0:
			_bed_name = _bed_want
			if _bed_name == "":
				_bed.stop()
			else:
				_bed.stream = _sounds[_bed_name]
				_bed.play(_rng.randf() * _bed.stream.get_length())
		return
	if _bed_name == "":
		return
	_bed.volume_db = move_toward(_bed.volume_db, _bed_target_db, step)
	if not _bed.playing:
		_bed.play(_rng.randf() * _bed.stream.get_length())


# ------------------------------------------------------------------ eventos
func _update_events(delta: float) -> void:
	if _dead or not EVENTS.has(_kingdom):
		return
	_event_in -= delta
	if _event_in > 0.0:
		return
	var calm := _is_calm()
	var gap := _rng.randf_range(EVENT_GAP.x, EVENT_GAP.y)
	if _room.is_dark:
		gap *= 0.7
	if not calm:
		gap *= 2.5
	_event_in = gap
	var prefix := _weighted(EVENTS[_kingdom])
	var key := _pick(prefix)
	if key == "":
		return
	var p := _events[_event_next]
	_event_next = (_event_next + 1) % _events.size()
	p.stream = _sounds[key]
	var db := EVENT_DB + _rng.randf_range(-4.0, 0.0)
	if _room.is_dark:
		db += 2.0
	if not calm:
		db -= 6.0
	p.volume_db = db
	p.pitch_scale = _rng.randf_range(0.9, 1.1)
	p.play()


func _weighted(list: Array) -> String:
	var tot := 0.0
	for e in list:
		tot += e[1]
	var x := _rng.randf() * tot
	for e in list:
		x -= e[1]
		if x <= 0.0:
			return e[0]
	return list[0][0]


# ------------------------------------------------------------------ antorchas
## Asigna los reproductores a las TORCH_N antorchas mas cercanas al jugador. Las que
## ya sonaban conservan su reproductor (sin saltos); las nuevas arrancan en un punto
## cualquiera del bucle para que no suenen todas sincronizadas.
func _update_torches() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var flames: Array = []
	var lighting := _main.get_node_or_null("RoomLighting")
	if player != null and lighting != null and _room.is_dark and "_decor" in lighting:
		var d: Dictionary = lighting._decor.get(_room, {})
		var node = d.get("node")
		if d.has("torches") and is_instance_valid(node) and node.visible:
			for t in d.torches:
				var f = t.get("flame")
				if is_instance_valid(f):
					flames.append(f)
	if player == null or flames.is_empty():
		for i in _torches.size():
			_torches[i].stop()
			_torch_of[i] = null
		return
	var origin := player.global_position
	flames.sort_custom(func(a, b): return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	var chosen: Array = flames.slice(0, TORCH_N)
	# libera los reproductores cuya antorcha ya no esta entre las elegidas
	for i in _torches.size():
		if _torch_of[i] != null and not chosen.has(_torch_of[i]):
			_torches[i].stop()
			_torch_of[i] = null
	for f in chosen:
		if _torch_of.has(f):
			continue
		var i := _torch_of.find(null)
		if i == -1:
			break
		_torch_of[i] = f
		var p := _torches[i]
		p.global_position = f.global_position
		p.play(_rng.randf() * p.stream.get_length())
	# las que siguen elegidas se quedan en su sitio (la antorcha no se mueve)


# ------------------------------------------------------------------ pasos
func _update_steps(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or _dead or delta <= 0.0:
		return
	var pos := player.global_position
	var dashing: bool = player.get("is_dashing") == true
	if dashing:
		# nada durante el dash; al terminar se empieza de cero
		_stride_acc = 0.0
		_was_dashing = true
		_last_pos = pos
		_have_pos = true
		return
	if _was_dashing:
		_was_dashing = false
		_last_pos = pos
		_have_pos = true
		return
	if not _have_pos:
		_last_pos = pos
		_have_pos = true
		return
	var moved := pos.distance_to(_last_pos)
	_last_pos = pos
	if moved > 80.0:  # teletransporte (puerta, sala nueva): no es andar
		_stride_acc = 0.0
		return
	if moved / delta < MIN_SPEED:
		_stride_acc = minf(_stride_acc, STRIDE * 0.5)  # al parar, el siguiente paso llega pronto
		return
	if _stride_acc == 0.0:
		_stride_acc = STRIDE * 0.55  # al arrancar, primer paso casi enseguida
	_stride_acc += moved
	if _stride_acc >= STRIDE:
		_stride_acc -= STRIDE
		_play_step(pos)


func _play_step(pos: Vector2) -> void:
	var kind: String = STEP_KIND.get(_kingdom, "dirt")
	var in_puddle := _in_puddle(pos)
	var key := _pick("splash" if in_puddle else "step_" + kind)
	if key == "":
		return
	var p := _steps[_step_next]
	_step_next = (_step_next + 1) % _steps.size()
	p.stream = _sounds[key]
	p.volume_db = (SPLASH_DB if in_puddle else STEP_DB.get(kind, -18.0)) + _rng.randf_range(-1.5, 0.5)
	p.pitch_scale = _rng.randf_range(0.92, 1.08)
	p.play()


## Charcos de la sala (sprites "puddle_<tipo>_<tam>" del nodo Decals), elipses en mundo.
func _in_puddle(pos: Vector2) -> bool:
	if not _puddles.has(_room):
		var decals := _room.get_node_or_null("Decals")
		if decals == null:
			return false
		var list: Array = []
		for c in decals.get_children():
			var s := c as Sprite2D
			if s == null or s.texture == null:
				continue
			var f := s.texture.resource_path.get_file().get_basename()
			if f.begins_with("puddle_") and f.count("_") == 2:  # sin las variantes de brillo (_a/_b)
				var sz := s.texture.get_size() * 0.38
				list.append({"c": s.global_position, "r": sz})
		_puddles[_room] = list
	for q in _puddles[_room]:
		var d: Vector2 = (pos - q.c) / q.r
		if d.length_squared() <= 1.0:
			return true
	return false


## Al cerrar, soltar los streams: si no, Godot avisa de que siguen en uso.
func _exit_tree() -> void:
	for p in _all_players():
		p.stop()
		p.stream = null
