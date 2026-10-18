"""Genera el arte de los muros por reino (assets/sprites/environment/walls/<reino>/)
y los TileSets assets/tilesets/walls_<reino>.tres.

Uso: python3 tools/gen_wall_art.py [reino ...]   (sin args = los cinco)
Reinos: neutral (Selva), pene (Penelandia), vulva (Vulvania), mixto (Perineo), censura (Palacio).

Arte pixel a 1x (1 px de arte = 1 px de mundo, como los personajes). Piezas por reino:
  atlas.png      256x64: baldosas de 64x64 (0 tapa, 1 cara frontal, 2 tapa b, 3 cara b)
  zocalo_top / zocalo_side / zocalo_bottom   zocalo al pie de cada muro
  pilaster.png   esquina interna (arista de la cara frontal)
  column.png     columna de esquina (esquina externa)
  frame.png      marco de puerta (88x88, hueco de 64x64), step.png umbral/escalon
  loose.png, vines.png, banner.png, painting.png   variantes decorativas
  window.png     ventana/grieta por la que entra luz de color
Las baldosas se pintan con luz arriba-izquierda y contorno oscuro; sin ruido que
parpadee (todo determinista por semilla).
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/environment/walls"
TILESETS = ROOT / "assets/tilesets"
CLEAR = (0, 0, 0, 0)
OL = (13, 11, 15, 255)  # contorno comun del juego


def C(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def dk(c, k):
    return (max(0, min(255, int(c[0] * k))), max(0, min(255, int(c[1] * k))), max(0, min(255, int(c[2] * k))), 255)


def jit(c, rng, amt):
    d = rng.randint(-amt, amt)
    return (max(0, min(255, c[0] + d)), max(0, min(255, c[1] + d)), max(0, min(255, c[2] + d)), 255)


def new(w, h, fill=CLEAR):
    return Image.new("RGBA", (w, h), fill)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def rect(im, x, y, w, h, c):
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            px(im, xx, yy, c)


def hline(im, x, y, w, c):
    for xx in range(x, x + w):
        px(im, xx, y, c)


def vline(im, x, y, h, c):
    for yy in range(y, y + h):
        px(im, x, yy, c)


def outline(im, c=OL):
    """Contorno de 1 px alrededor de lo opaco (en los pixeles transparentes vecinos)."""
    src = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < im.width and 0 <= yy < im.height and src.getpixel((xx, yy))[3] > 0:
                        im.putpixel((x, y), c)
                        break


def blit(dst, src, x, y):
    dst.alpha_composite(src, (x, y))


# ------------------------------------------------------------------ reinos
KINGDOMS = {
    "neutral": {
        "style": "earth",
        "light": C("7fe0a0"),
        "mortar": C("2e2018"), "dark": C("54382a"), "mid": C("78563a"), "lite": C("9a7648"), "hi": C("c09a62"),
        "moss": C("4a7a3a"), "mossd": C("2f5430"), "mossl": C("86b84e"),
        "root": C("a07a46"), "rootd": C("5e3f26"),
    },
    "pene": {
        "style": "marble",
        "light": C("6ec6ff"),
        "mortar": C("8e92aa"), "dark": C("c2c4d2"), "mid": C("e6e4dc"), "lite": C("f4f2ea"), "hi": C("ffffff"),
        "vein": C("a4b0d0"), "gold": C("e0b84c"), "goldd": C("a07a28"), "blue": C("4a78c0"), "blued": C("2c4a88"),
    },
    "vulva": {
        "style": "organic",
        "light": C("ff7ac0"),
        "mortar": C("6e2450"), "dark": C("b8567e"), "mid": C("e48aa8"), "lite": C("f6b0c2"), "hi": C("ffd8de"),
        "deep": C("8e3466"), "petal": C("ff5fa8"), "leaf": C("6aa66a"),
    },
    "mixto": {
        "style": "concrete",
        "light": C("ffc93c"),
        "mortar": C("30344a"), "dark": C("5a6078"), "mid": C("7e869e"), "lite": C("a0a8c0"), "hi": C("c8d0e4"),
        "yellow": C("f4c42c"), "black": C("1c1c22"), "rivet": C("d4dae8"), "red": C("d8483c"),
    },
    "prostata": {
        "style": "concrete",
        "light": C("d8b890"),
        "mortar": C("4a3c3c"), "dark": C("a08a86"), "mid": C("c8b4ae"), "lite": C("dccac4"), "hi": C("efe2dc"),
        "yellow": C("8e6c50"), "black": C("2a2222"), "rivet": C("d8ccc6"), "red": C("b05050"),
    },
    "censura": {
        "style": "white",
        "light": C("b48cff"),
        "mortar": C("a8abc6"), "dark": C("d0d3e6"), "mid": C("eef0fa"), "lite": C("f8f9ff"), "hi": C("ffffff"),
        "black": C("16141c"), "red": C("c8283c"), "violet": C("8a64d8"),
    },
}


# ------------------------------------------------------------------ bloques
def row_widths(rng, style, total=64, n=None):
    if style == "earth":
        ws, rem = [], total
        while rem > 0:
            w = rng.choice([14, 18, 22, 26])
            if rem - w < 12:
                w = rem
            ws.append(w)
            rem -= w
        return ws
    if style == "organic":
        n = n or 3
        base = total // n
        ws = [base] * n
        ws[-1] += total - base * n
        for i in range(n - 1):
            d = rng.randint(-3, 3)
            ws[i] += d
            ws[i + 1] -= d
        return ws
    return [32, 32]


def draw_block(im, x, y, w, h, K, rng, shade=1.0):
    """Un bloque de piedra con biselado (luz arriba-izquierda). Sin mortero (lo pone el fondo)."""
    s = K["style"]
    if s == "earth":
        base = rng.choice([K["dark"], K["mid"], K["mid"], K["lite"]])
    elif s == "organic":
        base = rng.choice([K["mid"], K["mid"], K["dark"], K["lite"]])
    elif s == "marble":
        base = rng.choice([K["mid"], K["mid"], K["lite"], mix(K["mid"], K["dark"], 0.5)])
    elif s == "concrete":
        base = rng.choice([K["mid"], K["mid"], K["dark"]])
    else:
        base = rng.choice([K["mid"], K["mid"], K["lite"]])
    base = dk(jit(base, rng, 4), shade)
    hi = mix(base, K["hi"], 0.55)
    lo = dk(base, 0.78)
    rect(im, x, y, w, h, base)
    hline(im, x, y, w, hi)
    vline(im, x, y, h, mix(base, K["hi"], 0.3))
    hline(im, x, y + h - 1, w, lo)
    vline(im, x + w - 1, y, h, lo)
    if s in ("earth", "organic"):  # esquinas redondeadas
        for cx, cy in ((x, y), (x + w - 1, y), (x, y + h - 1), (x + w - 1, y + h - 1)):
            px(im, cx, cy, K["mortar"])
    if s == "organic":
        px(im, x + 3, y + 2, K["hi"])
        px(im, x + 4, y + 2, K["hi"])
        px(im, x + 3, y + 3, K["lite"])
    # motas
    n = {"earth": 5, "organic": 2, "marble": 1, "concrete": 3, "white": 0}[s]
    for _ in range(n):
        sx, sy = x + rng.randint(2, max(2, w - 3)), y + rng.randint(2, max(2, h - 3))
        px(im, sx, sy, dk(base, rng.choice([0.85, 1.12])))
    if s == "marble" and rng.random() < 0.7:
        vx, vy = x + rng.randint(4, w - 5), y + rng.randint(1, 4)
        for _ in range(rng.randint(8, 16)):
            if vy >= y + h - 2:
                break
            px(im, vx, vy, K["vein"])
            vy += 1
            vx += rng.choice([-1, 0, 1])
            vx = max(x + 1, min(x + w - 2, vx))
    if s == "concrete":
        for rx, ry in ((x + 2, y + 2), (x + w - 4, y + 2), (x + 2, y + h - 4), (x + w - 4, y + h - 4)):
            rect(im, rx, ry, 2, 2, K["rivet"])
            px(im, rx + 1, ry + 1, K["dark"])
            px(im, rx + 2, ry + 2, K["mortar"])


def wrap_block(im, x, y, w, h, K, rng):
    """Dibuja el bloque con la misma semilla en x y x-64 para que la baldosa encaje."""
    st = rng.getstate()
    draw_block(im, x, y, w, h, K, rng)
    if x + w > 64:
        rng.setstate(st)
        draw_block(im, x - 64, y, w, h, K, rng)


def fill_courses(im, y0, y1, rows, K, rng, stagger=True):
    """Llena [y0,y1) de hileras de bloques con mortero de fondo; ancho 64 con envoltura."""
    rect(im, 0, y0, 64, y1 - y0, K["mortar"])
    rh = (y1 - y0) // rows
    for r in range(rows):
        y = y0 + r * rh
        h = rh if r < rows - 1 else (y1 - y)
        ws = row_widths(rng, K["style"], n=3 if K["style"] == "organic" else None)
        off = 0
        if stagger and r % 2 == 1 and K["style"] in ("marble", "concrete", "white"):
            off = 16
        elif stagger and K["style"] in ("earth", "organic"):
            off = rng.randint(0, 20)
        x = off
        for i, w in enumerate(ws):
            wrap_block(im, x % 64, y, w - 1 if x % 64 + w - 1 <= 64 else w - 1, h - 1, K, rng)
            x += w


# ------------------------------------------------------------------ baldosas
def moss_edges(im, K, rng, y_ranges, prob=0.35):
    for (ya, yb) in y_ranges:
        for x in range(64):
            if rng.random() < prob:
                ln = rng.randint(1, 3)
                for k in range(ln):
                    px(im, x, ya + k, rng.choice([K["moss"], K["mossd"], K["mossl"]]))


def roots(im, K, rng, n, y0, y1):
    for _ in range(n):
        x = rng.randint(6, 58)
        y = y0
        ln = rng.randint(14, y1 - y0)
        for k in range(ln):
            px(im, x, y, K["rootd"] if k % 3 == 0 else K["root"])
            px(im, x + 1, y, K["rootd"])
            y += 1
            if rng.random() < 0.3:
                x += rng.choice([-1, 1])
            x = max(2, min(61, x))


def meander(im, K, y, h=8):
    """Greca griega: banda azul con la clave dorada."""
    rect(im, 0, y, 64, h, K["blued"])
    hline(im, 0, y, 64, K["blue"])
    hline(im, 0, y + h - 1, 64, K["mortar"])
    pat = [
        "XXXXXXXX",
        "X......X",
        "X.XXXX.X",
        "X.X..X.X",
        "X.X.XX.X",
        "X.X....X",
        "X.XXXXXX",
    ]
    for rep in range(8):
        for yy in range(min(h - 2, len(pat))):
            for xx in range(8):
                if pat[yy][xx] == "X":
                    px(im, rep * 8 + xx, y + 1 + yy, K["gold"] if yy % 2 == 0 else K["goldd"])


def hazard(im, x, y, w, h, K, phase=0):
    rect(im, x, y, w, h, K["black"])
    for yy in range(h):
        for xx in range(w):
            if ((xx + yy + phase) // 4) % 2 == 0:
                px(im, x + xx, y + yy, K["yellow"])
    hline(im, x, y, w, dk(K["yellow"], 0.7))
    hline(im, x, y + h - 1, w, K["black"])


def face_tile(K, variant):
    s = K["style"]
    rng = random.Random(ord(s[0]) * 131 + variant * 977)
    im = new(64, 64)
    cap_h = 8
    # tapa del muro (la superficie superior, mas clara)
    rect(im, 0, 0, 64, cap_h, K["lite"])
    hline(im, 0, 0, 64, K["dark"])
    hline(im, 0, 1, 64, K["mid"])
    hline(im, 0, cap_h - 2, 64, K["hi"])
    hline(im, 0, cap_h - 1, 64, dk(K["dark"], 0.8))
    for sx in ((32,) if variant == 0 else (14, 46)):
        vline(im, sx, 2, cap_h - 4, K["mortar"])
    if s == "earth":
        fill_courses(im, cap_h, 64, 3, K, rng)
        moss_edges(im, K, rng, [(cap_h, cap_h)], 0.5)
        moss_edges(im, K, rng, [(cap_h + 18, 0)], 0.0)
        roots(im, K, rng, 1 if variant == 0 else 2, cap_h, 40)
        # musgo sobre el borde de las hileras
        for yy in (cap_h + 18, cap_h + 36):
            for x in range(64):
                if rng.random() < 0.3:
                    px(im, x, yy, rng.choice([K["moss"], K["mossd"]]))
    elif s == "marble":
        fill_courses(im, cap_h, 33, 1, K, rng)
        meander(im, K, 33, 10)
        fill_courses(im, 43, 64, 1, K, rng)
        for x in (31, 63):
            pass
    elif s == "organic":
        fill_courses(im, cap_h, 64, 3, K, rng)
        for _ in range(6):
            x, y = rng.randint(2, 60), rng.randint(cap_h + 2, 60)
            rect(im, x, y, 2, 1, K["deep"])
    elif s == "concrete":
        fill_courses(im, cap_h, 64, 2, K, rng)
        # franja de acero oscuro al pie (el amarillo y negro va en el zocalo)
        for yy in range(56, 64):
            for x in range(64):
                px(im, x, yy, dk(im.getpixel((x, yy)), 0.8))
    else:  # white
        fill_courses(im, cap_h, 64, 2, K, rng)
        # juntas finas, nada mas: blanco impoluto
    # sombra de oclusion al pie de la cara (la lee el ojo como contacto con el suelo)
    for yy, k in ((63, 0.7), (62, 0.82), (61, 0.92)):
        for x in range(64):
            c = im.getpixel((x, yy))
            im.putpixel((x, yy), dk(c, k))
    return im


def cap_tile(K, variant):
    s = K["style"]
    rng = random.Random(ord(s[0]) * 71 + variant * 313 + 5)
    im = new(64, 64)
    fill_courses(im, 0, 64, 2, K, rng)
    if s == "earth":
        for _ in range(7):
            x, y = rng.randint(0, 61), rng.randint(0, 61)
            for k in range(rng.randint(2, 4)):
                px(im, (x + k) % 64, y, rng.choice([K["moss"], K["mossl"]]))
                px(im, (x + k) % 64, y + 1, K["mossd"])
    if s == "marble" and variant:
        # grieta fina
        x, y = 40, 4
        for _ in range(22):
            px(im, x, y, K["mortar"])
            y += 1
            x += rng.choice([-1, 0, 0, 1])
    if s == "concrete" and variant:
        rect(im, 10, 40, 5, 3, K["black"])
    # la tapa mira al cielo: un velo claro la separa de la cara; y mas plana (menos tablero)
    flat = {"earth": 0.38, "organic": 0.22}.get(s, 0.0)
    for y in range(64):
        for x in range(64):
            c = im.getpixel((x, y))
            c = mix(c, K["mid"], flat) if flat else c
            im.putpixel((x, y), mix(c, K["hi"], 0.08))
    return im


# ------------------------------------------------------------------ zocalos
def plinth(K, w, h, rng):
    """Zocalo horizontal: fila 0 pegada al muro (superficie clara) -> fila h-1 lejos (sombra)."""
    s = K["style"]
    im = new(w, h)
    if s == "earth":
        # monton de tierra con musgo y raices, borde irregular
        for x in range(w):
            top = 2 + int(2.2 * math.sin(x * 0.45) + 1.5 * math.sin(x * 1.3 + 1))
            top = max(0, min(h - 3, top))
            for y in range(top, h):
                t = (y - top) / max(1, h - top)
                c = K["lite"] if y == top else (K["mid"] if t < 0.5 else K["dark"])
                im.putpixel((x, y), c)
            if rng.random() < 0.55:
                px(im, x, top, rng.choice([K["moss"], K["mossl"]]))
                px(im, x, top + 1, K["mossd"])
        for _ in range(3):
            px(im, rng.randint(0, w - 1), rng.randint(5, h - 2), K["rootd"])
    elif s == "marble":
        rect(im, 0, 0, w, h, K["mid"])
        hline(im, 0, 0, w, K["hi"])
        hline(im, 0, 1, w, K["lite"])
        hline(im, 0, h - 3, w, K["dark"])
        hline(im, 0, h - 2, w, K["mortar"])
        hline(im, 0, h - 1, w, dk(K["mortar"], 0.6))
        for sx in (0, 31):
            vline(im, sx % w, 1, h - 3, K["dark"])
        hline(im, 0, 4, w, K["lite"])
    elif s == "organic":
        for x in range(w):
            top = 1 + int(1.6 * math.sin(x * 0.5) + 1.2 * math.sin(x * 0.23 + 2))
            top = max(0, top)
            for y in range(top, h):
                t = (y - top) / max(1, h - top)
                c = K["hi"] if y == top else (K["lite"] if t < 0.3 else (K["mid"] if t < 0.7 else K["dark"]))
                im.putpixel((x, y), c)
        hline(im, 0, h - 1, w, K["mortar"])
    elif s == "concrete":
        hazard(im, 0, 0, w, h, K, 0)
        hline(im, 0, h - 1, w, dk(K["black"], 0.7))
    else:
        rect(im, 0, 0, w, h, K["black"])
        hline(im, 0, 1, w, mix(K["black"], K["violet"], 0.45))
        hline(im, 0, 2, w, mix(K["black"], K["violet"], 0.2))
        for sx in range(6, w, 22):
            px(im, sx, 1, K["hi"])
            px(im, sx + 1, 1, K["hi"])
        hline(im, 0, h - 1, w, dk(K["black"], 0.5))
    # el borde lejano se funde con el suelo: pixel suelto de sombra
    return im


def pilaster(K):
    """Arista de la esquina interna: franja vertical pegada a la cara frontal (10x40)."""
    rng = random.Random(7)
    base = plinth(K, 40, 10, rng)
    im = base.transpose(Image.ROTATE_270).transpose(Image.FLIP_LEFT_RIGHT)  # 10x40
    # degradado de sombra hacia el interior de la sala
    for x in range(im.width):
        for y in range(im.height):
            c = im.getpixel((x, y))
            if c[3]:
                im.putpixel((x, y), dk(c, 0.78 + 0.22 * (1 - x / im.width)))
    return im


# ------------------------------------------------------------------ columna
def column(K):
    s = K["style"]
    rng = random.Random(ord(s[0]) * 17)
    W, H = 44, 96
    im = new(W, H)
    shaft_x0, shaft_x1 = 8, 36
    y_top, y_base = 14, 82
    def cyl(x0, x1, y0, y1, cols):
        """Cilindro con bandas de luz: cols = [hi, lite, mid, dark] de izquierda a derecha."""
        w = x1 - x0
        for x in range(x0, x1):
            t = (x - x0) / w
            c = cols[0] if t < 0.14 else cols[1] if t < 0.4 else cols[2] if t < 0.75 else cols[3]
            vline(im, x, y0, y1 - y0, c)

    if s == "earth":
        cyl(shaft_x0 + 1, shaft_x1 - 1, y_top, y_base, [K["lite"], K["mid"], K["dark"], dk(K["dark"], 0.7)])
        for gx in range(shaft_x0 + 3, shaft_x1 - 2, 4):
            for y in range(y_top, y_base):
                if (y + gx) % 11 > 2:
                    px(im, gx, y, dk(K["dark"], 0.7))
        for _ in range(7):
            mx, my = rng.randint(10, 32), rng.randint(y_top + 4, y_base - 6)
            rect(im, mx, my, 3, 2, K["moss"])
            px(im, mx, my, K["mossl"])
        # raices en la base
        for rx, ry, dx in ((6, 76, -1), (34, 78, 1), (12, 84, -1), (30, 84, 1)):
            for k in range(8):
                px(im, rx + dx * k, ry + k // 2 + 3, K["rootd"])
                px(im, rx + dx * k, ry + k // 2 + 2, K["root"])
        # copa de hojas
        for lx, ly in ((6, 8), (14, 3), (22, 0), (30, 3), (38, 8), (22, 8)):
            rect(im, lx - 5, ly + 2, 10, 4, K["moss"])
            rect(im, lx - 4, ly + 1, 8, 2, K["mossl"])
            hline(im, lx - 5, ly + 5, 10, K["mossd"])
        rect(im, 6, y_base, 32, 10, K["dark"])
        hline(im, 6, y_base, 32, K["mid"])
    elif s == "marble":
        cyl(shaft_x0, shaft_x1, y_top, y_base, [K["hi"], K["lite"], K["mid"], K["dark"]])
        for fx in range(shaft_x0 + 4, shaft_x1 - 2, 5):
            vline(im, fx, y_top, y_base - y_top, K["vein"])
        # capitel y base dorica
        rect(im, 4, 4, 36, 4, K["lite"])
        rect(im, 2, 8, 40, 6, K["mid"])
        hline(im, 2, 8, 40, K["hi"])
        hline(im, 2, 13, 40, K["dark"])
        hline(im, 4, 3, 36, K["hi"])
        rect(im, 4, 82, 36, 4, K["mid"])
        rect(im, 1, 86, 42, 8, K["lite"])
        hline(im, 1, 86, 42, K["hi"])
        hline(im, 1, 93, 42, K["dark"])
        # anillo dorado
        hline(im, shaft_x0, 30, shaft_x1 - shaft_x0, K["gold"])
        hline(im, shaft_x0, 31, shaft_x1 - shaft_x0, K["goldd"])
    elif s == "organic":
        # fuste ondulante rosa, mas ancho al medio y base y copa redondeadas
        for y in range(6, 90):
            t = (y - 6) / 84
            half = 10 + int(3 * math.sin(t * math.pi * 2.0 + 0.5)) + (5 if y > 78 else 0) + (4 if y < 16 else 0)
            x0, x1 = 22 - half, 22 + half
            cols = [K["hi"], K["lite"], K["mid"], K["dark"]]
            for x in range(x0, x1):
                u = (x - x0) / max(1, x1 - x0)
                px(im, x, y, cols[0] if u < 0.15 else cols[1] if u < 0.4 else cols[2] if u < 0.78 else cols[3])
        for k in range(10):
            yy = 14 + k * 7
            hline(im, 14, yy, 6, K["deep"])
        for k in range(5):
            px(im, 22 + (k * 5) % 11 - 5, 20 + k * 11, K["hi"])
    elif s == "concrete":
        cyl(shaft_x0 + 4, shaft_x1 - 4, 10, y_base, [K["hi"], K["lite"], K["mid"], K["dark"]])
        for yy in range(30, 54, 1):
            for x in range(shaft_x0 + 4, shaft_x1 - 4):
                if ((x + yy) // 4) % 2 == 0:
                    px(im, x, yy, K["yellow"] if x - shaft_x0 > 6 else dk(K["yellow"], 1.1))
                else:
                    px(im, x, yy, K["black"])
        for rx in (shaft_x0 + 5, shaft_x1 - 7):
            for ry in (14, 60, 74):
                rect(im, rx, ry, 2, 2, K["rivet"])
        # lampara ambar arriba
        rect(im, 17, 2, 10, 8, K["yellow"])
        rect(im, 19, 4, 4, 3, C("fff0a0"))
        hline(im, 17, 9, 10, dk(K["yellow"], 0.6))
        rect(im, 6, 82, 32, 10, K["dark"])
        hline(im, 6, 82, 32, K["lite"])
        hline(im, 6, 91, 32, K["mortar"])
    else:
        cyl(shaft_x0, shaft_x1, y_top, y_base, [K["hi"], K["hi"], K["mid"], K["dark"]])
        rect(im, 4, 4, 36, 10, K["mid"])
        hline(im, 4, 4, 36, K["hi"])
        rect(im, 2, 82, 40, 12, K["mid"])
        hline(im, 2, 82, 40, K["hi"])
        # barra negra de censura atravesando la columna
        rect(im, shaft_x0 - 2, 40, shaft_x1 - shaft_x0 + 4, 12, K["black"])
        hline(im, shaft_x0 - 2, 41, shaft_x1 - shaft_x0 + 4, mix(K["black"], K["violet"], 0.5))
        for x in range(shaft_x0 + 2, shaft_x1 - 2, 6):
            px(im, x, 45, K["mid"])
            px(im, x + 1, 45, K["mid"])
        hline(im, 2, 90, 40, K["dark"])
    outline(im)
    return im


# ------------------------------------------------------------------ marco y escalon
def frame(K):
    s = K["style"]
    rng = random.Random(ord(s[0]) * 29)
    N, B = 88, 12
    im = new(N, N)
    base, hi, lo = K["mid"], K["hi"], K["dark"]
    if s == "earth":
        base, hi, lo = K["mid"], K["lite"], K["dark"]
    # anillo (hueco central transparente)
    for y in range(N):
        for x in range(N):
            if B <= x < N - B and B <= y < N - B:
                continue
            u = (x < B) + (y < B)
            c = base
            if y < 3 or x < 3:
                c = hi
            elif y >= N - 3 or x >= N - 3:
                c = lo
            if s == "concrete":
                c = K["mid"]
            im.putpixel((x, y), jit(c, rng, 3) if s in ("earth", "organic") else c)
    # sillares: juntas
    for k in range(B + 2, N - B - 2, 14):
        vline(im, 5, k, 1, K["mortar"])
    for xx in range(0, B, 1):
        pass
    hline(im, 0, B - 1, N, dk(base, 0.8))
    hline(im, B, N - B, N - 2 * B, dk(base, 0.7))  # sombra interior abajo del hueco (umbral)
    for yy in range(B, N - B, 14):
        hline(im, 0, yy, B, K["mortar"])
        hline(im, N - B, yy, B, K["mortar"])
    # clave del arco (arriba al centro)
    kx = N // 2
    if s == "earth":
        for dx in range(-9, 10, 3):
            for k in range(rng.randint(5, 10)):
                px(im, kx + dx, B + k, K["moss"] if k % 2 else K["mossd"])
        rect(im, kx - 6, 0, 12, 6, K["mossd"])
        rect(im, kx - 4, 1, 8, 3, K["moss"])
    elif s == "marble":
        rect(im, kx - 6, 0, 12, B, K["lite"])
        rect(im, kx - 5, 2, 10, 4, K["gold"])
        hline(im, kx - 5, 5, 10, K["goldd"])
        vline(im, kx - 6, 0, B, K["dark"])
        vline(im, kx + 5, 0, B, K["dark"])
    elif s == "organic":
        rect(im, kx - 7, 0, 14, B, K["lite"])
        rect(im, kx - 4, 3, 8, 6, K["petal"])
        px(im, kx - 1, 5, K["hi"])
        px(im, kx, 5, K["hi"])
        hline(im, kx - 4, 8, 8, K["deep"])
    elif s == "concrete":
        hazard(im, 0, 0, N, 4, K)
        hazard(im, 0, 0, 4, N, K, 2)
        hazard(im, N - 4, 0, 4, N, K, 1)
        rect(im, kx - 10, 5, 20, 6, K["black"])
        rect(im, kx - 8, 6, 16, 4, K["yellow"])
        hline(im, kx - 6, 8, 12, K["black"])
    else:
        rect(im, kx - 7, 0, 14, B, K["black"])
        hline(im, kx - 7, 1, 14, mix(K["black"], K["violet"], 0.5))
        rect(im, 0, B - 1, N, 1, K["hi"])
    outline(im)
    return im


def step(K):
    s = K["style"]
    rng = random.Random(ord(s[0]) * 41)
    W, H = 84, 14
    im = new(W, H)
    # superficie del umbral (clara) y canto (oscuro)
    top = K["mid"] if s != "earth" else K["lite"]
    for y in range(H):
        for x in range(W):
            if y < 9:
                c = mix(top, K["hi"], 0.25 if y < 2 else 0.0)
            elif y < 13:
                c = dk(top, 0.74)
            else:
                c = dk(top, 0.5)
            im.putpixel((x, y), jit(c, rng, 3) if s in ("earth", "organic") else c)
    for sx in (21, 42, 63):
        vline(im, sx, 0, 9, K["mortar"])
    if s == "concrete":
        hazard(im, 0, 9, W, 4, K)
    if s == "earth":
        for x in range(0, W, 3):
            if rng.random() < 0.6:
                px(im, x, 0, K["moss"])
    outline(im)
    return im


# ------------------------------------------------------------------ variantes
def loose(K):
    s = K["style"]
    rng = random.Random(ord(s[0]) * 3)
    im = new(30, 14)
    cols = {"earth": K["mid"], "marble": K["lite"], "organic": K["mid"], "concrete": K["mid"], "white": K["mid"]}[s]
    for (bx, by, bw, bh) in ((2, 6, 9, 5), (13, 3, 8, 5), (19, 8, 9, 5), (8, 10, 6, 3)):
        rect(im, bx, by, bw, bh, jit(cols, rng, 6))
        hline(im, bx, by, bw, K["hi"])
        vline(im, bx, by, bh, mix(cols, K["hi"], 0.4))
        hline(im, bx, by + bh - 1, bw, dk(cols, 0.7))
        vline(im, bx + bw - 1, by, bh, dk(cols, 0.78))
    for _ in range(6):
        px(im, rng.randint(0, 29), rng.randint(9, 13), dk(cols, 0.8))
    if s == "concrete":
        hline(im, 11, 4, 4, K["rivet"])
        px(im, 22, 7, K["yellow"])
    if s == "earth":
        px(im, 4, 5, K["moss"])
        px(im, 15, 2, K["mossl"])
    outline(im)
    return im


def vines(K):
    s = K["style"]
    rng = random.Random(ord(s[0]) * 13)
    im = new(30, 42)
    if s == "white":
        # cintas de censura colgando, con sus rayitas de "texto" tachado
        for x0, ln, w in ((4, 36, 7), (15, 26, 6), (23, 40, 6)):
            rect(im, x0, 0, w, ln, K["black"])
            hline(im, x0, 0, w, mix(K["black"], K["violet"], 0.5))
            vline(im, x0, 0, ln, mix(K["black"], K["violet"], 0.25))
            for y in range(4, ln - 3, 5):
                hline(im, x0 + 2, y, w - 4, K["mid"])
            for k in range(2):  # punta en V
                px(im, x0 + k, ln + 0, K["black"])
                px(im, x0 + w - 1 - k, ln + 0, K["black"])
            px(im, x0 + w // 2, ln, K["black"])
            px(im, x0 + w // 2, ln + 1, K["black"])
        rect(im, 0, 0, 30, 2, K["red"])
        outline(im)
        return im
    strands = [(6, 38), (14, 30), (22, 40)]
    for sx, ln in strands:
        x = sx
        for y in range(ln):
            if s == "concrete":
                c = K["black"] if y % 6 < 4 else K["yellow"]
            elif s == "white":
                c = K["black"]
            elif s == "marble":
                c = C("3f7a46")
            elif s == "organic":
                c = K["leaf"]
            else:
                c = K["moss"] if y % 4 else K["mossd"]
            px(im, x, y, c)
            if s in ("white",):
                px(im, x + 1, y, c)
                px(im, x - 1, y, c)
            if s != "concrete" and rng.random() < 0.3:
                x += rng.choice([-1, 1])
            if s == "concrete" and y % 9 == 8:
                x += rng.choice([-1, 1])
            if rng.random() < 0.28 and s in ("earth", "marble", "organic") and y > 3:
                lc = {"earth": K.get("mossl"), "marble": C("5ca860"), "organic": C("88c488")}[s]
                px(im, x + 1, y, lc)
                px(im, x + 2, y, lc)
                px(im, x - 1, y + 1, lc)
                px(im, x - 2, y + 1, lc)
        # remate
        if s == "organic":
            rect(im, x - 1, ln, 3, 3, K["petal"])
            px(im, x, ln + 1, K["hi"])
        elif s == "concrete":
            px(im, x, ln, K["red"])
            px(im, x - 1, ln + 1, K["yellow"])
        elif s == "white":
            rect(im, x - 2, ln, 5, 2, K["black"])
        elif s == "marble":
            rect(im, x - 1, ln, 3, 2, C("5ca860"))
    outline(im)
    return im


def banner(K):
    s = K["style"]
    W, H = 26, 42
    im = new(W, H)
    pal = {
        "earth": lambda: (C("3e7a3a"), C("2a5a2e"), C("d6b45a")),
        "marble": lambda: (K["blue"], K["blued"], K["gold"]),
        "organic": lambda: (K["petal"], K["deep"], K["hi"]),
        "concrete": lambda: (K["yellow"], dk(K["yellow"], 0.7), K["black"]),
        "white": lambda: (K["mid"], K["dark"], K["black"]),
    }[s]()
    cloth, shade, trim = pal
    # barra superior
    rect(im, 0, 0, W, 3, trim if s != "earth" else K["rootd"])
    hline(im, 0, 0, W, K["hi"] if s != "earth" else K["root"])
    for y in range(3, H - 6):
        for x in range(2, W - 2):
            c = cloth
            if x < 5:
                c = mix(cloth, K["hi"], 0.18)
            elif x > W - 8:
                c = shade
            px(im, x, y, c)
    # faldon en V
    for k in range(7):
        y = H - 6 + k
        a, b = 2 + k, W - 2 - k
        for x in range(a, b):
            px(im, x, y, shade if x > W // 2 else cloth)
        if k == 6:
            pass
    # emblema
    cx, cy = W // 2, 18
    if s == "earth":
        for k in range(8):
            rect(im, cx - 1 - k // 3, cy - 6 + k * 2 - 2, 3 + (k // 2), 2, C("a8d868"))
        vline(im, cx, cy - 8, 16, K["rootd"])
    elif s == "marble":
        for k in range(8):  # corona de laurel
            px(im, cx - 6 + (k // 2), cy + 6 - k * 2, K["gold"])
            px(im, cx + 6 - (k // 2), cy + 6 - k * 2, K["gold"])
            px(im, cx - 5 + (k // 2), cy + 6 - k * 2 + 1, K["goldd"])
            px(im, cx + 5 - (k // 2), cy + 6 - k * 2 + 1, K["goldd"])
        rect(im, cx - 2, cy - 2, 5, 5, K["gold"])
        px(im, cx, cy, K["hi"])
    elif s == "organic":
        for ox, oy in ((0, -5), (5, -1), (3, 5), (-3, 5), (-5, -1)):
            rect(im, cx + ox - 2, cy + oy - 2, 4, 4, K["hi"])
        rect(im, cx - 2, cy - 2, 4, 4, K["yellow"] if "yellow" in K else C("ffd54a"))
    elif s == "concrete":
        # sello de aduana: circulo con tilde
        for a in range(0, 360, 12):
            px(im, cx + int(7 * math.cos(math.radians(a))), cy + int(7 * math.sin(math.radians(a))), K["black"])
        for k in range(4):
            px(im, cx - 3 + k, cy + k, K["black"])
        for k in range(6):
            px(im, cx + 1 + k, cy + 3 - k, K["black"])
    else:
        rect(im, 4, cy - 5, W - 8, 4, K["black"])
        rect(im, 4, cy + 2, W - 8, 4, K["black"])
        rect(im, cx - 4, cy - 2, 8, 8, K["red"])
        px(im, cx - 1, cy + 1, K["hi"])
        px(im, cx, cy + 1, K["hi"])
    outline(im)
    return im


def figure(im, ox, oy, K, kind):
    """Figurita desnuda de 14x22 px, tapada (para variar) con una hoja de parra enorme."""
    skin = C("f0c8a0") if kind != "concrete" else C("e8c4a0")
    sd = dk(skin, 0.82)
    # cabeza
    rect(im, ox + 5, oy, 4, 4, skin)
    hline(im, ox + 5, oy, 4, C("5a3a28"))
    px(im, ox + 5, oy + 1, C("5a3a28"))
    # torso y brazos
    rect(im, ox + 4, oy + 4, 6, 8, skin)
    rect(im, ox + 2, oy + 5, 2, 7, skin)
    rect(im, ox + 10, oy + 5, 2, 7, skin)
    vline(im, ox + 9, oy + 4, 8, sd)
    # piernas
    rect(im, ox + 4, oy + 12, 3, 9, skin)
    rect(im, ox + 7, oy + 12, 3, 9, skin)
    vline(im, ox + 6, oy + 13, 8, sd)
    rect(im, ox + 4, oy + 21, 3, 1, sd)
    rect(im, ox + 7, oy + 21, 3, 1, sd)
    # hoja de parra, desproporcionada a proposito
    leaf, leafd = C("4ea85a"), C("2d6e3a")
    rect(im, ox + 3, oy + 10, 8, 5, leaf)
    rect(im, ox + 4, oy + 15, 6, 2, leaf)
    rect(im, ox + 5, oy + 17, 4, 1, leaf)
    vline(im, ox + 7, oy + 10, 8, leafd)
    px(im, ox + 4, oy + 12, leafd)
    px(im, ox + 10, oy + 12, leafd)
    px(im, ox + 5, oy + 14, leafd)
    px(im, ox + 9, oy + 14, leafd)


def painting(K):
    s = K["style"]
    W, H = 32, 38
    im = new(W, H)
    frame_c = {"earth": lambda: (K["rootd"], K["root"]), "marble": lambda: (K["goldd"], K["gold"]),
               "organic": lambda: (K["deep"], K["petal"]), "concrete": lambda: (K["dark"], K["rivet"]),
               "white": lambda: (K["dark"], K["hi"])}[s]()
    bg = {"earth": C("4e8a58"), "marble": C("8ec4ee"), "organic": C("f6c6d4"),
          "concrete": C("9ab4d8"), "white": C("16141c")}[s]
    rect(im, 0, 0, W, H, frame_c[0])
    rect(im, 1, 1, W - 2, H - 2, frame_c[1])
    rect(im, 3, 3, W - 6, H - 6, frame_c[0])
    rect(im, 4, 4, W - 8, H - 8, bg)
    hline(im, 4, H - 5, W - 8, dk(bg, 0.85))
    if s == "white":
        # el cuadro entero es una barra de censura
        hline(im, 5, 6, W - 10, K["violet"])
        for k in range(3):
            hline(im, 7, 16 + k * 5, W - 14, K["mid"] if k != 1 else K["red"])
        rect(im, 12, 8, 8, 3, K["mid"])
    else:
        if s == "earth":
            for x in range(5, 27, 4):
                vline(im, x, 4, 8, C("2d6e3a"))
        if s == "marble":
            rect(im, 6, 6, 8, 3, C("ffffff"))
            rect(im, 18, 8, 7, 2, C("ffffff"))
        if s == "organic":
            rect(im, 22, 6, 4, 4, K["petal"])
        if s == "concrete":
            hline(im, 5, 5, 22, K["red"])  # cabecera del documento
        figure(im, 9, 9, K, s)
        if s == "concrete":
            rect(im, 12, 11, 8, 2, K["black"])  # barra sobre los ojos: foto del pasaporte
    outline(im)
    return im


def window(K):
    s = K["style"]
    light = K["light"]
    glow = mix(light, C("ffffff"), 0.35)
    W, H = 26, 40
    im = new(W, H)
    if s == "earth":
        # grieta entre raices: la tierra se rasga y entra luz verde
        rng = random.Random(5)
        cx = 13
        for y in range(2, 38):
            if y % 2 == 0:
                cx = max(8, min(18, cx + rng.choice([-2, -1, 0, 1, 2])))
            half = 2 + (1 if 8 < y < 30 else 0) + rng.choice([0, 0, 1, 2])
            for x in range(cx - half - 2, cx + half + 3):
                d = x - cx
                if abs(d) <= half - 1 or (abs(d) <= half and rng.random() < 0.6):
                    px(im, x, y, glow if abs(d) < 2 else light)
                elif abs(d) <= half + 1:
                    px(im, x, y, K["dark"])
                else:
                    px(im, x, y, K["mortar"])
        for ry, rl in ((12, 9), (24, 7)):  # una raiz atravesando la grieta
            for k in range(rl):
                px(im, 8 + k + (ry % 3), ry + k // 3, K["rootd"])
                px(im, 8 + k + (ry % 3), ry + k // 3 - 1, K["root"])
    elif s == "marble":
        rect(im, 2, 6, 22, 34, K["lite"])
        for y in range(0, 7):
            half = int(11 * math.sqrt(max(0, 1 - ((6 - y) / 7.0) ** 2)))
            hline(im, 13 - half, y, half * 2, K["lite"])
        rect(im, 6, 10, 14, 26, light)
        for y in range(6, 12):
            half = int(7 * math.sqrt(max(0, 1 - ((12 - y) / 7.0) ** 2)))
            hline(im, 13 - half, y, half * 2, light)
        rect(im, 9, 12, 8, 24, glow)
        vline(im, 13, 6, 30, K["mid"])
        hline(im, 6, 20, 14, K["mid"])
        hline(im, 1, 38, 24, K["dark"])
        hline(im, 1, 39, 24, K["mortar"])
        vline(im, 2, 8, 30, K["hi"])
    elif s == "organic":
        # ojo de buey ovalado de piedra rosa
        for y in range(0, 40):
            for x in range(0, 26):
                d = ((x - 12.5) / 12.0) ** 2 + ((y - 19.5) / 19.0) ** 2
                if d <= 1.0:
                    px(im, x, y, K["lite"] if d > 0.6 else (light if d > 0.12 else glow))
                if 0.82 < d <= 1.0:
                    px(im, x, y, K["deep"])
        for y in range(8, 32):
            px(im, 12, y, K["mid"])
    elif s == "concrete":
        rect(im, 1, 4, 24, 34, K["dark"])
        hline(im, 1, 4, 24, K["lite"])
        rect(im, 4, 7, 18, 28, light)
        rect(im, 6, 9, 14, 24, glow)
        for x in (8, 13, 18):
            vline(im, x, 7, 28, K["black"])
        hline(im, 4, 18, 18, K["black"])
        hline(im, 4, 26, 18, K["black"])
        hazard(im, 1, 36, 24, 3, K)
    else:
        rect(im, 2, 4, 22, 34, K["mid"])
        rect(im, 5, 7, 16, 28, light)
        rect(im, 7, 9, 12, 24, glow)
        hline(im, 2, 4, 22, K["hi"])
        rect(im, 3, 17, 20, 7, K["black"])  # barra de censura sobre el cristal
        hline(im, 3, 18, 20, mix(K["black"], K["violet"], 0.5))
    outline(im)
    return im


# ------------------------------------------------------------------ salida
def tileset_text(name):
    poly = "-32, -32, 32, -32, 32, 32, -32, 32"
    tiles = "".join(
        f"{i}:0/0 = 0\n{i}:0/0/physics_layer_0/polygon_0/points = PackedVector2Array({poly})\n" for i in range(4)
    )
    return f"""[gd_resource type="TileSet" format=3]

