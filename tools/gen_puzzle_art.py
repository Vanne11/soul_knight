"""Genera el arte de los acertijos (assets/sprites/environment/puzzles/) y la llave del cinturon.

Uso: python3 tools/gen_puzzle_art.py

Arte pixel a 1x. Luz arriba-izquierda, contorno oscuro comun (como gen_obstacle_art.py).
Por reino (neutral, pene, vulva, mixto, censura):
  plate_<k>_up / plate_<k>_down   placa de 40x40: sobresale / hundida (se hunde al pisarla)
Comunes:
  mushroom_0..3     setas de la Selva (rojo, azul, amarillo, verde)
  statue            idolo de piedra de Penelandia (se empuja)
  flower_closed / flower_open   flores de Vulvania
  stamp_0..3        glifos de los sellos del Perineo (circulo, triangulo, cuadrado, estrella)
  paper             hoja del tramite
  censor_mosaic     mosaico de censura (Palacio): se levanta al pisar la placa
  lamp, mirror_a / mirror_b, sensor_off / sensor_on   luz y espejos
  padlock_<clase>, belt_lock, altar_blood   candados de los cofres y altar de sangre
Ademas: assets/sprites/items/key_belt.png (llave del cinturon de castidad).
Todo es determinista.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/environment/puzzles"
ITEMS = ROOT / "assets/sprites/items"
CLEAR = (0, 0, 0, 0)
OL = (13, 11, 15, 255)
WHITE = (255, 255, 255, 255)


def C(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def dk(c, k):
    return tuple(max(0, min(255, int(c[i] * k))) for i in range(3)) + (255,)


def new(w, h):
    return Image.new("RGBA", (w, h), CLEAR)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(im, x, y, c)


def disc(im, cx, cy, r, c):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                px(im, x, y, c)


def line(im, x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        px(im, round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


def outline(im):
    out = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if im.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < im.width and 0 <= ny < im.height and im.getpixel((nx, ny))[3] and im.getpixel((nx, ny)) != OL:
                    out.putpixel((x, y), OL)
                    break
    return out


def padded(im, pad=1):
    out = new(im.width + pad * 2, im.height + pad * 2)
    out.paste(im, (pad, pad))
    return out


def save(im, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path)


# ------------------------------------------------------------------ placas
PLATE_COL = {
    "neutral": ("6f8a55", "8fb36c", "c8e08a"),   # piedra con musgo
    "pene": ("5b7fa6", "7fa6d0", "bfe0ff"),      # piedra azulada con runa
    "vulva": ("b0587c", "d9809f", "ffc2d6"),     # piedra rosada, petalo
    "mixto": ("8a7c66", "b3a58a", "e6d9b8"),     # baldosa de oficina con marco de latón
    "censura": ("2b2b30", "45454d", "8a8a96"),   # negro con mosaico gris
}


def plate(kind, down):
    base, hi, glint = (C(c) for c in PLATE_COL[kind])
    im = new(40, 40)
    rng = random.Random(sum(map(ord, kind)))
    if not down:
        # losa levantada: cara arriba (36x30) y canto (6 px) abajo
        rect(im, 2, 2, 37, 31, base)
        rect(im, 2, 32, 37, 37, dk(base, 0.55))
        rect(im, 2, 2, 37, 3, hi)
        rect(im, 2, 2, 3, 31, hi)
        rect(im, 36, 4, 37, 31, dk(base, 0.8))
        rect(im, 4, 30, 35, 31, dk(base, 0.8))
        face = (4, 4, 35, 29)
    else:
        # hundida: marco, hueco oscuro y la cara 3 px mas abajo
        rect(im, 2, 2, 37, 37, dk(base, 0.5))
        rect(im, 3, 3, 36, 36, dk(base, 0.38))
        rect(im, 4, 7, 35, 33, dk(base, 0.9))
        rect(im, 4, 7, 35, 8, dk(base, 0.7))
        rect(im, 4, 7, 5, 33, dk(base, 0.7))
        face = (5, 9, 34, 33)
    x0, y0, x1, y1 = face
    # textura
    for _ in range(26):
        x = rng.randint(x0, x1)
        y = rng.randint(y0, y1)
        px(im, x, y, dk(base, rng.choice((0.85, 1.12))))
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    if kind == "neutral":
        for (x, y) in ((x0 + 2, y0 + 1), (x0 + 3, y0 + 2), (x1 - 4, y1 - 2), (x1 - 3, y1 - 3), (x0 + 1, y1 - 3)):
            disc(im, x, y, 1.6, C("4f7a3a"))
        line(im, cx - 6, cy + 4, cx, cy - 5, glint)
        line(im, cx, cy - 5, cx + 6, cy + 4, glint)
    elif kind == "pene":
        for r in (9, 6):
            for a in range(0, 360, 6):
                px(im, round(cx + math.cos(math.radians(a)) * r), round(cy + math.sin(math.radians(a)) * r * 0.85), glint if r == 9 else dk(glint, 0.8))
    elif kind == "vulva":
        for k in range(5):
            a = math.radians(-90 + k * 72)
            disc(im, cx + math.cos(a) * 6, cy + math.sin(a) * 6, 3.2, mix(base, glint, 0.5))
        disc(im, cx, cy, 2.4, C("ffe08a"))
    elif kind == "mixto":
        rect(im, x0, y0, x1, y0 + 1, C("b8924a"))
        rect(im, x0, y1 - 1, x1, y1, C("b8924a"))
        rect(im, x0, y0, x0 + 1, y1, C("b8924a"))
        rect(im, x1 - 1, y0, x1, y1, C("b8924a"))
        for (x, y) in ((x0 + 3, y0 + 3), (x1 - 3, y0 + 3), (x0 + 3, y1 - 3), (x1 - 3, y1 - 3)):
            px(im, x, y, C("f1d98a"))
    else:  # censura: mosaico de pixeles grandes
        for yy in range(y0, y1 + 1, 4):
            for xx in range(x0, x1 + 1, 4):
                k = rng.choice((0.7, 0.9, 1.1, 1.3))
                rect(im, xx, yy, min(x1, xx + 2), min(y1, yy + 2), dk(hi, k * 0.8))
    return outline(padded(im))


# ------------------------------------------------------------------ glifos
def mushroom(i):
    caps = ["e0525a", "5aa0e0", "e0c95a", "6ad07a"]
    cap = C(caps[i])
    im = new(28, 28)
    # tallo
    rect(im, 11, 15, 16, 24, C("efe6cf"))
    rect(im, 15, 15, 16, 24, C("c9bd9d"))
    # sombrero
    for y in range(4, 17):
        w = round(12 * math.sqrt(max(0.0, 1 - ((y - 16) / 12.0) ** 2)))
        for x in range(14 - w, 14 + w):
            px(im, x, y, cap if y > 7 else mix(cap, WHITE, 0.25))
    for (x, y) in ((8, 11), (14, 8), (19, 12), (12, 13)):
        disc(im, x, y, 1.6, C("fff4e0"))
    rect(im, 3, 15, 24, 16, dk(cap, 0.7))
    return outline(padded(im))


def statue():
    im = new(32, 44)
    st, stl, std = C("a9a5b0"), C("cfcbd6"), C("77737f")
    rect(im, 4, 34, 27, 40, std)          # base
    rect(im, 4, 34, 27, 35, stl)
    rect(im, 8, 14, 23, 34, st)           # cuerpo
    rect(im, 8, 14, 10, 34, stl)
    rect(im, 21, 14, 23, 34, std)
    for y in range(3, 15):                # cabeza redondeada
        w = round(8 * math.sqrt(max(0.0, 1 - ((y - 14) / 11.0) ** 2)))
        for x in range(16 - w, 16 + w):
            px(im, x, y, stl if x < 14 else st)
    rect(im, 11, 8, 13, 9, OL)            # ojos
    rect(im, 18, 8, 20, 9, OL)
    line(im, 12, 12, 19, 12, OL)          # sonrisa
    px(im, 11, 11, OL)
    px(im, 20, 11, OL)
    for (x, y) in ((10, 20), (20, 26), (13, 30)):
        px(im, x, y, std)
    return outline(padded(im))


def flower(open_):
    im = new(28, 28)
    pink, deep = C("ff7ac0"), C("c04a8a")
    rect(im, 13, 14, 14, 25, C("4f8a3a"))
    rect(im, 8, 19, 12, 20, C("4f8a3a"))
    if open_:
        for k in range(8):
            a = math.radians(k * 45)
            disc(im, 14 + math.cos(a) * 7, 10 + math.sin(a) * 7, 3.6, pink if k % 2 else mix(pink, WHITE, 0.3))
        disc(im, 14, 10, 4, C("ffe08a"))
        disc(im, 13, 9, 1.4, C("fff4c0"))
    else:
        for y in range(3, 15):
            w = round(5 * math.sqrt(max(0.0, 1 - ((y - 14) / 12.0) ** 2)))
            for x in range(14 - w, 14 + w + 1):
                px(im, x, y, deep if x > 14 else dk(pink, 0.8))
        line(im, 14, 4, 14, 14, dk(deep, 0.7))
        rect(im, 10, 13, 18, 14, C("4f8a3a"))
    return outline(padded(im))


def stamp(i):
    im = new(24, 24)
    ink = C("2a2f5a")
    if i == 0:
        disc(im, 12, 12, 8, ink)
        disc(im, 12, 12, 4, C("e9e2cc"))
    elif i == 1:
        for y in range(4, 20):
            w = (y - 4) * 0.62
            rect(im, round(12 - w), y, round(12 + w), y, ink)
    elif i == 2:
        rect(im, 4, 4, 19, 19, ink)
        rect(im, 8, 8, 15, 15, C("e9e2cc"))
    else:
        for k in range(10):
            a = math.radians(-90 + k * 36)
            r = 10 if k % 2 == 0 else 4.3
            line(im, 12, 12, round(12 + math.cos(a) * r), round(12 + math.sin(a) * r), ink)
        disc(im, 12, 12, 4, ink)
    return im


def paper():
    im = new(34, 44)
    rect(im, 2, 2, 31, 41, C("e9e2cc"))
    rect(im, 2, 2, 31, 3, C("fffbe9"))
    rect(im, 29, 4, 31, 41, C("c9bd9d"))
    for y in (32, 35, 38):
        rect(im, 6, y, 25, y, C("a39a82"))
    return outline(padded(im))


def censor_mosaic():
    im = new(40, 40)
    rng = random.Random(7)
    for yy in range(2, 38, 5):
        for xx in range(2, 38, 5):
            v = rng.choice((0.9, 1.1, 1.3, 0.7))
            rect(im, xx, yy, xx + 3, yy + 3, dk(C("8a8a96"), v))
    return im


# ------------------------------------------------------------------ luz y espejos
def lamp():
    im = new(24, 40)
    rect(im, 10, 18, 13, 38, C("6b4a2c"))
    rect(im, 10, 18, 11, 38, C("8d6a42"))
    rect(im, 6, 14, 17, 19, C("3a3a42"))
    for y in range(3, 15):
        w = round(6 * math.sqrt(max(0.0, 1 - ((y - 14) / 12.0) ** 2)))
        for x in range(12 - w, 12 + w):
            px(im, x, y, C("ffb43a") if y > 7 else C("ffe27a"))
    rect(im, 11, 8, 12, 12, C("fff6c8"))
    return outline(padded(im))


def mirror(variant):
    im = new(36, 36)
    rect(im, 12, 28, 23, 32, C("6e6a78"))
    rect(im, 12, 28, 23, 29, C("a6a2b2"))
    # marco rotado 45 grados: '/' = a, '\' = b
    pts = [(8, 27), (27, 8)] if variant == 0 else [(8, 8), (27, 27)]
    for t in (-2, -1, 0, 1, 2):
        line(im, pts[0][0] + t, pts[0][1], pts[1][0] + t, pts[1][1], C("c9a24a") if abs(t) == 2 else C("bfe8ff"))
    line(im, pts[0][0], pts[0][1], pts[1][0], pts[1][1], WHITE)
    return outline(padded(im))


def sensor(on):
    im = new(28, 32)
    rect(im, 8, 24, 19, 28, C("5a5664"))
    rect(im, 8, 24, 19, 25, C("8a86a0"))
    col = C("fff08a") if on else C("5a6a8a")
    hi = WHITE if on else C("8aa0c8")
    for y in range(4, 24):
        w = 8 - abs(y - 12) * 0.55
        w = max(2, round(w))
        rect(im, 14 - w, y, 14 + w - 1, y, col)
    rect(im, 11, 8, 12, 14, hi)
    return outline(padded(im))


# ------------------------------------------------------------------ candados y altar
def padlock(kind):
    cols = {"crystal": "9be8ff", "drunk": "e0a93a", "blood": "c0283a", "master": "ffd75a", "belt": "8a8a96"}
    c = C(cols[kind])
    im = new(16, 18)
    rect(im, 3, 8, 12, 15, c)
    rect(im, 3, 8, 12, 9, mix(c, WHITE, 0.4))
    rect(im, 3, 14, 12, 15, dk(c, 0.6))
    for y in range(1, 9):
        for x in (4, 5, 10, 11):
            px(im, x, y, C("c9c9d6"))
    rect(im, 4, 1, 11, 2, C("c9c9d6"))
    rect(im, 7, 10, 8, 12, OL)
    return outline(padded(im))


def belt_lock():
    im = new(40, 20)
    st, hi = C("6a6a78"), C("b3b3c4")
    for x in range(0, 40, 4):  # cadena
        rect(im, x, 6, x + 2, 8, st)
        px(im, x, 6, hi)
    rect(im, 14, 3, 25, 16, C("8a8a96"))
    rect(im, 14, 3, 25, 4, hi)
    rect(im, 14, 15, 25, 16, C("45454d"))
    rect(im, 18, 7, 21, 8, C("e0c060"))
    rect(im, 19, 9, 20, 12, OL)
    return outline(padded(im))


def altar_blood():
    im = new(40, 40)
    st, stl, std = C("5a2a3a"), C("8a4a5c"), C("33141f")
    rect(im, 6, 28, 33, 36, std)
    rect(im, 8, 14, 31, 30, st)
    rect(im, 8, 14, 31, 16, stl)
    rect(im, 5, 10, 34, 15, stl)
    rect(im, 5, 14, 34, 15, std)
    for y in range(10, 14):  # cuenco con sangre
        rect(im, 12, y, 27, y, C("a01a2a") if y > 10 else C("d83a4a"))
    rect(im, 24, 15, 25, 24, C("a01a2a"))
    return outline(padded(im))


def key_belt():
    im = new(24, 24)
    g, gh, gd = C("b3b3c4"), C("e6e6f2"), C("6a6a78")
    disc(im, 8, 8, 5, g)
    disc(im, 8, 8, 2, CLEAR)
    rect(im, 11, 10, 21, 12, g)
    rect(im, 11, 10, 21, 10, gh)
    rect(im, 18, 13, 19, 17, g)
    rect(im, 21, 13, 21, 15, g)
    rect(im, 3, 4, 6, 4, gh)
    line(im, 5, 14, 10, 19, gd)
    return outline(padded(im, 0))


def main():
    for k in PLATE_COL:
        save(plate(k, False), OUT / f"plate_{k}_up.png")
        save(plate(k, True), OUT / f"plate_{k}_down.png")
    for i in range(4):
        save(mushroom(i), OUT / f"mushroom_{i}.png")
        save(stamp(i), OUT / f"stamp_{i}.png")
    save(statue(), OUT / "statue.png")
    save(flower(False), OUT / "flower_closed.png")
    save(flower(True), OUT / "flower_open.png")
    save(paper(), OUT / "paper.png")
    save(censor_mosaic(), OUT / "censor_mosaic.png")
    save(lamp(), OUT / "lamp.png")
    save(mirror(0), OUT / "mirror_a.png")
    save(mirror(1), OUT / "mirror_b.png")
    save(sensor(False), OUT / "sensor_off.png")
    save(sensor(True), OUT / "sensor_on.png")
    for kind in ("crystal", "drunk", "blood", "master", "belt"):
        save(padlock(kind), OUT / f"padlock_{kind}.png")
    save(belt_lock(), OUT / "belt_lock.png")
    save(altar_blood(), OUT / "altar_blood.png")
    save(key_belt(), ITEMS / "key_belt.png")
    print("listo")


if __name__ == "__main__":
    main()
