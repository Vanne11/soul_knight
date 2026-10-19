extends EnemyBoss

## LA CENSURA QUE DESTIÑE (jefe de Arcoiria; nombre provisorio) - usa el MOTOR DINAMICO (dynamic = true).
## Un funcionario gris con un rodillo gigante de pintura gris: quiere que el mundo vuelva a ser
## gris. IDENTIDAD: la sala es una rejilla de zonas (DestineFloor) que empieza en COLOR, una franja de
## la bandera por fila; el jefe las va DESTIÑENDO y tu las RECOLORIZAS.
## - ZONA GRIS: te frena (estado "desteñido") y te hace dano en goteo mientras la pisas.
## - RECOLORIZAR: revienta un ORBE DE COLOR disparandole o pisandolo (DestineOrb): pinta de nuevo las
##   zonas grises de alrededor. Nacen solos si el gris se extiende, y los trae el ataque "pinta".
## - COLOR = DANO: cuanta mas sala tienes en color, mas dano le haces (x1,3 con todo en color, x0,55 con
##   todo en gris). Si dejas que gane el gris, casi no le haces cosquillas.
## - CONTAGIO: cada pocos segundos una zona de color pegada al gris se destine (avisa parpadeando); mas
##   rapido en cada fase.
## - ATAQUES: abanico gris, embestida, RODILLO (una fila/columna entera: golpe y destine; dos en fase 3),
##   SELLO (circulos de CENSURADO que destiñen lo que tocan) y PINTA (se le cae el color: suelta orbes y
##   queda agotado).
## - FASES por vida (66% / 33%): mas contagio, mas ataques por combo, avisos mas cortos.
## - CURA (1): canaliza y se hace invulnerable; para cortarla revienta 3 de los 4 orbes que aparecen
##   antes de que acabe el tiempo; si lo logras queda aturdido y la sala vuelve a color.
## Frases: bossarcoiria_<intro|phase2|phase3|death|after> (assets/data/narrator/arcoiria.json).

const GRAYC := Color(0.66, 0.66, 0.78)
const HP_MULT := 0.7
const GRAY_TICK := 1.1            ## segundos entre goteos de dano en zona gris
const GRAY_DMG := 0.18            ## fraccion del dano del jefe por goteo
const CREEP_EVERY := [7.0, 4.8, 3.2]
const MAX_ORBS := 5
const COLOR_DMG := Vector2(0.55, 1.3)   ## multiplicador de dano al jefe: todo gris .. todo color

var _grid: DestineFloor = null
var _creep_t := 6.0
var _orb_t := 6.0
var _gray_t := 0.4
var _ch_popped := 0


func _ready() -> void:
	super()
	dynamic = true
	fan_tint = GRAYC
	keep_min = 170.0
	keep_max = 290.0
	rest_min = 0.5
	rest_max = 0.9
	bullet_speed = 270.0
	tele_caps = [0.8, 0.65, 0.55]
	move_speed = 85.0
	max_health *= HP_MULT
	current_health = max_health
	_emit_health()
	_channels_total = 1
	_channels_left = 1
	_ge.boss_charges_changed.emit(_channels_left, _channels_total)


func _say(suffix: String) -> void:
	var key := "bossarcoiria_%s" % suffix
	if Narrator.has_lines(key):
		Narrator.say(key)


func _attack_pool() -> Array:
	match current_phase:
		1:
			return [&"atk_rodillo", &"atk_fan", &"atk_sello", &"atk_pinta"]
		2:
			return [&"atk_rodillo", &"atk_sello", &"atk_fan", &"atk_charge", &"atk_pinta", &"atk_rodillo"]
	return [&"atk_rodillo", &"atk_sello", &"atk_sello", &"atk_charge", &"atk_pinta", &"atk_rodillo"]


func _challenges() -> Array:
	return [&"ch_color"]


func _channel_color() -> Color:
	return Color(0.85, 0.85, 1.0)


func _hit_source() -> String:
	return "zona gris"


func _on_phase(n: int) -> void:
	move_speed = [85.0, 105.0, 125.0][n - 1]
	_creep_t = 1.5
	if _grid != null:
		for _i in n:
			_grid.creep()
	_float_text(tr("ARC_BOSS_PHASE_%d" % n), GRAYC)


func _on_death() -> void:
	if _grid != null and is_instance_valid(_grid):
		_grid.recolor_all()
		_float_text(tr("ARC_BOSS_DEATH"), Color("fff1c4"))
		var f := _grid
		get_tree().create_timer(3.0).timeout.connect(func():
			if is_instance_valid(f):
				f.queue_free())


func _on_cure_cut() -> void:
	if _grid != null:
		_grid.recolor_all()


func _on_cure_done() -> void:
	if _grid != null:
		for _i in 3:
			_grid.creep()


# ---------------------------------------------------------------- la rejilla y sus reglas
func _ensure_floor() -> void:
	if _grid != null and is_instance_valid(_grid):
		return
	_grid = DestineFloor.build(_spawn_container(), arena(), find_owning_room())
	# para que se entienda desde el principio: dos zonas ya destenidas
	var ok: Array[int] = []
	for i in DestineFloor.COLS * DestineFloor.ROWS:
		if _grid.valid[i] == 1:
			ok.append(i)
	RNG.shuffle(ok)
	for k in mini(2, ok.size()):
		_grid.gray(ok[k])


