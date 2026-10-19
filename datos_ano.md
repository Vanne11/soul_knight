# datos_ano.md — Datos del reino secreto LA PUERTA TRASERA (nombre provisorio)

Para: **Vanessa** (autora, área de salud). Mismo formato que `datos_salud.md` y `datos_orgullo.md`: cada fila es un dato que el juego va a afirmar, con su fuente sugerida y una casilla de revisión.
Estado: **previsto**. El reino aún no existe; las claves `LORE_PT_*` son las que se usarán al implementarlo (los textos de El Coprolito ya están en `locale/puerta_trasera.csv`). Nada de este documento se muestra al jugador hasta que Vanessa revise.
Tono: el humor es sobre la situación (“entrada de servicio”, “solo salida”), nunca sobre las personas ni sobre ninguna práctica. No se promueve ni se ridiculiza el sexo anal: se informa, y se deja claro que es una decisión libre de cada persona.

Advertencia de método: no tengo acceso a internet en este entorno. Las fuentes salen de mi conocimiento de las guías (OMS, NHS, CDC, NIDDK, ASCRS, UNESCO) y **no se verificó cada cita contra el original**. Se evitaron a propósito cifras, edades e intervalos que varían por guía o país. Lo que no pude respaldar queda marcado **REVISAR**.

- ✅ coincide con la fuente sugerida (cualitativo, sin cifras).
- ⚠️ / REVISAR: matiz o sin cita literal verificada; la nota dice qué mirar.
- ❌ incorrecto: ninguno.

## A. Salud anal: hemorroides, fisuras, hábitos

