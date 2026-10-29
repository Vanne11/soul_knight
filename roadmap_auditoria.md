# Roadmap de la auditoría (2026-10-29)

Auditoría de código en 4 zonas: autoloads/UI, jugador/ítems, enemigos y mazmorra. Se generaron 3600 pisos de prueba y el bot e2e no se corrió.
Leyenda: [x] arreglado · [ ] pendiente · [-] movido a diseño.

## Alta (afectan una partida normal)
- [x] A1 Monte de Venus se pierde en ~65% de las partidas: un solo intento en un piso de la Selva y
  casi nunca hay sala libre >=10x8 (las grandes van a jefe/tienda/inicio). `src/dungeon/monte_venus.gd`
  -> Arreglo: el piso del Monte agranda hasta 3 salas a 11x8 al planear; si una grande quedó de
  tienda/antro/puzzle le pasa el tipo a un combate; si aun asi no cabe, pasa al 2do piso de la Selva.
  Medido en 400 partidas: 94,5% con Monte (antes ~35%). El 5,5% restante: la única sala grande libre es
  la del minijefe. Invariantes del generador (3600 pisos) y de formas (360) siguen en 0.
- [x] A2 Sala gratis sin pelear: desarmado las puertas no se sellan; abrirlas todas desde dentro
  da la sala por limpia (enemigos borrados + recompensa). Igual en salas de puzle sin resolver.
  `src/dungeon/room.gd` `_on_door_state_changed` -> solo limpia si no quedan bichos vivos ni puzzle sin resolver.
- [x] A3 Escudo NaN para siempre: héroe con escudo base 0 + ítem que multiplica `max_shields`
  (ankh_anubis) -> 0*(0/0). `src/autoloads/player_stats.gd` `apply_stat_mod`
- [x] A4 Muertes fantasma: `take_damage` sigue con el jugador a 0 de vida; el "ardor" repite
  `player_died` cada 2 s en game over/menú (narrador, códice y cuarta pared suman muertes).
  `src/autoloads/player_stats.gd`
- [x] A5 Clave `BOSS_CH_AGUA_T/_D` duplicada (Coprolito y Don Sildenafil, desafíos distintos):
  un jefe muestra las instrucciones del otro. `locale/jefes_alt.csv`, `locale/puerta_trasera.csv`
  -> el desafío del Coprolito pasa a `ch_vasos` / `BOSS_CH_VASOS_*`.
- [x] A6 Minions mueren dos veces (botín y conteos dobles) cuando el jefe muere o la Hoja cae
  mientras un minion está en su animación de muerte. `src/enemies/enemy.gd` `die()`
  -> guarda DEAD en Enemy, swarmer, ranged y tank; la Hoja de Parra no reinicia el revivir.
- [x] A7 Etiquetas de La Etiqueta: el contador no vuelve a 0 (la primera nueva ya frena al 55%) y
  el dash no las rompe (`Arcoiria.rip_labels` sin llamador). `src/player/status_effects.gd`
  -> `labels = 0` al terminar; el dash las rompe con su anillo de daño.

## Media
- [x] M1 Bendición / elección del narrador se abre sobre el menú de pausa y al elegir despausa el
  juego detrás. `main.gd` (timers de recompensa), `blessing_picker.gd:215`, `narrator.gd:357`
  -> `PauseMenu.release()`: solo despausa si no queda otra pantalla que pausa (pausa, bendición, elección).
- [x] M2 `lore_progress.json` corrupto deja el códice muerto (sin `is Dictionary`); además se
  reescribe en cada kill (microtirones). `src/autoloads/lore_database.gd`
  -> valida el JSON (ilegible = se ignora) y guarda como mucho cada 3 s + al cerrar.
- [x] M3 Jaula maldita + Censura de escudo: al liberarla `max_shields` queda negativo.
  `src/items/item_slots.gd:191`, `player_stats.gd` `max_shields_flat`
  -> guarda lo que de verdad sumó (con Censura) y el escudo nunca baja de 0.
- [x] M4 Un solo E acciona dos interactuables pegados en el mismo frame (premios del cofre con
  llave). `src/items/interactable.gd` `_handoff`
  -> un E se usa una sola vez por fotograma.
- [x] M5 Lentitudes de espermicida/charco/masilla se pisan: enemigo lento para siempre.
  `src/weapons/puddle.gd`, `masilla.gd`, `lube_patch.gd`, `src/player/defenses/espermicida.gd`
  -> `src/weapons/slow_stack.gd`: cada fuente pone y quita su factor (producto); respeta si la IA recalcula.
- [x] M6 Ladrona que escapa a la sala de la misión de llave nunca aparece (monedas perdidas, cartel
  miente). `src/rooms/obj_thief.gd:216`, `room_director.gd`
  -> la ladrona no huye a salas bloqueadas (hormona / misión de llave); si sale por ahí, se pierde con el aviso correcto.
- [x] M7 Bala sin perforación daña a dos enemigos en el mismo frame. `src/player/player_bullet.gd`
  -> `_done = true` al impactar.
