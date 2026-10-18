"""Genera el arte de calcomanias de suelo (assets/sprites/environment/decals/).

Uso: python3 tools/gen_decal_art.py
Todo a 1 px de arte = 1 px de mundo (igual que los personajes). Es fondo: bajo
contraste, tonos apagados, sin el contorno negro de los items ni brillos fuertes
(que no se confunda con monedas o pickups reales).

Salida:
  rug_<k>.png            baldosa 32x32 tileable del camino/alfombra (el borde lo arma el juego)
  patch_<k>_a/_b.png     baldosa 32x32 tileable de otro material (parches de transicion)
  scatter_<k>_<n>.png    detalles sueltos por reino (raices, petalos, grietas, tinta...)
  stamp_<k>.png          sellos (aduana, censura)
  puddle_<tipo>_<s|m|l>[_a|_b].png   charcos y sus brillos (a/b = dos cuadros de brillo)
  coin_<n>.png           monedas incrustadas en el suelo (tienda)
  scroll_<n>.png         pergaminos y hojas caidas (inscripciones)
  glass_<n>.png          vasos, botellas y cristales rotos (antro)
Reinos: neutral (selva), pene, vulva, mixto (perineo), censura (palacio).
"""
import math
import random
import sys
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets/sprites/environment/decals"
T = 32  # lado de las baldosas tileables


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))), max(0, min(255, int(c[2] * f))), c[3])


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def soften(im, f):
    """Acerca cada pixel al tono medio de la baldosa: mas calma, menos contraste (es fondo)."""
    px = [im.getpixel((x, y)) for y in range(im.height) for x in range(im.width) if im.getpixel((x, y))[3]]
    if not px:
        return im
    m = [sum(p[i] for p in px) / len(px) for i in range(3)]
    out = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            p = im.getpixel((x, y))
            if p[3]:
                out.putpixel((x, y), tuple(int(p[i] + (m[i] - p[i]) * f) for i in range(3)) + (p[3],))
    return out


def save(im, name):
    OUT.mkdir(parents=True, exist_ok=True)
    im.save(OUT / f"{name}.png")


def new(w, h, fill=(0, 0, 0, 0)):
    return Image.new("RGBA", (w, h), fill)


def wput(im, x, y, c):
    """Pixel con envoltura (para baldosas tileables)."""
    im.putpixel((x % im.width, y % im.height), c)


def blobs(im, rng, tones, n, maxw=3, maxh=2):
    """Manchas pequenas de tonos (ruido agrupado, no pixel a pixel)."""
    for _ in range(n):
        x, y = rng.randrange(im.width), rng.randrange(im.height)
        c = rng.choice(tones)
        for dy in range(rng.randint(1, maxh)):
            for dx in range(rng.randint(1, maxw)):
                wput(im, x + dx, y + dy, c)


def walk(im, rng, x, y, n, c, bias=(1, 0)):
    """Linea quebrada (vetas, raices, grietas)."""
    for _ in range(n):
        wput(im, x, y, c)
        r = rng.random()
        if r < 0.55:
            x += bias[0]; y += bias[1]
        elif r < 0.8:
            x += bias[0]; y += bias[1] + rng.choice((-1, 1))
        else:
            x += rng.choice((-1, 0, 1)); y += bias[1] if bias[1] else rng.choice((-1, 1))


def slabs(im, rng, rows, tones, grout, hi=None, lo=None, wmin=8, wmax=14):
    """Losas/adoquines en filas con desfase. rows = alturas que suman T."""
    y = 0
    for h in rows:
        x = -rng.randrange(wmin)
        while x < T:
            w = rng.randint(wmin, wmax)
            c = rng.choice(tones)
            for yy in range(h):
                for xx in range(w):
                    px, py = x + xx, y + yy
                    edge = xx == 0 or yy == 0 or xx == w - 1 or yy == h - 1
                    col = grout if edge else c
                    if not edge and hi and (xx == 1 or yy == 1):
                        col = hi(c)
                    elif not edge and lo and (xx == w - 2 or yy == h - 2):
                        col = lo(c)
                    wput(im, px, py, col)
            x += w
        y += h


def spiral(im, ox, oy, size, c):
    """Meandro griego (espiral cuadrada) en una celda size x size."""
    x0, y0, x1, y1 = 1, 1, size - 2, size - 2
    px = lambda x, y: wput(im, ox + x, oy + y, c)
    while x1 - x0 >= 2:
        for x in range(x0, x1 + 1): px(x, y0)
        for y in range(y0, y1 + 1): px(x1, y)
        for x in range(x1, x0 - 1, -1): px(x, y1)
        for y in range(y1, y0 + 1, -1): px(x0, y)
        px(x0 + 1, y0 + 2)
        x0 += 2; y0 += 2; x1 -= 2; y1 -= 2


