extends RoomDynamic

## Pacto con la Hoja de Parra (sala de lore/descanso, una por piso como mucho, ~65% de las
## salas de lore). Su Pudorosidad ofrece poder a cambio de un costo; todo dura ~4 minutos
## (el resto del piso), nada es permanente, y puedes largarte sin pactar.
##   Recato   +30% dano          / el mundo se queda gris y el narrador calla
##   Escote   +35% cadencia      / te chupa el 30% de la vida que tengas (nunca te mata)
##   Perlas   +20% velocidad     / se queda con la mitad de tus monedas y te rompe el escudo
## PACTO MAYOR (a veces, mas en la 2a etapa de un reino): una maldicion de TODA la partida a cambio
## de mas botin. Va por las claves de Censura (Censura.PACT_CURSES: mult()/has()), maximo 2 por
## partida, y se ofrece como opcion 4 (antes de largarse), asi la primera opcion sigue siendo corta.
## Bot: primera opcion de cualquier eleccion; si pacta con el Recato, lo unico que cambia
## es el color y que el narrador calla.

const SECS := 240.0
const MAJOR_CHANCE := 0.22        # probabilidad de ofrecerlo en la 1a etapa de un reino
const MAJOR_CHANCE_STAGE2 := 0.6  # y en la 2a
const CHEST_SCENE := preload("res://src/items/chest.tscn")
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
	var opts := [tr("RM_PACT_1"), tr("RM_PACT_2"), tr("RM_PACT_3")]
	var curse := _roll_curse()
	if curse != "":
		opts.append(tr("RM_PACT_MAJOR") % [Censura.curse_name(curse), Censura.curse_curse(curse), Censura.curse_prize(curse)])
		Narrator.say("pm_offer")
	opts.append(tr("RM_PACT_NO"))
	Narrator.choose(tr("RM_PACT_Q"), opts)
	var pick: int = await Narrator.chosen
	if not is_instance_valid(self):
		return
	if curse != "" and pick == 3:
		_seal_major(curse)
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


## Maldicion que se ofrece ahora ("" = ninguna): no en la partida del dia (todos juegan lo mismo),
## solo si caben mas pactos mayores, y con mas probabilidad en la 2a etapa.
func _roll_curse() -> String:
	if rm().daily_mode:
		return ""
	var left := Censura.available_curses()
	if left.is_empty():
		return ""
	var p := MAJOR_CHANCE_STAGE2 if RunManager.floor_stage(rm().current_floor) >= 2 else MAJOR_CHANCE
	if RNG.randf() >= p:
		return ""
	return left[RNG.randi_range(0, left.size() - 1)]


## Sella el pacto mayor: la maldicion queda en Censura hasta que acabe la partida; el premio de
## claves (coin_drop) ya va incluido, y los cofres de regalo se sueltan aqui.
func _seal_major(id: String) -> void:
	if not Censura.add_curse(id):
		_close()
		return
	var cofres := int(Censura.PACT_CURSES[id].get("cofres", 0))
	for i in cofres:
		var c := CHEST_SCENE.instantiate()
		c.contents = "weapon" if i == 0 else ""
		var want := (_it.position if _it != null else center()) + Vector2(-70 - 60 * i, 20)
		var spot := RoomUtil.free_spot(main, room, want, 26.0)
		c.position = RoomUtil.loot_spot(room, want, [], null, 48.0) if spot == Vector2.INF else spot  # que no caiga en un muro o un hueco
		room.pickups_node.add_child.call_deferred(c)
	Sound.play("puzzle_solve")
	toast(tr("RM_PACT_MAJOR_T"), tr("RM_PACT_MAJOR_D") % Censura.curse_name(id), "ff5a7a")
	Narrator.say("pm_done")
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
