class_name Consultorio
extends RefCounted

## Consultorio de la Matrona Preventina en las salas de descanso: cura el contagio (gratis),
## vende prevencion (preservativo de bolsillo y vacuna VPH) y un poster con guiño. Todo se
## usa con E y solo si quieres; nada se impone. Lo construye Main._build_calm_room (REST).

const PROP := preload("res://src/edu/edu_prop.gd")
const ART := "res://assets/sprites/edu/"  # arte de tools/gen_edu_art.py


static func build(main: Node, room: Room) -> void:
	var c := room.get_center_position()
	var cfg := Edu.consultorio_cfg()
	var doc := matrona_visual()
	_prop(main, room, c + Vector2(-140, -30), doc,
		func(): return Edu.t("EDU_DOC_PROMPT_SICK" if Edu.ps().contagion_time > 0.0 else "EDU_DOC_PROMPT_OK"),
		func(_p, it):
			matrona_act(doc, "talk")
			main.get_node("/root/LoreDatabase").custom_event("matrona_consulta")
			if Edu.ps().contagion_time > 0.0:
				Edu.ps().clear_contagion()
				Sound.play("room_clear")
				Narrator.say("edu_cura")
			else:
				var fact := Edu.next_fact()
				if fact != "":
					Narrator.say_raw("%s: %s" % [Edu.t("EDU_DOC_NAME"), fact])
			it.finish(), true)
	_prop(main, room, c + Vector2(-140, -110), _sprite_visual(room, "poster", 40, true, 20.0),
		func(): return Edu.t("EDU_POSTER_PROMPT"),
		func(_p, it):
			Narrator.say_raw(Edu.t("EDU_POSTER_SAY"))
			it.finish(), true)
	var cp: int = Edu.price(int(cfg.get("preservativo", {}).get("precio", 6)))
	var secs: float = float(cfg.get("preservativo", {}).get("inmunidad_seg", 150.0))
	_prop(main, room, c + Vector2(-210, 30), _sprite_visual(room, "box_condon", 34, false, 10.0),
		func(): return Edu.t("EDU_CONDOM_PROMPT" if Edu.rm().coins >= cp else "EDU_CONDOM_POOR") % cp,
		func(p, it):
			if not _pay(cp, p):
				return
			matrona_act(doc, "give")
			Edu.ps().apply_item_effect({"type": 18, "duration": secs})
			Narrator.say("edu_condon")
			it.finish())
	var vp: int = Edu.price(int(cfg.get("vacuna_vph", {}).get("precio", 15)))
	_prop(main, room, c + Vector2(-140, 50), _sprite_visual(room, "vacuna", 30, false, 10.0),
		func():
			if Edu.ps().vph_vaccinated:
				return Edu.t("EDU_VAX_DONE")
			return Edu.t("EDU_VAX_PROMPT" if Edu.rm().coins >= vp else "EDU_VAX_POOR") % vp,
		func(p, it):
			if Edu.ps().vph_vaccinated:
				Narrator.say("edu_vacuna_ya")
				return
			if not _pay(vp, p):
				return
			Edu.ps().vph_vaccinated = true
			Narrator.toast(Edu.t("EDU_VAX_TOAST"), "", "7fe0a0")
			Narrator.say("edu_vacuna")
			it.finish())


## Cobra; si no alcanza, la Matrona lo dice con gracia y no pasa nada.
static func _pay(price: int, player: Node) -> bool:
	if Edu.rm().coins < price:
		Sound.play("poor")
		Narrator.say("edu_pobre")
		return false
	Edu.rm().add_coins(-price)
	Edu.ge().show_floating_text.emit(player.global_position + Vector2(0, -46), "-%d $" % price, Color("ffd75a"))
	Sound.play("buy")
	return true


static func _prop(main: Node, room: Room, pos: Vector2, visual: Node2D, prompt: Callable, on_use: Callable, badge := false) -> void:
	var it := PROP.new()
	it.has_badge = badge
	it.badge_y = _top_of(visual) - 12.0
	it.position = pos
	it.prompt_fn = prompt
	it.add_child(visual)
	dress(room, it, visual)
	it.used.connect(on_use.bind(it))
	room.props_node.add_child.call_deferred(it)


