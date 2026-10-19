# Inventario de dano por contacto (J0b) - SOLO INFORME

Base: 120fb75. Leido de `src/enemies/*.gd` y `*.tscn` y de los tipos que usan `assets/data/floors/*.json` (+ `floors/extra/enemigos3a.json`).
No se cambio ningun enemigo.

## Hallazgo principal

**Hoy NINGUN enemigo pega por simple roce.** En `enemy.gd`, `enemy_swarmer.gd`, `enemy_tank.gd`, `enemy_ranged.gd` y `enemy_boss.gd` el
`Hitbox` se pone `monitorable = false` y el dano solo sale de `_strike()`, que mira `get_overlapping_bodies()` unicamente en el estado de
embestida (LUNGE / DART / CHARGING / carga del jefe). El roce con el `Hurtbox`/cuerpo no hace nada. Ademas:

- Los cuerpo a cuerpo ya "disparan su ataque al tocarlos": `_chase()` pasa a WINDUP cuando la distancia baja de `lunge_trigger`
  (110 px por defecto, 70-230 segun el enemigo), con aviso (parpadeo + temblor) y solo pega la embestida si te alcanza. Con dash o
  alejandote durante el aviso no pasa nada. La regla del plan J0b ("tocarlos dispara su ataque, 0.3-0.5 s") esta casi cumplida;
  lo que falta es el empujon suave al tocarlos sin dano y el codice.
- Los `_strike()` propios (`enemy3a_base`, `enemy_its`, `enemy_dedo`, `enemy_tank`, `enemy_swarmer`) solo se llaman dentro de su estado
  de embestida, DESPUES del aviso. Ninguno se salta el aviso. `enemy_ai.gd` marca esos estados como "COMMITTED" y no los interrumpe.
- Los tiradores (`enemy_ranged.gd` y derivados) no tienen `_strike`: solo su proyectil dana (`projectile_enemy.gd`, grupo `enemy_attack`).

Excepciones no por contacto: Ego Inflado explota al morir (`_pop`, radio 120 px, dano `base*0.9` sin aviso, ver abajo); la Espinilla revienta
en gotas; los charcos (`its_puddle`, cera, etc.) y las zonas de jefe (`BossZone`, con `warn`) danan por area, no por cuerpo.

## Tabla por enemigo

"Aviso" = tiempo del WINDUP / AIM / carga antes de poder danar. `!` = aviso menor que 0.3 s (o igual), a revisar.

### Cuerpo a cuerpo (pegan solo al embestir, con aviso)

