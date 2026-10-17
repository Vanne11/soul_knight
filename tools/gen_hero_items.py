#!/usr/bin/env python3
"""Iconos (24x24) de los objetos iniciales de los heroes, dibujados por codigo.

Uso: python3 tools/gen_hero_items.py
Escribe assets/sprites/items/{casco_pulido,trenza_combate,huevo_suerte}.png.
Los objetos en si estan en assets/data/items/*.tres (tag "especial": no salen de botin).
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/items"


def c(s):
    return (int(s[1:3], 16), int(s[3:5], 16), int(s[5:7], 16), 255)


K = c("#0d0b0f")


def px(im, pts, col):
    for x, y in pts:
        if 0 <= x < 24 and 0 <= y < 24:
            im.putpixel((x, y), col)


def outline(im):
    src = im.copy()
    for y in range(24):
        for x in range(24):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < 24 and 0 <= ny < 24 and src.getpixel((nx, ny))[3] > 0:
                        im.putpixel((x, y), K)
                        break


def casco():
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    gold, goldl, goldd, red, redl = c("#ffc93c"), c("#fff1b0"), c("#a48132"), c("#ff4848"), c("#fb7570")
    # cresta
    for x in range(7, 17):
        px(im, [(x, 4)], red)
    for x in range(6, 18):
        px(im, [(x, 5), (x, 6)], red if x % 2 else redl)
    # calota
    for y in range(7, 17):
        w = 8 if y > 9 else 6 + (y - 7)
        for x in range(12 - w, 12 + w):
            px(im, [(x, y)], gold)
    for y in range(7, 12):
        px(im, [(8, y), (9, y)], goldl)
    # carrilleras y visera en T
    for y in range(14, 21):
        px(im, [(5, y), (6, y), (17, y), (18, y)], goldd)
    for y in range(11, 19):
        px(im, [(11, y), (12, y)], goldd)
    for x in range(7, 17):
        px(im, [(x, 12)], goldd)
    # destello
    px(im, [(16, 8), (15, 9), (17, 9), (16, 10), (14, 8), (18, 8)], (255, 255, 255, 255))
    outline(im)
    return im


def trenza():
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    g, gd, blue = c("#fbd267"), c("#d9a94a"), c("#93d0f4")
    for i, y in enumerate(range(3, 19)):
        sway = 1 if (i // 3) % 2 else 0
        a, b = (g, gd) if i % 2 == 0 else (gd, g)
        px(im, [(10 + sway, y), (11 + sway, y), (12 + sway, y), (13 + sway, y)], a)
        px(im, [(11 + sway, y), (12 + sway, y)], b)
    for x in range(9, 15):
        px(im, [(x, 19), (x, 20)], blue)
    px(im, [(10, 21), (13, 21), (9, 22), (14, 22)], g)
    px(im, [(10, 4), (11, 4)], (255, 255, 255, 255))
    outline(im)
    return im


def huevo():
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    cream, shade, spot, spotd = c("#eed6a1"), c("#d9bd85"), c("#86aea1"), c("#5c968c")
    for y in range(3, 21):
        t = (y - 3) / 17
        w = [3.0, 4.5, 5.6, 6.3, 6.7, 6.9, 7.0, 7.0, 7.0, 6.9, 6.8, 6.6, 6.2, 5.7, 5.1, 4.3, 3.2, 2.0][y - 3]
        for x in range(int(12 - w), int(12 + w)):
            px(im, [(x, y)], cream if x < 14 + (y % 2) else shade)
    for (x, y) in ((9, 8), (10, 8), (9, 9), (14, 12), (15, 12), (14, 13), (11, 16), (12, 16)):
        px(im, [(x, y)], spot)
    for (x, y) in ((10, 9), (15, 13), (12, 17)):
        px(im, [(x, y)], spotd)
    px(im, [(8, 6), (8, 7), (9, 5)], (255, 255, 255, 255))
    outline(im)
    return im


if __name__ == "__main__":
    for name, fn in (("casco_pulido", casco), ("trenza_combate", trenza), ("huevo_suerte", huevo)):
        fn().save(OUT / f"{name}.png")
    print("ok")
