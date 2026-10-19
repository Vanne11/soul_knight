class_name CorridorPest
extends CharacterBody2D

## BICHO INCOMODO de los pasillos entre reinos (guino a los encuentros aleatorios de Pokemon): aparece de
## vez en cuando al recorrer un pasillo (corridor_encounter.gd). Mucha vida (se cura sola y recibe solo una
## parte del dano) y poquisimo dano: lo suyo es MOLESTAR, cada uno a su manera. Se escapa corriendo hasta
## el final del pasillo (te sigue un trecho) o se vence para una recompensa chica de monedas.
## Dibujo por codigo (sin arte nuevo). Textos: locale/pasillos.csv (PAS_ENC_<ID>_*); codice: lore pest_<id>.
##
## Maneras de molestar ("kind"): empujar (tio, cunado), tapar la vista (spam, influencer), frenar (vendedor,
## chicle), pegarse (ex, chicle), aparecer por detras (notificacion), zumbar y picar (mosquito),
## congelar un segundo (captcha).

const TYPES := ["tio", "spam", "vendedor", "mosquito", "cunado", "notificacion", "ex", "influencer", "chicle", "captcha"]
const DATA := {
	"tio": {"speed": 150.0, "col": Color("c9915a")},
	"spam": {"speed": 125.0, "col": Color("5fc27a")},
	"vendedor": {"speed": 200.0, "col": Color("4a78c8")},
	"mosquito": {"speed": 235.0, "col": Color("6b5a78")},
	"cunado": {"speed": 170.0, "col": Color("d6a63c")},
	"notificacion": {"speed": 95.0, "col": Color("e0485a")},
	"ex": {"speed": 0.0, "col": Color("8a8ad8")},
	"influencer": {"speed": 140.0, "col": Color("f08cc0")},
	"chicle": {"speed": 110.0, "col": Color("f2a0c0")},
	"captcha": {"speed": 135.0, "col": Color("e8e8e8")},
}
const MAX_HEALTH := 650.0
const DAMAGE_TAKEN := 0.35     # fraccion del dano que le entra
const REGEN := 12.0            # vida por segundo
const CONTACT := 30.0
## Los que sueltan burbujas de texto que estorban en el pasillo (obstaculos fisicos que se revientan o se esquivan).
const BUBBLERS := ["spam", "tio", "cunado", "notificacion", "ex"]
const MAX_BUBBLES := 7

var type := "tio"
var room: Room
var player: Node2D
var cl := PackedVector2Array()
var current_health := MAX_HEALTH
var enemy_name := ""

var _t := 0.0
var _say_t := 4.0
var _hit_cd := 0.0
var _ability_t := 2.0
var _dead := false
var _attached := false
var _flash := 0.0
var _layer: CanvasLayer
var _mist: Control
var _stickers: Array = []
var _captcha_t := 0.0
var _face := 1.0
var _spr: AnimatedSprite2D = null   # arte de Gemini (assets/sprites/enemies/pasillos/<tipo>/); sin el, se dibuja por codigo
var _anim_t := 0.0
## "chase" (te persigue) o "guard" (se planta delante, entre tu y la salida, y copia tu posicion lateral).
var mode := "chase"
var _bub_t := 1.2
var _gone := false


static func create(type_: String, room_: Room, player_: Node2D) -> CorridorPest:
	var p := CorridorPest.new()
	p.type = type_
	p.room = room_
	p.player = player_
	p.cl = room_.get_meta("corridor_cl")
	p.enemy_name = tr_name(type_)
	return p


static func tr_name(type_: String) -> String:
	return TranslationServer.translate("PAS_ENC_%s_NAME" % type_.to_upper())


