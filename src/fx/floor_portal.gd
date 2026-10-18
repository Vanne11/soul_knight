class_name FloorPortal
extends Node2D

## Portal de salida al siguiente piso (antes una escotilla de dos discos). Arte por reino en
## assets/sprites/portal/ (tools/gen_portal_art.py): marco (base), remolino animado de 8
## fotogramas y piezas de primer plano. Encima: brillo aditivo (se ve tambien en sala clara),
## PointLight2D con pulso (solo en penumbra, como el resto de luces del kit), chispas que
## giran hacia el centro y otras que suben.
##
## Censura: nace GRIS y se colorea al liberar el reino (shader de censura, como las salas).
## Con el jefe el reino ya esta liberado y el color entra durante la apertura; con el
## guardian de la 1a etapa no se libera: se queda casi gris (un hilo de color para que
## se lea como "la salida" sin romper la regla).
##
## Uso: var p := FloorPortal.create(region, liberated); ...; await p.absorb(player);
## y FloorPortal.restore(player) tras cambiar de piso.

const DIR := "res://assets/sprites/portal/"
const CENSOR_SHADER := preload("res://src/shaders/censor.gdshader")
## region (floor_data.region) -> carpeta de arte y color del reino.
const THEMES := {
	"selva": {"art": "neutral", "color": Color("7fe0a0")},
	"penelandia": {"art": "pene", "color": Color("6ec6ff")},
	"vulvania": {"art": "vulva", "color": Color("ff7ac0")},
	"perineo": {"art": "mixto", "color": Color("ffc93c")},
	"palacio": {"art": "censura", "color": Color("b48cff")},
	"prostata": {"art": "prostata", "color": Color("d8b890")},
}
const CENTER := Vector2(80, 92)   # centro del portal en el lienzo del arte
const FRAMES := 8
const SWIRL_FPS := 9.0
const OPEN_TIME := 0.75
const CENSORED_AMOUNT := 0.14     # guardian sin liberar: casi gris
const ABSORB_TIME := 0.8

var color := Color.WHITE
var _amount := 0.0                # color_amount (0 gris, 1 color)
var _mat: ShaderMaterial
var _swirl: Sprite2D
var _glow: Sprite2D
var _light: PointLight2D
var _sparks: Node2D
var _t := 0.0
var _open := 0.0                  # 0..1 mientras se abre (escala la luz y las chispas)
var _liberated := false
var _boost := 0.0                 # empujon de luz al absorber


static func create(region: String, liberated: bool) -> FloorPortal:
	var p := FloorPortal.new()
	p._build(THEMES.get(region, THEMES["selva"]), liberated)
	return p


func _build(theme: Dictionary, liberated: bool) -> void:
	set_meta("flat", true)  # esta en el suelo: sin sombra de contacto (el marco ya trae su canto)
	color = theme.color
	_mat = ShaderMaterial.new()
	_mat.shader = CENSOR_SHADER
	_mat.set_shader_parameter("color_amount", CENSORED_AMOUNT)
	_amount = CENSORED_AMOUNT
	var art: String = theme.art
	# brillo aditivo bajo el marco
	_glow = Sprite2D.new()
	_glow.texture = LightKit.light_texture()
	_glow.scale = Vector2(1.0, 0.8) * 1.1
	_glow.modulate = Color(color.r, color.g, color.b, 0.0)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow.material = add
	add_child(_glow)
	add_child(_layer(DIR + "base_%s.png" % art))
	_swirl = Sprite2D.new()
	_swirl.texture = load(DIR + "swirl_%s.png" % art)
	_swirl.hframes = FRAMES
	_swirl.material = _mat
	add_child(_swirl)
	add_child(_layer(DIR + "front_%s.png" % art))
	_sparks = _Sparks.new()
	_sparks.portal = self
	_sparks.material = add
	add_child(_sparks)
	_light = LightKit.make_light(color, 1.0, 2.3, false)
	add_child(_light)
	_liberated = liberated


func _ready() -> void:
	# apertura: nace chiquito y girando, con destello
	scale = Vector2.ONE * 0.05
	_swirl.rotation = -PI
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, OPEN_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_swirl, "rotation", 0.0, OPEN_TIME + 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_open", 1.0, OPEN_TIME + 0.4)
	Sound.play("door")
	_flash()
	if _liberated:
		# el reino acaba de liberarse: el color entra mientras se abre
		var c := create_tween()
		c.tween_interval(0.3)
		c.tween_method(_set_amount, CENSORED_AMOUNT, 1.0, 1.2)


func _layer(path: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.position = -CENTER
	s.material = _mat
	return s


func _set_amount(v: float) -> void:
	_amount = v
	_mat.set_shader_parameter("color_amount", v)


## Destello blanco-del-reino que se expande al abrir.
func _flash() -> void:
	var f := Sprite2D.new()
	f.texture = LightKit.light_texture()
	f.modulate = color.lerp(Color.WHITE, 0.6)
	f.scale = Vector2.ONE * 0.3
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	f.material = add
	f.z_index = 2
	add_child(f)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(f, "scale", Vector2.ONE * 2.2, 0.55).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "modulate:a", 0.0, 0.55)
	tw.chain().tween_callback(f.queue_free)