def petal(im, rng, x, y, c1, c2):
    """Petalo de 3x2 / 2x3 con luz."""
    if rng.random() < 0.5:
        pts = [(0, 0), (1, 0), (2, 0), (1, 1), (2, 1)]
    else:
        pts = [(0, 0), (0, 1), (0, 2), (1, 1), (1, 2)]
    for dx, dy in pts:
        wput(im, x + dx, y + dy, c1)
    wput(im, x, y, c2)


# ---------------------------------------------------------------- baldosas por reino
def rug(k):
    rng = random.Random("rug" + k)
    im = new(T, T)
    if k == "neutral":  # sendero de tierra pisada con guijarros y raicillas
        base, d1, l1 = C("7a5c3e"), C("684d34"), C("8c6c4a")
        im.paste(base, (0, 0, T, T))
        blobs(im, rng, [d1, l1], 60, 3, 2)
        for _ in range(5):
            x, y = rng.randrange(T), rng.randrange(T)
            for dx, dy in ((0, 0), (1, 0), (2, 0), (0, 1), (1, 1), (2, 1)):
                wput(im, x + dx, y + dy, C("8e8474"))
            wput(im, x, y, C("a69c8a")); wput(im, x + 1, y + 2, C("4e3a28")); wput(im, x + 2, y + 2, C("4e3a28"))
        for _ in range(2):
            walk(im, rng, rng.randrange(T), rng.randrange(T), 9, C("4e3a28"))
        blobs(im, rng, [C("5f7a44")], 6, 2, 1)
    elif k == "pene":  # mosaico de marmol con meandro griego
        tones = [C("cdd3de"), C("c2c9d6"), C("d6dbe5")]
        im.paste(tones[0], (0, 0, T, T))
        blobs(im, rng, tones[1:], 50, 4, 2)
        for _ in range(3):
            walk(im, rng, rng.randrange(T), rng.randrange(T), 10, C("aab4c6"), (1, 1))
        for cx in range(2):
            for cy in range(2):
                if (cx + cy) % 2 == 0:
                    for y in range(16):
                        for x in range(16):
                            wput(im, cx * 16 + x, cy * 16 + y, C("c8d0dd") if (x + y) % 7 else C("bcc5d4"))
                    spiral(im, cx * 16, cy * 16, 16, C("6a86b4"))
                    wput(im, cx * 16 + 7, cy * 16 + 7, C("c9a95a"))
    elif k == "vulva":  # losas de piedra rosada con petalos
        tones = [C("c98aa0"), C("be7f97"), C("d396ab")]
        slabs(im, rng, [10, 11, 11], tones, C("8c5670"),
              hi=lambda c: shade(c, 1.1), lo=lambda c: shade(c, 0.9))
        for _ in range(4):
            petal(im, rng, rng.randrange(T), rng.randrange(T), C("e0709a"), C("f4a0c0"))
    elif k == "mixto":  # adoquin fronterizo, algun adoquin azul / rosa
        tones = [C("807a76"), C("757070"), C("8a847c"), C("6f6a68")]
        slabs(im, rng, [8, 8, 8, 8], tones, C("464244"), hi=lambda c: shade(c, 1.12), lo=lambda c: shade(c, 0.88), wmin=7, wmax=9)
        for _ in range(3):
            x, y = rng.randrange(T), rng.randrange(T)
            for dy in range(5):
                for dx in range(6):
                    wput(im, x + dx, y + dy, rng.choice([C("6f86aa"), C("b0788c")]) if 0 < dx < 5 and 0 < dy < 4 else C("464244"))
    elif k == "prostata":  # alfombra gris de sala de espera con rombos nuez
        base, dk, lt = C("a89c9a"), C("8e6c58"), C("b8aca8")
        im.paste(base, (0, 0, T, T))
        blobs(im, rng, [lt], 30, 2, 1)
        for i in range(T):
            for off in (0, 16):
                wput(im, i, (i + off) % T, dk)
                wput(im, i, (-i + off) % T, dk)
        for cx, cy in ((8, 8), (24, 24), (8, 24), (24, 8)):
            wput(im, cx, cy, C("e0c8c4")); wput(im, cx + 1, cy, C("c8aca8")); wput(im, cx, cy + 1, C("c8aca8"))
    else:  # censura: alfombra roja con rombos y botones dorados
        base, dk, lt = C("96202e"), C("7e1826"), C("a82c3a")
        im.paste(base, (0, 0, T, T))
        blobs(im, rng, [lt], 30, 2, 1)
        for i in range(T):
            for off in (0, 16):
                wput(im, i, (i + off) % T, dk)
                wput(im, i, (-i + off) % T, dk)
        for cx, cy in ((8, 8), (24, 24), (8, 24), (24, 8)):
            wput(im, cx, cy, C("c9a24c")); wput(im, cx + 1, cy, C("a88434")); wput(im, cx, cy + 1, C("a88434"))
    save(soften(im, {"pene": 0.5, "censura": 0.2}.get(k, 0.3)), f"rug_{k}")


