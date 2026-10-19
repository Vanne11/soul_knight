class_name StatusEffects
extends Node2D

## Estados temporales que los enemigos (Etapa 3a) le ponen al jugador. Es un nodo hijo del
## jugador que se crea solo la primera vez (`StatusEffects.of(player)`); player.gd solo lo
## consulta en 3 sitios (disparar, dash y caminar). Cada estado se dibuja sobre el heroe.
##
##   enrollado    la Huincha de Medir te enrolla: casi no avanzas.
##   enjaulado    Jaula Carcelera: sin disparar ni dash, casi inmovil. Machaca para salir.
##   esposado     Esposas peludas: atado a un enemigo (cadena) y sin poder disparar. Machaca,
##                o mata/aturde al enemigo (embestida, espolon) para soltarte.
##   amordazado   Mordaza: sin habilidades de heroe (escudo, alas, grito, huevo, espolon) y el
##                narrador se calla.
##   vendado      Venda: pantalla casi a oscuras alrededor del heroe.
##   enganchado   La Correa te arrastra hacia su dueno. El dash te suelta.
##   desteñido    Piso gris de La Censura que destine (Arcoiria): te frena mientras lo pisas (0,6x).
##   mareado      Vapores del Frasquito Magico (templo de Anubis): la pantalla ondula (ScreenFx lee `dizzy`) y
##                el control se vuelve torpe (un vaiven lateral suave y -15 % de velocidad). Se pasa solo.
##   etiquetado   La Etiqueta (Arcoiria) te pega etiquetas: cada una te frena (hasta 3). El dash las
##                ROMPE y cada etiqueta rota hace dano a los enemigos cercanos (Arcoiria.rip_labels).
##
## `apply()` devuelve false si estas esquivando (dash): no se aplica nada.

signal applied(kind: String)
signal ended(kind: String)

const KINDS := ["enrollado", "enjaulado", "esposado", "amordazado", "vendado", "enganchado", "etiquetado", "desteñido", "mareado"]
const MASH_ACTIONS := ["attack", "dash", "interact"]
const MASH_STEP := 0.3
const SPEED := {"enrollado": 0.3, "enjaulado": 0.45, "esposado": 0.85, "enganchado": 0.9, "desteñido": 0.6, "mareado": 0.85}
const TEXT_COLOR := {
	"enrollado": Color("ffd23a"), "enjaulado": Color("b8b8c8"), "esposado": Color("ff7ac0"),
	"amordazado": Color("e8322e"), "vendado": Color("8890a8"), "enganchado": Color("ff9a2e"),
	"etiquetado": Color("ffd23a"), "desteñido": Color("a8a8b8"), "mareado": Color("d4ee5a"),
}
const LABEL_SLOW := 0.82   ## velocidad que queda por cada etiqueta pegada
const LABEL_MAX := 3
const LABEL_SECS := 7.0
const PUSH_DECAY := 1500.0
const PULL_SPEED := 300.0
const TETHER := 130.0
const BLIND_HALF := 2000.0
const BLIND_SHADER := """
shader_type canvas_item;
uniform float radius = 46.0;
uniform float soft = 30.0;
uniform float darkness = 0.0;
varying vec2 wpos;
void vertex() { wpos = VERTEX - vec2(2000.0); }
void fragment() {
	float d = length(wpos);
	float a = smoothstep(radius, radius + soft, d) * 0.96 * darkness;
	COLOR = vec4(0.02, 0.0, 0.04, a);
}
"""

## Mareo actual 0..1 (lo lee ScreenFx para ondular la pantalla).
static var dizzy := 0.0

var player: Node2D = null
var _left := {}        ## kind -> segundos que faltan
var _total := {}       ## kind -> segundos totales
var _src := {}         ## kind -> enemigo que lo causo (cadena, correa)
var _pull := Vector2.ZERO
var _push := Vector2.ZERO   ## empujon puntual (El Armario): se apaga solo
var labels := 0             ## etiquetas pegadas ahora
var _blind: ColorRect = null
var _t := 0.0


