extends Defense
class_name DefPrep

## PrEP (defensa PASIVA). Prevencion del VIH ANTES de la exposicion: casi todos los contagios de ITS (picazon,
## ardor) te resbalan (BLOCK_CHANCE). No reemplaza a la guard del heroe. Licencia de juego: en la vida real
## protege SOLO del VIH, no de otras ITS, y se toma con indicacion profesional (ver datos_salud.md ML-21).

const BLOCK_CHANCE := 0.9

var blocked := 0


func setup(p: Player, it: Item) -> void:
	super.setup(p, it)
	gauge_color = Color("6fb4ff")


func is_passive() -> bool:
	return true


func blocks_contagion() -> bool:
	if RNG.randf() < BLOCK_CHANCE:
		blocked += 1
		return true
	return false
