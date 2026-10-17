"""Genera sprites de enemigos (32x48, mirando a la derecha) + su SpriteFrames .tres.

Uso: python3 tools/gen_enemy_art.py [variante ...]   (sin args = todas)
Cada frame se dibuja a 1x con poligonos y luego se le pasa un contorno
automatico #0d0b0f, igual que el resto de los enemigos.
"""
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/sprites/enemies"
W, H = 32, 48
OUTLINE = (13, 11, 15, 255)

# metal quirurgico
M_HI = (236, 240, 246, 255)
M_LO = (176, 184, 198, 255)
M_DK = (110, 116, 134, 255)
M_SH = (78, 82, 98, 255)
MOUTH = (90, 24, 44, 255)
TEETH = (255, 250, 236, 255)
EYE_W = (255, 255, 255, 255)
PUPIL = (20, 16, 24, 255)
BLUSH = (255, 120, 170, 255)


def outline(im: Image.Image) -> Image.Image:
    w, h = im.size
    src = im.load()
    out = im.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] and src[nx, ny] != OUTLINE:
                    dst[x, y] = OUTLINE
                    break
    return out


def rot(pts, cx, cy, deg):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]


# ------------------------------------------------------------------ especulo
def especulo(open_deg=6.0, bob=0, legs=(0, 0), lean=0, eyes="angry"):
    """Especulo con patitas: el cuerpo es la bisagra con tornillo y las dos
    valvas son la boca. open_deg abre las valvas (morder = abrir y cerrar)."""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    y0 = bob
    # patitas (la izquierda/derecha suben alternadas al caminar)
    for lx, up in ((9, legs[0]), (15, legs[1])):
        d.rectangle([lx, 39 + y0 - up, lx + 2, 44 - up], fill=M_DK)
        d.rectangle([lx - 1, 45 - up, lx + 3, 46 - up], fill=M_SH)
    hx, hy = 19 + lean, 31 + y0  # bisagra de las valvas
    # interior de la boca + dientes (solo se ve si esta abierta)
    upper = [(hx - 1, hy - 4), (hx + 9, hy - 3), (hx + 12, hy - 2), (hx + 12, hy), (hx - 1, hy)]
    lower = [(hx - 1, hy + 1), (hx + 12, hy + 1), (hx + 12, hy + 3), (hx + 9, hy + 4), (hx - 1, hy + 5)]
    up_r = rot(upper, hx, hy, -open_deg)
    lo_r = rot(lower, hx, hy + 1, open_deg)
    if open_deg > 8:
        d.polygon([up_r[4], up_r[3], lo_r[2], lo_r[0]], fill=MOUTH)
        for t in range(3):
            f = 0.35 + t * 0.25
            for pts, sgn in ((up_r, 1), (lo_r, -1)):
                a, b = (pts[4], pts[3]) if sgn == 1 else (pts[0], pts[1])
                tx = a[0] + (b[0] - a[0]) * f
                ty = a[1] + (b[1] - a[1]) * f
                d.polygon([(tx - 1, ty), (tx + 1, ty), (tx, ty + 2 * sgn)], fill=TEETH)
    # valvas: tono medio, filo de brillo arriba y sombra abajo
    d.polygon(up_r, fill=M_LO)
    d.line([up_r[0], up_r[1], up_r[2]], fill=M_HI)
    d.polygon(lo_r, fill=M_LO)
    d.line([lo_r[3], lo_r[4]], fill=M_DK)
    d.line([lo_r[2], lo_r[3]], fill=M_DK)
    # cuerpo / bisagra
    bx0, by0, bx1, by1 = 5 + lean, 21 + y0, 20 + lean, 40 + y0
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=4, fill=M_LO)
    d.rounded_rectangle([bx0 + 1, by0 + 1, bx0 + 4, by1 - 2], radius=2, fill=M_HI)
    d.rectangle([bx1 - 2, by0 + 3, bx1 - 1, by1 - 3], fill=M_DK)
    d.line([(bx0 + 2, by1 - 1), (bx1 - 2, by1 - 1)], fill=M_DK)
    # tornillo de apertura arriba
    d.rectangle([bx0 + 6, by0 - 5, bx0 + 8, by0], fill=M_DK)
    d.rounded_rectangle([bx0 + 3, by0 - 8, bx0 + 11, by0 - 5], radius=1, fill=M_LO)
    d.line([(bx0 + 4, by0 - 7), (bx0 + 10, by0 - 7)], fill=M_HI)
    # cara
    ex, ey = bx0 + 6, by0 + 6
    if eyes == "x":
        for cx in (ex, ex + 6):
            d.line([(cx - 1, ey - 1), (cx + 1, ey + 1)], fill=PUPIL)
            d.line([(cx - 1, ey + 1), (cx + 1, ey - 1)], fill=PUPIL)
    else:
        for cx in (ex, ex + 6):
            d.rectangle([cx - 1, ey - 1, cx + 2, ey + 2], fill=EYE_W)
            d.rectangle([cx + 1, ey, cx + 2, ey + 1], fill=PUPIL)
        if eyes == "angry":  # cejas en V
            d.line([(ex - 2, ey - 3), (ex + 2, ey - 2)], fill=PUPIL)
            d.line([(ex + 4, ey - 2), (ex + 8, ey - 3)], fill=PUPIL)
        d.point([(ex - 1, ey + 4), (ex + 7, ey + 4)], fill=BLUSH)
    return outline(im)


def tint(im, rgb, k):
    px = im.load()
    out = im.copy()
    po = out.load()
    for y in range(im.size[1]):
        for x in range(im.size[0]):
            r, g, b, a = px[x, y]
            if a:
                po[x, y] = (int(r + (rgb[0] - r) * k), int(g + (rgb[1] - g) * k), int(b + (rgb[2] - b) * k), a)
    return out


def death_frame(base, i, center=(14, 44)):
    """Se desarma: se ladea, se hunde y se apaga (4 frames)."""
    f = [(0.0, 0, 1.0, 0.0), (-25, 4, 0.85, 0.25), (-60, 10, 0.6, 0.45), (-90, 16, 0.35, 0.6)][i]
    ang, sink, alpha, dark = f
    im = tint(base, (40, 30, 50), dark).rotate(ang, resample=Image.NEAREST, center=center)
    out = Image.new("RGBA", base.size, (0, 0, 0, 0))
    out.alpha_composite(im, (0, sink if sink < 4 else 2))
    px = out.load()
    for y in range(base.size[1]):
        for x in range(base.size[0]):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, int(a * alpha))
    return out


def frames_especulo():
    idle = especulo(6)
    walk = [especulo(6, 0, (2, 0)), especulo(4, -1, (0, 0)), especulo(6, 0, (0, 2)), especulo(4, -1, (0, 0))]
    attack = [especulo(18, 0, eyes="angry"), especulo(32, 0, lean=-1), especulo(42, 0, lean=-2)]
    bite = [especulo(42, 0, lean=-1), especulo(0, 0, lean=2), especulo(4, 0, lean=1)]
    hurt = [tint(especulo(14, 0, eyes="hurt"), (255, 60, 70), 0.55), tint(especulo(10, 0, eyes="hurt"), (255, 255, 255), 0.4)]
    dead = especulo(25, 0, eyes="x")
    death = [death_frame(dead, i) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "bite": bite, "hurt": hurt, "death": death}


# ---------------------------------------------------------- dildo electrico
P_MD = (232, 84, 178, 255)
P_DK = (150, 40, 118, 255)
P_HI = (255, 150, 214, 255)
P_TIP = (255, 150, 214, 255)
G_MD = (134, 138, 153, 255)
G_DK = (70, 72, 86, 255)
G_SH = (50, 52, 64, 255)
G_HI = (216, 221, 227, 255)
B_HI = (150, 214, 255, 255)
B_MD = (74, 150, 240, 255)
B_DK = (44, 92, 190, 255)
B_SH = (30, 56, 128, 255)
BOLT = (255, 226, 80, 255)
BOLT_HI = (255, 250, 200, 255)
SPARK = (120, 240, 255, 255)