[ext_resource type="Texture2D" path="res://assets/sprites/environment/walls/{name}/atlas.png" id="1_atlas"]

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_wall"]
texture = ExtResource("1_atlas")
texture_region_size = Vector2i(64, 64)
{tiles}
[resource]
tile_size = Vector2i(64, 64)
physics_layer_0/collision_layer = 1
physics_layer_0/collision_mask = 0
sources/4 = SubResource("TileSetAtlasSource_wall")
"""


def build(name):
    K = KINGDOMS[name]
    d = OUT / name
    d.mkdir(parents=True, exist_ok=True)
    atlas = new(256, 64)
    for i, im in enumerate([cap_tile(K, 0), face_tile(K, 0), cap_tile(K, 1), face_tile(K, 1)]):
        blit(atlas, im, i * 64, 0)
    atlas.save(d / "atlas.png")
    rng = random.Random(ord(name[0]))
    plinth(K, 64, 12, rng).save(d / "zocalo_top.png")
    side = plinth(K, 64, 8, random.Random(ord(name[0]) + 1))
    side.save(d / "zocalo_bottom.png")
    side.transpose(Image.ROTATE_270).transpose(Image.FLIP_LEFT_RIGHT).save(d / "zocalo_side.png")
    pilaster(K).save(d / "pilaster.png")
    column(K).save(d / "column.png")
    frame(K).save(d / "frame.png")
    step(K).save(d / "step.png")
    loose(K).save(d / "loose.png")
    vines(K).save(d / "vines.png")
    banner(K).save(d / "banner.png")
    painting(K).save(d / "painting.png")
    window(K).save(d / "window.png")
    (TILESETS / f"walls_{name}.tres").write_text(tileset_text(name))
    print("ok", name)


if __name__ == "__main__":
    names = sys.argv[1:] or list(KINGDOMS)
    for n in names:
        build(n)
