extends StaticBody2D
class_name WaxBlock

## CERA ENDURECIDA (J2 de Doña Cera). Un charco de cera pasa por: AVISO (contorno) -> QUEMA
## (zona de dano) -> SE ENFRIA (parpadeo) -> PARED (StaticBody2D en la capa 1: bloquea al jugador
## y a las balas, y se rompe a tiros). Tambien hace de "borde": bandas de cera que suben por los
## muros de la sala en la fase 3 (kind EDGE, sin quema). El jefe decide si puede endurecer
## (flood fill: nunca te encierra) con boss.wax_may_solidify(bloque).
## Sin luces y con el sombreado gris/color de los avisos del resto de zonas del jefe.

enum Kind { PUDDLE, EDGE }
enum Ph { WARN, BURN, COOL, SOLID, CRUMBLE }

const GROUP := "cera_wax"
const COOL_SECS := 0.9
const WAX := Color(1.0, 0.78, 0.3)
const WAX_SOLID := Color(0.93, 0.8, 0.5)
const WAX_DARK := Color(0.42, 0.26, 0.08)

var kind := Kind.PUDDLE
var radius := 38.0
## EDGE: tamano del rectangulo (centrado en la posicion).
var size := Vector2(100.0, 50.0)
var warn := 0.6
var burn := 5.0
var damage := 6.0
var harden := true
var hp := 36.0
var boss: Node = null

var phase := Ph.WARN
var t := 0.0
var solid_age := 0.0
var _hp_max := 36.0
var _shape: CollisionShape2D = null
var _mat := ShaderMaterial.new()
var _room: Node = null
var _seed := 0.0
var _wait_clear := 0.0
var _hurt: Area2D = null
var _flash := 0.0


static func puddle(b: Node, pos: Vector2, r: float, warn_: float, burn_: float, dmg: float, harden_ := true) -> WaxBlock:
	var w := WaxBlock.new()
	w.boss = b
	w.radius = r
	w.warn = warn_
	w.burn = burn_
	w.damage = dmg
	w.harden = harden_
	w.position = pos
	return w


static func edge(b: Node, pos: Vector2, size_: Vector2, warn_: float) -> WaxBlock:
	var w := WaxBlock.new()
	w.boss = b
	w.kind = Kind.EDGE
	w.size = size_
	w.warn = warn_
	w.burn = 0.0
	w.damage = 0.0
	w.hp = 120.0
	w.position = pos
	return w


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group("bot_hazard")
	_hp_max = hp
	_seed = float(get_instance_id() % 997)
	collision_layer = 0  # solo es pared cuando se endurece
	collision_mask = 0
	_shape = CollisionShape2D.new()
	if kind == Kind.PUDDLE:
		var c := CircleShape2D.new()
		c.radius = radius - 4.0
		_shape.shape = c
	else:
		var r := RectangleShape2D.new()
		r.size = size
		_shape.shape = r
	add_child(_shape)
	# romper con ataques cuerpo a cuerpo y areas del jugador (las balas llaman hit_by_bullet)
	_hurt = Area2D.new()
	_hurt.collision_layer = 0
	_hurt.collision_mask = 8
	var hs := CollisionShape2D.new()
	if kind == Kind.PUDDLE:
		var hc := CircleShape2D.new()
		hc.radius = radius + 8.0
		hs.shape = hc
	else:
		var hr := RectangleShape2D.new()
		hr.size = size + Vector2(10, 10)
		hs.shape = hr
	_hurt.add_child(hs)
	_hurt.area_entered.connect(_on_area)
	add_child(_hurt)
	_mat.shader = BossZone.CENSOR_UNSHADED
	# sin sombreado de censura: la cera siempre se ve en su color (peligro legible en sala gris)
	var n: Node = get_parent()
	while n != null and not (n is Room):
		n = n.get_parent()
	_room = n
	z_index = 2
	if boss != null and is_instance_valid(boss) and boss is CharacterBody2D:
		(boss as CharacterBody2D).add_collision_exception_with(self)  # la jefa se desliza por su cera


func _on_area(a: Area2D) -> void:
	if phase == Ph.SOLID and a.is_in_group("player_attack"):
		hit_by_bullet(float(a.damage) if "damage" in a else 10.0, Vector2.ZERO)


