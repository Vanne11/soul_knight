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


VARIANTS = {"especulo": frames_especulo, "dildo_electrico": frames_dildo_electrico,
            "hemorroide": frames_hemorroide, "inspector_fluidos": frames_inspector, "pelusa_perineal": frames_pelusa}
ANIM = {  # nombre: (loop, fps)
    "idle": (True, 4.0), "walk": (True, 8.0), "attack": (False, 10.0),
    "bite": (False, 18.0), "hurt": (False, 10.0), "death": (False, 6.0),
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
    if sys.argv[1:] == ["sello"]:
        proyectil_sello()
        sys.exit(0)
    for v in sys.argv[1:] or VARIANTS:
        anims = VARIANTS[v]()
        for name, frames in anims.items():
            for i, im in enumerate(frames):
                im.save(OUT / f"{v}_{name}_{i:02d}.png")
        write_frames_tres(v, anims)
        print("ok", v, sum(len(f) for f in anims.values()), "frames")
