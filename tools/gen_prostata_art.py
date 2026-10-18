"""Arte de LA PROSTATA (etapa R): los tres enemigos nuevos (32x48), la jefa La Glandula Callada
(80x120, dibujada a 40x60 y ampliada x2 como los jefes alternativos) y su presentacion 320x180.

Uso: python3 tools/gen_prostata_art.py [goteo_tardio madrugador psa glandula intro ...]   (sin args = todo menos intro)
     python3 tools/gen_prostata_art.py intro    (presentacion con PIL: retrato sobre fondo de sala de espera)
     python3 tools/gen_prostata_art.py proyectiles   (gota del Goteo)
La presentacion por defecto es la de PIL; si hay una de Gemini (tools/gen_prostata_gemini.py) ocupa su lugar.
Reusa los ayudantes de gen_enemy_art.py / gen_boss_alt_art.py (contorno automatico, muerte, SpriteFrames).
"""
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_enemy_art as G  # noqa: E402
import gen_boss_alt_art as B  # noqa: E402

OUT = G.OUT
ROOT = G.ROOT
BLACK = (24, 20, 30, 255)
WHITE = (250, 250, 255, 255)
# paleta de sala de espera
NUEZ = (176, 130, 96, 255)
NUEZ_HI = (214, 172, 134, 255)
NUEZ_DK = (112, 78, 58, 255)
LECHE = (232, 204, 200, 255)
LECHE_DK = (196, 160, 158, 255)
GRIS = (150, 150, 158, 255)
GRIS_DK = (98, 98, 108, 255)
ORINA = (236, 214, 96, 255)
ORINA_HI = (255, 244, 170, 255)
ORINA_DK = (178, 150, 52, 255)
PJ = (84, 92, 168, 255)
PJ_HI = (128, 138, 214, 255)
PJ_DK = (50, 56, 116, 255)
CAP = (226, 226, 240, 255)
RED = (230, 50, 60, 255)
GLASS = (200, 230, 240, 255)
GLASS_DK = (130, 170, 190, 255)
BLOOD = (200, 36, 52, 255)
BLOOD_HI = (250, 110, 120, 255)
COAT = (96, 88, 80, 255)
COAT_HI = (140, 130, 118, 255)
COAT_DK = (60, 54, 50, 255)


def new32():
    im = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def feet(d, bob, step, xs, top, col):
    ups = (2 if step == 1 else 0, 2 if step == 2 else 0)
    for x, up in zip(xs, ups):
        d.rectangle([x, top + bob - up, x + 2, 44 - up], fill=col)
        d.rectangle([x - 1, 44 - up, x + 3, 45 - up], fill=G.M_SH)


