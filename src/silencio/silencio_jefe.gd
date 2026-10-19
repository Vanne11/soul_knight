class_name SilencioJefe
extends SilencioSala

## SALA DEL JEFE de Las Tierras del Silencio: la arena de "El Pacto de Silencio" (diseno_E3, secciones 5.3 y
## 5.8). Reemplaza a SilencioJefeHueco. Circulo de 16x12 tiles con 5 OBJETOS DE RUIDO en el borde (2
## campanas colgantes, 2 ollas sobre un tendedero y 1 vidrio grande; SilencioRuido) y el Pacto en el
## centro (src/enemies/bosses/boss_pacto_silencio.gd).
##
## Al entrar: se sellan las puertas, las 3 luces del circulo quedan apagadas (tambien la que dejo S6 B: el
## diseno 5.5 pide las 3 apagadas en la fase 1) y sale una pista corta ("Golpea las campanas, las ollas y el
## vidrio."). El jefe nace 1,2 s despues.
##
## MUERTE sin violencia: el manto se levanta, las siluetas se ponen de pie y salen en silencio, cada una
## con una luz; el ambiente vuelve de golpe (primera vez en el reino); cartel "Se rompio el silencio.".
## SIN botin, SIN logro, SIN sello, SIN recompensa a elegir (el jefe no emite enemy_killed, asi que
## main._complete_floor no corre). Se abren las puertas: la de la derecha lleva a la sala de memoria (S7).
## Si el reino no es "wip" (publicado), aqui se libera (RunManager.liberate); en pruebas wip no, para no
## tocar la partida guardada.

const NOISE := [
	["campana", Vector2(150, 176)], ["campana", Vector2(874, 176)],
	["olla", Vector2(150, 640)], ["olla", Vector2(874, 640)],
	["vidrio", Vector2(512, 150)],
]
const SPAWN_AT := Vector2(512, 400)   # los pies del Pacto (local de la sala)
const HINT_SECS := 9.0

var _boss: EnemyBoss = null
var _won := false


func build() -> void:
	# tendedero: una cuerda corta sobre cada olla, con dos postes
	for n in NOISE:
		var p: Vector2 = n[1]
		if n[0] == "olla":
			_cord(p + Vector2(-46, -30), p + Vector2(46, -30), 6.0)
		elif n[0] == "campana":
			_cord(p + Vector2(0, -36), p + Vector2(0, -78), 0.0)  # la cuerda de la que cuelga
	for n in NOISE:
		var o := SilencioRuido.new()
		o.kind = n[0]
		o.position = n[1]
		room.props_node.add_child(o)
		_decor.append(o)


func _cord(a: Vector2, b: Vector2, post: float) -> void:
	var l := Line2D.new()
	l.points = PackedVector2Array([a, b])
	l.width = 2.0
	l.default_color = Color("3a3a44")
	room.props_node.add_child(l)
	_decor.append(l)
	if post > 0.0:
		for p in [a, b]:
			var pl := ColorRect.new()
			pl.color = Color("3a3a44")
			pl.position = p + Vector2(-2, 0)
			pl.size = Vector2(4, 36)
			room.props_node.add_child(pl)
			_decor.append(pl)


func start() -> void:
	Silencio.circle_show()
	for i in 3:
		Silencio.circle_set(i, false)  # fase 1: las 3 luces apagadas (el jefe las enciende)
	room.seal_doors()
	Silencio.hint(tr("SIL_JEFE_PISTA"))
	get_tree().create_timer(HINT_SECS).timeout.connect(func():
		if inside and not _won:
			Silencio.hint(""))
	get_tree().create_timer(1.2).timeout.connect(_spawn_boss)


func _spawn_boss() -> void:
	if _boss != null or _won or not is_inside_tree():
		return
	var rm := get_node("/root/RunManager")
	var region_n: int = RunManager.region_index(rm.current_floor) + 1  # el jefe escala por reino, como en main
	var info := {
		"enemy_type": "boss",
		"name": tr("SIL_JEFE_NOMBRE"),
		"health": EnemyBoss.health_for_floor(region_n) * Censura.mult("boss_health"),
		"damage": 12.0 + region_n * 4.0,
		"script": EnemyBoss.script_path("pacto_silencio"),
		"drops": [],  # SIN botin
	}
	var data: Array[Dictionary] = [info]
	room.spawn_enemies(data, false, [room.global_position + SPAWN_AT])
	await get_tree().process_frame
	await get_tree().process_frame
	for e in room.enemies_spawned:
		if is_instance_valid(e) and e is EnemyBoss:
			_boss = e
			_boss.defeated.connect(_victory)


func stop() -> void:
	Silencio.hint("")


## El jefe cayo (sin violencia): el manto se levanta y las siluetas salen con su luz.
func _victory(at: Vector2) -> void:
	if _won:
		return
	_won = true
	Silencio.hint("")
	room.unseal_doors()
	Silencio.cartel([tr("SIL_JEFE_FIN")], 4.0)
	# el ambiente vuelve de golpe, por primera vez en el reino
	room.set_meta("sil_light", 0.66)
	main._lighting.paint(room, false, false)
	var base := at - room.global_position
	# el bloque se levanta (animacion "death" del jefe) y, cuando queda la cortina alzada sobre las sillas vacias,
	# las 7 siluetas salen, cada una con una luz
	await get_tree().create_timer(1.3).timeout
	if not is_inside_tree():
		return
	var exit_x := size_px().x - 70.0
	for i in 7:
		var e := SilencioEnte.make(base + SilencioEnte.SEATS[i])
		e.modulate.a = 0.0
		room.props_node.add_child(e)
		_decor.append(e)
		e.carry_light()
		var l := LightKit.make_light(Color(1.0, 0.86, 0.55), 0.3, 0.9, false)
		l.remove_from_group(LightKit.GROUP_DARK)
		l.position = Vector2(0, -22)
		l.enabled = true
		e.add_child(l)
		create_tween().tween_property(e, "modulate:a", 1.0, 0.6)
		_leave(e, Vector2(exit_x - i * 22.0, size_px().y * 0.5 + (i - 3) * 38.0), 0.8 + i * 0.5)
	if not RunManager.wip_enabled:
		get_node("/root/RunManager").liberate(int(get_node("/root/RunManager").current_floor))


## La silueta espera su turno, camina sin prisa hacia la salida y se desvanece.
func _leave(f: SilencioEnte, to: Vector2, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(f):
		return
	var secs := f.position.distance_to(to) / 55.0
	f.go_to(to, secs, &"light")
	await get_tree().create_timer(maxf(0.1, secs - 1.0)).timeout
	if not is_instance_valid(f):
		return
	var tw := create_tween()
	tw.tween_property(f, "modulate:a", 0.0, 1.2)
	tw.tween_callback(f.queue_free)
