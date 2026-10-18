"""Genera las puertas por reino: assets/sprites/environment/doors/<reino>/door_<dir>_<estado>.png

Uso: python3 tools/gen_door_art.py [reino ...]   (sin args = los cinco)
Reinos: neutral (Selva), pene (Penelandia), vulva (Vulvania), mixto (Perineo), censura (Palacio).

Cada puerta es de 64x64 (el marco de muro de 88x88 de gen_wall_art la rodea, asi que
rellena todo el cuadro). Se dibuja la de arriba ("up": la salida va hacia arriba) y las demas
direcciones son giros: down 180, left 90 antihorario, right 90 horario. Estados:
  closed  hoja cerrada propia del reino
  open    pasillo en perspectiva (muros laterales que convergen, suelo con juntas y
          oscuridad al fondo con un resplandor de la sala vecina)
  locked  cerrada + candado
  sealed  cerrada + cadenas en X con gema (sala en combate)
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/environment/doors"
OL = (13, 11, 15, 255)
N = 64
KINGDOMS = ["neutral", "pene", "vulva", "mixto", "censura", "prostata"]


def C(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def dk(c, k):
    return tuple(max(0, min(255, int(c[i] * k))) for i in range(3)) + (255,)


# paleta por reino: hoja (hi/md/dk), marco interior, suelo del pasillo, fondo oscuro, brillo del fondo, acento
PAL = {
    "neutral": dict(hi=C("#a87a4a"), md=C("#7a5334"), dk=C("#4a3022"), jm=C("#775539"), floor=C("#6a5238"),
                    dark=C("#10160f"), glow=C("#b8f090"), acc=C("#5aa850"), metal=C("#3c3a40")),
    "pene": dict(hi=C("#f6d070"), md=C("#c08a3a"), dk=C("#7a4e22"), jm=C("#e6e4dc"), floor=C("#d8d6ce"),
                 dark=C("#14161e"), glow=C("#bfe4ff"), acc=C("#4aa8f0"), metal=C("#8e92aa")),
    "vulva": dict(hi=C("#fa9cc0"), md=C("#d8548c"), dk=C("#8c2a5c"), jm=C("#e288a6"), floor=C("#c46888"),
                  dark=C("#1c0a16"), glow=C("#ffd0e4"), acc=C("#ff5c9c"), metal=C("#ffe8d8")),
    "mixto": dict(hi=C("#a6aec6"), md=C("#6a7290"), dk=C("#3a4058"), jm=C("#646b7e"), floor=C("#4c5268"),
                  dark=C("#0c0e16"), glow=C("#ffe48a"), acc=C("#f4c42c"), metal=C("#2a2c36")),
    "prostata": dict(hi=C("#b08a68"), md=C("#8a6a50"), dk=C("#54402f"), jm=C("#c8b4ae"), floor=C("#b4a09c"),
                     dark=C("#14100f"), glow=C("#ffe2c0"), acc=C("#c46a5a"), metal=C("#5a5658")),
    "censura": dict(hi=C("#5a5470"), md=C("#38344a"), dk=C("#1e1c2a"), jm=C("#d0d3e6"), floor=C("#b8bad0"),
                    dark=C("#0a0912"), glow=C("#ffffff"), acc=C("#d6303c"), metal=C("#16141c")),
}
GOLD = C("#ffc93c")
GOLD_DK = C("#b8841c")
CHAIN = C("#c8d0e4")
CHAIN_DK = C("#7a82a0")


def blank():
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def rim(d, c=OL):
    d.rectangle([0, 0, N - 1, N - 1], outline=c)


# ------------------------------------------------------------------ hojas cerradas
def closed_neutral(p):
    im, d = blank()
    d.rectangle([0, 0, 63, 63], fill=p["dk"])
    for i, x in enumerate(range(2, 62, 10)):  # tablones verticales de madera de selva
        c = p["md"] if i % 2 == 0 else mix(p["md"], p["hi"], 0.25)
        d.rectangle([x, 2, x + 8, 61], fill=c)
        d.line([(x + 1, 2), (x + 1, 61)], fill=p["hi"])
        d.line([(x + 8, 2), (x + 8, 61)], fill=p["dk"])
        for ky in (13 + i * 7 % 17, 40 + i * 5 % 11):  # nudos
            d.rectangle([x + 3, ky, x + 5, ky + 2], fill=p["dk"])
    for y in (11, 48):  # flejes de hierro viejo con remaches
        d.rectangle([2, y, 61, y + 5], fill=p["metal"])
        d.line([(2, y), (61, y)], fill=mix(p["metal"], (255, 255, 255, 255), 0.25))
        for x in range(6, 62, 10):
            d.rectangle([x, y + 2, x + 1, y + 3], fill=mix(p["metal"], (255, 255, 255, 255), 0.5))
    # cuerda y manojo de lianas colgando del dintel + musgo
    for x, ln in ((6, 18), (13, 11), (50, 22), (57, 14)):
        d.line([(x, 2), (x, 2 + ln)], fill=p["acc"])
        d.rectangle([x - 1, 2 + ln - 2, x + 1, 2 + ln], fill=mix(p["acc"], (255, 255, 255, 255), 0.25))
    for x in range(2, 62, 3):
        d.point([(x, 2 + (x * 7) % 3)], fill=p["acc"])
        d.point([(x + 1, 3 + (x * 5) % 3)], fill=mix(p["acc"], (255, 255, 255, 255), 0.3))
    rim(d)
    return im


def closed_pene(p):
    im, d = blank()
    d.rectangle([0, 0, 63, 63], fill=p["dk"])
    for lx in (2, 33):  # dos hojas de bronce con paneles
        d.rectangle([lx, 2, lx + 28, 61], fill=p["md"])
        d.rectangle([lx, 2, lx + 28, 3], fill=p["hi"])
        d.rectangle([lx + 3, 14, lx + 25, 56], outline=p["dk"], fill=mix(p["md"], p["hi"], 0.18))
        d.line([(lx + 4, 15), (lx + 24, 15)], fill=p["hi"])
        d.ellipse([lx + 8, 28, lx + 20, 40], fill=p["dk"], outline=None)
        d.ellipse([lx + 9, 29, lx + 19, 39], fill=p["hi"])
        d.ellipse([lx + 11, 31, lx + 17, 37], fill=p["md"])
        d.point([(lx + 12, 32)], fill=(255, 250, 220, 255))
    # greca griega arriba
    for x in range(3, 61, 6):
        d.line([(x, 8), (x + 3, 8), (x + 3, 10), (x + 1, 10), (x + 1, 6), (x + 5, 6)], fill=p["dk"])
    # aldaba: argolla en cada hoja
    for cx in (27, 36):
        d.ellipse([cx - 2, 44, cx + 2, 48], outline=p["hi"])
    d.rectangle([31, 2, 32, 61], fill=OL)  # juntura central
    rim(d)
    return im


def closed_vulva(p):
    im, d = blank()
    d.rectangle([0, 0, 63, 63], fill=p["md"])
    for x in range(2, 62, 12):  # tablones rosa con vetas
        d.line([(x, 2), (x, 61)], fill=p["dk"])
        d.line([(x + 1, 2), (x + 1, 61)], fill=p["hi"])
    d.rectangle([0, 0, 63, 3], fill=p["dk"])
    d.rectangle([0, 60, 63, 63], fill=p["dk"])
    # corazon-ventana de casita-hongo
    heart = [(32, 22), (26, 15), (20, 16), (18, 22), (22, 30), (32, 40), (42, 30), (46, 22), (44, 16), (38, 15)]
    d.polygon(heart, fill=p["dark"], outline=OL)
    d.polygon([(32, 24), (28, 19), (23, 20), (22, 23), (25, 29), (32, 36)], fill=mix(p["dark"], p["acc"], 0.35))
    d.point([(25, 19), (26, 18)], fill=(255, 255, 255, 255))
    # moldura crema alrededor del corazon + lunares de hongo abajo
    d.line(heart + [heart[0]], fill=p["metal"])
    for cx, cy, r in ((10, 52, 3), (24, 55, 2), (45, 53, 3), (55, 49, 2)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=p["metal"])
    # picaporte en forma de corazoncito dorado
    d.polygon([(51, 36), (49, 34), (47, 35), (47, 37), (51, 41), (55, 37), (55, 35), (53, 34)], fill=GOLD, outline=GOLD_DK)
    rim(d)
    return im


def closed_mixto(p):
    im, d = blank()
    d.rectangle([0, 0, 63, 63], fill=p["md"])
    for y in range(2, 62, 6):  # persiana de aduana: laminas horizontales
        d.rectangle([2, y, 61, y + 4], fill=mix(p["md"], p["hi"], 0.2))
        d.line([(2, y), (61, y)], fill=p["hi"])
        d.line([(2, y + 4), (61, y + 4)], fill=p["dk"])
    # franja de peligro amarilla y negra
    d.rectangle([2, 26, 61, 37], fill=p["metal"])
    for x in range(-12, 70, 8):
        d.polygon([(x, 37), (x + 6, 37), (x + 12, 26), (x + 6, 26)], fill=p["acc"])
    d.line([(2, 26), (61, 26)], fill=OL)
    d.line([(2, 37), (61, 37)], fill=OL)
    # semaforo de paso arriba + sello de ADUANA descolorido
    d.rectangle([28, 6, 35, 14], fill=p["metal"], outline=OL)
    d.ellipse([30, 7, 33, 10], fill=C("#e84a4a"))
    d.ellipse([30, 11, 33, 13], fill=mix(C("#3a6a3a"), p["metal"], 0.4))
    for i, x in enumerate(range(10, 54, 5)):
        d.line([(x, 46), (x + 2 + i % 2, 46)], fill=mix(p["hi"], (255, 255, 255, 255), 0.4))
    for x in range(14, 50, 6):
        d.line([(x, 52), (x + 3, 52)], fill=mix(p["hi"], (255, 255, 255, 255), 0.25))
    for x in (6, 56):
        for y in (8, 56):
            d.rectangle([x, y, x + 1, y + 1], fill=p["hi"])
    rim(d)
    return im


def closed_prostata(p):
    im, d = blank()
    d.rectangle([0, 0, 63, 63], fill=p["md"])
    for x in range(6, 60, 9):  # veta de la madera de nuez
        d.line([(x, 3), (x + 3, 60)], fill=mix(p["md"], p["dk"], 0.35))
    # panel de vidrio esmerilado (se ve una silueta esperando)
    d.rectangle([18, 8, 45, 36], fill=p["dk"])
    d.rectangle([20, 10, 43, 34], fill=mix(C("#d8d2d0"), p["md"], 0.2))
    d.ellipse([28, 16, 35, 23], fill=mix(C("#d8d2d0"), p["dk"], 0.45))
    d.rectangle([25, 24, 38, 34], fill=mix(C("#d8d2d0"), p["dk"], 0.45))
    # visor del numero de turno
    d.rectangle([24, 42, 39, 50], fill=p["metal"], outline=OL)
    d.rectangle([26, 44, 37, 48], fill=C("#3a0e0e"))
    d.line([(28, 46), (30, 46)], fill=p["acc"])
    d.line([(33, 44), (33, 48)], fill=p["acc"])
    d.rectangle([49, 36, 52, 39], fill=p["glow"])  # manilla
    rim(d)
    return im


def closed_censura(p):
    im, d = blank()
    d.rectangle([0, 0, 63, 63], fill=p["md"])
    # mosaico de pixelado en los bordes (la censura se come la puerta)
    for i, y in enumerate(range(2, 62, 4)):
        for x in (2, 6, 54, 58):
            c = mix(p["md"], p["hi"], ((i * 7 + x) % 5) / 6.0)
            d.rectangle([x, y, x + 3, y + 3], fill=c)
    # dos barras negras de censura tachando la hoja
    for y, w in ((14, 44), (38, 36)):
        x0 = 10 + ((N - 20 - w) // 2) if w < 44 else 10
        d.rectangle([x0, y, x0 + w - 1, y + 9], fill=p["metal"], outline=OL)
        d.line([(x0 + 2, y + 1), (x0 + w - 3, y + 1)], fill=p["hi"])
        for rx in (x0 + 3, x0 + w - 5):
            d.rectangle([rx, y + 4, rx + 1, y + 5], fill=p["hi"])
    # sello de lacre rojo con X en el centro
    d.ellipse([25, 26, 39, 40], fill=p["acc"], outline=OL)
    d.ellipse([27, 28, 33, 33], fill=mix(p["acc"], (255, 255, 255, 255), 0.35))
    d.line([(29, 30), (35, 36)], fill=(255, 235, 235, 255), width=2)
    d.line([(35, 30), (29, 36)], fill=(255, 235, 235, 255), width=2)
    rim(d)
    return im


CLOSED = {"neutral": closed_neutral, "pene": closed_pene, "vulva": closed_vulva,
          "mixto": closed_mixto, "censura": closed_censura, "prostata": closed_prostata}


# ------------------------------------------------------------------ puerta abierta: pasillo
def open_door(k, p):
    im, d = blank()
    px = im.load()
    far_l, far_r, near_l, near_r = 21, 42, 8, 55

    def edge_l(y):
        return far_l + (near_l - far_l) * (y / 63.0)

    def edge_r(y):
        return far_r + (near_r - far_r) * (y / 63.0)

    for y in range(N):
        t = 1.0 - y / 63.0  # 1 = fondo
        dark_k = (t ** 0.9) * 0.92
        fl = mix(p["floor"], p["dark"], dark_k)
        wl = mix(p["jm"], p["dark"], dark_k * 0.95)
        for x in range(N):
            if x < edge_l(y):
                px[x, y] = dk(wl, 0.78)
            elif x > edge_r(y):
                px[x, y] = dk(wl, 0.62)
            else:
                px[x, y] = fl
    # suelo: juntas de baldosa en perspectiva
    seams = [60, 52, 45, 39, 34, 30, 26, 23, 20, 17, 14, 12, 10, 8]
    for y in seams:
        t = 1.0 - y / 63.0
        c = mix(dk(p["floor"], 0.7), p["dark"], t * 0.9)
        d.line([(edge_l(y) + 1, y), (edge_r(y) - 1, y)], fill=c)
        # tambien sobre los muros laterales (hiladas)
        cw = mix(dk(p["jm"], 0.55), p["dark"], t * 0.9)
        d.line([(0, y), (edge_l(y) - 1, y)], fill=cw)
        d.line([(edge_r(y) + 1, y), (63, y)], fill=dk(cw, 0.85))
    # aristas de union muro/suelo
    d.line([(near_l, 63), (far_l, 0)], fill=mix(p["hi"], p["dark"], 0.45))
    d.line([(near_r, 63), (far_r, 0)], fill=mix(p["hi"], p["dark"], 0.65))
    # resplandor de la sala vecina al fondo
    for y in range(0, 7):
        a = (1 - y / 7.0) * 0.8
        for x in range(int(far_l) + 1, int(far_r)):
            px[x, y] = mix(px[x, y], p["glow"], a * (1 - abs(x - 31.5) / 14.0 * 0.5))
    # sombra del dintel arriba de todo (grosor del muro)
    d.rectangle([0, 0, 63, 1], fill=p["dark"])
    # detalles por reino
    if k == "neutral":
        for x, ln in ((10, 12), (14, 7), (50, 10)):
            d.line([(x, 56), (x, 56 - ln)], fill=p["acc"])
        d.line([(30, 63), (34, 40)], fill=mix(p["acc"], p["floor"], 0.6))
        for x in range(24, 41, 5):
            d.point([(x, 58 - (x % 4))], fill=p["acc"])
    elif k == "pene":
        for y in (56, 44, 34):  # relieves de greca dorada a lo largo del muro
            t = 1.0 - y / 63.0
            c = mix(p["hi"], p["dark"], t * 0.8)
            d.line([(max(1, edge_l(y) - 6), y - 2), (edge_l(y) - 2, y - 2)], fill=c)
            d.line([(edge_r(y) + 2, y - 2), (min(62, edge_r(y) + 6), y - 2)], fill=c)
        d.line([(31, 63), (31, 20)], fill=mix(p["hi"], p["floor"], 0.4))
    elif k == "vulva":
        for y in (58, 46, 36):  # alfombra de terciopelo con corazoncitos
            t = 1.0 - y / 63.0
            c = mix(p["acc"], p["dark"], t * 0.85)
            d.rectangle([int(edge_l(y)) + 6, y - 1, int(edge_r(y)) - 6, y], fill=c)
        d.rectangle([29, 59, 34, 60], fill=mix(p["glow"], p["floor"], 0.3))
        d.point([(30, 58), (33, 58), (31, 60), (32, 60)], fill=p["acc"])
    elif k == "mixto":
        for y in range(63, 4, -2):  # franjas de peligro en la base de los muros
            if (y // 2) % 2 == 0:
                t = 1.0 - y / 63.0
                c = mix(p["acc"], p["dark"], t * 0.85)
                d.point([(int(edge_l(y)) - 1, y), (int(edge_l(y)) - 2, y)], fill=c)
                d.point([(int(edge_r(y)) + 1, y), (int(edge_r(y)) + 2, y)], fill=c)
        for y in (56, 42, 30):  # flechas de la cinta de aduana
            t = 1.0 - y / 63.0
            c = mix(p["acc"], p["dark"], t * 0.85)
            d.line([(27, y), (31, y - 4), (35, y)], fill=c)
    elif k == "censura":
        for i, y in enumerate((50, 38, 28, 20)):  # pixelado negro comiendo el muro
            t = 1.0 - y / 63.0
            c = mix(p["metal"], p["dark"], t * 0.7)
            w = int(5 - i)
            d.rectangle([int(edge_l(y)) - w - 2, y, int(edge_l(y)) - 2, y + 2], fill=c)
            d.rectangle([int(edge_r(y)) + 2, y + 1, int(edge_r(y)) + w + 2, y + 3], fill=c)
        d.rectangle([22, 6, 41, 8], fill=p["metal"])  # barra negra a medio bajar al fondo
    # contorno
    rim(d)
    return im


# ------------------------------------------------------------------ cerrojo y sellado
def add_lock(im, p):
    d = ImageDraw.Draw(im)
    d.rectangle([20, 29, 43, 34], fill=p["dk"])  # placa tras el candado
    d.arc([26, 17, 37, 31], 180, 360, fill=CHAIN, width=2)
    d.line([(27, 24), (27, 30)], fill=CHAIN, width=2)
    d.line([(36, 24), (36, 30)], fill=CHAIN, width=2)
    d.rectangle([23, 29, 40, 44], fill=GOLD, outline=OL)
    d.rectangle([24, 30, 39, 31], fill=mix(GOLD, (255, 255, 255, 255), 0.5))
    d.rectangle([24, 42, 39, 43], fill=GOLD_DK)
    d.ellipse([29, 34, 34, 39], fill=OL)
    d.rectangle([31, 38, 32, 42], fill=OL)
    return im


def add_chains(im, p):
    d = ImageDraw.Draw(im)
    for a, b in (((1, 1), (62, 62)), ((62, 1), (1, 62))):
        d.line([a, b], fill=CHAIN_DK, width=5)
        d.line([a, b], fill=CHAIN, width=3)
        # eslabones: puntos oscuros espaciados sobre la cadena
        for i in range(1, 12):
            x = a[0] + (b[0] - a[0]) * i / 12.0
            y = a[1] + (b[1] - a[1]) * i / 12.0
            d.rectangle([int(x) - 1, int(y) - 1, int(x), int(y)], fill=CHAIN_DK)
    d.ellipse([23, 23, 40, 40], fill=p["acc"], outline=OL)
    d.ellipse([27, 27, 36, 36], fill=GOLD, outline=GOLD_DK)
    d.ellipse([28, 28, 31, 31], fill=(255, 250, 200, 255))
    return im


def rim_final(im):
    ImageDraw.Draw(im).rectangle([0, 0, N - 1, N - 1], outline=OL)
    return im


def build(k):
    p = PAL[k]
    base = {"closed": CLOSED[k](p), "open": open_door(k, p)}
    base["locked"] = add_lock(base["closed"].copy(), p)
    base["sealed"] = add_chains(base["closed"].copy(), p)
    for st in base:
        base[st] = rim_final(base[st])
    return base


def rotated(im, direction):
    if direction == "up":
        return im
    if direction == "down":
        return im.rotate(180)
    if direction == "left":
        return im.rotate(90)
    return im.rotate(-90)


def main():
    kingdoms = sys.argv[1:] or KINGDOMS
    for k in kingdoms:
        out = OUT / k
        out.mkdir(parents=True, exist_ok=True)
        for st, im in build(k).items():
            for dr in ("up", "down", "left", "right"):
                rotated(im, dr).save(out / f"door_{dr}_{st}.png")
        print("ok", k)


if __name__ == "__main__":
    main()
