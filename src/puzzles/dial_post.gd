extends "res://src/items/interactable.gd"

## Rueda numerica del candado del diario: E la avanza (0-9, y vuelve a 0). Sin colision.
## El numero se ve por la ventanita; los puntitos de arriba dicen que rueda es (1, 2 o 3).

signal turned(dial: Node)

var index := 0
var digit := 0
var _spr: Sprite2D
var _num: Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # el jugador
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	shape.shape.radius = 17.0
	add_child(shape)
	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/sprites/environment/puzzles/dial_post.png")
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.position = Vector2(0, -8)
	_spr.use_parent_material = true
	add_child(_spr)
	_num = Label.new()
	_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_num.size = Vector2(16, 14)
	_num.position = Vector2(-8, -15)
	HudStyle.style_label(_num, 12, Color("ffd75a"), true)
	_num.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_num.use_parent_material = true
	add_child(_num)
	for i in index + 1:  # puntitos: que rueda es
		var d := ColorRect.new()
		d.color = Color("e0525a")
		d.size = Vector2(2, 2)
		d.position = Vector2(-(index * 4.0) / 2.0 - 1.0 + i * 4.0, -32)
		add_child(d)
	super()
	_show()


func set_digit(v: int) -> void:
	digit = posmod(v, 10)
	_show()


func _show() -> void:
	if _num:
		_num.text = str(digit)


func _use(_player: Node) -> void:
	set_digit(digit + 1)
	_spr.scale = Vector2(1.15, 0.9)
	_spr.create_tween().tween_property(_spr, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	turned.emit(self)
