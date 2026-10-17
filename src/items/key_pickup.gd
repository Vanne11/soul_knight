extends "res://src/items/interactable.gd"
class_name KeyPickup

## Llave de una mision de llave (KeyQuests). Mientras la custodian (enemigos vivos) sale con
## un candado encima y no se puede coger. Coger la llave no pasa por el inventario normal:
## la mision la lleva (y decide cuando se pierde y vuelve aqui).

var quest: Node
var kind := "crystal"
var locked := true
var _spr: Sprite2D
var _lock: Sprite2D
var _tw: Tween


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 26.0
	add_child(shape)
	_spr = Sprite2D.new()
	_spr.texture = KeyQuests.key_tex(kind)
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2(1.4, 1.4)
	add_child(_spr)
	ActorFx.setup_object(self, _spr, false, 0.3)
	ActorFx.add_item_glow(self, _spr, KeyQuests.key_color(kind), 0.5, 0.45)
	_lock = Sprite2D.new()
	_lock.texture = PuzzlePlate.load_tex("padlock_%s" % kind)
	_lock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lock.position = Vector2(0, 2)
	_lock.z_index = 1
	add_child(_lock)
	super()
	_tw = create_tween().set_loops()
	_tw.tween_property(_spr, "position:y", -6.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(_spr, "position:y", 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_apply_lock()


func set_locked(v: bool) -> void:
	if v == locked:
		return
	locked = v
	_apply_lock()
	if not v:
		Sound.play("locked", 0.0)
		var f := ActorFx.make_flash(Color(1.0, 0.9, 0.5, 0.6), 0.8)
		add_child(f)
		var ft := f.create_tween().set_parallel(true)
		ft.tween_property(f, "scale", Vector2.ONE * 1.6, 0.4)
		ft.tween_property(f, "modulate:a", 0.0, 0.4)
		ft.chain().tween_callback(f.queue_free)


func _apply_lock() -> void:
	if _spr == null:
		return
	_lock.visible = locked
	_spr.modulate = Color(0.55, 0.55, 0.6) if locked else Color.WHITE
	set_deferred("monitoring", not locked)
	if locked and _player != null:
		_player = null
		Narrator.clear_prompt(self)


func _prompt_text() -> String:
	return "[b]%s[/b]\n[font_size=13]%s[/font_size]\n[color=#b08d4a]%s[/color]" % [
		tr("PZ_KEY_%s_NAME" % kind.to_upper()), tr("PZ_KEY_%s_DESC" % kind.to_upper()), tr("PICKUP_TAKE")]


func _use(player: Node) -> void:
	if locked or quest == null:
		return
	if quest.take_key(player, self):
		finish()
		queue_free()
	else:
		# se escurre / no se deja coger: sacudida
		var tw := create_tween()
		for i in 4:
			tw.tween_property(_spr, "position:x", 4.0 if i % 2 == 0 else -4.0, 0.04)
		tw.tween_property(_spr, "position:x", 0.0, 0.04)