def patch(k, v):
    rng = random.Random(f"patch{k}{v}")
    im = new(T, T)
    if k == "neutral":
        if v == "a":  # musgo
            im.paste(C("4f7a3e"), (0, 0, T, T))
            blobs(im, rng, [C("5d8c48"), C("43692f")], 70, 3, 2)
            blobs(im, rng, [C("78a85c")], 14, 1, 1)
        else:  # tierra oscura con raices
            im.paste(C("4e3a2a"), (0, 0, T, T))
            blobs(im, rng, [C("5e4632"), C("403022")], 60, 3, 2)
            for _ in range(3):
                walk(im, rng, rng.randrange(T), rng.randrange(T), 14, C("72573a"))
    elif k == "pene":
        if v == "a":  # marmol oscuro
            im.paste(C("8c98ae"), (0, 0, T, T))
            blobs(im, rng, [C("98a4ba"), C("808ca4")], 50, 4, 2)
            for _ in range(3):
                walk(im, rng, rng.randrange(T), rng.randrange(T), 12, C("6c7890"), (1, 1))
        else:  # teselas azules y doradas
            for y in range(0, T, 4):
                for x in range(0, T, 4):
                    c = rng.choice([C("7898c4"), C("84a4cc"), C("6c8cb8"), C("7898c4"), C("b8a060")])
                    for yy in range(3):
                        for xx in range(3):
                            im.putpixel((x + xx, y + yy), c)
                    for i in range(4):
                        im.putpixel((x + 3, y + i), C("56709a")); im.putpixel((x + i, y + 3), C("56709a"))
    elif k == "vulva":
        if v == "a":  # piedra palida
            im.paste(C("dcb4c4"), (0, 0, T, T))
            blobs(im, rng, [C("e4bfce"), C("d2a8ba")], 60, 4, 2)
            for _ in range(2):
                walk(im, rng, rng.randrange(T), rng.randrange(T), 10, C("b88aa0"), (1, 1))
        else:  # cama de petalos
            im.paste(C("b84a78"), (0, 0, T, T))
            for _ in range(26):
                petal(im, rng, rng.randrange(T), rng.randrange(T), rng.choice([C("d8628e"), C("c4507e"), C("e87aa0")]), C("f6a8c4"))
    elif k == "mixto":
        if v == "a":  # arena de aduana
            im.paste(C("b09c6c"), (0, 0, T, T))
            blobs(im, rng, [C("bca878"), C("a48f60")], 60, 4, 2)
            blobs(im, rng, [C("7a6a48")], 8, 2, 1)
        else:  # grava
            im.paste(C("6a6664"), (0, 0, T, T))
            for _ in range(46):
                x, y = rng.randrange(T), rng.randrange(T)
                c = rng.choice([C("8a8480"), C("7a7470"), C("9a948c"), C("58544f")])
                wput(im, x, y, c); wput(im, x + 1, y, c); wput(im, x, y + 1, shade(c, 0.8))
    elif k == "prostata":
        if v == "a":  # baldosa rosa lechoso con juntas
            im.paste(C("d6bcb8"), (0, 0, T, T))
            blobs(im, rng, [C("dcc4c0"), C("cdb0ac")], 40, 4, 2)
            for i in range(T):
                wput(im, i, 15, C("a89490")); wput(im, 15, i, C("a89490"))
        else:  # tablones de nuez
            im.paste(C("8a6a50"), (0, 0, T, T))
            for y in range(0, T, 8):
                for x in range(T):
                    wput(im, x, y, C("5e4634"))
            for _ in range(5):
                walk(im, rng, rng.randrange(T), rng.randrange(T), 12, C("7a5c44"), (1, 0))
    else:
        if v == "a":  # marmol gris claro con cruz de juntas
            im.paste(C("dadae2"), (0, 0, T, T))
            blobs(im, rng, [C("e2e2ea"), C("d0d0da")], 40, 4, 2)
            for i in range(T):
                wput(im, i, 15, C("bcbcc8")); wput(im, 15, i, C("bcbcc8"))
        else:  # tachon de tinta con rayas diagonales (censura)
            im.paste(C("2c2834"), (0, 0, T, T))
            for i in range(T):
                for off in range(0, T * 2, 8):
                    wput(im, i, off - i, C("383244"))
            blobs(im, rng, [C("22202a")], 20, 3, 2)
    save(soften(im, 0.45), f"patch_{k}_{v}")


