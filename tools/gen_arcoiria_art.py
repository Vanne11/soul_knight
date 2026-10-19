"""Arte PROVISORIO de ARCOIRIA (reino del Orgullo): enemigos, jefe, objetos de colores y decorado.

Uso: python3 tools/gen_arcoiria_art.py [rumor comentario mirada fase armario hombre etiqueta destine
                                       objetos decor proyectiles preview]   (sin args = todo menos preview)
  enemigos   assets/sprites/enemies/<v>_<anim>_NN.png + <v>_sprite_frames.tres (32x48, mirando a la derecha)
             rumor, comentario, mirada = el trio comun (melee, a distancia, enjambre)
             fase, armario, hombre (+ hombre_l / hombre_r, las mitades), etiqueta = los enemigos-prejuicio
  destine    el jefe La Censura que destine (80x120), mismo formato que Dona Regla
  objetos    assets/sprites/items/bandera_<color>.png (24x24, uno por franja)
  decor      assets/sprites/environment/decor/orgullo_*.png (banderin, maceta, guirnalda)
  proyectiles assets/sprites/projectiles/etiqueta.png
  preview    hoja de contacto en la carpeta que se pase como 2o argumento (para mirar el arte)
Mismo estilo que gen_enemy3a_art.py: poligonos a 1x y contorno automatico #0d0b0f. Es arte provisorio:
el definitivo se hace con Gemini (hojas completas en una sola imagen).
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_enemy_art as G  # noqa: E402

ROOT = G.ROOT
OUT = G.OUT
face = G.face
tint = G.tint
outline = G.outline
death_frame = G.death_frame

G.ANIM.update({"ghost": (True, 4.0), "open": (True, 6.0)})

# la bandera: rojo, naranja, amarillo, verde, azul, violeta (franja -> color)
RED = (232, 64, 72, 255)
RED_HI = (255, 130, 130, 255)
RED_DK = (150, 30, 48, 255)
ORANGE = (255, 150, 48, 255)
ORANGE_HI = (255, 200, 120, 255)
ORANGE_DK = (190, 96, 24, 255)
YELLOW = (255, 214, 64, 255)
YELLOW_HI = (255, 244, 160, 255)
YELLOW_DK = (200, 150, 24, 255)
GREEN = (78, 190, 96, 255)
GREEN_HI = (160, 235, 150, 255)
GREEN_DK = (36, 110, 58, 255)
BLUE = (64, 130, 230, 255)
BLUE_HI = (140, 190, 255, 255)
BLUE_DK = (34, 70, 160, 255)
VIOLET = (150, 96, 220, 255)
VIOLET_HI = (200, 160, 250, 255)
VIOLET_DK = (92, 52, 150, 255)
STRIPES = [("rojo", RED, RED_HI, RED_DK), ("naranja", ORANGE, ORANGE_HI, ORANGE_DK),
           ("amarillo", YELLOW, YELLOW_HI, YELLOW_DK), ("verde", GREEN, GREEN_HI, GREEN_DK),
           ("azul", BLUE, BLUE_HI, BLUE_DK), ("violeta", VIOLET, VIOLET_HI, VIOLET_DK)]

GREY = (170, 170, 182, 255)
GREY_HI = (214, 214, 226, 255)
GREY_DK = (110, 110, 126, 255)
GREY_SH = (70, 70, 86, 255)
WHITE = (252, 250, 255, 255)
PAPER = (250, 244, 224, 255)
PAPER_DK = (214, 204, 176, 255)
SKIN = (246, 196, 168, 255)
SKIN_DK = (214, 150, 126, 255)
WOOD = (176, 110, 64, 255)
WOOD_HI = (216, 150, 92, 255)
WOOD_DK = (112, 66, 38, 255)
DARK = (30, 22, 40, 255)
INK = (24, 20, 30, 255)
PINK = (255, 150, 200, 255)
PINK_DK = (214, 96, 152, 255)
MOON = (255, 236, 150, 255)
MOON_HI = (255, 250, 210, 255)
MOON_DK = (214, 178, 90, 255)


def new(w=32, h=48):
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def feet(d, bob, step, xs=(10, 19), top=40, color=GREY_DK):
    """Dos patitas que alternan al caminar (step 0 quieto, 1 y 2 alternan)."""
    ups = (2 if step == 1 else 0, 2 if step == 2 else 0)
    for x, up in zip(xs, ups):
        d.rectangle([x, top + bob - up, x + 2, 44 - up], fill=color)
        d.rectangle([x - 1, 44 - up, x + 3, 45 - up], fill=GREY_SH)


def std_frames(draw, atk_n=3, death_center=(16, 44), extra=None):
    idle = draw()
    walk = [draw(bob=0, step=1), draw(bob=-1, step=0), draw(bob=0, step=2), draw(bob=-1, step=0)]
    attack = [draw(atk=i + 1, mouth="open") for i in range(atk_n)]
    hurt = [tint(draw(eyes="hurt", mouth="open"), (255, 60, 70), 0.55),
            tint(draw(eyes="hurt"), (255, 255, 255), 0.4)]
    dead = draw(eyes="x", mouth="open")
    death = [death_frame(dead, i, center=death_center) for i in range(4)]
    out = {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}
    if extra:
        out.update(extra)
    return out


def wavy_hem(d, x0, x1, y, amp, col, phase=0):
    """Borde inferior ondulado de fantasma."""
    n = x1 - x0
    pts = [(x0, y - 8)]
    for i in range(n + 1):
        pts.append((x0 + i, y + int(round(math.sin((i + phase) / n * math.pi * 3) * amp))))
    pts.append((x1, y - 8))
    d.polygon(pts, fill=col)


# ------------------------------------------------------------------ rumor (cuerpo a cuerpo)
def rumor(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    """Rumor Ambulante: un fantasmita de murmuracion con una oreja enorme y marcas de cuchicheo."""
    im, d = new()
    lean = (0, 1, 3, 5)[atk]
    # cuerpo: nube lila con borde ondulado
    d.ellipse([6 + lean, 8 + bob, 25 + lean, 30 + bob], fill=(206, 200, 226, 255))
    d.rectangle([6 + lean, 19 + bob, 25 + lean, 36 + bob], fill=(206, 200, 226, 255))
    wavy_hem(d, 6 + lean, 25 + lean, 38 + bob, 2, (206, 200, 226, 255), phase=step * 3)
    d.rectangle([20 + lean, 12 + bob, 25 + lean, 34 + bob], fill=(160, 152, 190, 255))      # sombra derecha
    d.ellipse([9 + lean, 10 + bob, 15 + lean, 15 + bob], fill=(238, 234, 250, 255))         # brillo
    # oreja enorme (la que escucha todo)
    d.ellipse([20 + lean, 13 + bob, 30 + lean, 31 + bob], fill=SKIN)
    d.ellipse([23 + lean, 17 + bob, 28 + lean, 28 + bob], fill=SKIN_DK)
    d.arc([21 + lean, 15 + bob, 29 + lean, 29 + bob], 200, 340, fill=(190, 120, 100, 255))
    # cara
    face(d, 13 + lean, 21 + bob, eyes, mouth, gap=3)
    # marcas de cuchicheo (~) al atacar
    if atk >= 2:
        for i in range(atk - 1):
            x = 1 + i * 2
            d.line([(x, 18 + bob + i * 3), (x + 2, 17 + bob + i * 3), (x + 4, 18 + bob + i * 3)], fill=(150, 140, 190, 255))
    # patitas ocultas bajo el borde
    feet(d, bob, step, (11, 17), 38, (150, 142, 180, 255))
    return outline(im)


def frames_rumor():
    return std_frames(rumor)


# ------------------------------------------------------------------ comentario (a distancia)
def comentario(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    """Comentario Inoportuno: un globo de dialogo con patitas que dice lo que nadie pidio."""
    im, d = new()
    feet(d, bob, step, (9, 19), 38, GREY_DK)
    sx = (0, 0, -1, -2)[atk]
    # globo
    d.rounded_rectangle([3 + sx, 6 + bob, 28 + sx, 34 + bob], radius=8, fill=WHITE)
    d.rounded_rectangle([3 + sx, 6 + bob, 28 + sx, 34 + bob], radius=8, outline=(206, 206, 226, 255))
    d.polygon([(7, 33 + bob), (14, 33 + bob), (6, 41 + bob)], fill=WHITE)                    # colita
    d.rectangle([22 + sx, 12 + bob, 26 + sx, 32 + bob], fill=(226, 226, 242, 255))
    # "?!" arriba, en tinta
    d.rectangle([8 + sx, 10 + bob, 9 + sx, 10 + bob], fill=INK)
    d.line([(8 + sx, 9 + bob), (10 + sx, 8 + bob), (12 + sx, 9 + bob), (11 + sx, 11 + bob)], fill=INK)
    d.rectangle([11 + sx, 13 + bob, 11 + sx, 13 + bob], fill=INK)
    d.line([(20 + sx, 8 + bob), (20 + sx, 12 + bob)], fill=INK)
    d.point((20 + sx, 14 + bob), fill=INK)
    face(d, 15 + sx, 22 + bob, eyes, mouth, gap=3)
    # al atacar: tres puntitos que salen disparados
    if atk >= 2:
        for i in range(atk - 1):
            d.rectangle([29 + i * 2, 18 + bob + i, 30 + i * 2, 19 + bob + i], fill=INK)
    return outline(im)


def frames_comentario():
    return std_frames(comentario)


# ------------------------------------------------------------------ mirada (enjambre)
def mirada(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    """Mirada de Reojo: un ojo enorme que mira de lado, con la ceja levantada."""
    im, d = new()
    feet(d, bob, step, (12, 17), 40, (150, 90, 90, 255))
    wide = (0, 1, 2, 3)[atk]
    cx, cy = 16, 25 + bob
    d.ellipse([3, cy - 12 - wide, 29, cy + 12 + wide], fill=WHITE)
    d.arc([3, cy - 12 - wide, 29, cy + 12 + wide], 20, 160, fill=(214, 206, 226, 255))
    # venitas rojas
    for ang in (200, 245, 300, 340):
        a = math.radians(ang)
        d.line([(cx + math.cos(a) * 12, cy + math.sin(a) * 9), (cx + math.cos(a) * 8, cy + math.sin(a) * 6)], fill=(232, 120, 130, 255))
    # iris mirando a un lado (derecha), pupila y brillo
    ix = cx + 6 if atk < 3 else cx + 8
    d.ellipse([ix - 6, cy - 6, ix + 6, cy + 6], fill=(60, 170, 170, 255))
    d.ellipse([ix - 6, cy - 6, ix + 6, cy + 6], outline=(30, 100, 110, 255))
    d.ellipse([ix - 2, cy - 3, ix + 3, cy + 3], fill=INK)
    d.rectangle([ix - 4, cy - 4, ix - 3, cy - 3], fill=WHITE)
    if eyes == "x":
        d.rectangle([3, cy - 12, 29, cy + 12], fill=(0, 0, 0, 0))
        d.ellipse([3, cy - 12, 29, cy + 12], fill=(226, 220, 236, 255))
        d.line([(10, cy - 4), (22, cy + 4)], fill=INK, width=2)
        d.line([(10, cy + 4), (22, cy - 4)], fill=INK, width=2)
    elif eyes == "hurt":
        d.polygon([(2, cy - 14), (30, cy - 14), (30, cy), (2, cy)], fill=SKIN_DK)             # parpado cerrado a medias
    else:
        # parpado superior (ceja levantada, desconfiada)
        d.pieslice([2, cy - 14 - wide, 30, cy + 10], 180, 360, fill=SKIN)
        d.line([(3, cy - 2), (29, cy - 2 + (0 if atk else 1))], fill=SKIN_DK)
        d.line([(5, cy - 18 - wide), (13, cy - 21 - wide), (23, cy - 18 - wide)], fill=(96, 58, 34, 255), width=2)  # ceja
    return outline(im)


def frames_mirada():
    return std_frames(mirada, death_center=(16, 38))


# ------------------------------------------------------------------ "Es una fase": una luna
def luna_disco(im, d, cx, cy, r, phase):
    """Dibuja la luna segun su fase: 0 creciente, 1 media, 2 llena, 3 nueva (hueca)."""
    if phase == 3:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(60, 66, 110, 150), outline=(150, 160, 220, 255))
        return
    base = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    bd = ImageDraw.Draw(base)
    bd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=MOON)
    if phase < 2:
        off = (7, 2)[phase] if phase < 2 else 0
        cut = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
        cd = ImageDraw.Draw(cut)
        cd.ellipse([cx - r + off + 4, cy - r + 1 - (phase == 0) * 2, cx + r + off + 5, cy + r + 1 - (phase == 0) * 2], fill=(255, 255, 255, 255))
        a = ImageChops.subtract(base.getchannel("A"), cut.getchannel("A"))
        base.putalpha(a)
    # sombra y crateres
    bd2 = ImageDraw.Draw(base)
    if phase == 2:
        for (px, py, pr) in ((cx - 4, cy - 4, 2), (cx + 4, cy + 3, 3), (cx - 3, cy + 5, 1)):
            bd2.ellipse([px - pr, py - pr, px + pr, py + pr], fill=MOON_DK)
        bd2.ellipse([cx - r + 2, cy - r + 2, cx - r + 6, cy - r + 6], fill=MOON_HI)
    im.alpha_composite(base)


def fase(bob=0, step=0, eyes="angry", mouth="line", atk=0, phase=None):
    """Es una fase: una lunita que cambia de fase (creciente -> media -> llena -> nueva)."""
    im, d = new()
    if phase is None:
        phase = (0, 1, 2, 2)[atk]
    feet(d, bob, step, (12, 18), 40, MOON_DK)
    cx, cy = 16, 22 + bob
    # estrellitas alrededor
    for (sx, sy) in ((4, 8), (27, 12), (26, 34)):
        d.point((sx, sy + bob), fill=MOON_HI)
        d.point((sx - 1, sy + bob), fill=MOON_HI)
        d.point((sx + 1, sy + bob), fill=MOON_HI)
        d.point((sx, sy - 1 + bob), fill=MOON_HI)
        d.point((sx, sy + 1 + bob), fill=MOON_HI)
    luna_disco(im, d, cx, cy, 13, phase)
    if phase == 3:
        face(d, 16, cy, "hurt" if eyes == "angry" else eyes, "line", gap=3)
    elif phase == 2:
        face(d, 16, cy + 1, eyes, mouth, gap=3)
    else:
        face(d, 12 if phase == 0 else 14, cy + 1, eyes, mouth, gap=2)
    return outline(im)


def frames_fase():
    base = std_frames(fase)
    base["ghost"] = [fase(phase=3, bob=0), fase(phase=3, bob=-1)]
    return base


# ------------------------------------------------------------------ "El Armario"
def armario(bob=0, step=0, eyes="angry", mouth="line", atk=0, opened=0):
    """El Armario: un ropero que se esconde; asoma una bufanda de colores por la rendija."""
    im, d = new()
    sh = (0, -1, 1, -1)[min(atk, 3)] if atk else 0
    # patas
    for x in (8, 21):
        d.rectangle([x, 41 + bob, x + 3, 44 - (2 if (step and x == (8 if step == 1 else 21)) else 0)], fill=WOOD_DK)
    # caja
    d.rectangle([5 + sh, 6 + bob, 27 + sh, 41 + bob], fill=WOOD)
    d.rectangle([5 + sh, 6 + bob, 8 + sh, 41 + bob], fill=WOOD_HI)
    d.rectangle([24 + sh, 6 + bob, 27 + sh, 41 + bob], fill=WOOD_DK)
    d.rectangle([3 + sh, 3 + bob, 29 + sh, 7 + bob], fill=WOOD_HI)                           # cornisa
    d.rectangle([3 + sh, 6 + bob, 29 + sh, 7 + bob], fill=WOOD_DK)
    d.rectangle([4 + sh, 40 + bob, 28 + sh, 42 + bob], fill=WOOD_DK)                         # zocalo
    if opened:
        # puertas abiertas hacia los lados y el interior oscuro con ropa de colores
        d.rectangle([8 + sh, 9 + bob, 24 + sh, 39 + bob], fill=DARK)
        d.rectangle([9 + sh, 12 + bob, 23 + sh, 13 + bob], fill=GREY_DK)                    # barra
        for i, (c, _, _, _) in enumerate(STRIPES):
            col = STRIPES[i][1]
            x = 10 + i * 2 + sh
            d.polygon([(x, 13 + bob), (x + 2, 13 + bob), (x + 2, 27 + bob - (i % 2) * 3), (x, 27 + bob - (i % 2) * 3)], fill=col)
        d.polygon([(8 + sh, 9 + bob), (2 + sh, 12 + bob), (2 + sh, 38 + bob), (8 + sh, 39 + bob)], fill=WOOD_HI)
        d.polygon([(24 + sh, 9 + bob), (30 + sh, 12 + bob), (30 + sh, 38 + bob), (24 + sh, 39 + bob)], fill=WOOD_DK)
        # ojitos en la oscuridad
        for ex in (13, 19):
            d.rectangle([ex + sh, 31 + bob, ex + 1 + sh, 33 + bob], fill=WHITE)
    else:
        d.rectangle([8 + sh, 9 + bob, 15 + sh, 39 + bob], fill=WOOD_HI)
        d.rectangle([17 + sh, 9 + bob, 24 + sh, 39 + bob], fill=WOOD)
        d.rectangle([15 + sh, 9 + bob, 16 + sh, 39 + bob], fill=DARK)                        # rendija
        d.rectangle([11 + sh, 12 + bob, 13 + sh, 36 + bob], fill=(196, 130, 80, 255))
        d.rectangle([19 + sh, 12 + bob, 22 + sh, 36 + bob], fill=(150, 90, 52, 255))
        d.ellipse([13 + sh, 23 + bob, 14 + sh, 24 + bob], fill=YELLOW)                       # pomos
        d.ellipse([17 + sh, 23 + bob, 18 + sh, 24 + bob], fill=YELLOW)
        # la bufanda de colores asomando por la rendija (secreto a medias)
        for i, (_, col, _, _) in enumerate(STRIPES):
            d.rectangle([15 + sh, 17 + bob + i * 2, 16 + sh, 18 + bob + i * 2], fill=col)
            if i % 2 == 0:
                d.point((17 + sh, 17 + bob + i * 2), fill=col)
        # ojos por la rendija
        if eyes in ("x", "hurt"):
            d.line([(12 + sh, 14 + bob), (14 + sh, 16 + bob)], fill=INK)
            d.line([(12 + sh, 16 + bob), (14 + sh, 14 + bob)], fill=INK)
        else:
            d.rectangle([12 + sh, 14 + bob, 14 + sh, 15 + bob], fill=WHITE)
            d.rectangle([13 + sh, 14 + bob, 14 + sh, 15 + bob], fill=INK)
            d.rectangle([18 + sh, 14 + bob, 20 + sh, 15 + bob], fill=WHITE)
            d.rectangle([19 + sh, 14 + bob, 20 + sh, 15 + bob], fill=INK)
        if eyes == "angry":
            d.line([(11 + sh, 13 + bob), (14 + sh, 14 + bob)], fill=INK)
            d.line([(18 + sh, 14 + bob), (21 + sh, 13 + bob)], fill=INK)
    return outline(im)


def frames_armario():
    anim = std_frames(armario)
    anim["open"] = [armario(opened=1), armario(opened=1, bob=-1)]
    anim["hurt"] = [tint(armario(eyes="hurt", opened=1), (255, 60, 70), 0.5), tint(armario(eyes="hurt"), (255, 255, 255), 0.4)]
    return anim


# ------------------------------------------------------------------ "¿Y quién es el hombre?"
def signo(d, x, y, col, inverted):
    """Signo de interrogacion de 7x13 px (dibujado a mano). inverted = el de apertura ¿."""
    pts = [(1, 2), (2, 1), (3, 0), (4, 0), (5, 1), (6, 2), (6, 3), (5, 4), (4, 5), (3, 6), (3, 7), (3, 8)]
    for (px, py) in pts:
        yy = (12 - py) if inverted else py
        xx = (6 - px) if inverted else px
        d.rectangle([x + xx, y + yy, x + xx + 1, y + yy + 1], fill=col)
    dy = 1 if inverted else 12
    d.rectangle([x + (3 if not inverted else 3), y + dy - 1, x + 4, y + dy], fill=col)


def hombre(bob=0, step=0, eyes="angry", mouth="line", atk=0, part=None):
    """¿Y quién es el hombre?: un globito partido por la mitad (azul y rosa) con ¿ y ?
    que cree que toda pareja necesita casting. part = "l" o "r" para cada mitad suelta."""
    im, d = new()
    feet(d, bob, step, (9, 20), 40, GREY_DK)
    sq = (0, 1, 2, 1)[atk]
    # cuerpo: mitad izquierda azul, mitad derecha rosa
    d.ellipse([3, 9 + bob - sq, 29, 42 + bob], fill=PINK)
    left = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    ld = ImageDraw.Draw(left)
    ld.ellipse([3, 9 + bob - sq, 29, 42 + bob], fill=BLUE)
    ld.rectangle([16, 0, 31, 47], fill=(0, 0, 0, 0))
    im.alpha_composite(left)
    d = ImageDraw.Draw(im)
    d.rectangle([16, 11 + bob, 16, 40 + bob], fill=(250, 250, 255, 255))                     # la costura
    for yy in range(12, 40, 4):
        d.point((16, yy + bob), fill=INK)
    d.ellipse([6, 12 + bob, 11, 17 + bob], fill=BLUE_HI)                                      # brillos
    d.ellipse([21, 12 + bob, 26, 17 + bob], fill=(255, 210, 230, 255))
    # los dos signos
    signo(d, 6, 22 + bob, WHITE, True)
    signo(d, 20, 22 + bob, WHITE, False)
    # cara: una mirada para cada lado
    for ex, col in ((10, BLUE_DK), (21, PINK_DK)):
        if eyes in ("x", "hurt"):
            d.line([(ex - 1, 15 + bob), (ex + 1, 17 + bob)], fill=INK)
            d.line([(ex - 1, 17 + bob), (ex + 1, 15 + bob)], fill=INK)
        else:
            d.rectangle([ex - 1, 14 + bob, ex + 1, 17 + bob], fill=WHITE)
            d.rectangle([ex, 15 + bob, ex + 1, 16 + bob], fill=INK)
    if eyes == "angry":
        d.line([(7, 13 + bob), (12, 14 + bob)], fill=INK)
        d.line([(19, 14 + bob), (24, 13 + bob)], fill=INK)
    d.line([(13, 19 + bob), (19, 19 + bob)], fill=INK)
    if part is not None:
        crop = (0, 16) if part == "l" else (16, 32)
        half = im.crop((crop[0], 0, crop[1], 48))
        im = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
        im.alpha_composite(half, (8, 0))
        # el lado cortado se redondea con un borde del color de su mitad
        d = ImageDraw.Draw(im)
        edge = BLUE_DK if part == "l" else PINK_DK
        ex = 23 if part == "l" else 8
        d.line([(ex, 14 + bob), (ex, 38 + bob)], fill=edge)
        # un ojo grande en la parte cortada (busca a su otra mitad)
        if eyes not in ("x", "hurt"):
            d.rectangle([ex - (2 if part == "l" else -1), 26 + bob, ex - (1 if part == "l" else -2), 28 + bob], fill=WHITE)
    return outline(im)


def frames_hombre():
    return std_frames(hombre)


def frames_hombre_l():
    return std_frames(lambda **k: hombre(part="l", **k), death_center=(16, 44))


def frames_hombre_r():
    return std_frames(lambda **k: hombre(part="r", **k), death_center=(16, 44))


# ------------------------------------------------------------------ "La Etiqueta"
def etiqueta(bob=0, step=0, eyes="angry", mouth="line", atk=0):
    """La Etiqueta: un cartel de precio con patitas que te pega otra etiqueta sin preguntar."""
    im, d = new()
    feet(d, bob, step, (10, 19), 40, GREY_DK)
    tilt = (0, -1, -2, -3)[atk]
    # cuerda y agujero
    d.arc([12, 1 + bob, 20, 9 + bob], 180, 360, fill=PINK_DK, width=1)
    d.line([(16, 4 + bob), (16, 8 + bob)], fill=PINK_DK)
    # la tarjeta: hexagono con esquina cortada
    pts = [(8, 8 + bob), (24, 8 + bob), (28, 13 + bob), (28, 40 + bob), (4, 40 + bob), (4, 13 + bob)]
    d.polygon(pts, fill=YELLOW)
    d.polygon([(24, 8 + bob), (28, 13 + bob), (28, 40 + bob), (22, 40 + bob), (22, 13 + bob)], fill=YELLOW_DK)
    d.polygon([(8, 8 + bob), (13, 8 + bob), (4, 13 + bob)], fill=YELLOW_HI)
    d.ellipse([14, 9 + bob, 18, 13 + bob], fill=(0, 0, 0, 0))
    d.ellipse([14, 9 + bob, 18, 13 + bob], outline=PINK_DK)
    # renglones de "texto" y codigo de barras
    d.line([(8, 30 + bob), (24, 30 + bob)], fill=INK)
    d.line([(8, 33 + bob), (20, 33 + bob)], fill=INK)
    for i, x in enumerate(range(8, 25, 2)):
        d.line([(x, 36 + bob), (x, 39 + bob)], fill=INK if i % 3 else YELLOW_DK)
    face(d, 16, 21 + bob, eyes, mouth, gap=4)
    # esquina despegandose al atacar
    if tilt:
        d.polygon([(28, 40 + bob), (28 + (-tilt) * 2, 36 + bob), (22, 40 + bob)], fill=PAPER)
        d.line([(28, 40 + bob), (28 + (-tilt) * 2, 36 + bob)], fill=PAPER_DK)
    return outline(im)


def frames_etiqueta():
    return std_frames(etiqueta)


# ------------------------------------------------------------------ jefe: la Censura que destine (80x120)
def destine(bob=0, legs=(0, 0), lean=0, eyes="angry", mouth="stern", arm="down", roll=0.0, flash=0, stain=0):
    im = Image.new("RGBA", (80, 120), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    b = bob
    # patas y zapatos grises
    for i, off in enumerate(legs):
        x = 30 + i * 14
        d.rectangle([x, 104 + b, x + 5, 114 - abs(off)], fill=GREY_DK)
        d.rectangle([x - 1, 113 - abs(off), x + 7, 116 - abs(off)], fill=GREY_SH)
    # abrigo gris: una campana larga que se va desteniendo hacia abajo
    d.polygon([(24 + lean, 52 + b), (56 + lean, 52 + b), (64, 108 + b), (16, 108 + b)], fill=GREY)
    d.polygon([(24 + lean, 52 + b), (34 + lean, 52 + b), (28, 108 + b), (16, 108 + b)], fill=GREY_DK)
    d.polygon([(46 + lean, 52 + b), (56 + lean, 52 + b), (64, 108 + b), (52, 108 + b)], fill=GREY_HI)
    d.line([(40, 62 + b), (40, 106 + b)], fill=GREY_DK)
    # los colores que se le escurren: franjas de la bandera lavadas en el bajo del abrigo
    for i, (_, col, _, _) in enumerate(STRIPES):
        x0 = 20 + i * 7
        h = 10 + ((i * 7 + stain) % 5) * 3
        faded = tuple(int(c * 0.55 + 140 * 0.45) for c in col[:3]) + (255,)
        d.rectangle([x0, 108 + b - h, x0 + 5, 108 + b], fill=faded)
        d.rectangle([x0, 108 + b, x0 + 5, 108 + b + 2 + (i + stain) % 3], fill=faded)
    d.rectangle([16, 106 + b, 64, 108 + b], fill=GREY_SH)
    # solapas con botones
    d.polygon([(34 + lean, 52 + b), (40 + lean, 66 + b), (46 + lean, 52 + b)], fill=GREY_HI)
    for y in (72, 82, 92):
        d.ellipse([38, y + b, 42, y + 4 + b], fill=GREY_SH)
    # cabeza: un bloque de censura (caja gris con rendija de ojos)
    d.rounded_rectangle([22 + lean, 12 + b, 58 + lean, 54 + b], radius=5, fill=GREY_DK)
    d.rounded_rectangle([24 + lean, 14 + b, 56 + lean, 52 + b], radius=4, fill=GREY)
    d.rectangle([24 + lean, 14 + b, 29 + lean, 52 + b], fill=GREY_HI)
    d.rectangle([51 + lean, 14 + b, 56 + lean, 52 + b], fill=GREY_DK)
    # franja negra de censura sobre los ojos
    d.rectangle([22 + lean, 26 + b, 58 + lean, 40 + b], fill=INK)
    for cx in (32, 48):
        if eyes == "x":
            d.line([(cx - 4 + lean, 29 + b), (cx + 4 + lean, 37 + b)], fill=WHITE, width=2)
            d.line([(cx - 4 + lean, 37 + b), (cx + 4 + lean, 29 + b)], fill=WHITE, width=2)
        else:
            d.rectangle([cx - 4 + lean, 30 + b, cx + 4 + lean, 36 + b], fill=WHITE)
            d.rectangle([cx - 1 + lean, 31 + b, cx + 3 + lean, 36 + b], fill=INK)
    if eyes == "angry":
        d.line([(26 + lean, 27 + b), (38 + lean, 31 + b)], fill=GREY_HI, width=2)
        d.line([(54 + lean, 27 + b), (42 + lean, 31 + b)], fill=GREY_HI, width=2)
    # boca: cremallera cerrada (o abierta al atacar)
    if mouth == "open":
        d.rectangle([32 + lean, 44 + b, 48 + lean, 50 + b], fill=INK)
        d.rectangle([34 + lean, 44 + b, 46 + lean, 45 + b], fill=WHITE)
    else:
        d.line([(30 + lean, 46 + b), (50 + lean, 46 + b)], fill=INK, width=2)
        for x in range(31, 50, 3):
            d.line([(x + lean, 44 + b), (x + lean, 48 + b)], fill=INK)
    # sombrero de funcionario gris con sello
    d.rectangle([20 + lean, 8 + b, 60 + lean, 14 + b], fill=GREY_SH)
    d.rectangle([28 + lean, 0 + b, 52 + lean, 10 + b], fill=GREY_DK)
    d.rectangle([28 + lean, 7 + b, 52 + lean, 9 + b], fill=INK)
    # brazo derecho + rodillo gigante de pintura gris
    sx, sy = 56 + lean, 58 + b
    hx, hy = 63, (72 if arm == "down" else 54) + b
    d.line([(sx, sy), (hx, hy)], fill=GREY, width=6)
    handle = Image.new("RGBA", (80, 120), (0, 0, 0, 0))
    hd = ImageDraw.Draw(handle)
    hd.rectangle([61, 40, 64, 104], fill=WOOD)                                                 # mango
    hd.line([(62, 40), (62, 104)], fill=WOOD_HI)
    hd.line([(63, 24), (63, 40)], fill=GREY_SH, width=2)                                      # varilla
    hd.rectangle([46, 6, 78, 24], fill=GREY_HI)                                               # rodillo
    hd.rectangle([46, 6, 78, 9], fill=WHITE)
    hd.rectangle([46, 20, 78, 24], fill=GREY)
    hd.rectangle([44, 8, 47, 22], fill=GREY_SH)
    hd.rectangle([77, 8, 79, 22], fill=GREY_SH)
    for gx in (52, 60, 68, 74):
        hd.line([(gx, 24), (gx, 28 + (gx % 5))], fill=GREY_DK)                                # gotas de gris
    if roll:
        handle = handle.rotate(roll, resample=Image.NEAREST, center=(hx, hy))
    if b:
        handle = handle.transform(handle.size, Image.AFFINE, (1, 0, 0, 0, 1, -b), resample=Image.NEAREST)
    im.alpha_composite(handle)
    d2 = ImageDraw.Draw(im)
    d2.ellipse([hx - 4, hy - 3, hx + 4, hy + 4], fill=GREY_HI)
    # brazo izquierdo con un sello de CENSURADO
    d2.line([(26 + lean, 58 + b), (14, 74 + b)], fill=GREY, width=6)
    d2.rectangle([5, 68 + b, 21, 86 + b], fill=PAPER)
    d2.rectangle([5, 68 + b, 21, 72 + b], fill=INK)
    d2.line([(7, 77 + b), (19, 77 + b)], fill=INK)
    d2.line([(7, 81 + b), (16, 81 + b)], fill=INK)
    d2.ellipse([12, 72 + b, 20, 80 + b], fill=(0, 0, 0, 0))
    out = G.outline(im)
    if flash:
        out = G.tint(out, (255, 255, 255), 0.55)
    return out


def frames_destine():
    idle = destine(0)
    walk = [destine(0, (3, 0), stain=0), destine(-1, (0, 0), stain=1), destine(0, (0, 3), stain=2), destine(-1, (0, 0), stain=3)]
    attack = [destine(0, roll=-14, arm="up", mouth="open"), destine(-1, roll=-60, arm="up", mouth="open", lean=-2),
              destine(1, roll=-100, arm="up", mouth="open", lean=-3)]
    hurt = [destine(2, lean=-3, eyes="x", mouth="open", flash=1), destine(1, lean=-2, eyes="x", mouth="open")]
    dead = destine(0, eyes="x", mouth="open")
    death = [death_frame(dead, i, center=(40, 112)) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


# ------------------------------------------------------------------ objetos: un icono por franja (24x24)
def medallon(col, hi, dk):
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([2, 2, 21, 21], fill=col)
    d.pieslice([2, 2, 21, 21], 190, 290, fill=hi)
    d.ellipse([2, 2, 21, 21], outline=dk)
    d.arc([4, 4, 19, 19], 20, 120, fill=dk)
    return im, d


def icono_rojo():
    """Vida: corazon."""
    im, d = medallon(*STRIPES[0][1:])
    d.polygon([(12, 18), (6, 12), (6, 9), (8, 7), (10, 7), (12, 9), (14, 7), (16, 7), (18, 9), (18, 12)], fill=WHITE)
    d.point((8, 9), fill=RED_HI)
    return outline(im)


def icono_naranja():
    """Sanacion: curita."""
    im, d = medallon(*STRIPES[1][1:])
    band = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    bd = ImageDraw.Draw(band)
    bd.rounded_rectangle([3, 9, 20, 15], radius=3, fill=(255, 226, 190, 255))
    bd.rectangle([9, 9, 14, 15], fill=(255, 250, 235, 255))
    for x in (5, 7, 16, 18):
        bd.point((x, 11), fill=ORANGE_DK)
        bd.point((x, 13), fill=ORANGE_DK)
    band = band.rotate(35, resample=Image.NEAREST, center=(12, 12))
    im.alpha_composite(band)
    return outline(im)


def icono_amarillo():
    """Luz: sol con rayos."""
    im, d = medallon(*STRIPES[2][1:])
    d.ellipse([8, 8, 15, 15], fill=WHITE)
    for ang in range(0, 360, 45):
        a = math.radians(ang)
        d.line([(11.5 + math.cos(a) * 5, 11.5 + math.sin(a) * 5), (11.5 + math.cos(a) * 8, 11.5 + math.sin(a) * 8)], fill=WHITE)
    return outline(im)


def icono_verde():
    """Naturaleza: hoja con espina."""
    im, d = medallon(*STRIPES[3][1:])
    d.polygon([(6, 17), (7, 10), (12, 6), (18, 6), (18, 12), (13, 17)], fill=WHITE)
    d.line([(7, 17), (16, 8)], fill=GREEN_DK)
    d.polygon([(11, 6), (12, 3), (13, 6)], fill=GREEN_HI)
    d.polygon([(19, 9), (22, 10), (19, 12)], fill=GREEN_HI)
    return outline(im)


def icono_azul():
    """Serenidad: gota / escudo de agua."""
    im, d = medallon(*STRIPES[4][1:])
    d.polygon([(12, 4), (17, 12), (17, 15), (15, 18), (9, 18), (7, 15), (7, 12)], fill=WHITE)
    d.ellipse([9, 12, 11, 15], fill=BLUE_HI)
    d.arc([8, 9, 16, 17], 30, 150, fill=BLUE_DK)
    return outline(im)


def icono_violeta():
    """Espiritu: llama fantasma."""
    im, d = medallon(*STRIPES[5][1:])
    d.polygon([(12, 4), (16, 10), (17, 15), (14, 19), (10, 19), (7, 15), (8, 10)], fill=WHITE)
    d.ellipse([9, 12, 11, 14], fill=VIOLET_DK)
    d.ellipse([13, 12, 15, 14], fill=VIOLET_DK)
    d.line([(10, 16), (14, 16)], fill=VIOLET_DK)
    return outline(im)


ICONOS = {"rojo": icono_rojo, "naranja": icono_naranja, "amarillo": icono_amarillo,
          "verde": icono_verde, "azul": icono_azul, "violeta": icono_violeta}


# ------------------------------------------------------------------ decorado
def decor_banderin():
    """Banderin de tela con los 6 colores que cuelga (24x34)."""
    im = Image.new("RGBA", (24, 34), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.line([(2, 1), (22, 1)], fill=WOOD_DK, width=2)
    d.polygon([(3, 3), (21, 3), (21, 30), (12, 25), (3, 30)], fill=WHITE)
    for i, (_, col, _, _) in enumerate(STRIPES):
        y = 3 + i * 4
        d.polygon([(3, y), (21, y), (21, y + 4), (3, y + 4)] if y + 4 < 25 else [(3, y), (21, y), (21, y + 4 - (y - 21) // 2), (12, 25), (3, y + 4 - (y - 21) // 2)], fill=col)
    return outline(im)


def decor_maceta():
    """Maceta con margaritas de colores (24x30)."""
    im = Image.new("RGBA", (24, 30), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(5, 18), (19, 18), (17, 29), (7, 29)], fill=(190, 96, 70, 255))
    d.rectangle([4, 16, 20, 19], fill=(216, 130, 96, 255))
    for (x, y, c) in ((7, 9, 0), (12, 5, 2), (17, 9, 4), (9, 13, 1), (15, 13, 5)):
        d.line([(x, y + 3), (12, 17)], fill=GREEN_DK)
        col = STRIPES[c][1]
        for ang in range(0, 360, 72):
            a = math.radians(ang)
            d.ellipse([x + math.cos(a) * 2.4 - 1.5, y + math.sin(a) * 2.4 - 1.5, x + math.cos(a) * 2.4 + 1.5, y + math.sin(a) * 2.4 + 1.5], fill=col)
        d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=YELLOW_HI)
    return outline(im)


def decor_guirnalda():
    """Guirnalda de banderines de colores (56x18)."""
    im = Image.new("RGBA", (56, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(1 + i, 2 + int(round(math.sin(i / 54.0 * math.pi) * 4))) for i in range(54)]
    for p0, p1 in zip(pts, pts[1:]):
        d.line([p0, p1], fill=WOOD_DK)
    for i in range(7):
        x = 5 + i * 7
        y = pts[x][1]
        col = STRIPES[i % 6][1]
        d.polygon([(x - 2, y + 1), (x + 3, y + 1), (x + 0, y + 8)], fill=col)
    return outline(im)


def proyectil_etiqueta():
    """Etiqueta adhesiva que vuela (16x16)."""
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.polygon([(2, 3), (13, 3), (14, 5), (14, 12), (2, 12)], fill=YELLOW)
    d.polygon([(11, 3), (14, 6), (14, 12), (10, 12)], fill=YELLOW_DK)
    d.line([(4, 6), (11, 6)], fill=INK)
    d.line([(4, 8), (9, 8)], fill=INK)
    d.line([(4, 10), (7, 10)], fill=INK)
    d.polygon([(2, 12), (6, 12), (2, 9)], fill=PAPER)
    return outline(im)


# ------------------------------------------------------------------ salida
VARIANTS = {
    "rumor": frames_rumor, "comentario": frames_comentario, "mirada": frames_mirada,
    "fase": frames_fase, "armario": frames_armario, "hombre": frames_hombre,
    "hombre_l": frames_hombre_l, "hombre_r": frames_hombre_r, "etiqueta": frames_etiqueta,
    "destine": frames_destine,
}


def save_variant(v):
    anims = VARIANTS[v]()
    for name, frames in anims.items():
        for i, im in enumerate(frames):
            im.save(OUT / f"{v}_{name}_{i:02d}.png")
    G.write_frames_tres(v, anims)
    print("ok", v, sum(len(f) for f in anims.values()), "frames")


def save_objetos():
    for nombre, fn in ICONOS.items():
        fn().save(ROOT / f"assets/sprites/items/bandera_{nombre}.png")
    print("ok objetos", len(ICONOS))


def save_decor():
    d = ROOT / "assets/sprites/environment/decor"
    decor_banderin().save(d / "orgullo_banderin.png")
    decor_maceta().save(d / "orgullo_maceta.png")
    decor_guirnalda().save(d / "orgullo_guirnalda.png")
    print("ok decor")


def preview(dest):
    """Hoja de contacto (x4) de los cuadros principales."""
    names = [v for v in VARIANTS if v != "destine"]
    sheet = Image.new("RGBA", (len(names) * 140, 4 * 200 + 200), (60, 56, 76, 255))
    for col, v in enumerate(names):
        anims = VARIANTS[v]()
        order = [("idle", 0), ("walk", 1), ("attack", 2), ("hurt", 0)]
        extra = [k for k in anims if k in ("ghost", "open")]
        for row, (an, idx) in enumerate(order[:4]):
            fr = anims[an][min(idx, len(anims[an]) - 1)]
            sheet.alpha_composite(fr.resize((fr.width * 4, fr.height * 4), Image.NEAREST).crop((0, 0, 130, 192)), (col * 140, row * 200))
        for k in extra:
            fr = anims[k][0]
            sheet.alpha_composite(fr.resize((fr.width * 2, fr.height * 2), Image.NEAREST), (col * 140, 800))
    sheet.save(Path(dest) / "arc_enemigos.png")
    bs = destine()
    iconos = Image.new("RGBA", (6 * 100, 100), (60, 56, 76, 255))
    for i, fn in enumerate(ICONOS.values()):
        ic = fn()
        iconos.alpha_composite(ic.resize((96, 96), Image.NEAREST), (i * 100, 2))
    iconos.save(Path(dest) / "arc_iconos.png")
    boss = Image.new("RGBA", (3 * 340, 500), (60, 56, 76, 255))
    for i, fr in enumerate((frames_destine()["idle"][0], frames_destine()["attack"][1], frames_destine()["hurt"][0])):
        boss.alpha_composite(fr.resize((fr.width * 4, fr.height * 4), Image.NEAREST), (i * 340, 10))
    boss.save(Path(dest) / "arc_jefe.png")
    deco = Image.new("RGBA", (3 * 260, 200), (60, 56, 76, 255))
    for i, im in enumerate((decor_banderin(), decor_maceta(), decor_guirnalda())):
        deco.alpha_composite(im.resize((im.width * 4, im.height * 4), Image.NEAREST), (i * 260, 4))
    deco.save(Path(dest) / "arc_decor.png")
    print("ok preview ->", dest)


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["preview"]:
        preview(args[1] if len(args) > 1 else ".")
        sys.exit(0)
    todo = args or (list(VARIANTS) + ["objetos", "decor", "proyectiles"])
    for t in todo:
        if t == "objetos":
            save_objetos()
        elif t == "decor":
            save_decor()
        elif t == "proyectiles":
            proyectil_etiqueta().save(ROOT / "assets/sprites/projectiles/etiqueta.png")
            print("ok proyectiles")
        else:
            save_variant(t)
