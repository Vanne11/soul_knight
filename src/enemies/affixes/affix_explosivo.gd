extends Affix

## Explosivo: al morir deja un circulo naranja que parpadea cada vez mas rapido y revienta a los
## 1.1 s. El dash lo esquiva (receive_hit lo ignora). Dano = su dano; el aviso es el circulo y
## su radio es el real. No daña a otros enemigos.

const RADIUS := 78.0
const FUSE := 1.1


func on_death() -> void:
	var b := AffixBlast.new()
	b.radius = RADIUS
	b.fuse = FUSE
	b.damage = float(host.get("damage"))
	b.color = Affixes.color_of(id)
	container().add_child(b)
	b.global_position = host.global_position
