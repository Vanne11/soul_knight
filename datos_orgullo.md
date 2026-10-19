# datos_orgullo.md — Datos del Reino del Orgullo (nombre provisorio: ARCOÍRIA)

Para: **Vanessa** (autora) y, antes de publicar, personas de la comunidad LGBTIQ+. Mismo formato que `datos_salud.md`: cada fila es un dato que el juego afirma, con su fuente y una casilla de revisión.
Alcance: las 25 entradas del códice, sección "Orgullo" (`assets/data/lore/*.tres` con `category = 7`; textos en `locale/orgullo.csv`, claves `LORE_<ID>_TITLE/TEXT/FLAVOR`). Íconos de banderas: `assets/sprites/codex/orgullo/` (los genera `tools/gen_orgullo_flags.py`).

Verificación: fechas y autores se contrastaron el 2026-10-18 con Wikipedia (artículo y referencias), la OMS y el Smithsonian vía búsqueda. Estado:

- **OK** = confirmado en la fuente citada.
- **REVISAR: sin confirmar** = no pude confirmarlo; la nota dice qué falta.
- Columna "universal": **sí** = vale en cualquier país (todo lo de este archivo lo es; las banderas y la CIE son internacionales).

Todas las filas quedan con la casilla `[ ] Vanessa` y la etiqueta **REVISAR** hasta que una persona las valide.

## Cómo se desbloquean (para quien arme el reino jugable)

Todas son `category = 7` (`LoreEntry.Category.ORGULLO`) con `unlock_condition` de tipo CUSTOM (10), que el `LoreDatabase` cuenta con `custom_event(id)`:

- Banderas, historia y conceptos (**21 entradas**): `{"type": 10, "target_id": "reino_orgullo_entrada"}`. Basta llamar una vez `LoreDatabase.custom_event("reino_orgullo_entrada")` al entrar al reino.
- Mitos (**4 entradas**): `orgullo_vencido_es_una_fase`, `orgullo_vencido_el_armario`, `orgullo_vencido_quien_es_el_hombre`, `orgullo_vencido_la_etiqueta`. Se abren con `custom_event("orgullo_vencido_<id>")` al derrotar a ese enemigo.
- Hoy nadie emite esos eventos: **todas quedan bloqueadas** (se ven como "???" al final del códice) y no se rompe nada. Para probar: llamar a esos `custom_event` desde la consola o un script de prueba.
- Los ids de reino y de enemigos son estables y no llevan el nombre del reino: cuando Vanessa elija el definitivo no hay que tocar código. El nombre visible, si hace falta, va en una clave de locale.

## A. Banderas

