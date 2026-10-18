# Doña Cera Caliente: tabla ANTES (J0)

Base: rama v2-jefes, commit 120fb75 (sin cambios de jefes). Medido con el bot (`tools/autoplay/correr_jefes.sh`), SIN modo dios,
headless a 60 fps fijos, 3 heroes x semillas 1-3, tiempo de juego. Pelea directa: el salto al piso se salta las mejoras de vida de
los pisos previos, asi que se dan dos variantes: vida base (25 + heroe) y `--hp-bonus=40` (parecido a llegar con 2-3 recompensas).
Arma: pistola basica (pistol_basic) o Bumeran de Silicona (`--loadout=boomerang_silicona`).
Notas: "golpes" cuenta golpes que dan invulnerabilidad; el dano recibido ya viene dividido por la regla de Censura 0 (1/3) y suma
vida + escudo. En todas las peleas donde Cera se curo, el bot corto TODAS las curas (100%). Cera amenaza (estado ATTACK) ~45% del
tiempo y esta agotada ~27%. Con pistola y vida base el heroe pierde siempre (muere con Cera al 70-90%); el golpe maximo con el
bumeran fue 31 (1.6% de los 1900 de vida): con el equipo base no se reproduce "muere de dos golpes".
Reproducir: `tools/autoplay/correr_jefes.sh cera <carpeta> [loadout]` y `python3 tools/autoplay/tabla_jefes.py <carpeta>`.

## Pistola, vida base

| jefe | heroe | semilla | arma | resultado | dur (s) | golpes | dano rec. | vida jefe restante | dps | % ataque | % agotado | curas (cortadas) | golpe max (arma) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cera | ornitorrinco | 1 | pistol_basic | derrota | 62.9 | 11 | 29 | 326/1450 | 17.9 | 44 | 27 | 1 (1) | 12 (pistol_basic) |
| cera | ornitorrinco | 2 | pistol_basic | derrota | 33.0 | 10 | 29 | 822/1450 | 19.0 | 49 | 19 | 1 (1) | 12 (pistol_basic) |
| cera | ornitorrinco | 3 | pistol_basic | derrota | 43.4 | 13 | 29 | 634/1450 | 18.8 | 45 | 25 | 1 (1) | 18 (pistol_basic) |
| cera | pitocles | 1 | pistol_basic | derrota | 41.2 | 17 | 45 | 1116/1900 | 19.0 | 43 | 23 | 1 (1) | 12 (pistol_basic) |
| cera | pitocles | 2 | pistol_basic | derrota | 74.7 | 21 | 57 | 444/1900 | 19.5 | 42 | 31 | 2 (2) | 12 (pistol_basic) |
| cera | pitocles | 3 | pistol_basic | derrota | 62.0 | 23 | 60 | 670/1900 | 19.8 | 44 | 29 | 2 (2) | 12 (pistol_basic) |
| cera | vulvalquiria | 1 | pistol_basic | derrota | 22.0 | 8 | 21 | 1406/1900 | 22.4 | 44 | 28 | 0 (0) | 18 (pistol_basic) |
| cera | vulvalquiria | 2 | pistol_basic | derrota | 15.2 | 8 | 21 | 1570/1900 | 21.8 | 49 | 21 | 0 (0) | 18 (pistol_basic) |
| cera | vulvalquiria | 3 | pistol_basic | derrota | 21.1 | 8 | 21 | 1410/1900 | 23.2 | 45 | 25 | 0 (0) | 18 (pistol_basic) |

Promedios por jefe y arma:

| jefe | arma | peleas | victorias | dur (s) | golpes | dano rec. | dps | % ataque | % agotado | curas | cortadas | golpe max |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cera | pistol_basic | 9 | 0 | 41.7 | 13.2 | 35 | 20.2 | 45 | 25 | 0.9 | 0.9 | 18 |

## Pistola, +40 de vida

| jefe | heroe | semilla | arma | resultado | dur (s) | golpes | dano rec. | vida jefe restante | dps | % ataque | % agotado | curas (cortadas) | golpe max (arma) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cera | ornitorrinco | 1 | pistol_basic | derrota | 77.1 | 28 | 69 | 54/1450 | 18.1 | 45 | 27 | 1 (1) | 18 (pistol_basic) |
| cera | ornitorrinco | 2 | pistol_basic | derrota | 59.8 | 28 | 69 | 238/1450 | 20.3 | 46 | 23 | 1 (1) | 18 (pistol_basic) |
| cera | ornitorrinco | 3 | pistol_basic | derrota | 77.3 | 24 | 69 | 32/1450 | 18.3 | 48 | 26 | 1 (1) | 18 (pistol_basic) |
| cera | pitocles | 1 | pistol_basic | derrota | 80.4 | 30 | 85 | 372/1900 | 19.0 | 45 | 29 | 2 (2) | 12 (pistol_basic) |
| cera | pitocles | 2 | pistol_basic | derrota | 85.9 | 28 | 85 | 374/1900 | 17.8 | 45 | 30 | 2 (2) | 12 (pistol_basic) |
| cera | pitocles | 3 | pistol_basic | derrota | 87.4 | 25 | 100 | 224/1900 | 19.2 | 45 | 26 | 2 (2) | 12 (pistol_basic) |
| cera | vulvalquiria | 1 | pistol_basic | derrota | 63.0 | 21 | 61 | 590/1900 | 20.8 | 43 | 29 | 2 (2) | 18 (pistol_basic) |
| cera | vulvalquiria | 2 | pistol_basic | derrota | 59.5 | 18 | 61 | 702/1900 | 20.1 | 49 | 27 | 2 (2) | 18 (pistol_basic) |
| cera | vulvalquiria | 3 | pistol_basic | derrota | 46.9 | 21 | 61 | 878/1900 | 21.8 | 43 | 27 | 1 (1) | 18 (pistol_basic) |

