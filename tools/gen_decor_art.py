"""Genera el arte de la decoracion junto a los muros (assets/sprites/environment/decor/).

Uso: python3 tools/gen_decor_art.py
Roadmap tanda 3, puntos 35 y 38-45. Todo a 1 px de arte = 1 px de mundo, con contorno oscuro
y luz arriba-izquierda (misma paleta que gen_wall_art.py). Es adorno: sin colision.

Salida (<reino> = neutral|pene|vulva|mixto|censura):
  web_a/web_b.png            telaranas de esquina (arriba-izquierda; el juego las voltea)
  hero_0..3.png              restos de heroes anteriores (esqueleto, sentado con nota, espada, tumba RIP)
  bones_a/bones_b.png        huesos sueltos
  statue_<reino>_m/_f.png    estatuas clasicas con hoja de parra
  neutral_*                  matorrales, pelos gigantes, lianas, hongos, raiz, ladillas (3 cuadros)
  pene_*                     anforas, columnas jonicas rotas, escudo y casco griegos
  vulva_*                    flores, corazones, cortina, jarrones
  mixto_*                    garita, valla, conos, carteles (STOP, prohibido pasar es/en, icono)
  censura_*                  sellos CENSURADO (es/en), barras negras, alfombras rojas, hojas de parra
Los textos van pintados con una fuente de 3x5 px propia (solo mayusculas).
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets/sprites/environment/decor"
CLEAR = (0, 0, 0, 0)
OL = (13, 11, 15, 255)


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (a[3],)


def dk(c, k):
    return (max(0, min(255, int(c[0] * k))), max(0, min(255, int(c[1] * k))), max(0, min(255, int(c[2] * k))), c[3])


def lt(c, t):
    return mix(c, (255, 255, 255, c[3]), t)


def new(w, h):
    im = Image.new("RGBA", (w, h), CLEAR)
    return im, ImageDraw.Draw(im)


def save(im, name):
    OUT.mkdir(parents=True, exist_ok=True)
    im.save(OUT / f"{name}.png")


def outline(im, c=OL):
    src = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < im.width and 0 <= yy < im.height and src.getpixel((xx, yy))[3] > 0:
                        im.putpixel((x, y), c)
                        break
    return im


def padded(im, p=1):
    """Agrega margen transparente para el contorno."""
    out = Image.new("RGBA", (im.width + 2 * p, im.height + 2 * p), CLEAR)
    out.alpha_composite(im, (p, p))
    return out


def cyl(im, strength=1.0):
    """Sombreado cilindrico por filas: luz a la izquierda, sombra a la derecha."""
    src = im.copy()
    for y in range(im.height):
        x = 0
        while x < im.width:
            if src.getpixel((x, y))[3] == 0:
                x += 1
                continue
            x0 = x
            while x < im.width and src.getpixel((x, y))[3] > 0:
                x += 1
            n = x - x0
            if n < 5:
                continue
            for i in range(n):
                t = (i + 0.5) / n
                p = src.getpixel((x0 + i, y))
                if t < 0.22:
                    q = lt(p, 0.22 * strength)
                elif t > 0.9:
                    q = dk(p, 1 - 0.32 * strength)
                elif t > 0.68:
                    q = dk(p, 1 - 0.16 * strength)
                else:
                    continue
                im.putpixel((x0 + i, y), q)
    return im


# fuente 3x5
_G = {
    "A": [".#.", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": [".##", "#..", "#..", "#..", ".##"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": [".#.", "#.#", "#.#", "#.#", ".#."], "P": ["##.", "#.#", "##.", "#..", "#.."],
    "R": ["##.", "#.#", "##.", "#.#", "#.#"], "S": [".##", "#..", ".#.", "..#", "##."],
    "T": ["###", ".#.", ".#.", ".#.", ".#."], "U": ["#.#", "#.#", "#.#", "#.#", "###"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."], " ": ["...", "...", "...", "...", "..."],
}


def text_w(s):
    return len(s) * 4 - 1


def text(im, x, y, s, c):
    for ch in s:
        g = _G[ch]
        for gy in range(5):
            for gx in range(3):
                if g[gy][gx] == "#":
                    im.putpixel((x + gx, y + gy), c)
        x += 4


# ------------------------------------------------------------------ paletas
BONE = (C("f0e8d0"), C("cbbf9f"), C("9a8e72"))
METAL = (C("c4ccd8"), C("8a94a6"), C("566074"), C("343c4c"))
WOOD = (C("b88850"), C("8a5c34"), C("5e3a20"))
STONE = {  # (claro, medio, oscuro)
    "neutral": (C("a8a490"), C("857f6c"), C("5c5748")),
    "pene": (C("f4f2ea"), C("e0ddd2"), C("b4b4c4")),
    "vulva": (C("ffe2e6"), C("f2c0cc"), C("c88aa0")),
    "mixto": (C("b8bece"), C("8a92a8"), C("5a6078")),
    "censura": (C("ffffff"), C("eceefa"), C("b8bbd6")),
}
LEAF = (C("78c04a"), C("4a9a38"), C("2e6a2c"))


def blob(d, cx, cy, rx, ry, col):
    d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=col)


# ------------------------------------------------------------------ generico
def web(variant):
    im, d = new(38, 38)
    col = (236, 236, 244, 175)
    br = (255, 255, 255, 215)
    ends = [(37, 0), (35, 11), (29, 24), (19, 33), (9, 36), (0, 37)] if variant == 0 else [(37, 0), (36, 9), (31, 21), (21, 31), (10, 35), (0, 37)]
    for e in ends:
        d.line((0, 0, e[0], e[1]), fill=col)
    for r in (0.3, 0.52, 0.76, 0.98):
        pts = [(e[0] * r, e[1] * r) for e in ends]
        for a, b in zip(pts, pts[1:]):
            mx, my = (a[0] + b[0]) / 2 * 0.9, (a[1] + b[1]) / 2 * 0.9
            d.line((a[0], a[1], mx, my), fill=col)
            d.line((mx, my, b[0], b[1]), fill=col)
        for p in pts[1:-1]:
            im.putpixel((int(p[0]), int(p[1])), br)
    d.line((14, 24, 13, 31), fill=col)
    d.line((26, 12, 27, 19), fill=col)
    if variant == 1:  # arana colgando
        d.line((21, 21, 21, 29), fill=col)
        blob(d, 21, 31, 2, 2, C("2a2230"))
        for dx in (-3, -2, 2, 3):
            im.putpixel((21 + dx, 29 + (abs(dx) == 3)), C("2a2230"))
        im.putpixel((20, 30), C("d84a4a"))
    return im


def bones(variant):
    im, d = new(22, 10)
    b, s, dd = BONE
    if variant == 0:
        d.line((2, 6, 17, 3), fill=b, width=2)
        d.line((4, 2, 18, 7), fill=s, width=2)
        for p in ((1, 5), (1, 7), (18, 2), (19, 3), (3, 1), (4, 1), (19, 7), (20, 7)):
            im.putpixel(p, b)
    else:
        blob(d, 7, 5, 4, 3, b)
        im.putpixel((5, 5), OL)
        im.putpixel((8, 5), OL)
        d.line((11, 7, 20, 7), fill=s, width=2)
        im.putpixel((21, 6), b)
        im.putpixel((21, 8), b)
    return outline(padded(im))


def hero(i):
    b, s, dd = BONE
    if i == 0:  # esqueleto tumbado con casco y espada
        im, d = new(50, 24)
        d.line((14, 13, 44, 13), fill=s, width=2)
        for k in range(5):
            d.arc((14 + k * 3, 4, 22 + k * 3, 20), 270, 90, fill=b)
        d.line((30, 11, 42, 6), fill=b, width=2)
        d.line((31, 15, 46, 19), fill=b, width=2)
        for p in ((43, 5), (45, 5), (47, 19), (48, 18)):
            im.putpixel(p, b)
        blob(d, 9, 12, 6, 5, b)
        d.pieslice((2, 4, 16, 18), 180, 360, fill=METAL[1])
        d.rectangle((2, 11, 16, 11), fill=METAL[2])
        im.putpixel((7, 14), OL)
        im.putpixel((11, 14), OL)
        d.line((20, 21, 47, 21), fill=METAL[0], width=1)
        d.rectangle((17, 19, 19, 23), fill=WOOD[1])
        d.line((47, 21, 49, 22), fill=METAL[2])
        return outline(padded(im))
    if i == 1:  # sentado contra el muro con una nota
        im, d = new(32, 38)
        blob(d, 14, 8, 5, 5, b)
        d.pieslice((8, 1, 20, 12), 180, 360, fill=METAL[1])
        im.putpixel((12, 9), OL)
        im.putpixel((16, 9), OL)
        d.rectangle((12, 14, 16, 26), fill=s)
        for y in (16, 19, 22):
            d.line((10, y, 18, y), fill=b)
        d.line((8, 15, 6, 25), fill=b, width=2)
        d.line((20, 15, 22, 24), fill=b, width=2)
        d.line((11, 27, 20, 33), fill=b, width=2)
        d.line((16, 27, 25, 31), fill=s, width=2)
        d.rectangle((21, 31, 26, 33), fill=b)
        d.rectangle((2, 20, 10, 31), fill=C("f4ecd0"))
        d.rectangle((2, 20, 10, 20), fill=C("d8cca8"))
        for y in (22, 24, 26):
            d.line((3, y, 8, y), fill=C("7a6a50"))
        im.putpixel((8, 29), C("c8283c"))
        im.putpixel((7, 28), C("c8283c"))
        im.putpixel((9, 28), C("c8283c"))
        return outline(padded(im))
    if i == 2:  # espada clavada con casco colgando y bota
        im, d = new(26, 42)
        d.rectangle((12, 12, 14, 36), fill=METAL[0])
        d.line((14, 12, 14, 36), fill=METAL[2])
        d.rectangle((6, 8, 20, 10), fill=C("c8a040"))
        d.rectangle((12, 1, 14, 7), fill=WOOD[1])
        blob(d, 13, 3, 2, 2, C("c8a040"))
        d.pieslice((13, 0, 25, 14), 180, 360, fill=METAL[1])
        d.rectangle((13, 7, 25, 8), fill=METAL[2])
        blob(d, 7, 37, 6, 3, b)
        blob(d, 20, 38, 4, 2, s)
        d.rectangle((16, 30, 19, 37), fill=WOOD[1])
        d.rectangle((16, 35, 22, 38), fill=WOOD[2])
        return outline(padded(im))
    im, d = new(28, 44)  # cruz de tumba con RIP y casco
    d.rectangle((12, 8, 15, 42), fill=WOOD[1])
    d.rectangle((12, 8, 12, 42), fill=WOOD[0])
    d.rectangle((4, 15, 23, 18), fill=WOOD[1])
    d.rectangle((4, 15, 23, 15), fill=WOOD[0])
    d.rectangle((5, 20, 22, 30), fill=WOOD[0])
    d.rectangle((5, 29, 22, 30), fill=WOOD[1])
    text(im, 8, 23, "RIP", WOOD[2])
    d.pieslice((9, 1, 19, 12), 180, 360, fill=METAL[1])
    d.rectangle((9, 7, 19, 8), fill=METAL[2])
    blob(d, 14, 41, 8, 2, C("5e4630"))
    for x in (6, 22):
        d.rectangle((x, 36, x + 1, 41), fill=LEAF[1])
        im.putpixel((x, 35), C("e85a7a"))
    return outline(padded(im))


# ------------------------------------------------------------------ estatuas
def statue(k, sex, mosaic=False):
    L, M, D = STONE[k]
    im, d = new(36, 58)
    d.rectangle((3, 47, 32, 56), fill=M)
    d.rectangle((1, 54, 34, 57), fill=D)
    d.rectangle((3, 47, 32, 48), fill=L)
    d.rectangle((6, 44, 29, 46), fill=D)
    if sex == "m":
        d.rectangle((11, 30, 16, 45), fill=M)
        d.rectangle((19, 30, 24, 45), fill=M)
        d.rectangle((10, 44, 16, 46), fill=M)
        d.rectangle((19, 44, 26, 46), fill=M)
        d.rounded_rectangle((11, 13, 25, 33), 4, fill=M)
        blob(d, 18, 7, 5, 6, M)
        d.rectangle((13, 1, 23, 3), fill=D)
        d.line((10, 15, 6, 28), fill=M, width=4)
        d.line((26, 15, 31, 8), fill=M, width=4)
        d.line((32, 2, 32, 42), fill=D)
        im.putpixel((32, 1), L)
        for y in (18, 22, 26):
            d.line((14, y, 22, y), fill=D)
        leaf = [(14, 29), (23, 29), (21, 34), (18, 37), (15, 34)]
    else:
        d.rectangle((12, 31, 17, 45), fill=M)
        d.rectangle((19, 31, 24, 45), fill=M)
        d.rectangle((10, 44, 17, 46), fill=M)
        d.rectangle((19, 44, 26, 46), fill=M)
        d.polygon([(12, 14), (24, 14), (26, 30), (10, 30)], fill=M)
        d.ellipse((9, 26, 27, 38), fill=M)
        blob(d, 18, 8, 5, 6, M)
        blob(d, 18, 1, 4, 3, D)
        d.line((11, 16, 14, 24), fill=M, width=3)
        d.line((25, 16, 22, 29), fill=M, width=3)
        d.rectangle((12, 9, 12, 20), fill=D)
        d.rectangle((24, 9, 24, 20), fill=D)
        d.line((17, 31, 17, 45), fill=D)  # separa las piernas
        d.line((23, 18, 25, 28), fill=D)  # hueco del brazo
        d.line((12, 20, 14, 26), fill=D)
        leaf = [(14, 30), (23, 30), (21, 35), (18, 38), (15, 35)]
    cyl(im, 0.8)
    im.putpixel((16, 7), OL)
    im.putpixel((20, 7), OL)
    if mosaic:
        # pixelado de censura de telediario: cuadritos grises 3x3 sobre la entrepierna
        rr = random.Random(5)
        y0 = leaf[0][1] - 1
        for gy in range(3):
            for gx in range(4):
                g = rr.choice((C("e8e8f2"), C("b8b8c8"), C("8a8aa0"), C("d0d0de")))
                d.rectangle((12 + gx * 3, y0 + gy * 3, 14 + gx * 3, y0 + gy * 3 + 2), fill=g)
    else:
        d.polygon(leaf, fill=LEAF[1])
        d.line((18, leaf[0][1], 18, leaf[-2][1] + 2), fill=LEAF[2])
        d.line((14, leaf[0][1], 17, leaf[0][1] + 3), fill=LEAF[0])
        im.putpixel((22, leaf[0][1] + 1), LEAF[0])
    if k == "neutral":  # musgo
        for p in ((12, 20), (13, 21), (24, 40), (6, 50), (28, 50), (9, 48)):
            d.rectangle((p[0], p[1], p[0] + 2, p[1] + 1), fill=C("4a7a3a"))
    return outline(padded(im))


# ------------------------------------------------------------------ Selva
# Matorrales y rizos (etapa 7): volumen por lobulos (luz arriba-izquierda, sombra abajo), hojas con
# textura, silueta irregular y contorno de 1 px. Cada tipo tiene 4 variantes de tamaño distinto.
LIGHT_DIR = (-0.55, -0.65, 0.52)
_LN = math.sqrt(sum(v * v for v in LIGHT_DIR))
LIGHT_DIR = tuple(v / _LN for v in LIGHT_DIR)

GREENS = {
    "a": (C("17402a"), C("27643a"), C("3c8a40"), C("62b04c"), C("9cd868")),
    "b": (C("1a3a2c"), C("2a5a3a"), C("40803c"), C("66a84a"), C("a0d070")),
    "c": (C("1c4a2a"), C("2c6e36"), C("48943c"), C("72ba4c"), C("aee070")),
    "d": (C("1e3a1e"), C("30602a"), C("4a8432"), C("74ac42"), C("b0d860")),
}
CURLS = {
    "a": (C("2a160c"), C("4a2a14"), C("6e421e"), C("94622c"), C("c08a42")),   # castaño
    "b": (C("0e0a12"), C("1c1a2c"), C("302e50"), C("4c4e7c"), C("7c82b4")),   # negro azulado
    "c": (C("4a1c0c"), C("7a3414"), C("a85420"), C("d07c34"), C("f0a850")),   # pelirrojo
    "d": (C("3a2812"), C("684a24"), C("98702e"), C("c8a048"), C("f0d078")),   # rubio oscuro
}


def _level(pal, col):
    for i, p in enumerate(pal):
        if p[:3] == col[:3]:
            return i
    return -1


def lobe_mound(w, h, lobes, pal, rng, rough=0.2):
    """Monton de lobulos esfericos pintados de atras (arriba) hacia delante, cada uno iluminado
    desde arriba a la izquierda. Devuelve RGBA sin contorno."""
    im, _ = new(w, h)
    px = im.load()
    for (cx, cy, r) in sorted(lobes, key=lambda o: o[1]):
        for y in range(max(0, int(cy - r) - 1), min(h, int(cy + r) + 2)):
            for x in range(max(0, int(cx - r) - 1), min(w, int(cx + r) + 2)):
                dx = (x + 0.5 - cx) / r
                dy = (y + 0.5 - cy) / (r * 0.92)
                q = dx * dx + dy * dy
                if q > 1.0:
                    continue
                nz = math.sqrt(1.0 - q)
                lam = dx * LIGHT_DIR[0] + dy * LIGHT_DIR[1] + nz * LIGHT_DIR[2]
                v = lam * 0.85 + 0.30 - 0.40 * (y / h) + (rng.random() - 0.5) * rough
                lv = max(0, min(4, int((v + 0.02) * 4.6)))
                if q > 0.74 and dy > 0.15:
                    lv = min(lv, 1)            # canto inferior del lobulo: separa de lo de atras
                if q > 0.88 and dy > 0.35:
                    lv = 0
                px[x, y] = pal[lv]
    return im


def leaf_marks(im, pal, rng, n):
    """Hojitas sueltas (guion claro + guion oscuro debajo) para que no sea un manchon plano."""
    px = im.load()
    w, h = im.size
    for _ in range(n):
        x, y = rng.randint(1, w - 4), rng.randint(1, h - 3)
        if px[x, y][3] == 0 or px[x + 1, y][3] == 0:
            continue
        lv = _level(pal, px[x, y])
        if lv < 1:
            continue
        up = pal[min(4, lv + 1)]
        px[x, y] = up
        px[x + 1, y] = up
        if px[x + 1, y + 1][3]:
            px[x + 1, y + 1] = pal[max(0, lv - 1)]
        if px[x + 2, y][3] and lv >= 2 and rng.random() < 0.5:
            px[x + 2, y] = pal[max(0, lv - 1)]
    for _ in range(n // 2):                    # huecos oscuros entre las hojas (profundidad)
        x, y = rng.randint(2, w - 4), rng.randint(2, h - 3)
        if px[x, y][3] and px[x + 1, y][3] and _level(pal, px[x, y]) in (1, 2):
            px[x, y] = pal[0]
            px[x + 1, y] = pal[0]


def leaf_tips(im, pal, rng, n, top_band):
    """Puntas de hoja que sobresalen de la silueta por arriba (silueta irregular)."""
    d = ImageDraw.Draw(im)
    w, h = im.size
    px = im.load()
    for _ in range(n):
        x = rng.randint(4, w - 5)
        y = next((yy for yy in range(h) if px[x, yy][3]), None)
        if y is None or y > top_band or y < 6:
            continue
        ln = rng.randint(3, 5)
        lean = rng.choice((-2, -1, 1, 2))
        d.polygon([(x - 2, y + 1), (x + 2, y + 1), (x + lean, y - ln)], fill=pal[2])
        d.line((x - 1, y, x + lean, y - ln + 1), fill=pal[3])
        px[x + lean, y - ln] = pal[4]


def berries(im, rng, n, col, hi, area):
    px = im.load()
    for _ in range(n):
        x, y = rng.randint(area[0], area[2]), rng.randint(area[1], area[3])
        if not (px[x, y][3] and px[x + 1, y + 1][3]):
            continue
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            px[x + dx, y + dy] = col
        px[x, y] = hi
        px[x + 1, y + 1] = dk(col, 0.6)


def flowers(im, rng, n, cols, area):
    px = im.load()
    for _ in range(n):
        x, y = rng.randint(area[0], area[2]), rng.randint(area[1], area[3])
        if not all(px[x + dx, y + dy][3] for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1))):
            continue
        c = rng.choice(cols)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            px[x + dx, y + dy] = c
        px[x, y] = C("ffd84a")


def mound_lobes(w, h, rng, n_front, n_mid, n_top):
    lobes = []
    for i in range(n_front):
        r = rng.uniform(h * 0.2, h * 0.28)
        x = r + 1 + (w - 2 * r - 2) * (i + rng.uniform(-0.15, 0.15)) / max(1, n_front - 1)
        lobes.append((max(r + 1, min(w - r - 1, x)), h - r * 0.92 - 2 - rng.uniform(0, 2), r))
    for i in range(n_mid):
        r = rng.uniform(h * 0.24, h * 0.33)
        x = w * (0.2 + 0.6 * (i + rng.uniform(-0.1, 0.1)) / max(1, n_mid - 1))
        lobes.append((x, h * 0.52 + rng.uniform(-3, 3), r))
    for i in range(n_top):
        r = rng.uniform(h * 0.2, h * 0.28)
        x = w * (0.3 + 0.4 * (i + rng.uniform(-0.2, 0.2)) / (n_top - 1)) if n_top > 1 else w * rng.uniform(0.4, 0.6)
        lobes.append((x, h * 0.3 + rng.uniform(-2, 2), r))
    return [(cx, max(r + 2, cy), r) for cx, cy, r in lobes]


def bush(variant):
    """Matorral frondoso. a: 60x46 liso; b: 68x52 con bayas; c: 52x42 con florecitas; d: 74x58 con rizos."""
    spec = {0: (60, 46, 4, 3, 2, "a"), 1: (68, 52, 4, 3, 2, "b"), 2: (52, 42, 3, 2, 1, "c"), 3: (74, 58, 5, 3, 2, "d")}
    w, h, nf, nm, nt, key = spec[variant]
    rng = random.Random(400 + variant * 17)
    pal = GREENS[key]
    im = lobe_mound(w, h, mound_lobes(w, h, rng, nf, nm, nt), pal, rng, 0.22)
    leaf_tips(im, pal, rng, 5 + variant, int(h * 0.5))
    leaf_marks(im, pal, rng, 70 + variant * 16)
    px = im.load()
    for _ in range(5):                         # ramitas oscuras asomando abajo, entre las hojas
        x = rng.randint(8, w - 9)
        for y in range(h - 5, h - 2):
            if px[x, y][3]:
                px[x, y] = C("4a2e18")
    if variant == 1:
        berries(im, rng, 11, C("e0403c"), C("ffb0a0"), (8, int(h * 0.3), w - 10, h - 10))
    if variant == 2:
        flowers(im, rng, 9, [C("fff4f4"), C("ffa8c8"), C("ffe070")], (8, int(h * 0.25), w - 9, h - 9))
    if variant == 3:
        # guiño: rizos castaños asomando entre las hojas (cada uno con su tallito)
        for cx, cy, r in ((13, h - 17, 4.2), (36, h - 25, 4.6), (58, h - 18, 4.0), (26, h - 9, 3.4), (49, h - 10, 3.6)):
            fat_spiral(im, cx, cy, r, CURLS["a"], rng.uniform(0, 6.3), 1.6, rng.choice((1, -1)), 1)
    return outline(padded(im))


def bosom_bush():
    """Guiño: matorral con dos lobulos grandes de pecho y su pezon en cada uno (70x50)."""
    w, h = 70, 50
    rng = random.Random(777)
    pal = GREENS["b"]
    r = h * 0.36
    lobes = [(w * 0.3, h - r - 2, r), (w * 0.7, h - r - 2, r),   # el par, delante
             (w * 0.5, h - r * 1.55, r * 0.72), (w * 0.14, h - r * 0.7, r * 0.6), (w * 0.86, h - r * 0.7, r * 0.6)]
    im = lobe_mound(w, h, lobes, pal, rng, 0.18)
    leaf_tips(im, pal, rng, 6, int(h * 0.45))
    leaf_marks(im, pal, rng, 60)
    for cx in (w * 0.3, w * 0.7):
        nipple(im, int(cx + 3), int(h - r * 0.95))  # un poco abajo y a la derecha del centro del lobulo
    return outline(padded(im))


def nipple(im, cx, cy):
    """Areola rosada con borde mas oscuro, pezon y un brillo de 1 px."""
    px = im.load()
    for y in range(cy - 4, cy + 5):
        for x in range(cx - 4, cx + 5):
            d = math.hypot(x - cx, (y - cy) * 1.1)
            if 0 <= x < im.width and 0 <= y < im.height and px[x, y][3] and d <= 4.2:
                px[x, y] = C("b8606c") if d > 3.2 else C("e8909c")
    for x, y, c in ((cx, cy, C("a8404e")), (cx + 1, cy, C("a8404e")), (cx, cy + 1, C("8a3040")),
                    (cx + 1, cy + 1, C("8a3040")), (cx, cy - 1, C("ffd0d4"))):
        px[x, y] = c


def spiral(im, cx, cy, r_max, pal, rot=0.0, turns=1.6, flip=1):
    """Rizo en espiral (1 px de grosor): lo claro arriba-izquierda, lo oscuro abajo-derecha."""
    px = im.load()
    n = int(turns * 2 * math.pi * max(r_max, 2) * 1.6)
    for i in range(n + 1):
        t = i / n
        ang = rot + flip * t * turns * 2 * math.pi
        r = r_max * (0.3 + 0.7 * (1.0 - t) ** 0.8)
        x = int(round(cx + math.cos(ang) * r))
        y = int(round(cy + math.sin(ang) * r))
        if not (0 <= x < im.width and 0 <= y < im.height):
            continue
        sh = -(math.cos(ang) * LIGHT_DIR[0] + math.sin(ang) * LIGHT_DIR[1])
        px[x, y] = pal[4] if sh < -0.75 else (pal[3] if sh < -0.3 else (pal[2] if sh < 0.4 else pal[1]))


def fat_spiral(im, cx, cy, r_max, pal, rot=0.0, turns=1.6, flip=1, thick=1):
    """Rizo gordo (trazo de 2 px) con sombra desplazada: se lee como un bucle de vello."""
    px = im.load()
    n = int(turns * 2 * math.pi * r_max * 2.2)
    path = []
    for i in range(n + 1):
        t = i / n
        ang = rot + flip * t * turns * 2 * math.pi
        r = r_max * (0.12 + 0.88 * (1.0 - t))
        path.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r, ang))

    def put(x, y, c):
        for ox in range(thick):
            for oy in range(thick):
                xx, yy = int(round(x)) + ox, int(round(y)) + oy
                if 0 <= xx < im.width and 0 <= yy < im.height:
                    px[xx, yy] = c

    for x, y, ang in path:
        put(x + 1, y + 1, pal[0])
    for x, y, ang in path:
        sh = -(math.cos(ang) * LIGHT_DIR[0] + math.sin(ang) * LIGHT_DIR[1])
        put(x, y, pal[4] if sh < -0.75 else (pal[3] if sh < -0.2 else (pal[2] if sh < 0.5 else pal[1])))


def dome_lobes(w, h, rng):
    """Silueta de cupula irregular: filas de lobulos que se estrechan hacia arriba."""
    lobes = []
    r = h * 0.21
    for frac, wf in ((0.0, 1.0), (0.27, 0.9), (0.52, 0.7), (0.78, 0.4)):
        y = h - r - 1 - frac * (h - 2 * r - 2)
        ww = (w - 2 * r) * wf
        n = max(1, int(ww / (r * 1.25)) + 1)
        for i in range(n):
            x = w / 2 - ww / 2 + (ww * i / (n - 1) if n > 1 else ww / 2) + rng.uniform(-2, 2)
            lobes.append((x, y + rng.uniform(-2, 2), r * rng.uniform(0.85, 1.15)))
    return lobes


def coil_tuft(w, h, rng, pal, n, big=3.4, lobes=None):
    """Mata de vello: monton de lobulos sombreado con rizos gordos encima (n rizos)."""
    r2 = random.Random(rng.random())
    nf = max(2, w // 14)
    lb = lobes or mound_lobes(w, h, r2, nf, max(1, nf - 1), 1)
    im = lobe_mound(w, h, lb, pal, r2, 0.12)
    px = im.load()
    for yy in range(h):                         # el cuerpo queda oscuro para que resalten los rizos
        for xx in range(w):
            if px[xx, yy][3]:
                lv = _level(pal, px[xx, yy])
                px[xx, yy] = pal[min(lv, 2) if lv < 3 else 2] if lv >= 0 else px[xx, yy]
    px = im.load()
    placed = []
    tries = 0
    while len(placed) < n and tries < 600:
        tries += 1
        x, y = r2.uniform(3, w - 4), r2.uniform(3, h - 3)
        r = big * r2.uniform(0.8, 1.15)
        if not px[int(x), int(y)][3] or any(math.hypot(x - a, y - b) < (r + rr) * 0.95 for a, b, rr, _, _ in placed):
            continue
        placed.append((x, y, r, r2.uniform(0, 6.3), r2.choice((1, -1))))
    placed.sort(key=lambda o: o[1])
    for x, y, r, rot, fl in placed:
        fat_spiral(im, x, y, r, pal, rot, 1.6, fl, 1)
    return im


def hair(variant):
    """Matas de vello pubico gigante (guiño de la Selva Pubica): pelos individuales gruesos que brotan
    de un monticulo de piel, suben en zigzag rizado y rematan en punta curva. 4 colores."""
    spec = {0: (60, 72, "a", 7), 1: (52, 86, "b", 6), 2: (64, 76, "c", 8), 3: (74, 92, "d", 10)}
    w, h, key, n = spec[variant]
    rng = random.Random(1300 + variant * 17)
    pal = CURLS[key]
    skin = (C("e8b49a"), C("c98a74"), C("9a5c50"))
    im, d = new(w, h)
    px = im.load()
    cx = w // 2
    base_y = h - 7
    def stroke(path, pal3):
        body, shade, hi = pal3
        for (x, y) in path:
            xi, yi = int(round(x)), int(round(y))
            for ox in (0, 1, 2):
                for oy in (0, 1):
                    xx, yy = xi + ox, yi + oy
                    if 0 <= xx < w and 0 <= yy < h:
                        px[xx, yy] = shade if ox == 2 else body
        for (x, y) in path:                                  # brillo: 1 px a lo largo de la hebra
            xx, yy = int(round(x)), int(round(y))
            if 0 <= xx < w and 0 <= yy < h:
                px[xx, yy] = hi

    strands = []
    for i in range(n):
        t = i / (n - 1)
        x0 = cx - 9 + 18 * t + rng.uniform(-1.5, 1.5)
        ang0 = (t - 0.5) * 2.0 * rng.uniform(0.4, 0.7)    # abanico (rad desde la vertical)
        length = rng.uniform(0.5, 0.95) * (base_y - 5)
        if i == n // 2:
            length = base_y - 3
        strands.append((x0, ang0, length, rng.uniform(2.6, 3.6), rng.uniform(7.0, 9.5),
                        rng.uniform(0, 6.28), rng.choice((1, -1)), rng.uniform(0.3, 0.8)))
    strands.sort(key=lambda s: -abs(s[1]))                   # los laterales al fondo
    for k, (x0, ang0, length, amp, period, ph, curl, bend) in enumerate(strands):
        back = k < n // 2
        pal3 = (dk(pal[1], 0.8), pal[0], pal[2]) if back else (pal[1], pal[0], pal[3])
        path = []
        steps = int(length * 3)
        x, y = x0, base_y
        for s_ in range(steps + 1):
            u = s_ / steps
            ang = max(-1.0, min(1.0, ang0 * (1 + 0.5 * u) + bend * 0.5 * u * u * (1 if ang0 >= 0 else -1)))
            x += math.sin(ang) * length / steps
            y -= math.cos(ang) * length / steps
            a = amp * min(1.0, 0.3 + u * 2.5)
            off = a * math.sin(u * length / period * 6.283 + ph)
            xx, yy = x + off * math.cos(ang), y + off * math.sin(ang) * 0.6
            if u > 0.84:                                      # punta: se enrosca en un gancho
                v = (u - 0.84) / 0.16
                th = v * 4.4 * curl
                r = 3.6 * (1 - v * 0.5)
                xx -= curl * r * (1 - math.cos(th))
                yy += -r * math.sin(th) * 0.8 + v * 3
            path.append((xx, yy))
        stroke(path, pal3)
    # monticulo de piel encima de las raices: los pelos brotan de el
    d = ImageDraw.Draw(im)
    d.ellipse((cx - 11, base_y - 1, cx + 11, base_y + 6), fill=skin[1])
    d.ellipse((cx - 10, base_y - 2, cx + 9, base_y + 3), fill=skin[0])
    d.arc((cx - 9, base_y - 2, cx + 7, base_y + 2), 200, 290, fill=lt(skin[0], 0.5))
    d.line((cx - 10, base_y + 5, cx + 10, base_y + 5), fill=skin[2])
    for fx in range(cx - 7, cx + 8, 4):                     # foliculos
        d.point((fx, base_y + (fx % 2)), fill=skin[2])
    return outline(padded(im))


def liana(variant):
    im, d = new(18, 60)
    g = [C("2f5430"), C("4a8a3a"), C("86b84e")]
    pts = [(9 + math.sin(y * 0.17) * 3, y) for y in range(0, 52)]
    for x, y in pts:
        d.rectangle((x - 1, y, x, y), fill=g[0])
        im.putpixel((int(x) - 1, y), g[1])
    for i, (x, y) in enumerate(pts[4::7]):
        side = -1 if i % 2 else 1
        d.polygon([(x, y + 4), (x + side * 7, y + 1), (x + side * 8, y + 5), (x + side * 3, y + 8)], fill=g[1])
        d.line((x, y + 4, x + side * 6, y + 4), fill=g[2])
    x, y = pts[-1]
    if variant == 0:
        for dx, dy in ((-2, 0), (2, 1), (0, 3)):
            blob(d, x + dx, y + dy + 2, 2, 2, C("e85a9a"))
        im.putpixel((int(x), int(y) + 4), C("ffd84a"))
    else:
        d.polygon([(x - 4, y), (x + 4, y), (x, y + 7)], fill=g[1])
    return outline(padded(im))


def mushrooms(variant):
    rng = random.Random(90 + variant)
    if variant == 0:
        im, d = new(30, 26)
        specs = [(8, 12, 7, C("d8483c")), (19, 8, 5, C("e8683c")), (24, 17, 4, C("c8283c"))]
        for cx, top, r, col in specs:
            d.rectangle((cx - 1, top + 4, cx + 1, 24), fill=C("f0e4c8"))
            d.pieslice((cx - r, top - r // 2 + 2, cx + r, top + r + 4), 180, 360, fill=col)
            d.rectangle((cx - r, top + 4, cx + r, top + 4), fill=dk(col, 0.7))
            im.putpixel((cx - r // 2, top + 1), C("fff4e0"))
            im.putpixel((cx + 1, top), C("fff4e0"))
    else:
        im, d = new(24, 18)
        for cx, h, r, col in ((6, 8, 4, C("8a6ac8")), (13, 6, 5, C("a888e0")), (19, 10, 3, C("8a6ac8"))):
            d.rectangle((cx - 1, h + 2, cx, 16), fill=C("d8d0e8"))
            d.pieslice((cx - r, h - 2, cx + r, h + r), 180, 360, fill=col)
            im.putpixel((cx, h), C("e8e0ff"))
    for x in range(1, im.width - 1, 3):
        d.line((x, im.height - 2, x + rng.choice((-1, 1)), im.height - 5), fill=C("4a8a3a"))
    return outline(padded(im))


def root():
    im, d = new(48, 24)
    pts = [(x, 12 + math.sin(x * 0.2) * 5 + (x - 24) * 0.05) for x in range(2, 46)]
    for x, y in pts:
        d.rectangle((x, y - 2, x + 1, y + 2), fill=C("7a5530"))
        d.rectangle((x, y - 2, x + 1, y - 1), fill=C("a07a46"))
        d.rectangle((x, y + 2, x + 1, y + 2), fill=C("4a301c"))
    for x0 in (10, 22, 34):
        x, y = pts[x0 - 2]
        d.line((x, y + 2, x - 2, y + 9), fill=C("5e3f26"), width=2)
    d.line((pts[-1][0], pts[-1][1], 47, 20), fill=C("5e3f26"), width=2)
    for p in ((12, 6), (30, 8), (40, 17)):
        d.rectangle((p[0], p[1], p[0] + 2, p[1] + 1), fill=C("4a7a3a"))
    return outline(padded(im))


def ladilla(frame):
    im, d = new(14, 11)
    leg = C("5e3f26")
    sh = frame % 2
    for i, y in enumerate((3, 5, 7)):
        o = sh if i % 2 == 0 else 1 - sh
        d.line((4, y, 1 - o, y + 1), fill=leg)
        d.line((9, y, 12 + o, y + 1), fill=leg)
    if frame == 2:
        d.line((3, 2, 1, 0), fill=C("c8883c"))
        d.line((10, 2, 12, 0), fill=C("c8883c"))
    blob(d, 7, 5, 3, 3, C("c8a070"))
    d.rectangle((5, 3, 6, 4), fill=C("e4c898"))
    im.putpixel((5, 7), C("8a603a"))
    im.putpixel((8, 7), C("8a603a"))
    im.putpixel((6, 2), OL)
    im.putpixel((8, 2), OL)
    return outline(padded(im))


# ------------------------------------------------------------------ Penelandia
TERRA = (C("e08a50"), C("c2683c"), C("8a4426"), C("3a1c14"))


def amphora(variant):
    im, d = new(24, 38) if variant == 0 else new(22, 30)
    t, m, dd, bl = TERRA
    if variant == 0:
        d.ellipse((4, 12, 19, 35), fill=m)
        d.rectangle((9, 6, 14, 14), fill=m)
        d.rectangle((7, 3, 16, 6), fill=m)
        d.ellipse((7, 34, 16, 37), fill=m)
        d.arc((0, 7, 8, 24), 90, 270, fill=m)
        d.arc((1, 7, 8, 24), 90, 270, fill=m)
        d.arc((15, 7, 23, 24), 270, 90, fill=m)
        d.arc((16, 7, 23, 24), 270, 90, fill=m)
    else:
        d.ellipse((3, 8, 18, 28), fill=m)
        d.rectangle((7, 3, 14, 10), fill=m)
        d.rectangle((6, 1, 15, 3), fill=m)
        d.arc((0, 5, 7, 18), 90, 270, fill=m)
        d.arc((14, 5, 21, 18), 270, 90, fill=m)
    cyl(im, 1.0)
    y0 = 18 if variant == 0 else 14
    for x in range(5, im.width - 5):
        if (x // 2) % 2 == 0:
            im.putpixel((x, y0), bl)
        im.putpixel((x, y0 + 4), bl)
    for x in range(6, im.width - 6, 3):
        im.putpixel((x, y0 + 2), bl)
        im.putpixel((x + 1, y0 + 1), bl)
    if variant == 1:  # rota: mordida en el borde
        d.polygon([(6, 1), (10, 1), (8, 5)], fill=CLEAR)
        d.line((11, 14, 9, 18), fill=bl)
    return outline(padded(im))


def amphora_fallen():
    a = amphora(0)
    inner = a.crop((1, 1, a.width - 1, a.height - 1))
    r = inner.transpose(Image.ROTATE_270)
    r = r.transpose(Image.FLIP_LEFT_RIGHT)
    d = ImageDraw.Draw(r)
    d.ellipse((r.width - 8, r.height - 7, r.width - 1, r.height - 3), fill=C("8a2a40"))
    return outline(padded(r))


def ionic_capital(w=34, h=18):
    L, M, D = STONE["pene"]
    im, d = new(w, h)
    d.rectangle((5, 3, w - 6, h - 5), fill=M)
    d.rectangle((3, 0, w - 4, 3), fill=L)
    d.rectangle((6, h - 5, w - 7, h - 1), fill=D)
    for cx in (5, w - 6):
        d.ellipse((cx - 5, 3, cx + 5, 13), fill=L)
        d.ellipse((cx - 3, 5, cx + 3, 11), fill=M)
        d.ellipse((cx - 1, 7, cx + 1, 9), fill=D)
    return im


def column_broken():
    L, M, D = STONE["pene"]
    im, d = new(34, 50)
    d.rectangle((3, 42, 30, 49), fill=M)
    d.rectangle((1, 46, 32, 49), fill=D)
    d.rectangle((3, 42, 30, 43), fill=L)
    d.polygon([(7, 42), (26, 42), (26, 14), (23, 18), (20, 12), (16, 20), (12, 15), (7, 21)], fill=M)
    cyl(im, 1.0)
    for x in (10, 14, 18, 22):
        d.line((x, 24, x, 41), fill=D)
    d.line((16, 20, 18, 26), fill=D)
    d.line((12, 15, 13, 18), fill=D)
    for p in ((6, 40), (27, 38)):
        d.rectangle((p[0], p[1], p[0] + 2, p[1] + 2), fill=LEAF[1])
    return outline(padded(im))


def column_fallen():
    L, M, D = STONE["pene"]
    im, d = new(70, 22)
    d.rectangle((2, 3, 36, 18), fill=M)
    for y in (6, 9, 12, 15):
        d.line((3, y, 35, y), fill=L if y == 6 else D)
    d.rectangle((2, 3, 3, 18), fill=L)
    im.alpha_composite(ionic_capital(), (36, 2))
    return outline(padded(im))


def shield():
    im, d = new(32, 32)
    br = (C("f0d070"), C("c8a040"), C("8a6a24"))
    d.ellipse((2, 2, 29, 29), fill=br[1])
    d.ellipse((4, 4, 27, 27), fill=C("2c4a88"))
    d.ellipse((7, 7, 24, 24), fill=C("4a78c0"))
    for a in range(0, 360, 20):
        x = 15.5 + math.cos(math.radians(a)) * 10.5
        y = 15.5 + math.sin(math.radians(a)) * 10.5
        im.putpixel((int(x), int(y)), C("f4f2ea"))
    d.polygon([(15, 9), (19, 15), (15, 22), (11, 15)], fill=br[0])
    d.ellipse((12, 12, 19, 19), fill=br[1])
    d.ellipse((14, 14, 17, 17), fill=br[0])
    d.arc((2, 2, 29, 29), 200, 290, fill=br[0], width=2)
    d.arc((2, 2, 29, 29), 20, 110, fill=br[2], width=2)
    im = im.rotate(-12, resample=Image.NEAREST, expand=True)
    return outline(padded(im))


def helmet():
    im, d = new(26, 26)
    b = (C("f0d070"), C("c8a040"), C("8a6a24"))
    d.pieslice((3, 3, 23, 25), 180, 360, fill=b[1])
    d.rectangle((3, 14, 22, 24), fill=b[1])
    d.rectangle((6, 17, 9, 24), fill=CLEAR)
    d.rectangle((16, 17, 19, 24), fill=CLEAR)
    d.rectangle((6, 14, 19, 16), fill=b[2])
    d.rectangle((6, 16, 9, 18), fill=OL)
    d.rectangle((16, 16, 19, 18), fill=OL)
    cyl(im, 0.9)
    d.arc((7, 3, 18, 16), 200, 340, fill=b[0])
    d.pieslice((5, 0, 20, 7), 180, 360, fill=C("c8283c"))
    d.rectangle((5, 3, 20, 4), fill=C("a01c2c"))
    return outline(padded(im))


# ------------------------------------------------------------------ Vulvania
def flowers_pot():
    im, d = new(26, 34)
    d.polygon([(6, 22), (20, 22), (18, 32), (8, 32)], fill=C("e4829c"))
    d.rectangle((5, 20, 21, 23), fill=C("f2a8bc"))
    cyl(im, 0.9)
    for x, top, col in ((8, 6, C("ff5fa8")), (14, 3, C("ffd84a")), (19, 8, C("ff8aa0"))):
        d.line((x, top + 4, x, 20), fill=C("4a9a38"))
        for dx, dy in ((-3, 0), (3, 0), (0, -3), (0, 3), (-2, -2), (2, 2), (2, -2), (-2, 2)):
            blob(d, x + dx, top + dy, 1, 1, col)
        blob(d, x, top, 1, 1, C("c86a2c") if col == C("ffd84a") else C("fff0b0"))
    d.polygon([(10, 20), (4, 16), (9, 17)], fill=C("4a9a38"))
    d.polygon([(16, 20), (22, 15), (17, 17)], fill=C("6aa66a"))
    return outline(padded(im))


def flowers_bed():
    rng = random.Random(8)
    im, d = new(44, 20)
    for x in range(4, 40, 4):
        d.polygon([(x, 18), (x + 4, 8 + rng.randint(0, 3)), (x + 8, 18)], fill=rng.choice([C("4a9a38"), C("6aa66a"), C("3a7a30")]))
    for x, y, c in ((8, 8, C("ff5fa8")), (16, 11, C("ffd84a")), (24, 7, C("ff8aa0")), (31, 10, C("ff5fa8")), (37, 13, C("fff0f4"))):
        d.rectangle((x - 1, y - 1, x + 1, y + 1), fill=c)
        im.putpixel((x, y), C("fff0b0"))
        for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
            im.putpixel((x + dx, y + dy), c)
    return outline(padded(im))


def heart_shape(d, cx, cy, r, col):
    d.ellipse((cx - r * 2, cy - r, cx, cy + r), fill=col)
    d.ellipse((cx, cy - r, cx + r * 2, cy + r), fill=col)
    d.polygon([(cx - r * 2, cy + 1), (cx + r * 2, cy + 1), (cx, cy + r * 2 + 3)], fill=col)


def heart_float():
    im, d = new(16, 15)
    heart_shape(d, 8, 5, 3, C("e8386c"))
    d.rectangle((4, 3, 5, 4), fill=C("ff9ab8"))
    return outline(padded(im))


def heart_topiary():
    im, d = new(34, 40)
    d.polygon([(10, 38), (24, 38), (22, 30), (12, 30)], fill=C("f2c0cc"))
    d.rectangle((9, 28, 25, 31), fill=C("ffe2e6"))
    d.rectangle((15, 24, 18, 29), fill=C("5e3a20"))
    heart_shape(d, 17, 12, 7, C("3f7a40"))
    cyl(im, 0.8)
    rng = random.Random(3)
    for _ in range(14):
        x, y = rng.randint(6, 28), rng.randint(5, 20)
        if im.getpixel((x, y))[3]:
            im.putpixel((x, y), C("78c04a"))
    for p in ((10, 9), (22, 11), (16, 17)):
        im.putpixel(p, C("ff5fa8"))
    return outline(padded(im))


def curtain():
    im, d = new(34, 48)
    wine = (C("d8587c"), C("a8325c"), C("7a2044"))
    d.rectangle((1, 1, 32, 3), fill=C("c8a040"))
    blob(d, 2, 2, 2, 2, C("f0d070"))
    blob(d, 31, 2, 2, 2, C("f0d070"))
    d.rectangle((15, 4, 18, 44), fill=C("5a2a4a"))
    for side in (0, 1):
        x0 = 3 if side == 0 else 18
        d.polygon([(x0, 4), (x0 + 12, 4), (x0 + 12, 44), (x0 + 6, 46), (x0, 44)], fill=wine[1])
        for k in range(1, 12, 3):
            d.line((x0 + k, 5, x0 + k + (1 if side == 0 else -1), 44), fill=wine[0] if k % 2 else wine[2])
    d.rectangle((2, 21, 31, 23), fill=C("f0d070"))
    d.line((16, 24, 16, 30), fill=C("c8a040"))
    d.rectangle((15, 30, 17, 33), fill=C("f0d070"))
    return outline(padded(im))


def vase(variant):
    if variant == 0:
        im, d = new(24, 32)
        d.ellipse((3, 8, 20, 30), fill=C("f6c6d4"))
        d.rectangle((9, 3, 14, 10), fill=C("f6c6d4"))
        d.rectangle((7, 1, 16, 3), fill=C("ffe2e6"))
        d.ellipse((8, 28, 15, 31), fill=C("f6c6d4"))
        cyl(im, 1.0)
        d.rectangle((5, 15, 18, 16), fill=C("f0d070"))
        d.rectangle((6, 22, 17, 22), fill=C("f0d070"))
        for x in range(7, 17, 3):
            im.putpixel((x, 19), C("e85a8a"))
            im.putpixel((x + 1, 18), C("e85a8a"))
    else:
        im, d = new(22, 26)
        d.ellipse((2, 4, 19, 25), fill=C("e48aa8"))
        d.rectangle((7, 1, 14, 6), fill=C("e48aa8"))
        cyl(im, 1.0)
        heart_shape(d, 10, 12, 3, C("fff0f4"))
        d.rectangle((6, 0, 15, 1), fill=C("f6b0c2"))
    return outline(padded(im))


# ------------------------------------------------------------------ Perineo
def booth():
    im, d = new(46, 60)
    gray = (C("a0a8c0"), C("7e869e"), C("5a6078"))
    d.rectangle((6, 22, 39, 58), fill=gray[1])
    d.rectangle((6, 22, 9, 58), fill=gray[0])
    d.rectangle((36, 22, 39, 58), fill=gray[2])
    d.rectangle((11, 28, 34, 44), fill=C("8ec4ee"))
    d.polygon([(11, 28), (22, 28), (14, 44), (11, 44)], fill=C("c8e4fa"))
    d.rectangle((11, 28, 34, 29), fill=gray[2])
    d.rectangle((11, 44, 34, 47), fill=gray[2])
    d.rectangle((15, 48, 30, 58), fill=gray[2])
    d.polygon([(2, 22), (43, 22), (40, 10), (5, 10)], fill=C("d8483c"))
    for x in range(5, 42, 8):
        d.polygon([(x, 22), (x + 4, 22), (x + 3, 10), (x - 1, 10)], fill=C("f4f2ea"))
    d.rectangle((2, 22, 43, 24), fill=gray[2])
    d.rectangle((22, 1, 23, 10), fill=C("343c4c"))
    d.polygon([(24, 1), (32, 3), (24, 6)], fill=C("f4c42c"))
    blob(d, 24, 36, 3, 3, C("e4b890"))
    d.rectangle((20, 30, 28, 32), fill=C("343c4c"))
    d.rectangle((21, 39, 27, 44), fill=C("343c4c"))
    return outline(padded(im))


def fence():
    im, d = new(42, 26)
    y, k = C("f4c42c"), C("1c1c22")
    for x in (2, 36):
        d.rectangle((x, 4, x + 3, 24), fill=C("7e869e"))
        d.rectangle((x, 4, x + 1, 24), fill=C("a0a8c0"))
    for y0 in (7, 15):
        d.rectangle((2, y0, 39, y0 + 5), fill=y)
        for x in range(3, 39, 8):
            d.polygon([(x, y0 + 5), (x + 4, y0 + 5), (x + 7, y0), (x + 3, y0)], fill=k)
        d.rectangle((2, y0, 39, y0), fill=C("fbe27a"))
    return outline(padded(im))


def cone():
    im, d = new(16, 18)
    d.rectangle((2, 14, 13, 16), fill=C("30344a"))
    d.polygon([(8, 1), (12, 14), (4, 14)], fill=C("f08030"))
    d.polygon([(7, 6), (9, 6), (10, 9), (6, 9)], fill=C("f4f2ea"))
    d.line((6, 2, 4, 13), fill=C("ffb060"))
    d.rectangle((9, 11, 11, 13), fill=C("d05a1c"))
    return outline(padded(im))


def sign_stop():
    im, d = new(26, 46)
    d.rectangle((12, 20, 14, 44), fill=C("7e869e"))
    d.rectangle((12, 20, 12, 44), fill=C("a0a8c0"))
    d.polygon([(7, 1), (18, 1), (24, 7), (24, 14), (18, 20), (7, 20), (1, 14), (1, 7)], fill=C("f4f2ea"))
    d.polygon([(8, 3), (17, 3), (22, 8), (22, 13), (17, 18), (8, 18), (3, 13), (3, 8)], fill=C("d8283c"))
    text(im, 5, 8, "STOP", C("fff8f0"))
    return outline(padded(im))


def sign_no(lang):
    im, d = new(44, 40)
    a, b = ("PROHIBIDO", "PASAR") if lang == "es" else ("NO", "ENTRY")
    for x in (6, 36):
        d.rectangle((x, 24, x + 2, 38), fill=C("7e869e"))
    d.rectangle((1, 1, 42, 26), fill=C("f4c42c"))
    d.rectangle((3, 3, 40, 24), fill=C("1c1c22"))
    d.rectangle((4, 4, 39, 23), fill=C("f4c42c"))
    text(im, 22 - text_w(a) // 2, 6, a, C("1c1c22"))
    text(im, 22 - text_w(b) // 2, 14, b, C("d8283c"))
    return outline(padded(im))


def sign_icon():
    im, d = new(30, 46)
    d.rectangle((14, 24, 16, 44), fill=C("7e869e"))
    d.ellipse((2, 2, 27, 27), fill=C("f4f2ea"))
    d.ellipse((4, 4, 25, 25), fill=C("d8283c"))
    d.ellipse((8, 8, 21, 21), fill=C("f4f2ea"))
    blob(d, 14, 11, 1, 1, C("1c1c22"))
    d.rectangle((13, 13, 15, 17), fill=C("1c1c22"))
    d.line((8, 21, 21, 8), fill=C("d8283c"), width=3)
    return outline(padded(im))


# ------------------------------------------------------------------ Palacio
def stamp(lang):
    word = "CENSURADO" if lang == "es" else "CENSORED"
    w = text_w(word) + 10
    im, d = new(w, 18)
    red = C("c8283c", 215)
    d.rectangle((0, 0, w - 1, 17), outline=red)
    d.rectangle((2, 2, w - 3, 15), outline=red)
    text(im, 5, 6, word, red)
    rng = random.Random(77)
    for _ in range(int(w * 18 * 0.04)):
        im.putpixel((rng.randrange(w), rng.randrange(18)), CLEAR)
    return im.rotate(4, resample=Image.NEAREST, expand=True)


def bar(w, variant):
    im, d = new(w + 4, 14)
    ink = C("17151c", 238)
    d.rectangle((2, 3, w + 1, 8), fill=ink)
    d.polygon([(0, 4), (2, 3), (2, 8), (0, 7)], fill=ink)
    d.polygon([(w + 1, 3), (w + 3, 4), (w + 3, 6), (w + 1, 8)], fill=ink)
    rng = random.Random(w + variant)
    for _ in range(3):
        x = rng.randint(4, w - 2)
        d.line((x, 8, x, 8 + rng.randint(2, 5)), fill=ink)
    for _ in range(4):
        im.putpixel((rng.randint(3, w), rng.randint(3, 8)), C("3a3646", 238))
    return im


def carpet_flat(w=68):
    im, d = new(w, 24)
    red = (C("e0485c"), C("b02848"), C("7a1830"))
    gold = C("e0b84c")
    d.rectangle((0, 4, w - 1, 19), fill=red[1])
    d.rectangle((0, 4, w - 1, 5), fill=red[0])
    d.rectangle((0, 18, w - 1, 19), fill=red[2])
    d.rectangle((0, 8, w - 1, 8), fill=gold)
    d.rectangle((0, 15, w - 1, 15), fill=gold)
    for x in range(6, w - 4, 8):
        d.polygon([(x, 11), (x + 2, 9), (x + 4, 11), (x + 2, 13)], fill=gold)
    for x in range(0, w, 3):
        d.line((x, 20, x, 22), fill=C("f0d070"))
    return outline(padded(im))


def carpet_roll():
    im, d = new(34, 24)
    red = (C("e0485c"), C("b02848"), C("7a1830"))
    d.rectangle((3, 4, 30, 19), fill=red[1])
    d.rectangle((3, 4, 30, 6), fill=red[0])
    d.ellipse((0, 4, 8, 19), fill=red[2])
    d.ellipse((2, 6, 6, 17), fill=C("f0d070"))
    d.ellipse((3, 8, 5, 15), fill=red[1])
    d.rectangle((14, 4, 16, 19), fill=C("e0b84c"))
    d.rectangle((22, 4, 24, 19), fill=C("e0b84c"))
    d.line((30, 8, 33, 8), fill=red[1])
    return outline(padded(im))


def grape_leaf(d, cx, cy, r, col, hi):
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        rr = r if i % 2 == 0 else r * 0.55
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=col)
    d.line((cx, cy + r * 0.2, cx, cy - r * 0.9), fill=hi)
    d.line((cx, cy, cx - r * 0.7, cy - r * 0.3), fill=hi)
    d.line((cx, cy, cx + r * 0.7, cy - r * 0.3), fill=hi)


def leaf_plant():
    im, d = new(30, 38)
    L, M, D = STONE["censura"]
    d.polygon([(7, 26), (23, 26), (21, 36), (9, 36)], fill=M)
    d.rectangle((6, 24, 24, 27), fill=L)
    cyl(im, 0.9)
    d.line((15, 25, 15, 14), fill=LEAF[2])
    d.line((15, 22, 7, 12), fill=LEAF[2])
    d.line((15, 22, 23, 13), fill=LEAF[2])
    grape_leaf(d, 15, 8, 8, LEAF[1], LEAF[0])
    grape_leaf(d, 6, 14, 6, LEAF[0], LEAF[2])
    grape_leaf(d, 24, 14, 6, LEAF[1], LEAF[0])
    blob(d, 12, 20, 2, 2, C("8a64d8"))
    blob(d, 18, 21, 2, 2, C("6a44b8"))
    return outline(padded(im))


def leaf_pile():
    im, d = new(30, 18)
    grape_leaf(d, 8, 9, 7, LEAF[1], LEAF[0])
    grape_leaf(d, 20, 8, 6, LEAF[0], LEAF[2])
    grape_leaf(d, 14, 12, 5, LEAF[2], LEAF[1])
    return outline(padded(im))


# ------------------------------------------------------------------ guiños (etapa 7)
# Doble sentido de fondo, con humor de dibujo animado: nada protagonista, todo con excusa clasica
# (herma griega, orquidea, cartel de carretera, mosaico de censura).
PETAL = (C("b8386c"), C("e0689a"), C("f490b8"), C("ffc0d6"))


def fold_flower(scale=1.0):
    """Flor-pliegue (orquidea a lo O'Keeffe): dos petalos grandes que se cierran sobre un surco central
    con un capullito arriba. Sin contorno, 22x22."""
    im, d = new(22, 22)
    d.ellipse((1, 4, 12, 21), fill=PETAL[1])          # petalo izquierdo
    d.ellipse((9, 4, 20, 21), fill=PETAL[1])          # petalo derecho
    d.ellipse((3, 6, 11, 19), fill=PETAL[2])          # cara interior clara
    d.ellipse((10, 6, 18, 19), fill=PETAL[2])
    d.ellipse((6, 9, 9, 17), fill=PETAL[3])            # brillo arriba-izquierda
    d.rectangle((10, 8, 11, 20), fill=PETAL[0])        # el surco
    d.line((10, 20, 11, 20), fill=dk(PETAL[0], 0.7))
    d.line((9, 12, 9, 15), fill=PETAL[0])              # pliegues que bajan hacia el surco
    d.line((12, 12, 12, 15), fill=PETAL[0])
    d.line((1, 14, 2, 18), fill=PETAL[0])
    d.line((20, 14, 19, 18), fill=PETAL[0])
    d.ellipse((8, 1, 13, 7), fill=PETAL[2])            # capullito
    d.rectangle((9, 2, 9, 3), fill=PETAL[3])
    d.line((10, 7, 11, 7), fill=PETAL[0])
    if scale != 1.0:
        im = im.resize((int(22 * scale), int(22 * scale)), Image.NEAREST)
    return im


def orchid_pot():
    """Maceta con una flor-pliegue grande y un capullo."""
    im, d = new(30, 48)
    d.polygon([(8, 34), (22, 34), (20, 46), (10, 46)], fill=C("e4829c"))
    d.rectangle((6, 32, 24, 35), fill=C("f2a8bc"))
    cyl(im, 0.9)
    d.line((15, 22, 15, 33), fill=C("3a7a30"), width=2)
    d.polygon([(15, 31), (5, 24), (11, 31)], fill=C("4a9a38"))
    d.polygon([(16, 30), (26, 23), (20, 30)], fill=C("6aa66a"))
    d.line((7, 26, 11, 30), fill=C("78c04a"))
    im.alpha_composite(fold_flower(), (4, 8))
    return outline(padded(im))


def orchid_bed():
    """Cama de hierba con tres flores-pliegue de distinto tamaño."""
    rng = random.Random(77)
    im, d = new(52, 28)
    for x in range(2, 48, 4):
        d.polygon([(x, 26), (x + 4, 15 + rng.randint(0, 4)), (x + 8, 26)], fill=rng.choice([C("4a9a38"), C("6aa66a"), C("3a7a30")]))
    for x, y, sc in ((3, 3, 0.8), (17, 0, 1.0), (35, 5, 0.7)):
        f = fold_flower(sc)
        d.line((x + f.width // 2, y + f.height - 3, x + f.width // 2, 24), fill=C("3a7a30"), width=2)
        im.alpha_composite(f, (x, y))
    return outline(padded(im))


def herma():
    """Herma griega: pilar con cabeza barbada arriba y, como manda la tradicion, su atributo al frente."""
    L, M, D = STONE["pene"]
    im, d = new(30, 58)
    d.rectangle((3, 52, 26, 57), fill=M)
    d.rectangle((3, 52, 26, 53), fill=L)
    d.rectangle((3, 56, 26, 57), fill=D)
    d.polygon([(8, 22), (21, 22), (23, 52), (6, 52)], fill=M)
    d.rectangle((4, 27, 8, 32), fill=M)                 # munones de los brazos
    d.rectangle((21, 27, 25, 32), fill=M)
    blob(d, 14, 11, 7, 9, M)                            # cabeza
    d.polygon([(8, 14), (21, 14), (19, 24), (14, 27), (10, 24)], fill=D)  # barba rizada
    d.rectangle((7, 3, 21, 6), fill=D)                  # cinta del pelo
    cyl(im, 0.9)
    d.line((9, 26, 9, 50), fill=D)                      # pliegues del pilar
    d.line((20, 26, 21, 50), fill=D)
    for p in ((11, 10), (17, 10)):
        d.rectangle((p[0], p[1], p[0] + 1, p[1]), fill=OL)
    d.line((14, 11, 14, 14), fill=D)
    for x in (11, 13, 15, 17):                          # rizos de la barba
        im.putpixel((x, 19), M)
        im.putpixel((x + 1, 21), M)
    # el atributo: fuste con glande, y los dos huevos clasicos en la base
    d.ellipse((7, 42, 14, 50), fill=L, outline=D)         # los dos huevos clasicos
    d.ellipse((15, 42, 22, 50), fill=L, outline=D)
    d.rectangle((12, 35, 17, 46), fill=L, outline=D)      # fuste
    d.ellipse((11, 29, 18, 37), fill=L, outline=D)        # glande
    d.line((12, 37, 17, 37), fill=D)                      # corona
    d.line((13, 31, 14, 30), fill=C("ffffff"))
    d.rectangle((15, 38, 16, 45), fill=M)
    return outline(padded(im))


def column_glans():
    """Columna jonica entera con capitel en forma de bellota (muy bien disimulado) y basa con dos bolas."""
    L, M, D = STONE["pene"]
    im, d = new(26, 60)
    d.rectangle((6, 14, 19, 51), fill=M)
    d.rectangle((3, 50, 22, 54), fill=M)                # basa
    d.rectangle((4, 54, 21, 59), fill=D)
    d.rectangle((3, 54, 22, 55), fill=M)
    d.rectangle((5, 12, 20, 15), fill=D)                 # corona (reborde)
    d.ellipse((4, 1, 21, 18), fill=L)                    # el capitel: cupula redondeada
    d.rectangle((4, 12, 21, 14), fill=M)
    cyl(im, 1.0)
    d.rectangle((4, 13, 21, 14), fill=D)
    d.line((12, 4, 12, 8), fill=D)                       # hendidura de la punta
    d.line((13, 4, 13, 7), fill=D)
    d.arc((4, 1, 21, 18), 200, 260, fill=C("ffffff"))
    for x in (9, 12, 15):                                # estrias
        d.line((x, 17, x, 49), fill=D)
    for k in range(0, 30, 3):                            # hiedra que sube enroscada por el fuste
        x = 12 + int(math.sin(k * 0.5) * 6)
        d.rectangle((x, 46 - k, x + 1, 46 - k), fill=LEAF[1])
        if k % 6 == 0:
            d.polygon([(x, 46 - k), (x + 3, 44 - k), (x + 2, 47 - k)], fill=LEAF[0])
    return outline(padded(im))


def sign_hills():
    """Cartel de carretera 'Dos colinas, camino estrecho': pictograma de dos lomas con una raya en medio."""
    im, d = new(30, 48)
    d.rectangle((14, 26, 16, 46), fill=C("7e869e"))
    d.polygon([(15, 0), (29, 14), (15, 28), (1, 14)], fill=C("1c1c22"))
    d.polygon([(15, 3), (26, 14), (15, 25), (4, 14)], fill=C("f0c830"))
    d.pieslice((6, 9, 15, 27), 180, 360, fill=C("1c1c22"))   # dos lomas redondas
    d.pieslice((15, 9, 24, 27), 180, 360, fill=C("1c1c22"))
    d.rectangle((15, 10, 15, 17), fill=C("f0c830"))          # con su raya en medio
    d.rectangle((6, 18, 24, 19), fill=C("f0c830"))
    d.rectangle((9, 12, 10, 12), fill=C("8a7a30"))
    d.rectangle((18, 12, 19, 12), fill=C("8a7a30"))
    return outline(padded(im))


# ------------------------------------------------------------------ salida
def main():
    save(web(0), "web_a")
    save(web(1), "web_b")
    save(bones(0), "bones_a")
    save(bones(1), "bones_b")
    for i in range(4):
        save(hero(i), f"hero_{i}")
    for k in STONE:
        for sx in ("m", "f"):
            save(statue(k, sx), f"statue_{k}_{sx}")
    for i, k in enumerate("abcd"):
        save(bush(i), f"neutral_bush_{k}")
        save(hair(i), f"neutral_hair_{k}")
    save(bosom_bush(), "neutral_bush_e")
    save(liana(0), "neutral_liana_a")
    save(liana(1), "neutral_liana_b")
    save(mushrooms(0), "neutral_mushroom_a")
    save(mushrooms(1), "neutral_mushroom_b")
    save(root(), "neutral_root")
    for f in range(3):
        save(ladilla(f), f"neutral_ladilla_{f}")
    save(amphora(0), "pene_amphora_a")
    save(amphora(1), "pene_amphora_b")
    save(amphora_fallen(), "pene_amphora_fallen")
    save(column_broken(), "pene_column_broken")
    save(column_fallen(), "pene_column_fallen")
    save(shield(), "pene_shield")
    save(helmet(), "pene_helmet")
    save(flowers_pot(), "vulva_flowers_pot")
    save(flowers_bed(), "vulva_flowers_bed")
    save(heart_float(), "vulva_heart_float")
    save(heart_topiary(), "vulva_heart_topiary")
    save(curtain(), "vulva_curtain")
    save(vase(0), "vulva_vase_a")
    save(vase(1), "vulva_vase_b")
    save(booth(), "mixto_booth")
    save(fence(), "mixto_fence")
    save(cone(), "mixto_cone")
    save(sign_stop(), "mixto_sign_stop")
    save(sign_no("es"), "mixto_sign_no_es")
    save(sign_no("en"), "mixto_sign_no_en")
    save(sign_icon(), "mixto_sign_icon")
    save(stamp("es"), "censura_stamp_es")
    save(stamp("en"), "censura_stamp_en")
    save(bar(52, 0), "censura_bar_a")
    save(bar(34, 1), "censura_bar_b")
    save(carpet_flat(), "censura_carpet_flat")
    save(carpet_roll(), "censura_carpet_roll")
    save(leaf_plant(), "censura_leaf_plant")
    save(leaf_pile(), "censura_leaf_pile")
    # guiños de la etapa 7
    save(herma(), "pene_herma")
    save(column_glans(), "pene_column_glans")
    save(orchid_pot(), "vulva_orchid_pot")
    save(orchid_bed(), "vulva_orchid_bed")
    save(sign_hills(), "mixto_sign_hills")
    save(statue("censura", "m", True), "statue_censura_mosaic_m")
    save(statue("censura", "f", True), "statue_censura_mosaic_f")


if __name__ == "__main__":
    main()
