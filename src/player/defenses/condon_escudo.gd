extends Defense
class_name DefCondon

## CONDON ESCUDO. MANTENER "guard": burbuja de latex alrededor del heroe que bloquea balas y golpes de
## cualquier lado y NO deja pasar contagios (picazon, ardor). Aguanta HITS golpes y se rompe: queda
## inservible ("uno por vez, no se reutiliza") y vuelve la guard del heroe hasta que consigas otro.
## Con la burbuja arriba camina lento y no dispara (como cualquier escudo).

const HITS := 5
const WALK_MULT := 0.7
const ICON_BROKEN := "res://assets/sprites/items/def_condon_escudo_roto.png"

var hits_left := HITS
var blocks := 0
var _flash := 0.0
var _t := 0.0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("3fd0c0")


func icon() -> Texture2D:
	return load(ICON_BROKEN) if spent else super.icon()


func speed_mult() -> float:
	return WALK_MULT if guarding else 1.0


func can_attack() -> bool:
	return not guarding


func blocks_contagion() -> bool:
	return guarding


func _physics_process(_d: float) -> void:
	if player == null:
		return
	guarding = not spent and guard_held()
	gauge_visible = not spent and hits_left < HITS
	gauge_value = float(hits_left) / HITS


func try_guard(area: Area2D, _dmg: float) -> bool:
	if not guarding or not is_projectile(area):
		return false
	consume(area)
	_absorb()
	return true


func filter_hit(dmg: float) -> float:
	if not guarding or dmg <= 0.0:
		return dmg
	_absorb()
	return 0.0


func _absorb() -> void:
	hits_left -= 1
	blocks += 1
	_flash = 0.25
	Sound.play("crack", 0.1)
	HitFx.shake(0.15)
	if hits_left <= 0:
		spent = true
		guarding = false
		gauge_visible = false
		text("DEF_CONDOM_BROKEN", Color("9fbfb8"), 40.0)
		Sound.play("hurt")
	else:
		text("DEF_CONDOM_HIT", Color("7fe8da"))


func _draw_tick() -> void:
	_t += get_process_delta_time()
	_flash = maxf(0.0, _flash - get_process_delta_time())
	if guarding or _flash > 0.0:
		queue_redraw()


func _draw_body() -> void:
	if not guarding:
		return
	var life := float(hits_left) / HITS
	var wob := 1.0 + sin(_t * 9.0) * 0.025
	var r := 22.0 * wob
	var col := Color("3fd0c0").lerp(Color("c8e8e4"), 1.0 - life)
	draw_circle(Vector2.ZERO, r, Color(col.r, col.g, col.b, 0.16 + _flash * 1.2))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(0, 0, 0, 0.7), 4.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(col.r, col.g, col.b, 0.9), 2.5)
	draw_arc(Vector2.ZERO, r - 4.0, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.8), 2.0)  # brillo
	# grietas: una por golpe recibido
	for i in range(HITS - hits_left):
		var a := 0.7 + i * 1.3
		var p0 := Vector2.from_angle(a) * (r - 1.0)
		draw_line(p0, p0 - Vector2.from_angle(a + 0.5) * 7.0, Color(0.1, 0.25, 0.25, 0.9), 1.5)