Promedios por jefe y arma:

| jefe | arma | peleas | victorias | dur (s) | golpes | dano rec. | dps | % ataque | % agotado | curas | cortadas | golpe max |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cera | pistol_basic | 9 | 0 | 70.8 | 24.8 | 73 | 19.5 | 45 | 27 | 1.6 | 1.6 | 18 |

## Bumeran de Silicona, vida base

| jefe | heroe | semilla | arma | resultado | dur (s) | golpes | dano rec. | vida jefe restante | dps | % ataque | % agotado | curas (cortadas) | golpe max (arma) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cera | ornitorrinco | 1 | boomerang_silicona | derrota | 45.9 | 11 | 29 | 372/1450 | 23.5 | 40 | 27 | 1 (1) | 20 (boomerang_silicona) |
| cera | ornitorrinco | 2 | boomerang_silicona | derrota | 41.5 | 11 | 29 | 344/1450 | 26.7 | 45 | 23 | 1 (1) | 20 (boomerang_silicona) |
| cera | ornitorrinco | 3 | boomerang_silicona | derrota | 51.6 | 10 | 29 | 174/1450 | 24.7 | 43 | 28 | 1 (1) | 31 (boomerang_silicona) |
| cera | pitocles | 1 | boomerang_silicona | derrota | 70.3 | 20 | 60 | 163/1900 | 24.7 | 48 | 26 | 2 (2) | 21 (boomerang_silicona) |
| cera | pitocles | 2 | boomerang_silicona | victoria | 77.1 | 12 | 41 | 0/1900 | 24.7 | 47 | 28 | 2 (2) | 21 (boomerang_silicona) |
| cera | pitocles | 3 | boomerang_silicona | derrota | 35.6 | 16 | 45 | 1099/1900 | 22.5 | 44 | 27 | 1 (1) | 21 (boomerang_silicona) |
| cera | vulvalquiria | 1 | boomerang_silicona | derrota | 15.6 | 7 | 21 | 1523/1900 | 24.2 | 44 | 25 | 0 (0) | 20 (boomerang_silicona) |
| cera | vulvalquiria | 2 | boomerang_silicona | derrota | 34.7 | 8 | 21 | 886/1900 | 29.2 | 43 | 27 | 1 (1) | 29 (boomerang_silicona) |
| cera | vulvalquiria | 3 | boomerang_silicona | derrota | 21.5 | 9 | 21 | 1471/1900 | 20.0 | 55 | 16 | 0 (0) | 20 (boomerang_silicona) |

Promedios por jefe y arma:

| jefe | arma | peleas | victorias | dur (s) | golpes | dano rec. | dps | % ataque | % agotado | curas | cortadas | golpe max |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cera | boomerang_silicona | 9 | 1 | 43.8 | 11.6 | 33 | 24.5 | 45 | 25 | 1.0 | 1.0 | 31 |

## Bumeran de Silicona, +40 de vida

| jefe | heroe | semilla | arma | resultado | dur (s) | golpes | dano rec. | vida jefe restante | dps | % ataque | % agotado | curas (cortadas) | golpe max (arma) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cera | ornitorrinco | 1 | boomerang_silicona | victoria | 54.8 | 15 | 46 | 0/1450 | 26.7 | 45 | 29 | 1 (1) | 31 (boomerang_silicona) |
| cera | ornitorrinco | 2 | boomerang_silicona | victoria | 58.7 | 13 | 37 | 0/1450 | 24.8 | 37 | 34 | 1 (1) | 20 (boomerang_silicona) |
| cera | ornitorrinco | 3 | boomerang_silicona | victoria | 59.0 | 20 | 55 | 0/1450 | 24.7 | 49 | 24 | 1 (1) | 31 (boomerang_silicona) |
| cera | pitocles | 1 | boomerang_silicona | victoria | 70.8 | 17 | 55 | 0/1900 | 27.1 | 47 | 28 | 2 (2) | 21 (boomerang_silicona) |
| cera | pitocles | 2 | boomerang_silicona | victoria | 79.1 | 17 | 56 | 0/1900 | 24.2 | 50 | 26 | 2 (2) | 21 (boomerang_silicona) |
| cera | pitocles | 3 | boomerang_silicona | victoria | 74.2 | 27 | 77 | 0/1900 | 25.6 | 44 | 29 | 2 (2) | 21 (boomerang_silicona) |
| cera | vulvalquiria | 1 | boomerang_silicona | derrota | 72.9 | 18 | 61 | 60/1900 | 25.2 | 43 | 31 | 2 (2) | 20 (boomerang_silicona) |
| cera | vulvalquiria | 2 | boomerang_silicona | derrota | 84.3 | 16 | 61 | 57/1900 | 21.9 | 51 | 25 | 2 (2) | 29 (boomerang_silicona) |
| cera | vulvalquiria | 3 | boomerang_silicona | derrota | 69.7 | 15 | 61 | 230/1900 | 24.0 | 42 | 32 | 2 (2) | 29 (boomerang_silicona) |

Promedios por jefe y arma:

| jefe | arma | peleas | victorias | dur (s) | golpes | dano rec. | dps | % ataque | % agotado | curas | cortadas | golpe max |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cera | boomerang_silicona | 9 | 6 | 69.3 | 17.6 | 57 | 24.9 | 45 | 29 | 1.7 | 1.7 | 31 |
