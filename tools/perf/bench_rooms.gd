extends Node
## Benchmark de rendimiento (no es el bot: no juega). Genera un piso y entra a cada sala midiendo
## el tiron de _enter_room y el frame medio ahi. Con --fixed-fps el motor no duerme: el tiempo real
## por frame es el coste de CPU.
## CPU (headless):
##   XDG_DATA_HOME=<tmp> godot --headless --audio-driver Dummy --fixed-fps 60 --path . \
##     res://tools/perf/bench_rooms.tscn -- --seed=42 --floor=1 --frames=120 [--blame=1] [--advance=3]
## GPU (ventana, sin vsync): ... --audio-driver Dummy --resolution 1920x1080 --path . \
##     res://tools/perf/bench_rooms.tscn -- --gpu=1 --quality=0 [--gpublame=1] --bot
##   --blame: apaga cada sistema y mide lo que baja el frame.  --gpublame: en la 1a sala oscura,
##   prueba presupuestos de luces/sombras y calidades.  --advance=N: mide N cambios de piso.

const MAIN_SCENE := "res://src/scenes/main.tscn"


func _arg(prefix: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.trim_prefix(prefix)
	return def


func _ready() -> void:
	DebugMenu.god_mode = true
	var gpu := _arg("--gpu=", "") != ""
	if gpu:  # en ventana: sin vsync ni tope, y el tiempo de GPU del viewport
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if _arg("--quality=", "") != "":
		Settings._set_quality(int(_arg("--quality=", "0")))
	var seed := int(_arg("--seed=", "42"))
	var floor_n := int(_arg("--floor=", "0"))
	var frames := int(_arg("--frames=", "120"))
	RunManager.test_seed = seed
	var rm: RunManager = get_node("/root/GameController").get_run_manager()
	rm.start_new_run(seed)
	if floor_n > 0:
		rm.current_floor = floor_n
	var t0 := Time.get_ticks_usec()
	var main: Node = load(MAIN_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await main.ready
	print("[bench] piso=%d generar=%.1f ms" % [rm.current_floor, (Time.get_ticks_usec() - t0) / 1000.0])
	for i in 10:
		await get_tree().process_frame
	for k in int(_arg("--advance=", "0")):
		var ta := Time.get_ticks_usec()
		main._advance_to_next_floor()
		print("[bench] cambio a piso %d = %.1f ms" % [rm.current_floor, (Time.get_ticks_usec() - ta) / 1000.0])
		for i in 5:
			await get_tree().process_frame
	var rooms: Array = main.dungeon_generator.rooms.values()
	var worst := 0.0
	var sum_frame := 0.0
	for room in rooms:
		if not is_instance_valid(room) or room == main.current_room:
			continue
		var t := Time.get_ticks_usec()
		main._enter_room(room)
		var enter_ms := (Time.get_ticks_usec() - t) / 1000.0
		# primer frame tras entrar (spawns diferidos, call_deferred, etc.)
		t = Time.get_ticks_usec()
		await get_tree().process_frame
		var first_ms := (Time.get_ticks_usec() - t) / 1000.0
		var acc := 0.0
		var peak := 0.0
		var gpu_acc := 0.0
		var tf := Time.get_ticks_usec()
		for f in frames:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			var ms := (now - tf) / 1000.0
			tf = now
			acc += ms
			peak = maxf(peak, ms)
			if gpu:
				gpu_acc += RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())
		var avg := acc / frames
		if gpu:
			print("[gpu] sala %s oscura=%s gpu=%.2f ms  frame=%.2f ms  luces=%d" % [room.grid_pos, room.get("is_dark"), gpu_acc / frames, avg, get_tree().get_nodes_in_group(LightKit.GROUP_DARK).filter(func(l): return l is Light2D and l.enabled and l.is_visible_in_tree()).size()])
		sum_frame += avg
		worst = maxf(worst, enter_ms)
		print("[bench] sala %s tipo=%d entrar=%.1f ms  1er_frame=%.1f ms  frame_medio=%.2f ms  pico=%.1f ms  enemigos=%d  nodos=%d" % [
			room.grid_pos, room.room_type, enter_ms, first_ms, avg, peak,
			get_tree().get_nodes_in_group("enemy").size(), get_tree().get_node_count()])
	if gpu:
		print("[gpu] FIN quality=%d metodo=%s" % [Settings.quality, ProjectSettings.get_setting("rendering/renderer/rendering_method")])
	print("[bench] FIN salas=%d peor_entrada=%.1f ms frame_medio_global=%.2f ms" % [rooms.size(), worst, sum_frame / maxf(1.0, rooms.size() - 1)])
	if _arg("--gpublame=", "") != "":
		await _gpu_blame(main, rooms, frames)
	if _arg("--blame=", "") != "":
		await _blame(main, frames)
	get_tree().quit()


## Tiempo real medio por frame (con --fixed-fps el motor no duerme: es el coste de CPU).
func _wall(frames: int) -> float:
	await get_tree().process_frame
	var t := Time.get_ticks_usec()
	for f in frames:
		await get_tree().process_frame
	return (Time.get_ticks_usec() - t) / 1000.0 / frames


## Apaga un sistema a la vez y mide cuanto baja el frame.
func _blame(main: Node, frames: int) -> void:
	var buckets := {}
	for c in main.get_children():
		buckets["main/" + str(c.name)] = [c]
	for c in get_tree().root.get_children():
		if c != main and c != self:
			buckets["auto/" + str(c.name)] = [c]
	buckets["grupo enemy"] = get_tree().get_nodes_in_group("enemy")
	var base: float = await _wall(frames)
	print("[blame] base=%.2f ms/frame" % base)
	var res := []
	for k in buckets:
		var saved := []
		for n in buckets[k]:
			if is_instance_valid(n):
				saved.append([n, n.process_mode])
				n.process_mode = Node.PROCESS_MODE_DISABLED
		var ms: float = await _wall(frames)
		for pair in saved:
			if is_instance_valid(pair[0]):
				pair[0].process_mode = pair[1]
		res.append([base - ms, k, ms])
	res.sort_custom(func(a, b): return a[0] > b[0])
	for r in res.slice(0, 15):
		print("[blame] -%.2f ms  sin %s (%.2f)" % [r[0], r[1], r[2]])


func _gpu_ms(frames: int) -> Vector2:
	var rid := get_viewport().get_viewport_rid()
	for i in 10:
		await get_tree().process_frame
	var g := 0.0
	var t := Time.get_ticks_usec()
	for f in frames:
		await get_tree().process_frame
		g += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	return Vector2(g / frames, (Time.get_ticks_usec() - t) / 1000.0 / frames)


## En la primera sala oscura: apaga una cosa a la vez y mide GPU y frame.
func _gpu_blame(main: Node, rooms: Array, frames: int) -> void:
	var dark: Room = null
	for r in rooms:
		if r.is_dark and r.room_type != Room.RoomType.BOSS:
			dark = r
			break
	if dark == null:
		return
	main._enter_room(dark)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.process_mode = Node.PROCESS_MODE_DISABLED  # la sala quieta: misma escena en cada medida
	var lights: Array = get_tree().get_nodes_in_group(LightKit.GROUP_DARK).filter(func(l): return l is PointLight2D)
	var lit := lights.filter(func(l): return l.enabled)
	var shad := lights.filter(func(l): return l.shadow_enabled)
	print("[gblame] sala %s luces=%d con_sombra=%d" % [dark.grid_pos, lit.size(), shad.size()])
	var base: Vector2 = await _gpu_ms(frames)
	print("[gblame] base gpu=%.2f frame=%.2f" % [base.x, base.y])
	var sfx := main.get_children().filter(func(c): return c is ScreenFx)
	var wfx := main.get_children().filter(func(c): return c is WorldFx)
	var ppos: Vector2 = main.player.global_position
	lights.sort_custom(func(x, y): return x.global_position.distance_to(ppos) / maxf(x.texture_scale, 0.2) < y.global_position.distance_to(ppos) / maxf(y.texture_scale, 0.2))
	var orig := lights.map(func(l): return [l.enabled, l.shadow_enabled, l.shadow_filter])
	var restore := func():
		main._lighting.process_mode = Node.PROCESS_MODE_INHERIT
		for i in lights.size():
			lights[i].enabled = orig[i][0]
			lights[i].shadow_enabled = orig[i][1]
			lights[i].shadow_filter = orig[i][2]
	var cfg := func(n_l: int, n_s: int, f: int):
		main._lighting.process_mode = Node.PROCESS_MODE_DISABLED  # que el presupuesto no lo deshaga
		var sh := 0
		for i in lights.size():
			var l: PointLight2D = lights[i]
			l.enabled = orig[i][0] and i < n_l
			var want: bool = l.enabled and l.get_meta("base_shadow", false) and sh < n_s
			if want: sh += 1
			l.shadow_enabled = want
			l.shadow_filter = f
	var P13 := Light2D.SHADOW_FILTER_PCF13
	var P5 := Light2D.SHADOW_FILTER_PCF5
	var setq := func(q: int):
		Settings._set_quality(q)
		main._lighting._apply_light_budget()
	var q0: int = Settings.quality
	# cada prueba se mide entre dos bases (la APU se calienta y el frame deriva)
	var tests := {
		"calidad media": func(on): setq.call(1 if on else q0),
		"calidad baja": func(on): setq.call(2 if on else q0),
		"luces=12 sombras=4 PCF13": func(on): cfg.call(12, 4, P13) if on else restore.call(),
		"luces=12 sombras=0": func(on): cfg.call(12, 0, P5) if on else restore.call(),
		"luces=4 sombras=0": func(on): cfg.call(4, 0, P5) if on else restore.call(),
		"sin ScreenFx": func(on): for c in sfx: c.visible = not on,
		"sin WorldFx": func(on): for c in wfx: c.visible = not on,
	}
	for k in tests:
		var b1: Vector2 = await _gpu_ms(frames)
		tests[k].call(true)
		var m: Vector2 = await _gpu_ms(frames)
		tests[k].call(false)
		var b2: Vector2 = await _gpu_ms(frames)
		var b := (b1 + b2) * 0.5
		print("[gblame] %-24s gpu=%.2f vs %.2f (%+.2f)  frame=%.2f vs %.2f (%+.2f)" % [k, m.x, b.x, m.x - b.x, m.y, b.y, m.y - b.y])
	var again: Vector2 = await _gpu_ms(frames)
	print("[gblame] base otra vez gpu=%.2f frame=%.2f" % [again.x, again.y])