def spark_zig(d, x0, y0, x1, y1, col, seed=0):
    """Rayito en zigzag de 1 px entre dos puntos."""
    pts = [(x0, y0)]
    n = 4
    for i in range(1, n):
        t = i / n
        off = ((i + seed) % 3 - 1) * 2
        pts.append((x0 + (x1 - x0) * t + off, y0 + (y1 - y0) * t + (off // 2)))
    pts.append((x1, y1))
    d.line(pts, fill=col)


def dildo_electrico(bob=0, legs=(0, 0), lean=0, eyes="angry", charge=0, seed=0):
    """Cilindro rosa erguido de punta redondeada mas clara (como el arma dildo_taser),
    base metalica gris con patitas y chispas cian/amarillas en la punta.
    charge 0..2 = cuanta chispa le sale (aviso del disparo)."""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    y0 = bob
    # patitas
    for lx, up in ((10 + lean, legs[0]), (17 + lean, legs[1])):
        d.rectangle([lx, 42 + y0 - up, lx + 3, 45 - up], fill=G_DK)
        d.rectangle([lx - 1, 45 - up, lx + 4, 46 - up], fill=G_SH)
    bx0, bx1 = 8 + lean, 23 + lean
    top, base = 13 + y0, 33 + y0
    # cuerpo rosa
    d.rectangle([bx0, top + 6, bx1, base], fill=P_MD)
    d.rectangle([bx1 - 3, top + 6, bx1 - 1, base], fill=P_DK)
    d.rectangle([bx0 + 1, top + 6, bx0 + 3, base], fill=P_HI)
    # punta redondeada mas clara
    d.rounded_rectangle([bx0, top, bx1, top + 14], radius=7, fill=P_TIP)
    d.rectangle([bx1 - 3, top + 4, bx1 - 1, top + 13], fill=P_MD)
    d.rectangle([bx0 + 2, top + 2, bx0 + 4, top + 4], fill=(255, 215, 238, 255))
    # base metalica gris
    d.rounded_rectangle([bx0 - 1, base + 1, bx1 + 1, base + 9], radius=2, fill=G_MD)
    d.rectangle([bx0, base + 2, bx0 + 2, base + 8], fill=G_HI)
    d.rectangle([bx1 - 2, base + 2, bx1, base + 8], fill=G_DK)
    d.line([(bx0 + 2, base + 5), (bx1 - 2, base + 5)], fill=G_DK)
    # chispas en la punta
    ex = (bx0 + bx1) // 2
    ty = top - 1
    if charge >= 1:
        d.point([(ex - 1, ty - 1), (ex + 1, ty - 2)], fill=SPARK)
        spark_zig(d, ex - 3, ty - 2, ex + 3, ty - 2, SPARK, seed)
        d.point([(ex, ty - 3)], fill=BOLT_HI)
    if charge >= 2:
        spark_zig(d, ex - 4, ty, ex - 11, ty - 6, BOLT, seed + 1)
        spark_zig(d, ex + 4, ty, ex + 11, ty - 5, BOLT, seed + 2)
        spark_zig(d, ex, ty - 3, ex + 1, ty - 9, SPARK, seed + 3)
        d.point([(ex - 12, ty - 2), (ex + 12, ty), (ex - 7, ty - 9)], fill=SPARK)
    # cara
    fx, fy = bx0 + 3, top + 7
    if eyes == "x":
        for ecx in (fx, fx + 6):
            d.line([(ecx - 1, fy - 1), (ecx + 1, fy + 1)], fill=PUPIL)
            d.line([(ecx - 1, fy + 1), (ecx + 1, fy - 1)], fill=PUPIL)
    else:
        for ecx in (fx, fx + 6):
            d.rectangle([ecx - 1, fy - 1, ecx + 2, fy + 2], fill=EYE_W)
            d.rectangle([ecx + 1, fy, ecx + 2, fy + 1], fill=PUPIL)
        if eyes == "angry":
            d.line([(fx - 2, fy - 3), (fx + 2, fy - 2)], fill=PUPIL)
            d.line([(fx + 4, fy - 2), (fx + 8, fy - 3)], fill=PUPIL)
        d.point([(fx - 1, fy + 4), (fx + 7, fy + 4)], fill=BLUSH)
    # boca: sonrisa torcida; abierta al cargar
    if charge >= 1:
        d.rectangle([fx + 1, fy + 5, fx + 5, fy + 7], fill=MOUTH)
        d.line([(fx + 2, fy + 5), (fx + 4, fy + 5)], fill=TEETH)
    elif eyes == "hurt":
        d.line([(fx + 1, fy + 6), (fx + 5, fy + 5)], fill=PUPIL)
    else:
        d.line([(fx + 1, fy + 5), (fx + 5, fy + 5)], fill=PUPIL)
    return outline(im)


def frames_dildo_electrico():
    idle = dildo_electrico(0, charge=0)
    walk = [dildo_electrico(0, (2, 0), seed=0), dildo_electrico(-1, (0, 0), seed=1),
            dildo_electrico(0, (0, 2), seed=2), dildo_electrico(-1, (0, 0), seed=3)]
    attack = [dildo_electrico(0, charge=1, seed=0), dildo_electrico(-1, charge=2, lean=-1, seed=1),
              dildo_electrico(-1, charge=2, lean=-1, seed=2)]
    hurt = [tint(dildo_electrico(0, eyes="hurt", charge=1), (255, 60, 70), 0.55),
            tint(dildo_electrico(0, eyes="hurt"), (255, 255, 255), 0.4)]
    dead = dildo_electrico(0, eyes="x")
    death = [death_frame(dead, i) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


# ------------------------------------------------------------ perineo (aduana)
# grises de aduana + amarillo/negro de franja fronteriza
HAZ_Y = (255, 201, 60, 255)
HAZ_Y_DK = (214, 150, 30, 255)
HAZ_K = (34, 30, 38, 255)
GR_HI = (200, 204, 212, 255)
GR_MD = (150, 155, 168, 255)
GR_DK = (98, 102, 116, 255)
GR_SH = (62, 65, 78, 255)
# hemorroide
H_HI = (240, 120, 140, 255)
H_MD = (206, 70, 100, 255)
H_DK = (140, 38, 76, 255)
H_SH = (92, 24, 56, 255)


def haz_band(d, x0, y0, x1, y1, shift=0):
    """Franja amarilla y negra en diagonal (cartel de frontera)."""
    d.rectangle([x0, y0, x1, y1], fill=HAZ_Y)
    hh = y1 - y0
    for x in range(x0 - hh + shift % 8, x1 + 1, 8):
        d.polygon([(x, y1), (x + 3, y1), (x + 3 + hh, y0), (x + hh, y0)], fill=HAZ_K)


def hemorroide(bob=0, squash=0, lean=0, eyes="grumpy", mouth="frown", legs=(0, 0), stripe=0):
    """Hemorroide Fronteriza 48x72: racimo de bultos rojos y brillantes hecho barrera
    de aduana. Gorra gris de guardia, franja amarilla/negra en la barriga, patitas
    cortas. squash > 0 la achata (carga/pisoton), < 0 la estira."""
    from PIL import ImageChops
    w, h = 48, 72
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    base = 66  # suelo
    for lx, up in ((13, legs[0]), (28, legs[1])):
        d.rectangle([lx + lean, base - 6 - up, lx + 6 + lean, base - up], fill=H_DK)
        d.rectangle([lx - 1 + lean, base - 2 - up, lx + 8 + lean, base - up + 1], fill=H_SH)
    top = 18 + bob + max(0, squash)
    bot = 60 + bob
    lx0, rx1 = 4 + lean - squash // 2, 43 + lean + squash // 2
    # bultos de arriba (racimo)
    for cx, cy, r in ((14, top + 6, 8), (34, top + 6, 8), (24, top + 1, 9)):
        d.ellipse([cx - r + lean, cy - r, cx + r + lean, cy + r], fill=H_MD)
        d.ellipse([cx - r + 2 + lean, cy - r + 2, cx - 1 + lean, cy - 2], fill=H_HI)
    # cuerpo grande
    d.rounded_rectangle([lx0, top + 6, rx1, bot], radius=14, fill=H_MD)
    d.rounded_rectangle([lx0 + 3, top + 9, lx0 + 12, top + 24], radius=4, fill=H_HI)
    d.rounded_rectangle([rx1 - 8, top + 10, rx1 - 2, bot - 6], radius=4, fill=H_DK)
    d.line([(lx0 + 6, bot - 1), (rx1 - 6, bot - 1)], fill=H_SH)
    # franja fronteriza en la barriga (hay que rodearla)
    sy0, sy1 = bot - 17, bot - 8
    band = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    haz_band(ImageDraw.Draw(band), lx0 + 1, sy0, rx1 - 1, sy1, stripe)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([lx0, top + 6, rx1, bot], radius=14, fill=255)
    clip = Image.new("L", (w, h), 0)
    ImageDraw.Draw(clip).rectangle([lx0 + 1, sy0, rx1 - 1, sy1], fill=255)
    band.putalpha(ImageChops.multiply(ImageChops.multiply(band.getchannel("A"), mask), clip))
    im.alpha_composite(band)
    d = ImageDraw.Draw(im)
    d.line([(lx0 + 2, sy0 - 1), (rx1 - 2, sy0 - 1)], fill=HAZ_Y_DK)
    # gorra de guardia de aduana
    cx0, cx1 = 11 + lean, 36 + lean
    cy = top - 2
    d.rounded_rectangle([cx0, cy - 7, cx1, cy + 2], radius=3, fill=GR_MD)
    d.rectangle([cx0 + 2, cy - 6, cx0 + 6, cy - 2], fill=GR_HI)
    d.rectangle([cx0 - 2, cy + 1, cx1 + 4, cy + 3], fill=GR_DK)  # visera
    d.rectangle([cx0 + 9, cy - 5, cx0 + 15, cy - 1], fill=HAZ_Y)  # escarapela
    d.point([(cx0 + 12, cy - 3)], fill=HAZ_K)
    # cara
    fx, fy = 12 + lean, top + 14
    for ecx in (fx, fx + 14):
        if eyes == "x":
            d.line([(ecx - 2, fy - 2), (ecx + 2, fy + 2)], fill=PUPIL)
            d.line([(ecx - 2, fy + 2), (ecx + 2, fy - 2)], fill=PUPIL)
        else:
            d.rectangle([ecx - 3, fy - 3, ecx + 3, fy + 3], fill=EYE_W)
            d.rectangle([ecx, fy - 1, ecx + 3, fy + 2], fill=PUPIL)
    if eyes in ("grumpy", "angry"):
        d.line([(fx - 4, fy - 6), (fx + 3, fy - 4)], fill=PUPIL, width=2)
        d.line([(fx + 11, fy - 4), (fx + 18, fy - 6)], fill=PUPIL, width=2)
    d.point([(fx - 4, fy + 6), (fx + 18, fy + 6)], fill=BLUSH)
    mx, my = fx + 4, fy + 8
    if mouth == "open":
        d.rectangle([mx, my, mx + 10, my + 5], fill=MOUTH)
        d.line([(mx + 1, my), (mx + 9, my)], fill=TEETH)
    elif mouth == "hurt":
        d.line([(mx, my + 3), (mx + 4, my), (mx + 8, my + 3), (mx + 10, my)], fill=PUPIL)
    else:
        d.line([(mx, my + 3), (mx + 3, my), (mx + 7, my), (mx + 10, my + 3)], fill=PUPIL, width=1)
    return outline(im)


def frames_hemorroide():
    c = (24, 66)
    idle = hemorroide()
    walk = [hemorroide(0, 0, 0, legs=(3, 0), stripe=0), hemorroide(-1, 1, 0, stripe=2),
            hemorroide(0, 0, 0, legs=(0, 3), stripe=4), hemorroide(-1, 1, 0, stripe=6)]
    attack = [hemorroide(2, 4, 0, mouth="open", eyes="angry"), hemorroide(3, 7, 0, mouth="open", eyes="angry"),
              hemorroide(-1, -2, 2, mouth="open", eyes="angry")]
    hurt = [tint(hemorroide(1, 2, 0, eyes="hurt", mouth="hurt"), (255, 60, 70), 0.55),
            tint(hemorroide(0, 0, 0, eyes="hurt", mouth="hurt"), (255, 255, 255), 0.4)]
    dead = hemorroide(0, 0, 0, eyes="x", mouth="hurt")
    death = [death_frame(dead, i, c) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


# ------------------------------------------------------ inspector de fluidos
GL_HI = (214, 240, 250, 255)
GL_MD = (160, 206, 226, 255)
GL_DK = (104, 150, 180, 255)
FLUID = (232, 222, 130, 255)
FLUID_DK = (196, 180, 78, 255)
STAMP_R = (214, 48, 56, 255)
STAMP_R_HI = (255, 120, 120, 255)
WOOD = (150, 98, 62, 255)
WOOD_DK = (100, 62, 40, 255)


def inspector(bob=0, legs=(0, 0), lean=0, eyes="angry", arm="down", glow=0):
    """Inspector de Fluidos: tubo de ensayo con gorra de aduana y un sello de
    goma en la mano. arm: down (reposo) | up (arma el sello) | slam (lo estampa)."""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    y0 = bob
    for lx, up in ((10 + lean, legs[0]), (16 + lean, legs[1])):
        d.rectangle([lx, 42 + y0 - up, lx + 3, 45 - up], fill=GR_DK)
        d.rectangle([lx - 1, 45 - up, lx + 4, 46 - up], fill=GR_SH)
    bx0, bx1 = 8 + lean, 23 + lean
    top, base = 14 + y0, 43 + y0
    # tubo de vidrio con el fluido dentro
    d.rounded_rectangle([bx0, top, bx1, base - 1], radius=6, fill=GL_MD)
    d.rectangle([bx0 + 1, top + 3, bx0 + 3, base - 6], fill=GL_HI)
    d.rectangle([bx1 - 3, top + 3, bx1 - 1, base - 5], fill=GL_DK)
    d.rounded_rectangle([bx0 + 1, top + 16, bx1 - 1, base - 2], radius=5, fill=FLUID)
    d.rectangle([bx1 - 3, top + 18, bx1 - 2, base - 4], fill=FLUID_DK)
    d.line([(bx0 + 2, top + 16), (bx1 - 2, top + 16)], fill=FLUID_DK)
    # etiqueta amarilla/negra
    d.rectangle([bx0 + 1, top + 24, bx1 - 1, top + 26], fill=HAZ_Y)
    for x in range(bx0 + 2, bx1 - 1, 4):
        d.point([(x, top + 24), (x + 1, top + 25), (x + 2, top + 26)], fill=HAZ_K)
    # gorra de inspector
    d.rounded_rectangle([bx0 - 1, top - 6, bx1 + 1, top + 2], radius=3, fill=GR_MD)
    d.rectangle([bx0, top - 5, bx0 + 3, top - 2], fill=GR_HI)
    d.rectangle([bx0 - 2, top + 1, bx1 + 5, top + 3], fill=GR_DK)  # visera hacia la derecha
    d.rectangle([bx0 + 6, top - 4, bx0 + 9, top - 1], fill=HAZ_Y)
    # cara
    fx, fy = bx0 + 3, top + 8
    for ecx in (fx, fx + 6):
        if eyes == "x":
            d.line([(ecx - 1, fy - 1), (ecx + 1, fy + 1)], fill=PUPIL)
            d.line([(ecx - 1, fy + 1), (ecx + 1, fy - 1)], fill=PUPIL)
        else:
            d.rectangle([ecx - 1, fy - 1, ecx + 2, fy + 2], fill=EYE_W)
            d.rectangle([ecx + 1, fy, ecx + 2, fy + 1], fill=PUPIL)
    if eyes == "angry":
        d.line([(fx - 2, fy - 3), (fx + 2, fy - 2)], fill=PUPIL)
        d.line([(fx + 4, fy - 2), (fx + 8, fy - 3)], fill=PUPIL)
    d.point([(fx - 1, fy + 4), (fx + 7, fy + 4)], fill=BLUSH)
    if arm == "slam" or glow:
        d.line([(fx + 1, fy + 6), (fx + 5, fy + 6)], fill=PUPIL)
    elif eyes == "hurt":
        d.line([(fx + 1, fy + 7), (fx + 5, fy + 6)], fill=PUPIL)
    else:
        d.line([(fx + 1, fy + 6), (fx + 3, fy + 7), (fx + 5, fy + 6)], fill=PUPIL)
    # brazo + sello de goma
    sx = bx1 + 1
    if arm == "down":
        ay = top + 20
    elif arm == "up":
        ay, hy0 = top + 12, top - 6
    else:
        ay, hy0 = top + 18, top + 8
    d.line([(sx - 1, top + 20), (sx + 3, ay)], fill=GL_DK, width=2)
    if arm == "down":
        d.rectangle([sx + 2, ay - 1, sx + 5, ay + 5], fill=WOOD)
        d.rectangle([sx + 5, ay - 1, sx + 5, ay + 5], fill=WOOD_DK)
        d.rectangle([sx + 1, ay + 5, sx + 6, ay + 7], fill=STAMP_R)
    else:
        d.rectangle([sx + 2, hy0 + 4, sx + 5, hy0 + 11], fill=WOOD)
        d.rectangle([sx + 5, hy0 + 4, sx + 5, hy0 + 11], fill=WOOD_DK)
        d.rectangle([sx, hy0 + 11, sx + 7, hy0 + 14], fill=STAMP_R)
        d.line([(sx, hy0 + 11), (sx + 7, hy0 + 11)], fill=STAMP_R_HI)
        d.rectangle([sx + 1, hy0 + 2, sx + 6, hy0 + 4], fill=WOOD_DK)
    if glow:
        px = im.load()
        for yy in range(H):
            for xx in range(W):
                if px[xx, yy][3] and px[xx, yy][0] > 190 and px[xx, yy][1] < 80:
                    px[xx, yy] = STAMP_R_HI
    return outline(im)


def frames_inspector():
    idle = inspector()
    walk = [inspector(0, (2, 0)), inspector(-1, (0, 0)), inspector(0, (0, 2)), inspector(-1, (0, 0))]
    attack = [inspector(0, arm="up", glow=0), inspector(-1, lean=-1, arm="up", glow=1),
              inspector(0, lean=1, arm="slam", glow=1)]
    hurt = [tint(inspector(0, eyes="hurt"), (255, 60, 70), 0.55), tint(inspector(0, eyes="hurt"), (255, 255, 255), 0.4)]
    dead = inspector(0, eyes="x")
    death = [death_frame(dead, i) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


# -------------------------------------------------------------- pelusa perineal
FZ_HI = (222, 222, 230, 255)
FZ_MD = (176, 176, 188, 255)
FZ_DK = (122, 122, 138, 255)


def pelusa(bob=0, seed=0, puff=0, eyes="angry", spread=0.0):
    """Pelusa Perineal 24x36: bola de pelusa gris con hebras sueltas. Flota (no tiene
    patitas), con una escarapela amarilla de aduana. puff > 0 la hincha; spread
    separa las hebras (muerte: se deshace en pelusilla)."""
    w, h = 24, 36
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = 12, 20 + bob
    r0 = 8 + puff
    pts = []
    n = 18
    for i in range(n):
        a = 2 * math.pi * i / n
        j = 1.6 * (1 if (i + seed) % 2 == 0 else -0.4) + (0.8 if (i + seed) % 3 == 0 else 0)
        r = (r0 + j) * (1 + spread)
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r * 0.92))
    d.polygon(pts, fill=FZ_MD)
    d.ellipse([cx - r0 + 2, cy - r0 + 1, cx - 1, cy - 1], fill=FZ_HI)
    d.ellipse([cx + 1, cy + 1, cx + r0 - 2, cy + r0 - 2], fill=FZ_DK)
    # hebras sueltas arriba y a los lados
    for k, (dx, dy) in enumerate(((-6, -10), (0, -12), (6, -10), (-11, -2), (11, -3), (-9, 7), (9, 8))):
        o = ((k + seed) % 3 - 1) * 1.5
        x0, y0_ = cx + dx * 0.55, cy + dy * 0.55
        d.line([(x0, y0_), (cx + dx * (1 + spread * 1.3) + o, cy + dy * (1 + spread * 1.3))], fill=FZ_DK if k % 2 else FZ_MD)
    # escarapela de aduana en la coronilla
    d.rectangle([cx - 3, cy - r0 - 1, cx + 2, cy - r0 + 2], fill=HAZ_Y)
    d.point([(cx - 1, cy - r0 + 1), (cx, cy - r0)], fill=HAZ_K)
    # cara
    for ecx in (cx - 4, cx + 3):
        if eyes == "x":
            d.line([(ecx - 1, cy - 2), (ecx + 1, cy)], fill=PUPIL)
            d.line([(ecx - 1, cy), (ecx + 1, cy - 2)], fill=PUPIL)
        else:
            d.rectangle([ecx - 1, cy - 3, ecx + 2, cy], fill=EYE_W)
            d.rectangle([ecx + 1, cy - 2, ecx + 2, cy - 1], fill=PUPIL)
    if eyes == "angry":
        d.line([(cx - 6, cy - 5), (cx - 2, cy - 4)], fill=PUPIL)
        d.line([(cx + 2, cy - 4), (cx + 6, cy - 5)], fill=PUPIL)
    d.point([(cx - 6, cy + 2), (cx + 5, cy + 2)], fill=BLUSH)
    if eyes == "angry" and puff > 0:
        d.rectangle([cx - 2, cy + 3, cx + 1, cy + 5], fill=MOUTH)
    else:
        d.line([(cx - 2, cy + 4), (cx + 1, cy + 4)], fill=PUPIL)
    return outline(im)


def frames_pelusa():
    idle = pelusa(0, 0, eyes="happy")
    walk = [pelusa(0, 0, eyes="happy"), pelusa(-2, 1, eyes="happy"), pelusa(0, 2, eyes="happy"), pelusa(-2, 3, eyes="happy")]
    attack = [pelusa(0, 0, puff=1), pelusa(-1, 1, puff=2), pelusa(-1, 2, puff=2)]
    hurt = [tint(pelusa(0, 1, eyes="hurt"), (255, 60, 70), 0.55), tint(pelusa(0, 2, eyes="hurt"), (255, 255, 255), 0.4)]
    death = [pelusa(0, 0, eyes="x"), pelusa(-1, 1, eyes="x", spread=0.3), pelusa(-2, 2, eyes="x", spread=0.7),
             pelusa(-3, 3, eyes="x", spread=1.2)]
    for i, a in enumerate((255, 210, 140, 70)):  # se apaga como el resto
        px = death[i].load()
        for y in range(death[i].size[1]):
            for x in range(death[i].size[0]):
                r, g, b, al = px[x, y]
                px[x, y] = (r, g, b, int(al * a / 255))
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


# ------------------------------------------------------------------ microbios ITS
# Infecciones de transmision sexual: microbios caricaturescos 32x40 con carita. Los
# villanos son ellos, no las personas. Cada uno lleva un guino visual a su infeccion.
ITS_COL = {  # hi, md, dk
    "clamidia": ((236, 228, 255, 255), (196, 182, 236, 255), (140, 124, 190, 255)),
    "herpes": ((255, 170, 160, 255), (232, 96, 96, 255), (168, 52, 70, 255)),
    "gonorrea": ((236, 240, 130, 255), (186, 200, 66, 255), (122, 140, 40, 255)),
    "vph": ((255, 226, 196, 255), (230, 178, 140, 255), (170, 118, 96, 255)),
    "sifilis": ((220, 170, 255, 255), (160, 100, 220, 255), (104, 56, 160, 255)),
}
BLISTER = (255, 244, 214, 255)
WART = (190, 132, 100, 255)
WART_HI = (226, 176, 140, 255)
DROP = (150, 190, 40, 255)
DROP_HI = (214, 236, 120, 255)
MUST = (60, 36, 30, 255)
GLASS = (240, 240, 250, 255)


def its_eyes(d, cx, cy, eyes):
    for ecx in (cx - 5, cx + 3):
        if eyes == "x":
            d.line([(ecx - 1, cy - 2), (ecx + 2, cy + 1)], fill=PUPIL)
            d.line([(ecx - 1, cy + 1), (ecx + 2, cy - 2)], fill=PUPIL)
        elif eyes == "sleepy":  # asintomatica: parpados a media asta
            d.rectangle([ecx - 1, cy - 2, ecx + 3, cy + 1], fill=EYE_W)
            d.rectangle([ecx + 1, cy - 1, ecx + 2, cy + 1], fill=PUPIL)
            d.line([(ecx - 1, cy - 2), (ecx + 3, cy - 2)], fill=PUPIL)
        elif eyes == "hurt":
            d.line([(ecx - 1, cy - 1), (ecx + 2, cy)], fill=PUPIL)
            d.line([(ecx - 1, cy + 1), (ecx + 2, cy)], fill=PUPIL)
        else:
            d.rectangle([ecx - 1, cy - 3, ecx + 3, cy + 1], fill=EYE_W)
            d.rectangle([ecx + 1, cy - 2, ecx + 2, cy + 1], fill=PUPIL)
    if eyes == "angry":
        d.line([(cx - 7, cy - 5), (cx - 2, cy - 3)], fill=PUPIL)
        d.line([(cx + 2, cy - 3), (cx + 7, cy - 5)], fill=PUPIL)
    d.point([(cx - 8, cy + 3), (cx + 7, cy + 3)], fill=BLUSH)


def its_mouth(d, cx, cy, mouth):
    if mouth == "open":
        d.rectangle([cx - 3, cy + 4, cx + 2, cy + 7], fill=MOUTH)
        d.rectangle([cx - 3, cy + 4, cx + 2, cy + 4], fill=TEETH)
    elif mouth == "sly":
        d.line([(cx - 3, cy + 5), (cx, cy + 6)], fill=PUPIL)
        d.line([(cx, cy + 6), (cx + 3, cy + 4)], fill=PUPIL)
    else:
        d.line([(cx - 2, cy + 5), (cx + 2, cy + 5)], fill=PUPIL)


def its_microbe(kind, bob=0, legs=(0, 0), eyes="angry", mouth="line", lean=0, puff=0, ghost=False, sx=0, drip=0):
    w, h = 32, 40
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    hi, md, dk = ITS_COL[kind]
    cx, cy = 16 + lean, 24 + bob
    rx, ry = 11 + puff, 10 + puff
    # patitas
    for fx, off in ((-5, legs[0]), (5, legs[1])):
        d.ellipse([cx + fx - 3, h - 8 + off - 1, cx + fx + 3, h - 3 + off], fill=dk)
    if kind == "sifilis":
        # espiroqueta: cuerpo en tirabuzon vertical
        for i in range(5):
            yy = cy - 10 + i * 5 + (i % 2)
            dx = (-2, 2)[(i + sx) % 2]
            d.ellipse([cx - 11 + dx, yy - 3, cx + 11 + dx, yy + 4], fill=md if i % 2 == 0 else dk)
            d.ellipse([cx - 9 + dx, yy - 3, cx + 2 + dx, yy], fill=hi if i % 2 == 0 else md)
        # disfraz: gafas redondas y bigote falso (la gran imitadora)
        for ecx in (cx - 5, cx + 4):
            d.ellipse([ecx - 4, cy - 8, ecx + 4, cy], outline=MUST, fill=GLASS)
        d.line([(cx - 1, cy - 4), (cx, cy - 4)], fill=MUST)
        its_eyes(d, cx, cy - 4, "happy" if eyes == "angry" else eyes)
        d.rectangle([cx - 6, cy + 2, cx + 5, cy + 4], fill=MUST)
        d.point([(cx - 7, cy + 3), (cx + 6, cy + 3)], fill=MUST)
    else:
        d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=md)
        d.ellipse([cx - rx + 2, cy - ry + 1, cx - 1, cy - 1], fill=hi)
        d.ellipse([cx + 1, cy + 1, cx + rx - 2, cy + ry - 1], fill=dk)
        if kind == "clamidia":
            # sin sintomas: puntitos de "no pasa nada" y mirada de reojo
            for px_, py_ in ((-8, -6), (7, -7), (0, -10)):
                d.point([(cx + px_, cy + py_)], fill=hi)
        elif kind == "herpes":
            for bx, by, br in ((-6, -9, 3), (2, -11, 3), (8, -5, 2), (-9, -2, 2)):
                d.ellipse([cx + bx - br, cy + by - br, cx + bx + br, cy + by + br], fill=BLISTER, outline=dk)
                d.point([(cx + bx - 1, cy + by - 1)], fill=(255, 255, 255, 255))
        elif kind == "gonorrea":
            # gotitas colgando del cuerpo
            for gx, gl in ((-7, 3), (-1, 5), (6, 2)):
                gl += drip
                d.rectangle([cx + gx - 1, cy + ry - 1, cx + gx, cy + ry + gl - 2], fill=DROP)
                d.ellipse([cx + gx - 2, cy + ry + gl - 3, cx + gx + 1, cy + ry + gl], fill=DROP_HI)
        elif kind == "vph":
            # coliflor de verruguitas en la coronilla y los costados
            for bx, by, br in ((-5, -10, 3), (1, -12, 3), (6, -9, 3), (-10, -3, 2), (10, -2, 2), (-2, -8, 2)):
                d.ellipse([cx + bx - br, cy + by - br, cx + bx + br, cy + by + br], fill=WART, outline=dk)
                d.point([(cx + bx - 1, cy + by - 1)], fill=WART_HI)
        its_eyes(d, cx, cy - 1, eyes)
        its_mouth(d, cx, cy - 1, mouth)
    if ghost:
        # contorno punteado: apenas se ve (asintomatica)
        px = im.load()
        for y in range(h):
            for x in range(w):
                r, g, b, a = px[x, y]
                if a:
                    px[x, y] = (r, g, b, 200 if (x + y) % 3 == 0 else 120)
    return outline(im)


def verruguita(bob=0, eyes="angry", legs=(0, 0)):
    """Minion del VPH 16x18: una verruga con patitas."""
    im = Image.new("RGBA", (16, 18), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for fx, off in ((-3, legs[0]), (3, legs[1])):
        d.ellipse([8 + fx - 2, 14 + off, 8 + fx + 1, 16 + off], fill=ITS_COL["vph"][2])
    d.ellipse([2, 3 + bob, 13, 14 + bob], fill=WART, outline=ITS_COL["vph"][2])
    d.ellipse([3, 4 + bob, 8, 8 + bob], fill=WART_HI)
    for ex in (5, 9):
        if eyes == "x":
            d.point([(ex, 8 + bob), (ex + 1, 9 + bob)], fill=PUPIL)
        else:
            d.rectangle([ex, 7 + bob, ex + 1, 9 + bob], fill=EYE_W)
            d.point([(ex + 1, 8 + bob)], fill=PUPIL)
    d.line([(6, 11 + bob), (9, 11 + bob)], fill=PUPIL)
    return outline(im)


def residuo_herpes():
    """Ampolla seca que deja el herpes al caer (24x16): pisala para rematarlo."""
    im = Image.new("RGBA", (24, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    hi, md, dk = ITS_COL["herpes"]
    d.ellipse([2, 6, 21, 14], fill=dk)
    d.ellipse([5, 3, 18, 12], fill=md)
    d.ellipse([8, 4, 14, 8], fill=BLISTER)
    d.point([(9, 5)], fill=(255, 255, 255, 255))
    d.line([(7, 10), (11, 11)], fill=dk)
    return outline(im)


def frames_its(kind, legs_walk=True):
    eyes0 = "sleepy" if kind == "clamidia" else ("happy" if kind == "sifilis" else "angry")
    g = kind == "clamidia"
    mk = lambda **k: its_microbe(kind, ghost=False, **k)
    idle = mk(eyes=eyes0, mouth="sly" if kind in ("clamidia", "sifilis") else "line")
    walk = [mk(eyes=eyes0, legs=(2, 0), drip=0), mk(bob=-1, eyes=eyes0, drip=1, sx=1),
            mk(eyes=eyes0, legs=(0, 2), drip=0), mk(bob=-1, eyes=eyes0, drip=1, sx=1)]
    attack = [mk(eyes="angry", mouth="open", puff=0), mk(eyes="angry", mouth="open", puff=1, lean=-1),
              mk(eyes="angry", mouth="open", puff=1, lean=-2)]
    hurt = [tint(mk(eyes="hurt", mouth="open"), (255, 60, 70), 0.55), tint(mk(eyes="hurt"), (255, 255, 255), 0.4)]
    dead = mk(eyes="x")
    death = [death_frame(dead, i, center=(16, 36)) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


def frames_verruguita():
    idle = verruguita()
    walk = [verruguita(legs=(1, 0)), verruguita(bob=-1), verruguita(legs=(0, 1)), verruguita(bob=-1)]
    attack = [verruguita(eyes="angry", bob=1), verruguita(eyes="angry"), verruguita(eyes="angry", bob=-1)]
    hurt = [tint(verruguita(), (255, 60, 70), 0.55), tint(verruguita(), (255, 255, 255), 0.4)]
    death = [death_frame(verruguita(eyes="x"), i, center=(8, 16)) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}
# ------------------------------------------------------------- espinilla reventona
SK_HI = (255, 204, 190, 255)
SK_MD = (244, 160, 156, 255)
SK_DK = (200, 104, 122, 255)
RD_HI = (255, 130, 116, 255)
RD_MD = (234, 70, 82, 255)
RD_DK = (164, 36, 62, 255)
CREAM = (255, 246, 214, 255)
CREAM_DK = (236, 214, 150, 255)
DROP_C = (255, 226, 214, 255)


def _mix(a, b, k):
    return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3)) + (255,)


def espinilla(grow=0.0, red=0.0, eyes="sleepy", mouth="smile", sprout=1.0, flat=0.0, drops=0, sweat=False):
    """Espinilla Reventona 40x44: monticulo rosado con punta cremosa y carita, pegado al
    suelo. grow (0..1) la infla, red (0..1) la enrojece, sprout (0..1) cuanto ha brotado
    del suelo, flat (0..1) la aplasta (muerte). drops: gotitas de crema al reventar."""
    w, h = 40, 44
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, base = 20, 38
    hi, md, dk = _mix(SK_HI, RD_HI, red), _mix(SK_MD, RD_MD, red), _mix(SK_DK, RD_DK, red)
    rx = (9 + 6 * grow) * (1.0 + 0.5 * flat)
    ry = (12 + 7 * grow) * sprout * (1.0 - 0.75 * flat)
    # sombra de contacto / cráter
    d.ellipse([cx - rx - 3, base - 3, cx + rx + 3, base + 3], fill=(120, 70, 80, 255) if flat < 0.5 else (200, 150, 150, 255))
    if ry >= 2:
        top = base - 2 * ry
        d.ellipse([cx - rx, top, cx + rx, base + 2], fill=md)
        d.ellipse([cx - rx, base - ry, cx + rx, base + 2], fill=md)
        d.pieslice([cx - rx, base - ry * 1.2, cx + rx, base + 3], 0, 180, fill=dk)  # panza oscura
        if ry > 9:
            d.ellipse([cx - rx + 1, top + 2, cx + rx - 1, base - 2], fill=md)
            d.ellipse([cx - rx + 3, top + 3, cx - 2, top + ry * 0.9], fill=hi)     # brillo
        # punta cremosa
        hr = 4 + 3 * grow
        hx, hy = cx + 1, top + 2 + hr * 0.3
        if flat < 0.5:
            d.ellipse([hx - hr, hy - hr * 0.8, hx + hr, hy + hr * 0.9], fill=CREAM)
            d.ellipse([hx - hr * 0.5, hy - hr * 0.6, hx - 1, hy - 1], fill=(255, 255, 255, 255))
            d.arc([hx - hr, hy - hr * 0.8, hx + hr, hy + hr * 0.9], 20, 160, fill=CREAM_DK)
        # cara
        ey = base - ry * 1.05
        for ex in (cx - 4, cx + 4):
            if eyes == "x":
                d.line([(ex - 1, ey - 2), (ex + 1, ey)], fill=PUPIL)
                d.line([(ex - 1, ey), (ex + 1, ey - 2)], fill=PUPIL)
            elif eyes == "sleepy":
                d.line([(ex - 2, ey - 1), (ex + 1, ey - 1)], fill=PUPIL)
                d.point([(ex - 2, ey - 2), (ex + 1, ey - 2)], fill=PUPIL)
            elif eyes == "wide":
                d.rectangle([ex - 2, ey - 4, ex + 1, ey], fill=EYE_W)
                d.rectangle([ex - 1, ey - 3, ex, ey - 1], fill=PUPIL)
            elif eyes == "angry":
                d.rectangle([ex - 2, ey - 3, ex + 1, ey], fill=EYE_W)
                d.rectangle([ex - 1, ey - 2, ex, ey - 1], fill=PUPIL)
        if eyes in ("angry", "wide") and red > 0.2:
            d.line([(cx - 7, ey - 5), (cx - 2, ey - 3)], fill=PUPIL)
            d.line([(cx + 2, ey - 3), (cx + 7, ey - 5)], fill=PUPIL)
        d.point([(cx - 7, ey + 2), (cx + 6, ey + 2)], fill=BLUSH)
        my = ey + 4
        if mouth == "smile":
            d.line([(cx - 2, my), (cx + 1, my)], fill=PUPIL)
            d.point([(cx - 3, my - 1), (cx + 2, my - 1)], fill=PUPIL)
        elif mouth == "oh":
            d.rectangle([cx - 2, my - 1, cx + 1, my + 2], fill=MOUTH)
        elif mouth == "wavy":
            for i, xx in enumerate(range(cx - 4, cx + 4, 2)):
                d.line([(xx, my + (i % 2)), (xx + 1, my + (i % 2))], fill=PUPIL)
        elif mouth == "dead":
            d.line([(cx - 2, my), (cx + 1, my)], fill=PUPIL)
        if sweat:
            d.polygon([(cx + rx - 2, ey - 6), (cx + rx, ey - 2), (cx + rx - 4, ey - 2)], fill=(150, 214, 255, 255))
    # gotitas al reventar
    import math as _m
    for i in range(drops):
        a = -_m.pi * (0.15 + 0.7 * i / max(1, drops - 1))
        r = 12 + 5 * (i % 2)
        gx, gy = cx + _m.cos(a) * (r + 3 * drops / 3), base - 8 + _m.sin(a) * r
        d.ellipse([gx - 2, gy - 2, gx + 1, gy + 2], fill=DROP_C)
        d.point([(gx - 1, gy - 1)], fill=(255, 255, 255, 255))
    return outline(im)


def frames_espinilla():
    idle = [espinilla(0.0, 0.0, "sleepy", "smile"), espinilla(0.05, 0.05, "sleepy", "smile")]
    sprout = [espinilla(0.0, 0.0, "sleepy", "smile", sprout=0.15), espinilla(0.0, 0.0, "sleepy", "smile", sprout=0.5),
              espinilla(0.0, 0.0, "sleepy", "smile", sprout=0.85), espinilla(0.0, 0.0, "sleepy", "smile", sprout=1.0)]
    attack = [espinilla(0.25, 0.3, "wide", "oh"), espinilla(0.5, 0.6, "angry", "wavy", sweat=True),
              espinilla(0.8, 0.85, "angry", "wavy", sweat=True), espinilla(1.0, 1.0, "angry", "wavy", sweat=True)]
    burst = [espinilla(1.0, 0.7, "x", "oh", drops=5), espinilla(0.2, 0.3, "x", "oh", flat=0.4, drops=7),
             espinilla(0.0, 0.0, "x", "dead", flat=0.9)]
    hurt = [tint(espinilla(0.0, 0.0, "wide", "oh"), (255, 60, 70), 0.55), tint(espinilla(0.0, 0.0, "wide", "oh"), (255, 255, 255), 0.4)]
    death = [espinilla(0.0, 0.0, "x", "dead"), espinilla(0.0, 0.0, "x", "dead", flat=0.5),
             espinilla(0.0, 0.0, "x", "dead", flat=0.9), espinilla(0.0, 0.0, "x", "dead", flat=1.0)]
    for i, a in enumerate((255, 220, 150, 80)):
        px = death[i].load()
        for y in range(death[i].size[1]):
            for x in range(death[i].size[0]):
                r, g, b, al = px[x, y]
                px[x, y] = (r, g, b, int(al * a / 255))
    return {"idle": idle, "sprout": sprout, "attack": attack, "burst": burst, "hurt": hurt, "death": death}


def proyectil_gota():
    """Gotita de crema (16x16) del reventon de la Espinilla: crema/rosado, sin gore."""
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([4, 4, 11, 12], fill=(255, 232, 218, 255))
    d.polygon([(7, 2), (9, 2), (11, 6), (4, 6)], fill=(255, 232, 218, 255))
    d.ellipse([5, 8, 11, 12], fill=(255, 190, 200, 255))
    d.rectangle([5, 5, 6, 7], fill=(255, 255, 255, 255))
    im = outline(im)
    im.save(ROOT / "assets/sprites/projectiles/gota.png")
    print("ok gota")


# ------------------------------------------------- palacio de la censura + rehechos
# Pixel de Censura, Barra Negra y Sello Censor (palacio) y Clamidia / Calambre:
# personajes con carita, mismo tamano y animaciones que los anteriores.
SKIN = [(252, 226, 204, 255), (236, 188, 160, 255), (214, 150, 132, 255),
        (190, 118, 118, 255), (246, 206, 196, 255), (224, 168, 120, 255)]
GLITCH = [(150, 152, 168, 255), (206, 208, 220, 255), (96, 98, 116, 255)]
INK_BAR = (38, 34, 48, 255)
INK_BAR_HI = (96, 90, 116, 255)
INK_BAR_SH = (22, 20, 30, 255)
GLOVE = (244, 244, 250, 255)
HEAD_SK = (216, 208, 226, 255)
HEAD_SK_DK = (162, 152, 182, 255)
RED_HI = (255, 120, 110, 255)
RED_MD = (206, 52, 60, 255)
RED_DK = (140, 30, 44, 255)
WOOD_HI = (190, 134, 90, 255)
RUBBER = (46, 42, 56, 255)
PAPER = (255, 244, 232, 255)


def face(d, cx, cy, eyes="angry", mouth="line", gap=3):
    """Carita comun (ojos a cx-gap y cx+gap)."""
    for ex in (cx - gap - 1, cx + gap - 1):
        if eyes == "x":
            d.line([(ex - 1, cy - 1), (ex + 1, cy + 1)], fill=PUPIL)
            d.line([(ex - 1, cy + 1), (ex + 1, cy - 1)], fill=PUPIL)
        elif eyes == "hurt":
            d.line([(ex - 1, cy - 1), (ex + 1, cy)], fill=PUPIL)
            d.line([(ex - 1, cy + 1), (ex + 1, cy)], fill=PUPIL)
        else:
            d.rectangle([ex - 1, cy - 1, ex + 1, cy + 2], fill=EYE_W)
            d.rectangle([ex, cy, ex + 1, cy + 1], fill=PUPIL)
    if eyes == "angry":
        d.line([(cx - gap - 3, cy - 3), (cx - 1, cy - 2)], fill=PUPIL)
        d.line([(cx + 1, cy - 2), (cx + gap + 3, cy - 3)], fill=PUPIL)
    if mouth == "open":
        d.rectangle([cx - 2, cy + 4, cx + 1, cy + 6], fill=MOUTH)
        d.line([(cx - 2, cy + 4), (cx + 1, cy + 4)], fill=TEETH)
    elif mouth == "smirk":
        d.line([(cx - 2, cy + 5), (cx, cy + 5)], fill=PUPIL)
        d.line([(cx, cy + 5), (cx + 2, cy + 4)], fill=PUPIL)
    else:
        d.line([(cx - 2, cy + 5), (cx + 1, cy + 5)], fill=PUPIL)


# ---- pixel de censura: un mosaico de pixelado vivo, con ojos que asoman
def pixel_censura(bob=0, block=4, legs=(0, 0), eyes="angry", mouth="smirk", shimmer=0,
                  scatter=0.0, lean=0):
    im = Image.new("RGBA", (24, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    n = 16 // block
    x0, y0 = 4 + lean, 9 + bob
    if scatter < 0.2:
        # patitas y bracitos de bloque
        for lx, up in ((7, legs[0]), (14, legs[1])):
            d.rectangle([lx + lean, 25 + bob - up, lx + 2 + lean, 30 - up], fill=GLITCH[2])
            d.rectangle([lx - 1 + lean, 30 - up, lx + 3 + lean, 31 - up], fill=GLITCH[0])
        d.rectangle([x0 - 3, 16 + bob, x0 - 1, 18 + bob], fill=SKIN[2])
        d.rectangle([x0 + 16, 16 + bob, x0 + 18, 18 + bob], fill=SKIN[2])
    cxm = x0 + 8
    cym = y0 + 8
    for j in range(n):
        for i in range(n):
            h = (i * 7 + j * 13 + shimmer * 5 + (i * j) % 3) % 11
            if h in (3, 8) and shimmer % 2 == 1:
                col = GLITCH[(i + j) % 2]
            elif h == 5:
                col = GLITCH[2] if shimmer % 3 == 0 else GLITCH[0]
            else:
                col = SKIN[(i * 3 + j * 5 + h) % len(SKIN)]
            bx, by = x0 + i * block, y0 + j * block
            if scatter:
                vx, vy = bx + block / 2 - cxm, by + block / 2 - cym
                bx += int(vx * scatter * 1.1) + (i % 2) * int(scatter * 2)
                by += int(vy * scatter * 0.9 + scatter * 6 * ((i + j) % 3))
                size = max(1, int(block * (1.0 - scatter * 0.65)))
            else:
                size = block
            if (i * 5 + j * 3) % 4 == 0 and scatter > 0.55:
                continue
            d.rectangle([bx, by, bx + size - 1, by + size - 1], fill=col)
            if size >= 3:
                d.line([(bx, by + size - 1), (bx + size - 1, by + size - 1)], fill=_mix(col, (80, 40, 50, 255), 0.25))
    if scatter < 0.2:
        # ventana de cara: el mosaico se aparta para dejar ver los ojos
        d.rectangle([x0 + 3, y0 + 3, x0 + 12, y0 + 8], fill=(255, 238, 224, 255))
        face(d, x0 + 8, y0 + 4, eyes, mouth, gap=3)
    # pixeles sueltos flotando a los lados (el pixelado se les escapa)
    if scatter < 0.2:
        for k, (fx, fy) in enumerate(((x0 - 2, y0 - 2), (x0 + 17, y0 + 1), (x0 - 1, y0 + 17))):
            if (k + shimmer) % 3:
                d.rectangle([fx, fy + (shimmer % 2), fx + 1, fy + 1 + (shimmer % 2)], fill=SKIN[(k + shimmer) % 6])
    return outline(im)


def frames_pixel_censura():
    idle = pixel_censura(shimmer=0)
    walk = [pixel_censura(0, legs=(2, 0), shimmer=1), pixel_censura(-1, shimmer=2),
            pixel_censura(0, legs=(0, 2), shimmer=3), pixel_censura(-1, shimmer=4)]
    attack = [pixel_censura(0, block=4, eyes="angry", mouth="open", shimmer=1),
              pixel_censura(-1, block=8, eyes="angry", mouth="open", shimmer=2, lean=-1),
              pixel_censura(0, block=8, eyes="angry", mouth="open", shimmer=3, lean=-2)]
    hurt = [tint(pixel_censura(0, eyes="hurt", mouth="open", shimmer=2), (255, 60, 70), 0.55),
            tint(pixel_censura(0, eyes="hurt", shimmer=3), (255, 255, 255), 0.4)]
    death = [pixel_censura(1, eyes="x", mouth="open", shimmer=1),
             pixel_censura(2, eyes="x", scatter=0.45, shimmer=1),
             pixel_censura(3, eyes="x", scatter=0.8, shimmer=2),
             pixel_censura(4, eyes="x", scatter=1.2, shimmer=3)]
    for i in (2, 3):
        death[i] = tint(death[i], (60, 50, 70), 0.3 * (i - 1))
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


# ---- barra negra: censor con cabeza que carga una barra de censura como cuerpo
def barra_negra(bob=0, legs=(0, 0), lean=0, eyes="angry", mouth="line", swing=0, glare=0, thrust=0):
    im = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # patitas
    for lx, up in ((9, legs[0]), (19, legs[1])):
        d.rectangle([lx, 34 + bob - up, lx + 2, 43 - up], fill=HEAD_SK_DK)
        d.rectangle([lx - 1, 43 - up, lx + 4, 45 - up], fill=INK_BAR)
    # barra (se dibuja aparte para poder inclinarla al atacar)
    bar = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bar)
    bx0, bx1 = 2 + lean, 29 + lean + thrust
    by0, by1 = 20 + bob, 34 + bob
    bd.rounded_rectangle([bx0, by0, bx1, by1], radius=2, fill=INK_BAR)
    bd.line([(bx0 + 2, by0 + 1), (bx1 - 2, by0 + 1)], fill=INK_BAR_HI)
    bd.line([(bx0 + 1, by1 - 1), (bx1 - 1, by1 - 1)], fill=INK_BAR_SH)
    # remaches y brillo "tachado": la barra de censura de toda la vida
    for rx in (bx0 + 3, bx1 - 4):
        bd.rectangle([rx, by0 + 4, rx + 1, by0 + 5], fill=INK_BAR_HI)
        bd.rectangle([rx, by1 - 5, rx + 1, by1 - 4], fill=INK_BAR_HI)
    gx = bx0 + 6 + glare * 6
    bd.line([(gx, by0 + 3), (gx + 3, by0 + 3)], fill=(150, 144, 170, 255))
    bd.line([(gx - 2, by0 + 6), (gx + 1, by0 + 6)], fill=(120, 114, 140, 255))
    # el mensaje de la barra: carita de "NO" (dos ojillos rojos asomando)
    cy = by0 + 8
    if eyes == "x":
        for ex in (bx0 + 8, bx1 - 11):
            bd.line([(ex, cy - 2), (ex + 2, cy)], fill=RED_HI)
            bd.line([(ex, cy), (ex + 2, cy - 2)], fill=RED_HI)
    else:
        for ex in (bx0 + 8, bx1 - 11):
            bd.rectangle([ex, cy - 1, ex + 2, cy + 1], fill=RED_MD if eyes != "hurt" else RED_HI)
    if swing:
        bar = bar.rotate(swing, resample=Image.NEAREST, center=(16 + lean, 27 + bob))
    im.alpha_composite(bar)
    d = ImageDraw.Draw(im)
    # manos con guante que sujetan la barra por los costados
    hy = 27 + bob - (4 if swing else 0)
    for hx in (bx0 - 1, bx1 + 1):
        d.ellipse([hx - 2, hy - 2, hx + 2, hy + 2], fill=GLOVE)
    # cabeza encima: redonda, con cara de funcionario ofendido
    hx0, hy0 = 16 + lean + thrust // 2, 12 + bob - (2 if swing else 0)
    d.ellipse([hx0 - 8, hy0 - 8, hx0 + 8, hy0 + 7], fill=HEAD_SK)
    d.ellipse([hx0 + 1, hy0 + 1, hx0 + 7, hy0 + 6], fill=HEAD_SK_DK)
    d.ellipse([hx0 - 6, hy0 - 6, hx0 - 1, hy0 - 2], fill=(238, 232, 244, 255))
    # bonete negro de censor
    d.rectangle([hx0 - 7, hy0 - 9, hx0 + 7, hy0 - 6], fill=INK_BAR)
    d.rectangle([hx0 - 4, hy0 - 12, hx0 + 4, hy0 - 9], fill=INK_BAR)
    d.line([(hx0 - 3, hy0 - 11), (hx0 + 2, hy0 - 11)], fill=INK_BAR_HI)
    face(d, hx0, hy0 - 3, eyes, mouth, gap=3)
    return outline(im)


def frames_barra_negra():
    idle = barra_negra()
    walk = [barra_negra(0, (2, 0), glare=0), barra_negra(-1, glare=1),
            barra_negra(0, (0, 2), glare=2), barra_negra(-1, glare=1)]
    attack = [barra_negra(0, mouth="open", swing=-8, lean=1),
              barra_negra(-1, mouth="open", swing=12, lean=-1),
              barra_negra(0, mouth="open", lean=-1, thrust=2, glare=2)]
    hurt = [tint(barra_negra(0, eyes="hurt", mouth="open"), (255, 60, 70), 0.55),
            tint(barra_negra(0, eyes="hurt"), (255, 255, 255), 0.4)]
    dead = barra_negra(0, eyes="x", mouth="open")
    death = [death_frame(dead, i, center=(16, 44)) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


# ---- sello censor: sello de goma con cara que estampa CENSURADO
def sello(bob=0, legs=(0, 0), lean=0, eyes="angry", mouth="line", lift=0, squash=0, ink=0):
    im = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    base_y = 35 + bob + squash  # parte alta de la base de goma
    # patitas bajo la base
    for lx, up in ((9, legs[0]), (19, legs[1])):
        d.rectangle([lx, 40 - up, lx + 2, 44 - up], fill=HEAD_SK_DK)
        d.rectangle([lx - 1, 44 - up, lx + 4, 45 - up], fill=INK_BAR)
    if ink:  # charco de tinta de la estampada
        d.ellipse([16 - 8 - ink * 2, 42, 16 + 8 + ink * 2, 46], fill=RED_MD)
        for sx_ in (-12, 11):
            d.rectangle([16 + sx_ - ink, 41, 16 + sx_ + ink, 42], fill=RED_HI)
    top = 6 + bob - lift + (squash // 2)
    # mango de madera (perilla + cuello)
    d.rectangle([14 + lean, top + 5, 18 + lean, top + 11], fill=(120, 76, 50, 255))
    d.ellipse([10 + lean, top, 22 + lean, top + 8], fill=(150, 98, 62, 255))
    d.ellipse([11 + lean, top + 1, 16 + lean, top + 4], fill=WOOD_HI)
    # cuerpo rojo (la tapa del sello) con cara
    bx0, bx1 = 6 + lean, 25 + lean
    d.rounded_rectangle([bx0, top + 11, bx1, base_y - 1], radius=3, fill=RED_MD)
    d.line([(bx0 + 2, top + 12), (bx1 - 2, top + 12)], fill=RED_HI)
    d.rectangle([bx1 - 3, top + 14, bx1 - 1, base_y - 3], fill=RED_DK)
    # etiqueta de papel con "texto" ilegible de CENSURADO
    ly = base_y - 6
    d.rectangle([bx0 + 3, ly, bx1 - 3, ly + 3], fill=PAPER)
    for tx in range(bx0 + 5, bx1 - 4, 3):
        d.line([(tx, ly + 1), (tx + 1, ly + 1)], fill=INK_BAR)
    face(d, 16 + lean, top + 16, eyes, mouth, gap=4)
    # base de goma negra con borde de tinta
    d.rounded_rectangle([bx0 - 2, base_y, bx1 + 2, base_y + 4], radius=1, fill=RUBBER)
    d.line([(bx0 - 1, base_y + 4), (bx1 + 1, base_y + 4)], fill=RED_MD)
    d.line([(bx0, base_y + 1), (bx1, base_y + 1)], fill=(96, 90, 116, 255))
    return outline(im)


def frames_sello():
    idle = sello()
    walk = [sello(0, (2, 0)), sello(-1), sello(0, (0, 2)), sello(-1)]
    attack = [sello(0, lift=5, mouth="open", lean=0, legs=(1, 1)),
              sello(0, lift=8, mouth="open", legs=(1, 1)),
              sello(0, squash=3, mouth="open", ink=3, legs=(-1, -1), lean=-1)]
    hurt = [tint(sello(0, eyes="hurt", mouth="open"), (255, 255, 90), 0.5),
            tint(sello(0, eyes="hurt"), (255, 255, 255), 0.4)]
    dead = sello(0, eyes="x", mouth="open")
    death = [death_frame(dead, i, center=(16, 44)) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


# ---- clamidia: bacteria de cilios, ojos entornados y sonrisita de "yo no fui"
def clamidia(bob=0, legs=(0, 0), eyes="sleepy", mouth="sly", lean=0, puff=0, cil=0):
    hi, md, dk = ITS_COL["clamidia"]
    w, h = 32, 40
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = 16 + lean, 22 + bob
    rx, ry = 9 + puff, 8 + puff
    for fx, off in ((-4, legs[0]), (4, legs[1])):
        d.rectangle([cx + fx - 2, 31 + off + bob, cx + fx + 1, 35 + off], fill=dk)
        d.ellipse([cx + fx - 3, 34 + off, cx + fx + 2, 36 + off], fill=dk)
    # cilios radiales con perlita en la punta
    for k in range(14):
        a = k * (2 * math.pi / 14)
        ln = 4 + (cil + k) % 2 + puff
        x1, y1 = cx + math.cos(a) * (rx - 1), cy + math.sin(a) * (ry - 1)
        x2, y2 = cx + math.cos(a) * (rx + ln), cy + math.sin(a) * (ry + ln)
        d.line([(x1, y1), (x2, y2)], fill=dk)
        d.rectangle([round(x2) - 1, round(y2) - 1, round(x2), round(y2)], fill=hi)
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=md)
    d.ellipse([cx - rx + 2, cy - ry + 1, cx - 1, cy - 1], fill=hi)
    d.ellipse([cx + 1, cy + 2, cx + rx - 1, cy + ry - 1], fill=dk)
    # cuerpo de inclusion: la mancha oscura que delata a la clamidia
    d.ellipse([cx + 3, cy + 1, cx + 8, cy + 5], fill=(92, 72, 150, 255))
    d.point([(cx + 4, cy + 2)], fill=hi)
    its_eyes(d, cx, cy - 2, eyes)
    its_mouth(d, cx, cy - 2, mouth)
    return outline(im)


def frames_clamidia():
    idle = clamidia()
    walk = [clamidia(0, (2, 0), cil=0), clamidia(-1, cil=1), clamidia(0, (0, 2), cil=0), clamidia(-1, cil=1)]
    attack = [clamidia(0, eyes="angry", mouth="open", puff=0, cil=1), clamidia(0, eyes="angry", mouth="open", puff=1, lean=-1),
              clamidia(0, eyes="angry", mouth="open", puff=2, lean=-2, cil=1)]
    hurt = [tint(clamidia(0, eyes="hurt", mouth="open"), (255, 60, 70), 0.55),
            tint(clamidia(0, eyes="hurt"), (255, 255, 255), 0.4)]
    dead = clamidia(0, eyes="x")
    death = [death_frame(dead, i, center=(16, 36)) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


# ---- calambre: musculo anudado que se contrae, con chispas
CR_HI = (255, 150, 206, 255)
CR_MD = (214, 58, 150, 255)
CR_DK = (140, 28, 100, 255)
CR_FIB = (172, 38, 120, 255)


def calambre(bob=0, legs=(0, 0), eyes="angry", mouth="grit", squeeze=0, spark=0, lean=0):
    im = Image.new("RGBA", (24, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = 12 + lean
    for fx, off in ((-4, legs[0]), (3, legs[1])):
        d.rectangle([cx + fx, 29 + bob - off, cx + fx + 2, 32 - off], fill=CR_DK)
        d.rectangle([cx + fx - 1, 32 - off, cx + fx + 3, 33 - off], fill=(60, 20, 50, 255))
    # dos vientres musculares con la cintura anudada entre ambos
    pinch = 2 + max(squeeze, 0)
    top = [cx - 8, 2 + bob, cx + 8, 14 + bob]
    bot = [cx - 7, 18 + bob, cx + 7, 30 + bob]
    d.ellipse(top, fill=CR_MD)
    d.ellipse(bot, fill=CR_MD)
    d.rectangle([cx - pinch, 12 + bob, cx + pinch, 19 + bob], fill=CR_MD)
    d.ellipse([cx - 6, 3 + bob, cx - 1, 8 + bob], fill=CR_HI)
    d.ellipse([cx - 5, 18 + bob, cx - 1, 22 + bob], fill=CR_HI)
    # fibras tensas y venita marcada
    for fx in (-5, 4):
        d.line([(cx + fx, 21 + bob), (cx + fx - 1, 27 + bob)], fill=CR_FIB)
    d.line([(cx + 5, 6 + bob), (cx + 6, 10 + bob)], fill=CR_FIB)
    # nudo: banda oscura cruzando la cintura
    d.line([(cx - pinch - 1, 15 + bob), (cx + pinch + 1, 18 + bob)], fill=CR_DK)
    d.line([(cx - pinch - 1, 18 + bob), (cx + pinch + 1, 15 + bob)], fill=CR_DK)
    # cara en el vientre de arriba
    face(d, cx, 6 + bob, eyes, "line" if mouth != "grit" else "open", gap=3)
    if mouth == "grit":
        d.rectangle([cx - 2, 10 + bob, cx + 1, 11 + bob], fill=TEETH)
        d.point([(cx - 1, 10 + bob), (cx + 1, 10 + bob)], fill=MOUTH)
    # chispas en zigzag de los espasmos
    if spark:
        spark_zig(d, cx + 8, 4 + bob, cx + 11, 12 + bob, BOLT, seed=spark)
        spark_zig(d, cx - 8, 14 + bob, cx - 11, 22 + bob, BOLT, seed=spark + 1)
        d.point([(cx + 11, 3 + bob), (cx - 11, 13 + bob)], fill=BOLT_HI)
    return outline(im)


def frames_calambre():
    idle = calambre(spark=0)
    walk = [calambre(0, (2, 0), spark=1), calambre(-1, squeeze=1), calambre(0, (0, 2), spark=2), calambre(-1, squeeze=1)]
    attack = [calambre(0, squeeze=-1, spark=1), calambre(-1, squeeze=2, spark=2, lean=-1),
              calambre(0, squeeze=2, spark=3, lean=-1)]
    hurt = [tint(calambre(0, eyes="hurt"), (255, 255, 255), 0.55), tint(calambre(0, eyes="hurt", spark=2), (255, 255, 120), 0.4)]
    dead = calambre(0, eyes="x", mouth="open")
    death = [death_frame(dead, i, center=(12, 32)) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


VARIANTS = {"especulo": frames_especulo, "dildo_electrico": frames_dildo_electrico,
            "hemorroide": frames_hemorroide, "inspector_fluidos": frames_inspector, "pelusa_perineal": frames_pelusa,
            "clamidia": frames_clamidia, "herpes": lambda: frames_its("herpes"),
            "gonorrea": lambda: frames_its("gonorrea"), "vph": lambda: frames_its("vph"),
            "sifilis": lambda: frames_its("sifilis"), "verruguita": frames_verruguita,
            "espinilla": frames_espinilla, "pixel_censura": frames_pixel_censura,
            "barra_negra": frames_barra_negra, "sello": frames_sello, "calambre": frames_calambre}
ANIM = {  # nombre: (loop, fps)
    "idle": (True, 4.0), "walk": (True, 8.0), "attack": (False, 10.0),
    "bite": (False, 18.0), "sprout": (False, 8.0), "burst": (False, 14.0), "hurt": (False, 10.0), "death": (False, 6.0),
}


def write_frames_tres(variant, anims):
    ext, blocks, n = [], [], 0
    for name, frames in anims.items():
        refs = []
        for i, _ in enumerate(frames):
            n += 1
            rid = f"{n}_{name}{i}"
            ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/enemies/{variant}_{name}_{i:02d}.png" id="{rid}"]')
            refs.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        loop, fps = ANIM[name]
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(refs), str(loop).lower(), name, fps))
    txt = '[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(ext) + "\n\n[resource]\nanimations = [" + ", ".join(blocks) + "]\n"
    (OUT / f"{variant}_sprite_frames.tres").write_text(txt)


def proyectil_sello():
    """Sello de goma rojo de RECHAZADO (16x16) para el proyectil del Inspector."""
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([2, 4, 13, 12], radius=2, fill=STAMP_R)
    d.rectangle([3, 5, 12, 5], fill=STAMP_R_HI)
    d.rectangle([4, 7, 11, 7], fill=(255, 230, 230, 255))   # "texto" del sello
    d.rectangle([4, 9, 9, 9], fill=(255, 230, 230, 255))
    d.line([(3, 3), (12, 13)], fill=(120, 20, 30, 255))     # tachon
    im = outline(im)
    im.save(ROOT / "assets/sprites/projectiles/sello.png")
    print("ok sello")


if __name__ == "__main__":
    if sys.argv[1:] == ["residuo"]:
        residuo_herpes().save(OUT / "herpes_residuo.png")
        print("ok residuo")
        sys.exit(0)
    if sys.argv[1:] == ["sello"]:
        proyectil_sello()
        sys.exit(0)
    if sys.argv[1:] == ["gota"]:
        proyectil_gota()
        sys.exit(0)
    for v in sys.argv[1:] or VARIANTS:
        anims = VARIANTS[v]()
        for name, frames in anims.items():
            for i, im in enumerate(frames):
                im.save(OUT / f"{v}_{name}_{i:02d}.png")
        write_frames_tres(v, anims)
        print("ok", v, sum(len(f) for f in anims.values()), "frames")
