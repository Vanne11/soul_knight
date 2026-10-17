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
def statue(k, sex):
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
    d.polygon(leaf, fill=LEAF[1])
    d.line((18, leaf[0][1], 18, leaf[-2][1] + 2), fill=LEAF[2])
    d.line((14, leaf[0][1], 17, leaf[0][1] + 3), fill=LEAF[0])
    im.putpixel((22, leaf[0][1] + 1), LEAF[0])
    if k == "neutral":  # musgo
        for p in ((12, 20), (13, 21), (24, 40), (6, 50), (28, 50), (9, 48)):
            d.rectangle((p[0], p[1], p[0] + 2, p[1] + 1), fill=C("4a7a3a"))
    return outline(padded(im))


# ------------------------------------------------------------------ Selva
def bush(variant):
    rng = random.Random(40 + variant)
    im, d = new(66, 62)
    base = [(C("2f5430"), C("3f6e38"), C("5a8c40"), C("86b84e")), (C("33472a"), C("4a6a30"), C("6c8c3a"), C("98b84c"))][variant]
    for layer, col in enumerate(base):
        for _ in range(26 - layer * 4):
            cx = rng.randint(14, 52)
            cy = rng.randint(22 - layer * 4, 54 - layer * 8)
            r = rng.randint(8, 13) - layer
            blob(d, cx, cy, r, int(r * 0.9), col)
    for _ in range(14):
        x = rng.randint(10, 56)
        y = rng.randint(14, 30)
        d.polygon([(x, y), (x + rng.randint(-4, 4), y - rng.randint(8, 16)), (x + 3, y + 2)], fill=rng.choice(base[1:]))
    for _ in range(9):
        x = rng.randint(14, 52)
        y = rng.randint(30, 52)
        d.line((x, y, x + rng.randint(-3, 3), y - rng.randint(5, 10)), fill=C("5a3a1e"))
    if variant == 1:
        for _ in range(7):
            blob(d, rng.randint(14, 52), rng.randint(26, 50), 2, 2, C("d8483c"))
    d.ellipse((8, 52, 58, 60), fill=dk(base[0], 0.8))
    return outline(padded(im))


def hair(variant):
    rng = random.Random(55 + variant)
    im, d = new(46, 68)
    cols = [C("4a2a14"), C("6a3c1c"), C("8a5224"), C("b07a3c")] if variant == 0 else [C("3a1c1c"), C("5a2a24"), C("7a3c30"), C("a0604c")]
    blob(d, 23, 62, 18, 5, cols[0])
    for s in range(9):
        x0 = 10 + s * 3.2 + rng.uniform(-1, 1)
        h = rng.randint(34, 62)
        amp = rng.uniform(2.5, 6)
        ph = rng.uniform(0, 6)
        freq = rng.uniform(0.12, 0.2)
        pts = []
        for t in range(0, h, 1):
            y = 62 - t
            x = x0 + math.sin(t * freq + ph) * amp * (0.4 + t / h) + (t / h) * (x0 - 23) * 0.5
            pts.append((x, y))
        col = cols[1 + s % 3]
        for (x, y) in pts:
            d.rectangle((x - 1, y, x + 1, y), fill=col)
        x, y = pts[-1]
        for a in range(0, 300, 25):
            rr = 4 - a / 90
            px = x + math.cos(math.radians(a)) * rr
            py = y + math.sin(math.radians(a)) * rr
            d.rectangle((px - 1, py - 1, px, py), fill=col)
        d.line([p for p in pts[::4]], fill=cols[3])
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
    save(bush(0), "neutral_bush_a")
    save(bush(1), "neutral_bush_b")
    save(hair(0), "neutral_hair_a")
    save(hair(1), "neutral_hair_b")
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


if __name__ == "__main__":
    main()
