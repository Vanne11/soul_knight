class_name EnemyPersonalities
extends RefCounted

## Tabla de PERSONALIDADES de enemigos (datos puros) + quien tiene cual.
## El comportamiento lo ejecuta EnemyAI (enemy_ai.gd). Aqui solo se describe.
##
## ---------------------------------------------------------------------------------
## COMO LE DOY PERSONALIDAD A UN ENEMIGO NUEVO (Etapa 3)
## ---------------------------------------------------------------------------------
## 1. Describe la personalidad en P (o, desde tu propio script, EnemyPersonalities.register(
##    "mi_id", {...})): solo pones los parametros que difieren de DEFAULTS.
## 2. Asignala por UNO de estos caminos (en este orden de prioridad):
##    a) `@export var personality` del enemigo (campo en el inspector de su escena .tscn, o
##       `personality = "mi_id"` en su _ready antes de super._ready()). "none" = sin IA.
##    b) por variante de sprite (el `variant` de los datos de pisos, p.ej. "huincha"):
##       una linea en BY_VARIANT (o EnemyPersonalities.assign_variant("huincha", "mi_id")).
##    c) si no, "normal" (solo moral de grupo y emociones basicas).
## 3. Si tu enemigo extiende Enemy / EnemyRanged / EnemySwarmer / EnemyTank ya esta listo:
##    esas clases instancian y consultan el componente solas. Si es una clase nueva, copia
##    los 4 ganchos (busca "ai" en enemy.gd):
##      var ai: EnemyAI = null
##      _ready():          ai = EnemyAI.attach(self)
##      _physics_process:  if ai != null and ai.control(delta): move_and_slide(); return
##      take_damage():     if ai != null: amount = ai.on_damage(amount, source)
##      die():             if ai != null: ai.on_death()
##    El enemigo debe tener: target, detection_range, move_speed, current_health, max_health,
##    state (int, 0 = IDLE), animated_sprite y group "enemy".
## 4. Reaccion por heroe: dentro de la personalidad, "hero": {"pitocles": {...},
##    "vulvalquiria": {...}, "ornitorrinco": {...}}. Esos parametros pisan a los base cuando
##    RunManager.character es ese heroe (ver la tabla en los enemigos actuales).
## 5. Frases cortas (burbuja): SAY["IA_<VARIANTE>_<EVENTO>"] o SAY["IA_<EVENTO>"] (es) y su
##    traduccion en locale/ia.csv (cabecera keys,es,en).
##
## Parametros (todos opcionales, valores por defecto en DEFAULTS):
##   detect_mult   multiplica detection_range            speed_mult   velocidad fija (x)
##   courage       0..1 aguante de la moral de grupo      search       segundos que te busca
##   sleep/wake_range  dormido: despierta si te acercas   passive/provoke_range  neutral
##   friend        neutral por simpatia (corazon)         startle_range  se asusta y huye
##   flee_hp/flee_time/flee_heal/flee_max  cobarde: huye bajo X% vida y vuelve curado
##   rage_hp/rage_ally/rage_speed/rage_time/rage_behind/rage_on_hit  rabia
##   alarm/alarm_radius  da la voz y despierta a vecinos  territory  radio de su zona
##   surrender_hp  se rinde y suelta el botin            grudge  rencor permanente
##   resent_time   si lo ignoras X s dispara mas fuerte  race    compite por llegar primero
##   shell         se cierra si le disparan de lejos     overload_shots/recharge_time  se descarga
##   inspect_wait  si te quedas quieto te inspecciona    confuse/spasm  movimiento errático
##   hide/guard    se esconde tras aliados / cubre a los de distancia
##   flank         te rodea por los lados                patrol/patrol_sight  ruta fija
##   split_time    se multiplica si no lo matas rapido
##   hazard_caution  >1 = cobarde ante las trampas (mas margen y avisa antes)   reckless  0..1 prob.
##                 de lanzarse sin mirar a un peligro de sala (los enfurecidos: min. 0,7)

const DEFAULTS := {
	"detect_mult": 1.0, "speed_mult": 1.0, "courage": 0.55, "search": 2.5,
	"sleep": false, "wake_range": 70.0,
	"passive": false, "provoke_range": 0.0, "provoke_group": false, "friend": false,
	"startle_range": 0.0,
	"flee_hp": 0.0, "flee_time": 3.5, "flee_heal": 0.5, "flee_max": 1,
	"rage_hp": 0.0, "rage_ally": false, "rage_speed": 1.3, "rage_time": 8.0,
	"rage_behind": false, "rage_on_hit": false, "rage_permanent": false,
	"alarm": false, "alarm_radius": 700.0,
	"territory": 0.0,
	"surrender_hp": 0.0,
	"grudge": false,
	"resent_time": 0.0,
	"race": false,
	"shell": false,
	"overload_shots": 0, "recharge_time": 2.2,
	"inspect_wait": 0.0,
	"confuse": false, "spasm": false,
	"hide": false, "guard": false, "flank": false,
	"patrol": false, "patrol_sight": 260.0,
	"split_time": 0.0,
	"wake_rage": false,
	"hazard_caution": 1.0, "reckless": 0.0,
}

