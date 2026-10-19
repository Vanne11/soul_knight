extends ProjectileStatus
class_name ProjectileEtiqueta

## Etiqueta adhesiva de La Etiqueta: si conecta, se te pega (StatusEffects.stick_label): te frena y
## el dash la rompe con dano extra. Igual que el resto de proyectiles de estado, no se pega si
## esquivas (dash/invulnerable) ni si la bloqueas con el escudo.


func on_hit() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p != null and _connects(p):
		var st := StatusEffects.of(p)
		if st != null:
			st.stick_label(projectile_owner)
	queue_free()
