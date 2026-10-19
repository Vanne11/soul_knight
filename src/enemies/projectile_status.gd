extends ProjectileEnemy
class_name ProjectileStatus

## Proyectil enemigo que ademas de dano deja un ESTADO en el jugador (mordaza, venda...).
## `kind` y `seconds` los fija la escena o el enemigo que lo dispara. El estado solo se pone si
## el golpe conecta de verdad: no si esquivas (dash/invulnerable) ni si lo bloqueas con escudo.

@export var kind := "amordazado"
@export var seconds := 4.0
@export var glow := Color("e8322e")
## multiplica los segundos si juegas con el Ornitorrinco (electrorrecepcion)
@export var platypus_mult := 1.0


func _ready() -> void:
	super._ready()
	var old := get_node_or_null("Glow")
	if old:
		old.queue_free()
	ActorFx.add_glow(self, glow, 0.55, 0.36)


func on_hit() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and _connects(p):
		var st := StatusEffects.of(p)
		if st != null:
			st.apply(kind, seconds * (platypus_mult if E3a.hero() == "ornitorrinco" else 1.0), projectile_owner)
	queue_free()


func _connects(p: Node) -> bool:
	if "is_dashing" in p and p.is_dashing:
		return false
	if "_iframes" in p and float(p._iframes) > 0.0:
		return false
	var df = p.get("defense")
	if df != null and (df.blocking or df.blocks_status()):
		return false
	var ab = p.get("ability")
	if ab != null and "guarding" in ab and ab.guarding:
		return false
	return true
