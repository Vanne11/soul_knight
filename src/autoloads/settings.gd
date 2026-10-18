extends Node

## Ajustes del jugador, guardados en user://settings.cfg y aplicados al arrancar.
## Audio: buses "Music" y "SFX" (los crea este autoload; Sound les asigna sus
## players). 100 = volumen por defecto de siempre (las constantes de sound.gd).

signal changed
## Se emite al cambiar la calidad grafica (fija o por el modo automatico).
signal quality_changed

const PATH := "user://settings.cfg"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
## [codigo, nombre en su propio idioma]
const LOCALES := [["es", "Español"], ["en", "English"]]

var music_volume := 100  # 0-100
var sfx_volume := 100
var fullscreen := false
var locale := "es"
## Efectos de pantalla (mareo, ondulacion, pulso): 0 completo, 1 reducido, 2 desactivado.
var screen_fx := 0
## Sacudida de camara y pausa breve al impactar.
var screen_shake := true
## --- Bloque movil/tactil (F4) ---
## Controles tactiles: 0 auto (pantalla tactil o primer toque), 1 siempre, 2 nunca.
var touch_mode := 0
## Tamano de la interfaz: 0 normal, 1 grande (por defecto en Android).
var ui_size := 1 if OS.has_feature("android") else 0

# ---------------------------------------------------------------- calidad grafica
## Nivel efectivo: 0 alta, 1 media, 2 baja. `quality_mode` es lo que elige el jugador;
## AUTO arranca como el defecto de la plataforma y baja un nivel si el FPS medio de
## los primeros segundos de partida cae de AUTO_MIN_FPS (nunca sube solo).
enum Quality { HIGH, MEDIUM, LOW, AUTO }
const AUTO_MIN_FPS := 45.0
const AUTO_WINDOW_S := 5.0
## Por nivel [alta, media, baja]:
const Q_MAX_LIGHTS := [999, 8, 4]             # luces dinamicas encendidas a la vez (las mas cercanas al jugador)
const Q_SHADOW_LIGHTS := [999, 3, 0]          # cuantas de ellas proyectan sombra (PointLight2D.shadow_enabled)
const Q_CAST_SHADOWS := [true, true, false]   # sombras alargadas de actores (raycasts por luz)
const Q_PARTICLES := [1.0, 0.5, 0.25]         # factor de cantidad de particulas (WorldFx y CPUParticles2D)
const Q_AMBIENT_FX := [1.0, 0.5, 0.0]         # particulas ambientales del reino (WorldFx)
const Q_FOOTPRINTS := [true, true, false]     # huellas y manchas en el suelo
const Q_DUST_RAYS := [1.0, 0.6, 0.0]          # polvo y rayos de luz de pantalla (ScreenFx); 0 = sin shader
const Q_INTOX_SHADER := [true, true, false]   # mareo con shader de pantalla; si no, solo un velo de color
var quality_mode := Quality.HIGH
var quality := 0
var _auto_t := 0.0
var _auto_frames := 0
var _auto_done := true


func _init() -> void:
	# antes de que Sound (autoload posterior) asigne sus players a los buses
	_ensure_bus(BUS_MUSIC)
	_ensure_bus(BUS_SFX)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	quality_mode = default_quality()
	load_settings()
	apply()
	_start_quality()


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_volume = clampi(int(cfg.get_value("audio", "music", 100)), 0, 100)
	sfx_volume = clampi(int(cfg.get_value("audio", "sfx", 100)), 0, 100)
	fullscreen = bool(cfg.get_value("video", "fullscreen", false))
	screen_fx = clampi(int(cfg.get_value("video", "screen_fx", 0)), 0, 2)
	screen_shake = bool(cfg.get_value("video", "screen_shake", true))
	touch_mode = clampi(int(cfg.get_value("touch", "mode", 0)), 0, 2)
	ui_size = clampi(int(cfg.get_value("touch", "ui_size", ui_size)), 0, 1)
	quality_mode = clampi(int(cfg.get_value("video", "quality", default_quality())), 0, Quality.AUTO) as Quality
	var l := str(cfg.get_value("game", "locale", "es"))
	locale = l if LOCALES.any(func(x): return x[0] == l) else "es"


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("video", "screen_fx", screen_fx)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.set_value("touch", "mode", touch_mode)
	cfg.set_value("touch", "ui_size", ui_size)
	cfg.set_value("video", "quality", quality_mode)
	cfg.set_value("game", "locale", locale)
	cfg.save(PATH)


