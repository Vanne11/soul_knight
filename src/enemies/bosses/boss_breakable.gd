extends StaticBody2D
class_name BossBreakable

## Objeto de jefe que el jugador puede romper a tiros: huevos de Ovaria (si no los
## rompes eclosionan) y hojas del escudo de la Hoja de Parra. Esta en el grupo
## "enemy" para que las balas del jugador (y el bot) lo traten como un enemigo, pero
## no cuenta para limpiar la sala. Nace gris (Censor) y se colorea al liberar la sala.

enum Kind { EGG, LEAF, FAKE }

const CENSOR_UNSHADED := preload("res://src/shaders/censor_unshaded.gdshader")
## Arte del huevo de Ovaria (tools/gen_ovaria_art.py): normal, a punto de eclosionar, roto y Ovulo Real (con corona).
const EGG_TEX := preload("res://assets/sprites/enemies/vulvania/reina_ovaria/reina_ovaria_huevo_normal.png")
const EGG_HATCH_TEX := preload("res://assets/sprites/enemies/vulvania/reina_ovaria/reina_ovaria_huevo_hatch.png")
const EGG_BROKEN_TEX := preload("res://assets/sprites/enemies/vulvania/reina_ovaria/reina_ovaria_huevo_broken.png")
const EGG_ROYAL_TEX := preload("res://assets/sprites/enemies/vulvania/reina_ovaria/reina_ovaria_huevo_royal.png")
## Segundos finales en que el huevo muestra el cascaron agrietado.
const HATCH_LOOK := 1.4

signal broken(b: BossBreakable)
signal expired(b: BossBreakable)

var kind := Kind.EGG
var enemy_name := "Huevo"
var max_health := 20.0
var current_health := 20.0
## Segundos hasta "expirar" (eclosionar / soltarse). < 0 = nunca.
var life := 6.0
## Dano al tocar al jugador (hojas). 0 = inofensivo.
var contact_damage := 0.0
var color := Color(1.0, 0.7, 0.8)
## Logica extra por frame (guardianes) y barra de vida propia sobre el objeto.
var tick_cb := Callable()
var show_bar := false
## FAKE: copia del jefe (textura, escala y espejo del sprite original).
var tex: Texture2D = null
var tex_scale := Vector2.ONE
var tex_flip := false
## EGG: Ovulo Real (usa el sprite con corona; el nodo va escalado, el dibujo lo compensa para conservar el pixel 1:1).
var royal := false

var _t := 0.0
var _flash := 0.0
var _dead := false
var _mat := ShaderMaterial.new()
var _room: Node = null
var _contact_hit := false
var _popped := false


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("boss_breakable")
	collision_layer = 0
	set_collision_layer_value(2, true)
	collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 22.0 if kind == Kind.EGG else 18.0
	if kind == Kind.FAKE:
		sh.radius = 40.0
		cs.position = Vector2(0, -55)
	cs.shape = sh
	add_child(cs)
	current_health = max_health
	_mat.shader = CENSOR_UNSHADED
	if kind != Kind.FAKE:
		material = _mat  # las copias del jefe van en color, como el original
	var n: Node = get_parent()
	while n != null and not (n is Room):
		n = n.get_parent()
	_room = n
	z_index = 1
	if kind != Kind.FAKE:
		ActorFx.add_glow(self, color, 0.5, 0.45)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	_flash = maxf(0.0, _flash - delta)
	_mat.set_shader_parameter("color_amount", Censor.amount(_room) if _room else 1.0)
	if contact_damage > 0.0:
		var tg := get_tree().get_first_node_in_group("player")
		if tg and tg.global_position.distance_to(global_position) < 34.0 and tg.has_method("receive_hit"):
			tg.receive_hit(contact_damage)
	if tick_cb.is_valid():
		tick_cb.call(self, delta)
	if life >= 0.0 and _t >= life:
		_dead = true
		expired.emit(self)
		queue_free()
		return
	queue_redraw()


func is_alive() -> bool:
	return not _dead


func remaining() -> float:
	return maxf(life - _t, 0.0) if life >= 0.0 else 999.0


func take_damage(amount: float, _source: Node = null, _kb: Vector2 = Vector2.ZERO) -> float:
	if _dead:
		return 0.0
	current_health -= amount
	_flash = 0.12
	Sound.play("enemy_hit")
	if current_health <= 0.0:
		_dead = true
		HitFx.shake(0.15)
		broken.emit(self)
		_pop()
	return amount


func die(_killer: Node = null) -> void:
	if _dead:
		return
	_dead = true
	queue_free()


func _pop() -> void:
	_popped = true
	set_deferred("collision_layer", 0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.chain().tween_callback(queue_free)


func _draw() -> void:
	if kind == Kind.FAKE:
		if tex:
			var sx := -tex_scale.x if tex_flip else tex_scale.x
			draw_set_transform(Vector2(0, -90), 0.0, Vector2(sx, tex_scale.y))
			draw_texture(tex, -tex.get_size() * 0.5, Color(1, 1, 1, 0.4) if _flash > 0.0 else Color.WHITE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var wob := Vector2.ZERO
	var urgent := life >= 0.0 and remaining() < 1.4
	if urgent:
		wob = Vector2(sin(_t * 60.0) * 2.5, 0.0)
	var flash := _flash > 0.0
	if kind == Kind.EGG:
		var tex_egg: Texture2D = EGG_TEX
		if royal:
			tex_egg = EGG_ROYAL_TEX
		elif _popped:
			tex_egg = EGG_BROKEN_TEX
		elif urgent and remaining() < HATCH_LOOK:
			tex_egg = EGG_HATCH_TEX
		var inv := Vector2.ONE / scale  # el sprite se dibuja a 1 pixel de arte = 1 pixel de pantalla aunque el nodo escale
		draw_set_transform(wob + Vector2(0, -8), 0.0, inv)
		draw_texture(tex_egg, -tex_egg.get_size() * 0.5, Color(1.8, 1.8, 1.8) if flash else Color.WHITE)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if life > 0.0:
			var frac := clampf(remaining() / life, 0.0, 1.0)
			draw_arc(Vector2(0, -8), 32.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 32, Color(1, 1, 1, 0.9), 4.0)
		if show_bar:
			var f := clampf(current_health / maxf(max_health, 1.0), 0.0, 1.0)
			draw_rect(Rect2(-24, -50, 48, 6), Color(0, 0, 0, 0.85))
			draw_rect(Rect2(-23, -49, 46.0 * f, 4), Color(1.0, 0.85, 0.2))
	else:
		var pts2 := PackedVector2Array([Vector2(0, -26), Vector2(14, -8), Vector2(10, 16), Vector2(0, 22), Vector2(-10, 16), Vector2(-14, -8)])
		draw_colored_polygon(pts2, Color.WHITE if flash else Color(0.45, 0.85, 0.4))
		draw_line(Vector2(0, -22), Vector2(0, 20), Color(0.1, 0.35, 0.15), 2.0)
		draw_line(Vector2(0, -2), Vector2(9, -10), Color(0.1, 0.35, 0.15), 2.0)
		draw_line(Vector2(0, 6), Vector2(-9, -2), Color(0.1, 0.35, 0.15), 2.0)