func _ready() -> void:
	add_to_group("enemy")
	set_meta("corridor_pest", true)
	collision_layer = 2
	collision_mask = 1  # solo muros (no se atascan entre ellos ni con el heroe)
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 11.0
	add_child(shape)
	var hurt := Area2D.new()
	hurt.collision_layer = 0
	hurt.collision_mask = 8
	var hs := CollisionShape2D.new()
	hs.shape = CircleShape2D.new()
	hs.shape.radius = 19.0
	hurt.add_child(hs)
	hurt.area_entered.connect(_on_hurt)
	add_child(hurt)
	_layer = CanvasLayer.new()
	_layer.layer = 35
	add_child(_layer)
	z_index = 3
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := "res://assets/sprites/enemies/pasillos/%s/%s_sprite_frames.tres" % [type, type]
	if ResourceLoader.exists(frames):
		_spr = AnimatedSprite2D.new()
		_spr.sprite_frames = load(frames)
		_spr.offset = Vector2(0, -27)
		_spr.use_parent_material = true
		add_child(_spr)
		_spr.play("idle")
	elif type == "mosquito":
		scale = Vector2(0.7, 0.7)
	_say()


func _exit_tree() -> void:
	if is_instance_valid(player) and type == "captcha":
		player.set_physics_process(true)


func _on_hurt(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		var dmg := float(area.damage) if "damage" in area else 10.0
		take_damage(dmg, area.get_parent(), Vector2.ZERO)


## Contrato con las armas y habilidades (se llaman con has_method).
func take_damage(amount: float, _source: Node = null, _kb: Vector2 = Vector2.ZERO) -> float:
	if _dead:
		return 0.0
	var real := maxf(amount * DAMAGE_TAKEN, 0.5)
	current_health -= real
	_flash = 0.12
	get_node("/root/GlobalEvents").show_damage_number.emit(global_position + Vector2(0, -26), real, false)
	if current_health <= 0.0:
		_die()
	return real


func scare(_s: float, _from: Vector2) -> void:
	pass


func stun(_s: float) -> void:
	pass


func reveal(_s: float) -> void:
	pass


func heal(_a: float) -> void:
	pass


func _die() -> void:
	_dead = true
	set_deferred("collision_layer", 0)
	if _spr != null:
		_spr.flip_h = _face < 0.0
		_spr.play("death")
	var main := get_tree().get_first_node_in_group("main")
	if main != null and room != null and is_instance_valid(room):
		var n := RNG.randi_range(4, 7)
		RoomUtil.coins(main, room, n, room.to_local(global_position))
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -34), tr("PAS_ENC_DEFEATED"), Color("ffd75a"))
	Sound.play("room_clear")
	_clear_overlays()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _clear_overlays() -> void:
	for s in _stickers:
		if is_instance_valid(s):
			s.queue_free()
	_stickers.clear()
	if _mist != null and is_instance_valid(_mist):
		_mist.queue_free()
	if is_instance_valid(player) and type == "captcha":
		player.set_physics_process(true)


# ------------------------------------------------------------------ movimiento
func _nearest(local: Vector2) -> int:
	var best := 0
	var bd := INF
	for i in cl.size():
		var d := cl[i].distance_squared_to(local)
		if d < bd:
			bd = d
			best = i
	return best


## Rumbo hacia el heroe siguiendo el camino del pasillo (las curvas y los ramales no lo atascan).
func _chase_dir() -> Vector2:
	var pp := player.global_position
	var i := _nearest(room.to_local(global_position))
	var j := _nearest(room.to_local(pp))
	if absi(i - j) <= 2 or _line_clear(pp):
		return (pp - global_position).normalized()
	var k := clampi(i + signi(j - i), 0, cl.size() - 1)
	return (room.to_global(cl[k]) - global_position).normalized()


## Rumbo del bicho que BLOQUEA: va al punto del camino unas baldosas por delante del heroe y copia su
## posicion lateral para taparle el paso.
func _guard_dir(dist: float) -> Vector2:
	var pl := room.to_local(player.global_position)
	var j := _nearest(pl)
	var k := mini(j + 4, cl.size() - 1)
	var tang := (cl[mini(k + 1, cl.size() - 1)] - cl[maxi(k - 1, 0)]).normalized()
	var perp := tang.orthogonal()
	var lat := clampf((pl - cl[k]).dot(perp), -52.0, 52.0)
	var goal := room.to_global(cl[k] + perp * lat)
	var to := goal - global_position
	if to.length() < 6.0:
		return Vector2.ZERO
	return to.normalized()