## Sombra de contacto (y proyectada si es alto) segun el pie y el ancho que marca el visual
## (metas "foot" y "half_w"), y el shader de censura de la sala: gris hasta liberarla.
## Los visuales son Sprite2D (no Polygon2D), asi que Main._prop_shadow no los mide.
static func dress(room: Room, it: Node2D, visual: Node2D) -> void:
	for c in [visual] + visual.get_children():
		if c is CanvasItem:
			Censor.apply(room, c)
	if visual.has_meta("flat"):
		return
	var foot: float = visual.get_meta("foot", 10.0)
	var r: float = visual.get_meta("half_w", 16.0)
	LightKit.add_contact_shadow(it, r + 2.0, foot + 2.0)
	if visual.has_meta("tall"):
		LightKit.mark_caster(it, r, foot + 2.0)
		TallProp.attach_visual(it, visual)


## Y del borde de arriba del visual (Sprite2D / AnimatedSprite2D no centrados): donde flota el icono.
static func _top_of(visual: Node2D) -> float:
	if visual.has_meta("top"):
		return float(visual.get_meta("top"))
	return float(visual.get("offset").y) if visual.get("offset") != null else -40.0


static func tex(file: String) -> Texture2D:
	return load(ART + file + ".png")


## Sprite2D centrado en x con los pies (borde inferior) a `foot` px bajo el origen del prop.
## `flat`: cartel/suelo, sin sombra. `tall`: proyecta sombra larga con las luces.
static func _sprite_visual(_room: Room, file: String, _height: int, flat: bool, foot: float, tall := false) -> Node2D:
	var s := Sprite2D.new()
	s.texture = tex(file)
	s.centered = false
	s.offset = Vector2(-s.texture.get_width() / 2.0, foot - s.texture.get_height())
	s.set_meta("foot", foot)
	s.set_meta("half_w", s.texture.get_width() / 2.0 - 3.0)
	if flat:
		s.set_meta("flat", true)
	if tall:
		s.set_meta("tall", true)
	return s


## La matrona (antes la doctora): idle con parpadeo y anotaciones en su ficha, y poses que se
## disparan al interactuar (talk al hablar, give al entregar, wave al saludar). Arte: tools/gen_matrona_art.py.
## Lo usa tambien la Consulta del Utero (la Matrona V.).
static func matrona_visual() -> AnimatedSprite2D:
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", 1.0)
	for e in [["idle", 3.2], ["blink", 0.25], ["idle", 2.4], ["write", 1.4], ["idle", 3.6], ["blink", 0.25]]:
		sf.add_frame("idle", tex("matrona_" + e[0]), e[1])
	var poses := {"talk": ["talk_a", "talk_b", "talk_a", "talk_b", "talk_a", "idle"],
		"give": ["give", "give", "give", "idle"], "wave": ["wave", "wave", "wave", "idle"]}
	for anim in poses:
		sf.add_animation(anim)
		sf.set_animation_loop(anim, false)
		sf.set_animation_speed(anim, 1.0)
		for f in poses[anim]:
			sf.add_frame(anim, tex("matrona_" + f), 0.22 if anim == "talk" else 0.4)
	var a := AnimatedSprite2D.new()
	a.sprite_frames = sf
	a.centered = false
	a.offset = Vector2(-24, 24 - 64)
	a.set_meta("foot", 24.0)
	a.set_meta("half_w", 17.0)
	a.set_meta("tall", true)
	a.animation_finished.connect(func():
		if a.animation != "idle":
			a.play("idle"))
	a.play("idle")
	return a


## Dispara una pose de la matrona (talk / give / wave); vuelve sola al idle.
static func matrona_act(v: AnimatedSprite2D, anim: String) -> void:
	if is_instance_valid(v):
		v.play(anim)
