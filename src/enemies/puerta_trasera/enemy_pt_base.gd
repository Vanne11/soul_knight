class_name EnemyPtBase
extends EnemySwarmer

## Base de los enemigos nuevos de LA PUERTA TRASERA (cada uno = un mito o un problema de salud anal, con humor
## sobre la SITUACION). Reutiliza el esqueleto de EnemySwarmer (vida, barra, botin, muerte, contrato con heroes)
## y deja a cada hijo su propia maquina de estados con AVISO claro antes de cualquier dano.
## Sin personalidad de IA ("none"): la conducta es la del propio script.

const PROJECTILE := preload("res://src/enemies/projectile_enemy.tscn")


func _init() -> void:
	personality = "none"


## Hay objetivo vivo? (lo busca si hace falta).
func _has_target() -> bool:
	if not target or not is_instance_valid(target):
		_find_target()
	return target != null


func _play(a: StringName) -> void:
	if animated_sprite.animation != a and animated_sprite.sprite_frames.has_animation(a):
		animated_sprite.play(a)


func _face(dx: float) -> void:
	if absf(dx) > 1.0:
		animated_sprite.flip_h = dx < 0.0


## Texto flotante sobre la cabeza (frases secas de "aeropuerto/clinica").
func say(text: String, col := Color(1, 1, 1)) -> void:
	var ge := get_node_or_null("/root/GlobalEvents")
	if ge != null:
		ge.show_floating_text.emit(global_position + Vector2(0, -52), tr(text), col)


## Golpe de contacto: mira a quien solapa el hitbox AHORA (mismo criterio que EnemySwarmer._strike).
func contact(dmg: float) -> bool:
	for b in hitbox.get_overlapping_bodies():
		if b.has_method("receive_hit") and b.receive_hit(dmg):
			return true
	return false


## Empuja al jugador (contrato con Player.shove).
func shove_player(dir: Vector2, force: float, secs := 0.2) -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("shove"):
		pl.shove(dir.normalized() * force, secs)


func shoot_ring(n: int, spd: float, dmg: float, col: Color, base := 0.0) -> void:
	Sound.play("crack")
	for i in n:
		var p := PROJECTILE.instantiate()
		p.damage = dmg
		p.speed = spd
		p.projectile_owner = self
		p.lifetime = 3.0
		p.tint = col
		_spawn_container().add_child(p)
		var ang := base + i * TAU / float(n)
		p.global_rotation = ang
		p.global_position = global_position + Vector2.RIGHT.rotated(ang) * 16.0 + Vector2(0, -8)
