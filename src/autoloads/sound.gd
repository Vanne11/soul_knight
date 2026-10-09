extends Node

## Efectos y musica. Los .wav salen de tools/gen_audio.py.
##   Sound.play("shoot")      efecto (ver assets/audio/sfx)
##   Sound.music("boss")      cambia de tema ("" para callar)
## Lo que ya tiene señal en GlobalEvents suena desde aqui; el resto lo llama
## cada script en su sitio.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const VOICES := 12
## El mismo efecto dos veces en menos de esto suena a uno (perdigones, rafagas).
const MIN_GAP_MS := 40
const SFX_DB := -6.0
const MUSIC_DB := -14.0

var _sfx: Dictionary = {}
var _last_ms: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # la musica sigue en pausa
	for file in ResourceLoader.list_directory(SFX_DIR):
		if file.ends_with(".wav"):
			_sfx[file.get_basename()] = load(SFX_DIR + file)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_DB
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)

	var ge := get_node("/root/GlobalEvents")
	ge.enemy_damaged.connect(func(_e, _a, _s): play("enemy_hit"))
	ge.enemy_killed.connect(func(e, _k): play("boss_die" if e.is_in_group("boss") else "enemy_die"))
	ge.player_died.connect(func():
		music("")
		play("player_die"))
	ge.item_picked_up.connect(func(item, _q): play("coin" if "moneda" in item.tags else "pickup"))


func play(sfx_name: String, pitch_jitter := 0.06) -> void:
	if not _sfx.has(sfx_name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_ms.get(sfx_name, -1000)) < MIN_GAP_MS:
		return
	_last_ms[sfx_name] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _sfx[sfx_name]
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


func music(track: String) -> void:
	if track == _music_name:
		return
	_music_name = track
	if track == "" or not ResourceLoader.exists(MUSIC_DIR + track + ".wav"):
		_music.stop()
		return
	var s: AudioStreamWAV = load(MUSIC_DIR + track + ".wav")
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_end = int(s.get_length() * s.mix_rate)
	_music.stream = s
	_music.play()


## F2 silencia todo (aun no hay menu de opciones).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
