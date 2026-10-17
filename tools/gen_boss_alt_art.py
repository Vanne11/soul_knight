"""Sprites de los jefes ALTERNATIVOS (etapa 6c), por script, sin APIs de IA: 80x120 como los
jefes actuales (se dibuja a 40x60 y se amplia x2 con vecino mas cercano: pixeles gruesos) +
SpriteFrames .tres. Tambien las ilustraciones de presentacion a pantalla completa
(assets/sprites/ui/bosses/<jefe>.png, 320x180) que se generan aqui mismo con el retrato
agrandado sobre un fondo del reino.

Uso: python3 tools/gen_boss_alt_art.py [jefe ...]   (sin args = los cinco)
     python3 tools/gen_boss_alt_art.py --no-intro    (solo sprites)
Jefes: afeitadora don_viagra diu_cosmico prostata algoritmo

HUECO PARA ILUSTRACION GEMINI: la presentacion carga assets/sprites/ui/bosses/<jefe>.png.
Para sustituir la de script por una de Gemini basta con generar un PNG pixelado 320x180 con el
mismo nombre (tools/gen_boss_art.py: agregar el jefe a su dict BOSSES con el prompt y
correrlo; mueve la imagen a ui/bosses). Los textos NO van en la imagen: el nombre lo pone el juego.
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_enemy_art as G  # noqa: E402

OUT = G.OUT
ROOT = G.ROOT
OL = G.OUTLINE
W, H = 40, 60

# paleta
STEEL = (176, 190, 214, 255)
STEEL_HI = (232, 240, 252, 255)
STEEL_DK = (96, 108, 140, 255)
NAVY = (46, 70, 134, 255)
NAVY_HI = (84, 120, 196, 255)
LED = (90, 255, 140, 255)
BLUE = (60, 132, 232, 255)
BLUE_HI = (140, 196, 255, 255)
BLUE_DK = (30, 78, 170, 255)
WHITE = (250, 250, 255, 255)
COPPER = (214, 128, 62, 255)
COPPER_HI = (255, 190, 120, 255)
COPPER_DK = (146, 78, 34, 255)
VIOLET = (170, 120, 255, 255)
VIOLET_HI = (222, 196, 255, 255)
NUT = (220, 150, 108, 255)
NUT_HI = (248, 196, 156, 255)
NUT_DK = (160, 96, 70, 255)
TIE = (110, 120, 150, 255)
PAPER = (252, 244, 214, 255)
BEZEL = (62, 66, 84, 255)
BEZEL_HI = (108, 114, 140, 255)
SCREEN = (176, 224, 255, 255)
SCREEN_DK = (110, 170, 230, 255)
RED = (230, 50, 60, 255)
BLACK = (24, 20, 30, 255)


def new():
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def up(im):
    """Contorno de 1 px a baja resolucion y ampliacion x2 (contorno de 2 px)."""
    return G.outline(im).resize((W * 2, H * 2), Image.NEAREST)


def legs(d, bob, step, xs=(14, 24), top=50, col=STEEL_DK):
    ups = (2 if step == 1 else 0, 2 if step == 2 else 0)
    for x, u in zip(xs, ups):
        d.rectangle([x, top + bob - u, x + 2, 57 - u], fill=col)
        d.rectangle([x - 1, 57 - u, x + 3, 58 - u], fill=BEZEL)


def arm(d, x, y, dx, dy, col):
    d.line([(x, y), (x + dx, y + dy)], fill=col, width=2)
    d.rectangle([x + dx - 1, y + dy - 1, x + dx + 1, y + dy + 1], fill=col)


def frames(draw):
    idle = draw()
    walk = [draw(bob=0, step=1), draw(bob=-1, step=0), draw(bob=0, step=2), draw(bob=-1, step=0)]
    attack = [draw(atk=i + 1, mouth="open") for i in range(3)]
    hurt = [G.tint(draw(eyes="hurt", mouth="open"), (255, 60, 70), 0.55),
            G.tint(draw(eyes="hurt"), (255, 255, 255), 0.4)]
    dead = draw(eyes="x", mouth="open")
    death = [G.death_frame(dead, i, center=(20, 54)) for i in range(4)]
    out = {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}
    return {k: [up(f) for f in v] for k, v in out.items()}


# ------------------------------------------------------------------ la afeitadora electrica
def afeitadora(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    legs(d, bob, step, (13, 25), 50)
    # cable negro con enchufe
    d.line([(31, 44 + bob), (36, 47 + bob), (37, 53)], fill=BLACK, width=1)
    d.rectangle([35, 53, 38, 56], fill=STEEL_HI)
    d.line([(36, 56), (36, 58)], fill=STEEL_DK)
    d.line([(38, 56), (38, 58)], fill=STEEL_DK)
    # cuerpo azul
    d.rounded_rectangle([8, 22 + bob, 32, 52 + bob], radius=6, fill=NAVY)
    d.rounded_rectangle([10, 24 + bob, 16, 34 + bob], radius=2, fill=NAVY_HI)
    d.rectangle([27, 28 + bob, 30, 48 + bob], fill=(30, 48, 100, 255))
    d.ellipse([27, 44 + bob, 31, 48 + bob], fill=LED)       # led de carga
    # cabezal plateado con rejilla (vibra al atacar)
    sh = (0, -1, 1, -1)[atk] if atk else 0
    d.rounded_rectangle([6 + sh, 6 + bob, 34 + sh, 23 + bob], radius=5, fill=STEEL)
    d.rounded_rectangle([8 + sh, 7 + bob, 20 + sh, 11 + bob], radius=2, fill=STEEL_HI)
    for i in range(5):
        x = 10 + i * 5 + sh
        d.line([(x, 14 + bob), (x, 20 + bob)], fill=STEEL_DK)
    d.line([(8 + sh, 13 + bob), (32 + sh, 13 + bob)], fill=STEEL_DK)
    if atk:  # cuchillas asomando
        for i in range(5):
            x = 10 + i * 5 + sh
            d.line([(x, 4 + bob - atk), (x, 6 + bob)], fill=STEEL_HI)
        d.ellipse([16, 2 + bob, 24, 8 + bob], outline=STEEL_HI)
    arm(d, 8, 36 + bob, -3, 5 - (atk > 0) * 5, NAVY_HI)
    arm(d, 32, 36 + bob, 3, 5 - (atk > 0) * 5, NAVY_HI)
    G.face(d, 19, 35 + bob, eyes, mouth, gap=3)
    return im


# ------------------------------------------------------------------ don viagra
def don_viagra(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    legs(d, bob, step, (15, 23), 51, BLUE_DK)
    # pastilla romboide
    r = atk
    pts = [(20, 7 + bob - r), (37 + r, 29 + bob), (20, 54 + bob + r // 2), (3 - r, 29 + bob)]
    d.polygon(pts, fill=BLUE)
    d.polygon([(20, 10 + bob), (33, 29 + bob), (20, 29 + bob)], fill=BLUE_DK)     # mitad en sombra
    d.polygon([(20, 10 + bob), (8, 28 + bob), (20, 28 + bob)], fill=BLUE_HI)      # brillo
    d.line([(20, 7 + bob - r), (20, 54 + bob)], fill=BLUE_DK)
    # sombrero de copa pequeno y monoculo (Don)
    d.rectangle([14, 2 + bob - r, 26, 6 + bob - r], fill=BLACK)
    d.rectangle([11, 6 + bob - r, 29, 7 + bob - r], fill=BLACK)
    d.rectangle([14, 5 + bob - r, 26, 5 + bob - r], fill=RED)
    # bigote
    d.line([(14, 36 + bob), (19, 38 + bob), (20, 36 + bob), (21, 38 + bob), (26, 36 + bob)], fill=BLACK, width=1)
    G.face(d, 20, 26 + bob, eyes, "none", gap=3)
    d.ellipse([22, 23 + bob, 28, 29 + bob], outline=(255, 214, 80, 255))          # monoculo
    if mouth == "open":
        d.rectangle([18, 39 + bob, 21, 42 + bob], fill=G.MOUTH)
    # brazos finitos
    arm(d, 5, 30 + bob, -4, 4 - (atk > 0) * 10, BLUE_DK)
    arm(d, 35, 30 + bob, 4, 4 - (atk > 0) * 10, BLUE_DK)
    if atk:  # destellos
        for (x, y) in [(3, 6), (36, 8), (38, 44), (2, 46)]:
            d.line([(x - 2, y), (x + 2, y)], fill=WHITE)
            d.line([(x, y - 2), (x, y + 2)], fill=WHITE)
    return im


# ------------------------------------------------------------------ el diu cosmico
def diu_cosmico(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    # hilos de nylon (se mueven al caminar)
    w = (0, 2, 0, -2)[step if step < 3 else 0] if step else 0
    d.line([(18, 52 + bob), (16 + w, 57)], fill=WHITE)
    d.line([(22, 52 + bob), (24 - w, 57)], fill=WHITE)
    # tallo de cobre
    d.rounded_rectangle([14, 14 + bob, 26, 53 + bob], radius=4, fill=COPPER)
    d.rectangle([16, 16 + bob, 18, 50 + bob], fill=COPPER_HI)
    d.rectangle([24, 16 + bob, 25, 50 + bob], fill=COPPER_DK)
    # brazos de la T (se levantan al atacar)
    a = atk * 2
    d.polygon([(14, 16 + bob), (3, 12 + bob - a), (2, 8 + bob - a), (6, 7 + bob - a), (15, 11 + bob)], fill=COPPER)
    d.polygon([(26, 16 + bob), (37, 12 + bob - a), (38, 8 + bob - a), (34, 7 + bob - a), (25, 11 + bob)], fill=COPPER)
    d.ellipse([0, 5 + bob - a, 5, 10 + bob - a], fill=COPPER_HI)
    d.ellipse([35, 5 + bob - a, 40, 10 + bob - a], fill=COPPER_HI)
    d.line([(6, 9 + bob - a), (14, 13 + bob)], fill=COPPER_HI)
    # estrellas moradas alrededor
    for i, (x, y) in enumerate([(5, 30), (35, 26), (7, 46), (34, 44)]):
        if (i + atk + step) % 2 == 0 or atk:
            d.line([(x - 2, y + bob), (x + 2, y + bob)], fill=VIOLET)
            d.line([(x, y - 2 + bob), (x, y + 2 + bob)], fill=VIOLET)
    d.ellipse([17, 8 + bob, 23, 14 + bob], fill=VIOLET_HI)    # gema en la union
    G.face(d, 20, 30 + bob, eyes, mouth, gap=3)
    return im


# ------------------------------------------------------------------ la prostata burocratica
def prostata(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    legs(d, bob, step, (14, 23), 50, NUT_DK)
    # nuez
    d.ellipse([6, 12 + bob, 34, 52 + bob], fill=NUT)
    d.ellipse([9, 15 + bob, 18, 26 + bob], fill=NUT_HI)
    d.line([(20, 14 + bob), (20, 50 + bob)], fill=NUT_DK)                  # surco central
    for (x, y) in [(10, 34), (13, 44), (28, 34), (26, 44), (31, 26)]:
        d.line([(x, y + bob), (x + 3, y + 2 + bob)], fill=NUT_DK)
    # pelo peinado de lado
    d.line([(12, 13 + bob), (20, 10 + bob), (28, 14 + bob)], fill=BLACK, width=2)
    # corbata
    d.polygon([(18, 40 + bob), (22, 40 + bob), (23, 52 + bob), (20, 54 + bob), (17, 52 + bob)], fill=TIE)
    d.rectangle([18, 39 + bob, 22, 41 + bob], fill=(80, 90, 120, 255))
    # gafas redondas
    for ex in (14, 22):
        d.ellipse([ex, 24 + bob, ex + 6, 30 + bob], outline=BLACK)
    d.line([(20, 27 + bob), (22, 27 + bob)], fill=BLACK)
    G.face(d, 20, 28 + bob, eyes, mouth, gap=3)
    # carnet y cartel con numero (se levanta al atacar)
    d.rectangle([9, 38 + bob, 14, 43 + bob], fill=WHITE)
    d.rectangle([10, 39 + bob, 13, 40 + bob], fill=BLUE)
    sy = 36 - atk * 4
    arm(d, 33, 36 + bob, 3, sy - 36, NUT_DK)
    d.rectangle([32, sy - 6 + bob, 40, sy + 2 + bob], fill=PAPER)
    d.line([(34, sy - 3 + bob), (38, sy - 3 + bob)], fill=RED)
    d.line([(34, sy - 1 + bob), (37, sy - 1 + bob)], fill=BLACK)
    arm(d, 7, 36 + bob, -3, 4, NUT_DK)
    return im


# ------------------------------------------------------------------ el algoritmo moderador
def algoritmo(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    legs(d, bob, step, (13, 25), 50, BEZEL_HI)
    # antena
    d.line([(20, 4 + bob), (20, 10 + bob)], fill=BEZEL_HI)
    d.ellipse([18, 1 + bob, 22, 5 + bob], fill=RED if atk or step == 1 else (120, 40, 50, 255))
    # monitor
    d.rounded_rectangle([5, 10 + bob, 35, 50 + bob], radius=4, fill=BEZEL)
    d.rectangle([8, 13 + bob, 32, 43 + bob], fill=SCREEN)
    d.rectangle([8, 13 + bob, 32, 18 + bob], fill=SCREEN_DK)
    for y in range(20, 42, 4):
        d.line([(8, y + bob), (32, y + bob)], fill=(150, 205, 245, 255))   # lineas de escaneo
    d.rectangle([14, 46 + bob, 26, 48 + bob], fill=BEZEL_HI)
    # ojo unico
    d.ellipse([11, 20 + bob, 29, 38 + bob], fill=WHITE)
    px = 20 + (atk - 1) * 2 if atk else 20
    iris = RED if eyes != "x" else (120, 120, 130, 255)
    d.ellipse([px - 5, 25 + bob, px + 5, 35 + bob], fill=iris)
    if eyes == "x":
        d.line([(px - 4, 26 + bob), (px + 4, 34 + bob)], fill=BLACK)
        d.line([(px - 4, 34 + bob), (px + 4, 26 + bob)], fill=BLACK)
    elif eyes == "hurt":
        d.line([(12, 28 + bob), (28, 28 + bob)], fill=BLACK, width=2)   # parpadeo forzado
        d.rectangle([11, 28 + bob, 29, 38 + bob], fill=SCREEN)
        d.line([(12, 29 + bob), (28, 29 + bob)], fill=BLACK, width=2)
    else:
        d.ellipse([px - 2, 28 + bob, px + 2, 32 + bob], fill=BLACK)
        d.ellipse([px - 4, 26 + bob, px - 2, 28 + bob], fill=WHITE)
        d.line([(11, 22 + bob), (29, 25 + bob)], fill=BLACK, width=1)    # ceja severa
    if atk:  # signo de "reportado"
        d.polygon([(30, 2 + bob), (38, 16 + bob), (22, 16 + bob)], fill=RED)
        d.line([(30, 6 + bob), (30, 11 + bob)], fill=WHITE)
        d.point((30, 13 + bob), fill=WHITE)
    arm(d, 5, 30 + bob, -3, 5, BEZEL_HI)
    arm(d, 35, 30 + bob, 3, 5, BEZEL_HI)
    return im


BOSSES = {
    "afeitadora": afeitadora,
    "don_viagra": don_viagra,
    "diu_cosmico": diu_cosmico,
    "prostata": prostata,
    "algoritmo": algoritmo,
}

# ------------------------------------------------------------------ presentacion 320x180
# fondo por reino (colores del degradado y de los detalles) + retrato agrandado x6 con sombra.
BG = {
    "afeitadora": ((18, 52, 38), (60, 150, 100), (200, 230, 150)),
    "don_viagra": ((20, 36, 80), (70, 120, 210), (230, 240, 255)),
    "diu_cosmico": ((30, 12, 56), (120, 60, 160), (255, 190, 120)),
    "prostata": ((60, 40, 36), (170, 130, 100), (240, 220, 160)),
    "algoritmo": ((18, 18, 28), (70, 80, 110), (230, 60, 70)),
}


def intro_art(name):
    rng = random.Random(name)
    top, bot, acc = BG[name]
    im = Image.new("RGBA", (320, 180), (0, 0, 0, 255))
    px = im.load()
    for y in range(180):
        t = y / 179
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(320):
            px[x, y] = c + (255,)
    d = ImageDraw.Draw(im)
    # detalles del escenario
    for _ in range(40):
        x, y = rng.randrange(320), rng.randrange(0, 120)
        s = rng.choice([1, 1, 2, 3])
        if name == "algoritmo":
            d.rectangle([x, y, x + s * 4, y + s * 4], fill=(140, 140, 150, 255) if rng.random() < 0.5 else (20, 20, 26, 255))
        elif name == "diu_cosmico":
            d.line([(x - s, y), (x + s, y)], fill=acc + (255,))
            d.line([(x, y - s), (x, y + s)], fill=acc + (255,))
        elif name == "don_viagra":
            d.ellipse([x, y, x + s * 3, y + s * 3], outline=(220, 235, 255, 255))
        elif name == "prostata":
            d.rectangle([x, y, x + 3 * s, y + 4 * s], fill=(250, 244, 214, 255))
        else:
            d.line([(x, y), (x + rng.randrange(-3, 4), y + 6 * s)], fill=(40, 110, 80, 255), width=1)
    d.rectangle([0, 138, 320, 180], fill=tuple(max(0, c - 40) for c in bot) + (255,))
    # retrato: sprite idle ampliado x1.45 (sobre el 80x120 ya ampliado) con sombra
    spr = Image.open(OUT / f"{name}_idle_00.png").convert("RGBA")
    spr = spr.resize((spr.width * 11 // 5, spr.height * 11 // 5), Image.NEAREST)  # x2.2 -> ~176x264? recortado a la escena
    spr = spr.crop(spr.getbbox())
    k = 150 / spr.height
    spr = spr.resize((max(1, int(spr.width * k)), 150), Image.NEAREST)
    x0 = (320 - spr.width) // 2
    y0 = 146 - spr.height + 8
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([x0 - 6, 142, x0 + spr.width + 6, 152], fill=(0, 0, 0, 120))
    im.alpha_composite(shadow)
    im.alpha_composite(spr, (x0, max(0, y0)))
    # vineta inferior para el nombre
    px = im.load()
    for y in range(110, 180):
        a = (y - 110) / 70 * 0.7
        for x in range(320):
            r, g, b, _ = px[x, y]
            px[x, y] = (int(r * (1 - a)), int(g * (1 - a)), int(b * (1 - a)), 255)
    dst = ROOT / "assets/sprites/ui/bosses"
    dst.mkdir(parents=True, exist_ok=True)
    im.save(dst / f"{name}.png")
    print("ok intro", name)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    for v in args or BOSSES:
        anims = frames(BOSSES[v])
        for name, fr in anims.items():
            for i, im in enumerate(fr):
                im.save(OUT / f"{v}_{name}_{i:02d}.png")
        G.write_frames_tres(v, anims)
        print("ok", v, sum(len(f) for f in anims.values()), "frames")
        if "--no-intro" not in sys.argv:
            intro_art(v)
