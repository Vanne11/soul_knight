"""Genera el arte de obstaculos por reino (assets/sprites/environment/obstacles/<reino>/).

Uso: python3 tools/gen_obstacle_art.py [reino ...]   (sin args = los cinco)
Reinos: neutral (Selva), pene (Penelandia), vulva (Vulvania), mixto (Perineo), censura (Palacio).

Arte pixel a 1x (1 px de arte = 1 px de mundo). Luz arriba-izquierda, contorno oscuro comun.
Piezas por reino:
  rock_a / rock_b   roca grande y chica (bloquean y cubren de las balas)
  column            columna de cobertura (alta, base estrecha)
  extra             pieza ancha y baja: tronco, columna caida, lomo rosado, barrera de aduana, bloque
  barrel / crate    rompibles (anfora, tambor, caja de contrabando, caja de archivo...)
  barrel_broken / crate_broken   restos que quedan en el suelo al romperse
  chunk             tira de 4 trozos de 6x6 para las particulas
  spikes / spikes_s pinchos de las salas trampa (solo decoracion)
Comunes (sin reino): skull.png, bones.png (huesos para las salas trampa).
Todo es determinista (semillas fijas).
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/environment/obstacles"
CLEAR = (0, 0, 0, 0)
OL = (13, 11, 15, 255)
WHITE = (255, 255, 255, 255)


def C(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def dk(c, k):
    return (max(0, min(255, int(c[0] * k))), max(0, min(255, int(c[1] * k))), max(0, min(255, int(c[2] * k))), 255)


class Pal:
    """Cuatro tonos de un color: claro, base, sombra, sombra profunda."""

    def __init__(self, base):
        b = C(base) if isinstance(base, str) else base
        self.base = b
        self.hi = mix(b, WHITE, 0.38)
        self.lo = dk(b, 0.76)
        self.deep = dk(b, 0.55)


def new(w, h):
    return Image.new("RGBA", (w, h), CLEAR)


def mask_of(w, h, fn):
    m = Image.new("L", (w, h), 0)
    fn(ImageDraw.Draw(m))
    return m


def union(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = ImageChops.lighter(out, m)
    return out


def inside(m, x, y):
    return 0 <= x < m.width and 0 <= y < m.height and m.getpixel((x, y)) > 0


def shade(m, pal, light_k=1.0):
    """Rellena la mascara con luz arriba-izquierda: borde claro, borde oscuro y degradado vertical."""
    im = new(m.width, m.height)
    for y in range(m.height):
        for x in range(m.width):
            if not inside(m, x, y):
                continue
            hi1 = not (inside(m, x - 1, y) and inside(m, x, y - 1) and inside(m, x - 1, y - 1))
            lo1 = not (inside(m, x + 1, y) and inside(m, x, y + 1) and inside(m, x + 1, y + 1))
            lo2 = not (inside(m, x + 2, y) and inside(m, x, y + 2) and inside(m, x + 2, y + 2))
            if lo1:
                c = pal.deep
            elif hi1:
                c = pal.hi
            elif lo2:
                c = pal.lo
            else:
                t = y / max(1, m.height - 1)
                c = mix(pal.hi, pal.base, 0.55 + 0.45 * min(1.0, t * 1.6)) if t < 0.35 else pal.base
            im.putpixel((x, y), c)
    return im


def outline(im, pad_ok=True):
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


def paste_clip(im, m, layer):
    """Pega layer en im solo donde la mascara m es > 0 y layer tiene alfa."""
    for y in range(im.height):
        for x in range(im.width):
            p = layer.getpixel((x, y))
            if p[3] and inside(m, x, y):
                im.putpixel((x, y), p)


def draw_on(im, m, fn):
    layer = new(im.width, im.height)
    fn(ImageDraw.Draw(layer), layer)
    paste_clip(im, m, layer)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def line(im, x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        px(im, round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


def canvas(w, h, pad=1):
    """Lienzo con margen para el contorno: devuelve (ancho, alto) interior desplazado en pad."""
    return w + pad * 2, h + pad * 2


# ------------------------------------------------------------------ paletas por reino
KINGS = {
    "neutral": dict(stone=Pal("#8d8878"), moss=Pal("#5f8f3a"), wood=Pal("#8a5a30"), wood2=Pal("#a8743c"),
                    metal=Pal("#5b5a52"), trim=Pal("#6a8f3c"), plate=Pal("#6b6355")),
    "pene": dict(stone=Pal("#e6e1d3"), moss=Pal("#c9a24a"), wood=Pal("#c4673a"), wood2=Pal("#e8b87a"),
                 metal=Pal("#8b8fa8"), trim=Pal("#d9b34a"), plate=Pal("#b9b8c0")),
    "vulva": dict(stone=Pal("#e8869f"), moss=Pal("#f6b0c4"), wood=Pal("#c4547a"), wood2=Pal("#f19ab5"),
                  metal=Pal("#a8456a"), trim=Pal("#fbd0dc"), plate=Pal("#c06a88")),
    "mixto": dict(stone=Pal("#8d93a2"), moss=Pal("#e5b800"), wood=Pal("#9a6b3a"), wood2=Pal("#b88650"),
                  metal=Pal("#6b7280"), trim=Pal("#e5b800"), plate=Pal("#707788")),
    "censura": dict(stone=Pal("#f2f2f6"), moss=Pal("#14121a"), wood=Pal("#e4e4ec"), wood2=Pal("#fafafc"),
                    metal=Pal("#c5c5d2"), trim=Pal("#8a1a2a"), plate=Pal("#d8d8e2")),
}
# La Prostata: se dibuja con las formas del Perineo ("mixto": sillas-bloque, cajas, barreras)
# pero con paleta de sala de espera (nuez, rosa lechoso, gris).
KINGS["prostata"] = dict(stone=Pal("#b4a8a6"), moss=Pal("#8e6c50"), wood=Pal("#8a6a50"), wood2=Pal("#b08a68"),
                         metal=Pal("#7c7476"), trim=Pal("#d6bcb8"), plate=Pal("#a49a9a"))
SHAPE_AS = {"prostata": "mixto"}
BAR = C("#14121a")
BARHI = C("#2c2a36")
RED = C("#8a1a2a")


def blob_mask(w, h, rng, jitter=0.18, n=10, flat_bottom=True):
    pts = []
    cx, cy = w / 2.0, h / 2.0
    for i in range(n):
        a = i * math.tau / n + rng.uniform(-0.15, 0.15)
        rx = (w / 2.0 - 1.5) * (1 - rng.uniform(0, jitter))
        ry = (h / 2.0 - 1.5) * (1 - rng.uniform(0, jitter))
        x, y = cx + math.cos(a) * rx, cy + math.sin(a) * ry
        if flat_bottom and y > cy + ry * 0.55:
            y = h - 2.0
        pts.append((x, y))
    return mask_of(w, h, lambda d: d.polygon(pts, fill=255))


# ------------------------------------------------------------------ rocas y bloques
def rock(k, w, h, seed):
    rng = random.Random(seed)
    P = KINGS[k]
    W, H = canvas(w, h)
    if k == "censura":
        return block(k, w, h, seed)
    m = blob_mask(W, H, rng, 0.2 if k != "vulva" else 0.3, 11 if k == "vulva" else 9)
    im = shade(m, P["stone"])
    base = P["stone"]

    def det(d, layer):
        # facetas y grietas
        for _ in range(2):
            x = rng.randint(W // 4, W * 3 // 4)
            y = rng.randint(3, H // 2)
            line(layer, x, y, x + rng.randint(-5, 5), y + rng.randint(4, 9), base.deep if k != "vulva" else P["wood"].base)
        for _ in range(3):
            x, y = rng.randint(3, W - 6), rng.randint(2, H // 2)
            line(layer, x, y, x + rng.randint(2, 5), y, base.hi)
        if k == "neutral":  # musgo arriba
            for _ in range(int(W * 0.9)):
                x, y = rng.randint(2, W - 3), rng.randint(1, int(H * 0.5))
                c = rng.choice([P["moss"].base, P["moss"].hi, P["moss"].lo])
                for dx in range(rng.randint(1, 3)):
                    px(layer, x + dx, y, c)
        if k == "vulva":  # venas y brillos humedos
            for _ in range(2):
                x, y = rng.randint(4, W - 6), H - 5
                for i in range(rng.randint(8, 14)):
                    px(layer, x + int(i * 0.6), y - i, P["wood"].base)
                    if i % 3 == 2:
                        px(layer, x + int(i * 0.6) + 1, y - i, P["wood"].lo)
            for _ in range(3):
                x, y = rng.randint(5, W - 8), rng.randint(3, H // 2)
                layer.putpixel((x, y), WHITE) if 0 <= x < W and 0 <= y < H else None
                px(layer, x + 1, y, P["moss"].hi)
        if k == "mixto":  # hierro asomando
            x = rng.randint(W // 3, W * 2 // 3)
            line(layer, x, 2, x + 2, 8, P["wood"].lo)
            line(layer, x + 1, 2, x + 3, 8, P["wood"].base)

    draw_on(im, m, det)
    return outline(im)


def block(k, w, h, seed):
    """Bloque de piedra (censura: blanco con barra negra; tambien sirve de muro bajo)."""
    P = KINGS[k]
    W, H = canvas(w, h)
    m = mask_of(W, H, lambda d: d.rounded_rectangle((1, 1, W - 2, H - 2), radius=3, fill=255))
    im = shade(m, P["stone"])
    rng = random.Random(seed)

    def det(d, layer):
        by = H // 2 - 4
        d.rectangle((0, by, W, by + 7), fill=BAR)
        d.line((0, by, W, by), fill=BARHI)
        for i in range(2):
            x = rng.randint(4, W - 6)
            line(layer, x, 2, x + 2, by - 2, P["stone"].lo)
        # juntas
        line(layer, 2, H - 8, W - 3, H - 8, P["stone"].lo)

    draw_on(im, m, det)
    return outline(im)


# ------------------------------------------------------------------ columnas
def column(k):
    P = KINGS[k]
    rng = random.Random(7)
    W, H = 36, 74
    im = new(W, H)
    if k == "pene":
        base = mask_of(W, H, lambda d: d.rectangle((2, 64, 33, 72), fill=255))
        shaft = mask_of(W, H, lambda d: d.rectangle((7, 12, 28, 64), fill=255))
        cap = mask_of(W, H, lambda d: d.rectangle((2, 3, 33, 11), fill=255))
        for m, pal in ((base, P["stone"]), (shaft, P["stone"]), (cap, P["stone"])):
            layer = shade(m, pal)
            paste_clip(im, m, layer)
        for x in range(10, 28, 4):  # estrias
            line(im, x, 13, x, 63, P["stone"].lo)
            line(im, x + 1, 13, x + 1, 63, P["stone"].hi)
        line(im, 2, 7, 33, 7, P["trim"].base)  # banda dorada
        line(im, 2, 68, 33, 68, P["trim"].base)
        line(im, 4, 62, 31, 62, P["stone"].deep)
        # grieta
        line(im, 15, 30, 18, 40, P["stone"].deep)
        line(im, 18, 40, 16, 46, P["stone"].deep)
    elif k == "neutral":
        m = mask_of(W, H, lambda d: d.polygon([(8, 70), (6, 66), (10, 60), (10, 12), (26, 12), (26, 60), (30, 66), (28, 70)], fill=255))
        im = shade(m, P["wood"])

        def det(d, layer):
            for x in range(11, 26, 3):
                line(layer, x, 14, x + rng.randint(-1, 1), 62, P["wood"].deep)
            for _ in range(10):
                y = rng.randint(16, 58)
                line(layer, rng.randint(11, 22), y, rng.randint(14, 25), y, P["wood"].hi)
            for _ in range(36):  # musgo
                x, y = rng.randint(9, 27), rng.randint(14, 66)
                if rng.random() < 0.5:
                    px(layer, x, y, rng.choice([P["moss"].base, P["moss"].lo, P["moss"].hi]))

        draw_on(im, m, det)
        canopy = mask_of(W, H, lambda d: (d.ellipse((1, 0, 35, 22), fill=255)))
        leaf = shade(canopy, P["moss"])
        paste_clip(im, canopy, leaf)
        for _ in range(14):
            x, y = rng.randint(4, 31), rng.randint(3, 17)
            px(im, x, y, P["moss"].hi)
            px(im, x + 1, y + 1, P["moss"].deep)
    elif k == "vulva":
        def prof(y):
            return 9.0 + 4.0 * math.sin((y - 10) / 62.0 * math.tau * 1.1) + (3 if y > 60 else 0)

        pts = [(18 - prof(y), y) for y in range(12, 72, 2)] + [(18 + prof(y), y) for y in range(70, 11, -2)]
        dome = (18, 4)
        m = mask_of(W, H, lambda d: (d.polygon(pts, fill=255), d.ellipse((8, 2, 28, 24), fill=255)))
        im = shade(m, P["stone"])

        def det(d, layer):
            for i in range(3):
                x0 = 12 + i * 6
                for y in range(16, 66):
                    px(layer, x0 + int(math.sin(y / 7.0 + i) * 2), y, P["wood"].base if y % 5 else P["wood"].lo)
            for x, y in ((13, 8), (14, 7), (15, 7), (14, 18), (13, 30), (13, 31)):
                px(layer, x, y, WHITE)
            px(layer, 18, 3, P["trim"].hi)

        draw_on(im, m, det)
    elif k == "mixto":
        base = mask_of(W, H, lambda d: d.rectangle((3, 64, 32, 72), fill=255))
        shaft = mask_of(W, H, lambda d: d.rectangle((9, 12, 26, 64), fill=255))
        head = mask_of(W, H, lambda d: d.rectangle((6, 4, 29, 12), fill=255))
        for m, pal in ((base, P["metal"]), (shaft, P["metal"]), (head, P["metal"])):
            paste_clip(im, m, shade(m, pal))

        def stripes(d, layer):
            for y in range(36, 56):
                for x in range(9, 27):
                    if ((x + y) // 4) % 2 == 0:
                        px(layer, x, y, P["trim"].base if x > 11 else P["trim"].hi)
                    else:
                        px(layer, x, y, BAR)

        draw_on(im, shaft, stripes)
        for y in (14, 62):
            line(im, 9, y, 26, y, P["metal"].deep)
        for x, y in ((10, 6), (27, 6), (5, 66), (30, 66)):
            px(im, x, y, P["metal"].hi)
        lamp = mask_of(W, H, lambda d: d.rectangle((13, 0, 22, 4), fill=255))
        paste_clip(im, lamp, shade(lamp, P["trim"]))
    else:  # censura
        base = mask_of(W, H, lambda d: d.rectangle((2, 64, 33, 72), fill=255))
        shaft = mask_of(W, H, lambda d: d.rectangle((7, 12, 28, 64), fill=255))
        cap = mask_of(W, H, lambda d: d.rectangle((2, 3, 33, 11), fill=255))
        for m in (base, shaft, cap):
            paste_clip(im, m, shade(m, P["stone"]))
        for x in range(10, 28, 6):
            line(im, x, 13, x, 63, P["stone"].lo)
        d = ImageDraw.Draw(im)
        d.rectangle((6, 30, 29, 40), fill=BAR)
        d.line((6, 30, 29, 30), fill=BARHI)
        d.line((2, 7, 33, 7), fill=P["trim"].base)
    return outline(im)


# ------------------------------------------------------------------ pieza ancha y baja
def extra(k):
    P = KINGS[k]
    rng = random.Random(11)
    W, H = 66, 30
    if k == "censura":
        return block(k, 64, 28, 3)
    if k == "neutral":  # tronco caido
        m = mask_of(W, H, lambda d: d.rounded_rectangle((2, 4, 64, 27), radius=9, fill=255))
        im = shade(m, P["wood"])

        def det(d, layer):
            for y in range(8, 26, 4):
                line(layer, 14, y, 62, y + rng.randint(-1, 1), P["wood"].deep)
            for _ in range(20):
                x, y = rng.randint(16, 60), rng.randint(6, 24)
                line(layer, x, y, x + rng.randint(2, 5), y, P["wood"].hi)
            for _ in range(40):
                x, y = rng.randint(14, 62), rng.randint(5, 14)
                px(layer, x, y, rng.choice([P["moss"].base, P["moss"].lo, P["moss"].hi]))
            # corte de la punta: anillos
            d.ellipse((2, 4, 20, 27), fill=P["wood2"].base)
            d.ellipse((6, 9, 16, 22), outline=P["wood2"].lo)
            d.ellipse((9, 13, 13, 18), outline=P["wood2"].deep)

        draw_on(im, m, det)
        return outline(im)
    if k == "pene":  # tambor de columna tumbado
        m = mask_of(W, H, lambda d: d.rounded_rectangle((4, 3, 63, 27), radius=4, fill=255))
        im = shade(m, P["stone"])

        def det(d, layer):
            for y in range(7, 26, 4):
                line(layer, 14, y, 62, y, P["stone"].lo)
            d.ellipse((2, 3, 20, 27), fill=P["stone"].hi)
            d.ellipse((6, 8, 16, 22), outline=P["stone"].lo)
            line(layer, 40, 6, 44, 14, P["stone"].deep)
            line(layer, 44, 14, 42, 20, P["stone"].deep)
            line(layer, 26, 3, 26, 27, P["trim"].base)

        draw_on(im, m, det)
        return outline(im)
    if k == "vulva":
        m = blob_mask(W, H, rng, 0.22, 12)
        im = shade(m, P["stone"])

        def det(d, layer):
            for i in range(3):
                x0 = 12 + i * 18
                for t in range(9):
                    px(layer, x0 + t, 20 - int(math.sin(t / 8.0 * math.pi) * 8) - i, P["wood"].base)
            for x, y in ((14, 8), (30, 7), (47, 9), (24, 12)):
                px(layer, x, y, WHITE)
                px(layer, x + 1, y, P["trim"].hi)

        draw_on(im, m, det)
        return outline(im)
    # mixto: barrera de aduana (dos postes y barra rayada)
    im = new(W, H)
    for x0 in (3, 56):
        m = mask_of(W, H, lambda d, x0=x0: d.rectangle((x0, 2, x0 + 6, 28), fill=255))
        paste_clip(im, m, shade(m, P["metal"]))
    bar = mask_of(W, H, lambda d: d.rectangle((6, 7, 60, 17), fill=255))
    paste_clip(im, bar, shade(bar, P["trim"]))

    def stripes(d, layer):
        for y in range(7, 18):
            for x in range(6, 61):
                if ((x + y) // 5) % 2 == 1:
                    px(layer, x, y, RED)

    draw_on(im, bar, stripes)
    for x in (4, 57):
        px(im, x, 3, P["trim"].hi)
    feet = mask_of(W, H, lambda d: (d.rectangle((1, 26, 11, 28), fill=255), d.rectangle((52, 26, 63, 28), fill=255)))
    paste_clip(im, feet, shade(feet, P["metal"]))
    return outline(im)


# ------------------------------------------------------------------ rompibles
def barrel(k):
    P = KINGS[k]
    rng = random.Random(21)
    W, H = 30, 36
    if k == "pene":  # anfora
        def half(y):
            return 11.0 * math.sin(math.pi * (y - 8) / 24.0) ** 0.7 + 3.0 if 8 <= y <= 31 else 0

        pts = [(15 - half(y), y) for y in range(8, 32)] + [(15 + half(y), y) for y in range(31, 7, -1)]
        m = mask_of(W, H, lambda d: (d.polygon(pts, fill=255), d.rectangle((11, 2, 19, 9), fill=255), d.rectangle((9, 1, 21, 3), fill=255),
                                     d.rectangle((9, 30, 21, 34), fill=255), d.rectangle((1, 9, 4, 20), fill=255), d.rectangle((26, 9, 29, 20), fill=255)))
        im = shade(m, P["wood"])

        def det(d, layer):
            for y in range(16, 22):  # banda con greca
                for x in range(6, 25):
                    px(layer, x, y, P["wood2"].base)
            for x in range(6, 25):
                px(layer, x, 17, BAR if (x // 2) % 2 == 0 else P["wood"].deep)
                px(layer, x, 20, BAR if (x // 2) % 2 == 1 else P["wood"].deep)
            for x, y in ((9, 12), (9, 13), (10, 11), (9, 25), (10, 26)):
                px(layer, x, y, P["wood"].hi)

        draw_on(im, m, det)
        return outline(im)
    if k == "vulva":  # vasija organica con brillo
        def half(y):
            return 12.0 * math.sin(math.pi * (y - 4) / 30.0) ** 0.6 + 2 if 4 <= y <= 34 else 0

        pts = [(15 - half(y), y) for y in range(4, 35)] + [(15 + half(y), y) for y in range(34, 3, -1)]
        m = mask_of(W, H, lambda d: (d.polygon(pts, fill=255), d.ellipse((9, 0, 21, 7), fill=255)))
        im = shade(m, P["stone"])

        def det(d, layer):
            for y in range(10, 31):
                px(layer, 15 + int(math.sin(y / 5.0) * 2), y, P["wood"].base)
            for x, y in ((8, 14), (8, 15), (9, 13), (9, 22)):
                px(layer, x, y, WHITE)
            d.ellipse((11, 1, 19, 5), fill=P["wood"].deep)

        draw_on(im, m, det)
        return outline(im)
    # tambor / barril de duelas
    def half(y):
        return 11.5 + 2.5 * math.sin(math.pi * (y - 2) / 32.0) if k != "mixto" and k != "censura" else 12.5

    pts = [(15 - half(y), y) for y in range(3, 34)] + [(15 + half(y), y) for y in range(33, 2, -1)]
    m = mask_of(W, H, lambda d: (d.polygon(pts, fill=255), d.ellipse((3, 0, 27, 8), fill=255)))
    pal = P["wood"] if k in ("neutral",) else P["metal"] if k == "mixto" else P["stone"]
    im = shade(m, pal)

    def det(d, layer):
        d.ellipse((4, 1, 26, 7), fill=pal.hi)
        d.ellipse((7, 2, 23, 6), outline=pal.lo)
        for y in (11, 28):  # aros
            for x in range(2, 29):
                px(layer, x, y, P["metal"].deep if k != "censura" else BAR)
        if k == "neutral":
            for x in range(6, 26, 5):
                line(layer, x, 8, x, 34, pal.deep)
            for _ in range(10):
                px(layer, rng.randint(4, 25), rng.randint(2, 10), P["moss"].base)
        elif k == "mixto":
            for x in range(3, 28):
                for y in range(16, 24):
                    px(layer, x, y, P["trim"].base if ((x + y) // 3) % 2 else BAR)
        else:
            d.rectangle((3, 16, 27, 23), fill=BAR)

    draw_on(im, m, det)
    return outline(im)


def crate(k):
    P = KINGS[k]
    rng = random.Random(31)
    W, H = 34, 34
    m = mask_of(W, H, lambda d: d.rounded_rectangle((1, 2, 32, 32), radius=2, fill=255))
    pal = {"neutral": P["wood"], "pene": P["wood2"], "vulva": P["wood2"], "mixto": P["wood"], "censura": P["stone"]}[k]
    im = shade(m, pal)

    def det(d, layer):
        d.rectangle((1, 2, 32, 8), fill=pal.hi)  # tapa vista desde arriba
        d.line((1, 9, 32, 9), fill=pal.deep)
        frame = P["wood"].deep if k not in ("censura",) else P["stone"].lo
        for rx in ((2, 10, 5, 31), (28, 10, 31, 31)):
            d.rectangle(rx, fill=frame)
        d.rectangle((2, 27, 31, 31), fill=frame)
        d.rectangle((2, 10, 31, 13), fill=frame)
        line(layer, 6, 14, 27, 26, frame)
        line(layer, 27, 14, 6, 26, frame)
        if k == "neutral":
            for _ in range(24):
                px(layer, rng.randint(2, 31), rng.randint(2, 12), rng.choice([P["moss"].base, P["moss"].lo]))
        elif k == "pene":
            for x, y in ((3, 11), (30, 11), (3, 29), (30, 29)):
                d.rectangle((x - 1, y - 1, x + 1, y + 1), fill=P["trim"].base)
        elif k == "vulva":
            for y in range(14, 27, 4):
                line(layer, 6, y, 27, y, P["wood"].base)
            px(layer, 9, 4, WHITE)
        elif k == "mixto":  # sello de contrabando
            d.rectangle((11, 17, 22, 23), outline=C("#4a9a4a"))
            line(layer, 13, 20, 20, 20, C("#4a9a4a"))
        else:  # archivo censurado
            d.rectangle((2, 15, 31, 24), fill=BAR)
            d.rectangle((12, 4, 21, 7), fill=P["stone"].lo)

    draw_on(im, m, det)
    return outline(im)


def debris(k, w, h, kind, seed):
    """Restos planos (sin colision) con los colores del rompible."""
    P = KINGS[k]
    rng = random.Random(seed)
    cols = {
        "barrel": {"neutral": P["wood"], "pene": P["wood"], "vulva": P["stone"], "mixto": P["metal"], "censura": P["stone"]}[k],
        "crate": {"neutral": P["wood"], "pene": P["wood2"], "vulva": P["wood2"], "mixto": P["wood"], "censura": P["stone"]}[k],
    }[kind]
    W, H = w + 2, h + 2
    im = new(W, H)
    # sombra bajo los restos
    for _ in range(9):
        x, y = rng.randint(3, W - 10), rng.randint(2, H - 8)
        pw, ph = rng.randint(5, 11), rng.randint(3, 5)
        pts = [(x, y + rng.randint(0, 1)), (x + pw, y + rng.randint(0, 2)), (x + pw - rng.randint(0, 2), y + ph), (x + 1, y + ph)]
        m = mask_of(W, H, lambda d, pts=pts: d.polygon(pts, fill=255))
        paste_clip(im, m, shade(m, cols))
    if k == "censura":  # un trozo con barra negra
        d = ImageDraw.Draw(im)
        d.rectangle((W // 2 - 5, H // 2, W // 2 + 4, H // 2 + 1), fill=BAR)
    return outline(im)


def chunks(k):
    P = KINGS[k]
    tones = [P["wood"], P["wood2"], P["stone"], P["metal"]]
    im = new(24, 6)
    for i, pal in enumerate(tones):
        m = mask_of(6, 6, lambda d: d.polygon([(1, 1), (4, 0), (5, 3), (3, 5), (0, 4)], fill=255))
        tile = outline(shade(m, pal))
        im.paste(tile, (i * 6, 0))
    return im


# ------------------------------------------------------------------ trampas (decoracion)
def spikes(k, n):
    P = KINGS[k]
    rng = random.Random(41 + n)
    S = 16 * n + 12
    m = mask_of(S, S, lambda d: d.rounded_rectangle((1, 1, S - 2, S - 2), radius=3, fill=255))
    im = shade(m, P["plate"])
    d = ImageDraw.Draw(im)
    d.rectangle((3, 3, S - 4, S - 4), outline=P["plate"].deep)
    for x, y in ((4, 4), (S - 5, 4), (4, S - 5), (S - 5, S - 5)):
        px(im, x, y, P["plate"].hi)
        px(im, x + 1, y + 1, P["plate"].deep)
    steel = Pal("#9aa1ad")
    for i in range(n):
        for j in range(n):
            cx, cy = 6 + 8 + i * 16, 6 + 8 + j * 16 + 3
            d.ellipse((cx - 5, cy - 2, cx + 5, cy + 2), fill=BAR)  # agujero
            d.ellipse((cx - 4, cy - 1, cx + 4, cy + 1), fill=(40, 36, 44, 255))
            # pua: triangulo con luz a la izquierda
            for t in range(11):
                half = max(0, 3 - t // 3)
                for dx in range(-half, half + 1):
                    c = steel.hi if dx < 0 else steel.base if dx == 0 else steel.lo
                    px(im, cx + dx, cy - t, c)
            px(im, cx, cy - 11, C("#a01c2c"))
            px(im, cx, cy - 10, C("#a01c2c"))
            px(im, cx - 4, cy, steel.deep)
            px(im, cx + 4, cy, steel.deep)
    return outline(im)


def skull():
    im = new(16, 14)
    m = mask_of(16, 14, lambda d: (d.ellipse((2, 1, 13, 10), fill=255), d.rectangle((5, 8, 10, 12), fill=255)))
    im.paste(shade(m, Pal("#e8e2cf")), (0, 0), m)
    d = ImageDraw.Draw(im)
    d.rectangle((4, 5, 6, 7), fill=BAR)
    d.rectangle((9, 5, 11, 7), fill=BAR)
    px(im, 8, 8, BAR)
    for x in (6, 8, 10):
        px(im, x, 11, BAR)
    return outline(im)


def bones():
    im = new(34, 16)
    pal = Pal("#e8e2cf")
    for (x0, y0, x1, y1) in ((2, 4, 22, 10), (6, 12, 28, 6)):
        m = Image.new("L", (34, 16), 0)
        dm = ImageDraw.Draw(m)
        dm.line((x0, y0, x1, y1), fill=255, width=3)
        for (cx, cy) in ((x0, y0), (x1, y1)):
            dm.ellipse((cx - 2, cy - 3, cx + 2, cy + 1), fill=255)
            dm.ellipse((cx - 2, cy, cx + 2, cy + 3), fill=255)
        layer = shade(m, pal)
        paste_clip(im, m, layer)
    return outline(im)


# ------------------------------------------------------------------ salida
def save(im, k, name):
    d = OUT / k if k else OUT
    d.mkdir(parents=True, exist_ok=True)
    im.save(d / f"{name}.png")


def build(k):
    shape = SHAPE_AS.get(k, k)
    if shape != k:
        KINGS[shape], saved = KINGS[k], KINGS[shape]
    try:
        save(rock(shape, 48, 38, 101), k, "rock_a")
        save(rock(shape, 32, 26, 202), k, "rock_b")
        save(column(shape), k, "column")
        save(extra(shape), k, "extra")
        save(barrel(shape), k, "barrel")
        save(crate(shape), k, "crate")
        save(debris(shape, 36, 20, "barrel", 5), k, "barrel_broken")
        save(debris(shape, 38, 22, "crate", 6), k, "crate_broken")
        save(chunks(shape), k, "chunk")
        save(spikes(shape, 3), k, "spikes")
        save(spikes(shape, 2), k, "spikes_s")
    finally:
        if shape != k:
            KINGS[shape] = saved


if __name__ == "__main__":
    ks = sys.argv[1:] or list(KINGS)
    for k in ks:
        build(k)
    save(skull(), None, "skull")
    save(bones(), None, "bones")
    print("listo:", ", ".join(ks))