func apply() -> void:
	_apply_bus(BUS_MUSIC, music_volume)
	_apply_bus(BUS_SFX, sfx_volume)
	_apply_fullscreen()
	apply_ui_size()
	TranslationServer.set_locale(locale)


func set_music_volume(v: int) -> void:
	music_volume = clampi(v, 0, 100)
	_apply_bus(BUS_MUSIC, music_volume)
	save_settings()


func set_sfx_volume(v: int) -> void:
	sfx_volume = clampi(v, 0, 100)
	_apply_bus(BUS_SFX, sfx_volume)
	save_settings()


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_fullscreen()
	save_settings()


func set_screen_fx(mode: int) -> void:
	screen_fx = clampi(mode, 0, 2)  # ScreenFx lo lee cada frame
	save_settings()


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	save_settings()


# ---------------------------------------------------------- movil / tactil
## Factor de contenido de la ventana por cada tamano de UI (>1 = todo mas grande).
const UI_SCALES := [1.0, 1.2]


func set_touch_mode(mode: int) -> void:
	touch_mode = clampi(mode, 0, 2)
	save_settings()


func set_ui_size(size: int) -> void:
	ui_size = clampi(size, 0, 1)
	apply_ui_size()
	save_settings()


func apply_ui_size() -> void:
	get_tree().root.content_scale_factor = UI_SCALES[ui_size]

## Alta en escritorio, baja en web y movil.
static func default_quality() -> int:
	return Quality.LOW if OS.has_feature("web") or OS.has_feature("android") or OS.has_feature("ios") else Quality.HIGH


func set_quality_mode(mode: int) -> void:
	quality_mode = clampi(mode, 0, Quality.AUTO) as Quality
	_start_quality()
	save_settings()


## Fija `quality` segun el modo. En AUTO empieza en el defecto de la plataforma y mide.
func _start_quality() -> void:
	_auto_done = quality_mode != Quality.AUTO
	_auto_t = 0.0
	_auto_frames = 0
	_set_quality(default_quality() if quality_mode == Quality.AUTO else quality_mode)


func _set_quality(q: int) -> void:
	q = clampi(q, 0, 2)
	if q == quality:
		return
	quality = q
	quality_changed.emit()


## Cantidad de particulas para el nivel actual (nunca menos de 1).
func fx_amount(n: int) -> int:
	return maxi(1, int(round(n * Q_PARTICLES[quality])))


func _process(delta: float) -> void:
	if _auto_done or get_tree().paused or get_tree().get_first_node_in_group("main") == null:
		return
	if delta > 0.2:
		return  # tirones de carga (cambio de piso, sala nueva) no cuentan
	_auto_t += delta
	_auto_frames += 1
	if _auto_t < AUTO_WINDOW_S:
		return
	var fps := _auto_frames / _auto_t
	_auto_t = 0.0
	_auto_frames = 0
	if fps < AUTO_MIN_FPS and quality < 2:
		_set_quality(quality + 1)  # y vuelve a medir con el nivel nuevo
	else:
		_auto_done = true


func set_locale(code: String) -> void:
	locale = code
	TranslationServer.set_locale(code)
	save_settings()
	changed.emit()


func _apply_bus(bus_name: String, volume: int) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, volume <= 0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volume / 100.0, 0.0001)))


func _apply_fullscreen() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
