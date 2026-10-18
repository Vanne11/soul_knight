extends EnemyRanged
class_name EnemyGoteoTardio

## Goteo Tardio (La Prostata): una gota cansada que tarda en cargar y luego suelta una rafaga que
## se va cortando: cada gota sale mas lenta y mas espaciada, y la ultima ya ni llega ("ya no llega
## como antes"). Legible: carga larga y brillante (aviso), gotas amarillas lentas. Sin dano por
## contacto. Es un tirador de zona: el reto es el ritmo irregular, no la cantidad.

const GAPS := [0.0, 0.13, 0.24, 0.42]
const SPEEDS := [290.0, 255.0, 205.0, 120.0]
var _dripping := false


func _ready() -> void:
	Prostata.ensure()
	personality = "goteo"
	spread_shots = 1
	fire_rate = 3.6
	charge_time = 1.1          # tarda en arrancar
	projectile_speed = 290.0
	preferred_distance = 310.0
	strafe_speed = 70.0
	super._ready()


## En vez del abanico, la rafaga que se corta.
func _release_spread() -> void:
	animated_sprite.modulate = Color.WHITE
	_fire_timer = fire_rate
	if not target or not is_instance_valid(target) or state == State.DEAD:
		return
	_drip_burst()


func _drip_burst() -> void:
	_dripping = true
	var n := RNG.randi_range(2, GAPS.size())  # cuantas alcanza a soltar antes de cortarse
	for i in n:
		if GAPS[i] > 0.0:
			await get_tree().create_timer(GAPS[i]).timeout
		if state == State.DEAD or not is_instance_valid(target):
			_dripping = false
			return
		var last := i == n - 1 and n > 2
		var base: float = (target.global_position - projectile_spawn.global_position).angle()
		_drop(base + RNG.randf_range(-0.05, 0.05), SPEEDS[i] * (0.8 if last else 1.0), 0.8 if last else 3.2)
	_dripping = false
	if RNG.randf() < 0.4:
		Prostata.say(self, "goteo_cut", 1.8)


func _drop(angle: float, speed: float, life: float) -> void:
	var proj: ProjectileEnemy = projectile_scene.instantiate()
	proj.global_rotation = angle
	proj.damage = damage
	proj.speed = speed
	proj.lifetime = life
	proj.tint = Color(1.0, 0.92, 0.35)
	proj.projectile_owner = self
	_spawn_container().add_child(proj)
	proj.global_position = projectile_spawn.global_position


func die(killer: Node = null) -> void:
	Prostata.codex("goteo_tardio")
	Prostata.note("pro_goteo")
	super.die(killer)