- [x] M8 Liberarse de una maldición con la llave de la misión deja la misión trabada.
  `src/items/item_slots.gd:269`, `key_quests.gd`
  -> se gasta primero otra llave; si era la de la misión, vuelve a su sitio (`lose("spent")`, texto PZ_KEY_LOST_SPENT).

## Baja
- [x] B1 Narrador arrastra la cola de frases a la partida siguiente (`narrator.gd` `_on_run_started`).
  -> `_on_run_started` llama `hush()` y limpia la queja pendiente.
- [x] B2 `FloorEvents` (p. ej. "censura") queda pegado en pisos de paz y oculta el minimapa (`main.gd:111`).
  -> `FloorEvents.clear()` en los pisos de paz.
- [x] B3 "Volver al menú" despausa 0.25 s antes de la cortinilla (`pause_menu.gd:140`).
  -> sigue pausado durante la cortinilla; `Transition.change_scene` despausa al cambiar la escena.
- [x] B4 Tiempo de partida y emboscadas cuentan el tiempo en pausa (`run_manager.gd`, `waves.gd`).
  -> `RunManager.run_played_time` (se detiene en pausa) y la emboscada usa tiempo de juego.
- [x] B5 Pinchos y respiraderos siguen dañando con la sala limpia (`trap_room.gd`).
  -> pinchos y respiraderos quedan abajo con la sala limpia.
- [x] B6 30 claves sin francés en `locale/jefes_cera_dano.csv` y `jefes_cera_dinamica.csv`.
  -> 30 traducciones al francés agregadas (fr 0 faltantes).
- [-] B7 `required_intoxication_tier` / `Room.can_enter()` asignados pero nunca aplicados. -> pasa a diseño (D2).
- [x] B8 Detalles: Pastilla del Día Después cura el daño bruto; Suspensorio `_proj` obsoleto;
  trampa de oso salta con cadáveres; el bajón del Estimulante se anula con otro buff de velocidad;
  altar de sangre resta vida antes de `take_key`; `Enemy.die()` usa `animated_sprite` antes de
  comprobarlo; Hoja de Parra puede reiniciar el revivir con un `die()` directo.
  -> todos: Pastilla cura la vida realmente perdida; Suspensorio resetea `_proj` cada fotograma;
  `ItemActions.enemies()` salta cadáveres; buffs y bajones temporales van por separado; el altar cobra
  solo si entrega la llave; `die()` y la Hoja ya estaban (A6).

## Diseño (anotado por Nico, 2026-10-29)
- [x] D1 Bendiciones del Ornitorrinco y reparto (Nico, 2026-10-29).
  -> Set propio "ninguno" (NO ESPECIFICA, color 5fd6b4), ni de Penelandia ni de Vulvania, sin alergia:
  Electrorrecepción (balas aturden), Espolón Venenoso (dash envenena), Puesta Inexplicable (huevo que cura
  al limpiar), Cola de Castor (-10% daño), Pico de Pato (+25% alcance), Casilla en Blanco (+6% de todo).
  `roll_blessings()` reparte 3-0 (30%), 2-1 (40%) o 1-1-1 (30%: reino / Ornitorrinco AL MEDIO / contrario),
  para todos los héroes. Iconos en tools/gen_blessing_icons.py; en el árbol, rama compacta bajo Equilibrio.
- [x] D2 Requisito de intoxicación: el generador pone `required_intoxication_tier` 1-2 al antro y 2 a la
  secreta, pero nadie lo aplica (`Room.can_enter()` sin llamador; `Door.try_open` solo lo mira en puertas
  LOCKED y la puerta nunca recibe el valor). Hoy se entra siempre. Decidir: aplicarlo (el antro pide estar
  "entonado") o borrar la configuración muerta.
  -> Nico (2026-10-29): se entra entonado. El antro pide ACHISPADO (nivel 1): `main._lock_antro_rooms()`
  pone candado de intoxicación a sus puertas, solo si el antro no corta el paso (el resto del piso se
  alcanza sin cruzarlo). Junto a cada puerta, por fuera, una botella "de la previa" (DrunkBottle, +50)
  que vuelve si te la tomaste y sigues sobrio. El generador prefiere el antro en una rama sin salida
  fuera del camino al jefe. Medido (2400 pisos): 70% de los antros con candado; el resto queda abierto.
  La secreta sigue abriéndose solo con el puzzle (su tier 2 no se usa).
- [x] D3 Espacios de guardado (Nico, 2026-10-29; reemplaza el botón "Borrar progreso").
  -> 3 espacios (`src/core/save_slots.gd`, user://slot_N/) con JUGAR / DUPLICAR / ELIMINAR (doble
  pulsación). Se eligen tras el aviso +16 (`src/scenes/save_slots.tscn`) y desde el menú (ESPACIO N).
  El guardado de antes pasa solo al espacio 1. Ajustes y teclas siguen siendo de la máquina.
