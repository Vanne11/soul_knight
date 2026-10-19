"""Arte de la sala MONTE DE VENUS (assets/sprites/environment/decor/).

Uso: python3 tools/gen_monte_venus_art.py
  monte_venus_loma.png     loma escalonada de 3 terrazas, cesped y rizos de vello (1 px arte = 1 px mundo)
  monte_venus_bandera.png  mastil con bandera rosa y el simbolo de Venus (cima)
Misma paleta verde de la Selva (gen_decor_art.py): contorno oscuro y luz arriba-izquierda.
"""
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets/sprites/environment/decor"
OL = (13, 11, 15, 255)
CLEAR = (0, 0, 0, 0)


def C(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def outline(im):
    src = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < im.width and 0 <= yy < im.height and src.getpixel((xx, yy))[3] > 0:
                        im.putpixel((x, y), OL)
                        break
    return im


def loma():
    W, H = 320, 190
    im = Image.new("RGBA", (W, H), CLEAR)
    d = ImageDraw.Draw(im)
    rnd = random.Random(7)
    cx = W // 2
    # (rx, ry, cy, color de la cara superior), de abajo (ancha) a arriba
    tiers = [(150, 56, 106, "#3f9a52"), (108, 42, 84, "#4cae5a"), (62, 26, 62, "#62c466")]
    SIDE = 14
    soil = C("#5d7a3a")
    for rx, ry, cy, col in tiers:
        top = C(col)
        # cara lateral (tierra con musgo): elipse inferior + rectangulo
        d.ellipse([cx - rx, cy + SIDE - ry, cx + rx, cy + SIDE + ry], fill=soil)
        d.rectangle([cx - rx, cy, cx + rx, cy + SIDE], fill=soil)
        # sombreado lateral por columnas (luz izquierda)
        for x in range(cx - rx, cx + rx + 1):
            t = (x - (cx - rx)) / (2.0 * rx)
            k = -0.12 if t < 0.2 else (0.22 if t > 0.75 else 0.0)
            for y in range(cy, cy + SIDE + int(ry * math.sqrt(max(0, 1 - ((x - cx) / rx) ** 2))) + 1):
                p = im.getpixel((x, y))
                if p[3] and p == soil:
                    q = mix(p, (255, 255, 255, 255), -k) if k < 0 else mix(p, (0, 0, 0, 255), k)
                    im.putpixel((x, y), q)
        # cara superior
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=top)
        # raices/piedritas en el lateral
        for _ in range(int(rx * 0.35)):
            x = cx + rnd.randint(-rx + 4, rx - 4)
            edge = int(ry * math.sqrt(max(0, 1 - ((x - cx) / rx) ** 2)))
            y = cy + edge + rnd.randint(2, SIDE - 3)
            if im.getpixel((x, y))[:3] == soil[:3] or True:
                im.putpixel((x, y), mix(soil, (0, 0, 0, 255), 0.35))
        # flequillo de cesped en el borde frontal
        for x in range(cx - rx + 3, cx + rx - 2, 3):
            edge = int(ry * math.sqrt(max(0, 1 - ((x - cx) / rx) ** 2)))
            by = cy + edge
            h = rnd.randint(2, 5)
            for j in range(h):
                im.putpixel((x, by + j), mix(top, (0, 0, 0, 255), 0.18))
        # textura: moteado en 3 tonos + brillo arriba-izquierda
        for _ in range(rx * ry // 6):
            x = cx + rnd.randint(-rx, rx)
            y = cy + rnd.randint(-ry, ry)
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 0.92:
                continue
            lit = (x - cx) / rx + (y - cy) / ry < 0
            r = rnd.random()
            c = mix(top, (255, 255, 255, 255), 0.18) if (r < 0.4 and lit) else (mix(top, (0, 0, 0, 255), 0.2) if r < 0.75 else mix(top, C("#bfe08a"), 0.3))
            im.putpixel((x, y), c)
        # matas de cesped (V) y rizos de vello (arco enroscado marron)
        for _ in range(rx * ry // 90):
            x = cx + rnd.randint(-rx + 8, rx - 8)
            y = cy + rnd.randint(-ry + 5, ry - 5)
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 0.8:
                continue
            g = mix(top, (0, 0, 0, 255), 0.35)
            gl = mix(top, C("#d6f2a0"), 0.45)
            for dx, dy in ((0, 0), (-1, -1), (1, -1), (-2, -3), (2, -3)):
                im.putpixel((x + dx, y + dy), g)
            im.putpixel((x, y - 2), gl)
        for _ in range(rx * ry // 70):
            x = cx + rnd.randint(-rx + 10, rx - 10)
            y = cy + rnd.randint(-ry + 6, ry - 6)
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 > 0.85:
                continue
            hair = C("#4a2f1c")
            hair_l = C("#7a5232")
            rr = rnd.choice([2, 2, 3])
            d.arc([x - rr, y - rr, x + rr, y + rr], 20, 330, fill=hair)
            im.putpixel((x + rr - 1, y), hair_l)
            im.putpixel((x - 1, y - rr), hair_l)
    outline(im)
    # contorno entre terrazas: borde oscuro del plano superior
    d2 = ImageDraw.Draw(im)
    for rx, ry, cy, _ in tiers:
        d2.arc([cx - rx, cy - ry, cx + rx, cy + ry], 0, 180, fill=mix(OL, (60, 70, 50, 255), 0.4))
    return im


def bandera():
    W, H = 40, 72
    im = Image.new("RGBA", (W, H), CLEAR)
    d = ImageDraw.Draw(im)
    wood, wood_l = C("#6b4226"), C("#93603a")
    d.rectangle([6, 6, 8, 68], fill=wood)
    d.line([(6, 6), (6, 68)], fill=wood_l)
    d.ellipse([4, 2, 10, 8], fill=C("#d9b84a"))
    d.ellipse([5, 3, 7, 5], fill=C("#ffe58a"))
    # tela ondeada
    pink, pink_l, pink_d = C("#f06aa0"), C("#ff9cc4"), C("#b8386f")
    for x in range(9, 37):
        wave = int(2.2 * math.sin((x - 9) / 4.0))
        y0, y1 = 10 + wave, 34 + wave
        d.line([(x, y0), (x, y1)], fill=pink)
        d.point((x, y0 + 1), fill=pink_l)
        if (x - 9) % 8 >= 5:
            d.line([(x, y0 + 2), (x, y1)], fill=pink_d)
    # simbolo de Venus (circulo + cruz) en crema
    cream = C("#fff4dc")
    ox, oy = 23, 16
    d.ellipse([ox - 4, oy - 4, ox + 4, oy + 4], outline=cream)
    d.line([(ox, oy + 5), (ox, oy + 13)], fill=cream)
    d.line([(ox - 3, oy + 9), (ox + 3, oy + 9)], fill=cream)
    # base de piedritas
    for x, y in ((3, 68), (11, 69), (7, 70), (13, 67)):
        d.ellipse([x - 2, y - 1, x + 2, y + 1], fill=C("#8a8494"))
    outline(im)
    return im


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    loma().save(OUT / "monte_venus_loma.png")
    bandera().save(OUT / "monte_venus_bandera.png")
    print("ok")
