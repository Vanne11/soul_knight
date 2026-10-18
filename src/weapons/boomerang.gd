class_name Boomerang
extends Node2D

## Bumeran de Silicona: sale en linea recta atravesando enemigos, da la vuelta al llegar a su
## alcance (o al topar con una pared) y regresa a ti pegando otra vez. Mientras vuela no puedes
## lanzar otro (Player._weapon_ready mira `_boomerang`). Se atrapa al tocar al jugador.

const TEX := preload("res://assets/sprites/projectiles/boomerang.png")
const HIT_RADIUS := 17.0
const CATCH_RADIUS := 22.0
const MAX_LIFE := 4.0

var player: Node = null
var damage := 13.0
var speed := 540.0
var reach := 230.0
var knockback := 120.0
var crit_mult := 1.0
var weapon_id := ""  ## para BossDamage
var pierce_all := true
var direction := Vector2.RIGHT
var return_mult := 1.0  ## dano de la pasada de vuelta (sinergia Siempre Vuelve)
var returning := false
var _flown := 0.0
var _t := 0.0
var _hit: Array = []
var _spr: Sprite2D


func _ready() -> void:
	z_index = 3
	add_to_group("player_boomerang")
	_spr = Sprite2D.new()
	_spr.texture = TEX
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	ActorFx.add_projectile_shadow(self, 5.0, 10.0)
	ActorFx.add_glow(self, Color(1.0, 0.45, 0.6), 0.5, 0.3)


func _physics_process(delta: float) -> void:
	_t += delta
	_spr.rotation += 16.0 * delta
	if player == null or not is_instance_valid(player) or _t > MAX_LIFE:
		_release()
		return
	if returning:
		var to_p: Vector2 = (player.global_position + Vector2(0, -6)) - global_position
		if to_p.length() <= CATCH_RADIUS:
			_release()
			return
		direction = to_p.normalized()
	var step := direction * speed * delta
	if not returning:
		var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step * 2.0, 1)
		var wall: Dictionary = get_world_2d().direct_space_state.intersect_ray(q)
		if not wall.is_empty():
			var c = wall.get("collider")
			if c is Node and c.has_method("hit_by_bullet"):
				c.hit_by_bullet(damage, direction)
			_turn()
			return
	global_position += step
	_flown += step.length()
	if not returning and _flown >= reach:
		_turn()
	_strike()


func _turn() -> void:
	returning = true
	_hit.clear()
	get_node("/root/Sound").play("crack", 0.1)


func _strike() -> void:
	var ps := get_node("/root/PlayerStats")
	for e in get_tree().get_nodes_in_group("enemy"):
		if e in _hit or not is_instance_valid(e) or not e.has_method("take_damage") or float(e.get("current_health")) <= 0.0:
			continue
		if e.global_position.distance_to(global_position) > HIT_RADIUS + 12.0:
			continue
		_hit.append(e)
		var dmg := damage * crit_mult * (return_mult if returning else 1.0)
		# contra jefes la vuelta pega mucho menos (no es un segundo golpe completo)
		if returning and e.is_in_group("boss") and BossDamage.applies(e):
			dmg *= BossDamage.BOOMERANG_RETURN_MULT
		var kb := direction * knockback * (1.6 if returning and return_mult > 1.0 else 1.0)
		BossDamage.tag(weapon_id, crit_mult)
		e.take_damage(dmg, player, kb)
		if ps.lifesteal > 0.0:
			ps.heal(dmg * ps.lifesteal)
		if dmg >= PlayerBullet.STRONG_HIT:
			HitFx.hitstop()


func _release() -> void:
	if player != null and is_instance_valid(player) and player.get("_boomerang") == self:
		player.set("_boomerang", null)
	queue_free()


func _exit_tree() -> void:
	if player != null and is_instance_valid(player) and player.get("_boomerang") == self:
		player.set("_boomerang", null)
