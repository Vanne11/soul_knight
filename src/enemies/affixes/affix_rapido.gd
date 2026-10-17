extends Affix

## Rapido: +30% de velocidad de desplazamiento. No acelera el aviso ni la embestida (siguen igual
## de esquivables): solo te alcanza antes y se escapa menos. Se aplica en pre_setup para que la IA
## (que copia las velocidades base al nacer) lo tome como suyo.

const MULT := 1.3
const PROPS := ["move_speed", "strafe_speed", "charge_speed", "dart_speed"]


func pre_setup() -> void:
	for p in PROPS:
		if p in host:
			host.set(p, float(host.get(p)) * MULT)
