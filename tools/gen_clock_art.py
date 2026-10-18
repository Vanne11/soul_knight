"""Genera el arte del reloj de pie del contrarreloj (assets/sprites/clock/).

Uso: python3 tools/gen_clock_art.py
Piezas (arte a 1x, luz arriba-izquierda, contorno oscuro comun):
  body.png      caja de madera con tejado, esfera (sin agujas), ventana del pendulo y peana (40x64)
  pendulum.png  varilla + dos pelotas doradas (guino); el pivote es el centro de arriba (16x12)
  hand_hour/min/sec.png  agujas, dibujadas "apuntando arriba" desde el centro del giro
  leaf_l/leaf_r.png      puertecitas del cucu
  bird.png      el cucu (un pajarito rosado y presumido)
  glint.png     destello para llamar a tocarlo
Todo es determinista.
"""
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/clock"
OL = (13, 11, 15, 255)
CLEAR = (0, 0, 0, 0)


def C(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


W_HI, W_BASE, W_SH, W_DEEP = C("e0a566"), C("b06f3e"), C("77442a"), C("442717")
B_HI, B_BASE, B_SH = C("fff0a0"), C("e2b13c"), C("9a6f1e")
CREAM, CREAM_SH = C("f6eed2"), C("d6c796")
INK = C("2a1a1a")
RED = C("d8404a")
PINK, PINK_SH = C("ff8fb0"), C("d8587f")


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def rect(img, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, c)


def disc(img, cx, cy, r, c):
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                put(img, x, y, c)


def outline(img):
    """Contorno oscuro de 1 px alrededor de lo opaco (4 vecinos)."""
    src = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < img.width and 0 <= ny < img.height and src.getpixel((nx, ny))[3] > 0:
                        img.putpixel((x, y), OL)
                        break


def body():
    im = Image.new("RGBA", (40, 64), CLEAR)
    # caja
    rect(im, 5, 14, 34, 57, W_BASE)
    rect(im, 5, 14, 6, 57, W_HI)       # luz a la izquierda
    rect(im, 33, 14, 34, 57, W_SH)     # sombra a la derecha
    # tejado a dos aguas
    for y in range(1, 12):
        half = int(round(y * 1.65))
        rect(im, 20 - half, y, 19 + half, y, W_BASE if y > 3 else W_HI)
        put(im, 20 - half, y, W_HI)
        put(im, 19 + half, y, W_SH)
    rect(im, 2, 12, 37, 14, W_HI)      # cornisa
    rect(im, 2, 14, 37, 14, W_SH)
    # apertura del cucu
    rect(im, 16, 5, 23, 11, W_DEEP)
    rect(im, 16, 5, 23, 5, INK)
    # esfera: aro de laton + cara
    cx, cy = 20, 27
    disc(im, cx, cy, 12, B_SH)
    disc(im, cx - 0.5, cy - 0.5, 11.5, B_BASE)
    disc(im, cx, cy, 10, CREAM_SH)
    disc(im, cx - 0.5, cy - 0.5, 9.2, CREAM)
    for i in range(12):
        a = math.radians(i * 30 - 90)
        x, y = round(cx + math.cos(a) * 7.5), round(cy + math.sin(a) * 7.5)
        if i % 3 == 0:
            rect(im, x - 1, y - 1, x, y, INK)
        else:
            put(im, x, y, INK)
    # ventana del pendulo
    rect(im, 9, 42, 30, 55, W_SH)
    rect(im, 10, 43, 29, 54, C("1d120f"))
    rect(im, 10, 43, 29, 43, INK)
    for k in range(5):
        put(im, 12 + k, 53 - k, C("3a2a26"))
        put(im, 15 + k, 53 - k, C("33241f"))
    # peana
    rect(im, 2, 58, 37, 63, W_SH)
    rect(im, 2, 58, 37, 59, W_BASE)
    rect(im, 2, 58, 37, 58, W_HI)
    rect(im, 3, 62, 8, 63, W_DEEP)
    rect(im, 31, 62, 36, 63, W_DEEP)
    outline(im)
    return im


def pendulum():
    im = Image.new("RGBA", (16, 12), CLEAR)
    for y in range(0, 6):
        put(im, 8, y, B_BASE)
    # dos pelotas doradas, juntas (el guino)
    for cxp in (5.5, 10.5):
        disc(im, cxp, 8, 3.3, B_SH)
        disc(im, cxp - 0.5, 7.5, 2.7, B_BASE)
        put(im, int(cxp - 1.5), 6, B_HI)
        put(im, int(cxp - 1.5) + 1, 6, B_HI)
        put(im, int(cxp - 1.5), 7, B_HI)
    outline(im)
    return im


def hand(name, length, kind):
    """Aguja apuntando arriba; el centro de giro queda en (cx, cy) y se imprime."""
    w = 11
    tail = 3
    h = length + tail + 2
    im = Image.new("RGBA", (w, h), CLEAR)
    cx = w // 2
    cy = length + 1
    if kind == "sec":
        for y in range(1, cy + tail):
            put(im, cx, y, RED)
        disc(im, cx, cy + 1, 1.6, RED)
    elif kind == "min":
        for y in range(3, cy + tail - 1):
            put(im, cx, y, INK)
        rect(im, cx - 1, cy - 1, cx + 1, cy + 1, INK)
        disc(im, cx, 2, 1.2, INK)  # puntita redonda
    else:  # hora: punta en forma de corazoncito
        for y in range(5, cy + tail - 1):
            put(im, cx, y, INK)
        put(im, cx - 1, 3, RED)
        put(im, cx + 1, 3, RED)
        rect(im, cx - 1, 4, cx + 1, 4, RED)
        put(im, cx, 5, RED)
        rect(im, cx - 1, cy - 1, cx + 1, cy + 1, INK)
    im.save(OUT / name)
    print(name, im.size, "centro", (cx, cy))


def leaves():
    for name, left in (("leaf_l.png", True), ("leaf_r.png", False)):
        im = Image.new("RGBA", (4, 7), CLEAR)
        rect(im, 0, 0, 3, 6, W_BASE)
        rect(im, 0 if left else 3, 0, 0 if left else 3, 6, W_HI if left else W_SH)
        rect(im, 0, 0, 3, 0, W_HI)
        put(im, 2 if left else 1, 3, B_BASE)  # pomo
        im.save(OUT / name)


def bird():
    im = Image.new("RGBA", (10, 9), CLEAR)
    disc(im, 4.5, 5.5, 3.4, PINK_SH)
    disc(im, 4, 5, 2.9, PINK)
    rect(im, 3, 1, 5, 2, PINK)
    put(im, 6, 2, B_BASE)
    put(im, 7, 2, B_BASE)
    put(im, 4, 2, OL)
    put(im, 2, 0, RED)
    put(im, 3, 0, RED)
    rect(im, 1, 6, 2, 7, PINK_SH)
    outline(im)
    im.save(OUT / "bird.png")


def glint():
    im = Image.new("RGBA", (7, 7), CLEAR)
    for k in range(7):
        c = (255, 250, 225, 255) if 1 <= k <= 5 else (255, 240, 180, 255)
        put(im, 3, k, c)
        put(im, k, 3, c)
    for (x, y) in ((2, 2), (4, 2), (2, 4), (4, 4)):
        put(im, x, y, (255, 245, 200, 255))
    put(im, 3, 3, (255, 255, 255, 255))
    im.save(OUT / "glint.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    body().save(OUT / "body.png")
    pendulum().save(OUT / "pendulum.png")
    hand("hand_hour.png", 6, "hour")
    hand("hand_min.png", 8, "min")
    hand("hand_sec.png", 9, "sec")
    leaves()
    bird()
    glint()
    print("listo ->", OUT)