const P := {
	"normal": {},
	# Minijefe y gigantes: no dudan.
	"gigante": {"courage": 1.0},

	# --- Selva Publica ---
	# Pelo Encarnado: terco. Te ve de lejos, no se rinde y si te pierde te busca mucho rato.
	"terco": {
		"detect_mult": 2.0, "courage": 1.0, "search": 5.0, "reckless": 0.2,
		"hero": {"vulvalquiria": {"speed_mult": 1.12}, "ornitorrinco": {"confuse": true}},
	},
	# Granito Rencoroso: si le pegas, te recuerda para siempre; y se enfurece si cae un colega.
	"rencoroso": {
		"grudge": true, "rage_ally": true, "rage_time": 10.0, "reckless": 0.2,
		"hero": {"vulvalquiria": {"rage_speed": 1.45}, "ornitorrinco": {"detect_mult": 1.3}},
	},
	# Ladilla: pasta tranquila hasta que te acercas o le pegas; entonces todas se te pegan.
	"pastora": {
		"passive": true, "provoke_range": 100.0, "provoke_group": true,
		"hero": {"pitocles": {"provoke_range": 170.0}, "ornitorrinco": {"provoke_range": 40.0}},
	},

	# --- Penelandia ---
	# Testiculo Errante: despistado. Deambula; si lo sorprendes de cerca, arranca (y luego se arma de valor).
	"despistado": {
		"passive": true, "startle_range": 150.0, "flee_time": 2.6, "flee_heal": 0.0, "hazard_caution": 1.3,
		"hero": {
			"pitocles": {"startle_range": 0.0, "friend": true},
			"vulvalquiria": {"startle_range": 230.0},
			"ornitorrinco": {"confuse": true},
		},
	},
	# Vesicula Resentida: si la ignoras (no le pegas) dispara mas fuerte.
	"resentida": {
		"resent_time": 8.0,
		"hero": {"vulvalquiria": {"resent_time": 5.0}},
	},
	# Espermatozoide: competitivo, corren a ver quien llega primero.
	"competitivo": {
		"race": true,
		"hero": {
			"pitocles": {"passive": true, "friend": true, "provoke_range": 0.0, "race": false},
			"vulvalquiria": {"speed_mult": 1.15},
		},
	},

	# --- Vulvania ---
	# Ovulo Rodante: realeza. No ataca hasta que la provocas; despues, no para.
	"realeza": {
		"passive": true, "provoke_range": 110.0, "courage": 1.0, "rage_permanent": true,
		"hero": {"vulvalquiria": {"provoke_range": 0.0, "friend": true}},
	},
	# Trompa Escupidora: chismosa. En cuanto te ve, avisa a todos.
	"chismosa": {
		"alarm": true, "alarm_radius": 700.0,
		"hero": {"vulvalquiria": {"alarm_radius": 450.0}, "ornitorrinco": {"alarm_radius": 1000.0}},
	},
	# Calambre: impredecible. Espasmos sin ritmo.
	"impredecible": {
		"spasm": true,
		"hero": {"ornitorrinco": {"confuse": true}},
	},

	# --- Perineo ---
	# Espéculo Mordedor: defensivo. Solo defiende su zona; se cierra si le disparan de lejos.
	"defensivo": {
		"territory": 230.0, "shell": true,
		"hero": {"ornitorrinco": {"confuse": true, "territory": 330.0}},
	},
	# Hemorroide Fronteriza: quejona y dormilona. Despierta de mal humor, cubre a los de distancia
	# y se enfurece si la golpeas por detras.
	"quejona": {
		"sleep": true, "wake_range": 90.0, "guard": true, "rage_behind": true, "wake_rage": true,
		"hero": {
			"pitocles": {"wake_range": 130.0},
			"vulvalquiria": {"wake_range": 40.0, "rage_on_hit": true},
			"ornitorrinco": {"wake_range": 80.0},
		},
	},
	# Inspector de Fluidos: burocrata. Si te quedas quieto te inspecciona en vez de disparar.
	# Si lo dejas en las últimas se jubila (se rinde y suelta el botin).
	"burocrata": {
		"inspect_wait": 1.1, "surrender_hp": 0.18, "courage": 0.7, "hazard_caution": 1.3,
		"hero": {"ornitorrinco": {"inspect_wait": 0.0, "confuse": true}},
	},
	# Pelusa Perineal: timida. Se esconde detras de los demas.
	"timida": {
		"hide": true, "courage": 0.2, "flee_hp": 0.3, "flee_heal": 0.6, "hazard_caution": 1.5,
		"hero": {"ornitorrinco": {"hide": false}},
	},
	# Dildo Electrico: hiperactivo. Se descarga y debe recargarse (ventana para pegarle).
	"hiperactivo": {
		"overload_shots": 2, "speed_mult": 1.12,
		"hero": {"pitocles": {"overload_shots": 3}, "vulvalquiria": {"recharge_time": 2.8}},
	},

	# --- Palacio de la Censura ---
	# Barra Negra: censora acosadora; te rodea por los lados para taparte la vista.
	"censora": {
		"flank": true, "detect_mult": 1.4,
		"hero": {"ornitorrinco": {"detect_mult": 0.8}},
	},
	# Sello Censor: estricto. Patrulla una ruta fija y da el alto.
	"estricto": {
		"patrol": true, "courage": 0.9,
		"hero": {"vulvalquiria": {"alarm": true}, "ornitorrinco": {"confuse": true}},
	},
	# Pixel de Censura: contagioso. Si no lo matas rapido, se multiplica.
	"contagioso": {
		"split_time": 9.0,
		"hero": {"pitocles": {"split_time": 7.0}},
	},
}

