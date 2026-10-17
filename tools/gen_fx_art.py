#!/usr/bin/env python3
"""Arte de efectos de mundo (roadmap tanda 4): huellas y restos en el suelo.
Salen en blanco con alfa: el codigo los tine (color del liquido, rosa de los restos).
Uso: python3 tools/gen_fx_art.py  ->  assets/sprites/fx/
"""
import os, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "fx")
os.makedirs(OUT, exist_ok=True)

W = (255, 255, 255, 255)
SHADE = (205, 205, 205, 255)


def footprint():
    # huella de pie vista desde arriba, apuntando hacia arriba: planta + talon
    im = Image.new("RGBA", (7, 11), (0, 0, 0, 0))
    px = im.load()
    rows = {
        0: (2, 4), 1: (1, 5), 2: (1, 5), 3: (1, 5), 4: (2, 5), 5: (2, 5),
        6: (2, 4), 7: (2, 4), 8: (2, 4), 9: (2, 4), 10: (2, 3),
    }
    for y, (a, b) in rows.items():
        for x in range(a, b + 1):
            px[x, y] = W
    px[3, 0] = (0, 0, 0, 0)  # muesca entre dedos
    for x in range(2, 4):
        px[x, 9] = SHADE
    px[2, 10] = SHADE
    im.save(os.path.join(OUT, "footprint.png"))


def splat(name, w, h, seed, blobs):
    # mancha irregular: nucleo + gotas sueltas alrededor
    rnd = random.Random(seed)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = w / 2.0, h / 2.0
    for _ in range(blobs):
        r = rnd.uniform(2.0, min(w, h) * 0.3)
        x = cx + rnd.uniform(-w * 0.22, w * 0.22)
        y = cy + rnd.uniform(-h * 0.2, h * 0.2)
        d.ellipse((x - r, y - r * 0.75, x + r, y + r * 0.75), fill=W)
    for _ in range(blobs + 2):
        x = rnd.randint(1, w - 2)
        y = rnd.randint(1, h - 2)
        d.point((x, y), fill=W)
        if rnd.random() < 0.5:
            d.point((x + 1, y), fill=W)
    px = im.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] and y > cy + h * 0.12 and rnd.random() < 0.5:
                px[x, y] = SHADE
    im.save(os.path.join(OUT, name))


footprint()
splat("splat_0.png", 20, 14, 1, 4)
splat("splat_1.png", 26, 18, 2, 6)
splat("splat_2.png", 16, 12, 3, 3)
print("ok ->", OUT)
