extends Affix

## Reflector (Espejado): algunas de tus balas que lo van a golpear (40%, una cada 0.7 s) rebotan
## hacia ti como proyectil lento (260 px/s) con el 60% de su dano (3-14). Aviso: destello de
## espejo permanente sobre su cuerpo + icono, texto al rebotar. Se rodea o se le pega en cuerpo
## a cuerpo.

const CHANCE := 0.4
const COOLDOWN := 0.7
const NEAR := 70.0
const PROJ := preload("res://src/enemies/projectile_enemy.tscn")

var _cd := 0.0


func tick(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	var p := player()
	if p == null or p.get_parent() == null:
		return
	for b in p.get_parent().get_children():
		if not (b is PlayerBullet) or b.has_meta("reflect_rolled") or b.is_queued_for_deletion():
			continue
		if b.global_position.distance_to(host.global_position) > NEAR:
			continue
		var dir_b := Vector2.RIGHT.rotated(b.rotation)
		if dir_b.dot((host.global_position - b.global_position).normalized()) < 0.5:
			continue
		b.set_meta("reflect_rolled", true)
		if _cd <= 0.0 and RNG.randf() < CHANCE:
			reflect(b, p)
			return


func reflect(b: PlayerBullet, p: Node2D) -> void:
	_cd = COOLDOWN
	var proj: Area2D = PROJ.instantiate()
	proj.set("damage", clampf(b.damage * 0.6, 3.0, 14.0))
	proj.set("speed", 260.0)
	proj.set("projectile_owner", host)
	proj.set("tint", Color(0.85, 0.92, 1.0))
	proj.global_rotation = (p.global_position - b.global_position).angle()
	container().add_child(proj)
	proj.global_position = b.global_position
	b.queue_free()
	say(Loc.tr_or("AFFIX_REFLECT", "¡Rebote!"), Vector2(0, -52))
	if tag != null:
		tag.flash(Affixes.color_of(id))
