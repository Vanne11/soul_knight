class_name WorldFx
extends Node2D

## Efectos de mundo (roadmap tanda 4, puntos 46-53 y 66): polvo al caminar y nube de dash,
## casquillos y gotitas al disparar, chispas de balas contra muros, salpicaduras rosas al
## golpear, restos que se desvanecen, particulas ambientales por reino, burbujas y vapor en
## el antro, brillos al liberar sala/region y huellas de liquidos.
##
## Main la anade con una linea en _ready. Solo OBSERVA: posiciones de jugador y grupo
## "enemy", senales de GlobalEvents (enemy_damaged, enemy_killed), `node_added` para balas
## nuevas y el estado de la sala (cleared) y del RunManager (liberated). No toca player,
## enemigos, puertas ni cofres.
##
## Particulas propias (arrays + _draw, cuadraditos de 1-3 px = pixel art a zoom 2) en vez de
## cientos de nodos GPUParticles. Capas:
##  - aire: por encima de todo el mundo (z 10); se grisa segun la censura de la sala.
##  - brillo: igual pero aditiva y sin luces (chispas, brasas, destellos).
##  - suelo: hija de la sala, entre el suelo y los actores; nace con el material de Censor
##    (huellas, restos, casquillos caidos), asi se colorea sola al liberar la sala.
## Determinismo: no usa el autoload RNG, solo randf()/randi() globales de Godot.

const ART := "res://assets/sprites/fx/"
const MAX_PARTS := 520
const MAX_DECALS := 90

enum K { SQUARE, CASING, PUFF, BUBBLE, SPARKLE, PETAL, CONFETTI, SPARK }

## Colores del polvo por reino.
const DUST := {
	"neutral": Color(0.66, 0.58, 0.42), "pene": Color(0.72, 0.8, 0.92),
	"vulva": Color(0.92, 0.72, 0.8), "mixto": Color(0.82, 0.72, 0.5),
	"censura": Color(0.74, 0.74, 0.8), "prostata": Color(0.8, 0.7, 0.66),
}
## Color de la huella cuando no se puede sacar del charco.
const LIQUID := {
	"water": Color(0.62, 0.82, 1.0), "mud": Color(0.42, 0.28, 0.16), "baba": Color(1.0, 0.82, 0.92),
	"dudoso": Color(0.82, 0.88, 0.3), "tinta": Color(0.16, 0.08, 0.26), "aceite": Color(0.2, 0.15, 0.1),
	"whiskey": Color(0.86, 0.52, 0.14),
}
const PINKS := [Color(1.0, 0.45, 0.7), Color(0.95, 0.3, 0.55), Color(1.0, 0.78, 0.88)]
const GLITTER := [Color(1.0, 0.48, 0.75), Color(1.0, 0.85, 0.3), Color(0.45, 0.9, 1.0),
	Color(0.55, 1.0, 0.7), Color(0.78, 0.6, 1.0), Color(1.0, 1.0, 1.0)]

## Pasos de huella: cuanto liquido queda al salir del charco y cada cuantos px se pisa.
const WET_STEPS := 10.0
const STEP_PLAYER := 15.0
const STEP_ENEMY := 20.0
const FOOT_LIFE := 7.0


class P extends RefCounted:
	var p := Vector2.ZERO      # posicion en el suelo (mundo)
	var z := 0.0               # altura sobre el suelo (se dibuja p - z)
	var v := Vector2.ZERO
	var vz := 0.0
	var g := 0.0               # gravedad (si > 0, al tocar el suelo rebota/aterriza)
	var drag := 0.0
	var age := 0.0             # negativo = aun no nace (retardo)
	var life := 1.0
	var hold := 0.0            # tiempo a opacidad completa antes de apagarse
	var col := Color.WHITE
	var sz := Vector2(1, 1)
	var kind := K.SQUARE
	var grow := 0.0            # px de radio por segundo (puffs, burbujas)
	var phase := 0.0
	var amp := 0.0             # vaiven lateral (px/s)
	var freq := 3.0
	var env := false           # entra y sale suavemente (ambientales)
	var exempt := false        # no se grisa nunca (confeti gris, brillos de liberar)
	var amb := false           # cuenta para el tope de ambientales
	var bounce := 0
	var stain := 0.0           # prob. de dejar mancha en el suelo al aterrizar
	var stain_life := 2.5
	var pop := false           # al terminar revienta en chispitas (burbujas)