| id / clave | dónde se ve | afirmación exacta (es) | fuente sugerida | estado y nota | Vanessa | universal sí/no |
|---|---|---|---|---|---|---|
| PT-01 `LORE_PT_HEMORROIDES_TEXT` | Códice, enemigo Hemorroide Fronteriza (ya existe) y cartel del reino | “Las hemorroides son tejido normal del ano que a veces se inflama. Son muy comunes, en todos los cuerpos, no son culpa tuya y casi siempre se tratan.” | NHS, *Haemorrhoids*; ASCRS (Sociedad Estadounidense de Cirujanos de Colon y Recto), hoja para pacientes | ✅ Afirmación cualitativa, sin cifras. | [ ] Vanessa | sí |
| PT-02 `LORE_PT_HEMORROIDES_TEXT (b)` | Códice, Hemorroide Fronteriza | “Fibra, agua, no pujar de más y moverte suelen aliviarlas. Si sangran o duelen mucho, consulta.” | NHS; ASCRS | ✅ | [ ] Vanessa | sí |
| PT-03 `LORE_PT_HEMORROIDES_MITO_TEXT` | Mito o Verdad (previsto) | “Mito: las hemorroides son cáncer o llevan al cáncer. Verdad: no. Pero si sangras, que lo mire un profesional: no todo sangrado es una hemorroide.” | ASCRS; NHS | ✅ Hemorroides no causan cáncer; el matiz del sangrado va en PT-10. | [ ] Vanessa | sí |
| PT-04 `LORE_PT_FISURA_TEXT` | Códice, enemigo Fisura (previsto) | “Una fisura anal es un desgarro pequeño en el borde del ano. Duele al hacer caca y puede dejar sangre roja y viva. Es común y muchas cicatrizan solas.” | NHS, *Anal fissure*; ASCRS | ✅ | [ ] Vanessa | sí |
| PT-05 `LORE_PT_FISURA_TEXT (b)` | Códice, enemigo Fisura | “Con fibra, agua y baños tibios suele mejorar. Si no mejora o el dolor es fuerte, hay tratamientos; consulta.” | NHS; ASCRS | ✅ Sin plazos concretos a propósito (las guías varían). | [ ] Vanessa | sí |
| PT-06 `LORE_PT_NO_AGUANTARSE_TEXT` | Códice y cartel, jefe El Coprolito | “Si tu cuerpo avisa, ve al baño. Aguantarse una y otra vez puede endurecer la caca y dejarte estreñida o estreñido.” | NHS, *Constipation*; NIDDK (EE. UU.), *Constipation* | ✅ Lo recomiendan ambas fuentes (no ignorar el impulso). | [ ] Vanessa | sí |
| PT-07 `LORE_PT_NO_PUJAR_TEXT` | Cartel de sala, códice del jefe | “Pujar fuerte y pasar mucho rato sentado en el inodoro (con el celular, por ejemplo) castiga a las hemorroides.” | NHS; ASCRS | ⚠️ REVISAR: lo del celular es consejo frecuente de coloproctología, pero no encontré una frase literal citable. Dejar solo “pujar fuerte y mucho rato” si Vanessa prefiere. | [ ] Vanessa | sí |
| PT-08 `LORE_PT_FIBRA_AGUA_TEXT` | Códice, Coprolito; evento de sala | “Frutas, verduras, legumbres, cereales integrales y agua: la fibra necesita agua para ablandar la caca. Moverte también ayuda.” | OMS, *Healthy diet* (nota descriptiva); NHS, *Constipation* | ✅ Sin gramos a propósito (la cifra diaria varía por guía). | [ ] Vanessa | sí |
| PT-09 `LORE_PT_ESTRENIMIENTO_TEXT` | Códice, jefe El Coprolito | “El estreñimiento es muy común y casi siempre se resuelve con hábitos. Lo normal varía de persona a persona. Si es persistente, duele mucho o cambia sin motivo, consulta.” | NHS; NIDDK | ✅ Se evita a propósito el “normal es X veces por día”. | [ ] Vanessa | sí |
| PT-10 `LORE_PT_SANGRE_TEXT` | Cartel de salida del reino; códice del jefe | “Sangre en las deposiciones: no la adivines, consúltala. Puede ser algo menor, como una hemorroide, pero solo un profesional lo confirma.” | OMS, nota descriptiva *Cáncer colorrectal* (síntomas); NHS, *Bowel cancer symptoms* | ✅ | [ ] Vanessa | sí |
| PT-11 `LORE_PT_LAXANTES_TEXT` | Objeto/evento de farmacia (previsto) | “Los laxantes no son para vivir con ellos: pregunta en la farmacia o en tu centro de salud antes de usarlos seguido.” | NHS, *Laxatives* | ⚠️ REVISAR: consejo general de prudencia; confirmar tono con Vanessa. | [ ] Vanessa | sí |
| PT-12 `LORE_PT_MITO_FRIO_TEXT` | Mito o Verdad (previsto) | “Mito: sentarse en piedra o en un suelo frío da hemorroides. Verdad: no hay evidencia; influyen el esfuerzo al evacuar, el estreñimiento y otros factores.” | NHS; ASCRS | ⚠️ REVISAR: no lo confirmé en una fuente que lo nombre expresamente. Si no se puede respaldar, quitarlo. | [ ] Vanessa | sí |

## B. ITS, VPH anal y vacunas