## Las balas del jugador llaman a esto al chocar con una pared (ver player_bullet.gd).
func hit_by_bullet(dmg: float, _dir: Vector2) -> void:
	if phase != Ph.SOLID:
		return
	hp -= dmg
	_flash = 0.12
	Sound.play("enemy_hit")
	if hp <= 0.0:
		crumble()


func crumble() -> void:
	if phase == Ph.CRUMBLE:
		return
	phase = Ph.CRUMBLE
	t = 0.0
	collision_layer = 0
	_hurt.monitoring = false
	Sound.play("crack")


func is_solid() -> bool:
	return phase == Ph.SOLID


## Cancela el aviso/quema sin endurecer (se enfria y desaparece).
func dismiss() -> void:
	if phase < Ph.SOLID:
		phase = Ph.CRUMBLE
		t = 0.0
		_hurt.monitoring = false


func _physics_process(delta: float) -> void:
	t += delta
	_flash = maxf(0.0, _flash - delta)
	_mat.set_shader_parameter("color_amount", Censor.amount(_room) if _room else 1.0)
	match phase:
		Ph.WARN:
			if t >= warn:
				phase = Ph.BURN if burn > 0.0 else Ph.COOL
				t = 0.0
		Ph.BURN:
			_burn_check()
			if t >= burn:
				if harden:
					phase = Ph.COOL
				else:
					phase = Ph.CRUMBLE
				t = 0.0
		Ph.COOL:
			_burn_check()
			if t >= COOL_SECS:
				_try_solid(delta)
		Ph.SOLID:
			solid_age += delta
		Ph.CRUMBLE:
			if t >= 0.5:
				queue_free()
	queue_redraw()


var _burned := false

func _burn_check() -> void:
	if damage <= 0.0 or kind == Kind.EDGE:
		return
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not p.has_method("receive_hit"):
		return
	# quema UNA vez por charco: pisarlo duele, pero no se castiga dos veces el mismo error
	if not _burned and p.global_position.distance_to(global_position) <= radius + 8.0:
		_burned = p.receive_hit(damage)