## Burbuja de texto (obstaculo fisico) por delante del heroe.
func _drop_bubble() -> void:
	var pool: Array = get_tree().get_nodes_in_group("chat_bubble")
	if pool.size() >= MAX_BUBBLES:
		return
	var j := _nearest(room.to_local(player.global_position))
	var k := mini(j + RNG.randi_range(3, 6), cl.size() - 3)
	var tang := (cl[mini(k + 1, cl.size() - 1)] - cl[maxi(k - 1, 0)]).normalized()
	var spot := cl[k] + tang.orthogonal() * RNG.randf_range(-38.0, 38.0)
	var b := ChatBubble.create(tr("PAS_ENC_%s_SAY%d" % [type.to_upper(), RNG.randi_range(0, 2)]), DATA[type].col, type == "spam" or type == "notificacion")
	room.add_child(b)
	b.position = spot


## Se retira (fin del tiempo del encuentro o del pasillo).
func retreat() -> void:
	if _gone or _dead:
		return
	_gone = true
	_clear_overlays()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _line_clear(to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, to, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _physics_process(delta: float) -> void:
	if _dead or _gone or not is_instance_valid(player) or room == null or not is_instance_valid(room):
		return
	_t += delta
	_hit_cd -= delta
	_flash = maxf(_flash - delta, 0.0)
	current_health = minf(current_health + REGEN * delta, MAX_HEALTH)
	var pp := player.global_position
	var dist := global_position.distance_to(pp)
	var dir := _chase_dir()
	var speed: float = DATA[type].speed
	if mode == "guard":
		dir = _guard_dir(dist)
		speed *= 1.25
	var vel := dir * speed
	match type:
		"mosquito":
			vel += dir.orthogonal() * sin(_t * 9.0) * 130.0
		"ex":
			# se pega: mantiene ~50 px y va a la velocidad del heroe (no se le puede sacar)
			var want := 50.0
			var pspeed: float = float(player.get("move_speed")) if player.get("move_speed") != null else 250.0
			vel = dir * clampf((dist - want) * 6.0, 0.0, pspeed * 1.0)
			if dist < 120.0:
				player.set_terrain_slow(0.88)
		"vendedor":
			if dist < 90.0:
				player.set_terrain_slow(0.5)  # el folleto frena
		"chicle":
			if _attached:
				vel = Vector2.ZERO
				global_position = pp + Vector2(0, 12)
				player.set_terrain_slow(0.38)
				if bool(player.get("is_dashing")):  # un dash lo raspa
					_attached = false
					_hit_cd = 2.0
					get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -30), tr("PAS_ENC_CHICLE_FREE"), Color("f2a0c0"))
					global_position = pp + (dir * -1.0) * 40.0
		"notificacion":
			_ability_t -= delta
			if _ability_t <= 0.0:
				_ability_t = 3.2
				_behind()
		"spam":
			_ability_t -= delta
			if _ability_t <= 0.0:
				_ability_t = 0.85
				_sticker()
		"influencer":
			_mist_step(dist, delta)
		"captcha":
			_captcha_step(dist, delta)
	velocity = vel
	if absf(vel.x) > 4.0:
		_face = signf(vel.x)
	if _spr != null:
		_anim_t -= delta
		var want := "idle"
		if _flash > 0.0:
			want = "hurt"
		elif _anim_t > 0.0:
			want = "annoy"
		elif vel.length() > 25.0:
			want = "walk"
		if _spr.animation != want:
			_spr.play(want)
		_spr.flip_h = _face < 0.0
		_spr.modulate = Color(1.7, 1.4, 1.4) if _flash > 0.0 else Color.WHITE
	if not (type == "chicle" and _attached):
		move_and_slide()
	# te agarran y frenan (todos): estorban sin hacer dano
	if dist < 44.0 and not (type == "chicle" and _attached):
		player.set_terrain_slow(0.72)
	_bub_t -= delta
	if _bub_t <= 0.0 and type in BUBBLERS:
		_bub_t = 2.3
		_drop_bubble()
	# contacto: dano casi nulo y la molestia propia de cada uno
	if dist < CONTACT and _hit_cd <= 0.0:
		_touch(dir)
	_say_t -= delta
	if _say_t <= 0.0:
		_say_t = 4.2 + RNG.randf() * 1.5
		_say()
	queue_redraw()