class Layer extends Node2D:
	var ps: Array = []
	var decals: Array = []     # [{spr, age, life, hold, base}] (solo la capa de suelo)
	var use_gray := false
	var amount := 1.0          # color_amount de la sala (1 = color)

	func _draw() -> void:
		for q: P in ps:
			if q.age < 0.0:
				continue
			var t := q.age / q.life
			var a := 1.0
			if q.age > q.hold:
				a = clampf(1.0 - (q.age - q.hold) / maxf(q.life - q.hold, 0.01), 0.0, 1.0)
			if q.env:
				a = minf(a, minf(t / 0.2, 1.0))
				a = minf(a, clampf((1.0 - t) / 0.3, 0.0, 1.0))
			if q.kind == K.SPARKLE:
				a *= 0.55 + 0.45 * sin(q.age * 9.0 + q.phase)
			var c: Color = q.col
			if use_gray and not q.exempt and amount < 0.999:
				var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				c = Color(l * 0.88, l * 0.88, l * 0.95, c.a).lerp(c, amount)
			c.a *= a
			if c.a <= 0.01:
				continue
			var pos: Vector2 = (q.p - Vector2(0, q.z)).round()
			match q.kind:
				K.SQUARE:
					draw_rect(Rect2(pos - q.sz * 0.5, q.sz), c)
				K.CASING:
					draw_rect(Rect2(pos, q.sz), c)
					draw_rect(Rect2(pos, Vector2(q.sz.x, 1)), Color(1, 1, 1, 0.45 * c.a))
				K.PUFF:
					var r: float = q.sz.x + q.grow * q.age
					draw_circle(pos, r, c)
				K.BUBBLE:
					var r2: float = q.sz.x + q.grow * q.age
					draw_circle(pos, r2, Color(c.r, c.g, c.b, c.a * 0.22))
					draw_arc(pos, r2, 0.0, TAU, 12, c, 1.0)
					draw_rect(Rect2(pos + Vector2(-r2 * 0.5, -r2 * 0.5), Vector2(1, 1)), Color(1, 1, 1, c.a))
				K.SPARKLE:
					var s := int(q.sz.x)
					draw_rect(Rect2(pos + Vector2(-s, 0), Vector2(s * 2 + 1, 1)), c)
					draw_rect(Rect2(pos + Vector2(0, -s), Vector2(1, s * 2 + 1)), c)
					if s > 1:
						draw_rect(Rect2(pos, Vector2(1, 1)), Color(1, 1, 1, c.a))
				K.PETAL:
					var flat := sin(q.age * 5.0 + q.phase) > 0.0
					var w := Vector2(3, 2) if flat else Vector2(2, 3)
					draw_rect(Rect2(pos, w), c)
					draw_rect(Rect2(pos, Vector2(1, 1)), Color(1, 1, 1, 0.5 * c.a))
				K.CONFETTI:
					var fl := sin(q.age * 7.0 + q.phase) > 0.0
					draw_rect(Rect2(pos, Vector2(2, 1) if fl else Vector2(1, 2)), c)
				K.SPARK:
					draw_line(pos, pos - q.v.normalized() * clampf(q.v.length() * 0.05, 1.0, 7.0), c, 1.0)


# ------------------------------------------------------------------ estado
var _main: Node
var _player: CharacterBody2D
var _air := Layer.new()
var _glow := Layer.new()
var _bright := Layer.new()  # colores plenos sin luces (brillos de liberar)
var _ground: Layer = null
var _room: Node = null
var _rect := Rect2()
var _kingdom := "neutral"
var _room_time := 0.0
var _setup_wait := 0
var _prev_cleared := false
var _prev_floor := -1
var _prev_lib := false
var _amb_count := 0
var _amb_t := 0.0
var _antro_t := 0.0
var _vapor_t := 0.0
var _puddles: Array = []   # [{pos, kind, tex, img, size, flip}]
var _acts := {}            # instance_id -> estado de pasos
var _last_shot := 0
var _was_dashing := false
var _foot_tex: Texture2D
var _splat_tex: Array[Texture2D] = []


func _ready() -> void:
	name = "WorldFx"
	add_to_group("world_fx")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_foot_tex = load(ART + "footprint.png")
	for i in 3:
		_splat_tex.append(load("%ssplat_%d.png" % [ART, i]))
	_main = get_parent()
	_air.z_index = 10
	_air.use_gray = true
	_air.name = "Air"
	add_child(_air)
	_glow.z_index = 11
	_glow.use_gray = true
	_glow.name = "Glow"
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_glow.material = mat
	add_child(_glow)
	_bright.z_index = 11
	_bright.use_gray = true
	_bright.name = "Bright"
	var bm := CanvasItemMaterial.new()
	bm.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_bright.material = bm
	add_child(_bright)
	var ge := get_node("/root/GlobalEvents")
	ge.enemy_damaged.connect(_on_enemy_damaged)
	ge.enemy_killed.connect(_on_enemy_killed)
	get_tree().node_added.connect(_on_node_added)


func _exit_tree() -> void:
	if get_tree() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


# ------------------------------------------------------------------ bucle
func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	var room: Node = _main.get("current_room")
	if room != _room:
		_set_room(room)
	if _room == null or not is_instance_valid(_room):
		return
	_room_time += delta
	var amt := Censor.amount(_room)
	_air.amount = amt
	_glow.amount = amt
	_bright.amount = amt

	if _setup_wait > 0:
		_setup_wait -= 1
		if _setup_wait == 0:
			_finish_room_setup()
	_watch_events()
	if _player and is_instance_valid(_player):
		_watch_shots()
		_watch_actors(delta)
	_ambient(delta)
	_antro(delta)
	_step_layer(_air, delta)
	_step_layer(_glow, delta)
	_step_layer(_bright, delta)
	if _ground and is_instance_valid(_ground):
		_step_layer(_ground, delta)
		_step_decals(delta)
	_air.queue_redraw()
	_glow.queue_redraw()
	_bright.queue_redraw()
	if _ground and is_instance_valid(_ground):
		_ground.queue_redraw()