## variante de sprite (assets/sprites/enemies/<variante>_sprite_frames.tres) -> personalidad.
## Variante sin entrada = "normal". ITS y Espinilla tienen mecanica propia: NO_AI.
const BY_VARIANT := {
	"pelo_encarnado": "terco",
	"granito": "rencoroso",
	"ladilla": "pastora",
	"testiculo": "despistado",
	"vesicula": "resentida",
	"espermatozoide": "competitivo",
	"ovulo": "realeza",
	"trompa": "chismosa",
	"calambre": "impredecible",
	"especulo": "defensivo",
	"hemorroide": "quejona",
	"inspector_fluidos": "burocrata",
	"pelusa_perineal": "timida",
	"dildo_electrico": "hiperactivo",
	"barra_negra": "censora",
	"sello": "estricto",
	"pixel_censura": "contagioso",
}

## Escenas (nombre de archivo sin .tscn) que NO usan este componente (mecanica propia).
const NO_AI := ["enemy_its", "enemy_espinilla", "enemy_boss"]

## Frases de burbuja (es). Clave: IA_<VARIANTE>_<EVENTO> (especifica) o IA_<EVENTO> (general).
## La traduccion vive en locale/ia.csv con las mismas claves. Eventos: ver EnemyAI.
const SAY := {
	"IA_FLEE": "¡MAMÁÁ!",
	"IA_BACK": "¡Ya estoy curado!",
	"IA_SURRENDER": "¡Me rindo! ¡Toma mi botín!",
	"IA_WAKE": "¿Eh? ¿Quién anda ahí?",
	"IA_ALARM": "¡AQUÍ ESTÁ! ¡AQUÍ ESTÁ!",
	"IA_RAGE": "¡¡GRRR!!",
	"IA_ALLY_DIED": "¡NOOO! ¡Mi compañero!",
	"IA_DOUBT": "Esto no era parte del plan...",
	"IA_LOST": "¿Dónde se metió?",
	"IA_PROVOKED": "¡Me has pisado!",
	"IA_STARTLE": "¡AAAH! ¡Un héroe!",
	"IA_HERO_CONFUSED": "¿Qué... ERES?",
	"IA_PELO_ENCARNADO_LOST": "No pienso soltarte.",
	"IA_GRANITO_GRUDGE": "Te recordaré. Siempre.",
	"IA_LADILLA_PROVOKED": "¡Te pillé! Ahora vives aquí.",
	"IA_TESTICULO_STARTLE": "¡AAAH! ¡Me han visto!",
	"IA_TESTICULO_HERO_FRIEND": "¡Colega!",
	"IA_VESICULA_RESENT": "¿Me estás ignorando?",
	"IA_ESPERMATOZOIDE_HERO_FRIEND": "¡Es de los nuestros!",
	"IA_ESPERMATOZOIDE_RACE": "¡YO PRIMERO!",
	"IA_OVULO_PROVOKED": "¿Cómo osas tocar a la realeza?",
	"IA_OVULO_HERO_FRIEND": "Saludos, hermana.",
	"IA_TROMPA_ALARM": "¡Cotilleo! ¡Está aquí!",
	"IA_ESPECULO_SHELL": "*clac*",
	"IA_HEMORROIDE_WAKE": "¡Déjame dormir, bruto!",
	"IA_HEMORROIDE_RAGE": "¡POR DETRÁS NO!",
	"IA_INSPECTOR_FLUIDOS_INSPECT": "¿Documentos?",
	"IA_INSPECTOR_FLUIDOS_STAMP": "SELLADO. Sin papeles.",
	"IA_INSPECTOR_FLUIDOS_ABORT": "Se mueve. Irregular.",
	"IA_INSPECTOR_FLUIDOS_SURRENDER": "Solicito jubilación anticipada.",
	"IA_PELUSA_PERINEAL_HIDE": "Yo... mejor me escondo.",
	"IA_DILDO_ELECTRICO_DISCHARGE": "Sin batería...",
	"IA_DILDO_ELECTRICO_RECHARGED": "¡LISTO! ¡OTRA VEZ!",
	"IA_BARRA_NEGRA_ALERT": "[CENSURADO]",
	"IA_SELLO_ALERT": "ALTO. Esta ruta es mía.",
	"IA_PIXEL_CENSURA_SPLIT": "¡Me multipliqué!",
	"IA_HAZARD_WARY": "Eso pincha. No, gracias.",
	"IA_HAZARD_DIVE": "¿Qué podría salir mal?",
	"IA_HAZARD_OUCH": "Ay. Eso podía salir mal.",
}