func _touch(dir: Vector2) -> void:
	_anim_t = 0.6
	var stats := get_node("/root/PlayerStats")
	match type:
		"tio":
			_hit_cd = 2.0
			_push(dir, 70.0)
			stats.take_damage(1.0)
		"cunado":
			_hit_cd = 1.6
			_push(dir, 120.0)
			stats.take_damage(1.0)
		"mosquito":
			_hit_cd = 1.2
			_push(dir.rotated(0.6), 40.0)
			stats.take_damage(1.0)
		"chicle":
			if not _attached:
				_attached = true
				get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -30), tr("PAS_ENC_CHICLE_STUCK"), Color("f2a0c0"))
		_:
			_hit_cd = 2.2
			stats.take_damage(1.0)


func _push(dir: Vector2, px: float) -> void:
	if player.has_method("move_and_collide"):
		player.move_and_collide(dir * px)


## Notificacion Insistente: reaparece detras del heroe (ding-ding).
func _behind() -> void:
	var j := _nearest(room.to_local(player.global_position))
	var k := maxi(j - 3, 0)
	if k == j:
		k = mini(j + 3, cl.size() - 1)
	global_position = room.to_global(cl[k])
	Sound.play("pickup")
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -30), tr("PAS_ENC_NOTIFICACION_DING"), Color("ff8f8f"))


## Spam del Grupo Familiar: stickers y cadenas que tapan trozos de la pantalla un rato.
func _sticker() -> void:
	_stickers = _stickers.filter(func(s): return is_instance_valid(s))
	if _stickers.size() >= 7:
		return
	var vp := get_viewport().get_visible_rect().size
	var lab := Label.new()
	lab.text = tr("PAS_ENC_SPAM_STICKER_%d" % RNG.randi_range(0, 3))
	lab.add_theme_font_size_override("font_size", RNG.randi_range(26, 46))
	lab.add_theme_color_override("font_color", Color.from_hsv(RNG.randf(), 0.55, 1.0))
	lab.add_theme_color_override("font_outline_color", Color("1a1020"))
	lab.add_theme_constant_override("outline_size", 6)
	lab.position = Vector2(RNG.randf_range(0.0, vp.x - 260.0), RNG.randf_range(90.0, vp.y - 120.0))
	lab.rotation = RNG.randf_range(-0.3, 0.3)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(lab)
	_stickers.append(lab)
	var tw := lab.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(lab, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lab.queue_free)


## Influencer de Cremas: una niebla brillante (rosa y purpurina) tapa la vista mientras esta cerca.
func _mist_step(dist: float, delta: float) -> void:
	if _mist == null:
		_mist = Mist.new()
		_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_mist.set_anchors_preset(Control.PRESET_FULL_RECT)
		_layer.add_child(_mist)
	var target := 0.55 if dist < 240.0 else 0.0
	_mist.modulate.a = move_toward(_mist.modulate.a, target, delta * 0.8)


## Captcha: de vez en cuando exige quedarte quieto un segundo ("¿eres humano?").
func _captcha_step(dist: float, delta: float) -> void:
	if _captcha_t > 0.0:
		_captcha_t -= delta
		if _captcha_t <= 0.0:
			player.set_physics_process(true)
		return
	_ability_t -= delta
	if _ability_t <= 0.0 and dist < 280.0:
		_ability_t = 5.5
		_captcha_t = 1.0
		player.set_physics_process(false)
		if "velocity" in player:
			player.velocity = Vector2.ZERO
		var lab := Label.new()
		lab.text = "[ ]  %s" % tr("PAS_ENC_CAPTCHA_Q")
		lab.add_theme_font_size_override("font_size", 28)
		lab.add_theme_color_override("font_outline_color", Color("1a1020"))
		lab.add_theme_constant_override("outline_size", 8)
		lab.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 180.0, 150.0)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(lab)
		var tw := lab.create_tween()
		tw.tween_interval(0.55)
		tw.tween_callback(func(): lab.text = "[x]  %s" % tr("PAS_ENC_CAPTCHA_OK"))
		tw.tween_interval(0.5)
		tw.tween_callback(lab.queue_free)


