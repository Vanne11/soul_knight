extends Node

## Efectos y musica. Los efectos (.wav) salen de tools/gen_audio.py; la musica va en .ogg (tools/gen_music_lyria.py: chiptune de Lyria 3.5).
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
## Fundido al cambiar de pista.
const MUSIC_FADE := 0.4
const FADE_DB := -50.0

var _sfx: Dictionary = {}
var _last_ms: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
## Dos reproductores de musica para el fundido cruzado; _cur es el que suena ahora.
var _music: Array[AudioStreamPlayer] = []
var _cur := 0
var _music_name := ""
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # la musica sigue en pausa
	for file in ResourceLoader.list_directory(SFX_DIR):
		if file.ends_with(".wav"):
			var w := load(SFX_DIR + file) as AudioStreamWAV
			if w != null:
				w.loop_mode = AudioStreamWAV.LOOP_DISABLED  # un efecto es de un solo disparo, nunca en bucle
			_sfx[file.get_basename()] = w
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_DB
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.volume_db = MUSIC_DB
		m.bus = "Music"
		add_child(m)
		_music.append(m)

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
	p.volume_db = SFX_DB  # la voz puede haberlo bajado en este reproductor
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.stream_paused = false
	p.play()


## "Voz" de texto que se escribe: una silaba por letra, el tono sale de la
## propia letra (misma frase = misma melodia) + pitch base del que habla.
## vol_offset_db: ajuste sobre el volumen de los efectos (negativo = mas bajo).
func voice(ch: String, base_pitch := 1.0, vol_offset_db := 0.0) -> void:
	if not _sfx.has("voice") or ch.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _sfx["voice"]
	p.volume_db = SFX_DB + vol_offset_db
	p.pitch_scale = base_pitch * (0.85 + float(ch.to_lower().unicode_at(0) % 7) * 0.05) + randf_range(-0.03, 0.03)
	p.play()


## Cambia de tema con un fundido cruzado (la pista vieja baja mientras la nueva sube).
## Si ya suena esa pista no hace nada (no reinicia). El volumen del jugador
## lo ajusta el bus "Music"; aqui solo se mueve volume_db de los players.
## loop=false para jingles de una sola vez (ej. "studio_jingle", "victoria").
## fade: segundos del cruce (0.6 al cambiar de fase de jefe).
func music(track: String, loop := true, fade := MUSIC_FADE) -> void:
	if track == _music_name:
		return
	_music_name = track
	print("[musica] %s" % track)
	if _fade:
		_fade.kill()
	var old := _music[_cur]
	var nuevo := _music[1 - _cur]
	nuevo.stop()  # un cruce anterior sin terminar: se corta
	var started := false
	if track != "" and ResourceLoader.exists(MUSIC_DIR + track + ".ogg"):
		var s: AudioStreamOggVorbis = load(MUSIC_DIR + track + ".ogg")
		s.loop = loop
		nuevo.stream = s
		nuevo.volume_db = FADE_DB if old.playing else MUSIC_DB
		nuevo.play()
		started = true
	if started:
		_cur = 1 - _cur
	if not old.playing:
		return
	_fade = create_tween()  # el nodo es ALWAYS: el fundido sigue en pausa
	_fade.set_parallel(true)
	_fade.tween_property(old, "volume_db", FADE_DB, fade)
	if started:
		_fade.tween_property(nuevo, "volume_db", MUSIC_DB, fade)
	_fade.chain().tween_callback(old.stop)


## F2 silencia todo (los volumenes finos estan en Ajustes).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		var muted := not AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0, muted)
		# antes no avisaba: apretarlo sin querer (esta junto a F1) dejaba el juego mudo sin explicacion
		var n := get_node_or_null("/root/Narrator")
		if n and n.has_method("toast"):
			n.toast(tr("SOUND_MUTED_F2") if muted else tr("SOUND_UNMUTED_F2"))


## Al cerrar, soltar la pista: si no, Godot avisa de que el stream sigue en uso.
func _exit_tree() -> void:
	if _fade:
		_fade.kill()
	for p in _players:
		p.stop()
		p.stream = null
	for m in _music:
		m.stop()
		m.stream = null