| id / clave | dónde se ve | afirmación exacta (es) | fuente sugerida | estado y nota | Vanessa | universal sí/no |
|---|---|---|---|---|---|---|
| PT-13 `LORE_PT_ITS_ANAL_TEXT` | Códice, cartel de entrada | “Por vía anal también se pueden transmitir ITS (como VIH, clamidia, gonorrea, sífilis, herpes y VPH). Se previenen con condón, lubricante y pruebas periódicas.” | OMS, nota descriptiva *ITS*; CDC, *Anal sex and STIs* | ✅ Ver también IT en datos_salud.md. | [ ] Vanessa | sí |
| PT-14 `LORE_PT_ITS_ANAL_TEXT (b)` | Códice, enemigo Mito (previsto) | “El sexo anal sin protección tiene más riesgo de transmitir el VIH que otras prácticas, porque el tejido se lesiona con más facilidad.” | CDC, *HIV Risk Behaviors* | ⚠️ REVISAR: es cierto cualitativamente (CDC); no pongo cifras. Confirmar que Vanessa quiere la comparación. | [ ] Vanessa | sí |
| PT-15 `LORE_PT_VPH_ANAL_TEXT` | Códice, enemigo VPH Anal (previsto) | “El VPH también puede estar en el ano, en cualquier cuerpo. Casi siempre no da síntomas; a veces causa verrugas y, rara vez, cáncer anal.” | OMS, nota descriptiva VPH; CDC, *HPV and cancer* | ✅ Sin cifras. | [ ] Vanessa | sí |
| PT-16 `LORE_PT_VPH_VACUNA_TEXT` | Códice, cartel | “La vacuna contra el VPH protege también de los tipos que causan verrugas y cánceres anales. Pregunta en tu centro de salud si te toca.” | OMS, documento de posición sobre vacunas VPH (2022); CDC | ⚠️ REVISAR: los tipos de las vacunas varían (no todas cubren verrugas). Ver IT-03 en datos_salud.md. | [ ] Vanessa | sí |
| PT-17 `LORE_PT_TAMIZAJE_ANAL_TEXT` | Códice (previsto) | “Algunas personas con más riesgo se hacen controles del ano. Si te preocupa, pregunta a tu equipo de salud.” | CDC, *Anal cancer screening* | ⚠️ REVISAR: las guías de tamizaje anal varían mucho por país y población; no pude verificar una recomendación universal. Mantener sin edades ni intervalos. | [ ] Vanessa | no (depende del país) |
| PT-18 `LORE_PT_HEPATITIS_TEXT` | Códice (previsto) | “Hay vacunas contra las hepatitis A y B. Las dos se pueden pasar con prácticas que tocan la zona anal.” | OMS, notas descriptivas hepatitis A y B; CDC | ⚠️ REVISAR: la hepatitis A pasa por contacto oral-anal; confirmar redacción. | [ ] Vanessa | sí |
| PT-19 `LORE_PT_PRUEBAS_TEXT` | Cartel de entrada | “Muchas ITS no dan síntomas. Hacerse pruebas es cuidado, no sospecha.” | OMS, nota descriptiva ITS | ✅ Ver el dato “sin síntomas” de datos_salud.md. | [ ] Vanessa | sí |

## C. Condón y lubricante

| id / clave | dónde se ve | afirmación exacta (es) | fuente sugerida | estado y nota | Vanessa | universal sí/no |
|---|---|---|---|---|---|---|
| PT-20 `LORE_PT_ANO_LUBRICA_TEXT` | Códice, objeto Lubricante; cartel | “El ano no se lubrica solo. Con lubricante, y con calma, se cuida el tejido.” | NHS, *Anal sex*; Planned Parenthood; CDC | ✅ | [ ] Vanessa | sí |
| PT-21 `LORE_PT_LUBE_TIPOS_TEXT` | Códice, objeto Lubricante | “Lubricante a base de agua o de silicona. Con condones de látex, nunca aceites (vaselina, aceite de bebé, crema de manos): rompen el látex.” | CDC, *Condom use*; NHS, *How to use condoms* | ✅ | [ ] Vanessa | sí |
| PT-22 `LORE_PT_SILICONA_JUGUETES_TEXT` | Códice, objeto Juguete (previsto) | “El lubricante de silicona puede dañar los juguetes de silicona; para ellos, usa uno a base de agua.” | Fabricantes de juguetes; Planned Parenthood | ⚠️ REVISAR: consejo de uso, no de salud; fuente institucional por confirmar. | [ ] Vanessa | sí |
| PT-23 `LORE_PT_CONDON_ANAL_TEXT` | Códice, objeto Preservativo | “El condón también protege en el sexo anal. Se pone antes de empezar, con lubricante, y se cambia si pasas a otra práctica.” | CDC, *Condom use*; OMS | ✅ | [ ] Vanessa | sí |
| PT-24 `LORE_PT_CONDON_INTERNO_TEXT` | Códice (previsto) | “El condón interno también se puede usar por vía anal.” | CDC, *Internal condoms* | ⚠️ REVISAR: depende de la autorización de cada país; no afirmar si Vanessa no lo confirma. | [ ] Vanessa | no (depende del país) |
| PT-25 `LORE_PT_BASE_JUGUETES_TEXT` | Códice, objeto Juguete (previsto) | “Un juguete anal necesita base ancha: sin ella, puede quedarse dentro y acabar en urgencias.” | Consejo de coloproctología y urgencias (sociedades colorrectales) | ⚠️ REVISAR: consejo muy extendido pero sin cita literal verificada. Si no hay fuente, dejarlo como aviso de seguridad sin cifras. | [ ] Vanessa | sí |
| PT-26 `LORE_PT_LIMPIEZA_TEXT` | Códice (previsto) | “No hace falta ningún ritual extremo. Con higiene normal basta; las duchas internas o enemas frecuentes pueden irritar.” | NHS, *Anal sex*; sociedades de coloproctología | ⚠️ REVISAR: no pude verificar una cita puntual; decidir con Vanessa si se incluye. | [ ] Vanessa | sí |