func _count() -> int:
	return _air.ps.size() + _glow.ps.size() + _bright.ps.size()


func _layer_for(glow: bool) -> Layer:
	return _glow if glow else _air


func _add_bright(q: P) -> void:
	if _count() < MAX_PARTS:
		_bright.ps.append(q)


func _add(q: P, glow := false) -> void:
	if _count() >= MAX_PARTS:
		return
	_layer_for(glow).ps.append(q)


func _step_layer(layer: Layer, dt: float) -> void:
	var ps := layer.ps
	var i := ps.size() - 1
	while i >= 0:
		var q: P = ps[i]
		q.age += dt
		if q.age >= q.life:
			if q.pop:
				_pop(q)
			if q.amb:
				_amb_count -= 1
			ps[i] = ps[ps.size() - 1]
			ps.pop_back()
		elif q.age >= 0.0:
			if q.g > 0.0:
				q.vz -= q.g * dt
				q.z += q.vz * dt
				if q.z <= 0.0:
					q.z = 0.0
					if q.bounce > 0 and absf(q.vz) > 25.0:
						q.vz = -q.vz * 0.35
						q.v *= 0.5
						q.bounce -= 1
					else:
						_land(q, layer, i)
						i -= 1
						continue
			if q.amp != 0.0:
				q.p.x += sin(q.age * q.freq + q.phase) * q.amp * dt
			q.p += q.v * dt
			if q.drag > 0.0:
				q.v *= maxf(0.0, 1.0 - q.drag * dt)
			q.z += q.vz * dt if q.g <= 0.0 else 0.0
		i -= 1


## Aterriza una particula con gravedad: se queda plana en la capa de suelo o se desvanece.
func _land(q: P, layer: Layer, idx: int) -> void:
	layer.ps[idx] = layer.ps[layer.ps.size() - 1]
	layer.ps.pop_back()
	if _ground == null or not is_instance_valid(_ground) or randf() > q.stain \
			or _ground.ps.size() > 160:
		return
	q.g = 0.0
	q.v = Vector2.ZERO
	q.vz = 0.0
	q.age = 0.0
	q.life = q.stain_life
	q.hold = q.stain_life * 0.4
	q.drag = 0.0
	q.kind = K.SQUARE if q.kind != K.CASING else K.CASING
	_ground.ps.append(q)


func _pop(q: P) -> void:
	for i in 3:
		var s := P.new()
		s.p = q.p
		s.z = q.z
		s.v = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(14.0, 30.0)
		s.col = Color(q.col, 0.8)
		s.life = 0.22
		s.drag = 3.0
		_add(s, false)


# ------------------------------------------------------------------ sala
func _set_room(room: Node) -> void:
	_room = room
	_ground = null
	_puddles.clear()
	_room_time = 0.0
	_amb_count = 0
	_air.ps.clear()
	_glow.ps.clear()
	_bright.ps.clear()
	_acts.clear()
	if room == null or not is_instance_valid(room):
		return
	var rm := get_node("/root/RunManager")
	_kingdom = rm.floor_data().kingdom
	var used: Rect2i = room.floor_tilemap.get_used_rect()
	_rect = Rect2(room.global_position + Vector2(used.position) * 64.0, Vector2(used.size) * 64.0)
	_prev_cleared = room.cleared
	var fl: int = rm.current_floor
	if fl != _prev_floor:
		_prev_floor = fl
		_prev_lib = rm.is_liberated(fl)
	_setup_wait = 3  # Main termina de montar calcomanias y decoracion tras _enter_room
	_prefill_ambient()


func _finish_room_setup() -> void:
	if _room == null or not is_instance_valid(_room):
		return
	_ground = _room.get_node_or_null("FxGround") as Layer
	if _ground == null:
		_ground = Layer.new()
		_ground.name = "FxGround"
		_ground.top_level = true  # coordenadas de mundo, da igual donde este la sala
		_room.add_child(_ground)
		var dec := _room.get_node_or_null("Decals")
		var after: Node = dec if dec else _room.floor_tilemap
		_room.move_child(_ground, after.get_index() + 1)
		Censor.apply(_room, _ground)
	_collect_puddles()


func _collect_puddles() -> void:
	_puddles.clear()
	var dec := _room.get_node_or_null("Decals")
	if dec == null:
		return
	for c in dec.get_children():
		var s := c as Sprite2D
		if s == null or s.texture == null:
			continue
		var path := s.texture.resource_path.get_file()
		if not path.begins_with("puddle_") or path.ends_with("_a.png") or path.ends_with("_b.png"):
			continue
		var parts := path.get_basename().split("_")
		if parts.size() < 3:
			continue
		# Elipse del charco (sin leer pixeles: en la web la textura no se puede leer de
		# vuelta y antes la deteccion fallaba entera, sin una sola huella).
		var half := Vector2(s.texture.get_size()) * 0.5 * s.scale.abs() * 0.85
		_puddles.append({"pos": s.global_position, "kind": parts[1], "half": half, "col": _wet_color(parts[1])})
	# Parches de barro, arena o alquitran pintados en el suelo (RoomDecals los anota).
	for z in _room.get_meta("wet_zones", []):
		_puddles.append({"pos": _room.global_position + z.center, "kind": z.kind,
			"half": Vector2(z.rx, z.ry) * 0.9, "col": _wet_color(z.kind)})


