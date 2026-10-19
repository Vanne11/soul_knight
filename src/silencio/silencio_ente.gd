class_name SilencioEnte
extends AnimatedSprite2D

## UNA silueta suelta de la asamblea del Pacto de Silencio (sin rostro, sin genero, sin humor).
## Arte: assets/sprites/silencio/pacto/ente_sprite_frames.tres (tools/gen_pacto_art.py, hoja "ente").
## El nodo esta en los PIES. Es solo imagen: no choca ni daña. Lo usa SilencioCuerpo (cada una de las 7 siluetas del
## jefe, que reciben el golpe y se lo pasan a la unica vida del Pacto; ver boss_pacto_silencio.gd). SEATS = las 7 sillas
## del escenario fijo (SilencioEscenario), local al centro del escenario.

const FRAMES := "res://assets/sprites/silencio/pacto/ente_sprite_frames.tres"
const POSES := [&"idle", &"turn", &"lean", &"bow", &"away", &"ears"]
const H := 72.0
## Donde estaban sentadas las 7 siluetas del bloque (local al jefe, pies en el origen).
const SEATS := [Vector2(-66, -58), Vector2(-22, -64), Vector2(22, -64), Vector2(66, -58),
		Vector2(-44, -22), Vector2(0, -22), Vector2(44, -22)]

var _tw: Tween = null
var _wander_t := 0.0
var _home := Vector2.ZERO
var wander := false
var wander_r := 34.0


static func make(pos: Vector2) -> SilencioEnte:
	var e := SilencioEnte.new()
	e.sprite_frames = load(FRAMES)
	e.offset = Vector2(0, -H * 0.5)
	e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	e.position = pos
	e._home = pos
	e._wander_t = randf_range(0.4, 1.6)
	e.play(&"idle")
	return e


func set_home(p: Vector2) -> void:
	_home = p


## Camina (animacion "walk", mirando hacia donde va) hasta `to` en `secs` y se queda en una pose.
func go_to(to: Vector2, secs: float, end_pose := &"idle") -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var dx := to.x - position.x
	if absf(dx) > 2.0:
		flip_h = dx < 0.0
	play(&"walk")
	_tw = create_tween()
	_tw.tween_property(self, "position", to, maxf(0.05, secs)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_callback(func(): play(end_pose))


## Con luz en la mano (la unica nota calida del reino): solo al final del jefe.
func carry_light() -> void:
	play(&"light")


func stop_moving() -> void:
	wander = false
	if _tw != null and _tw.is_valid():
		_tw.kill()


func _process(delta: float) -> void:
	if not wander:
		return
	_wander_t -= delta
	if _wander_t > 0.0:
		return
	_wander_t = randf_range(1.2, 2.6)
	if randf() < 0.55:
		var to := _home + Vector2(randf_range(-wander_r, wander_r), randf_range(-wander_r * 0.5, wander_r * 0.5))
		go_to(to, to.distance_to(position) / 38.0, POSES[randi() % POSES.size()])
	else:
		play(POSES[randi() % POSES.size()])