## El componente del jugador (lo crea si no existe).
static func of(p: Node) -> StatusEffects:
	if p == null or not is_instance_valid(p):
		return null
	var n := p.get_node_or_null("StatusEffects")
	if n is StatusEffects:
		return n
	var s := StatusEffects.new()
	s.name = "StatusEffects"
	s.player = p as Node2D
	s.z_index = 50
	p.add_child(s)
	return s


func _ready() -> void:
	if player == null:
		player = get_parent() as Node2D


func apply(kind: String, seconds: float, src: Node = null) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if "is_dashing" in player and player.is_dashing:
		return false
	var df = player.get("defense")
	if df != null and (df.blocks_status() or df.blocks_status_kind(kind)):  # Vacuna VPH: inmune a estados un rato
		return false
	var was := _left.has(kind)
	_left[kind] = maxf(float(_left.get(kind, 0.0)), seconds)
	_total[kind] = maxf(float(_total.get(kind, 0.0)), seconds)
	if src != null:
		_src[kind] = src
	if not was:
		_begin(kind)
	applied.emit(kind)
	return true


func active(kind: String) -> bool:
	return float(_left.get(kind, 0.0)) > 0.0


func any_active() -> bool:
	return not _left.is_empty()


func time_left(kind: String) -> float:
	return float(_left.get(kind, 0.0))


## La Etiqueta te pega otra etiqueta (hasta LABEL_MAX). false si esquivas.
func stick_label(src: Node = null) -> bool:
	if not apply("etiquetado", LABEL_SECS, src):
		return false
	labels = mini(labels + 1, LABEL_MAX)
	return true


## Empujon: suma una velocidad que se apaga sola (la camina el jugador en player.gd con pull_velocity).
func push(v: Vector2) -> void:
	var df = player.get("defense") if player != null else null
	if df != null and df.anchored():
		return  # Tampon Ancla: no te mueves
	_push = v * (df.knockback_mult() if df != null else 1.0)


func blocks_shoot() -> bool:
	return active("enjaulado") or active("esposado")


func blocks_dash() -> bool:
	return active("enjaulado")


func silenced() -> bool:
	return active("amordazado")


func speed_mult() -> float:
	var m := 1.0
	for k in SPEED:
		if active(k):
			m *= SPEED[k]
	if active("etiquetado"):
		m *= pow(LABEL_SLOW, labels)
	return m


## Velocidad extra impuesta (correa, cadena, empujon). Player la suma al caminar.
func pull_velocity() -> Vector2:
	var df = player.get("defense") if player != null else null
	if df != null and df.anchored():
		return Vector2.ZERO
	return _pull + _push


func clear(kind := "") -> void:
	for k in _left.keys():
		if kind == "" or k == kind:
			_end(k)


func _exit_tree() -> void:
	dizzy = 0.0


func _begin(kind: String) -> void:
	var ge := get_node_or_null("/root/GlobalEvents")
	var label := Loc.tr_or("E3A_STATE_" + kind.to_upper(), kind.to_upper())
	if ge != null and player != null:
		ge.show_floating_text.emit(player.global_position + Vector2(0, -38), label, TEXT_COLOR.get(kind, Color.WHITE))
	match kind:
		"amordazado":
			_set_abilities(false)
		"vendado":
			_make_blind()
	queue_redraw()


func _end(kind: String) -> void:
	_left.erase(kind)
	_total.erase(kind)
	_src.erase(kind)
	match kind:
		"amordazado":
			_set_abilities(true)
		"vendado":
			if _blind != null and is_instance_valid(_blind):
				_blind.queue_free()
			_blind = null
		"enganchado":
			_pull = Vector2.ZERO
		"mareado":
			dizzy = 0.0
	ended.emit(kind)
	queue_redraw()