func _tick(delta: float) -> void:
	_ensure_floor()
	if state in [State.INTRO, State.TRANSITION] or target == null:
		return
	_creep_t -= delta
	if _creep_t <= 0.0:
		_creep_t = CREEP_EVERY[clampi(current_phase, 1, 3) - 1]
		if not _channeling or RNG.randf() < 0.5:
			_grid.creep()
	_orb_t -= delta
	if _orb_t <= 0.0:
		_orb_t = 8.0
		if _orb_count() == 0 and _grid.gray_fraction() >= 0.2 and not _channeling:
			_spawn_orbs(1)
	_gray_floor_effect(delta)


## Pisar gris frena y hace dano en goteo.
func _gray_floor_effect(delta: float) -> void:
	_gray_t -= delta
	if not _grid.is_gray(_grid.cell_at(target.global_position)):
		return
	var st := StatusEffects.of(target)
	if st != null:
		st.apply("desteñido", 0.4, self)
	if _gray_t <= 0.0:
		_gray_t = GRAY_TICK
		target.receive_hit(damage * GRAY_DMG)


func take_damage(amount: float, source: Node = null, kb: Vector2 = Vector2.ZERO) -> float:
	if _grid != null and is_instance_valid(_grid) and state not in [State.DEAD, State.INTRO, State.TRANSITION] and not _channeling and not invuln:
		var color_frac := 1.0 - _grid.gray_fraction()
		amount *= lerpf(COLOR_DMG.x, COLOR_DMG.y, color_frac)
	return super(amount, source, kb)


func _orb_count() -> int:
	var n := 0
	for o in get_tree().get_nodes_in_group("boss_breakable"):
		if o is DestineOrb and o.is_alive():
			n += 1
	return n


func _spawn_orb(pos: Vector2, color: Color, life := 11.0) -> DestineOrb:
	var o := DestineOrb.new()
	o.color = color
	o.life = life
	o.floor_ref = _grid
	_spawn_container().add_child(o)
	o.global_position = pos
	return o


func _spawn_orbs(n: int) -> void:
	for _i in n:
		if _orb_count() >= MAX_ORBS:
			return
		_spawn_orb(arena_point(110.0), Arcoiria.stripe(RNG.randi_range(0, 5)).color)


# ---------------------------------------------------------------- ataques
## RODILLO: una fila (o columna) entera: aviso en el suelo, golpe y se destine. En fase 3, fila Y columna.
func atk_rodillo() -> void:
	var a := arena()
	var warn: float = [1.0, 0.85, 0.72][current_phase - 1]
	if not await _tele(0.5, Color(1.7, 1.7, 1.9), 2.0):
		return
	var row := clampi(int((target.global_position.y - a.position.y) / _grid.cell.y), 0, DestineFloor.ROWS - 1)
	var col := clampi(int((target.global_position.x - a.position.x) / _grid.cell.x), 0, DestineFloor.COLS - 1)
	var axes := [[0, row]] if current_phase < 3 else [[0, row], [1, col]]
	for ax in axes:
		var z: BossZone
		if ax[0] == 0:
			z = BossZone.rect(Vector2(a.get_center().x, a.position.y + (ax[1] + 0.5) * _grid.cell.y), Vector2(a.size.x, _grid.cell.y - 6.0), 0.0, warn, 0.3, damage * 0.8, GRAYC)
		else:
			z = BossZone.rect(Vector2(a.position.x + (ax[1] + 0.5) * _grid.cell.x, a.get_center().y), Vector2(a.size.y, _grid.cell.x - 6.0), PI * 0.5, warn, 0.3, damage * 0.8, GRAYC)
		_add_hazard(z)
	Sound.play("enemy_shoot")
	if not await _wait(warn):
		return
	for ax in axes:
		_grid.gray_line(ax[0], ax[1])
	HitFx.shake(0.3)
	if not await _wait(0.4):
		return
	_tire(1.0)


## SELLO: circulos de CENSURADO sobre ti (y al azar) que destiñen lo que tocan.
func atk_sello() -> void:
	var warn: float = [1.1, 0.95, 0.8][current_phase - 1]
	if not await _tele(0.5, Color(1.7, 1.7, 1.9), 2.0):
		return
	var spots: Array[Vector2] = [clamp_to_arena(target.global_position, 90.0)]
	for _i in 1 + current_phase:
		spots.append(arena_point(100.0))
	for p in spots:
		_add_hazard(BossZone.circle(p, 78.0, warn, 0.3, damage * 0.9, GRAYC))
	Sound.play("enemy_shoot")
	if not await _wait(warn):
		return
	for p in spots:
		_grid.gray_radius(p, 84.0)
	HitFx.shake(0.3)
	if not await _wait(0.4):
		return
	_tire(0.9)


## PINTA: se le cae el color: suelta orbes (tu herramienta) y queda agotado, expuesto.
func atk_pinta() -> void:
	if not await _tele(0.45, Color(1.5, 1.5, 1.5), 1.5):
		return
	_float_text(tr("ARC_BOSS_PINTA"), Color("ffe08a"))
	_spawn_orbs(1 + current_phase)
	Sound.play("crack")
	if not await _wait(0.4):
		return
	_tire(1.5)


# ---------------------------------------------------------------- desafio de la cura
## COLOR: reventar 3 de los 4 orbes antes de que acabe el tiempo corta la cura.
func ch_color() -> void:
	_ch_popped = 0
	var need := 3
	for i in 4:
		var o := _spawn_orb(arena_point(110.0), Arcoiria.stripe(i + 1).color, 13.0)
		o.popped.connect(func(_o):
			if _channeling:
				_ch_popped += 1
				_chan_prog = float(_ch_popped) / need
				if _ch_popped >= need:
					_chan_ok = true)
	if not await _wait(0.3):
		return
	await _ch_loop(12.5)