func _process(delta: float) -> void:
	_t += delta
	_swirl.frame = int(_t * SWIRL_FPS) % FRAMES
	var vis := 0.4 + 0.6 * _amount   # gris = luz y brillo bajitos
	var pulse := 0.88 + 0.12 * sin(_t * 2.6) + 0.05 * sin(_t * 7.1)
	_light.energy = 1.0 * vis * pulse * _open * (1.0 + _boost)
	_light.texture_scale = 2.3 * (0.95 + 0.05 * sin(_t * 2.6)) * (1.0 + 0.3 * _boost)
	_glow.modulate.a = (0.22 + 0.07 * sin(_t * 2.6)) * vis * _open * (1.0 + _boost)
	if _amount < 0.3:  # el color del brillo tambien se apaga
		_glow.modulate = Color(0.8, 0.82, 0.9, _glow.modulate.a * 0.6)
	else:
		_glow.modulate = Color(color.r, color.g, color.b, _glow.modulate.a)


## Uso: el heroe se encoge y gira hacia el centro (el portal tira de el). Esperar con await;
## despues cambiar de piso y llamar a FloorPortal.restore(player).
func absorb(player: Node) -> void:
	Sound.play("suck")
	if player.has_method("set_physics_process"):
		player.set_physics_process(false)
	if "velocity" in player:
		player.velocity = Vector2.ZERO
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "_boost", 1.5, ABSORB_TIME)
	tw.tween_property(player, "global_position", global_position + Vector2(0, -4), ABSORB_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for n in _visuals(player):
		tw.tween_property(n, "scale", Vector2.ONE * 0.04, ABSORB_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(n, "rotation", n.rotation + TAU * 2.0, ABSORB_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(player.get("animated_sprite"), "modulate", color.lerp(Color.WHITE, 0.4), ABSORB_TIME)
	await tw.finished
	_flash()
	await get_tree().create_timer(0.12).timeout


## Deja al heroe como estaba (escala/giro/color) tras la absorcion.
static func restore(player: Node) -> void:
	if not is_instance_valid(player):
		return
	for n in _visuals(player):
		n.scale = Vector2.ONE
		n.rotation = 0.0
	var spr = player.get("animated_sprite")
	if spr:
		spr.modulate = Color.WHITE
	player.set_physics_process(true)


static func _visuals(player: Node) -> Array:
	var out: Array = []
	for k in ["animated_sprite", "weapon_pivot"]:
		var n = player.get(k)
		if n is Node2D:
			out.append(n)
	return out


## Chispas: unas orbitan cerrando la espiral hacia el centro, otras suben desde el marco.
class _Sparks extends Node2D:
	const ORBIT := 26
	const RISE := 12
	const RX := 60.0
	const RY := 48.0
	var portal: FloorPortal
	var _o: Array = []   # [angulo, radio 0..1, velocidad, tamano]
	var _r: Array = []   # [x, y, vy, vida, vida_max, deriva]
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.randomize()
		for i in ORBIT:
			_o.append([_rng.randf() * TAU, _rng.randf_range(0.15, 1.0), _rng.randf_range(0.9, 1.8), _rng.randi_range(1, 2)])
		for i in RISE:
			_r.append(_spawn_rise(_rng.randf()))

	func _spawn_rise(age01: float) -> Array:
		var a := _rng.randf() * TAU
		var life := _rng.randf_range(1.2, 2.2)
		return [cos(a) * RX * 0.8, sin(a) * RY * 0.8, _rng.randf_range(16.0, 30.0), life * age01, life, _rng.randf_range(-1.0, 1.0)]

	func _process(delta: float) -> void:
		for p in _o:
			p[0] += delta * p[2] * (1.6 - p[1] * 0.8)   # mas rapido cerca del centro
			p[1] -= delta * 0.22
			if p[1] < 0.06:
				p[1] = 1.0
				p[0] = _rng.randf() * TAU
		for i in _r.size():
			var p: Array = _r[i]
			p[3] += delta
			p[1] -= p[2] * delta
			p[0] += p[5] * 6.0 * delta
			if p[3] >= p[4]:
				_r[i] = _spawn_rise(0.0)
		queue_redraw()

	func _draw() -> void:
		if portal == null:
			return
		var amt := portal._amount
		var open := portal._open
		var base := Color(0.82, 0.83, 0.9).lerp(portal.color.lerp(Color.WHITE, 0.35), clampf((amt - 0.14) / 0.86, 0.0, 1.0))
		for p in _o:
			var r: float = p[1]
			var pos := Vector2(cos(p[0]) * r * RX, sin(p[0]) * r * RY)
			var a := clampf(r * 2.5, 0.0, 1.0) * clampf((1.0 - r) * 4.0 + 0.4, 0.0, 1.0) * open
			draw_rect(Rect2(pos.round() - Vector2(p[3], p[3]) * 0.5, Vector2(p[3], p[3])), Color(base, a * (0.5 + 0.5 * amt)))
		for p in _r:
			var k: float = p[3] / p[4]
			var a := sin(k * PI) * open
			var s := 2.0 if k < 0.6 else 1.0
			draw_rect(Rect2(Vector2(p[0], p[1]).round(), Vector2(s, s)), Color(base, a * (0.55 + 0.45 * amt)))
