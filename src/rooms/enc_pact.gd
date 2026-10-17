extends RoomDynamic

## Pacto con la Hoja de Parra (sala de lore/descanso, una por piso como mucho, ~65% de las
## salas de lore). Su Pudorosidad ofrece poder a cambio de un costo; todo dura ~4 minutos
## (el resto del piso), nada es permanente, y puedes largarte sin pactar.
##   Recato   +30% dano          / el mundo se queda gris y el narrador calla
##   Escote   +35% cadencia      / te chupa el 30% de la vida que tengas (nunca te mata)
##   Perlas   +20% velocidad     / se queda con la mitad de tus monedas y te rompe el escudo
## Bot: primera opcion de cualquier eleccion; si pacta con el Recato, lo unico que cambia
## es el color y que el narrador calla.

const SECS := 240.0
const INTERACTABLE := preload("res://src/items/interactable.gd")

var _npc: Node2D
var _it: Node2D


func start() -> void:
	var spot := RoomUtil.free_spot(main, room, center() + Vector2(150, -30), 30.0)
	if spot == Vector2.INF:
		spot = RoomUtil.free_spot(main, room, center() + Vector2(-150, -30), 30.0)
	if spot == Vector2.INF:
		return
	_it = INTERACTABLE.new()
	_it.position = spot
	_it.set("prompt_text", tr("RM_PACT_PROMPT"))
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = load("res://assets/sprites/enemies/hoja_de_parra_sprite_frames.tres")
	spr.play("idle")
	spr.scale = Vector2(0.62, 0.62)
	spr.offset = Vector2(0, -52)
	_it.add_child(spr)
	ActorFx.add_glow(_it, Color(0.5, 1.0, 0.55), 0.8, 1.0).position = Vector2(0, -30)
	_it.connect("used", _ask)
	room.props_node.add_child.call_deferred(_it)
	_npc = _it
	LightKit.add_contact_shadow(_it, 22.0, 4.0)
	Narrator.say_first("rm_pact")


func _ask(_pl: Node) -> void:
	if finished:
		return
	Narrator.say("rm_pact_offer")
	var opts := [tr("RM_PACT_1"), tr("RM_PACT_2"), tr("RM_PACT_3"), tr("RM_PACT_NO")]
	Narrator.choose(tr("RM_PACT_Q"), opts)
	var pick: int = await Narrator.chosen
	if not is_instance_valid(self):
		return
	match pick:
		0:
			ps().apply_item_effect({"type": 11, "stat": "damage", "magnitude": 1.3, "duration": SECS})
			director.pact_start_gray(SECS)
		1:
			ps().apply_item_effect({"type": 11, "stat": "fire_rate", "magnitude": 1.35, "duration": SECS})
			var cost: float = maxf(0.0, ps().current_health * 0.3)
			ps().current_health = maxf(1.0, ps().current_health - cost)
			ps().health_changed.emit(ps().current_health, ps().max_health)
		2:
			ps().apply_item_effect({"type": 11, "stat": "speed", "magnitude": 1.2, "duration": SECS})
			rm().add_coins(-int(rm().coins / 2))
			ps().current_shields = 0.0
			ps().shields_changed.emit(ps().current_shields, ps().max_shields)
		_:
			Narrator.say("rm_pact_no")
			toast(tr("RM_PACT_NO_T"), tr("RM_PACT_NO_D"), "9be88a")
			_close()
			return
	Sound.play("puzzle_solve")
	toast(tr("RM_PACT_DONE_T"), tr("RM_PACT_DONE_%d" % (pick + 1)), "c08cff")
	Narrator.say("rm_pact_done")
	_close()


func _close() -> void:
	finished = true
	room.set_meta("dyn_done", true)
	if _it != null and is_instance_valid(_it):
		_it.call("finish")
		var tw := _it.create_tween()
		tw.tween_interval(1.2)
		tw.tween_property(_it, "modulate:a", 0.0, 1.0)
		tw.tween_callback(_it.queue_free)
