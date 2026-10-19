"""Genera el arte de la educacion 4a (assets/sprites/edu/): la doctora provisoria (YA NO SE USA: ahora es la matrona, tools/gen_matrona_art.py; se conserva como referencia de diseno) y los props
del consultorio y de Mito o Verdad (src/edu/consultorio.gd y mito_verdad.gd).

Uso: python3 tools/gen_edu_art.py

Arte pixel a 1x (1 px de arte = 1 px de mundo). Luz arriba-izquierda, contorno oscuro comun
(como gen_obstacle_art.py). Piezas:
  doctora_idle_0..3   Dra. Preventina, 44x62, idle de 4 cuadros (respira, brilla y parpadea)
  box_condon          caja de preservativos de bolsillo (rosa, con sobrecitos)
  vacuna              bandeja con jeringa y frasco verde de la vacuna VPH
  poster              cartel de salud sexual con corazon y escudo
  placa               placa de piedra de Mito o Verdad (signo de pregunta dorado)
  piedra_verdad / piedra_mito   piedras de respuesta (verde con visto, roja con cruz)
Todo es determinista. El gris/color lo pone el shader de censura del juego (Censor).
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/edu"
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


class Pal:
    """Cuatro tonos: claro, base, sombra, sombra profunda."""

    def __init__(self, base):
        b = C(base) if isinstance(base, str) else base
        self.base = b
        self.hi = mix(b, WHITE, 0.4)
        self.lo = dk(b, 0.78)
        self.deep = dk(b, 0.56)


def new(w, h):
    return Image.new("RGBA", (w, h), CLEAR)


def px(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(im, x, y, c)


def line(im, x0, y0, x1, y1, c):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        px(im, round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n), c)


# ------------------------------------------------------------------ formas con luz y contorno
def ell(cx, cy, rx, ry):
    return lambda x, y: ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0


def box(x0, y0, x1, y1, r=0):
    """Rectangulo con esquinas cortadas r px."""
    def f(x, y):
        if not (x0 <= x <= x1 and y0 <= y <= y1):
            return False
        dx = min(x - x0, x1 - x)
        dy = min(y - y0, y1 - y)
        return dx + dy >= r if (dx < r and dy < r) else True
    return f


def poly(pts):
    def f(x, y):
        inside = False
        n = len(pts)
        px_, py_ = x + 0.5, y + 0.5
        j = n - 1
        for i in range(n):
            xi, yi = pts[i]
            xj, yj = pts[j]
            if (yi > py_) != (yj > py_) and px_ < (xj - xi) * (py_ - yi) / (yj - yi) + xi:
                inside = not inside
            j = i
        return inside
    return f


def union(*fs):
    return lambda x, y: any(f(x, y) for f in fs)


def part(im, fn, pal, outline=True):
    """Pinta una pieza: relleno con borde claro arriba-izquierda y oscuro abajo-derecha,
    y su contorno oscuro (pisa lo de debajo: separa las piezas como en los enemigos)."""
    W, H = im.size
    if outline:
        for y in range(H):
            for x in range(W):
                if not fn(x, y) and any(fn(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    im.putpixel((x, y), OL)
    for y in range(H):
        for x in range(W):
            if not fn(x, y):
                continue
            hi1 = not (fn(x - 1, y) and fn(x, y - 1))
            lo1 = not (fn(x + 1, y) and fn(x, y + 1))
            lo2 = not (fn(x + 2, y) and fn(x, y + 2))
            c = pal.deep if lo1 else pal.hi if hi1 else pal.lo if lo2 else pal.base
            im.putpixel((x, y), c)


def save(im, name):
    OUT.mkdir(parents=True, exist_ok=True)
    im.save(OUT / (name + ".png"))


# ------------------------------------------------------------------ Dra. Preventina
SKIN = Pal("f0b48c")
COAT = Pal("f4f1ea")
SCRUB = Pal("3fb5a5")
HAIR = Pal("7a3a6a")
SHOE = Pal("2f6f8f")
STET = Pal("9aa0ae")
RED = C("e0453f")
GOLD = C("ffd75a")


def doctora(frame):
    """Cuadro de idle: 0 base, 1 respira (sube 1 px), 2 base con brillo en el espejo, 3 parpadea."""
    W, H = 44, 62
    im = new(W, H)
    up = 1 if frame == 1 else 0       # pecho y cabeza suben al inhalar
    blink = frame == 3
    glint = frame == 2
    # zapatos y piernas
    part(im, box(10, 56, 19, 60, 2), SHOE)
    part(im, box(24, 56, 33, 60, 2), SHOE)
    part(im, box(13, 50, 18, 57), SCRUB)
    part(im, box(25, 50, 30, 57), SCRUB)
    # bata blanca, acampanada
    part(im, poly([(8, 31 - up), (36, 31 - up), (39, 54), (5, 54)]), COAT)
    # escote de pijama quirurgico y cruz roja en el bolsillo
    part(im, poly([(17, 31 - up), (27, 31 - up), (22, 42 - up)]), SCRUB, outline=False)
    rect(im, 11, 41 - up, 17, 47 - up, COAT.lo)
    rect(im, 14, 42 - up, 14, 46 - up, RED)
    rect(im, 12, 44 - up, 16, 44 - up, RED)
    # linea central y botones de la bata
    line(im, 22, 43 - up, 22, 53, COAT.deep)
    px(im, 21, 46 - up, GOLD)
    px(im, 21, 51 - up, GOLD)
    # brazo izquierdo (nuestra izquierda) con la carpeta
    part(im, ell(7, 40 - up, 4, 8), COAT)
    part(im, ell(7, 47 - up, 3, 3), SKIN)
    part(im, box(1, 43 - up, 9, 56 - up, 1), Pal("c99a5a"))
    rect(im, 3, 46 - up, 7, 54 - up, C("fff4e0"))
    for yy in (48, 50):
        rect(im, 4, yy - up, 6, yy - up, C("7fb0e0"))
    px(im, 6, 52 - up, RED)
    px(im, 5, 53 - up, RED)
    px(im, 4, 52 - up, RED)
    # brazo derecho levantado, saluda
    part(im, ell(37, 39 - up, 4, 8), COAT)
    part(im, ell(39, 31 - up, 3, 3), SKIN)
    # estetoscopio colgando del cuello
    part(im, poly([(14, 30 - up), (17, 30 - up), (19, 38 - up), (25, 38 - up), (27, 30 - up), (30, 30 - up),
                   (27, 41 - up), (17, 41 - up)]), STET, outline=False)
    part(im, ell(22, 42 - up, 2.6, 2.6), Pal("d8dde8"))
    # cabeza grande caricaturesca
    hy = 15 - up
    part(im, ell(22, hy, 15, 14), SKIN)
    # chongo y flequillo
    part(im, ell(22, 3 - up, 5, 4), HAIR)
    part(im, poly([(7, hy - 2), (9, hy - 10), (16, hy - 13), (28, hy - 13), (35, hy - 10), (37, hy - 2),
                   (33, hy - 7), (26, hy - 8), (18, hy - 8), (11, hy - 7)]), HAIR)
    # espejo frontal de medico
    part(im, ell(22, hy - 9, 4, 3.3), Pal("dfe7f0"))
    px(im, 21, hy - 10, WHITE)
    px(im, 20, hy - 9, WHITE)
    if glint:
        for dx, dy in ((0, -2), (0, 2), (-2, 0), (2, 0)):
            px(im, 21 + dx, hy - 10 + dy, WHITE)
        px(im, 21, hy - 10, GOLD)
    # lentes redondos
    for cx in (16, 28):
        part(im, ell(cx, hy + 1, 4.6, 4.2), Pal("eaf4ff"))
    line(im, 20, hy, 24, hy, OL)
    # ojos
    for cx in (16, 28):
        if blink:
            line(im, cx - 2, hy + 1, cx + 2, hy + 1, OL)
        else:
            rect(im, cx - 1, hy - 1, cx + 1, hy + 3, OL)
            px(im, cx - 1, hy - 1, WHITE)
    # cejas, mejillas sonrojadas y sonrisa picara
    line(im, 12, hy - 4, 19, hy - 5, HAIR.deep)
    line(im, 25, hy - 5, 32, hy - 4, HAIR.deep)
    rect(im, 10, hy + 6, 13, hy + 7, mix(SKIN.base, RED, 0.45))
    rect(im, 31, hy + 6, 34, hy + 7, mix(SKIN.base, RED, 0.45))
    line(im, 18, hy + 8, 26, hy + 8, RED)
    line(im, 19, hy + 9, 25, hy + 9, RED)
    px(im, 17, hy + 7, RED)
    px(im, 27, hy + 7, RED)
    px(im, 21, hy + 6, SKIN.deep)  # nariz
    save(im, "doctora_idle_%d" % frame)


# ------------------------------------------------------------------ props
def caja_condon():
    im = new(38, 34)
    pink = Pal("e87fa8")
    part(im, box(3, 14, 34, 30, 2), pink)
    part(im, box(2, 8, 35, 15, 2), Pal("f7a3c2"))
    part(im, box(10, 18, 27, 27, 1), Pal("fff4e0"), outline=False)
    line(im, 17, 22, 20, 22, pink.lo)
    for x in (14, 21):  # corazoncitos
        px(im, x, 20, RED)
        px(im, x + 2, 20, RED)
        px(im, x + 1, 19, RED)
        px(im, x + 1, 21, RED)
    # sobrecitos asomando por la tapa
    for i, (x, col) in enumerate(((8, "7fe0a0"), (15, "ffd75a"), (22, "7fc4ff"))):
        part(im, poly([(x, 9), (x + 6, 6 - i % 2), (x + 8, 10 - i % 2), (x + 2, 12)]), Pal(col))
    save(im, "box_condon")


def vacuna():
    im = new(52, 30)
    part(im, box(1, 14, 50, 27, 2), Pal("e8eef2"))      # bandeja
    # jeringa horizontal
    part(im, box(10, 16, 32, 22, 1), Pal("cfe8f0"))
    rect(im, 12, 18, 24, 20, C("7fe0a0"))
    part(im, box(5, 14, 9, 24), Pal("b8b2a0"))
    part(im, box(32, 18, 35, 20), Pal("b8b2a0"))
    line(im, 36, 19, 41, 19, C("c9c2b0"))
    # frasco verde con tapa y cruz
    part(im, box(38, 4, 48, 15, 2), Pal("5fd08a"))
    part(im, box(39, 1, 47, 5, 1), Pal("d9d4c4"))
    rect(im, 42, 8, 44, 12, WHITE)
    rect(im, 41, 10, 45, 10, WHITE)
    save(im, "vacuna")


def poster():
    im = new(32, 40)
    part(im, box(2, 2, 29, 37, 1), Pal("efe3b8"))
    rect(im, 5, 5, 26, 9, C("b08d4a"))
    line(im, 8, 7, 23, 7, C("efe3b8"))
    heart = union(ell(12, 17, 4.2, 4), ell(19.5, 17, 4.2, 4), poly([(7.5, 18), (23.5, 18), (15.5, 27)]))
    part(im, heart, Pal("e0453f"))
    px(im, 11, 15, WHITE)
    px(im, 12, 15, WHITE)
    part(im, poly([(12, 14), (19, 14), (19, 21), (15.5, 24), (12, 21)]), Pal("3fb5a5"))
    rect(im, 15, 16, 16, 22, WHITE)
    rect(im, 13, 18, 18, 19, WHITE)
    for i, w in enumerate((20, 17, 20, 12)):
        rect(im, 5, 29 + i * 2, 4 + w, 29 + i * 2, C("8a8494"))
    part(im, ell(15.5, 3, 2, 2), Pal("d94a4a"))  # chinche
    save(im, "poster")


def placa():
    im = new(40, 50)
    part(im, box(14, 38, 25, 48, 1), Pal("5a5662"))
    part(im, box(3, 2, 36, 40, 5), Pal("8a8494"))
    part(im, box(7, 6, 32, 36, 3), Pal("a8a2b4"), outline=False)
    # signo de pregunta dorado
    for x, y in ((14, 11), (15, 10), (16, 9), (17, 9), (18, 9), (19, 9), (20, 10), (21, 11), (21, 12), (21, 13),
                 (20, 14), (19, 15), (18, 16), (18, 17), (18, 18)):
        rect(im, x, y, x + 2, y + 1, GOLD)
    rect(im, 18, 22, 20, 24, GOLD)
    for x, y in ((9, 33), (30, 33), (9, 9), (30, 9)):  # remaches
        rect(im, x, y, x + 1, y + 1, C("5a5662"))
    save(im, "placa")


def piedra(name, col, mark):
    im = new(32, 26)
    part(im, poly([(2, 22), (4, 9), (12, 3), (22, 3), (29, 9), (30, 22), (26, 24), (6, 24)]), Pal(col))
    if mark == "ok":
        for i in range(5):
            rect(im, 9 + i, 13 + i, 10 + i, 14 + i, WHITE)
        for i in range(9):
            rect(im, 14 + i, 17 - i, 15 + i, 18 - i, WHITE)
    else:
        for i in range(10):
            rect(im, 10 + i, 7 + i, 11 + i, 8 + i, WHITE)
            rect(im, 19 - i, 7 + i, 20 - i, 8 + i, WHITE)
    save(im, name)


def main():
    for f in range(4):
        doctora(f)
    caja_condon()
    vacuna()
    poster()
    placa()
    piedra("piedra_verdad", "5fd08a", "ok")
    piedra("piedra_mito", "e0605a", "x")
    print("listo:", OUT)


if __name__ == "__main__":
    main()