| id / clave | afirmación (es, resumida) | fuente | estado y nota | Vanessa | universal sí/no |
|---|---|---|---|---|---|
| `bandera_arcoiris`: autor y año | Gilbert Baker, 1978; izada por primera vez el 25 de junio de 1978 en el Desfile de la Libertad Gay de San Francisco | https://en.wikipedia.org/wiki/Rainbow_flag_(LGBTQ) | OK | [ ] Vanessa | sí |
| `bandera_arcoiris`: 8 colores y sentidos | rosa fuerte = sexualidad (en inglés "sex"), rojo = vida, naranja = sanación, amarillo = luz del sol, verde = naturaleza, turquesa = magia/arte, índigo = serenidad, violeta = espíritu | misma URL | OK | [ ] Vanessa | sí |
| `bandera_arcoiris`: por qué quedaron 6 | el rosa se quitó por falta de tela de ese color (1978); el turquesa en 1979, para partir la bandera en postes de luz del recorrido, que pedía un número par de franjas por lado. El índigo pasó a azul | misma URL | OK para ambas razones. REVISAR: sin confirmar que "índigo pasó a azul" (lo conozco, pero la página no lo dice en el tramo leído) | [ ] Vanessa | sí |
| `bandera_arcoiris`: hex del ícono | #FF69B4 #FF0000 #FF8E00 #FFFF00 #008E00 #00C0C0 #400098 #8E008E | uso común de la versión de 8 franjas (la página no da hex) | REVISAR: sin confirmar contra fuente oficial | [ ] Vanessa | sí |
| `bandera_trans`: autora y año | Monica Helms (mujer trans, veterana de la Marina), diseñada en 1999 (agosto), mostrada en Phoenix en 2000; original donada al Smithsonian el 19-ago-2014 | https://en.wikipedia.org/wiki/Transgender_flag ; búsqueda con ficha del Smithsonian (National Museum of American History) | OK. REVISAR: la donación al Smithsonian la vi en resúmenes de búsqueda, no en la ficha del museo | [ ] Vanessa | sí |
| `bandera_trans`: colores | celeste y rosa = colores tradicionales de bebé niño/niña; blanco = transición, género neutro/indefinido, intersex (según Helms) | misma URL | OK. Hex del ícono #5BCEFA / #F5A9B8: REVISAR: sin confirmar (la página no da hex) | [ ] Vanessa | sí |
| `bandera_bi`: autor y año | Michael Page, 1998; presentada el 5-dic-1998 en el aniversario del BiCafe; paleta de Liz Nania | https://en.wikipedia.org/wiki/Bisexual_flag | OK | [ ] Vanessa | sí |
| `bandera_bi`: colores | magenta #D60270 = mismo sexo/género; azul #0038A8 = otro; morado #9B4F96 = mezcla. Hoy se lee también como atracción sin importar el género | misma URL | OK (hex de la página) | [ ] Vanessa | sí |
| `bandera_lesbica`: versiones | 1999 labrys (Sean Campbell); 2010 "lipstick" (Natalie McCray; criticada por excluir a lesbianas butch y por comentarios previos de la autora); 2010 versión rosa sin labios (autoría sin acreditar); 2016 y 2017 versiones butch; 2018 naranja-rosa | https://en.wikipedia.org/wiki/Lesbian_flag | OK. El juego solo nombra labrys, lipstick y la de 2018; no repite las críticas personales a McCray (solo la de exclusión de butch) | [ ] Vanessa | sí |
| `bandera_lesbica`: la de 2018 | atribuida a la bloguera de Tumblr Emily Gwen; 7 franjas: naranja rojizo = no conformidad de género, naranja = independencia, naranja claro = comunidad, blanco = relaciones únicas con la feminidad, rosa = serenidad y paz, rosa polvo = amor y sexo, rosa oscuro = feminidad. Hay una variante de 5 franjas (la más usada hoy según Wikipedia) | misma URL | OK en atribución ("se atribuye"). REVISAR: circulan significados distintos para las franjas; el juego usa los de Gwen. Hex #D52D00 #EF7627 #FF9A56 #FFFFFF #D162A4 #B55690 #A30262: REVISAR: sin confirmar (la página no da hex) | [ ] Vanessa | sí |
| `bandera_pan`: autor y año | 2010, publicada en un Tumblr anónimo por Jasper V. | https://en.wikipedia.org/wiki/Pansexual_flag | OK. Colores #FF218C #FFD800 #21B1FF (hex de la página). Significado (magenta = mujeres, cian = hombres, amarillo = no binarios) es "según algunas fuentes": el juego lo dice así | [ ] Vanessa | sí |
| `bandera_asexual`: autoría y año | AVEN (Asexual Visibility and Education Network), 2010; la propuso un miembro llamado "standup" | https://en.wikipedia.org/wiki/Asexual_flag | OK. | [ ] Vanessa | sí |
| `bandera_asexual`: colores | negro = asexualidad, gris = gris-asexualidad y demisexualidad, blanco = alosexualidad (a veces aliados), morado = comunidad. Hex #000000 #A3A3A3 #FFFFFF #800080 | misma URL | OK en significados. Hex: REVISAR: sin confirmar | [ ] Vanessa | sí |
| `bandera_nobinaria`: autor y año | Kye Rowan, febrero de 2014 | https://en.wikipedia.org/wiki/Non-binary_flag | OK | [ ] Vanessa | sí |
| `bandera_nobinaria`: colores | amarillo = géneros fuera del binario, blanco = varios géneros, morado = mezcla de masculino y femenino, negro = agénero. Hex #FFF433 #FFFFFF #9B59D0 #2D2D2D (diseño original) | misma URL | OK. Los hex del ícono (#FCF434, #9C59D1, #2C2C2C) son una variante de uso común: REVISAR: pasarlos a los de la página | [ ] Vanessa | sí |
| `bandera_intersex`: autor, año, org | Morgan Carpenter, julio de 2013, para Organisation Intersex International Australia (hoy Intersex Human Rights Australia); amarillo con círculo morado, sin asociación de género; el círculo = lo completo y las posibilidades | https://en.wikipedia.org/wiki/Intersex_flag | OK. Hex #FFD800 y #7902AA del ícono: REVISAR: sin confirmar | [ ] Vanessa | sí |
| `bandera_progress`: autor y año | Daniel Quasar, 2018; cuña con blanco, rosa y celeste = personas trans; marrón y negro = personas racializadas y lucha antirracista (el negro ya se usaba en la bandera "Victory Over AIDS") | https://en.wikipedia.org/wiki/Progress_Pride_flag | OK. REVISAR: el artículo también dice "franja amarilla = personas con VIH/sida", que parece error de resumen y NO se usó; el juego dice que el negro "recuerda el VIH/sida" (sin confirmar el detalle) | [ ] Vanessa | sí |
| `bandera_intersex_inclusiva`: autor y año | Valentino Vecchietti (Intersex Equality Rights UK), 2021: triángulo amarillo y círculo morado dentro de la cuña | https://en.wikipedia.org/wiki/Intersex_flag ; https://en.wikipedia.org/wiki/Progress_Pride_flag | OK | [ ] Vanessa | sí |