## Devuelve el charco que cubre el punto (o {}).
func _puddle_at(pt: Vector2) -> Dictionary:
	for pd in _puddles:
		var h: Vector2 = pd.half
		var d: Vector2 = pt - pd.pos
		if (d.x * d.x) / (h.x * h.x) + (d.y * d.y) / (h.y * h.y) <= 1.0:
			return pd
	return {}


## Color de la huella: una huella mojada se lee mas oscura y saturada que el suelo
## (con el color del liquido tal cual, barro sobre tierra no se veia).
func _wet_color(kind: String) -> Color:
	match kind:
		"water":
			return Color(0.06, 0.1, 0.16)  # suelo mojado: oscurece, no tine
		"arena":
			return Color(0.42, 0.33, 0.18)
		"mud", "tinta", "aceite":
			return LIQUID.get(kind, Color.GRAY).darkened(0.45)
	var c: Color = LIQUID.get(kind, Color.GRAY)
	return Color.from_hsv(c.h, minf(1.0, c.s * 1.4), c.v * 0.8)


## Charco que no daña (Espinilla Reventona al reventar): mancha de crema en el suelo y huellas
## al pisarlo. Se borra al cambiar de sala igual que los demas charcos detectados.
func add_puddle(pos: Vector2, radius: float) -> void:
	if _ground == null or not is_instance_valid(_ground):
		return
	_add_decal(_splat_tex[randi() % 3], pos, Color(1.0, 0.8, 0.84, 0.95), 14.0, 30.0, randf() < 0.5, radius / 11.0)
	_puddles.append({"pos": pos, "kind": "baba", "half": Vector2(radius, radius * 0.7), "col": _wet_color("baba")})


# ------------------------------------------------------------------ eventos de combate
func _watch_events() -> void:
	# sala liberada: un destello por la sala
	var cl: bool = _room.cleared
	if cl and not _prev_cleared and _room_time > 0.8:
		_burst_room_cleared()
	_prev_cleared = cl
	# region liberada (jefe del piso derrotado)
	var rm := get_node("/root/RunManager")
	var lib: bool = rm.is_liberated(rm.current_floor)
	if lib and not _prev_lib and rm.current_floor == _prev_floor:
		_burst_region_liberated()
	_prev_lib = lib


func _on_node_added(n: Node) -> void:
	if n is PlayerBullet or n is ProjectileEnemy:
		n.tree_exiting.connect(_on_bullet_exit.bind(n))


## Una bala que desaparece lejos de todo cuerpo (y sin haber agotado su vida) choco con un
## muro u obstaculo: chispas. Si se fue contra un enemigo o el jugador no hace nada aqui.
func _on_bullet_exit(b: Node2D) -> void:
	if not is_instance_valid(b) or _room == null or not is_instance_valid(_room):
		return
	var pos := b.global_position
	if not _rect.grow(90.0).has_point(pos):
		return
	var hostile := b is ProjectileEnemy
	if hostile:
		if b._timer >= b.lifetime:
			return
		if _player and is_instance_valid(_player) and _player.global_position.distance_to(pos) < 26.0:
			return
	else:
		if b._t >= b.lifetime:
			return
		for e in get_tree().get_nodes_in_group("enemy"):
			if e is Node2D and e.global_position.distance_to(pos) < 30.0:
				return
	var dir := Vector2.RIGHT.rotated(b.global_rotation)
	_impact(pos, dir, hostile)


func _impact(pos: Vector2, dir: Vector2, hostile: bool) -> void:
	var c1 := Color(0.78, 1.0, 0.45) if hostile else Color(1.0, 0.86, 0.4)
	var c2 := Color(0.45, 0.9, 0.3) if hostile else Color(1.0, 0.5, 0.18)
	var fl := P.new()  # destello del choque
	fl.p = pos
	fl.z = 6.0
	fl.kind = K.SPARKLE
	fl.sz = Vector2(2, 1)
	fl.col = c1
	fl.exempt = true
	fl.life = 0.14
	_add(fl, true)
	for i in randi_range(7, 10):
		var q := P.new()
		q.p = pos
		q.z = 6.0
		q.exempt = true
		q.v = (-dir).rotated(randf_range(-1.3, 1.3)) * randf_range(70.0, 220.0)
		q.drag = 3.5
		q.life = randf_range(0.16, 0.34)
		q.col = c1 if randf() < 0.5 else c2
		q.kind = K.SPARK
		_add(q, true)
	for i in 2:  # esquirlas de pared que caen
		var s := P.new()
		s.p = pos
		s.z = 6.0
		s.v = (-dir).rotated(randf_range(-1.0, 1.0)) * randf_range(20.0, 60.0)
		s.vz = randf_range(20.0, 60.0)
		s.g = 300.0
		s.life = 1.0
		s.col = Color(0.55, 0.5, 0.5)
		s.sz = Vector2(1, 1)
		_add(s)
	var d := P.new()
	d.p = pos
	d.z = 6.0
	d.v = -dir * 10.0
	d.life = 0.4
	d.col = Color(0.75, 0.72, 0.7, 0.3)
	d.kind = K.PUFF
	d.sz = Vector2(1.5, 1)
	d.grow = 7.0
	_add(d)


