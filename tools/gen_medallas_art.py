#!/usr/bin/env python3
"""Dibuja los iconos de las medallas (pixel art por codigo, sin IA).

Salida: assets/sprites/ui/medallas/<nivel>_<glifo>.png (32x32) para los niveles
sonrojo (rosado), destape (plateado) y sin_pudor (dorado) con cada glifo de categoria,
y platino_final.png (Desnudo Integral: cristal con destellos).
Uso: python3 tools/gen_medallas_art.py
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets/sprites/ui/medallas"
S = 32

NIVELES = {
    # cara, borde, brillo, cinta, cinta oscura
    "sonrojo": ("#f48fa6", "#b24a68", "#ffd0dc", "#d8607f", "#9a3552"),
    "destape": ("#d3dae6", "#7a8598", "#ffffff", "#8f9fc0", "#5a6684"),
    "sin_pudor": ("#f6c945", "#b07c1f", "#fff1a8", "#d24a4a", "#8e2c34"),
}
INK = "#2a1a2e"

GLIFOS = {
    "jefe": [
        ".XXXXXXX.",
        "XXXXXXXXX",
        "XX..X..XX",
        "XX..X..XX",
        "XXXXXXXXX",
        ".XXX.XXX.",
        "..XXXXX..",
        "..X.X.X..",
        "..XXXXX..",
    ],
    "reino": [
        "X........",
        "XXXXXX...",
        "XXXXXXXX.",
        "XXXXXXXXX",
        "XXXXXXXX.",
        "XXXXXX...",
        "X........",
        "X........",
        "X........",
    ],
    "heroe": [
        "...XXX...",
        "..XXXXX..",
        ".XXXXXXX.",
        "XXXXXXXXX",
        "XXXXXXXXX",
        "XXX...XXX",
        "XXX...XXX",
        "XX.....XX",
        "X.......X",
    ],
    "codice": [
        ".XXXXXXX.",
        "XX.....XX",
        "XX.XXX.XX",
        "XX.....XX",
        "XX.XXX.XX",
        "XX.....XX",
        "XX.XX..XX",
        "XX.....XX",
        ".XXXXXXX.",
    ],
    "acertijo": [
        "..XXXXX..",
        ".XX...XX.",
        ".XX...XX.",
        ".....XX..",
        "....XX...",
        "...XX....",
        "...XX....",
        ".........",
        "...XX....",
    ],
    "pacto": [
        "XXXXXXXX.",
        "X......X.",
        "X.XXXX.X.",
        "X......X.",
        "X.XXX..X.",
        "X......X.",
        "X.XXXX.XX",
        "X......XX",
        "XXXXXXXXX",
    ],
    "dia": [
        "....X....",
        ".X..X..X.",
        "..XXXXX..",
        "..XXXXX.X",
        "XXXXXXXXX",
        "..XXXXX..",
        "..XXXXX..",
        ".X..X..X.",
        "....X....",
    ],
    "secreta": [
        "....X....",
        "....X....",
        "...XXX...",
        "XXXXXXXXX",
        ".XXXXXXX.",
        "..XXXXX..",
        "..XXXXX..",
        ".XXX.XXX.",
        ".XX...XX.",
    ],
    "humor": [
        ".XXXXXXX.",
        "XX.....XX",
        "X.XX.XX.X",
        "X.XX.XX.X",
        "X.......X",
        "X.X...X.X",
        "XX.XXX.XX",
        ".XX...XX.",
        "..XXXXX..",
    ],
    "final": [
        "....X....",
        "...XXX...",
        "..XXXXX..",
        ".XXXXXXX.",
        "XXXXXXXXX",
        ".XXXXXXX.",
        "..XXXXX..",
        "...XXX...",
        "....X....",
    ],
}


def put(img, x, y, c):
    if 0 <= x < S and 0 <= y < S:
        img.putpixel((x, y), c)


def rgba(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def disco(img, cx, cy, r, cara, borde, brillo):
    for y in range(S):
        for x in range(S):
            d2 = (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2
            if d2 <= r * r:
                put(img, x, y, rgba(borde) if d2 > (r - 1.6) ** 2 else rgba(cara))
    # brillo arriba a la izquierda
    for (dx, dy) in [(-6, -6), (-5, -7), (-4, -7), (-7, -5), (-7, -4)]:
        put(img, int(cx + dx), int(cy + dy), rgba(brillo))
    put(img, int(cx - 5), int(cy - 6), rgba(brillo))


def cinta(img, c1, c2):
    # dos colas que cuelgan bajo el disco
    for (x0, lado) in [(9, 1), (17, 1)]:
        for i in range(8):
            y = 22 + i
            for x in range(x0, x0 + 6):
                put(img, x, y, rgba(c1 if (x - x0) < 5 else c2))
        # muesca en V al final
        put(img, x0 + 2, 29, (0, 0, 0, 0))
        put(img, x0 + 3, 29, (0, 0, 0, 0))
        put(img, x0 + 2, 28, (0, 0, 0, 0)) if False else None


def glifo(img, nombre, cx, cy, color):
    g = GLIFOS[nombre]
    ox, oy = cx - 4, cy - 4
    for j, fila in enumerate(g):
        for i, ch in enumerate(fila):
            if ch == "X":
                put(img, ox + i, oy + j, rgba(color))


def medalla(nivel, nombre):
    cara, borde, brillo, c1, c2 = NIVELES[nivel]
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cinta(img, c1, c2)
    disco(img, 16, 15, 13, cara, borde, brillo)
    # anillo interior
    for y in range(S):
        for x in range(S):
            d2 = (x + 0.5 - 16) ** 2 + (y + 0.5 - 15) ** 2
            if (9.2 ** 2) < d2 <= (10.2 ** 2):
                put(img, x, y, rgba(borde, 140))
    glifo(img, nombre, 16, 15, INK)
    return img


def platino():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    cinta(img, "#7fd8ff", "#3a8fc9")
    cara, borde, brillo = "#eafcff", "#4aa7d6", "#ffffff"
    disco(img, 16, 15, 14, cara, borde, brillo)
    # facetas de cristal
    for y in range(S):
        for x in range(S):
            d2 = (x + 0.5 - 16) ** 2 + (y + 0.5 - 15) ** 2
            if d2 <= 11.5 ** 2 and ((x + y) // 5) % 2 == 0:
                put(img, x, y, rgba("#c6efff"))
    glifo(img, "final", 16, 15, "#d6338a")
    for (x, y) in [(3, 4), (28, 6), (26, 25), (5, 24)]:
        for dx, dy in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]:
            put(img, x + dx, y + dy, rgba("#ffffff"))
    return img


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for nivel in NIVELES:
        for nombre in GLIFOS:
            if nombre == "final":
                continue
            medalla(nivel, nombre).save(OUT / f"{nivel}_{nombre}.png")
    platino().save(OUT / "platino_final.png")
    # hoja de prueba (no se versiona)
    print("iconos en", OUT)


if __name__ == "__main__":
    main()