## D. Consentimiento

| id / clave | dónde se ve | afirmación exacta (es) | fuente sugerida | estado y nota | Vanessa | universal sí/no |
|---|---|---|---|---|---|---|
| PT-27 `LORE_PT_CONSENT_TEXT` | Códice, cartel de entrada, evento “Entrada de servicio” | “Aquí también se pregunta. Nada se hace “porque sí”, ni “porque todo el mundo lo hace”: sin presión, un sí que se puede retirar.” | UNESCO, *Orientaciones técnicas internacionales sobre educación en sexualidad* (2018); OMS | ✅ Coherente con OT-06 de datos_salud.md. | [ ] Vanessa | sí |
| PT-28 `LORE_PT_PARAR_TEXT` | Evento de sala, cartel | “En cualquier momento se puede parar, cambiar o decir que no, aunque ya hayan empezado.” | UNESCO (2018); OMS | ✅ | [ ] Vanessa | sí |

## E. Tamizaje de cáncer colorrectal

| id / clave | dónde se ve | afirmación exacta (es) | fuente sugerida | estado y nota | Vanessa | universal sí/no |
|---|---|---|---|---|---|---|
| PT-29 `LORE_PT_TAMIZAJE_TEXT` | Códice, cartel de salida del reino | “El tamizaje de cáncer colorrectal busca problemas antes de que den síntomas. La edad y el examen dependen del país: pregunta en tu centro de salud.” | OMS, nota descriptiva *Cáncer colorrectal*; NHS, *Bowel screening*; CDC | ✅ Se evita a propósito dar edades, para ser universal. | [ ] Vanessa | no (edad y método según el país) |
| PT-30 `LORE_PT_SINTOMAS_TEXT` | Códice, jefe El Coprolito | “Consulta si hay sangre en la caca, cambios que duran semanas o dolor persistente. Casi siempre no es grave, pero hay que mirarlo.” | OMS; NHS, *Bowel cancer symptoms* | ⚠️ REVISAR: “semanas” es deliberadamente vago (las guías dicen 3 semanas o más en algunos países). | [ ] Vanessa | sí |

## F. Desmitificar el sexo anal