static var _custom: Dictionary = {}
static var _custom_variant: Dictionary = {}


static func register(id: String, params: Dictionary) -> void:
	_custom[id] = params


static func assign_variant(variant: String, id: String) -> void:
	_custom_variant[variant] = id


static func exists(id: String) -> bool:
	return P.has(id) or _custom.has(id)


## Parametros finales de una personalidad para un heroe.
static func params(id: String, hero: String) -> Dictionary:
	var base: Dictionary = _custom.get(id, P.get(id, {}))
	var d := DEFAULTS.duplicate()
	for k in base:
		if k != "hero":
			d[k] = base[k]
	var h: Dictionary = base.get("hero", {}).get(hero, {})
	for k in h:
		d[k] = h[k]
	return d


## Variante de sprite del enemigo (por el nombre del recurso de frames).
static func variant_of(enemy: Node) -> String:
	var spr = enemy.get("animated_sprite")
	if spr == null or not (spr is AnimatedSprite2D) or spr.sprite_frames == null:
		return ""
	return spr.sprite_frames.resource_path.get_file().get_basename().trim_suffix("_sprite_frames")


## Id de personalidad de un enemigo ("none" = sin IA). Ver prioridad arriba.
static func resolve(enemy: Node) -> String:
	var exp = enemy.get("personality")
	if exp != null and String(exp) != "":
		return String(exp)
	var scene_name := String(enemy.scene_file_path).get_file().get_basename()
	if scene_name in NO_AI:
		return "none"
	var v := variant_of(enemy)
	var spr = enemy.get("animated_sprite")
	if spr != null and spr is AnimatedSprite2D and absf(spr.scale.x) > _default_scale(enemy) * 1.3:
		return "gigante"
	if _custom_variant.has(v):
		return _custom_variant[v]
	return BY_VARIANT.get(v, "normal")


static var _scale_cache: Dictionary = {}


## Escala de sprite por defecto de la escena del enemigo (el minijefe la agranda al instanciar).
static func _default_scale(enemy: Node) -> float:
	var path := String(enemy.scene_file_path)
	if _scale_cache.has(path):
		return _scale_cache[path]
	var sc := 1.0
	var scn := load(path) as PackedScene if path != "" else null
	if scn != null:
		var st := scn.get_state()
		for i in st.get_node_count():
			if st.get_node_name(i) == "AnimatedSprite2D":
				for j in st.get_node_property_count(i):
					if st.get_node_property_name(i, j) == "scale":
						sc = (st.get_node_property_value(i, j) as Vector2).x
	_scale_cache[path] = absf(sc)
	return absf(sc)


## Texto de burbuja traducido; "" si no hay frase para ese evento.
static func say_text(variant: String, event: String) -> String:
	var ev := event.to_upper()
	for key in ["IA_%s_%s" % [variant.to_upper(), ev], "IA_%s" % ev]:
		if SAY.has(key):
			return Loc.tr_or(key, SAY[key])
	return ""