func _on_enemy_damaged(enemy: Node, amount: float, source: Node) -> void:
	if not (enemy is Node2D) or _room == null:
		return
	var pos: Vector2 = enemy.global_position + Vector2(0, -6)
	var dir := Vector2.from_angle(randf() * TAU)
	if source is Node2D and source != enemy:
		dir = (pos - source.global_position).normalized()
	var dying: bool = enemy.get("current_health") != null and float(enemy.get("current_health")) <= 0.0
	var n := int(clampf(3.0 + amount / 5.0, 3.0, 8.0))
	if dying:
		n = 14
	for i in n:
		var q := P.new()
		q.p = pos
		q.z = randf_range(4.0, 12.0)
		var ang := randf_range(-0.9, 0.9) if not dying else randf_range(-PI, PI)
		q.v = dir.rotated(ang) * randf_range(50.0, 150.0)
		q.vz = randf_range(30.0, 110.0)
		q.g = 420.0
		q.bounce = 0
		q.col = PINKS[randi() % PINKS.size()]
		var s := 2.0 if randf() < 0.55 else 1.0
		q.sz = Vector2(s, s)
		q.exempt = true
		q.life = 1.5
		q.stain = 0.5
		q.stain_life = 2.8
		_add(q)


func _on_enemy_killed(enemy: Node, _killer: Node) -> void:
	if not (enemy is Node2D) or _ground == null or not is_instance_valid(_ground):
		return
	var foot := _foot_of(enemy)
	var pos: Vector2 = enemy.global_position + Vector2(0, foot * 0.6)
	_add_decal(_splat_tex[randi() % 3], pos, Color(1.0, 0.45, 0.7, 0.8), 2.0, 8.0, randf() < 0.5, 1.0)
	for i in randi_range(4, 6):
		var q := P.new()
		q.p = pos + Vector2.from_angle(randf() * TAU) * randf_range(5.0, 20.0)
		q.col = PINKS[randi() % PINKS.size()]
		var s := randf_range(1.0, 3.0)
		q.sz = Vector2(s, maxf(1.0, s - 1.0))
		q.life = randf_range(5.0, 8.0)
		q.hold = 2.0
		_ground.ps.append(q)
	# un puf rosa al reventar
	for i in 4:
		var d := P.new()
		d.p = pos
		d.z = 8.0
		d.v = Vector2.from_angle(randf() * TAU) * randf_range(10.0, 40.0)
		d.life = 0.5
		d.col = Color(1.0, 0.6, 0.8, 0.35)
		d.kind = K.PUFF
		d.sz = Vector2(3, 3)
		d.grow = 10.0
		d.drag = 2.0
		_add(d)


# ------------------------------------------------------------------ decals de suelo (huellas, restos)
func _add_decal(tex: Texture2D, pos: Vector2, col: Color, hold: float, life: float, flip: bool, scl: float, rot := 0.0) -> void:
	if _ground == null or not is_instance_valid(_ground):
		return
	if _ground.decals.size() >= MAX_DECALS:
		var old: Dictionary = _ground.decals.pop_front()
		old.spr.queue_free()
	var s := Sprite2D.new()
	s.texture = tex
	s.use_parent_material = true
	s.flip_h = flip
	s.rotation = rot
	s.scale = Vector2.ONE * scl
	s.modulate = col
	_ground.add_child(s)
	s.global_position = pos.round()
	_ground.decals.append({"spr": s, "age": 0.0, "life": life, "hold": hold, "base": col.a})


func _step_decals(dt: float) -> void:
	var ds := _ground.decals
	var i := ds.size() - 1
	while i >= 0:
		var d: Dictionary = ds[i]
		d.age += dt
		if d.age >= d.life:
			d.spr.queue_free()
			ds.remove_at(i)
		elif d.age > d.hold:
			var m: Color = d.spr.modulate
			m.a = d.base * (1.0 - (d.age - d.hold) / (d.life - d.hold))
			d.spr.modulate = m
		i -= 1


# ------------------------------------------------------------------ actores: polvo, nube de dash, huellas
func _foot_of(a: Node2D) -> float:
	var sh := a.get_node_or_null("ContactShadow") as Node2D
	return (sh.position.y + 2.0) if sh else 12.0


func _watch_actors(dt: float) -> void:
	var seen := {}
	_track(_player, true, dt, seen)
	var pp := _player.global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is EnemyBoss or not (e is Node2D) or e.global_position.distance_to(pp) > 520.0:
			continue
		_track(e, false, dt, seen)
	for id in _acts.keys():
		if not seen.has(id):
			_acts.erase(id)


