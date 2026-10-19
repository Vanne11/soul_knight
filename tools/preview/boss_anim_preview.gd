extends Node2D

## Vista previa de las animaciones de un jefe (prototipo Dona Cera): monta al jefe sin sala, lo pone en
## cada situacion y guarda capturas PNG recortadas. Uso (con ventana, en la pantalla del notebook):
##   godot --audio-driver Dummy --screen 2 --path . res://tools/preview/boss_anim_preview.tscn -- --out=/ruta/ [--boss=cera]
## Despues tools/preview/contact_sheet.py arma las hojas de contacto.

const FRAMES := "res://assets/sprites/enemies/selva/boss_cera/boss_cera_sprite_frames.tres"
const SCRIPT := "res://src/enemies/bosses/boss_cera.gd"

var out := "user://preview/"
var boss: EnemyBoss
var player: Node2D
var cam: Camera2D
var shots := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var bg := ColorRect.new()
	bg.color = Color(0.32, 0.3, 0.36)
	bg.size = Vector2(4000, 4000)
	bg.position = Vector2(-2000, -2000)
	bg.z_index = -10
	add_child(bg)
	cam = Camera2D.new()
	cam.zoom = Vector2(2.2, 2.2)
	add_child(cam)
	cam.make_current()
	player = Node2D.new()
	player.add_to_group("player")
	player.position = Vector2(260, 0)
	add_child(player)
	_run.call_deferred()


func _spawn() -> void:
	if boss and is_instance_valid(boss):
		boss.free()
	var scene: PackedScene = load("res://src/enemies/enemy_boss.tscn")
	boss = scene.instantiate()
	boss.set_script(load(SCRIPT))
	boss.enemy_name = "Dona Cera"
	boss.max_health = 1000.0
	boss.get_node("AnimatedSprite2D").sprite_frames = load(FRAMES)
	boss.position = Vector2.ZERO
	add_child(boss)
	boss.target = player
	boss.set_physics_process(false)  # el estado lo manejo yo desde aqui
	cam.position = Vector2(0, -70)


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var r := Rect2i(w / 2 - 330, h / 2 - 290, 660, 580)
	img.get_region(r).save_png("%s/%s.png" % [out, tag])
	shots += 1


## Corre `secs` de juego y guarda una captura cada `every` s (etiquetadas tag_00, tag_01...).
func _clip(tag: String, secs: float, every: float, tick := Callable()) -> void:
	var t := 0.0
	var next := 0.0
	var n := 0
	while t < secs:
		if tick.is_valid():
			tick.call(t)
		if t >= next:
			await _shot("%s_%02d" % [tag, n])
			n += 1
			next += every
		await get_tree().process_frame
		t += get_process_delta_time()


func _run() -> void:
	for i in 40:  # deja pasar la pantalla de carga inicial
		await get_tree().process_frame
	# intro (la jefa se cae del cielo)
	_spawn()
	await _clip("intro", 2.2, 0.16)
	# idle
	boss.state = EnemyBoss.State.IDLE
	await _clip("idle", 1.4, 0.18)
	# walk
	await _clip("walk", 1.2, 0.15, func(_t): boss.velocity = Vector2(90, 0))
	boss.velocity = Vector2.ZERO
	# cada ataque: aviso (el temblor de offset.x lo emulo como el jefe) + suelta
	for atk in [&"atk_tiron", &"atk_salpicadura", &"atk_cruz", &"atk_charge", &"atk_fan"]:
		boss.state = EnemyBoss.State.IDLE
		await get_tree().process_frame
		boss._last_attack = atk
		boss.state = EnemyBoss.State.ATTACK
		boss.animated_sprite.play("attack")
		var tag := str(atk).trim_prefix("atk_")
		await _clip("atk_" + tag, 1.5, 0.15, func(t):
			boss.animated_sprite.offset.x = sin(t * 90.0) * 2.0 if t < 0.8 else 0.0
			if t >= 0.8 and atk == &"atk_charge":
				boss.velocity = Vector2(420, 0) if t < 1.3 else Vector2.ZERO)
		boss.velocity = Vector2.ZERO
	# agotada (tras su propio ataque: recupera el aliento) vs aturdida (la aturde el jugador: mareo)
	boss.state = EnemyBoss.State.IDLE
	await get_tree().process_frame
	boss._tire(2.0)
	await _clip("recover", 2.0, 0.2)
	boss.state = EnemyBoss.State.IDLE
	await get_tree().process_frame
	boss._stun(2.0)
	await _clip("tired", 2.0, 0.2)
	# tiron fallido: la tira queda pegada y forcejea
	boss.state = EnemyBoss.State.IDLE
	await get_tree().process_frame
	boss._last_attack = &"atk_tiron"
	boss.state = EnemyBoss.State.ATTACK
	boss.animated_sprite.play("attack")
	await _clip("tiron_fallo", 2.4, 0.15, func(t):
		boss.animated_sprite.offset.x = sin(t * 90.0) * 2.0 if t < 0.9 else 0.0
		if t >= 1.0 and boss.state == EnemyBoss.State.ATTACK:
			boss._tire(1.4))
	# reposo largo: parpadeo y gestos
	boss.state = EnemyBoss.State.IDLE
	await _clip("reposo_largo", 14.0, 0.5)
	# channel
	boss.state = EnemyBoss.State.IDLE
	boss._channeling = true
	await _clip("channel", 1.4, 0.16)
	boss._channeling = false
	# hurt
	boss.current_health -= 80.0
	await _clip("hurt", 0.6, 0.1)
	# fases 2 y 3: transicion de rabia y reposo
	for ph in [2, 3]:
		boss.current_phase = ph
		boss.state = EnemyBoss.State.TRANSITION
		await _clip("phase%d_rage" % ph, 0.7, 0.12)
		boss.state = EnemyBoss.State.IDLE
		await _clip("phase%d_idle" % ph, 0.9, 0.15)
		boss.state = EnemyBoss.State.TIRED
		await _clip("phase%d_tired" % ph, 0.9, 0.15)
		boss.state = EnemyBoss.State.IDLE
		boss._last_attack = &"atk_tiron"
		boss.state = EnemyBoss.State.ATTACK
		boss.animated_sprite.play("attack")
		await _clip("phase%d_atk" % ph, 0.9, 0.15, func(t): boss.animated_sprite.offset.x = sin(t * 90.0) * 2.0 if t < 0.6 else 0.0)
	# muerte
	boss.state = EnemyBoss.State.IDLE
	boss.set_physics_process(true)
	boss.die(null)
	await _clip("death", 1.35, 0.11)
	print("capturas: ", shots)
	get_tree().quit()
