extends Node2D
class_name Defense

## Base de las DEFENSAS de MANO IZQUIERDA (condon_escudo.gd, diafragma.gd, toalla_nocturna.gd,
## copa_menstrual.gd, diu_cobre.gd, barrera_latex.gd, vacuna_vph.gd).
##
## Una defensa es un objeto con equip_slot OFFHAND (ver Item.EquipSlot) y custom_data.defense = <clave de
## Player.DEFENSES>. Mientras la llevas REEMPLAZA a la "guard" propia del heroe (escudo, alas, espolon):
## es la misma tecla/boton ("guard", reasignable en controls.gd), pero la lee la defensa y no el heroe.
## La "ability" del heroe (grito, huevo) sigue intacta. Con la defensa inservible (spent) o sin defensa
## vuelve la habilidad propia. Se coge y se cambia como un arma (la anterior queda en el suelo).
##
## Player la crea como nodo hijo (equip_defense) y la consulta en estos puntos:
##   - try_guard(area, dmg)   proyectil/golpe que entra al Hurtbox: true = bloqueado (Player no recibe dano)
##   - filter_hit(dmg)        antes de aplicar CUALQUIER dano (cuerpo a cuerpo incluido): devuelve el que pasa
##   - blocks_contagion()     PlayerStats.infect (ITS: picazon, ardor) / blocks_status() StatusEffects.apply
##   - speed_mult() / can_attack()  como en HeroAbility
## El medidor (gauge_*) lo dibuja la propia defensa bajo los pies y el panel MANOS (hands_panel.gd).

var player: Player = null
var stats: Node = null
var item: Item = null
## Inservible (condon roto): ya no reemplaza a la guard del heroe.
var spent := false
## Defensa "arriba" ahora (mantienes guard, o esta desplegada).
var guarding := false
## true solo mientras la defensa consume un proyectil (para que ProjectileStatus no ponga su estado).
var blocking := false
var gauge_value := 1.0
var gauge_color := Color("ffd75a")
var gauge_visible := false
## En recarga / enfriamiento / cambio (el panel MANOS apaga el icono).
var cooling := false


func setup(p: Player, it: Item) -> void:
	player = p
	stats = p.get_node("/root/PlayerStats")
	item = it
	z_index = 6
	position = Vector2(0, -2)


## Textura del panel MANOS (el condon roto cambia de icono).
func icon() -> Texture2D:
	return item.sprite if item else null


func replaces_hero_guard() -> bool:
	return not spent


func speed_mult() -> float:
	return 1.0


func can_attack() -> bool:
	return true


func try_guard(_area: Area2D, _dmg: float) -> bool:
	return false


func filter_hit(dmg: float) -> float:
	return dmg


func blocks_contagion() -> bool:
	return false


func blocks_status() -> bool:
	return false


## Al soltar/cambiar la defensa: limpia lo que dejo en el mundo.
func on_removed() -> void:
	pass


# ------------------------------------------------------------------ utilidades
func _silenced() -> bool:
	var st := player.get_node_or_null("StatusEffects") as StatusEffects
	return st != null and st.silenced()


func guard_held() -> bool:
	if player == null or player.is_dashing or Narrator.ate_input() or _silenced():
		return false
	return Input.is_action_pressed("guard")


func guard_pressed() -> bool:
	if player == null or player.is_dashing or Narrator.ate_input() or _silenced():
		return false
	return Input.is_action_just_pressed("guard")


func is_projectile(area: Area2D) -> bool:
	return "speed" in area and area.has_method("on_hit")


## Que tan de frente viene la fuente (1 = justo al frente del apuntado, -1 = por detras).
func facing_dot(area: Node2D) -> float:
	var to_src: Vector2 = (area.global_position - player.global_position).normalized()
	return to_src.dot(player._aim)


## Se come el proyectil sin que ponga su estado (venda, mordaza...).
func consume(area: Area2D) -> void:
	blocking = true
	area.on_hit()
	blocking = false


func text(key: String, color: Color, up := 34.0) -> void:
	player._global_events.show_floating_text.emit(player.global_position + Vector2(0, -up), tr(key), color)


## Devuelve el proyectil a quien lo disparo (parry): bala del jugador con `mult` del dano original.
func reflect(area: Area2D, mult: float, min_damage := 12.0) -> void:
	var owner_node = area.get("projectile_owner")
	var dir: Vector2 = player._aim
	if owner_node is Node2D and is_instance_valid(owner_node):
		dir = (owner_node.global_position - area.global_position).normalized()
	var b := Player.PLAYER_BULLET.instantiate()
	b.damage = maxf(float(area.get("damage")) * mult, min_damage) * stats.damage_modifier
	b.speed = maxf(float(area.get("speed")) * 1.3, 400.0)
	b.rotation = dir.angle()
	b.tint = Color("fff1b0")
	b.crit = true
	b.pierce = 1
	var at: Vector2 = area.global_position
	player.get_parent().add_child.call_deferred(b)  # estamos dentro de una consulta de fisica
	b.set_deferred("global_position", at)
	consume(area)


func _process(_d: float) -> void:
	if guarding or gauge_visible:
		queue_redraw()
	_draw_tick()


func _draw_tick() -> void:
	pass


func _draw() -> void:
	_draw_body()
	if gauge_visible and player != null:
		var w := 30.0
		var r := Rect2(Vector2(-w * 0.5, 38.0), Vector2(w, 3.0))
		draw_rect(r.grow(1.0), Color(0, 0, 0, 0.7))
		var v := clampf(gauge_value, 0.0, 1.0)
		draw_rect(Rect2(r.position, Vector2(w * v, 3.0)), gauge_color)


func _draw_body() -> void:
	pass
