extends RoomDynamic

## Vendedor ambulante con la ruleta del preservativo (sala de descanso, ~55%; una por piso).
## Apuestas monedas a doble o nada: 40% sale intacto (ganas lo apostado), 6% sale con "premio
## gordo" (ganas el doble) y 54% sale pinchado (lo pierdes). Hasta 3 giros y el vendedor se
## marcha. La primera opcion del menu es la apuesta pequena (lo que elige el bot).

const SPINS := 3
const INTERACTABLE := preload("res://src/items/interactable.gd")

var _it: Node2D
var _spins := 0
var _busy := false


func start() -> void:
	var spot := RoomUtil.free_spot(main, room, center() + Vector2(-150, -20), 30.0)
	if spot == Vector2.INF:
		spot = RoomUtil.free_spot(main, room, center() + Vector2(150, -20), 30.0)
	if spot == Vector2.INF:
		return
	_it = INTERACTABLE.new()
	_it.position = spot
	_it.set("prompt_text", tr("RM_ROUL_PROMPT"))
	_it.add_child(_vendor())
	_it.connect("used", _menu)
	room.props_node.add_child.call_deferred(_it)
	LightKit.add_contact_shadow(_it, 24.0, 4.0)
	Narrator.say_first("rm_roulette")


## Un bicho del piso con gabardina (de las de abrirse) y un carrito con la ruleta.
func _vendor() -> Node2D:
	var n := Node2D.new()
	var fd: Dictionary = rm().floor_data()
	var roster: Array = fd.get("roster", [])
	var frames: String = main._frames_path(str(roster[0])) if not roster.is_empty() else ""
	if frames != "" and ResourceLoader.exists(frames):
		var spr := AnimatedSprite2D.new()
		spr.sprite_frames = load(frames)
		spr.play("idle")
		spr.offset = Vector2(0, -22)
		spr.scale = Vector2(1.1, 1.1)
		n.add_child(spr)
	var coat := Polygon2D.new()
	coat.polygon = PackedVector2Array([Vector2(-15, -26), Vector2(15, -26), Vector2(19, 6), Vector2(-19, 6)])
	coat.color = Color(0.22, 0.17, 0.2)
	n.add_child(coat)
	var lapel := Polygon2D.new()
	lapel.polygon = PackedVector2Array([Vector2(-4, -26), Vector2(4, -26), Vector2(8, 6), Vector2(-8, 6)])
	lapel.color = Color(0.85, 0.5, 0.65)
	n.add_child(lapel)
	var hat := Polygon2D.new()
	hat.polygon = PackedVector2Array([Vector2(-14, -38), Vector2(14, -38), Vector2(10, -48), Vector2(-10, -48)])
	hat.color = Color(0.16, 0.12, 0.14)
	n.add_child(hat)
	var cart := _Cart.new()
	cart.position = Vector2(34, 2)
	n.add_child(cart)
	return n


func _menu(_pl: Node) -> void:
	if finished or _busy:
		return
	var c: int = rm().coins
	var d := RunManager.depth_i(rm().current_floor)
	var small := mini(c, 4 + 2 * d)
	var big := mini(c, 10 + 4 * d)
	var opts: Array = []
	var bets: Array[int] = []
	if small >= 2:
		opts.append(tr("RM_ROUL_BET") % small)
		bets.append(small)
		if big > small:
			opts.append(tr("RM_ROUL_BET_BIG") % big)
			bets.append(big)
	opts.append(tr("RM_ROUL_PASS"))
	Narrator.say("rm_roulette_ask")
	Narrator.choose(tr("RM_ROUL_Q") % c if small >= 2 else tr("RM_ROUL_Q_POOR"), opts)
	_busy = true
	var pick: int = await Narrator.chosen
	_busy = false
	if not is_instance_valid(self) or pick >= bets.size():
		return
	_spin(bets[pick])


func _spin(bet: int) -> void:
	_spins += 1
	var r := randf()
	rm().add_coins(-bet)
	var pos: Vector2 = (_it.global_position if _it != null else player().global_position) + Vector2(0, -60)
	if r < 0.40:
		rm().add_coins(bet * 2)
		RoomUtil.popup(pos, "+%d $" % bet, RoomUtil.GOLD)
		Sound.play("puzzle_solve")
		toast(tr("RM_ROUL_WIN_T"), tr("RM_ROUL_WIN") % bet, "9be88a")
		Narrator.say("rm_roulette_win")
	elif r < 0.46:
		rm().add_coins(bet * 3)
		RoomUtil.popup(pos, "+%d $$$" % (bet * 2), RoomUtil.GOLD)
		Sound.play("room_clear")
		toast(tr("RM_ROUL_JACKPOT_T"), tr("RM_ROUL_JACKPOT") % (bet * 2), "ffd75a")
		Narrator.say("rm_roulette_jackpot")
	else:
		RoomUtil.popup(pos, "-%d $" % bet, Color("ff6b6b"))
		Sound.play("poor")
		toast(tr("RM_ROUL_LOSE_T"), tr("RM_ROUL_LOSE") % bet, "ff6b6b")
		Narrator.say("rm_roulette_lose")
	if _spins >= SPINS:
		finished = true
		room.set_meta("dyn_done", true)
		toast(tr("RM_ROUL_BYE_T"), tr("RM_ROUL_BYE"), "ffd75a")
		_it.call("finish")
		var tw := _it.create_tween()
		tw.tween_interval(1.0)
		tw.tween_property(_it, "modulate:a", 0.0, 0.8)
		tw.tween_callback(_it.queue_free)


## Carrito con la ruleta de preservativos (gira despacio).
class _Cart extends Node2D:
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(-18, -10, 36, 14), Color(0.45, 0.28, 0.15))
		draw_rect(Rect2(-18, -10, 36, 3), Color(0.65, 0.42, 0.22))
		draw_circle(Vector2(-12, 6), 4.0, Color(0.15, 0.1, 0.08))
		draw_circle(Vector2(12, 6), 4.0, Color(0.15, 0.1, 0.08))
		var c := Vector2(0, -22)
		draw_circle(c, 12.0, Color(0.95, 0.88, 0.75))
		for i in 6:
			var a := _t * 1.2 + TAU * i / 6.0
			draw_line(c, c + Vector2.from_angle(a) * 11.0, Color(0.9, 0.35, 0.55) if i % 2 == 0 else Color(0.35, 0.7, 0.9), 2.0)
		draw_arc(c, 12.0, 0.0, TAU, 20, Color(0.2, 0.12, 0.1), 1.5)
		draw_colored_polygon(PackedVector2Array([Vector2(0, -36), Vector2(4, -31), Vector2(-4, -31)]), Color(0.95, 0.8, 0.2))