func _track(a: Node2D, is_player: bool, dt: float, seen: Dictionary) -> void:
	var id := a.get_instance_id()
	seen[id] = true
	var pos := a.global_position
	if not _acts.has(id):
		_acts[id] = {"last": pos, "dust": 0.0, "step": 0.0, "wet": 0.0, "col": Color.WHITE, "side": 1.0}
		return
	var st: Dictionary = _acts[id]
	var move: Vector2 = pos - st.last
	st.last = pos
	var dist := move.length()
	if dist > 80.0 or dt <= 0.0:  # teletransporte (cambio de sala)
		return
	var foot_pos := pos + Vector2(0, _foot_of(a))
	var dashing: bool = is_player and bool(a.get("is_dashing"))
	if is_player:
		if dashing and not _was_dashing:
			_dash_cloud(foot_pos, move.normalized() if dist > 0.01 else Vector2.RIGHT)
		_was_dashing = dashing
	if dist < 0.4:
		return

	# polvo al caminar
	st.dust += dist
	var dust_step := 10.0 if dashing else (24.0 if is_player else 46.0)
	if st.dust >= dust_step:
		st.dust = 0.0
		_dust_puff(foot_pos, -move.normalized(), is_player, dashing)

	# huellas de liquido
	var pd := _puddle_at(foot_pos)
	if not pd.is_empty():
		st.wet = WET_STEPS
		st.col = pd.col
		st.kind = pd.kind
	st.step += dist
	var every := STEP_PLAYER if is_player else STEP_ENEMY
	if st.step >= every:
		st.step = 0.0
		if st.wet > 0.0:
			var frac: float = st.wet / WET_STEPS
			st.wet -= 1.0
			st.side = -st.side
			var dirn := move.normalized()
			var perp: Vector2 = dirn.orthogonal() * 3.5 * st.side
			var col: Color = st.col
			var strong := 0.55 if st.kind == "water" else 0.95  # el agua solo oscurece el suelo
			col.a = strong * (0.35 + 0.65 * frac) if pd.is_empty() else strong
			if frac <= 0.0:
				return
			var scl := 1.3 if is_player else 1.0
			_add_decal(_foot_tex, foot_pos + perp, col, FOOT_LIFE * 0.35, FOOT_LIFE,
				st.side < 0.0, scl, dirn.angle() + PI * 0.5)


func _dust_puff(pos: Vector2, back: Vector2, strong: bool, dashing: bool) -> void:
	var q := P.new()
	q.p = pos + Vector2(randf_range(-2, 2), 0)
	q.z = 1.0
	q.v = back * randf_range(6.0, 16.0) + Vector2(0, randf_range(-6.0, 0.0))
	q.vz = randf_range(6.0, 14.0)
	var c: Color = DUST.get(_kingdom, DUST.neutral)
	q.col = Color(c, 0.36 if strong else 0.2)
	q.kind = K.PUFF
	q.sz = Vector2(1.5 if not dashing else 2.5, 1)
	q.grow = 5.0 if strong else 3.5
	q.life = 0.5 if strong else 0.4
	q.drag = 2.0
	_add(q)


func _dash_cloud(pos: Vector2, dir: Vector2) -> void:
	var c: Color = DUST.get(_kingdom, DUST.neutral)
	for i in 8:
		var q := P.new()
		q.p = pos + Vector2(randf_range(-4, 4), randf_range(-2, 2))
		q.z = randf_range(1.0, 5.0)
		q.v = (-dir).rotated(randf_range(-1.1, 1.1)) * randf_range(20.0, 70.0)
		q.vz = randf_range(4.0, 14.0)
		q.col = Color(c, 0.4)
		q.kind = K.PUFF
		q.sz = Vector2(3.0, 1)
		q.grow = 10.0
		q.life = randf_range(0.45, 0.75)
		q.drag = 3.0
		_add(q)


# ------------------------------------------------------------------ disparos: casquillos y gotitas
func _watch_shots() -> void:
	var ms: int = int(_player.get("_last_shot_ms"))
	if ms == _last_shot:
		return
	_last_shot = ms
	var w = _player.get("current_weapon")
	if w == null:
		return
	var id: String = String(w.id)
	var aim: Vector2 = _player.get("_aim") if _player.get("_aim") != null else Vector2.RIGHT
	var pivot := _player.get_node_or_null("WeaponPivot") as Node2D
	var wp: Vector2 = pivot.global_position if pivot else _player.global_position
	match id:
		"satisfyer":
			return
		"launcher_condom":
			_droplets(wp + aim * 16.0, aim)
		"shotgun_pelvic":
			_casing(wp, aim, Color(0.85, 0.2, 0.2), Vector2(3, 2))
		"pistol_golden":
			_casing(wp, aim, Color(1.0, 0.86, 0.3), Vector2(2, 1))
		_:
			_casing(wp, aim, Color(0.95, 0.72, 0.28), Vector2(2, 1))


func _casing(wp: Vector2, aim: Vector2, col: Color, size_: Vector2) -> void:
	var q := P.new()
	q.p = wp + Vector2(0, 8) + aim * 4.0
	q.z = 8.0
	var side := aim.orthogonal() * (1.0 if randf() < 0.85 else -1.0)
	if aim.x < 0.0:
		side = -side
	q.v = (side + aim * 0.2).rotated(randf_range(-0.4, 0.4)) * randf_range(45.0, 95.0)
	q.vz = randf_range(70.0, 130.0)
	q.g = 520.0
	q.bounce = 1
	q.col = col
	q.sz = size_
	q.kind = K.CASING
	q.exempt = true
	q.life = 2.0
	q.stain = 1.0
	q.stain_life = 3.5
	_add(q)