func _try_solid(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player")
	# sin jugador encima (no lo empotra) y con el visto bueno del jefe (flood fill)
	if p != null and _covers(p.global_position, 26.0):
		_wait_clear += delta
		if _wait_clear > 4.0:
			dismiss()
		return
	if boss != null and is_instance_valid(boss) and boss.has_method("wax_may_solidify") and not boss.wax_may_solidify(self):
		dismiss()
		return
	phase = Ph.SOLID
	t = 0.0
	collision_layer = 1
	Sound.play("crack")


## Cubre el punto (con margen)? Sirve para el flood fill y para no empotrar al jugador.
func _covers(p: Vector2, margin: float) -> bool:
	if kind == Kind.PUDDLE:
		return p.distance_to(global_position) <= radius + margin
	var l := p - global_position
	return absf(l.x) <= size.x * 0.5 + margin and absf(l.y) <= size.y * 0.5 + margin


## Protocolo del bot de pruebas (tools/autoplay): direccion para salir si este charco te quema
## (o te va a quemar en menos de `react` s). Vector2.ZERO = a salvo.
func bot_exit(p: Vector2, react: float) -> Vector2:
	if kind != Kind.PUDDLE or damage <= 0.0:
		return Vector2.ZERO
	if phase == Ph.WARN and warn - t > react:
		return Vector2.ZERO
	if phase > Ph.COOL:
		return Vector2.ZERO
	if p.distance_to(global_position) > radius + 14.0:
		return Vector2.ZERO
	var o := p - global_position
	return o.normalized() if o.length() > 0.5 else Vector2.RIGHT


func bot_urgent() -> bool:
	return phase >= Ph.BURN


func covers(p: Vector2, margin: float) -> bool:
	return _covers(p, margin)


# ------------------------------------------------------------------ dibujo
func _blob(r: float, col: Color, grow := 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var wob := 1.0 + 0.07 * sin(a * 3.0 + _seed) + 0.04 * sin(a * 5.0 + _seed * 2.0)
		pts.append(Vector2.RIGHT.rotated(a) * (r + grow) * wob)
	draw_colored_polygon(pts, col)


func _draw() -> void:
	var pulse := 0.65 + 0.35 * sin(t * 24.0)
	var white := Color(1, 1, 1)
	if kind == Kind.EDGE:
		_draw_edge(pulse)
		return
	match phase:
		Ph.WARN:
			var p := clampf(t / maxf(warn, 0.01), 0.0, 1.0)
			draw_circle(Vector2.ZERO, radius, Color(WAX, 0.10 + 0.22 * p))
			draw_circle(Vector2.ZERO, radius * p, Color(WAX, 0.35))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(Color(0.5, 0.1, 0.04).lerp(Color(1.0, 0.25, 0.08), pulse), 0.8 + 0.2 * pulse), 4.0)
		Ph.BURN:
			var left := clampf((burn - t) / maxf(burn, 0.01), 0.0, 1.0)
			_blob(radius + 2.0, Color(0.5, 0.1, 0.04, 0.95))
			_blob(radius - 2.0, Color(1.0, 0.6, 0.1, 0.92))
			draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 0.86, 0.32, 0.7 * left))
			for i in 5:  # burbujas que revientan y vapor
				var life := fposmod(t * 1.4 + i * 0.41, 1.0)
				draw_arc(Vector2(sin(i * 12.9 + _seed), cos(i * 7.3 + _seed)) * radius * 0.6, 2.0 + 8.0 * life, 0.0, TAU, 10, Color(0.5, 0.1, 0.04, 0.8 * (1.0 - life)), 2.0)
			for i in 3:
				var life2 := fposmod(t * 0.8 + i * 0.33, 1.0)
				draw_circle(Vector2(sin(i * 5.1 + _seed) * radius * 0.4, -life2 * 50.0), 9.0 + 12.0 * life2, Color(1.0, 0.9, 0.8, 0.14 * (1.0 - life2)))
		Ph.COOL:
			# se enfria: del naranja al color de cera dura, parpadeando (aun quema)
			var k := clampf(t / COOL_SECS, 0.0, 1.0)
			var c := WAX.lerp(WAX_SOLID, k)
			_blob(radius, Color(c, 0.9))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.5, 0.1, 0.04, 0.9), 4.0)
		Ph.SOLID:
			var shade := 1.0 + (2.0 if _flash > 0.0 else 0.0)
			_blob(radius + 3.0, Color(WAX_DARK, 1.0))
			_blob(radius - 2.0, Color(WAX_SOLID.r * shade, WAX_SOLID.g * shade, WAX_SOLID.b * shade, 1.0))
			draw_circle(Vector2(-radius * 0.25, -radius * 0.3), radius * 0.35, Color(1, 0.96, 0.8, 0.45))
			var dmg := 1.0 - hp / _hp_max
			for i in int(dmg * 6.0):
				var a := _seed + i * 1.9
				draw_line(Vector2.RIGHT.rotated(a) * radius * 0.2, Vector2.RIGHT.rotated(a + 0.4) * radius * 0.85, Color(WAX_DARK, 0.9), 2.0)
		Ph.CRUMBLE:
			var a := 1.0 - clampf(t / 0.5, 0.0, 1.0)
			_blob(radius * (0.7 + 0.3 * a), Color(WAX_SOLID, 0.7 * a))


func _draw_edge(pulse: float) -> void:
	var r := Rect2(-size * 0.5, size)
	match phase:
		Ph.WARN:
			var p := clampf(t / maxf(warn, 0.01), 0.0, 1.0)
			draw_rect(r, Color(WAX, 0.10 + 0.25 * p))
			draw_rect(r, Color(Color(0.5, 0.1, 0.04).lerp(Color(1.0, 0.25, 0.08), pulse), 0.9), false, 4.0)
		Ph.SOLID, Ph.COOL, Ph.BURN:
			var shade := 1.0 + (2.0 if _flash > 0.0 else 0.0)
			draw_rect(r, WAX_DARK)
			draw_rect(r.grow(-4.0), Color(WAX_SOLID.r * shade, WAX_SOLID.g * shade, WAX_SOLID.b * shade, 1.0))
			var x := r.position.x + 18.0
			while x < r.end.x:
				draw_line(Vector2(x, r.position.y + 6.0), Vector2(x - 10.0, r.end.y - 6.0), Color(WAX_DARK, 0.25), 3.0)
				x += 46.0
		Ph.CRUMBLE:
			var a := 1.0 - clampf(t / 0.5, 0.0, 1.0)
			draw_rect(r, Color(WAX_SOLID, 0.6 * a))