## Habilidades de heroe: se apagan (proceso desactivado) y se sueltan el escudo/planeo.
func _set_abilities(on: bool) -> void:
	var ab = player.get("ability") if player != null else null
	if ab == null or not is_instance_valid(ab):
		return
	if not on:
		if "guarding" in ab and ab.guarding and ab.has_method("_release"):
			ab._release(0.0)
		if "gliding" in ab:
			ab.gliding = false
		ab.gauge_visible = false
	ab.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _make_blind() -> void:
	if _blind != null:
		return
	_blind = ColorRect.new()
	_blind.size = Vector2(BLIND_HALF * 2.0, BLIND_HALF * 2.0)
	_blind.position = -_blind.size * 0.5
	_blind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BLIND_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("darkness", 0.0)
	_blind.material = mat
	add_child(_blind)


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_t += delta
	_pull = Vector2.ZERO
	_push = _push.move_toward(Vector2.ZERO, PUSH_DECAY * delta)
	var dashing: bool = "is_dashing" in player and player.is_dashing
	for k in _left.keys():
		var dt := delta
		# machacar: soltarse mas rapido de la jaula y las esposas
		if k == "enjaulado" or k == "esposado":
			for a in MASH_ACTIONS:
				if Input.is_action_just_pressed(a):
					dt += MASH_STEP
		if k == "enganchado" and dashing:
			dt += 99.0
		var src_v = _src.get(k, null)  # sin tipo: asignar un nodo ya liberado a una var Node da error
		var src: Node = src_v if is_instance_valid(src_v) else null
		if k == "esposado" or k == "enganchado":
			if src == null or not is_instance_valid(src) or float(src.get("current_health")) <= 0.0:
				dt += 99.0  # el dueno murio: se acabo
			elif k == "esposado" and int(src.get("state")) == Enemy.State.STUNNED:
				dt += 99.0  # lo aturdiste (embestida / espolon): te suelta
		_left[k] = float(_left[k]) - dt
		if k == "esposado" and src != null and is_instance_valid(src) and not dashing:
			var to: Vector2 = src.global_position - player.global_position
			if to.length() > TETHER:
				_pull += to.normalized() * (to.length() - TETHER) * 6.0
		if k == "enganchado" and src != null and is_instance_valid(src):
			var to2: Vector2 = src.global_position - player.global_position
			if to2.length() > 42.0:
				_pull += to2.normalized() * PULL_SPEED
		if k == "mareado":
			_pull += Vector2(sin(_t * 2.3), cos(_t * 1.7)) * 60.0 * clampf(float(_left[k]), 0.0, 1.0)
		if k == "amordazado":
			_hush_narrator()
		if float(_left[k]) <= 0.0:
			_end(k)
	dizzy = clampf(time_left("mareado") / 0.8, 0.0, 1.0) * 0.6 if active("mareado") else 0.0
	if _blind != null and is_instance_valid(_blind):
		var left := time_left("vendado")
		var tot := maxf(float(_total.get("vendado", 1.0)), 0.1)
		var fade := minf(minf(left, tot - left) / 0.35, 1.0) if tot > 0.7 else 1.0
		(_blind.material as ShaderMaterial).set_shader_parameter("darkness", clampf(fade, 0.0, 1.0))
	if any_active():
		queue_redraw()


func _hush_narrator() -> void:
	var nar := get_node_or_null("/root/Narrator")
	if nar != null and "_queue" in nar:
		nar._queue.clear()


# ------------------------------------------------------------------ dibujo
func _draw() -> void:
	if active("enrollado"):
		_draw_tape()
	if active("enjaulado"):
		_draw_cage()
	if active("esposado"):
		_draw_cuffs()
	if active("amordazado"):
		_draw_gag()
	if active("enganchado"):
		_draw_leash()
	if active("etiquetado"):
		_draw_labels()


func _draw_tape() -> void:
	var col := Color("ffd23a")
	var dark := Color("2a2210")
	for i in 5:
		var y := -22.0 + i * 9.0
		var w := 15.0 - absf(i - 2) * 1.5
		draw_line(Vector2(-w, y), Vector2(w, y + 3.0), dark, 5.0)
		draw_line(Vector2(-w, y), Vector2(w, y + 3.0), col, 3.0)
		for j in range(-2, 3):
			draw_line(Vector2(j * 6.0, y + 0.5 + j * 0.4), Vector2(j * 6.0, y + 2.5 + j * 0.4), dark, 1.0)


