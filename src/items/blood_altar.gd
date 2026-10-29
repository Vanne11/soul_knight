extends "res://src/items/interactable.gd"
class_name BloodAltar

## Altar de la llave de sangre: E deja una parte de tu vida en el cuenco y a cambio sale la
## llave. No se explica el precio: lo dice el cuadro de interaccion (es el mismo cuadro de
## cualquier objeto). Si la llave se seca, el altar vuelve a pedir sangre.

const COST_FRACTION := 0.3

var quest: Node
var armed := true
var _spr: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 34.0
	add_child(shape)
	_spr = Sprite2D.new()
	_spr.texture = PuzzlePlate.load_tex("altar_blood")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	ActorFx.setup_object(self, _spr)
	TallProp.attach(self, TallProp.box_of(_spr))
	ActorFx.add_item_glow(self, _spr, Color("c0283a"), 0.6, 0.5)
	super()


func cost() -> float:
	return roundf(get_node("/root/PlayerStats").max_health * COST_FRACTION)


func set_armed(v: bool) -> void:
	armed = v
	_spr.modulate = Color.WHITE if v else Color(0.5, 0.4, 0.4)
	refresh_prompt()


func _prompt_text() -> String:
	if not armed:
		return "[b]%s[/b]" % tr("PZ_ALTAR_DRY")
	return "[b]%s[/b]\n[font_size=13]%s[/font_size]\n[color=#b08d4a]%s[/color]" % [
		tr("PZ_ALTAR_NAME"), tr("PZ_ALTAR_COST") % int(cost()), tr("PZ_ALTAR_GIVE")]


func _use(player: Node) -> void:
	if not armed or quest == null:
		return
	var ps = get_node("/root/PlayerStats")
	if ps.current_health <= cost() + 1.0:
		get_node("/root/GlobalEvents").show_floating_text.emit(global_position + Vector2(0, -40), tr("PZ_ALTAR_WEAK"), Color("ff7a8a"))
		return
	if not quest.take_key(player, self):
		return  # no entrego la llave: no se cobra la sangre
	# la sangre se descuenta a pelo (sin pasar por el dano: ni escudos ni modo dios la libran)
	ps.current_health = maxf(1.0, ps.current_health - cost())
	ps.health_changed.emit(ps.current_health, ps.max_health)
	Sound.play("hurt")
	get_node("/root/GlobalEvents").show_floating_text.emit(player.global_position + Vector2(0, -40), "-%d" % int(cost()), Color("c0283a"))