| Enemigo (script) | Reinos | Cuando pega | Aviso | Nota |
|---|---|---|---|---|
| Melee base: pelo_encarnado, testiculo, ovulo, barra_negra, especulo... (`enemy.gd`) | todos (slot 0 del roster) | solo en LUNGE (0.22 s) | 0.55 s | disparo a 110 px |
| Huincha de Medir (`enemy_huincha.gd`) | casi todos los reinos | solo en LUNGE | 0.42 s; Vulvalquiria 0.4 s; **Ornitorrinco 0.2 s !** | el Ornitorrinco embiste "en panico" al acercarse a 100 px: aviso muy corto |
| Dedo del Urologo (`enemy_dedo.gd`) | perineo, aduana, prostata | LUNGE desde "detras" (propio `_strike`) | 0.5 s | si lo enfrentas de frente no pega y queda aturdido |
| Correa (`enemy_correa.gd`) | palacio, archivo, aduana | LUNGE + gancho a distancia | 0.4 s (gancho 0.55 s) | |
| Esposas (`enemy_esposas.gd`) | palacio, archivo, aduana | LUNGE (y esposa) | 0.5 s | |
| Jaula (`enemy_jaula.gd`) | palacio, archivo | LUNGE | 0.65 s (0.9 s variante) | |
| Shibari (`enemy_shibari.gd`) | palacio, archivo | LUNGE + redes | 0.5 s (red 0.6 s) | |
| Sonda uretral (`enemy_sonda.gd`) | penelandia, conducto | LUNGE largo y rapido (1000 px/s) | 0.7 s con linea de mira | |
| Mito de la Mano / Marcha / Himen (`enemy_mito_*.gd`) | selva, penelandia, vulvania, palacio | LUNGE | 0.5 / 0.45 / 0.55 s | |
| Madrugador (`prostata/enemy_madrugador.gd`) | prostata | LUNGE | 0.5 s | |
| PSA (`prostata/enemy_psa.gd`) | prostata | LUNGE + pulso de balas cada 3 s | 0.55 s (pulso 0.55 s) | no es tirador puro |
| Ego Inflado (`enemy_ego.gd`) | penelandia, conducto, perineo, aduana | LUNGE; al morir `_pop` en radio 120 px | 0.5 s (LUNGE); **el `_pop` no tiene aviso** | dano de `_pop` = `base_damage*0.9` |
| Gran Urologo / Gran Candado (minijefes, `enemy_gran_*.gd`) | perineo, aduana, prostata / palacio, archivo | LUNGE (hereda Dedo / Enemy3a) | 0.6 s / 0.75 s | |
| ITS: clamidia | varios reinos | LUNGE + contagio | **0.3 s !** (en el limite) | ademas es casi invisible de lejos |
| ITS: verruguita | (ITS, varios) | LUNGE | 0.35 s | |
| ITS: sifilis / herpes / gonorrea / vph | varios reinos | LUNGE + contagio | 0.4 / 0.55 (base) / 0.6 / 0.7 s | |
| Tanque `hemorroide` (`enemy_tank.gd`) | perineo, aduana, prostata | solo mientras CARGA (0.8 s) | 1.0 s (se pone amarillo) | |
| Espermatozoide / pelusa_perineal (`enemy_swarmer.gd`) | slot 2 y perineo/aduana | solo en DART (0.32 s) | AIM 0.4 s (brilla) | |

### A distancia (NO pegan por contacto: solo sus balas)

`enemy_ranged.gd` (vesicula, trompa, granito... slot 1), `enemy_taser.gd` (dildo_electrico), `enemy_inspector.gd`, `enemy_mordaza.gd`
(carga 0.75 s), `enemy_venda.gd` (0.8 s), `prostata/enemy_goteo_tardio.gd` (1.1 s). Carga visible 0.6 s por defecto antes de disparar.
**Tiradores que pegan por contacto: ninguno** (el `Hitbox` queda `monitorable=false`, comentado "no pega cuerpo a cuerpo, solo escupe").

### Especiales

| Enemigo | Comportamiento |
|---|---|
| Espinilla Reventona (`enemy_espinilla.gd`) | Inmovil. Nunca pega por contacto. Si te acercas a 105 px (o tras 4.5-7 s) se infla 1.1 s (aviso) y revienta en 10 gotas lentas (130 px/s). Es el "pinchudo" mas claro del plan. |
| Jefes (`enemy_boss.gd` + `bosses/*.gd`) | El cuerpo solo pega en las embestidas (`_strike()` en `enemy_boss.gd:345` y `boss_don_sildenafil.gd`, `boss_testiculo_primordial.gd`). El resto de sus ataques son proyectiles y `BossZone` (circulo/rect con `warn` 0.8 s por defecto). En reposo no hay dano por contacto. |

## Marcas pedidas

- **Tiradores que pegan por contacto:** ninguno.
- **Cuerpo a cuerpo sin aviso:** ninguno (todos pasan por WINDUP/AIM). Pero el `_pop` de Ego Inflado (al matarlo) pega sin aviso.
- **Aviso menor que 0.3 s:** Huincha del Ornitorrinco (0.2 s). En el limite (0.3 s): Clamidia.
- **Pinchudos (queman al tocar):** hoy no existe ninguno; la Espinilla no quema por roce, reventa. Para la regla "solo algunos queman al
  tocar" habria que crearlos (candidatos: espinilla, medusas) y dibujarlos con pinchos.
- **Pendiente respecto al plan J0b:** empujon suave al tocar a un enemigo sin dano (hoy los cuerpos solo colisionan), nota en el codice,
  subir el aviso de la Huincha (Ornitorrinco) y de la Clamidia a >= 0.3-0.4 s, y dar un aviso al `_pop` de Ego (hinchazon visible ya existe;
  falta tiempo de reaccion o dano menor).
