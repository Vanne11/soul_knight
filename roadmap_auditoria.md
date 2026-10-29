# Roadmap de la auditoría (2026-10-29)

Auditoría de código en 4 zonas: autoloads/UI, jugador/ítems, enemigos y mazmorra. Se generaron 3600 pisos de prueba y el bot e2e no se corrió.
Leyenda: [x] arreglado · [ ] pendiente.

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
- [ ] M1 Bendición / elección del narrador se abre sobre el menú de pausa y al elegir despausa el
  juego detrás. `main.gd` (timers de recompensa), `blessing_picker.gd:215`, `narrator.gd:357`
- [ ] M2 `lore_progress.json` corrupto deja el códice muerto (sin `is Dictionary`); además se
  reescribe en cada kill (microtirones). `src/autoloads/lore_database.gd`
- [ ] M3 Jaula maldita + Censura de escudo: al liberarla `max_shields` queda negativo.
  `src/items/item_slots.gd:191`, `player_stats.gd` `max_shields_flat`
- [ ] M4 Un solo E acciona dos interactuables pegados en el mismo frame (premios del cofre con
  llave). `src/items/interactable.gd` `_handoff`
- [ ] M5 Lentitudes de espermicida/charco/masilla se pisan: enemigo lento para siempre.
  `src/weapons/puddle.gd`, `masilla.gd`, `lube_patch.gd`, `src/player/defenses/espermicida.gd`
- [ ] M6 Ladrona que escapa a la sala de la misión de llave nunca aparece (monedas perdidas, cartel
  miente). `src/rooms/obj_thief.gd:216`, `room_director.gd`
- [ ] M7 Bala sin perforación daña a dos enemigos en el mismo frame. `src/player/player_bullet.gd`
- [ ] M8 Liberarse de una maldición con la llave de la misión deja la misión trabada.
  `src/items/item_slots.gd:269`, `key_quests.gd`

## Baja
- [ ] B1 Narrador arrastra la cola de frases a la partida siguiente (`narrator.gd` `_on_run_started`).
- [ ] B2 `FloorEvents` (p. ej. "censura") queda pegado en pisos de paz y oculta el minimapa (`main.gd:111`).
- [ ] B3 "Volver al menú" despausa 0.25 s antes de la cortinilla (`pause_menu.gd:140`).
- [ ] B4 Tiempo de partida y emboscadas cuentan el tiempo en pausa (`run_manager.gd`, `waves.gd`).
- [ ] B5 Pinchos y respiraderos siguen dañando con la sala limpia (`trap_room.gd`).
- [ ] B6 30 claves sin francés en `locale/jefes_cera_dano.csv` y `jefes_cera_dinamica.csv`.
- [ ] B7 `required_intoxication_tier` / `Room.can_enter()` asignados pero nunca aplicados.
- [ ] B8 Detalles: Pastilla del Día Después cura el daño bruto; Suspensorio `_proj` obsoleto;
  trampa de oso salta con cadáveres; el bajón del Estimulante se anula con otro buff de velocidad;
  altar de sangre resta vida antes de `take_key`; `Enemy.die()` usa `animated_sprite` antes de
  comprobarlo; Hoja de Parra puede reiniciar el revivir con un `die()` directo.