func _say() -> void:
	if type in BUBBLERS:
		return  # esos hablan con burbujas
	var line := tr("PAS_ENC_%s_SAY%d" % [type.to_upper(), RNG.randi_range(0, 2)])
	get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -34), line, DATA[type].col.lerp(Color.WHITE, 0.45))


# ------------------------------------------------------------------ dibujo
class Mist extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 0.85, 0.95, 0.55))
		for i in 60:
			var h := float(i) * 12.9898
			var x := fposmod(sin(h) * 437.5, s.x)
			var y := fposmod(cos(h * 1.7) * 311.7, s.y)
			var a := 0.4 + 0.6 * absf(sin(_t * 3.0 + h))
			draw_rect(Rect2(x, y, 5, 5), Color(1, 1, 1, a))


func _draw() -> void:
	if _dead and modulate.a <= 0.0:
		return
	var col: Color = DATA[type].col
	var f := _face
	if _flash > 0.0:
		col = col.lerp(Color.WHITE, 0.7)
	var ink := Color("1a1020")
	# sombra
	draw_set_transform(Vector2(0, 14), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _spr != null:
		return  # el cuerpo lo pone el sprite
	var bob := sin(_t * 6.0) * 2.0
	var c := Vector2(0, -6 + bob)
	match type:
		"tio":
			_blob(c, 15.0, col, ink)
			draw_rect(Rect2(c + Vector2(-9 * f - 5, 4), Vector2(18, 4)), Color("3a2418"))  # bigote
			draw_circle(c + Vector2(0, 11), 8.0, col.darkened(0.12))  # barriga
			_eyes(c + Vector2(0, -4), f, ink)
			_bubble(c + Vector2(14, -24), "?")
		"spam":
			_blob(c, 13.0, col, ink)
			for i in 3:
				var a := _t * 2.5 + i * TAU / 3.0
				var p := c + Vector2.from_angle(a) * 19.0
				draw_rect(Rect2(p - Vector2(5, 4), Vector2(10, 8)), Color.from_hsv(float(i) / 3.0, 0.5, 1.0))
				draw_rect(Rect2(p - Vector2(5, 4), Vector2(10, 8)), ink, false, 1.5)
			_eyes(c + Vector2(0, -3), f, ink)
		"vendedor":
			_blob(c, 13.0, col, ink)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 2), c + Vector2(3, 2), c + Vector2(2, 14), c + Vector2(-2, 14)]), Color("d83a3a"))  # corbata
			draw_rect(Rect2(c + Vector2(10 * f - 6, 2), Vector2(14, 18)), Color("f4f0e0"))  # folleto
			draw_rect(Rect2(c + Vector2(10 * f - 6, 2), Vector2(14, 18)), ink, false, 1.5)
			_eyes(c + Vector2(0, -4), f, ink)
		"mosquito":
			_blob(c, 8.0, col, ink)
			var w := sin(_t * 60.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-2, -6), c + Vector2(-16, -14 + w * 4), c + Vector2(-8, -2)]), Color(0.8, 0.9, 1.0, 0.7))
			draw_colored_polygon(PackedVector2Array([c + Vector2(2, -6), c + Vector2(16, -14 - w * 4), c + Vector2(8, -2)]), Color(0.8, 0.9, 1.0, 0.7))
			draw_line(c + Vector2(8 * f, 2), c + Vector2(17 * f, 5), ink, 2.0)
			_eyes(c + Vector2(0, -2), f, ink)
		"cunado":
			_blob(c, 15.0, col, ink)
			draw_rect(Rect2(c + Vector2(-9, -8), Vector2(7, 5)), ink, false, 1.5)  # gafas
			draw_rect(Rect2(c + Vector2(2, -8), Vector2(7, 5)), ink, false, 1.5)
			draw_line(c + Vector2(10 * f, 2), c + Vector2(24 * f, -6 + sin(_t * 8.0) * 3.0), ink, 3.0)  # dedo que explica
			draw_circle(c + Vector2(24 * f, -6 + sin(_t * 8.0) * 3.0), 3.0, col.lightened(0.2))
		"notificacion":
			draw_rect(Rect2(c + Vector2(-13, -15), Vector2(26, 30)), Color("f4f0e0"))
			draw_rect(Rect2(c + Vector2(-13, -15), Vector2(26, 30)), ink, false, 2.0)
			draw_circle(c + Vector2(11, -14), 8.0, col)
			draw_circle(c + Vector2(11, -14), 8.0, ink, false, 1.5)
			draw_string(ThemeDB.fallback_font, c + Vector2(8, -10), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
			_eyes(c + Vector2(0, -2), f, ink)
		"ex":
			draw_rect(Rect2(c + Vector2(-10, -16), Vector2(20, 32)), Color("2a2a44"))
			draw_rect(Rect2(c + Vector2(-10, -16), Vector2(20, 32)), ink, false, 2.0)
			draw_rect(Rect2(c + Vector2(-8, -12), Vector2(16, 22)), col)
			for i in 3:
				draw_circle(c + Vector2(-4 + i * 4.0, 2), 1.6 + (1.0 if int(_t * 3.0) % 3 == i else 0.0), Color.WHITE)  # "escribiendo..."
		"influencer":
			_blob(c, 14.0, col, ink)
			draw_circle(c + Vector2(0, -14), 9.0, Color("f4d27a"))  # pelazo
			draw_circle(c + Vector2(0, -14), 9.0, ink, false, 1.5)
			_eyes(c + Vector2(0, -3), f, ink)
			for i in 4:
				var a := _t * 3.0 + i * 1.57
				draw_rect(Rect2(c + Vector2.from_angle(a) * 20.0 - Vector2(2, 2), Vector2(4, 4)), Color(1, 1, 1, 0.9))
		"chicle":
			_blob(c + Vector2(0, 4), 13.0, col, ink)
			draw_line(c + Vector2(6, 0), c + Vector2(20, -10 + sin(_t * 4.0) * 4.0), col.darkened(0.1), 3.0)  # hilo de chicle
			_eyes(c + Vector2(0, 2), f, ink)
		"captcha":
			draw_rect(Rect2(c + Vector2(-14, -14), Vector2(28, 28)), col)
			draw_rect(Rect2(c + Vector2(-14, -14), Vector2(28, 28)), ink, false, 2.0)
			draw_rect(Rect2(c + Vector2(-8, -8), Vector2(10, 10)), Color.WHITE)
			draw_rect(Rect2(c + Vector2(-8, -8), Vector2(10, 10)), ink, false, 1.5)
			_eyes(c + Vector2(6, 4), f, ink)


func _blob(c: Vector2, r: float, col: Color, ink: Color) -> void:
	draw_circle(c, r + 2.0, ink)
	draw_circle(c, r, col)
	draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.25, col.lightened(0.35))