func _droplets(pos: Vector2, aim: Vector2) -> void:
	for i in 6:
		var q := P.new()
		q.p = pos
		q.z = 8.0
		q.v = aim.rotated(randf_range(-0.55, 0.55)) * randf_range(40.0, 120.0)
		q.vz = randf_range(20.0, 70.0)
		q.g = 340.0
		q.col = Color(0.95, 0.95, 1.0, 0.85) if randf() < 0.6 else Color(0.75, 0.9, 1.0, 0.85)
		q.sz = Vector2(1, 1) if randf() < 0.5 else Vector2(2, 2)
		q.exempt = true
		q.life = 1.0
		q.stain = 0.4
		q.stain_life = 1.6
		_add(q)


# ------------------------------------------------------------------ ambiente por reino
func _amb_target() -> int:
	return int(clampf(_rect.get_area() / 14000.0, 8.0, 26.0))


func _prefill_ambient() -> void:
	if _room == null:
		return
	for i in _amb_target():
		_spawn_ambient(randf())


func _ambient(dt: float) -> void:
	_amb_t -= dt
	if _amb_t > 0.0 or _amb_count >= _amb_target():
		return
	_amb_t = 0.35
	_spawn_ambient(0.0)


func _spawn_ambient(age_frac: float) -> void:
	var q := P.new()
	q.amb = true
	q.env = true
	q.phase = randf() * TAU
	q.freq = randf_range(1.0, 2.5)
	var glow := false
	var inset := 40.0
	var x := randf_range(_rect.position.x + inset, _rect.end.x - inset)
	var y := randf_range(_rect.position.y + inset, _rect.end.y - inset)
	q.p = Vector2(x, y)
	match _kingdom:
		"neutral":  # esporas flotando hacia arriba
			q.kind = K.SQUARE
			q.sz = Vector2(1, 1) if randf() < 0.6 else Vector2(2, 2)
			q.col = Color(0.78, 1.0, 0.55, 0.75) if randf() < 0.6 else Color(1.0, 0.95, 0.5, 0.7)
			q.v = Vector2(randf_range(-4.0, 4.0), randf_range(-14.0, -5.0))
			q.amp = 8.0
			q.life = randf_range(6.0, 9.0)
			glow = true
		"vulva":  # petalos cayendo en diagonal
			q.kind = K.PETAL
			q.col = Color(1.0, 0.55, 0.75, 0.9) if randf() < 0.65 else Color(1.0, 0.8, 0.88, 0.9)
			q.v = Vector2(randf_range(4.0, 14.0), randf_range(14.0, 26.0))
			q.amp = 12.0
			q.life = randf_range(7.0, 10.0)
		"mixto":  # brasas que suben y cenizas
			if randf() < 0.45:
				q.kind = K.SQUARE
				q.sz = Vector2(1, 1)
				q.col = Color(1.0, 0.62, 0.2, 0.9)
				q.v = Vector2(randf_range(-5.0, 5.0), randf_range(-24.0, -10.0))
				glow = true
			else:
				q.kind = K.SQUARE
				q.sz = Vector2(2, 1)
				q.col = Color(0.5, 0.48, 0.46, 0.7)
				q.v = Vector2(randf_range(-6.0, 6.0), randf_range(-12.0, -4.0))
			q.amp = 6.0
			q.life = randf_range(4.5, 7.0)
		"prostata":  # motas de polvo de sala de espera, casi quietas
			q.kind = K.SQUARE
			q.sz = Vector2(1, 1)
			q.col = Color(0.92, 0.84, 0.76, 0.55)
			q.v = Vector2(randf_range(-2.0, 2.0), randf_range(-4.0, 1.0))
			q.amp = 5.0
			q.life = randf_range(8.0, 12.0)
		"pene":  # destellos de rocio azul que titilan
			q.kind = K.SPARKLE
			q.sz = Vector2(1, 1)
			q.col = Color(0.6, 0.88, 1.0, 0.9)
			q.v = Vector2(randf_range(-5.0, 5.0), randf_range(-6.0, 3.0))
			q.amp = 6.0
			q.life = randf_range(4.0, 7.0)
			glow = true
		_:  # censura: confeti gris que cae
			q.kind = K.CONFETTI
			var l := randf_range(0.5, 0.85)
			q.col = Color(l, l, l * 1.04, 0.95)
			q.exempt = true
			q.v = Vector2(randf_range(-6.0, 6.0), randf_range(14.0, 26.0))
			q.amp = 10.0
			q.life = randf_range(6.0, 9.0)
	q.age = age_frac * q.life * 0.8
	if _count() < MAX_PARTS:
		if glow:
			_glow.ps.append(q)
		elif LightKit.dark:
			q.col.a *= 0.7  # a oscuras no se apagan con las luces: se ven, pero tenues
			_bright.ps.append(q)
		else:
			_air.ps.append(q)
	else:
		_amb_count -= 1
	_amb_count += 1


