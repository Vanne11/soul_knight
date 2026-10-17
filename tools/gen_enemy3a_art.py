"""Sprites de los enemigos de la Etapa 3a (32x48, mirando a la derecha) + SpriteFrames .tres.

Uso: python3 tools/gen_enemy3a_art.py [variante ...]   (sin args = todas)
     python3 tools/gen_enemy3a_art.py proyectiles      (mordaza.png y venda.png)
Reusa el estilo y los ayudantes de gen_enemy_art.py (contorno #0d0b0f automatico, muerte, hurt).
Variantes: huincha dedo gran_urologo jaula gran_candado esposas correa shibari sonda ego_inflado
           mito_marcha mito_himen mito_mano
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_enemy_art as G  # noqa: E402

OUT = G.OUT
ROOT = G.ROOT
face = G.face
tint = G.tint
outline = G.outline
death_frame = G.death_frame

# paleta propia
YEL = (255, 206, 52, 255)
YEL_HI = (255, 236, 130, 255)
YEL_DK = (200, 150, 24, 255)
STEEL = (176, 184, 198, 255)
STEEL_HI = (236, 240, 246, 255)
STEEL_DK = (110, 116, 134, 255)
STEEL_SH = (78, 82, 98, 255)
SKIN = (246, 196, 168, 255)
SKIN_DK = (214, 150, 126, 255)
SKIN_HI = (255, 224, 204, 255)
LATEX = (92, 170, 232, 255)
LATEX_HI = (170, 218, 255, 255)
LATEX_DK = (52, 110, 178, 255)
GOLD = (236, 184, 52, 255)
GOLD_HI = (255, 230, 120, 255)
GOLD_DK = (160, 112, 24, 255)
FUR = (255, 150, 200, 255)
FUR_HI = (255, 200, 228, 255)
FUR_DK = (214, 96, 152, 255)
LEATHER = (150, 90, 44, 255)
LEATHER_HI = (200, 134, 72, 255)
LEATHER_DK = (92, 52, 24, 255)
ROPE = (206, 60, 70, 255)
ROPE_HI = (255, 124, 132, 255)
ROPE_DK = (130, 28, 44, 255)
BALLOON = (255, 130, 170, 255)
BALLOON_HI = (255, 196, 216, 255)
BALLOON_DK = (210, 78, 124, 255)
SIGN_R = (216, 40, 48, 255)
SUIT = (62, 74, 120, 255)
SUIT_HI = (96, 110, 164, 255)
PAPER = (250, 244, 224, 255)
HAIR = (96, 58, 34, 255)
BLACK = (24, 20, 30, 255)


def feet(d, bob, step, xs=(10, 19), top=40, color=STEEL_DK):
    """Dos patitas que alternan al caminar (step 0 quieto, 1 y 2 alternan)."""
    ups = (2 if step == 1 else 0, 2 if step == 2 else 0)
    for x, up in zip(xs, ups):
        d.rectangle([x, top + bob - up, x + 2, 44 - up], fill=color)
        d.rectangle([x - 1, 44 - up, x + 3, 45 - up], fill=STEEL_SH)


def new():
    im = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def std_frames(draw, atk_n=3, death_center=(16, 44)):
    idle = draw()
    walk = [draw(bob=0, step=1), draw(bob=-1, step=0), draw(bob=0, step=2), draw(bob=-1, step=0)]
    attack = [draw(atk=i + 1, mouth="open") for i in range(atk_n)]
    hurt = [tint(draw(eyes="hurt", mouth="open"), (255, 60, 70), 0.55),
            tint(draw(eyes="hurt"), (255, 255, 255), 0.4)]
    dead = draw(eyes="x", mouth="open")
    death = [death_frame(dead, i, center=death_center) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


# ------------------------------------------------------------------ huincha de medir
def huincha(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    feet(d, bob, step, (9, 17), 39)
    # cinta que sale por la derecha (mas larga al atacar: estoque)
    tl = (0, 6, 14, 22)[atk]
    ty = 33 + bob
    d.rectangle([24, ty, 25 + tl, ty + 3], fill=YEL)
    d.line([(24, ty), (25 + tl, ty)], fill=YEL_HI)
    for tx in range(26, 25 + tl, 3):
        d.line([(tx, ty + 1), (tx, ty + 2)], fill=G.OUTLINE)
    if tl:
        hx = 25 + tl
        d.rectangle([hx, ty - 2, hx + 1, ty + 5], fill=STEEL)      # gancho de metal
        d.rectangle([hx + 1, ty - 2, hx + 3, ty - 1], fill=STEEL_HI)
    # caja de la huincha
    d.rounded_rectangle([5, 19 + bob, 25, 38 + bob], radius=5, fill=YEL)
    d.rounded_rectangle([6, 20 + bob, 12, 26 + bob], radius=2, fill=YEL_HI)
    d.rectangle([21, 22 + bob, 24, 36 + bob], fill=YEL_DK)
    d.line([(7, 37 + bob), (23, 37 + bob)], fill=YEL_DK)
    d.rectangle([13, 15 + bob, 17, 19 + bob], fill=SIGN_R)         # boton de freno
    d.line([(13, 15 + bob), (17, 15 + bob)], fill=(255, 130, 120, 255))
    # numeritos de cinta en el borde inferior
    for tx in range(8, 23, 3):
        d.line([(tx, 34 + bob), (tx, 35 + bob)], fill=G.OUTLINE)
    face(d, 14, 26 + bob, eyes, mouth, gap=3)
    return outline(im)


def frames_huincha():
    return std_frames(huincha)


# ------------------------------------------------------------------ dedo del urologo
def dedo(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    feet(d, bob, step, (10, 17), 40, LATEX_DK)
    fing = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    f = ImageDraw.Draw(fing)
    # dedo con guante de latex azul: capsula vertical, punta redondeada, brillo
    f.rounded_rectangle([9, 5 + bob, 22, 41 + bob], radius=6, fill=LATEX)
    f.rounded_rectangle([10, 7 + bob, 13, 30 + bob], radius=2, fill=LATEX_HI)
    f.rectangle([19, 12 + bob, 21, 38 + bob], fill=LATEX_DK)
    # punta del guante (pliegue) y punteria brillante
    f.ellipse([12, 5 + bob, 19, 9 + bob], fill=LATEX_HI)
    # puno del guante (borde mas oscuro) abajo
    f.rectangle([8, 36 + bob, 23, 41 + bob], fill=LATEX_DK)
    f.line([(8, 36 + bob), (23, 36 + bob)], fill=LATEX_HI)
    # cara
    face(f, 16, 17 + bob, eyes, mouth, gap=3)
    if atk:
        fing = fing.rotate(-(10, 24, 34)[atk - 1], resample=Image.NEAREST, center=(16, 42))
    im.alpha_composite(fing)
    return outline(im)


def frames_dedo():
    return std_frames(dedo)


# ------------------------------------------------------------------ gran urologo (mano entera)
def gran_urologo(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    feet(d, bob, step, (8, 20), 41, LATEX_DK)
    sp = (0, -3, -5, -7)[atk]
    # cuatro dedos hacia arriba (se abren al atacar)
    for i, (x, h) in enumerate([(5, 12), (11, 16), (17, 15), (23, 11)]):
        dx = int((i - 1.5) * (-sp) * 0.5)
        d.rounded_rectangle([x + dx, 24 - h + bob + sp, x + 4 + dx, 28 + bob], radius=2, fill=LATEX)
        d.line([(x + 1 + dx, 25 - h + bob + sp), (x + 1 + dx, 26 + bob)], fill=LATEX_HI)
        d.line([(x + 4 + dx, 26 - h + bob + sp), (x + 4 + dx, 28 + bob)], fill=LATEX_DK)
    # pulgar
    d.rounded_rectangle([1, 24 + bob, 6, 31 + bob], radius=2, fill=LATEX)
    # palma
    d.rounded_rectangle([4, 24 + bob, 28, 42 + bob], radius=5, fill=LATEX)
    d.rounded_rectangle([5, 25 + bob, 10, 35 + bob], radius=2, fill=LATEX_HI)
    d.rectangle([24, 28 + bob, 27, 40 + bob], fill=LATEX_DK)
    d.rectangle([4, 39 + bob, 28, 42 + bob], fill=LATEX_DK)
    face(d, 16, 30 + bob, eyes, mouth, gap=4)
    return outline(im)


def frames_gran_urologo():
    return std_frames(gran_urologo)


# ------------------------------------------------------------------ jaula carcelera
def jaula(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    feet(d, bob, step, (9, 20), 39)
    lift = (0, 2, 6, 10)[atk]  # al saltar, la jaula se abre por abajo
    # interior oscuro
    d.rounded_rectangle([7, 13 + bob - lift, 25, 38 + bob - lift], radius=5, fill=(30, 24, 40, 255))
    # ojos brillando entre los barrotes
    ey = 25 + bob - lift
    for ex in (11, 18):
        if eyes == "x":
            d.line([(ex, ey - 1), (ex + 2, ey + 1)], fill=(255, 90, 90, 255))
            d.line([(ex, ey + 1), (ex + 2, ey - 1)], fill=(255, 90, 90, 255))
        else:
            d.rectangle([ex, ey - 1, ex + 2, ey + 1], fill=(255, 70, 70, 255) if eyes != "hurt" else (255, 255, 255, 255))
    if mouth == "open":
        d.rectangle([13, ey + 5, 18, ey + 6], fill=(255, 70, 70, 255))
    # barrotes
    for bx in range(8, 26, 3):
        d.line([(bx, 14 + bob - lift), (bx, 38 + bob - lift)], fill=STEEL)
        d.line([(bx, 14 + bob - lift), (bx, 20 + bob - lift)], fill=STEEL_HI)
    # aros horizontales
    d.rounded_rectangle([6, 12 + bob - lift, 26, 15 + bob - lift], radius=1, fill=STEEL_DK)
    d.rounded_rectangle([6, 36 + bob - lift, 26, 39 + bob - lift], radius=1, fill=STEEL_DK)
    # cupula y anilla de colgar
    d.polygon([(7, 13 + bob - lift), (25, 13 + bob - lift), (21, 6 + bob - lift), (11, 6 + bob - lift)], fill=STEEL)
    d.line([(11, 6 + bob - lift), (21, 6 + bob - lift)], fill=STEEL_HI)
    d.arc([12, 0 + bob - lift, 20, 8 + bob - lift], 180, 360, fill=STEEL_DK, width=2)
    return outline(im)


def frames_jaula():
    return std_frames(jaula)


# ------------------------------------------------------------------ gran candado
def gran_candado(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    feet(d, bob, step, (8, 21), 41, GOLD_DK)
    off = (0, 0, 4, 7)[atk]  # al embestir el arco se suelta de un lado (se abre)
    # arco
    d.arc([8, 2 + bob - off // 2, 24, 28 + bob], 180, 360, fill=STEEL_DK, width=5)
    d.arc([9, 3 + bob - off // 2, 23, 27 + bob], 180, 360, fill=STEEL, width=2)
    d.rectangle([8, 12 + bob - off // 2, 12, 24 + bob], fill=STEEL_DK)
    d.rectangle([20, 14 + bob + off, 24, 24 + bob], fill=STEEL_DK)
    # cuerpo
    d.rounded_rectangle([3, 22 + bob, 29, 43 + bob], radius=4, fill=GOLD)
    d.rounded_rectangle([5, 24 + bob, 11, 40 + bob], radius=2, fill=GOLD_HI)
    d.rectangle([24, 26 + bob, 27, 41 + bob], fill=GOLD_DK)
    d.rectangle([3, 40 + bob, 29, 43 + bob], fill=GOLD_DK)
    # remaches
    for rx, ry in ((6, 25), (25, 25), (6, 39), (25, 39)):
        d.rectangle([rx, ry + bob, rx + 1, ry + 1 + bob], fill=GOLD_DK)
    # ojos arriba y ojo de cerradura de boca
    face(d, 16, 28 + bob, eyes, "line", gap=4)
    d.ellipse([13, 33 + bob, 19, 37 + bob], fill=BLACK)
    d.polygon([(14, 36 + bob), (18, 36 + bob), (19, 41 + bob), (13, 41 + bob)], fill=BLACK)
    if mouth == "open":
        d.line([(14, 34 + bob), (18, 34 + bob)], fill=(255, 70, 70, 255))
    return outline(im)


def frames_gran_candado():
    return std_frames(gran_candado)


# ------------------------------------------------------------------ esposas peludas
def fuzz(d, cx, cy, r, seed=0, col=FUR, hi=FUR_HI, dk=FUR_DK):
    """Bola de pelusa: muchos circulitos."""
    pts = [(0, 0)]
    for i in range(10):
        a = i / 10 * math.tau + seed
        pts.append((math.cos(a) * r * 0.8, math.sin(a) * r * 0.8))
    for px, py in pts:
        d.ellipse([cx + px - r * 0.45, cy + py - r * 0.45, cx + px + r * 0.45, cy + py + r * 0.45], fill=col)
    d.ellipse([cx - r * 0.5, cy - r * 0.7, cx + r * 0.1, cy - r * 0.2], fill=hi)
    d.ellipse([cx + r * 0.1, cy + r * 0.3, cx + r * 0.7, cy + r * 0.8], fill=dk)


def esposas(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    feet(d, bob, step, (10, 18), 40, FUR_DK)
    reach = (0, 3, 7, 9)[atk]
    # cadena y brazo-argolla derecho (se estira al atacar)
    d.line([(20, 30 + bob), (24 + reach, 30 + bob - reach // 2)], fill=STEEL_DK, width=2)
    d.ellipse([22 + reach, 24 + bob - reach // 2, 30 + reach, 33 + bob - reach // 2], outline=STEEL, width=2)
    d.ellipse([23 + reach, 25 + bob - reach // 2, 29 + reach, 32 + bob - reach // 2], outline=STEEL_HI, width=1)
    # argolla izquierda
    d.ellipse([1, 29 + bob, 9, 38 + bob], outline=STEEL, width=2)
    d.line([(8, 33 + bob), (12, 33 + bob)], fill=STEEL_DK, width=2)
    # cuerpo de pelusa rosa
    fuzz(d, 16, 28 + bob, 11)
    face(d, 16, 26 + bob, eyes, mouth, gap=3)
    # tira de pelusa en las argollas (lo peludo de las esposas)
    for ex in (5, 26 + reach):
        d.ellipse([ex - 2, 24 + bob - reach // 3 - (0 if ex < 10 else 0), ex + 2, 28 + bob], fill=FUR)
    return outline(im)


def frames_esposas():
    return std_frames(esposas)


# ------------------------------------------------------------------ correa
def correa(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    feet(d, bob, step, (10, 18), 40, LEATHER_DK)
    # cuerpo: lazo de cuero
    d.ellipse([4, 19 + bob, 24, 41 + bob], fill=LEATHER)
    d.ellipse([8, 24 + bob, 20, 36 + bob], fill=(40, 26, 20, 255))
    d.arc([4, 19 + bob, 24, 41 + bob], 200, 300, fill=LEATHER_HI, width=2)
    # costuras
    for a in range(0, 360, 36):
        x = 14 + math.cos(math.radians(a)) * 8.5
        y = 30 + bob + math.sin(math.radians(a)) * 9.5
        d.point((int(x), int(y)), fill=LEATHER_DK)
    # mosqueton (la cabeza): metal con ojos
    hx = 22 + (2 if atk else 0)
    d.rounded_rectangle([hx - 2, 12 + bob, hx + 9, 24 + bob], radius=4, fill=STEEL)
    d.rectangle([hx - 1, 13 + bob, hx + 2, 20 + bob], fill=STEEL_HI)
    d.rectangle([hx + 6, 14 + bob, hx + 8, 22 + bob], fill=STEEL_DK)
    face(d, hx + 4, 17 + bob, eyes, mouth, gap=2)
    # correa que se lanza al atacar
    if atk:
        ll = (0, 5, 9, 12)[atk]
        d.line([(hx + 9, 20 + bob), (hx + 9 + ll // 2, 21 + bob + 1)], fill=LEATHER, width=2)
        d.ellipse([hx + 8 + ll // 2, 19 + bob, hx + 12 + ll // 2, 23 + bob], outline=STEEL, width=1)
    # asa
    d.arc([0, 28 + bob, 8, 40 + bob], 90, 270, fill=LEATHER_HI, width=2)
    return outline(im)


def frames_correa():
    return std_frames(correa)


# ------------------------------------------------------------------ shibari
def shibari(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    feet(d, bob, step, (10, 18), 40, ROPE_DK)
    # cuerpo de cuerdas: trapecio con rombos de nudos
    d.polygon([(8, 22 + bob), (24, 22 + bob), (27, 41 + bob), (5, 41 + bob)], fill=ROPE)
    d.polygon([(9, 23 + bob), (14, 23 + bob), (11, 40 + bob), (7, 40 + bob)], fill=ROPE_HI)
    for i in range(4):
        y = 25 + i * 4 + bob
        d.line([(8 - i // 2, y), (24 + i // 2, y + 3)], fill=ROPE_DK, width=1)
        d.line([(24 + i // 2, y), (8 - i // 2, y + 3)], fill=ROPE_DK, width=1)
    # brazos: cuerdas que se lanzan al frente al atacar
    ar = (0, 3, 8, 12)[atk]
    d.line([(22, 27 + bob), (27 + ar, 26 + bob - ar // 3)], fill=ROPE, width=3)
    d.line([(22, 27 + bob), (27 + ar, 26 + bob - ar // 3)], fill=ROPE_HI, width=1)
    d.line([(10, 27 + bob), (5, 31 + bob)], fill=ROPE, width=3)
    # cabeza con mono de maestro de cuerdas
    d.ellipse([9, 8 + bob, 23, 22 + bob], fill=SKIN)
    d.ellipse([16, 14 + bob, 22, 21 + bob], fill=SKIN_DK)
    d.ellipse([11, 9 + bob, 16, 13 + bob], fill=SKIN_HI)
    d.ellipse([12, 3 + bob, 19, 9 + bob], fill=(30, 24, 34, 255))     # mono
    d.rectangle([9, 8 + bob, 23, 10 + bob], fill=(30, 24, 34, 255))   # pelo
    d.rectangle([14, 8 + bob, 17, 9 + bob], fill=ROPE)                 # cinta
    face(d, 16, 14 + bob, "angry" if eyes == "angry" else eyes, mouth, gap=3)
    return outline(im)


def frames_shibari():
    return std_frames(shibari)


# ------------------------------------------------------------------ sonda uretral
def sonda(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    sh = (0, -2, -5, -7)[atk]   # al lanzarse se inclina hacia delante y deja estela
    probe = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    p = ImageDraw.Draw(probe)
    # tubo fino
    p.rounded_rectangle([9, 24 + bob, 30, 28 + bob], radius=2, fill=STEEL)
    p.line([(10, 25 + bob), (28, 25 + bob)], fill=STEEL_HI)
    p.line([(10, 28 + bob), (29, 28 + bob)], fill=STEEL_DK)
    # punta redondeada
    p.ellipse([26, 23 + bob, 31, 29 + bob], fill=STEEL_HI)
    # conector (la "cabeza"): cono ancho en la parte de atras
    p.polygon([(1, 17 + bob), (11, 22 + bob), (11, 30 + bob), (1, 35 + bob)], fill=(120, 200, 255, 255))
    p.polygon([(1, 17 + bob), (11, 22 + bob), (11, 24 + bob), (1, 21 + bob)], fill=(190, 230, 255, 255))
    p.rectangle([8, 21 + bob, 11, 31 + bob], fill=STEEL_DK)
    # cara en el conector
    face(p, 5, 24 + bob, eyes, mouth, gap=2)
    if atk:
        probe = probe.rotate(-sh * 0.6, resample=Image.NEAREST, center=(10, 26))
    im.alpha_composite(probe)
    d = ImageDraw.Draw(im)
    if atk >= 2:
        for ly in (20, 26, 32):  # lineas de velocidad
            d.line([(0, ly + bob), (4 + atk, ly + bob)], fill=(220, 240, 255, 200))
    return outline(im)


def frames_sonda():
    return std_frames(sonda, death_center=(14, 40))


# ------------------------------------------------------------------ ego inflado
def ego_inflado(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    feet(d, bob, step, (11, 17), 41, BALLOON_DK)
    puff = (0, 1, 2, 3)[atk]
    r = 12 + puff
    cx, cy = 16, 24 + bob
    # brazos (flexionando)
    d.line([(cx - r + 1, cy + 2), (cx - r - 3, cy - 4)], fill=BALLOON_DK, width=3)
    d.line([(cx + r - 1, cy + 2), (cx + r + 2, cy - 4)], fill=BALLOON_DK, width=3)
    d.ellipse([cx - r - 6, cy - 7, cx - r, cy - 1], fill=BALLOON)
    d.ellipse([cx + r - 1, cy - 7, cx + r + 5, cy - 1], fill=BALLOON)
    # globo
    d.ellipse([cx - r, cy - r, cx + r, cy + r + 2], fill=BALLOON)
    d.ellipse([cx - r + 3, cy - r + 3, cx - r + 9, cy - r + 9], fill=BALLOON_HI)
    d.ellipse([cx + 2, cy + 2, cx + r - 1, cy + r], fill=BALLOON_DK)
    # nudo del globo
    d.polygon([(cx - 2, cy + r + 1), (cx + 2, cy + r + 1), (cx, cy + r + 4)], fill=BALLOON_DK)
    # cara: engreida (parpados a media altura, sonrisa de lado)
    ey = cy - 2
    if eyes in ("x", "hurt"):
        face(d, cx, ey, eyes, "open", gap=4)
    else:
        for ex in (cx - 6, cx + 3):
            d.rectangle([ex, ey, ex + 3, ey + 2], fill=(255, 255, 255, 255))
            d.rectangle([ex + 1, ey + 1, ex + 2, ey + 2], fill=G.PUPIL)
            d.line([(ex - 1, ey), (ex + 4, ey)], fill=BALLOON_DK, width=1)  # parpado
        d.line([(cx - 5, ey + 8), (cx + 1, ey + 9)], fill=G.PUPIL)
        d.line([(cx + 1, ey + 9), (cx + 6, ey + 6)], fill=G.PUPIL)
        if mouth == "open":
            d.rectangle([cx - 3, ey + 8, cx + 3, ey + 11], fill=G.MOUTH)
    return outline(im)


def frames_ego_inflado():
    return std_frames(ego_inflado, death_center=(16, 40))


# ------------------------------------------------------------------ mito: marcha atras
def mito_marcha(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    feet(d, bob, step, (10, 18), 40, STEEL_DK)
    lean = (0, 1, 3, 4)[atk]
    cx, cy = 16 + lean, 21 + bob
    # poste y senal redonda de "marcha atras"
    d.rectangle([cx - 1, cy + 8, cx + 1, 40 + bob], fill=STEEL_DK)
    d.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=SIGN_R)
    d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=(250, 244, 230, 255))
    # flecha en U hacia atras (izquierda)
    d.line([(cx + 5, cy - 4), (cx - 1, cy - 6), (cx - 5, cy - 2), (cx - 4, cy + 3)], fill=BLACK, width=2)
    d.polygon([(cx - 8, cy + 2), (cx, cy + 2), (cx - 4, cy + 8)], fill=BLACK)
    # carita en el centro, mirando de lado
    if eyes in ("x", "hurt"):
        face(d, cx, cy - 1, eyes, "open", gap=3)
    else:
        for ex in (cx - 4, cx + 2):
            d.rectangle([ex, cy - 3, ex + 2, cy - 1], fill=(255, 255, 255, 255))
            d.rectangle([ex, cy - 2, ex + 1, cy - 1], fill=G.PUPIL)
        d.line([(cx - 3, cy + 6), (cx + 3, cy + 6)], fill=G.PUPIL)
    # ruedecitas de reversa (humo de escape al atacar)
    if atk >= 2:
        d.ellipse([cx - 16, cy + 10, cx - 12, cy + 14], fill=(200, 200, 210, 200))
    return outline(im)


def frames_mito_marcha():
    return std_frames(mito_marcha)


# ------------------------------------------------------------------ mito: himen-certificador
def mito_himen(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    feet(d, bob, step, (10, 18), 40, BLACK)
    # traje
    d.rounded_rectangle([8, 23 + bob, 24, 41 + bob], radius=3, fill=SUIT)
    d.rectangle([9, 24 + bob, 12, 38 + bob], fill=SUIT_HI)
    d.polygon([(14, 23 + bob), (18, 23 + bob), (16, 30 + bob)], fill=(250, 244, 230, 255))   # camisa
    d.polygon([(15, 25 + bob), (17, 25 + bob), (17, 33 + bob), (16, 35 + bob), (15, 33 + bob)], fill=SIGN_R)
    # brazo derecho con sello (baja al atacar) y brazo izquierdo con certificado
    sy = (0, -4, 3, 6)[atk]
    d.line([(23, 27 + bob), (28, 26 + bob + sy)], fill=SUIT, width=3)
    d.rounded_rectangle([26, 22 + bob + sy, 31, 28 + bob + sy], radius=1, fill=LEATHER)
    d.rectangle([27, 28 + bob + sy, 31, 30 + bob + sy], fill=SIGN_R)
    d.line([(9, 28 + bob), (4, 31 + bob)], fill=SUIT, width=3)
    d.rectangle([0, 27 + bob, 7, 36 + bob], fill=PAPER)
    d.line([(1, 29 + bob), (6, 29 + bob)], fill=STEEL_DK)
    d.line([(1, 31 + bob), (5, 31 + bob)], fill=STEEL_DK)
    d.ellipse([2, 33 + bob, 5, 36 + bob], fill=SIGN_R)   # sello de lacre
    # cabeza con gafas redondas
    d.ellipse([9, 8 + bob, 23, 23 + bob], fill=SKIN)
    d.ellipse([16, 15 + bob, 22, 22 + bob], fill=SKIN_DK)
    d.rectangle([9, 8 + bob, 23, 11 + bob], fill=STEEL_SH)  # pelo gris
    for gx in (12, 17):
        d.ellipse([gx, 13 + bob, gx + 5, 18 + bob], outline=BLACK, width=1)
    face(d, 16, 15 + bob, eyes, mouth, gap=3)
    return outline(im)


def frames_mito_himen():
    return std_frames(mito_himen)


# ------------------------------------------------------------------ mito: mano peluda
def mito_mano(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    im, d = new()
    sp = (0, 2, 5, 7)[atk]
    # dedos-patas (cinco) que trepan
    legs = [(5, 34), (10, 38), (16, 40), (22, 38), (27, 34)]
    for i, (lx, ly) in enumerate(legs):
        up = 2 if (step == 1 and i % 2 == 0) or (step == 2 and i % 2 == 1) else 0
        tx = lx + (i - 2) * (sp // 2 + 1) // 2
        d.line([(lx, 32 + bob), (tx, ly + 4 - up - (sp if atk else 0))], fill=SKIN, width=4)
        d.ellipse([tx - 2, ly + 2 - up - (sp if atk else 0), tx + 2, ly + 6 - up - (sp if atk else 0)], fill=SKIN_DK)
    # palma
    d.ellipse([4, 18 + bob, 28, 38 + bob], fill=SKIN)
    d.ellipse([7, 20 + bob, 15, 28 + bob], fill=SKIN_HI)
    d.ellipse([17, 28 + bob, 27, 37 + bob], fill=SKIN_DK)
    # pulgar
    d.ellipse([0, 22 + bob, 8, 30 + bob], fill=SKIN)
    # tres pelos "del mito" (siempre pocos y ridiculos)
    for hx in (12, 16, 20):
        d.line([(hx, 19 + bob), (hx + (hx - 16) // 2, 13 + bob)], fill=HAIR, width=1)
    face(d, 16, 26 + bob, eyes, mouth, gap=4)
    return outline(im)


def frames_mito_mano():
    return std_frames(mito_mano, death_center=(16, 40))


VARIANTS = {
    "huincha": frames_huincha, "dedo": frames_dedo, "gran_urologo": frames_gran_urologo,
    "jaula": frames_jaula, "gran_candado": frames_gran_candado, "esposas": frames_esposas,
    "correa": frames_correa, "shibari": frames_shibari, "sonda": frames_sonda,
    "ego_inflado": frames_ego_inflado, "mito_marcha": frames_mito_marcha,
    "mito_himen": frames_mito_himen, "mito_mano": frames_mito_mano,
}


# ------------------------------------------------------------------ enemigos a distancia (mordaza, venda)
def mordaza(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    """Cabeza amordazada: bola roja con correa negra en la boca, y un pano que se estira al atacar."""
    im, d = new()
    feet(d, bob, step, (10, 18), 40, BLACK)
    d.rounded_rectangle([8, 24 + bob, 24, 41 + bob], radius=4, fill=BLACK)
    d.rectangle([9, 26 + bob, 12, 38 + bob], fill=(70, 62, 86, 255))
    d.line([(10, 30 + bob), (22, 30 + bob)], fill=(70, 62, 86, 255))
    # arnes con tachuelas
    for sx in (11, 16, 21):
        d.rectangle([sx, 33 + bob, sx + 1, 34 + bob], fill=STEEL)
    # brazo que lanza
    th = (0, -3, -6, 2)[atk]
    d.line([(23, 29 + bob), (28, 27 + bob + th)], fill=BLACK, width=3)
    d.ellipse([26, 24 + bob + th, 31, 29 + bob + th], fill=SIGN_R)
    # cabeza
    d.ellipse([8, 7 + bob, 24, 24 + bob], fill=SKIN)
    d.ellipse([17, 15 + bob, 23, 23 + bob], fill=SKIN_DK)
    d.ellipse([10, 8 + bob, 16, 13 + bob], fill=SKIN_HI)
    # capucha de cuero
    d.pieslice([7, 5 + bob, 25, 22 + bob], 180, 360, fill=BLACK)
    d.rectangle([7, 13 + bob, 25, 14 + bob], fill=BLACK)
    # ojos
    for ex in (12, 18):
        if eyes in ("x", "hurt"):
            d.line([(ex - 1, 15 + bob), (ex + 1, 17 + bob)], fill=G.PUPIL)
            d.line([(ex - 1, 17 + bob), (ex + 1, 15 + bob)], fill=G.PUPIL)
        else:
            d.rectangle([ex - 1, 15 + bob, ex + 1, 17 + bob], fill=(255, 255, 255, 255))
            d.rectangle([ex, 16 + bob, ex + 1, 17 + bob], fill=G.PUPIL)
    if eyes == "angry":
        d.line([(10, 13 + bob), (14, 14 + bob)], fill=G.PUPIL)
        d.line([(17, 14 + bob), (21, 13 + bob)], fill=G.PUPIL)
    # mordaza: bola roja + correas
    d.line([(8, 20 + bob), (24, 20 + bob)], fill=BLACK, width=2)
    d.ellipse([12, 17 + bob, 20, 23 + bob], fill=SIGN_R)
    d.ellipse([13, 18 + bob, 15, 20 + bob], fill=(255, 150, 140, 255))
    return outline(im)


def venda(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    """Personaje con una venda negra en los ojos que lanza otra."""
    im, d = new()
    feet(d, bob, step, (10, 18), 40, BLACK)
    d.rounded_rectangle([8, 24 + bob, 24, 41 + bob], radius=4, fill=(112, 70, 170, 255))
    d.rectangle([9, 26 + bob, 12, 38 + bob], fill=(160, 120, 210, 255))
    d.rectangle([20, 28 + bob, 23, 40 + bob], fill=(80, 46, 128, 255))
    th = (0, -3, -6, 2)[atk]
    d.line([(23, 29 + bob), (28, 27 + bob + th)], fill=(112, 70, 170, 255), width=3)
    d.rectangle([26, 24 + bob + th, 31, 28 + bob + th], fill=BLACK)   # venda lista para tirar
    d.line([(26, 25 + bob + th), (31, 25 + bob + th)], fill=(70, 62, 86, 255))
    # cabeza
    d.ellipse([8, 7 + bob, 24, 24 + bob], fill=SKIN)
    d.ellipse([17, 15 + bob, 23, 23 + bob], fill=SKIN_DK)
    d.ellipse([10, 8 + bob, 16, 13 + bob], fill=SKIN_HI)
    d.pieslice([7, 5 + bob, 25, 22 + bob], 180, 360, fill=(60, 36, 90, 255))
    # venda negra sobre los ojos (con nudo detras) y ojos pintados encima: "no ve pero mira"
    d.rectangle([7, 13 + bob, 25, 18 + bob], fill=BLACK)
    d.polygon([(6, 14 + bob), (2, 12 + bob), (3, 18 + bob), (6, 17 + bob)], fill=BLACK)
    d.line([(9, 14 + bob), (22, 14 + bob)], fill=(70, 62, 86, 255))
    if eyes in ("x", "hurt"):
        for ex in (12, 18):
            d.line([(ex - 1, 14 + bob), (ex + 1, 17 + bob)], fill=SIGN_R)
            d.line([(ex - 1, 17 + bob), (ex + 1, 14 + bob)], fill=SIGN_R)
    else:
        for ex in (12, 18):
            d.rectangle([ex - 1, 15 + bob, ex + 1, 16 + bob], fill=(255, 255, 255, 255))
    d.line([(12, 21 + bob), (19, 21 + bob)] if mouth != "open" else [(13, 21 + bob), (18, 22 + bob)], fill=G.PUPIL)
    return outline(im)


VARIANTS["mordaza"] = lambda: std_frames(mordaza)
VARIANTS["venda"] = lambda: std_frames(venda)


def proyectil_mordaza():
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.line([(1, 8), (14, 8)], fill=BLACK, width=2)          # correa
    d.ellipse([4, 3, 12, 11], fill=SIGN_R)
    d.ellipse([5, 4, 8, 7], fill=(255, 170, 160, 255))
    d.arc([4, 3, 12, 11], 20, 120, fill=(150, 20, 30, 255), width=1)
    outline(im).save(ROOT / "assets/sprites/projectiles/mordaza.png")
    print("ok mordaza")


def proyectil_venda():
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(1, 5), (14, 3), (15, 10), (2, 12)], fill=BLACK)
    d.line([(2, 6), (13, 4)], fill=(96, 88, 120, 255))
    d.line([(1, 12), (0, 15)], fill=BLACK)
    d.line([(4, 12), (4, 15)], fill=BLACK)
    outline(im).save(ROOT / "assets/sprites/projectiles/venda.png")
    print("ok venda")


if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["proyectiles"] or not args:
        proyectil_mordaza()
        proyectil_venda()
        if args:
            sys.exit(0)
    for v in args or VARIANTS:
        anims = VARIANTS[v]()
        for name, frames in anims.items():
            for i, im in enumerate(frames):
                im.save(OUT / f"{v}_{name}_{i:02d}.png")
        G.write_frames_tres(v, anims)
        print("ok", v, sum(len(f) for f in anims.values()), "frames")