func _draw_cage() -> void:
	var shake := sin(_t * 40.0) * 0.6 if time_left("enjaulado") < 1.0 else 0.0
	var col := Color("c8c8d8")
	var dark := Color("23202c")
	for i in range(-3, 4):
		var x := i * 7.0 + shake
		draw_line(Vector2(x, -32), Vector2(x, 14), dark, 4.0)
		draw_line(Vector2(x, -32), Vector2(x, 14), col, 2.0)
	for y in [-32.0, -9.0, 14.0]:
		draw_line(Vector2(-24 + shake, y), Vector2(24 + shake, y), dark, 5.0)
		draw_line(Vector2(-24 + shake, y), Vector2(24 + shake, y), col, 3.0)


func _draw_cuffs() -> void:
	var src_v = _src.get("esposado", null)
	var src: Node = src_v if is_instance_valid(src_v) else null
	var gold := Color("ff7ac0")
	draw_circle(Vector2(-14, 4), 5.0, Color("23202c"))
	draw_circle(Vector2(14, 4), 5.0, Color("23202c"))
	draw_arc(Vector2(-14, 4), 4.0, 0.0, TAU, 14, gold, 2.0)
	draw_arc(Vector2(14, 4), 4.0, 0.0, TAU, 14, gold, 2.0)
	draw_line(Vector2(-10, 4), Vector2(10, 4), Color("b8b8c8"), 2.0)
	if src != null and is_instance_valid(src):
		var to := to_local(src.global_position + Vector2(0, -8))
		var n := 9
		for i in n:
			var a := Vector2(0, 4).lerp(to, float(i) / n)
			draw_circle(a, 2.2, Color("23202c"))
			draw_circle(a, 1.4, Color("d8d8e6"))


func _draw_gag() -> void:
	var head := Vector2(0, -24)
	draw_circle(head, 5.5, Color("23202c"))
	draw_circle(head, 4.5, Color("e8322e"))
	draw_circle(head + Vector2(-1.5, -1.5), 1.4, Color("ff9a90"))
	draw_line(head + Vector2(-5, 0), head + Vector2(-13, -2), Color("23202c"), 3.0)
	draw_line(head + Vector2(5, 0), head + Vector2(13, -2), Color("23202c"), 3.0)


func _draw_leash() -> void:
	var src_v = _src.get("enganchado", null)
	var src: Node = src_v if is_instance_valid(src_v) else null
	if src == null or not is_instance_valid(src):
		return
	var to := to_local(src.global_position + Vector2(0, -8))
	var prev := Vector2(0, -6)
	var n := 10
	for i in range(1, n + 1):
		var f := float(i) / n
		var p := Vector2(0, -6).lerp(to, f) + Vector2(0, sin(f * PI) * 7.0)
		draw_line(prev, p, Color("23160a"), 4.0)
		draw_line(prev, p, Color("a0602a"), 2.0)
		prev = p
	draw_circle(Vector2(0, -6), 3.5, Color("c8c8d8"))


## Etiquetas pegadas en el torso (una por cada una), torcidas y con renglones de "texto".
func _draw_labels() -> void:
	var spots := [Vector2(-9, -8), Vector2(7, -14), Vector2(-3, 2)]
	for i in labels:
		var c: Vector2 = spots[i]
		var rot: float = [-0.25, 0.2, -0.1][i]
		draw_set_transform(c, rot)
		draw_rect(Rect2(-7, -4.5, 14, 9), Color("23202c"))
		draw_rect(Rect2(-6, -3.5, 12, 7), Color("ffd23a"))
		draw_rect(Rect2(-6, -3.5, 4, 7), Color("fff0a0"))
		draw_line(Vector2(-3, -1), Vector2(4, -1), Color("23202c"), 1.0)
		draw_line(Vector2(-3, 1.5), Vector2(2, 1.5), Color("23202c"), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0)