# ------------------------------------------------------------------ antro: burbujas y vapor
func _antro(dt: float) -> void:
	if _room.room_type != Room.RoomType.INTOXICATION:
		return
	var inset := 70.0
	_antro_t -= dt
	if _antro_t <= 0.0:
		_antro_t = randf_range(0.12, 0.3)
		var q := P.new()
		q.p = Vector2(randf_range(_rect.position.x + inset, _rect.end.x - inset),
			randf_range(_rect.position.y + inset, _rect.end.y - inset))
		q.z = 0.0
		q.vz = randf_range(14.0, 24.0)
		q.amp = 5.0
		q.freq = randf_range(3.0, 5.0)
		q.phase = randf() * TAU
		q.kind = K.BUBBLE
		q.sz = Vector2(randf_range(2.5, 4.5), 0)
		q.grow = 0.6
		q.col = Color(0.95, 0.62, 0.12, 1.0) if randf() < 0.55 else Color(0.3, 0.78, 0.3, 1.0)
		q.life = randf_range(2.0, 3.2)
		q.pop = true
		_add(q)
	_vapor_t -= dt
	if _vapor_t <= 0.0:
		_vapor_t = randf_range(0.35, 0.7)
		var v := P.new()
		v.p = Vector2(randf_range(_rect.position.x + inset, _rect.end.x - inset),
			randf_range(_rect.position.y + inset, _rect.end.y - inset))
		v.z = 2.0
		v.vz = randf_range(6.0, 12.0)
		v.v = Vector2(randf_range(-4.0, 4.0), 0)
		v.kind = K.PUFF
		v.sz = Vector2(5.0, 0)
		v.grow = 7.0
		v.col = Color(0.9, 0.98, 0.85, 0.24)
		v.env = true
		v.life = randf_range(2.2, 3.4)
		_add(v)


# ------------------------------------------------------------------ liberar sala / region
func _sparkle(pos: Vector2, delay: float, big := false) -> void:
	var q := P.new()
	q.p = pos
	q.z = randf_range(0.0, 8.0)
	q.v = Vector2(randf_range(-8.0, 8.0), randf_range(-34.0, -12.0))
	q.kind = K.SPARKLE
	q.sz = Vector2(2 if big else 1, 1)
	q.col = GLITTER[randi() % GLITTER.size()]
	q.exempt = true
	q.phase = randf() * TAU
	q.age = -delay
	q.life = randf_range(0.9, 1.6)
	q.hold = 0.4
	_add_bright(q)


func _burst_room_cleared() -> void:
	var c := _rect.get_center()
	var maxd := maxf(_rect.size.length() * 0.5, 1.0)
	# oleada de brillos que sigue al color: del centro hacia los muros en ~1.2 s
	for i in 70:
		var pos := Vector2(randf_range(_rect.position.x + 30.0, _rect.end.x - 30.0),
			randf_range(_rect.position.y + 30.0, _rect.end.y - 30.0))
		_sparkle(pos, pos.distance_to(c) / maxd * 1.2, randf() < 0.2)
	# anillo de chispas que sale del centro
	for i in 28:
		var q := P.new()
		q.p = c
		q.z = 4.0
		q.v = Vector2.from_angle(TAU * i / 28.0 + randf() * 0.1) * randf_range(200.0, 300.0)
		q.drag = 2.2
		q.kind = K.SPARK
		q.col = GLITTER[randi() % GLITTER.size()]
		q.exempt = true
		q.life = 0.6
		_add_bright(q)


func _burst_region_liberated() -> void:
	var c := _rect.get_center()
	var maxd := maxf(_rect.size.length() * 0.5, 1.0)
	for w in 3:  # tres ondas de anillo
		for i in 36:
			var q := P.new()
			q.p = c
			q.z = 4.0
			q.age = -w * 0.35
			q.v = Vector2.from_angle(TAU * i / 36.0 + w * 0.1) * (230.0 + w * 60.0)
			q.drag = 1.8
			q.kind = K.SPARK
			q.col = GLITTER[(i + w) % GLITTER.size()]
			q.exempt = true
			q.life = 0.9
			_add_bright(q)
	for i in 110:
		var pos := Vector2(randf_range(_rect.position.x + 20.0, _rect.end.x - 20.0),
			randf_range(_rect.position.y + 20.0, _rect.end.y - 20.0))
		_sparkle(pos, pos.distance_to(c) / maxd * 1.6, randf() < 0.35)
	# lluvia de confeti de colores desde arriba
	for i in 70:
		var q := P.new()
		q.p = Vector2(randf_range(_rect.position.x, _rect.end.x), _rect.position.y - 10.0)
		q.z = 0.0
		q.v = Vector2(randf_range(-14.0, 14.0), randf_range(50.0, 110.0))
		q.amp = 14.0
		q.freq = randf_range(2.0, 4.0)
		q.phase = randf() * TAU
		q.kind = K.CONFETTI
		q.col = GLITTER[randi() % (GLITTER.size() - 1)]
		q.exempt = true
		q.age = -randf() * 1.8
		q.life = randf_range(2.6, 4.0)
		q.hold = 1.8
		_add_bright(q)
