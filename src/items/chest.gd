extends Area2D

## Cofre: se abre al tocarlo y suelta un arma o botin. contents="weapon" fuerza arma.

const ITEM_PICKUP_SCENE := preload("res://src/items/item_pickup.tscn")
var contents: String = ""
var _opened := false

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	RoomUtil.settle(self)
	if ResourceLoader.exists("res://assets/sprites/environment/chest_closed.png"):
		sprite.texture = load("res://assets/sprites/environment/chest_closed.png")
	ActorFx.setup_object(self, sprite)
	ActorFx.add_item_glow(self, sprite, Color(1.0, 0.8, 0.35), 0.55, 0.6)

func _on_body_entered(body: Node) -> void:
	if _opened or not body.is_in_group("player"):
		return
	_opened = true
	var main := get_tree().get_first_node_in_group("main")
	# el azar se tira ya (mismo orden de RNG que antes); solo la entrega espera el temblor
	var id: String = main._random_weapon_id() if contents == "weapon" or RNG.randf() < 0.5 else main._random_loot_id()
	await _shake_then_flash()
	if not is_inside_tree():
		return
	var tex := "res://assets/sprites/environment/chest_open.png"
	if ResourceLoader.exists(tex):
		sprite.texture = load(tex)
	var p := ITEM_PICKUP_SCENE.instantiate()
	p.item_id = id
	p.position = position + Vector2(0, 40)
	var room := RoomUtil.room_of(self)
	if room != null:
		p.position = RoomUtil.loot_spot(room, p.position)  # que no caiga en un muro o un hueco
	get_parent().add_child.call_deferred(p)
	Sound.play("chest")

## Temblor corto (0.25 s) y destello al abrirse. Solo presentacion.
func _shake_then_flash() -> void:
	var base := sprite.position
	var tw := create_tween()
	for i in 6:
		var amp := 2.5 * (1.0 - i / 8.0)
		tw.tween_property(sprite, "position:x", base.x + (amp if i % 2 == 0 else -amp), 0.04)
	tw.tween_property(sprite, "position:x", base.x, 0.01)
	await tw.finished
	if not is_inside_tree():
		return
	var f := ActorFx.make_flash(Color(1.0, 0.85, 0.45, 0.55), 0.7)
	f.position = sprite.position + Vector2(0, -6)
	add_child(f)
	var ft := f.create_tween().set_parallel(true)
	ft.tween_property(f, "scale", Vector2.ONE * 1.8, 0.35).set_ease(Tween.EASE_OUT)
	ft.tween_property(f, "modulate:a", 0.0, 0.35)
	ft.chain().tween_callback(f.queue_free)
	sprite.scale *= Vector2(1.12, 0.9)  # saltito al abrir
	create_tween().tween_property(sprite, "scale", sprite.scale / Vector2(1.12, 0.9), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
