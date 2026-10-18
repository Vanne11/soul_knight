extends Node
class_name HeroAbility

## Base de las habilidades propias de cada heroe (pitocles.gd, vulvalquiria.gd,
## ornitorrinco.gd). Player crea UNA como nodo hijo en _apply_character y le avisa:
##   - setup(player)            al crearla (aqui se aplican los numeros del heroe)
##   - speed_mult()             multiplicador de velocidad de caminata
##   - can_attack()             false = el gatillo no dispara (p.ej. con el escudo arriba)
##   - on_dash_start(dir)/on_dash_tick(dir)   embestida de falange, etc.
##   - try_guard(area, dmg)     true = el golpe/bala se bloqueo (Player no recibe dano)
## Entradas: "guard" (mantener) y "ability" (pulsar), ver [input] de project.godot.
## Los efectos sobre enemigos NUNCA tocan enemy*.gd: usan metodos opcionales
## (has_method) y, si no existen, el estado STUNNED que ya trae Enemy.

var player: Player = null
var stats: Node = null
var _ge: Node = null

## Estado del medidor bajo los pies (lo lee AbilityGauge): 0..1, 1 = lista.
var gauge_value := 1.0
var gauge_color := Color("ffd75a")
var gauge_visible := false


func setup(p: Player) -> void:
	player = p
	stats = p.get_node("/root/PlayerStats")
	_ge = p.get_node("/root/GlobalEvents")


func speed_mult() -> float:
	return 1.0


func can_attack() -> bool:
	return true


func on_dash_start(_dir: Vector2) -> void:
	pass


func on_dash_tick(_dir: Vector2) -> void:
	pass


func try_guard(_area: Area2D, _dmg: float) -> bool:
	return false


## Distancia al suelo (px) para levantar el sprite (planeo).
func hover_lift() -> float:
	return 0.0


func _text(key: String, color: Color, up := 34.0) -> void:
	_ge.show_floating_text.emit(player.global_position + Vector2(0, -up), tr(key), color)


func _say(event: String) -> void:
	Narrator.say_first(event)


## Enemigos vivos a menos de `radius` de `pos`.
func enemies_near(pos: Vector2, radius: float) -> Array:
	var out: Array = []
	for e in player.get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e is Node2D and float(e.get("current_health")) > 0.0 \
				and e.global_position.distance_to(pos) <= radius:
			out.append(e)
	return out


## Aturde a un enemigo. Los jefes solo se tambalean (el aturdimiento largo los rompe).
func stun(e: Node, seconds: float, away: Vector2 = Vector2.ZERO) -> void:
	if e.is_in_group("boss"):
		seconds = minf(seconds, 0.35)
	if e.has_method("stun"):
		e.stun(seconds)
	elif "state" in e and "_state_timer" in e:
		e.state = Enemy.State.STUNNED
		e._state_timer = seconds
		if away != Vector2.ZERO:
			e.velocity = away
			PitFall.push(e, away)  # empujado hacia un foso: puede caer
		var spr = e.get("animated_sprite")
		if spr:
			spr.modulate = Color(0.7, 0.8, 1.3)


## Hace huir a un enemigo `seconds` segundos (grito). Jefes: no.
func scare(e: Node, seconds: float, from: Vector2) -> void:
	if e.is_in_group("boss"):
		stun(e, 0.4)
		return
	if e.has_method("scare"):
		e.scare(seconds, from)
		return
	var old := e.get_node_or_null("FleeEffect")
	if old:
		old.queue_free()
	var f := FleeEffect.new()
	f.name = "FleeEffect"
	f.seconds = seconds
	f.from = from
	e.add_child(f)
