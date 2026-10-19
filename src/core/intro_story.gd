class_name IntroStory
extends RefCounted

## PLAN 6: la intro NO es fija, cuenta en que va TU juego (estado persistente de RunManager).
## build(rm) devuelve las diapositivas [{text, art, gray}]: `art` = indice de assets/sprites/intro/slide_NN.png
## (se reusan las de siempre, sin arte nuevo) y `gray` = el fondo va en gris (censura).
## Variantes (RunManager.intro_kind):
##   "primera"   la intro de siempre, tal cual (lines.json "intro_slides").
##   "resumen"   desde la 2a vez: que paso y donde vas (reinos liberados, lo que falta, el Algoritmo).
##   "copia"     terminaste sin vencer al Algoritmo: la historia de la copia de seguridad (la 1a vez; despues,
##               el resumen con "Quedan N reinos tomados") y tu heroe aparece entre los restos del decorado.
##   "verdadero" final verdadero: intro corta.
## Ademas, con derrotas seguidas (DERROTAS_GUINO) el narrador te saluda primero. Textos: locale/plan6.csv.

const DERROTAS_GUINO := 3
## Diapositivas de la intro de siempre que son grises (la Hoja ya tapo el mundo).
const PRIMERA_GRIS_DESDE := 4


static func build(rm: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var kind: String = rm.intro_kind()
	if kind == "primera":
		var lines: Array = Narrator.get_lines("intro_slides")
		for i in lines.size():
			out.append(_s(str(lines[i]), i, i >= PRIMERA_GRIS_DESDE))
		return out
	if rm.derrotas_seguidas >= DERROTAS_GUINO:
		out.append(_s(_t("P6_INTRO_DERROTAS"), 5, true))
	match kind:
		"verdadero":
			out.append(_s(_t("P6_INTRO_V1"), 6, false))
			out.append(_s(_t("P6_INTRO_V2"), 0, false))
		"copia":
			if not rm.copia_intro_vista:
				var hero := Loc.char_field(str(rm.heroe_resto.get("hero", rm.character)), "name")
				out.append(_s(_t("P6_COPIA_1") % hero, 3, false))
				out.append(_s(_t("P6_COPIA_2"), 8, false))
				out.append(_s(_t("P6_COPIA_3"), 4, true))
				out.append(_s(_t("P6_COPIA_4"), 6, true))
			out.append_array(_resumen(rm))
		_:
			out.append_array(_resumen(rm))
	return out


static func _s(text: String, art: int, gray: bool) -> Dictionary:
	return {"text": text, "art": art, "gray": gray}


static func _t(key: String) -> String:
	return TranslationServer.translate(key)


## Que paso y donde vas: reinos liberados, lo que falta, el Algoritmo y los reinos tomados.
static func _resumen(rm: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var total: int = RunManager.world_order().size()
	var lib: int = rm.liberated.size()
	if lib <= 0:
		out.append(_s(_t("P6_RES_NINGUNO"), 6, false))
	else:
		out.append(_s(_t("P6_RES_LIBERADOS") % [lib, total], 6, false))
	var pending: Array = rm.pending_regions()
	if not pending.is_empty():
		out.append(_s(_t("P6_RES_FALTAN") % ", ".join(pending.map(func(r): return Loc.region_name_id(str(r)))), 4, true))
	if rm.algoritmo_vencido:
		out.append(_s(_t("P6_RES_ALG_VENCIDO"), 3, false))
	elif RunManager.final_region() in rm.liberated or rm.copia_restaurada:
		out.append(_s(_t("P6_RES_ALG_VIVO"), 8, true))
	else:
		out.append(_s(_t("P6_RES_HOJA"), 3, true))
	if not rm.taken.is_empty():
		var n: int = rm.taken.size()
		var names: String = DesordenPanel.taken_names(rm)
		out.append(_s(_t("P6_RES_TOMADOS_1") % names if n == 1 else _t("P6_RES_TOMADOS_N") % [n, names], 5, true))
	return out
