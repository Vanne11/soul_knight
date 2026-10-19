extends Affix

## Invocador: cada INTERVAL s (primera a los 3 s) tras un aviso de 0.8 s (parpadeo morado) suelta
## una cria del enjambre del piso. Hasta MAX_ALIVE crias vivas a la vez; son debiles (18% de su
## vida, 45% de su dano, mas pequenas, sin botin) y cuentan para limpiar la sala. No invoca si
## esta atacando o la IA lo controla (dormido, huyendo...).

const INTERVAL := 7.0
const FIRST := 3.0
const WARN := 0.8
const MAX_ALIVE := 3

var _cd := FIRST
var _warn := -1.0
var _kids: Array = []


func tick(delta: float) -> void:
	_kids = _kids.filter(func(k): return is_instance_valid(k) and float(k.get("current_health")) > 0.0)
	if _warn >= 0.0:
		_warn -= delta
		var spr = host.get("animated_sprite")
		if spr is AnimatedSprite2D:
			spr.self_modulate = Color(1.4, 0.8, 1.8) if int(_warn * 14.0) % 2 == 0 else Color.WHITE
		if _warn < 0.0:
			if spr is AnimatedSprite2D:
				spr.self_modulate = Color.WHITE
			summon()
		return
	_cd -= delta
	if _cd > 0.0 or _kids.size() >= MAX_ALIVE or busy() or dist_to_player() > 700.0:
		return
	_warn = WARN
	say(Loc.tr_or("AFFIX_SUMMON", "¡Refuerzos!"), Vector2(0, -60))
	if tag != null:
		tag.flash(Affixes.color_of(id))


func summon() -> void:
	_cd = INTERVAL
	if _dead or float(host.get("current_health")) <= 0.0:
		return
	var fd: Dictionary = get_node("/root/RunManager").floor_data()
	var roster: Array = fd.get("roster", [])
	var names: Array = fd.get("names", [])
	var idx := mini(2, roster.size() - 1)  # el puesto 2 del roster es el enjambre
	var kid: Node2D = EnemyRegistry.scene("swarmer").instantiate()
	kid.set("enemy_name", String(names[idx]) if idx >= 0 and idx < names.size() else String(host.get("enemy_name")))
	kid.set("max_health", maxf(6.0, float(host.get("max_health")) * 0.18))
	kid.set("damage", float(host.get("damage")) * 0.45)
	kid.set("drop_table", [] as Array[Dictionary])
	var frames_path := ""
	if idx >= 0 and idx < roster.size():
		frames_path = EnemyArt.frames(roster[idx])
	if frames_path != "" and ResourceLoader.exists(frames_path):
		kid.get_node("AnimatedSprite2D").sprite_frames = load(frames_path)
	kid.get_node("AnimatedSprite2D").scale *= 0.75
	kid.set_meta("summoned", true)
	container().add_child(kid)
	var pos := host.global_position + Vector2.RIGHT.rotated(RNG.randf_range(0.0, TAU)) * 38.0
	if not free_spot(pos, 10.0):
		pos = host.global_position
	kid.global_position = pos
	var room = host.find_owning_room() if host.has_method("find_owning_room") else null
	if room != null:
		room.enemies_spawned.append(kid)
	_kids.append(kid)