| id / clave | dónde se ve | afirmación exacta (es) | fuente sugerida | estado y nota | Vanessa | universal sí/no |
|---|---|---|---|---|---|---|
| PT-31 `LORE_PT_ORIENTACION_TEXT` | Mito o Verdad (previsto) | “Mito: el sexo anal define tu orientación. Verdad: no. Personas de todos los cuerpos y orientaciones lo practican, y muchas nunca.” | OMS, *Sexual health*; UNESCO (2018) | ✅ Sin porcentajes. | [ ] Vanessa | sí |
| PT-32 `LORE_PT_DOLOR_TEXT` | Mito o Verdad (previsto) | “Mito: tiene que doler. Verdad: no. Si duele, se para; ir despacio, con lubricante y comunicación, importa.” | NHS, *Anal sex*; Planned Parenthood | ✅ | [ ] Vanessa | sí |
| PT-33 `LORE_PT_NO_OBLIGADO_TEXT` | Códice, cartel de entrada | “No es obligatorio ni es una prueba de nada. Se puede hacer, probar o dejarlo; las dos opciones son normales.” | UNESCO (2018) | ✅ No promueve ni desalienta. | [ ] Vanessa | sí |
| PT-34 `LORE_PT_PLACER_TEXT` | Códice (previsto) | “El ano tiene muchas terminaciones nerviosas. A algunas personas les gusta, a otras no, y ambas cosas son normales.” | Fuentes de sexología (p. ej., Kinsey Institute); NHS | ⚠️ REVISAR: afirmación anatómica aceptada, pero no tengo una cita literal verificada. | [ ] Vanessa | sí |

## G. Poppers (reducción de daños) — Templo de Anubis

| id / clave | dónde se ve | afirmación exacta (es) | fuente sugerida | estado y nota | Vanessa | universal sí/no |
|---|---|---|---|---|---|---|
| PT-35 `LORE_ENE_FRASQUITO_TEXT` | Códice, enemigo Frasquito Mágico (se abre al matar 3) | “Los «poppers» son nitritos que se inhalan; dilatan los vasos sanguíneos y bajan la presión, y por eso dan mareo, dolor de cabeza y a veces desmayo. Sobre la piel pueden quemar; no se deben tragar; son inflamables; y están contraindicados con problemas del corazón, presión baja o glaucoma. NUNCA se mezclan con sildenafil (Viagra), tadalafilo u otros medicamentos para la erección: juntos pueden bajar la presión de forma peligrosa. Si hay dolor de pecho, mareo fuerte o desmayo, pide ayuda médica de inmediato.” | CDC; NHS (*Poppers*); Drugs.ie / Energy Control (reducción de daños); prospectos de sildenafil y tadalafilo (contraindicación con nitratos) | ⚠️ REVISAR: la contraindicación con inhibidores de la PDE5 está en los prospectos (nitratos); confirmar la lista de contraindicaciones (corazón, presión baja, glaucoma) y el tono sobrio, sin moralina. | [ ] Vanessa | sí |
| PT-36 `PT_POPPER_SILDENAFIL` | Aviso flotante del Frasquito si ya te cruzaste con Don Sildenafil en la partida | “¡Popper + Sildenafil = NO!” | ídem PT-35 | ⚠️ REVISAR: guiño con Don Sildenafil; mantener solo como alerta de seguridad. | [ ] Vanessa | sí |
| PT-37 `LORE_TEMPLO_PUERTA_TEXT` | Códice críptico al abrir la puerta biológica | “Los condones de látex y el lubricante van juntos; el lubricante debe ser a base de agua o de silicona, nunca aceites con el látex.” | OMS; CDC (PT-21) | ✅ (repite PT-21) | [ ] Vanessa | sí |

## Conteo

Total: **37 datos**; **15** con REVISAR y 22 ✅ (PT-35 a PT-37: poppers y puerta biológica). Por tema: G 3, A 12, B 7, C 7, D 2, E 2, F 4.

Datos que dependen del país (“universal: no”): tamizaje colorrectal (PT-29), tamizaje anal (PT-17) y condón interno (PT-24). Todos los textos del juego dicen “pregunta en tu centro de salud”, sin nombrar instituciones nacionales.

## Dónde se conectan (resumen; el detalle está en el diseño del reino, fuera del repo)

- Códice: sección Salud, entradas `LORE_PT_*` (se abren al derrotar al enemigo correspondiente o al entrar al reino con `LoreDatabase.custom_event(...)`).
- Carteles de sala: PT-20, PT-23, PT-27, PT-28, PT-33 (entrada) y PT-10, PT-29 (salida).
- Mito o Verdad: PT-03, PT-12, PT-31, PT-32.
- Jefe El Coprolito: PT-06, PT-07, PT-08, PT-09, PT-30.