# ---------------------------------------------------------------- detalles sueltos
def scatter(k, n):
    rng = random.Random(f"sc{k}{n}")
    if k == "neutral":
        if n == 0:  # raiz que cruza el suelo
            im = new(56, 22)
            x, y = 0, 11
            for _ in range(70):
                for t in range(2):
                    if 0 <= y + t < 22 and 0 <= x < 56:
                        im.putpixel((x, y + t), C("5a4230", 230))
                if 0 <= y - 1 < 22 and 0 <= x < 56:
                    im.putpixel((x, y - 1), C("7a5a3c", 200))
                x += 1
                if rng.random() < 0.3:
                    y = max(2, min(19, y + rng.choice((-1, 1))))
                if x >= 56:
                    break
            for bx in (12, 30, 44):  # ramitas
                yy = 11
                for i in range(6):
                    if 0 <= bx + i < 56:
                        im.putpixel((bx + i, max(1, min(20, yy + (i if bx % 2 else -i) // 2))), C("5a4230", 210))
            return im
        if n == 1:  # mata de musgo
            im = new(28, 18)
            for _ in range(90):
                a = rng.random() * math.tau
                r = rng.random() ** 0.6
                x, y = int(14 + math.cos(a) * r * 12), int(9 + math.sin(a) * r * 7)
                im.putpixel((x, y), rng.choice([C("557f42", 230), C("476c35", 230), C("6a9a52", 210)]))
            return im
        im = new(24, 16)  # hojas caidas
        for _ in range(4):
            x, y = rng.randrange(2, 20), rng.randrange(2, 12)
            c = rng.choice([C("8a7a3a", 230), C("6a7a3a", 230), C("9a6a34", 230)])
            for dx, dy in ((0, 0), (1, 0), (2, 0), (1, 1), (2, 1), (3, 1)):
                im.putpixel((x + dx, y + dy), c)
            im.putpixel((x, y), shade(c, 1.2))
        return im
    if k == "pene":
        if n == 0:  # grieta de marmol
            im = new(40, 24)
            walk(im, rng, 1, 12, 46, C("7e8aa2", 235), (1, 0))
            for y in range(24):
                for x in range(40):
                    if im.getpixel((x, y))[3] and y + 1 < 24 and im.getpixel((x, y + 1))[3] == 0 and rng.random() < 0.6:
                        im.putpixel((x, y + 1), C("e8edf6", 150))
            return im
        if n == 1:  # esquirlas de marmol
            im = new(24, 14)
            for _ in range(7):
                x, y = rng.randrange(1, 20), rng.randrange(1, 11)
                c = rng.choice([C("d2d8e4"), C("bcc4d4")])
                im.putpixel((x, y), c); im.putpixel((x + 1, y), c); im.putpixel((x + 1, y + 1), shade(c, 0.8))
            return im
        im = new(22, 14)  # hoja de laurel
        for i in range(10):
            x = 2 + i * 2
            y = 7 - int(math.sin(i / 9 * math.pi) * 3)
            im.putpixel((x, y), C("7a9a58", 235)); im.putpixel((x + 1, y), C("7a9a58", 235))
            im.putpixel((x, y + 1), C("5a7a40", 235)); im.putpixel((x + 1, y + 1), C("5a7a40", 235))
        return im
    if k == "vulva":
        im = new(32, 20)
        cnt = (5, 8, 3)[n]
        for _ in range(cnt):
            petal(im, rng, rng.randrange(2, 28), rng.randrange(2, 16), rng.choice([C("d4628c", 235), C("c4507e", 235)]), C("f09ec0", 235))
        return im
    if k == "mixto":
        if n == 0:  # grieta con sello
            im = new(36, 20)
            walk(im, rng, 1, 10, 40, C("2e2a2c", 220), (1, 0))
            return im
        if n == 1:  # monton de arena
            im = new(28, 14)
            for _ in range(70):
                a = rng.random() * math.tau
                r = rng.random() ** 0.7
                im.putpixel((int(14 + math.cos(a) * r * 12), int(7 + math.sin(a) * r * 5)),
                            rng.choice([C("c0aa78", 220), C("a8945f", 220), C("d0ba88", 200)]))
            return im
        im = new(30, 18)  # papel de formulario arrugado, con huella de bota
        for y in range(6, 14):
            for x in range(6, 22):
                im.putpixel((x, y), C("c8c2b0", 235) if (x + y) % 5 else C("b4ae9c", 235))
        for x in range(8, 20, 2):
            im.putpixel((x, 9), C("6a6458", 235))
        return im
    if k == "prostata":
        if n == 0:  # revista vieja abierta
            im = new(30, 20)
            for y in range(3, 17):
                for x in range(2, 28):
                    im.putpixel((x, y), C("e4dccc", 235) if x != 15 else C("a89c8c", 235))
            for y in (6, 9, 12):
                for x in range(4, 13):
                    im.putpixel((x, y), C("8a8478", 220))
                for x in range(18, 26):
                    im.putpixel((x, y), C("8a8478", 220))
            return im
        if n == 1:  # turnos tirados
            im = new(26, 16)
            for ox, oy in ((3, 3), (14, 6), (8, 9)):
                for y in range(oy, oy + 5):
                    for x in range(ox, ox + 8):
                        im.putpixel((x, y), C("eee2bc", 235))
                im.putpixel((ox + 3, oy + 2), C("a02828", 235)); im.putpixel((ox + 4, oy + 2), C("a02828", 235))
            return im
        im = new(14, 12)  # chicle pegado
        for y in range(3, 9):
            for x in range(2, 12):
                if (x - 7) ** 2 / 24 + (y - 6) ** 2 / 9 <= 1:
                    im.putpixel((x, y), C("d68aa0", 235))
        im.putpixel((5, 4), C("f0b8c8", 235))
        return im
    # censura
    if n == 0:  # gotas de tinta
        im = new(30, 20)
        for _ in range(9):
            x, y = rng.randrange(2, 27), rng.randrange(2, 17)
            r = rng.choice([1, 1, 2])
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if dx * dx + dy * dy <= r * r + 1:
                        im.putpixel((x + dx, y + dy), C("2a2634", 225))
        return im
    if n == 1:  # tiras de papel tachado
        im = new(34, 14)
        for i, y in enumerate((2, 6, 10)):
            x0 = rng.randrange(0, 6)
            for x in range(x0, x0 + rng.randint(18, 26)):
                im.putpixel((x, y), C("bcbcc8", 235)); im.putpixel((x, y + 1), C("a6a6b4", 235))
        return im
    im = new(24, 16)  # trozo de sello roto
    for y in range(2, 14):
        for x in range(2, 22):
            if (x - 12) ** 2 / 100 + (y - 8) ** 2 / 36 <= 1 and rng.random() < 0.9:
                edge = (x - 12) ** 2 / 100 + (y - 8) ** 2 / 36 > 0.65
                if edge:
                    im.putpixel((x, y), C("a64450", 200))
    return im


def stamp(k):
    """Sellos pintados en el suelo: aduana (mixto) y censura (palacio)."""
    if k == "mixto":
        im = new(34, 22)
        col = C("7a6a58", 215)
        for x in range(34):
            for y in (0, 1, 20, 21):
                im.putpixel((x, y), col)
        for y in range(22):
            for x in (0, 1, 32, 33):
                im.putpixel((x, y), col)
        for i in range(8):  # flechas en sentidos contrarios
            im.putpixel((6 + i, 8), col); im.putpixel((27 - i, 13), col)
        for d in range(1, 4):
            im.putpixel((14 - d, 8 - d), col); im.putpixel((14 - d, 8 + d), col)
            im.putpixel((19 + d, 13 - d), col); im.putpixel((19 + d, 13 + d), col)
        return im
    im = new(36, 36)
    col = C("a8505c", 200)
    cx = cy = 17.5
    for y in range(36):
        for x in range(36):
            r = math.hypot(x - cx, y - cy)
            if 14.5 <= r <= 17 or 10.5 <= r <= 11.5:
                im.putpixel((x, y), col)
    for i in range(-12, 13):  # barra de censura en diagonal
        for t in range(-2, 3):
            x, y = int(cx + i), int(cy + i * 0.35 + t)
            if 0 <= x < 36 and 0 <= y < 36:
                im.putpixel((x, y), C("3a3040", 215))
    return im


# ---------------------------------------------------------------- charcos
PUDDLES = {
    # rim, cuerpo, reflejo, brillo, alfa del cuerpo
    "water": (C("3c6a96"), C("5486b8"), C("7eaed6"), C("e8f6ff"), 175),
    "mud": (C("3a2a1c"), C("5a4430"), C("7a5e42"), C("c8b89a"), 225),
    "baba": (C("b0487e"), C("e486b4"), C("f6b4d2"), C("fff0f8"), 205),
    "dudoso": (C("b8b090"), C("e6e0c0"), C("f6f2da"), C("ffffff"), 225),
    "tinta": (C("120f18"), C("221e2c"), C("3c3650"), C("a8a0c0"), 240),
    "aceite": (C("1c1a28"), C("2c2a3e"), C("3a6a62"), C("d8a0e8"), 230),
    "whiskey": (C("7a4a1c"), C("b0702c"), C("d89848"), C("ffe0a0"), 205),
}
SIZES = {"s": (22, 14), "m": (38, 24), "l": (60, 38)}


def puddle(kind, sz):
    rim, body, refl, shine, alpha = PUDDLES[kind]
    w, h = SIZES[sz]
    rng = random.Random(f"pud{kind}{sz}")
    p1, p2, p3 = rng.random() * 6, rng.random() * 6, rng.random() * 6
    inside = set()
    for y in range(h):
        for x in range(w):
            dx, dy = (x + 0.5 - w / 2) / (w / 2 - 1), (y + 0.5 - h / 2) / (h / 2 - 1)
            a = math.atan2(dy, dx)
            r = 0.86 + 0.12 * math.sin(3 * a + p1) + 0.07 * math.sin(5 * a + p2) + 0.04 * math.sin(7 * a + p3)
            if math.hypot(dx, dy) <= r:
                inside.add((x, y))
    im = new(w, h)
    for (x, y) in inside:
        edge = any((x + dx, y + dy) not in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if edge:
            c = (rim[0], rim[1], rim[2], min(255, alpha + 20))
        elif (x - 2, y - 2) not in inside:
            c = (refl[0], refl[1], refl[2], alpha)
        else:
            c = (body[0], body[1], body[2], alpha)
        im.putpixel((x, y), c)
    # textura interior segun el liquido
    pts = [p for p in inside if all((p[0] + dx, p[1] + dy) in inside for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0)))]
    rng.shuffle(pts)
    if kind == "aceite":  # irisado: bandas de colores apagados
        for (x, y) in pts[: len(pts) // 2]:
            band = (x + y * 2) // 3 % 3
            im.putpixel((x, y), [C("4a7a6e", alpha), C("6a4a8a", alpha), C("2c2a3e", alpha)][band])
    elif kind == "baba":  # hilos y burbujas
        for (x, y) in pts[: max(2, len(pts) // 10)]:
            im.putpixel((x, y), (refl[0], refl[1], refl[2], alpha))
    elif kind == "dudoso":  # burbujitas
        for (x, y) in pts[: max(2, len(pts) // 14)]:
            im.putpixel((x, y), C("fffff0", alpha))
            if (x + 1, y) in inside:
                im.putpixel((x + 1, y), C("c8c2a0", alpha))
    elif kind in ("water", "mud", "whiskey"):
        for (x, y) in pts[: max(2, len(pts) // 12)]:
            im.putpixel((x, y), (refl[0], refl[1], refl[2], alpha))
    if kind == "dudoso" and sz == "l":  # chiste sutil: las ondas dibujan un signo de interrogacion
        q = ["..###..", ".#...#.", ".....#.", "....#..", "...#...", ".......", "...#..."]
        ox, oy = w // 2 - 3, h // 2 - 3
        for yy, row in enumerate(q):
            for xx, ch in enumerate(row):
                if ch == "#" and (ox + xx, oy + yy) in inside:
                    im.putpixel((ox + xx, oy + yy), C("c0b888", alpha))
    save(im, f"puddle_{kind}_{sz}")
    # dos cuadros de brillo (el juego los alterna con una onda lenta)
    for v, (fx, fy) in (("a", (0.3, 0.32)), ("b", (0.56, 0.5))):
        sh = new(w, h)
        for dy, ln in ((0, 5), (3, 3)):
            sx, sy = int(w * fx) + dy, int(h * fy) + dy
            for i in range(ln * (2 if sz == "l" else 1)):
                x, y = sx + i, sy - i // 3
                if (x, y) in pts or (x, y) in inside and (x + 1, y + 1) in inside:
                    sh.putpixel((x, y), (shine[0], shine[1], shine[2], 255))
        if sz != "s":
            for _ in range(2):
                x, y = rng.choice(pts)
                sh.putpixel((x, y), (shine[0], shine[1], shine[2], 255))
        save(sh, f"puddle_{kind}_{sz}_{v}")


# ---------------------------------------------------------------- monedas incrustadas (tienda)
def coin_flat(im, cx, cy, r=4, half=False):
    """Moneda aplastada contra el suelo: dorado apagado, sin brillo, con grieta alrededor."""
    for y in range(-r, r + 1):
        for x in range(-r, r + 1):
            d = x * x + (y * 1.15) ** 2
            if d <= r * r + 1:
                if half and y > 1:
                    continue
                edge = d > (r - 1) ** 2 + 1
                c = C("46381f", 235) if edge else C("8c7440", 235)
                if not edge and (x + y) < -2:
                    c = C("a08a52", 235)
                if not edge and x == 0 and abs(y) < 2:
                    c = C("6c582e", 235)
                im.putpixel((cx + x, cy + y), c)
    for ang in (0.6, 2.2, 3.9, 5.4):  # grietitas
        for t in range(r + 1, r + 4):
            x, y = int(cx + math.cos(ang) * t), int(cy + math.sin(ang) * t * 0.9)
            if 0 <= x < im.width and 0 <= y < im.height and im.getpixel((x, y))[3] == 0:
                im.putpixel((x, y), C("2a2218", 150))


def coins():
    im = new(14, 12); coin_flat(im, 7, 6); save(im, "coin_0")
    im = new(24, 14); coin_flat(im, 7, 7); coin_flat(im, 16, 8, 4); save(im, "coin_1")
    im = new(14, 12); coin_flat(im, 7, 7, 4, half=True)
    for x in range(3, 12):
        im.putpixel((x, 8), C("2a2218", 200)); im.putpixel((x, 9), C("2a2218", 120))
    save(im, "coin_2")
    im = new(34, 20)
    rng = random.Random("coin3")
    for _ in range(6):
        coin_flat(im, rng.randrange(5, 29), rng.randrange(5, 15), 3)
    save(im, "coin_3")


# ---------------------------------------------------------------- pergaminos (inscripciones)
def scrolls():
    ink, pa, pl, pd = C("6a5230", 235), C("c6b48a", 235), C("d6c69c", 235), C("a8946a", 235)
    rng = random.Random("scroll")
    im = new(30, 20)  # hoja abierta con renglones
    for y in range(3, 17):
        for x in range(4, 26):
            im.putpixel((x, y), pd if (y in (3, 16) or x in (4, 25)) else (pl if (x + y) % 9 else pa))
    for y in (6, 9, 12):
        for x in range(7, 23, 1):
            if rng.random() < 0.8:
                im.putpixel((x, y), ink)
    im.putpixel((4, 3), (0, 0, 0, 0)); im.putpixel((25, 16), (0, 0, 0, 0)); im.putpixel((25, 3), (0, 0, 0, 0))
    save(im, "scroll_0")
    im = new(28, 10)  # rollo
    for y in range(1, 9):
        for x in range(3, 25):
            c = pl if y in (2, 3) else (pa if y < 6 else pd)
            im.putpixel((x, y), c)
    for y in range(2, 8):
        im.putpixel((2, y), pd); im.putpixel((25, y), pd); im.putpixel((1, y + 0), C("8a7650", 235)); im.putpixel((26, y), C("8a7650", 235))
    for x in range(4, 24, 3):
        im.putpixel((x, 4), ink)
    save(im, "scroll_1")
    im = new(22, 18)  # hoja rota
    for y in range(2, 16):
        for x in range(2, 20):
            if rng.random() < 0.97 and not (x > 14 and y < 6 + (x - 14)):
                im.putpixel((x, y), pl if (x + y) % 7 else pa)
    for y in (5, 8, 11):
        for x in range(4, 16):
            if rng.random() < 0.7:
                im.putpixel((x, y), ink)
    save(im, "scroll_2")
    im = new(14, 12)  # bola de papel
    for y in range(12):
        for x in range(14):
            if (x - 6.5) ** 2 / 36 + (y - 6) ** 2 / 26 <= 1:
                im.putpixel((x, y), rng.choice([pa, pl, pd]))
    save(im, "scroll_3")
    im = new(24, 16)  # tintero volcado y mancha
    for y in range(16):
        for x in range(24):
            if (x - 14) ** 2 / 64 + (y - 9) ** 2 / 20 <= 1 and x > 5:
                im.putpixel((x, y), C("24202e", 215))
    for y in range(3, 9):
        for x in range(2, 9):
            im.putpixel((x, y), C("56506a", 235) if x > 2 and y > 3 else C("3a3648", 235))
    save(im, "scroll_4")


# ---------------------------------------------------------------- vasos y botellas (antro)
def glass():
    rng = random.Random("glass")
    g1, g2, g3 = C("4a6e4c", 235), C("62906a", 235), C("2e4630", 235)
    im = new(26, 12)  # botella verde tumbada
    for y in range(3, 9):
        for x in range(2, 17):
            im.putpixel((x, y), g2 if y < 5 else g1)
    for y in range(4, 8):
        for x in range(17, 25):
            im.putpixel((x, y), g2 if y == 4 else g1)
    for x in range(2, 25):
        im.putpixel((x, 9), C("1c1c1c", 90))
        if x < 17: im.putpixel((x, 3), g3)
    for y in range(3, 9): im.putpixel((2, y), g3)
    im.putpixel((24, 5), C("c8b890", 235)); im.putpixel((24, 6), C("c8b890", 235))
    im.putpixel((6, 4), C("b8d8c0", 200)); im.putpixel((7, 4), C("b8d8c0", 200))
    save(im, "glass_0")
    im = new(24, 12)  # botella marron rota
    b1, b2 = C("7a4a26", 235), C("a06a3a", 235)
    for y in range(3, 8):
        for x in range(2, 10):
            im.putpixel((x, y), b2 if y < 5 else b1)
    for _ in range(7):
        x, y = rng.randrange(10, 22), rng.randrange(2, 10)
        im.putpixel((x, y), rng.choice([b1, b2, C("c8a070", 220)]))
        im.putpixel((x + 1, y), b1)
    save(im, "glass_1")
    im = new(18, 14)  # vaso tumbado con derrame
    for y in range(4, 10):
        for x in range(8, 16):
            im.putpixel((x, y), C("a8c0c8", 150) if 5 < y < 9 else C("d0e0e4", 200))
    for y in range(4, 11):
        for x in range(1, 9):
            if (x - 3) ** 2 / 9 + (y - 7.5) ** 2 / 9 <= 1:
                im.putpixel((x, y), C("a8682c", 190))
    for y in range(4, 10):
        im.putpixel((8, y), C("e8f0f0", 220))
    save(im, "glass_2")
    im = new(26, 18)  # cristales rotos
    for _ in range(12):
        x, y = rng.randrange(2, 22), rng.randrange(2, 14)
        c = rng.choice([C("a8c0c8", 210), C("d4e4e8", 220), C("7a98a0", 210)])
        im.putpixel((x, y), c); im.putpixel((x + 1, y), c); im.putpixel((x + (1 if rng.random() < 0.5 else 0), y + 1), shade(c, 0.8))
    save(im, "glass_3")
    im = new(18, 18)  # aro de vaso en la mugre
    for a in range(0, 360, 6):
        x, y = int(9 + math.cos(math.radians(a)) * 6), int(9 + math.sin(math.radians(a)) * 5)
        if rng.random() < 0.85:
            im.putpixel((x, y), C("5a3c20", 130))
    save(im, "glass_4")
    im = new(10, 8)  # corcho
    for y in range(1, 7):
        for x in range(1, 9):
            if (x - 4.5) ** 2 / 14 + (y - 3.5) ** 2 / 8 <= 1:
                im.putpixel((x, y), rng.choice([C("a07a4a", 235), C("8a6838", 235)]))
    save(im, "glass_5")


def main():
    for k in (sys.argv[1:] or ("neutral", "pene", "vulva", "mixto", "censura", "prostata")):
        rug(k)
        patch(k, "a")
        patch(k, "b")
        for n in range(3):
            save(scatter(k, n), f"scatter_{k}_{n}")
    if len(sys.argv) > 1:  # solo los reinos pedidos
        return
    save(stamp("mixto"), "stamp_mixto")
    save(stamp("censura"), "stamp_censura")
    for kind in PUDDLES:
        for sz in SIZES:
            puddle(kind, sz)
    coins()
    scrolls()
    glass()
    print("ok:", len(list(OUT.glob("*.png"))), "png en", OUT)


if __name__ == "__main__":
    main()