Hex de la Progress y la Intersex-Inclusiva del ícono (#E40303 #FF8C00 #FFED00 #008026 #004DFF #750787, cuña #FFFFFF #F5A9B8 #5BCEFA #613915 #000000): REVISAR: sin confirmar contra fuente oficial.

## B. Historia

| id / clave | afirmación (es, resumida) | fuente | estado y nota | Vanessa | universal sí/no |
|---|---|---|---|---|---|
| `hito_stonewall` | Redada policial en el Stonewall Inn (Nueva York) en la madrugada del sábado 28-jun-1969 (1:20 am); disturbios del 28-jun al 3-jul; símbolo del movimiento moderno, no el primer acto de resistencia | https://en.wikipedia.org/wiki/Stonewall_riots | OK. "No fue el primero" es contexto histórico conocido; REVISAR: sin confirmar en el tramo leído de la página | [ ] Vanessa | sí |
| `hito_marsha_sylvia` | Marsha P. Johnson y Sylvia Rivera cofundaron STAR (1970) para jóvenes LGBTIQ+ sin hogar | https://en.wikipedia.org/wiki/Sylvia_Rivera ; https://en.wikipedia.org/wiki/Marsha_P._Johnson | OK (STAR 1970; Marsha: disuelto en 1973) | [ ] Vanessa | sí |
| `hito_marsha_sylvia`: mito del "primer ladrillo" | Marsha contó que llegó hacia las 2 am con los disturbios en marcha; no se sabe quién lanzó el primer objeto. No se afirma nada sobre Sylvia esa noche: su presencia la discuten historiadores (David Carter) | las mismas dos páginas | OK. El texto del juego evita pronombres/etiquetas de identidad para Marsha porque las fuentes discrepan (se describió de varias formas; "I think of myself as me") | [ ] Vanessa | sí |
| `hito_primera_marcha` | 28-jun-1970, primer aniversario: Christopher Street Liberation Day en Nueva York, primera marcha del orgullo; hubo manifestaciones en otras ciudades de EE. UU. | https://en.wikipedia.org/wiki/Christopher_Street_Liberation_Day ; https://en.wikipedia.org/wiki/Stonewall_riots | OK la fecha y la marcha. "Otras ciudades": la página de Stonewall habla de "varias ciudades"; REVISAR: sin confirmar cuáles ni que fueran el mismo día | [ ] Vanessa | sí |
| `hito_17_mayo` | 17-may-1990: la Asamblea Mundial de la Salud de la OMS retira la homosexualidad de la CIE; por eso el 17 de mayo es el Día Internacional contra la Homofobia, la Transfobia y la Bifobia, celebrado desde 2005 (la transfobia se sumó al nombre en 2009 y la bifobia en 2015) | https://en.wikipedia.org/wiki/International_Day_Against_Homophobia,_Transphobia_and_Biphobia | OK la decisión de 1990 y la primera celebración de 2005. REVISAR: sin confirmar que el día exacto de la votación fuera el 17-may-1990 (la fecha se toma del propio Día Internacional) | [ ] Vanessa | sí |
| `hito_cie11` | CIE-11 respaldada por la 72.ª Asamblea Mundial de la Salud el 28-may-2019; en vigor desde el 1-ene-2022; la "incongruencia de género" sale del capítulo de trastornos mentales y pasa al de condiciones de salud sexual, porque no es un trastorno mental y clasificarlo así estigmatiza; se mantuvo un código para acceder a atención | https://en.wikipedia.org/wiki/ICD-11 ; https://www.who.int/standards/classifications/frequently-asked-questions/gender-incongruence-and-transgender-health-in-the-icd | OK (la FAQ de la OMS confirma el traslado de capítulo y el motivo; las fechas, Wikipedia) | [ ] Vanessa | sí |

## C. Conceptos

| id / clave | afirmación (es, resumida) | fuente sugerida | estado y nota | Vanessa | universal sí/no |
|---|---|---|---|---|---|
| `concepto_sexo_asignado` | se anota al nacer según el cuerpo; no dice identidad ni atracción; existen personas intersex | OMS / ONU Derechos Humanos (glosarios de diversidad sexual y de género); UNESCO, orientaciones técnicas de educación en sexualidad | REVISAR: sin confirmar contra el glosario citado (definiciones estándar, no las verifiqué palabra por palabra) | [ ] Vanessa | sí |
| `concepto_identidad_genero` | lo que cada persona siente que es; puede coincidir (cis) o no (trans, no binario) con el sexo asignado | ídem | REVISAR: sin confirmar | [ ] Vanessa | sí |
| `concepto_expresion_genero` | cómo se muestra (ropa, voz, gestos, nombre); no dice identidad ni orientación | ídem | REVISAR: sin confirmar | [ ] Vanessa | sí |
| `concepto_orientacion` | atracción sexual y afectiva; distinta de identidad y expresión; se puede ser trans y hetero, etc. | ídem | REVISAR: sin confirmar | [ ] Vanessa | sí |
| `concepto_pronombres` | ella, él, elle o el que cada quien use; se pregunta; equivocarse se corrige | guías de inclusión de organismos de derechos humanos | REVISAR: sin confirmar. Ojo: "elle" no es de uso oficial en todos los países ni en la RAE; la versión es_ES y fr (iel) conviene que las revise una persona hablante | [ ] Vanessa | sí |
| `concepto_salir_closet` | decisión de cada quien (si, cuándo, a quién, cómo); no se saca a otra persona del clóset | guías de organizaciones LGBTIQ+ y de salud mental juvenil | REVISAR: sin confirmar fuente concreta (consenso general, no un dato con cifra) | [ ] Vanessa | sí |

## D. Mitos y verdades (se abren al vencer a cada enemigo-prejuicio)

| id / clave | mito | verdad corta (es) | fuente sugerida | estado y nota | Vanessa | universal sí/no |
|---|---|---|---|---|---|---|
| `mito_es_una_fase` | "Es una fase" | la orientación y la identidad no son modas adolescentes; explorar a cualquier edad es conocerse | la verdad de fondo es el cambio de la CIE (`hito_17_mayo`, `hito_cie11`); para "fase", REVISAR: sin confirmar fuente concreta (APA y organismos de salud mental infanto-juvenil hablan de exploración legítima) | [ ] Vanessa | sí |
| `mito_el_armario` | "El Armario" | nadie le debe su orientación o identidad a nadie; guardarla es privacidad, no vergüenza | consenso de organizaciones LGBTIQ+ (ver `concepto_salir_closet`) | REVISAR: sin confirmar fuente concreta | [ ] Vanessa | sí |
| `mito_quien_es_el_hombre` | "¿Y quién es el hombre?" | una pareja no copia un guion hetero; tareas y roles se acuerdan | estudios de reparto de tareas en parejas del mismo sexo; sin fuente concreta | REVISAR: sin confirmar fuente concreta (el texto no afirma cifras) | [ ] Vanessa | sí |
| `mito_la_etiqueta` | "La Etiqueta" | las etiquetas son opcionales; sirven para describirse; no se le pone una a otra persona | glosarios de diversidad | REVISAR: sin confirmar fuente concreta | [ ] Vanessa | sí |

## Notas de tono y de riesgo

- El humor se ríe del prejuicio (el armario, la fase, el casting de "el hombre", la etiqueta), no de las personas. Las frases de sabor ("A closet is for coats, not for people") son del narrador del códice; las puede cambiar quien revise.
- Idiomas: es, en y fr están escritos; `es_ES` quedó vacío como en otros csv. La traducción fr y en la hice yo: conviene revisión de hablantes, sobre todo `concepto_pronombres` (iel / they) y las frases de sabor.
- Riesgo ya anotado en el plan: el Ornitorrinco como cara del Orgullo puede leerse como "el animal raro". Va a revisión de personas de la comunidad antes de publicar.
- "Cómo buscar ayuda" (E1) ya existe como entrada del códice (`como_buscar_ayuda`) y no se duplica aquí.
