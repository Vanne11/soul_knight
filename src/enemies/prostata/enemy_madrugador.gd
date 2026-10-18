extends Enemy3a
class_name EnemyMadrugador

## Madrugador Nocturno (La Prostata): pijama, gorro y un despertador que suena a las 3 a. m.
## Embiste en rafagas rapidas. Llega en OLEADAS DE NOCHE, TRES veces por sala: al caer el ultimo
## de una tanda suena la alarma, la sala se oscurece un momento ("te despierta") y entra la
## siguiente tanda desde el borde (2 y luego 3 madrugadores mas debiles). Aviso: el reloj
## "3:00 A. M." flota sobre la sala y los nuevos parpadean al llegar.

const WAVES_PER_ROOM := 3
const META := "madrugador_wave"


func _setup() -> void:
	Prostata.ensure()
	personality = "madrugador"
	move_speed = 165.0
	lunge_trigger = 130.0
	windup_time = 0.5
	lunge_time = 0.24
	lunge_speed = 540.0
	recover_time = 0.65
	attack_cooldown = 0.4
	detection_range = 700.0


func die(killer: Node = null) -> void:
	if state != State.DEAD:
		Prostata.note("pro_madrugador")
		_call_next_wave()
	super.die(killer)


## Si era el ultimo madrugador vivo de la sala y quedan tandas, suena la alarma.
func _call_next_wave() -> void:
	var room := find_owning_room()
	if room == null:
		return
	var wave: int = int(room.get_meta(META, 1))
	if wave >= WAVES_PER_ROOM:
		return
	for e in room.enemies_spawned:
		if e != self and is_instance_valid(e) and not e.is_queued_for_deletion() and e is EnemyMadrugador \
				and float(e.current_health) > 0.0:
			return
	room.set_meta(META, wave + 1)
	var clock := "3:%02d A. M." % (wave * 7 + 3)
	Prostata.floating(global_position + Vector2(0, -60), clock, Color("ffd23a"))
	Prostata.night(self, 1.0)
	var n := wave + 1  # 2 en la segunda tanda, 3 en la tercera
	var pts: Array = room.spawn_points.duplicate()
	RNG.shuffle(pts)
	var player := _player()
	for i in n:
		var at: Vector2 = global_position + Vector2.from_angle(RNG.randf_range(0.0, TAU)) * 90.0
		for p in pts:
			if player == null or (p as Vector2).distance_to(player.global_position) > 230.0:
				at = p
				pts.erase(p)
				break
		var m := E3a.spawn(self, "madrugador", at, maxf(max_health * 0.7, 20.0), base_damage * 0.9,
				"", 1.0)
		m.add_to_group("madrugador_tanda")
		Prostata.say(m, "madrugador_wake", 2.0)
		Prostata.icon(m, "alert", 1.2)
	room.set_meta(META, wave + 1)
