class_name ActorFx
extends RefCounted

## Ayudantes de sombra y brillo para actores, proyectiles y objetos (roadmap_nico 7, 8, 13-16).
## Se apoyan en LightKit; aqui solo se calcula donde ponerlo y se anima lo que se mueve.

## Sombra de contacto + marca de proyectada para un actor con AnimatedSprite2D.
## Se difiere un frame: room.gd cambia sprite_frames y scale despues de instanciar.
static func setup_actor(actor: Node2D, spr: AnimatedSprite2D, radius_mul := 0.3) -> void:
	_deferred_actor.call_deferred(actor, spr, radius_mul)


static func _deferred_actor(actor: Node2D, spr: AnimatedSprite2D, radius_mul: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(spr) or spr.sprite_frames == null:
		return
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, 0)
	if tex == null:
		return
	var radius := clampf(tex.get_width() * absf(spr.scale.x) * radius_mul, 9.0, 70.0)
	var foot := LightKit.foot_y(spr)
	LightKit.add_contact_shadow(actor, radius, foot)
	LightKit.mark_caster(actor, radius, foot)


## Sombra de contacto + marca de proyectada para un Sprite2D (objetos del suelo).
static func setup_object(obj: Node2D, spr: Sprite2D, cast := true, radius_mul := 0.35) -> void:
	if spr.texture == null:
		return
	var h := spr.texture.get_height() * absf(spr.scale.y)
	var foot := spr.position.y + (spr.offset.y if spr.centered else 0.0) * spr.scale.y + (h * 0.5 if spr.centered else h)
	var radius := clampf(spr.texture.get_width() * absf(spr.scale.x) * radius_mul, 6.0, 40.0)
	LightKit.add_contact_shadow(obj, radius, foot)
	if cast:
		LightKit.mark_caster(obj, radius, foot)


## Manchita desplazada hacia abajo (en pantalla) para leer la altura de un proyectil.
## El proyectil rota, asi que el desplazamiento y el giro se compensan.
static func add_projectile_shadow(proj: Node2D, radius: float, drop: float, alpha := 0.5) -> void:
	var s := Sprite2D.new()
	s.name = "BlobShadow"
	s.texture = LightKit.contact_texture()
	s.scale = Vector2(radius * 2.0 / 64.0, radius * 1.0 / 64.0)
	s.modulate.a = alpha
	s.show_behind_parent = true
	proj.add_child(s)
	_orient_shadow.call_deferred(proj, s, drop)


static func _orient_shadow(proj: Node2D, s: Sprite2D, drop: float) -> void:
	if not is_instance_valid(proj) or not is_instance_valid(s):
		return
	var rot := proj.global_rotation
	s.rotation = -rot
	s.position = Vector2(0, drop).rotated(-rot)


## Luz chica sin sombras que acompana a un proyectil o objeto. Solo luce en sala oscura.
static func add_glow(parent: Node2D, color: Color, energy: float, scale_: float) -> PointLight2D:
	var l := LightKit.make_light(color, energy, scale_, false)
	l.name = "Glow"
	parent.add_child(l)
	return l


## Destello aditivo, ignora las luces (no se oscurece en penumbra).
static func make_flash(color: Color, scale_: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = LightKit.light_texture()
	s.scale = Vector2.ONE * scale_
	s.modulate = color
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	s.material = mat
	return s


## Fogonazo: luz sin sombras + destello, se apagan solos.
static func muzzle_flash(parent: Node2D, local_pos: Vector2, color: Color) -> void:
	var holder := Node2D.new()
	holder.position = local_pos
	parent.add_child(holder)
	var l := add_glow(holder, color, 1.1, 0.7)
	var f := make_flash(Color(color, 0.85), 0.11)
	holder.add_child(f)
	var tw := holder.create_tween().set_parallel(true)
	tw.tween_property(l, "energy", 0.0, 0.09)
	tw.tween_property(f, "modulate:a", 0.0, 0.09)
	tw.tween_property(f, "scale", Vector2.ONE * 0.04, 0.09)
	tw.chain().tween_callback(holder.queue_free)


## Brillo de objeto: luz pulsante (solo en penumbra) + destello que centellea en el sprite.
static func add_item_glow(obj: Node2D, spr: Sprite2D, color: Color, energy := 0.55, scale_ := 0.55) -> void:
	var center := Vector2(0, spr.position.y + spr.offset.y)
	var l := add_glow(obj, color, energy, scale_)
	l.position = center
	var tw := l.create_tween().set_loops()
	tw.tween_property(l, "energy", energy * 1.35, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(l, "energy", energy * 0.7, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# centelleo pequeno cerca del sprite (visible tambien en sala clara, muy tenue)
	var sp := make_flash(Color(1, 0.95, 0.8, 0.0), 0.035)
	obj.add_child(sp)
	var stw := sp.create_tween().set_loops()
	stw.tween_interval(randf_range(0.2, 2.2))
	stw.tween_callback(func():
		sp.position = center + Vector2(randf_range(-9, 9), randf_range(-9, 7)))
	stw.tween_property(sp, "modulate:a", 0.8, 0.18)
	stw.tween_property(sp, "modulate:a", 0.0, 0.3)
	stw.tween_interval(randf_range(1.0, 2.2))
