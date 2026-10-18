class_name LightKit
extends RefCounted

## Piezas comunes de luz y sombra (roadmap_nico, tanda 1). Referencia visual:
## src/scenes/light_test.tscn. Contrato entre sistemas:
##
## - Salas en penumbra: RoomLighting llama a LightKit.set_dark(tree, true/false) al entrar.
##   Toda luz creada con make_light() entra al grupo GROUP_DARK y solo se enciende en
##   sala oscura (en sala clara una luz aditiva solo quemaria los colores).
## - Sombras alargadas por luz: cualquier Node2D en el grupo GROUP_CASTER con las metas
##   "foot" (Vector2 local, punto de los pies) y "shadow_radius" (float) recibe sombras
##   proyectadas desde cada luz cercana (las calcula RoomLighting). Usa mark_caster().
## - intox_wobble (0..1): la pantalla lo sube con la intoxicacion; las antorchas y faroles
##   lo leen para oscilar mas (solo visual).

## Capas de luz: 1 = suelo y actores (reciben sombra), 2 = muros (se iluminan, no se sombrean).
const MASK_FLOOR := 1
const MASK_WALL := 2
const GROUP_DARK := "dark_light"
const GROUP_CASTER := "shadow_caster"

## true mientras la sala actual esta en penumbra.
static var dark := false
static var intox_wobble := 0.0

static var _light_tex: GradientTexture2D
static var _unshaded: CanvasItemMaterial
static var _contact_tex: GradientTexture2D
static var _cast_tex: GradientTexture2D


static func set_dark(tree: SceneTree, value: bool) -> void:
	dark = value
	for n in tree.get_nodes_in_group(GROUP_DARK):
		if n is Light2D:
			n.enabled = value
		elif n is CanvasItem:
			n.visible = value


## Luz puntual con caida suave. shadows=false para luces chicas y fugaces (balas,
## fogonazos, brillos): proyectar sombra cuesta y en algo tan chico no se nota.
static func make_light(color: Color, energy: float, scale_: float, shadows := true) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.texture_scale = scale_
	l.color = color
	l.energy = energy
	l.range_item_cull_mask = MASK_FLOOR | MASK_WALL
	l.shadow_item_cull_mask = MASK_FLOOR
	l.shadow_enabled = shadows and Settings.Q_SHADOW_LIGHTS[Settings.quality] > 0
	l.shadow_filter = Light2D.SHADOW_FILTER_PCF13
	l.shadow_filter_smooth = 6.0
	l.set_meta("base_shadow", shadows)
	l.set_meta("base_energy", energy)
	l.set_meta("base_scale", scale_)
	l.set_meta("base_color", color)
	l.enabled = dark
	l.add_to_group(GROUP_DARK)
	return l


## Material para lo que debe leerse siempre (carteles, precios): ignora luces y penumbra.
static func unshaded_material() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded


## Sombra de contacto: elipse oscura bajo los pies (vale en salas claras y oscuras).
static func add_contact_shadow(target: Node2D, radius: float, foot_y: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = "ContactShadow"
	s.texture = contact_texture()
	s.scale = Vector2(radius * 2.0 / 64.0, radius * 0.8 / 64.0)
	s.position = Vector2(0, foot_y - 2.0)
	s.show_behind_parent = true
	target.add_child(s)
	return s


## Marca un actor para recibir sombras alargadas por luz (ver RoomLighting).
static func mark_caster(target: Node2D, radius: float, foot_y: float) -> void:
	target.set_meta("foot", Vector2(0, foot_y - 2.0))
	target.set_meta("shadow_radius", radius)
	target.add_to_group(GROUP_CASTER)


## Pie del sprite: borde inferior del primer cuadro (local, o en coordenadas del padre).
static func foot_y(spr: AnimatedSprite2D, in_parent := true) -> float:
	var tex := spr.sprite_frames.get_frame_texture(spr.animation, 0)
	if tex == null:
		return 0.0
	var local := spr.offset.y + tex.get_height() * 0.5
	return spr.position.y + local * spr.scale.y if in_parent else local


static func light_texture() -> GradientTexture2D:
	if _light_tex == null:
		_light_tex = _radial(256, [
			[0.0, Color(1, 1, 1, 1.0)],
			[0.25, Color(1, 1, 1, 0.78)],
			[0.5, Color(1, 1, 1, 0.42)],
			[0.75, Color(1, 1, 1, 0.13)],
			[1.0, Color(1, 1, 1, 0.0)],
		])
	return _light_tex


static func contact_texture() -> GradientTexture2D:
	if _contact_tex == null:
		_contact_tex = _radial(64, [
			[0.0, Color(0, 0, 0, 0.7)],
			[0.4, Color(0, 0, 0, 0.55)],
			[1.0, Color(0, 0, 0, 0.0)],
		])
	return _contact_tex


## Sombra proyectada: centro del degradado en el borde izquierdo (los pies); se
## estira hacia +x y se gira lejos de la luz (Sprite2D con centered=false, offset (0,-32)).
static func cast_texture() -> GradientTexture2D:
	if _cast_tex == null:
		_cast_tex = _radial(64, [
			[0.0, Color(0, 0, 0, 1.0)],
			[0.5, Color(0, 0, 0, 0.55)],
			[1.0, Color(0, 0, 0, 0.0)],
		], Vector2(0.0, 0.5), Vector2(1.0, 0.5))
	return _cast_tex


static func _radial(size: int, stops: Array, from := Vector2(0.5, 0.5), to := Vector2(1.0, 0.5)) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = from
	t.fill_to = to
	return t