func _eyes(c: Vector2, f: float, ink: Color) -> void:
	for dx in [-5.0, 5.0]:
		draw_circle(c + Vector2(dx, 0), 3.2, Color.WHITE)
		draw_circle(c + Vector2(dx + f * 1.2, 0.5), 1.5, ink)


func _bubble(p: Vector2, txt: String) -> void:
	draw_circle(p, 7.0, Color("f4f0e0"))
	draw_circle(p, 7.0, Color("1a1020"), false, 1.5)
	draw_string(ThemeDB.fallback_font, p + Vector2(-3, 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("1a1020"))


## Burbuja de chat con texto: obstaculo FISICO del pasillo (capa 2, como los enemigos: se cruza con dash). Se
## revienta a tiros (las letras salen volando), se esquiva o se desvanece sola a los ~7 s para no trabar a nadie.
## Las "pegajosas" (spam, aviso) ademas frenan al tocarlas.
class ChatBubble extends StaticBody2D:
	const LIFE := 7.5
	var text := ""
	var col := Color.WHITE
	var sticky := false
	var _t := 0.0
	var _label: Label
	var _area: Area2D
	var _popped := false

	static func create(text_: String, col_: Color, sticky_: bool) -> ChatBubble:
		var b := ChatBubble.new()
		b.text = text_
		b.col = col_
		b.sticky = sticky_
		return b

	func _ready() -> void:
		add_to_group("chat_bubble")
		collision_layer = 2
		collision_mask = 0
		z_index = 4
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(62, 34)
		add_child(shape)
		_label = Label.new()
		_label.text = text
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size = Vector2(58, 0)
		_label.size = Vector2(58, 30)
		_label.position = Vector2(-29, -15)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.add_theme_font_size_override("font_size", 8)
		_label.add_theme_color_override("font_color", Color("1a1020"))
		_label.clip_text = true
		_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_label)
		_area = Area2D.new()
		_area.collision_layer = 0
		_area.collision_mask = 8 | 1  # disparos del heroe y el propio heroe (frena si es pegajosa)
		var hs := CollisionShape2D.new()
		hs.shape = RectangleShape2D.new()
		hs.shape.size = Vector2(70, 42)
		_area.add_child(hs)
		_area.area_entered.connect(_on_area)
		add_child(_area)
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		material = mat
		scale = Vector2(0.2, 0.2)
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _on_area(a: Area2D) -> void:
		if a.is_in_group("player_attack"):
			pop()

	func take_damage(_amount: float, _src: Node = null, _kb: Vector2 = Vector2.ZERO) -> float:
		pop()
		return 1.0

	func pop() -> void:
		if _popped:
			return
		_popped = true
		set_deferred("collision_layer", 0)
		Sound.play("crack")
		var root := get_parent()
		var base := global_position
		for i in mini(text.length(), 7):
			var ch := Label.new()
			ch.text = text.substr(i, 1)
			ch.add_theme_font_size_override("font_size", 16)
			ch.add_theme_color_override("font_color", col.lightened(0.2))
			ch.add_theme_color_override("font_outline_color", Color("1a1020"))
			ch.add_theme_constant_override("outline_size", 4)
			ch.z_index = 6
			root.add_child(ch)
			ch.global_position = base + Vector2(randf_range(-20, 20), randf_range(-8, 8))
			var tw := ch.create_tween().set_parallel(true)
			tw.tween_property(ch, "position", ch.position + Vector2.from_angle(randf() * TAU) * randf_range(40, 90), 0.6)
			tw.tween_property(ch, "modulate:a", 0.0, 0.6)
			tw.chain().tween_callback(ch.queue_free)
		queue_free()

	func _physics_process(delta: float) -> void:
		_t += delta
		if sticky and _area != null:
			for b in _area.get_overlapping_bodies():
				if b.is_in_group("player") and b.has_method("set_terrain_slow"):
					b.set_terrain_slow(0.55)
		if _t > LIFE - 1.0:
			modulate.a = clampf(LIFE - _t, 0.0, 1.0)
			if _t > LIFE - 0.9:
				set_deferred("collision_layer", 0)  # ya no estorba
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(-31, -17, 62, 34)
		draw_rect(r.grow(2), Color("1a1020"))
		draw_rect(r, Color("f4f0e0"))
		draw_rect(Rect2(-31, -17, 62, 4), col)
		draw_colored_polygon(PackedVector2Array([Vector2(-10, 17), Vector2(2, 17), Vector2(-14, 28)]), Color("1a1020"))
		draw_colored_polygon(PackedVector2Array([Vector2(-9, 16), Vector2(0, 16), Vector2(-12, 25)]), Color("f4f0e0"))
