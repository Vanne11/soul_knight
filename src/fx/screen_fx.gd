class_name ScreenFx
extends CanvasLayer

## Efectos de pantalla (roadmap_nico 10-12): vineta con pulso de vida baja, polvo y
## rayos de luz segun la sala, y mareo por intoxicacion. Main la instancia con
## `add_child(ScreenFx.new())`. Va POR ENCIMA del mundo y POR DEBAJO del HUD (ambos en
## layer 1; se mueve al principio del arbol de Main para dibujarse antes que el HUD,
## asi el HUD tampoco se ve afectado por el mareo). Escribe LightKit.intox_wobble.

const LOW_HEALTH_PCT := 0.4
const VIGNETTE_CLEAR := 0.45
const VIGNETTE_DARK := 0.75

var _vignette_mat := ShaderMaterial.new()
var _ambient_mat := ShaderMaterial.new()
var _intox_mat := ShaderMaterial.new()
var _intox_rect: ColorRect

var _stats: PlayerStats
var _low_health := 0.0
var _intox_pct := 0.0
var _dark := 0.0  # LightKit.dark suavizado
var _room: Node = null
var _rays_target := 0.0
var _dust_target := 0.4
var _rays := 0.0
var _dust := 0.4


func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parent := get_parent()
	if parent:
		parent.move_child.call_deferred(self, 0)  # antes que el HUD (mismo layer)

	_ambient_mat.shader = load("res://src/shaders/ambient.gdshader")
	_add_rect(_ambient_mat)
	_vignette_mat.shader = load("res://src/shaders/vignette.gdshader")
	_add_rect(_vignette_mat)
	_intox_mat.shader = load("res://src/shaders/intox.gdshader")
	_intox_rect = _add_rect(_intox_mat)
	_intox_rect.visible = false

	_stats = get_node("/root/PlayerStats")
	_stats.health_changed.connect(_on_health)
	_stats.intoxication_changed.connect(_on_intox)
	_on_health(_stats.current_health, _stats.max_health)
	_on_intox(_stats.intoxication_level, _stats.intoxication_tier)
	_dark = 1.0 if LightKit.dark else 0.0


func _exit_tree() -> void:
	LightKit.intox_wobble = 0.0


func _add_rect(mat: ShaderMaterial) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.material = mat
	add_child(r)
	return r


func _on_health(current: float, maxv: float) -> void:
	var pct := current / maxf(maxv, 1.0)
	_low_health = clampf(1.0 - pct / LOW_HEALTH_PCT, 0.0, 1.0)


func _on_intox(level: float, _tier: int) -> void:
	_intox_pct = clampf(level / maxf(_stats.max_intoxication, 1.0), 0.0, 1.0)


func _process(delta: float) -> void:
	_dark = move_toward(_dark, 1.0 if LightKit.dark else 0.0, delta * 2.5)

	# sala nueva -> reelige polvo y rayos (determinista)
	var main := get_tree().get_first_node_in_group("main")
	if main and main.get("current_room") != _room:
		_room = main.get("current_room")
		if _room:
			_pick_room_fx.call_deferred()
	_rays = move_toward(_rays, _rays_target, delta * 0.6)
	_dust = move_toward(_dust, _dust_target, delta * 0.6)

	_vignette_mat.set_shader_parameter("strength", lerpf(VIGNETTE_CLEAR, VIGNETTE_DARK, _dark))
	_vignette_mat.set_shader_parameter("low_health", _low_health)
	# Settings.screen_fx: 0 completo, 1 reducido, 2 desactivado
	_vignette_mat.set_shader_parameter("pulse_amount", [1.0, 0.25, 0.0][Settings.screen_fx])

	_ambient_mat.set_shader_parameter("dust", _dust)
	_ambient_mat.set_shader_parameter("rays", _rays)
	_ambient_mat.set_shader_parameter("dark", _dark)
	_ambient_mat.set_shader_parameter("light_uv", _player_uv())

	var amount: float = _intox_pct * [1.0, 0.4, 0.0][Settings.screen_fx]
	LightKit.intox_wobble = amount
	_intox_rect.visible = amount > 0.01
	if _intox_rect.visible:
		_intox_mat.set_shader_parameter("amount", amount)
		_intox_mat.set_shader_parameter("wave", 1.0 if Settings.screen_fx == 0 else 0.3)


func _player_uv() -> Vector2:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return Vector2(0.5, 0.5)
	var vp := get_viewport()
	var sp: Vector2 = vp.get_canvas_transform() * p.global_position
	return sp / vp.get_visible_rect().size


## Decide rayos y polvo de la sala sin tocar el RNG global: hash de grid_pos,
## piso y semilla de la run. Diferido un frame para que LightKit.dark ya este al dia.
func _pick_room_fx() -> void:
	if _room == null or not is_instance_valid(_room):
		return
	var runs := get_node("/root/RunManager")
	var seed_v: int = runs.current_seed
	var floor_v: int = runs.current_floor
	var gp: Vector2i = _room.grid_pos
	var h := hash([gp.x, gp.y, floor_v, seed_v])
	var r1 := float(h & 0xFFFF) / 65535.0
	var r2 := float((h >> 16) & 0xFFFF) / 65535.0
	var ray_chance := 0.65 if LightKit.dark else 0.3
	_rays_target = (0.55 + 0.45 * r2) if r1 < ray_chance else 0.0
	_dust_target = 0.35 + 0.5 * r2 + (0.15 if LightKit.dark else 0.0)
