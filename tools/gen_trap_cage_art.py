#!/usr/bin/env python3
"""Arte de la trampa de jaulas que caen (src/rooms/trap_room.gd, clase _Cage).
Jaula de laton con barrotes, vista de frente: nace con color y el juego la pasa por el shader
de censura (gris hasta liberar la sala, ver src/fx/censor.gd).
Uso: python3 tools/gen_trap_cage_art.py  ->  assets/sprites/environment/trap_cage.png
"""
import math
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "environment")
os.makedirs(OUT, exist_ok=True)

W, H = 56, 64
INK = (35, 30, 44, 255)
BRASS = (214, 172, 78, 255)
LIGHT = (248, 226, 150, 255)
SHADE = (140, 104, 52, 255)
BACK = (96, 74, 46, 255)


def dome_y(x, cx=28.0, rx=24.0, top=6.0, base=50.0):
    """Altura del borde superior de la cupula en x."""
    t = max(-1.0, min(1.0, (x - cx) / rx))
    return base - (base - top) * math.sqrt(1.0 - t * t)


def main():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # sombra de contacto suave
    d.ellipse((2, 52, 54, 63), fill=(0, 0, 0, 70))
    # barrotes traseros (mas oscuros)
    for x in (12, 20, 28, 36, 44):
        d.line((x, dome_y(x) + 2, x, 56), fill=BACK, width=1)
    # aro de la base (trasero) y delantero
    d.arc((4, 46, 52, 62), 180, 360, fill=INK, width=3)
    d.arc((4, 46, 52, 62), 180, 360, fill=SHADE, width=1)
    # barrotes delanteros con borde de tinta
    for x in (6, 13, 20, 28, 36, 43, 50):
        y0 = dome_y(x)
        d.line((x, y0, x, 56), fill=INK, width=3)
    for x in (6, 13, 20, 28, 36, 43, 50):
        y0 = dome_y(x)
        d.line((x, y0, x, 56), fill=BRASS, width=1)
        d.line((x - 1, y0 + 2, x - 1, 54), fill=LIGHT, width=1) if x in (20, 28) else None
    # aros horizontales
    for yy, rx in ((24, 24), (38, 24)):
        pts = []
        for i in range(0, 21):
            a = math.pi * i / 20.0
            pts.append((28 - rx * math.cos(a), yy + 5 * math.sin(a)))
        d.line(pts, fill=INK, width=3)
        d.line(pts, fill=BRASS, width=1)
    # aro delantero de la base
    pts = [(28 - 24 * math.cos(math.pi * i / 20.0), 54 + 6 * math.sin(math.pi * i / 20.0)) for i in range(21)]
    d.line(pts, fill=INK, width=4)
    d.line(pts, fill=BRASS, width=2)
    d.line([(p[0], p[1] - 1) for p in pts[4:9]], fill=LIGHT, width=1)
    # anilla de la cima
    d.ellipse((22, 0, 34, 9), outline=INK, width=2)
    d.ellipse((24, 2, 32, 7), outline=BRASS, width=1)
    d.rectangle((26, 8, 30, 11), fill=INK)
    d.rectangle((27, 8, 29, 11), fill=BRASS)
    im.save(os.path.join(OUT, "trap_cage.png"))


main()
