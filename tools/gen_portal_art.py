"""Genera el arte del portal de salida por reino (assets/sprites/portal/).

Uso: python3 tools/gen_portal_art.py [reino ...]   (sin args = los cinco)
Reinos: neutral (Selva), pene (Penelandia), vulva (Vulvania), mixto (Perineo), censura (Palacio).

Por reino:
  base_<k>.png     marco del portal: anillo en el suelo + piezas altas del fondo (columnas, petales...)
  front_<k>.png    piezas de primer plano (se dibujan DESPUES del remolino, tapan su borde de abajo)
  swirl_<k>.png    remolino: tira de 8 fotogramas de 96x80 (bucle perfecto)
Mismo lienzo (160x150) en base y front; el centro del portal es (80, 92).
Arte pixel a 1x, contorno oscuro comun, luz arriba-izquierda. Determinista.
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/portal"
CLEAR = (0, 0, 0, 0)
OL = (13, 11, 15, 255)
W, H = 160, 150
CX, CY = 80, 92
RX, RY = 54, 43          # elipse del anillo (centro de la banda)
IRX, IRY = 42, 33        # hueco del remolino
SW, SH = 96, 80          # fotograma del remolino
FRAMES = 8


def C(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def dk(c, k):
    return tuple(max(0, min(255, int(c[i] * k))) for i in range(3)) + (255,)


def lt(c, k):
    return mix(c, (255, 255, 255, 255), k)


def new():
    return Image.new("RGBA", (W, H), CLEAR)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((int(x), int(y)), c)


def rect(im, x0, y0, x1, y1, c):
    ImageDraw.Draw(im).rectangle([x0, y0, x1, y1], fill=c)


def blob(im, x, y, r, c, hi=None, lo=None):
    """Disco pixelado con luz arriba-izquierda."""
    d = ImageDraw.Draw(im)
    d.ellipse([x - r, y - r, x + r, y + r], fill=lo or dk(c, 0.7))
    d.ellipse([x - r, y - r, x + r - 1, y + r - 1], fill=c)
    if r >= 3:
        d.ellipse([x - r + 1, y - r + 1, x - 1, y - 1], fill=hi or lt(c, 0.3))


def on_ring(a, k=1.0, dy=0):
    return CX + RX * k * math.cos(a), CY + RY * k * math.sin(a) + dy


def outline(im):
    out = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if im.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < im.width and 0 <= ny < im.height and im.getpixel((nx, ny))[3]:
                    out.putpixel((x, y), OL)
                    break
    return out


def clear_hole(im):
    """Vacia el hueco del remolino (el remolino va debajo del front, encima del base)."""
    d = ImageDraw.Draw(im)
    d.ellipse([CX - IRX, CY - IRY, CX + IRX, CY + IRY], fill=CLEAR)


def ring_band(im, pal, rnd, tex=None):
    """Banda elipsoidal gruesa entre el hueco y el borde exterior, con luz arriba-izquierda."""
    d = ImageDraw.Draw(im)
    ox, oy = RX + 8, RY + 7
    d.ellipse([CX - ox, CY - oy + 3, CX + ox, CY + oy + 3], fill=pal["deep"])      # canto
    d.ellipse([CX - ox, CY - oy, CX + ox, CY + oy], fill=pal["base"])               # tapa
    d.ellipse([CX - ox + 2, CY - oy + 2, CX + ox - 3, CY + oy - 3], fill=pal["lo"])
    d.ellipse([CX - ox + 3, CY - oy + 3, CX + ox - 5, CY + oy - 5], fill=pal["base"])
    # luz: arco claro arriba-izquierda
    d.arc([CX - ox + 2, CY - oy + 2, CX + ox - 3, CY + oy - 3], 180, 280, fill=pal["hi"], width=2)
    if tex:
        tex(im, d, rnd)


# ---------------------------------------------------------------- remolino
def swirl(pal, arms, twist, t):
    """Un fotograma del remolino. pal = 4 tonos (oscuro, medio, claro, brillo)."""
    im = Image.new("RGBA", (SW, SH), CLEAR)
    cx, cy = SW / 2, SH / 2
    rx, ry = IRX + 1, IRY + 1
    for y in range(SH):
        for x in range(SW):
            u = (x + 0.5 - cx) / rx
            v = (y + 0.5 - cy) / ry
            r = math.hypot(u, v)
            if r > 1.0:
                continue
            a = math.atan2(v, u)
            s = (arms * a / math.tau + twist * (1 - r) * 1.0 - t / FRAMES) % 1.0
            if s < 0.38:
                c = pal[0]
            elif s < 0.62:
                c = pal[1]
            elif s < 0.84:
                c = pal[2]
            else:
                c = pal[3]
            # borde exterior oscuro (profundidad del hueco) y centro brillante
            if r > 0.9:
                c = dk(pal[0], 0.6)
            elif r > 0.8:
                c = mix(c, dk(pal[0], 0.55), 0.55)
            if r < 0.1:
                c = pal[3]
            elif r < 0.2:
                c = mix(c, pal[3], 0.55)
            im.putpixel((x, y), c)
    return im


def swirl_sheet(pal, arms=3, twist=1.6, alt=None):
    sheet = Image.new("RGBA", (SW * FRAMES, SH), CLEAR)
    for i in range(FRAMES):
        sheet.paste(swirl(pal, arms, twist, i), (i * SW, 0))
    return sheet


# ---------------------------------------------------------------- reinos
def make_neutral():
    """Selva: raices retorcidas que forman un arco, hojas y mechones de vello."""
    rnd = random.Random(11)
    bark = {"base": C("7a5232"), "hi": C("a9794a"), "lo": C("5a3b24"), "deep": C("3a2616")}
    leaf = C("3fae6a")
    base, front = new(), new()

    def tex(im, d, r):
        for i in range(40):  # vetas
            a = r.uniform(0, math.tau)
            x, y = on_ring(a)
            px(im, x + r.randint(-3, 3), y + r.randint(-3, 3), bark["deep"])
    ring_band(base, bark, rnd, tex)
    # arco de dos raices detras (se dibuja antes que la banda frontal)
    arch = new()
    for side in (-1, 1):
        pts = []
        for i in range(0, 31):
            t = i / 30
            x = CX + side * (RX + 2) * (1 - t ** 2.3) + 3 * math.sin(t * 8 + side)
            y = CY - 4 - 78 * math.sin(t * math.pi / 2) ** 1.3
            pts.append((x, y))
        for (x, y) in pts:
            blob(arch, x, y, 4 if y > CY - 40 else 3, bark["base"], bark["hi"], bark["lo"])
    base = Image.alpha_composite(arch, base)
    # hojas y vello colgando del arco
    for _ in range(14):
        side = rnd.choice((-1, 1))
        t = rnd.uniform(0.2, 0.95)
        x = CX + side * (RX + 2) * (1 - t ** 2.3) + rnd.randint(-3, 3)
        y = CY - 4 - 78 * math.sin(t * math.pi / 2) ** 1.3
        blob(base, x, y, 2, leaf, lt(leaf, 0.4), dk(leaf, 0.6))
    for _ in range(9):  # vello: curvitas oscuras
        side = rnd.choice((-1, 1))
        t = rnd.uniform(0.3, 0.9)
        x = int(CX + side * (RX + 2) * (1 - t ** 2.3))
        y = int(CY - 4 - 78 * math.sin(t * math.pi / 2) ** 1.3) + 4
        for k in range(rnd.randint(4, 8)):
            px(base, x + int(2 * math.sin(k)), y + k, C("2a1c12"))
    clear_hole(base)
    # primer plano: mechones y hojas en el borde bajo
    for i in range(16):
        a = math.pi * (0.1 + 0.8 * i / 15)
        x, y = on_ring(a, 1.14, 2)
        if i % 3 == 0:
            blob(front, x, y, 3, leaf, lt(leaf, 0.4), dk(leaf, 0.6))
        else:
            for k in range(rnd.randint(4, 7)):
                px(front, x + int(2 * math.sin(k * 0.9 + i)), y - k, C("2a1c12"))
    pal = [C("0f3a24"), C("2e8a58"), C("7fe0a0"), C("eaffd8")]
    return base, front, swirl_sheet(pal, 3, 1.4), C("7fe0a0")


def make_pene():
    """Penelandia: columnas griegas con dintel y suelo de marmol azulado."""
    rnd = random.Random(12)
    mar = {"base": C("c9d6e6"), "hi": C("f4f9ff"), "lo": C("9fb0c8"), "deep": C("6a7d99")}
    base, front = new(), new()

    def tex(im, d, r):
        n = 28
        for i in range(n):  # juntas de losas
            a = math.tau * i / n
            x0, y0 = on_ring(a, 0.82)
            x1, y1 = on_ring(a, 1.12)
            d.line([x0, y0, x1, y1], fill=mar["lo"])
    ring_band(base, mar, rnd, tex)

    def column(im, x, ytop, ybot, w=8):
        rect(im, x - w // 2, ytop, x + w // 2, ybot, mar["base"])
        rect(im, x - w // 2, ytop, x - w // 2 + 1, ybot, mar["hi"])
        rect(im, x + w // 2 - 1, ytop, x + w // 2, ybot, mar["lo"])
        for fx in (x - 1, x + 2):  # estrias
            rect(im, fx, ytop + 4, fx, ybot - 4, mar["lo"])
        rect(im, x - w // 2 - 2, ytop - 3, x + w // 2 + 2, ytop + 1, mar["hi"])   # capitel
        rect(im, x - w // 2 - 2, ytop + 1, x + w // 2 + 2, ytop + 2, mar["lo"])
        rect(im, x - w // 2 - 2, ybot, x + w // 2 + 2, ybot + 3, mar["base"])      # basa
        rect(im, x - w // 2 - 2, ybot + 3, x + w // 2 + 2, ybot + 3, mar["deep"])
    arch = new()
    for side in (-1, 1):
        column(arch, CX + side * (RX - 4), CY - 62, CY - 4)
    # dintel y frontón
    rect(arch, CX - RX - 8, CY - 70, CX + RX + 8, CY - 63, mar["base"])
    rect(arch, CX - RX - 8, CY - 70, CX + RX + 8, CY - 69, mar["hi"])
    rect(arch, CX - RX - 8, CY - 64, CX + RX + 8, CY - 63, mar["lo"])
    d = ImageDraw.Draw(arch)
    d.polygon([(CX - RX - 8, CY - 71), (CX, CY - 92), (CX + RX + 8, CY - 71)], fill=mar["base"])
    d.polygon([(CX - RX + 4, CY - 72), (CX, CY - 87), (CX + RX - 4, CY - 72)], fill=mar["lo"])
    d.line([(CX - RX - 8, CY - 71), (CX, CY - 92)], fill=mar["hi"], width=1)
    blob(arch, CX, CY - 78, 4, C("6ec6ff"), C("d6efff"), C("3c7fb0"))   # gema en el frontón
    base = Image.alpha_composite(arch, base)
    clear_hole(base)
    for side in (-1, 1):  # trozos de columna caidos delante
        x, y = on_ring(math.pi * (0.5 + side * 0.33), 1.17, 2)
        rect(front, x - 7, y - 3, x + 7, y + 3, mar["base"])
        rect(front, x - 7, y - 3, x + 7, y - 2, mar["hi"])
        rect(front, x - 7, y + 3, x + 7, y + 3, mar["deep"])
    pal = [C("12306a"), C("2d6fc4"), C("6ec6ff"), C("e4f6ff")]
    return base, front, swirl_sheet(pal, 3, 1.5), C("6ec6ff")


def make_vulva():
    """Vulvania: marco de petalos carnosos que se cierran como un capullo."""
    rnd = random.Random(13)
    pink = {"base": C("e0679f"), "hi": C("ff9ccb"), "lo": C("b84a7f"), "deep": C("7d2f58")}
    base, front = new(), new()

    def tex(im, d, r):
        for i in range(36):
            a = math.tau * i / 36
            x, y = on_ring(a)
            px(im, x, y, pink["deep"])
    ring_band(base, pink, rnd, tex)
    arch = new()

    def petal(im, x, y, ang, ln, wd, c):
        d = ImageDraw.Draw(im)
        ux, uy = math.cos(ang), math.sin(ang)
        nx, ny = -uy, ux
        pts = []
        for i in range(0, 21):
            t = i / 20
            w = wd * math.sin(t * math.pi) ** 0.8
            pts.append((x + ux * ln * t + nx * w, y + uy * ln * t + ny * w))
        for i in range(20, -1, -1):
            t = i / 20
            w = wd * math.sin(t * math.pi) ** 0.8
            pts.append((x + ux * ln * t - nx * w, y + uy * ln * t - ny * w))
        d.polygon(pts, fill=dk(c, 0.62))
        pts2 = [(x + (px_ - x) * 0.82 + ux * 1, y + (py_ - y) * 0.82) for px_, py_ in pts]
        d.polygon(pts2, fill=c)
        d.line([(x + ux * 4, y + uy * 4), (x + ux * ln * 0.8, y + uy * ln * 0.8)], fill=lt(c, 0.35), width=1)
    # petales altos al fondo: abanico que se curva sobre el hueco
    for i, ang in enumerate([-160, -135, -110, -90, -70, -45, -20]):
        a = math.radians(ang)
        sx, sy = on_ring(math.radians(ang), 0.95, -2)
        ln = 54 if abs(ang + 90) < 30 else 46
        petal(arch, sx, sy, a, ln, 9, pink["base"] if i % 2 else pink["hi"])
    base = Image.alpha_composite(arch, base)
    clear_hole(base)
    for i in range(14):  # petalos de primer plano
        a = math.pi * (0.08 + 0.84 * i / 13)
        x, y = on_ring(a, 1.1, 3)
        petal(front, x, y, math.pi / 2 + (a - math.pi / 2) * 0.4, 16, 5, pink["hi"] if i % 2 else pink["base"])
    # gotas de rocio
    for _ in range(10):
        a = rnd.uniform(0.15, 0.85) * math.pi
        x, y = on_ring(a, rnd.uniform(1.0, 1.2), 3)
        blob(front, x, y, 1, C("ffe3f1"))
    pal = [C("5a0f3d"), C("c93c86"), C("ff7ac0"), C("ffe6f3")]
    return outline_both(base, front, swirl_sheet(pal, 4, 1.2), C("ff7ac0"))


def make_mixto():
    """Perineo: caseta de aduana, barrera a rayas y suelo ajedrezado dorado."""
    rnd = random.Random(14)
    gold = {"base": C("e0b030"), "hi": C("ffe27a"), "lo": C("a67f1c"), "deep": C("6b4f10")}
    base, front = new(), new()

    def tex(im, d, r):
        n = 36
        for i in range(n):  # franjas de peligro alternadas
            if i % 2:
                a0, a1 = 360 * i / n, 360 * (i + 1) / n
                d.arc([CX - RX - 4, CY - RY - 3, CX + RX + 4, CY + RY + 3], a0, a1, fill=C("2a2230"), width=7)
    ring_band(base, gold, rnd, tex)
    arch = new()
    red, white = C("d8453c"), C("f3efe6")

    def post(im, x):
        for y in range(CY - 66, CY - 2):
            c = red if ((y - CY) // 5) % 2 else white
            rect(im, x - 3, y, x + 3, y, c)
        rect(im, x - 3, CY - 66, x - 2, CY - 3, lt(C("d8453c"), 0.25))
        blob(im, x, CY - 70, 5, C("ffd75a"), C("fff3b0"), C("a67f1c"))   # farol
    for side in (-1, 1):
        post(arch, CX + side * (RX - 2))
    # cartel colgante (sin texto: tira con tres sellos)
    rect(arch, CX - 30, CY - 80, CX + 30, CY - 62, C("3a3342"))
    rect(arch, CX - 30, CY - 80, CX + 30, CY - 79, C("5d5468"))
    for k in range(3):
        blob(arch, CX - 18 + k * 18, CY - 71, 5, C("d8453c"), C("ff8a80"), C("8a2a24"))
        px(arch, CX - 18 + k * 18, CY - 71, C("f3efe6"))
    for sx in (-30, 29):
        rect(arch, CX + sx, CY - 82, CX + sx + 1, CY - 62, C("8a8196"))
    base = Image.alpha_composite(arch, base)
    clear_hole(base)
    # barrera levantada en primer plano (brazo a rayas) y conos
    for i in range(52):
        c = red if (i // 5) % 2 else white
        rect(front, CX - 26 + i, CY + 47 - i // 6, CX - 26 + i, CY + 50 - i // 6, c)
    for side in (-1, 1):
        x, y = CX + side * (RX + 4), CY + 38
        ImageDraw.Draw(front).polygon([(x - 5, y + 9), (x + 5, y + 9), (x, y - 6)], fill=C("ff8a3c"))
        rect(front, x - 3, y + 1, x + 3, y + 3, C("f3efe6"))
    pal = [C("1c2f6a"), C("4a86d8"), C("ff7ac0"), C("ffe8a0")]
    return outline_both(base, front, swirl_sheet(pal, 4, 1.3), C("ffc93c"))


def make_censura():
    """Palacio: losas negras con barras de censura y lacres rojos."""
    rnd = random.Random(15)
    stone = {"base": C("4a4658"), "hi": C("7a7490"), "lo": C("322f3e"), "deep": C("1b1923")}
    base, front = new(), new()

    def tex(im, d, r):
        n = 24
        for i in range(n):  # barras negras de censura sobre el anillo
            if i % 3 == 0:
                a = math.tau * i / n
                x, y = on_ring(a)
                rect(im, x - 5, y - 2, x + 5, y + 2, C("0a090d"))
    ring_band(base, stone, rnd, tex)
    arch = new()
    for side in (-1, 1):  # pilares con barras
        x = CX + side * (RX - 2)
        rect(arch, x - 8, CY - 66, x + 8, CY - 3, stone["base"])
        rect(arch, x - 8, CY - 66, x - 6, CY - 3, stone["hi"])
        rect(arch, x + 6, CY - 66, x + 8, CY - 3, stone["lo"])
        for k in range(4):
            rect(arch, x - 8, CY - 58 + k * 14, x + 8, CY - 52 + k * 14, C("0a090d"))
    rect(arch, CX - RX - 10, CY - 78, CX + RX + 10, CY - 64, stone["base"])
    rect(arch, CX - RX - 10, CY - 78, CX + RX + 10, CY - 77, stone["hi"])
    rect(arch, CX - 36, CY - 74, CX + 36, CY - 68, C("0a090d"))
    blob(arch, CX, CY - 71, 7, C("c8283c"), C("ff6a78"), C("7a1020"))     # sello grande
    px(arch, CX - 2, CY - 73, C("ffd0d4"))
    base = Image.alpha_composite(arch, base)
    clear_hole(base)
    for side in (-1, 1):  # lacres sueltos delante
        for k in range(2):
            x, y = on_ring(math.pi * (0.5 + side * (0.3 + 0.1 * k)), 1.16, 3)
            blob(front, x, y, 4, C("c8283c"), C("ff6a78"), C("7a1020"))
    pal = [C("1a0f3a"), C("5a3fa0"), C("b48cff"), C("f0e6ff")]
    return outline_both(base, front, swirl_sheet(pal, 5, 1.0), C("b48cff"))


def outline_both(base, front, sheet, glow):
    return outline(base), outline(front), sheet, glow


MAKERS = {
    "neutral": make_neutral,
    "pene": make_pene,
    "vulva": make_vulva,
    "mixto": make_mixto,
    "censura": make_censura,
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    names = sys.argv[1:] or list(MAKERS)
    for k in names:
        base, front, sheet, _glow = MAKERS[k]()
        if k in ("neutral", "pene"):
            base, front = outline(base), outline(front)
        base.save(OUT / f"base_{k}.png")
        front.save(OUT / f"front_{k}.png")
        sheet.save(OUT / f"swirl_{k}.png")
        print("portal", k)


if __name__ == "__main__":
    main()
