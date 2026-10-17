extends Affix

## Blindado: escudo igual al 50% de su vida que hay que romper ANTES de danar la vida. El
## sobrante del golpe que lo rompe si pasa a la vida. Barra azul y burbuja visibles; al romperse
## avisa. No se regenera.

const SHIELD_FRAC := 0.5

var shield := 0.0
var shield_max := 0.0


func pre_setup() -> void:
	shield_max = float(host.get("max_health")) * SHIELD_FRAC
	shield = shield_max


func filter_damage(amount: float, _source: Node) -> float:
	if shield <= 0.0 or amount <= 0.0:
		return amount
	var absorbed := minf(amount, shield)
	shield -= absorbed
	say("-%d" % int(round(absorbed)), Vector2(14, -34))
	if tag != null:
		tag.flash(Affixes.color_of(id))
	if shield <= 0.0:
		shield = 0.0
		say(Loc.tr_or("AFFIX_SHIELD_BREAK", "¡Escudo roto!"), Vector2(0, -60))
		HitFx.shake(0.2)
	return amount - absorbed
