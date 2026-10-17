extends "res://src/items/interactable.gd"
class_name LockedChest

## Cofre con candado de una mision de llave. Se abre con E llevando la llave de su clase
## (o la maestra). El cinturon de castidad es el mismo cofre con otra cerradura.

var quest: Node
var kind := "crystal"
var opened := false
var _spr: Sprite2D
var _lock: Sprite2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 34.0
	add_child(shape)
	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/sprites/environment/chest_closed.png")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)
	ActorFx.setup_object(self, _spr)
	_lock = Sprite2D.new()
	_lock.texture = PuzzlePlate.load_tex("belt_lock" if kind == "belt" else "padlock_%s" % kind)
	_lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lock.position = Vector2(0, -2)
	_lock.z_index = 1
	add_child(_lock)
	super()


func _prompt_text() -> String:
	if opened:
		return ""
	if quest and quest.can_open(kind):
		return "[b]%s[/b]\n[color=#b08d4a]%s[/color]" % [tr("PZ_CHEST_%s" % kind.to_upper()), tr("PZ_CHEST_OPEN")]
	return "[b]%s[/b]\n[font_size=13]%s[/font_size]" % [tr("PZ_CHEST_%s" % kind.to_upper()), tr("PZ_CHEST_%s_LOCKED" % kind.to_upper())]


func _use(player: Node) -> void:
	if opened or quest == null:
		return
	if not quest.try_open(player, self):
		var tw := create_tween()
		for i in 4:
			tw.tween_property(_spr, "position:x", 3.0 if i % 2 == 0 else -3.0, 0.04)
		tw.tween_property(_spr, "position:x", 0.0, 0.04)
		return
	opened = true
	finish()
	_lock.visible = false
	_spr.texture = load("res://assets/sprites/environment/chest_open.png")
	Sound.play("chest")
	var f := ActorFx.make_flash(Color(1.0, 0.85, 0.45, 0.55), 0.7)
	f.position = Vector2(0, -6)
	add_child(f)
	var ft := f.create_tween().set_parallel(true)
	ft.tween_property(f, "scale", Vector2.ONE * 1.8, 0.35).set_ease(Tween.EASE_OUT)
	ft.tween_property(f, "modulate:a", 0.0, 0.35)
	ft.chain().tween_callback(f.queue_free)
