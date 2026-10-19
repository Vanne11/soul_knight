class_name HitFx
extends Node

## Sensacion de golpe (roadmap 54-56): sacudida de camara, pausa breve al impactar y
## destello blanco del sprite. Solo presentacion: no toca danos, vidas ni tiempos de juego.
## main.gd lo agrega como hijo; los demas lo llaman con HitFx.shake(), HitFx.hitstop(), HitFx.flash().

const FLASH_SHADER := preload("res://src/shaders/hit_flash.gdshader")
const MAX_OFFSET := 7.0       # px de pantalla con trauma 1
const TRAUMA_DECAY := 2.2     # trauma por segundo real
const HITSTOP_SECS := 0.045   # ~3 frames a 60 fps
const HITSTOP_SCALE := 0.04
const HITSTOP_COOLDOWN := 0.28
const HITSTOP_BOSS_HIT := 0.04    # pegarle al jefe: muy corta (el enfriamiento la acota para las rafagas)
const HITSTOP_BOSS_HURT := 0.08   # el jefe te pega fuerte: un poco mas larga
const HITSTOP_PHASE := 0.1        # cambio de fase del jefe
const HITSTOP_HEAVY_MIN := 0.07   # desde aqui la pausa pisa el enfriamiento (es un golpe grande)

static var inst: HitFx = null

var camera: Camera2D
var _trauma := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0
var _last_us := 0
var _stop_until_us := 0
var _next_stop_us := 0
var _stopping := false  # solo restauramos time_scale si el hitstop lo puso (utero_fx tambien lo toca)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	inst = self
	_noise.seed = 7
	_noise.frequency = 1.0
	_last_us = Time.get_ticks_usec()


func _exit_tree() -> void:
	if inst == self:
		inst = null
	Engine.time_scale = 1.0


## Trauma 0-1 (acumulativo). Golpe al jugador ~0.3, jefe ~0.2, muerte de jefe ~0.8.
static func shake(amount: float) -> void:
	if inst and Settings.screen_shake:
		inst._trauma = minf(1.0, inst._trauma + amount)


## Pausa de ~3 frames (o `secs`). Usa Engine.time_scale y se restaura con reloj real; no se acumula.
## Respeta la opcion de reducir sacudida y no actua con el juego en pausa (menu, mapa, narrador).
static func hitstop(secs := HITSTOP_SECS) -> void:
	if inst == null or not Settings.screen_shake or not inst.is_inside_tree() or inst.get_tree().paused:
		return
	secs = minf(secs, 0.12)
	var now := Time.get_ticks_usec()
	if now < inst._next_stop_us and secs < HITSTOP_HEAVY_MIN:
		return
	inst._next_stop_us = now + int((secs + HITSTOP_COOLDOWN) * 1e6)
	inst._stop_until_us = maxi(inst._stop_until_us, now + int(secs * 1e6))
	inst._stopping = true
	Engine.time_scale = HITSTOP_SCALE


## Destello blanco breve en un sprite (jugador o enemigo). Crea su material la primera vez.
static func flash(spr: CanvasItem, secs := 0.12) -> void:
	if spr == null or not is_instance_valid(spr):
		return
	var mat := spr.material as ShaderMaterial
	if mat == null or mat.shader != FLASH_SHADER:
		if spr.material != null:
			return  # ya tiene otro material (censura): no se pisa
		mat = ShaderMaterial.new()
		mat.shader = FLASH_SHADER
		spr.material = mat
	var old: Tween = spr.get_meta("hit_flash_tween") if spr.has_meta("hit_flash_tween") else null
	if old and old.is_valid():
		old.kill()
	mat.set_shader_parameter("flash", 0.9)
	var tw := spr.create_tween().set_ignore_time_scale(true)
	tw.tween_interval(secs * 0.4)
	tw.tween_method(func(v: float): mat.set_shader_parameter("flash", v), 0.9, 0.0, secs * 0.6)
	spr.set_meta("hit_flash_tween", tw)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last_us) / 1e6, 0.1)  # tiempo real, no afectado por time_scale
	_last_us = now
	if _stopping and now >= _stop_until_us:
		_stopping = false
		Engine.time_scale = 1.0
	if camera == null or not is_instance_valid(camera):
		return
	if _trauma <= 0.0:
		camera.offset = Vector2.ZERO
		return
	_trauma = maxf(0.0, _trauma - TRAUMA_DECAY * dt)
	_t += dt * 38.0
	var k := _trauma * _trauma * MAX_OFFSET
	camera.offset = Vector2(_noise.get_noise_2d(_t, 0.0), _noise.get_noise_2d(0.0, _t + 100.0)) * k