def std_frames(draw, atk_n=3):
    idle = draw()
    walk = [draw(bob=0, step=1), draw(bob=-1, step=0), draw(bob=0, step=2), draw(bob=-1, step=0)]
    attack = [draw(atk=i + 1, mouth="open") for i in range(atk_n)]
    hurt = [G.tint(draw(eyes="hurt", mouth="open"), (255, 60, 70), 0.55),
            G.tint(draw(eyes="hurt"), (255, 255, 255), 0.4)]
    dead = draw(eyes="x", mouth="open")
    death = [G.death_frame(dead, i, center=(16, 44)) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


def half_eyes(d, cx, cy, gap, eyes):
    """Ojos de sueno: parpado a la mitad y ojeras."""
    for ex in (cx - gap - 1, cx + gap - 1):
        if eyes == "x":
            d.line([(ex - 1, cy - 1), (ex + 1, cy + 1)], fill=G.PUPIL)
            d.line([(ex - 1, cy + 1), (ex + 1, cy - 1)], fill=G.PUPIL)
        elif eyes == "hurt":
            d.line([(ex - 1, cy - 1), (ex + 1, cy)], fill=G.PUPIL)
            d.line([(ex - 1, cy + 1), (ex + 1, cy)], fill=G.PUPIL)
        else:
            d.rectangle([ex - 1, cy, ex + 1, cy + 2], fill=G.EYE_W)
            d.rectangle([ex, cy + 1, ex + 1, cy + 2], fill=G.PUPIL)
            d.line([(ex - 1, cy), (ex + 1, cy)], fill=G.PUPIL)       # parpado
            d.line([(ex - 1, cy + 3), (ex + 1, cy + 3)], fill=(140, 96, 130, 255))   # ojera


# ------------------------------------------------------------------ Goteo Tardio
def goteo_tardio(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    """Una gota amarillenta y cansada colgando de una llave de paso; suelta lo que le queda."""
    im, d = new32()
    feet(d, bob, step, (11, 18), 40, ORINA_DK)
    # llave de paso oxidada arriba
    d.rectangle([13, 2 + bob, 19, 7 + bob], fill=G.M_DK)
    d.rectangle([11, 4 + bob, 21, 5 + bob], fill=G.M_LO)
    d.rectangle([22, 3 + bob, 26, 4 + bob], fill=G.M_LO)
    d.rectangle([25, 1 + bob, 26, 6 + bob], fill=BLOOD)
    # cuerpo en forma de gota, mas flaca al atacar
    w = -atk
    d.polygon([(16, 7 + bob), (23 + w // 2, 24 + bob), (24 + w, 36 + bob), (16, 42 + bob), (8 - w, 36 + bob), (9 - w // 2, 24 + bob)], fill=ORINA)
    d.ellipse([8 - w, 22 + bob, 24 + w, 42 + bob], fill=ORINA)
    d.ellipse([11, 24 + bob, 15, 31 + bob], fill=ORINA_HI)
    d.rectangle([21 + w, 28 + bob, 23 + w, 38 + bob], fill=ORINA_DK)
    # cara cansada
    half_eyes(d, 16, 28 + bob, 3, eyes)
    if mouth == "open":
        d.rectangle([14, 35 + bob, 17, 38 + bob], fill=G.MOUTH)
    else:
        d.line([(14, 36 + bob), (18, 37 + bob)], fill=G.PUPIL)
    return G.outline(im)


# ------------------------------------------------------------------ Madrugador Nocturno
def madrugador(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    """Pijama azul, gorro de dormir, ojeras y un despertador gigante que suena a las 3."""
    im, d = new32()
    feet(d, bob, step, (10, 18), 40, PJ_DK)
    d.rounded_rectangle([7, 22 + bob, 25, 41 + bob], radius=5, fill=PJ)
    d.rectangle([8, 24 + bob, 11, 38 + bob], fill=PJ_HI)
    d.rectangle([21, 26 + bob, 24, 40 + bob], fill=PJ_DK)
    for ty in (28, 33, 38):
        d.line([(15, ty + bob), (17, ty + bob)], fill=CAP)               # botones
    # cabeza
    d.ellipse([8, 8 + bob, 24, 25 + bob], fill=(246, 196, 168, 255))
    d.ellipse([17, 16 + bob, 23, 24 + bob], fill=(214, 150, 126, 255))
    # gorro con pompon
    d.polygon([(7, 14 + bob), (16, 2 + bob), (25, 14 + bob)], fill=CAP)
    d.rectangle([7, 12 + bob, 25, 15 + bob], fill=(190, 190, 214, 255))
    off = 2 if atk else 0
    d.ellipse([14 + off, 0 + bob, 18 + off, 4 + bob], fill=WHITE)
    half_eyes(d, 16, 17 + bob, 3, eyes)
    d.line([(14, 22 + bob), (18, 22 + bob)] if mouth != "open" else [(14, 22 + bob), (18, 23 + bob)], fill=G.PUPIL)
    # despertador en la mano: campanas y reloj 3:00
    ax, ay = 24, 28 + bob - (3 if atk else 0)
    d.line([(21, 31 + bob), (ax, ay + 4)], fill=(246, 196, 168, 255), width=2)
    d.ellipse([ax - 1, ay, ax + 8, ay + 9], fill=RED)
    d.ellipse([ax + 1, ay + 2, ax + 6, ay + 7], fill=WHITE)
    d.line([(ax + 3, ay + 4), (ax + 3, ay + 6)], fill=BLACK)
    d.line([(ax + 3, ay + 4), (ax + 5, ay + 4)], fill=BLACK)
    d.rectangle([ax, ay - 2, ax + 2, ay], fill=G.M_LO)
    d.rectangle([ax + 5, ay - 2, ax + 7, ay], fill=G.M_LO)
    for k in range(atk):
        d.line([(ax + 9 + k, ay + 1), (ax + 10 + k, ay - 1 - k)], fill=(255, 236, 120, 255))
    return G.outline(im)


# ------------------------------------------------------------------ PSA Sospechoso
def psa(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    """Un tubo de muestra de sangre con gabardina, sombrero y lentes oscuros: sospechoso."""
    im, d = new32()
    feet(d, bob, step, (11, 18), 40, COAT_DK)
    # tubo de ensayo
    d.rounded_rectangle([10, 14 + bob, 22, 41 + bob], radius=5, fill=GLASS)
    d.rectangle([11, 28 + bob, 21, 40 + bob], fill=BLOOD)
    d.rounded_rectangle([11, 26 + bob, 21, 30 + bob], radius=2, fill=BLOOD_HI)
    d.rectangle([11, 16 + bob, 13, 36 + bob], fill=(236, 248, 252, 255))
    d.rectangle([20, 18 + bob, 21, 38 + bob], fill=GLASS_DK)
    d.rectangle([9, 12 + bob, 23, 16 + bob], fill=(230, 60, 70, 255))          # tapon
    # gabardina abierta
    d.polygon([(6, 24 + bob), (11, 22 + bob), (11, 41 + bob), (5, 41 + bob)], fill=COAT)
    d.polygon([(26, 24 + bob), (21, 22 + bob), (21, 41 + bob), (27, 41 + bob)], fill=COAT)
    d.line([(6, 25 + bob), (6, 40 + bob)], fill=COAT_HI)
    # sombrero
    d.rectangle([6, 9 + bob, 26, 11 + bob], fill=COAT_DK)
    d.rectangle([10, 3 + bob, 22, 10 + bob], fill=COAT)
    d.rectangle([10, 8 + bob, 22, 9 + bob], fill=BLOOD)
    # lentes oscuros y boca
    d.rectangle([11, 19 + bob, 15, 22 + bob], fill=BLACK)
    d.rectangle([17, 19 + bob, 21, 22 + bob], fill=BLACK)
    d.line([(15, 20 + bob), (17, 20 + bob)], fill=BLACK)
    if eyes in ("x", "hurt"):
        d.line([(12, 19 + bob), (14, 22 + bob)], fill=WHITE)
        d.line([(14, 19 + bob), (12, 22 + bob)], fill=WHITE)
    else:
        d.point([(12, 20 + bob), (18, 20 + bob)], fill=(120, 120, 150, 255))
    if mouth == "open":
        d.rectangle([14, 25 + bob, 17, 27 + bob], fill=G.MOUTH)
    else:
        d.line([(14, 26 + bob), (18, 26 + bob)], fill=G.PUPIL)
    if atk:  # abre la gabardina para soltar el pulso
        d.rectangle([4 - atk, 30 + bob, 6, 31 + bob], fill=COAT)
        d.rectangle([26, 30 + bob, 28 + atk, 31 + bob], fill=COAT)
    return G.outline(im)


VARIANTS = {
    "goteo_tardio": lambda: std_frames(goteo_tardio),
    "madrugador": lambda: std_frames(madrugador),
    "psa": lambda: std_frames(psa),
}


# ------------------------------------------------------------------ La Glandula Callada
def glandula(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    """Una nuez enorme, rosada y quieta. Boca cosida: no dice nada. Se hincha con cada ataque."""
    im, d = B.new()
    B.legs(d, bob, step, (14, 23), 51, NUEZ_DK)
    g = atk  # inflado
    # dos lobulos
    d.ellipse([4 - g, 12 + bob - g, 23, 53 + bob + g], fill=NUEZ)
    d.ellipse([17, 12 + bob - g, 36 + g, 53 + bob + g], fill=NUEZ)
    d.ellipse([7 - g, 15 + bob - g, 16, 28 + bob], fill=NUEZ_HI)
    d.ellipse([22, 15 + bob, 29, 22 + bob], fill=NUEZ_HI)
    # rosa lechoso en el vientre (la glandula "sana")
    d.ellipse([11, 33 + bob, 29, 50 + bob], fill=LECHE)
    d.ellipse([12, 34 + bob, 18, 40 + bob], fill=(246, 226, 222, 255))
    # surco central y arrugas de nuez
    d.line([(20, 13 + bob), (20, 52 + bob)], fill=NUEZ_DK)
    for (x, y) in [(8, 32), (10, 44), (30, 30), (28, 44), (33, 22), (6, 22)]:
        d.line([(x, y + bob), (x + 3, y + 2 + bob)], fill=NUEZ_DK)
    # etiqueta de la sala de espera: turno (prendida al costado)
    d.rectangle([27, 36 + bob, 34, 43 + bob], fill=(238, 226, 190, 255))
    d.line([(29, 38 + bob), (32, 38 + bob)], fill=RED)
    d.line([(29, 40 + bob), (32, 40 + bob)], fill=RED)
    # cara: ojos hondos con ojeras y BOCA COSIDA (silencio)
    for ex in (14, 24):
        if eyes == "x":
            d.line([(ex - 2, 24 + bob), (ex + 2, 28 + bob)], fill=BLACK)
            d.line([(ex - 2, 28 + bob), (ex + 2, 24 + bob)], fill=BLACK)
        elif eyes == "hurt":
            d.line([(ex - 2, 25 + bob), (ex + 2, 27 + bob)], fill=BLACK, width=1)
            d.line([(ex - 2, 28 + bob), (ex + 2, 26 + bob)], fill=BLACK, width=1)
        else:
            d.ellipse([ex - 3, 23 + bob, ex + 3, 29 + bob], fill=WHITE)
            d.ellipse([ex - 1, 25 + bob, ex + 2, 28 + bob], fill=BLACK)
            d.line([(ex - 3, 22 + bob), (ex + 3, 22 + bob)], fill=NUEZ_DK, width=1)   # parpado pesado
            d.line([(ex - 3, 30 + bob), (ex + 3, 30 + bob)], fill=(150, 90, 100, 255))  # ojera
    d.line([(15, 34 + bob), (25, 34 + bob)], fill=BLACK)
    for x in range(16, 25, 3):  # puntadas
        d.line([(x, 32 + bob), (x, 36 + bob)], fill=BLACK)
    if atk:  # el aviso: una vena palpita en la frente
        d.line([(19, 15 + bob), (21, 18 + bob), (19, 20 + bob)], fill=RED)
    B.arm(d, 4, 38 + bob, -3, 5, NUEZ_DK)
    B.arm(d, 36, 38 + bob, 3, 5, NUEZ_DK)
    return im


def boss_frames():
    idle = glandula()
    walk = [glandula(bob=0, step=1), glandula(bob=-1, step=0), glandula(bob=0, step=2), glandula(bob=-1, step=0)]
    attack = [glandula(atk=i + 1) for i in range(3)]
    hurt = [G.tint(glandula(eyes="hurt"), (255, 60, 70), 0.55), G.tint(glandula(eyes="hurt"), (255, 255, 255), 0.4)]
    dead = glandula(eyes="x")
    death = [G.death_frame(dead, i, center=(20, 54)) for i in range(4)]
    out = {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}
    return {k: [B.up(f) for f in v] for k, v in out.items()}


# ------------------------------------------------------------------ proyectiles
def proyectiles():
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(8, 1), (12, 9), (8, 14), (4, 9)], fill=ORINA)
    d.ellipse([4, 7, 12, 14], fill=ORINA)
    d.ellipse([6, 8, 8, 10], fill=ORINA_HI)
    G.outline(im).save(ROOT / "assets/sprites/projectiles/goteo.png")
    print("ok proyectiles")


# ------------------------------------------------------------------ presentacion 320x180 (PIL)
def intro_pil():
    rng = random.Random("glandula")
    im = Image.new("RGBA", (320, 180), (0, 0, 0, 255))
    px = im.load()
    top, bot = (70, 56, 52), (178, 150, 142)
    for y in range(180):
        t = y / 179
        c = tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3))
        for x in range(320):
            px[x, y] = c + (255,)
    d = ImageDraw.Draw(im)
    # sala de espera: pared con zocalo, sillas, visor de turnos
    d.rectangle([0, 120, 320, 180], fill=(150, 140, 142, 255))
    for x in range(0, 320, 32):
        d.line([(x, 120), (x - 20, 180)], fill=(128, 118, 120, 255))
    d.rectangle([0, 112, 320, 122], fill=(112, 82, 62, 255))
    for cx in (18, 62, 258, 302):
        d.rectangle([cx - 14, 100, cx + 14, 112], fill=LECHE_DK)
        d.rectangle([cx - 14, 112, cx + 14, 130], fill=LECHE)
        d.rectangle([cx - 12, 130, cx - 10, 144], fill=GRIS_DK)
        d.rectangle([cx + 10, 130, cx + 12, 144], fill=GRIS_DK)
    d.rectangle([128, 14, 192, 40], fill=(48, 30, 30, 255))
    for k in range(3):
        d.rectangle([140 + k * 14, 20, 148 + k * 14, 34], fill=RED)
        d.rectangle([142 + k * 14, 23, 146 + k * 14, 25], fill=(48, 30, 30, 255))
        d.rectangle([142 + k * 14, 29, 146 + k * 14, 31], fill=(48, 30, 30, 255))
    for _ in range(26):  # papelitos de turno en el aire
        x, y = rng.randrange(320), rng.randrange(40, 110)
        d.rectangle([x, y, x + 4, y + 6], fill=(238, 226, 190, 255))
    spr = Image.open(OUT / "glandula_idle_00.png").convert("RGBA")
    spr = spr.crop(spr.getbbox())
    k = 138 / spr.height
    spr = spr.resize((max(1, int(spr.width * k)), 138), Image.NEAREST)
    x0 = (320 - spr.width) // 2
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse([x0 - 8, 140, x0 + spr.width + 8, 154], fill=(0, 0, 0, 120))
    im.alpha_composite(shadow)
    im.alpha_composite(spr, (x0, 148 - spr.height))
    px = im.load()
    for y in range(110, 180):
        a = (y - 110) / 70 * 0.72
        for x in range(320):
            r, g, b, _ = px[x, y]
            px[x, y] = (int(r * (1 - a)), int(g * (1 - a)), int(b * (1 - a)), 255)
    dst = ROOT / "assets/sprites/ui/bosses"
    dst.mkdir(parents=True, exist_ok=True)
    im.save(dst / "glandula.png")
    print("ok intro glandula (PIL)")


def build(v):
    anims = boss_frames() if v == "glandula" else VARIANTS[v]()
    for name, frames in anims.items():
        for i, im in enumerate(frames):
            im.save(OUT / f"{v}_{name}_{i:02d}.png")
    G.write_frames_tres(v, anims)
    print("ok", v, sum(len(f) for f in anims.values()), "frames")


if __name__ == "__main__":
    args = sys.argv[1:]
    todo = [a for a in args if a not in ("intro", "proyectiles")] or ([] if args else list(VARIANTS) + ["glandula"])
    for v in todo:
        build(v)
    if "proyectiles" in args or not args:
        proyectiles()
    if "intro" in args:
        intro_pil()
