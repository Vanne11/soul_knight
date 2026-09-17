# Soul Knight PC

Roguelite cenital estilo *Soul Knight*, hecho con **Godot 4.7** (GDScript).

## Cómo ejecutarlo

```bash
godot --path .            # jugar
godot -e --path .         # abrir el editor
python3 tools/gen_placeholder_art.py   # regenerar el arte placeholder
```

## Controles

| Acción | Tecla |
|---|---|
| Moverse | `W` `A` `S` `D` |
| Apuntar | ratón |
| Disparar | clic izquierdo (mantener) |
| Esquiva (da invulnerabilidad) | `Espacio` |
| Reiniciar | `R` |

## Estructura

```
assets/sprites/     PNG 16x16 generados por tools/gen_placeholder_art.py
assets/shaders/     flash.gdshader — destello blanco al recibir un golpe
resources/          TileSet de la mazmorra y armas (.tres = datos puros)
scenes/             .tscn — los "prefabs" del juego
scripts/
  autoload/events.gd      bus de señales global (singleton)
  components/health.gd    vida + armadura + invulnerabilidad (reutilizable)
  actors/                 player.gd, enemy.gd (base), slime.gd
  weapons/                weapon_data.gd (datos), weapon.gd (comportamiento)
  projectiles/bullet.gd
  world/                  main.gd, room_builder.gd, game_camera.gd
  ui/hud.gd
```

## Decisiones de diseño

- **Composición sobre herencia**: cualquier cosa que pueda recibir daño lleva un
  nodo hijo `Health`. Las balas no preguntan "¿eres un enemigo?", preguntan
  "¿tienes Health?".
- **Bus de señales** (`Events`): el HUD no conoce al jugador ni al revés.
- **Armas como datos**: cada arma es un `.tres`. Añadir una escopeta es crear un
  archivo con `bullet_count = 5`, no escribir código.
- **Armadura regenerativa** (la firma de Soul Knight): absorbe el daño antes que
  la vida y vuelve sola tras 4 s sin recibir golpes. Hace el juego exigente sin
  ser injusto.
- **Capas de física** nombradas en `project.godot`: `world`, `player`, `enemy`,
  `player_bullet`, `enemy_bullet`, `pickup`.

## Estado actual

Una sala jugable: te mueves, apuntas, disparas, esquivas; 8 slimes que saltan
hacia ti y hacen daño al contacto; HUD de vida/armadura/energía; muerte y
reinicio. Feedback: destello al golpear, sacudida de cámara, retroceso,
empujón, *squash & stretch*, estela de esquiva.

## Siguientes pasos

1. **Mazmorra generada**: varias salas conectadas por puertas que se cierran
   hasta despejar la sala (`room_builder.gd` ya está preparado para ello).
2. **Más enemigos**: uno a distancia que dispare, uno que cargue.
3. **Armas y drops**: soltar armas en el suelo y poder cambiarlas con `F`.
4. **Personajes** con habilidad activa (`E`) y estadísticas propias.
5. **Jefe** al final del piso.
6. **Meta-progresión**: gemas y desbloqueos entre partidas.
7. **Audio**: disparo, impacto, muerte, música.
