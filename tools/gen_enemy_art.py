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
    src = im.load()
    out = im.copy()
    dst = out.load()
    for y in range(H):
        for x in range(W):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and src[nx, ny][3] and src[nx, ny] != OUTLINE:
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
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            if a:
                po[x, y] = (int(r + (rgb[0] - r) * k), int(g + (rgb[1] - g) * k), int(b + (rgb[2] - b) * k), a)
    return out


def death_frame(base, i):
    """Se desarma: se ladea, se hunde y se apaga (4 frames)."""
    f = [(0.0, 0, 1.0, 0.0), (-25, 4, 0.85, 0.25), (-60, 10, 0.6, 0.45), (-90, 16, 0.35, 0.6)][i]
    ang, sink, alpha, dark = f
    im = tint(base, (40, 30, 50), dark).rotate(ang, resample=Image.NEAREST, center=(14, 44))
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(im, (0, sink if sink < 4 else 2))
    px = out.load()
    for y in range(H):
        for x in range(W):
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
    """Capsula azul electrico con carita, dos puntas de electrodo arriba y un rayo
    amarillo en la panza. charge 0..2 = cuanta chispa le sale (aviso del disparo)."""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    y0 = bob
    # patitas
    for lx, up in ((10 + lean, legs[0]), (17 + lean, legs[1])):
        d.rectangle([lx, 41 + y0 - up, lx + 3, 45 - up], fill=B_DK)
        d.rectangle([lx - 1, 45 - up, lx + 4, 46 - up], fill=B_SH)
    bx0, by0, bx1, by1 = 8 + lean, 15 + y0, 23 + lean, 42 + y0
    # cuerpo: capsula vertical con brillo a la izquierda y sombra a la derecha
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=7, fill=B_MD)
    d.rounded_rectangle([bx0 + 1, by0 + 2, bx0 + 4, by1 - 4], radius=2, fill=B_HI)
    d.rectangle([bx1 - 3, by0 + 5, bx1 - 1, by1 - 4], fill=B_DK)
    d.line([(bx0 + 3, by1 - 1), (bx1 - 3, by1 - 1)], fill=B_SH)
    # aro metalico bajo la cabeza
    d.rectangle([bx0 + 1, by0 + 11, bx1 - 1, by0 + 12], fill=B_DK)
    # rayo amarillo en la panza
    cx, cy = bx0 + 7, by0 + 14
    d.polygon([(cx + 2, cy), (cx - 3, cy + 5), (cx, cy + 5), (cx - 2, cy + 10), (cx + 4, cy + 3), (cx + 1, cy + 3)], fill=BOLT)
    d.line([(cx + 2, cy + 1), (cx - 2, cy + 5)], fill=BOLT_HI)
    # electrodo: dos puntas metalicas arriba y chispa entre ellas
    ex = bx0 + 7
    d.rectangle([ex - 2, by0 - 4, ex - 1, by0 + 1], fill=M_LO)
    d.rectangle([ex + 1, by0 - 4, ex + 2, by0 + 1], fill=M_LO)
    d.point([(ex - 2, by0 - 4), (ex + 1, by0 - 4)], fill=M_HI)
    d.rectangle([ex - 3, by0 + 1, ex + 3, by0 + 1], fill=M_DK)
    if charge >= 1:
        spark_zig(d, ex - 1, by0 - 5, ex + 1, by0 - 5, SPARK, seed)
        d.point([(ex, by0 - 6), (ex, by0 - 7)], fill=BOLT_HI)
    if charge >= 2:
        spark_zig(d, ex - 2, by0 - 4, ex - 9, by0 - 9, BOLT, seed + 1)
        spark_zig(d, ex + 2, by0 - 4, ex + 9, by0 - 8, BOLT, seed + 2)
        d.point([(ex - 10, by0 - 5), (ex + 10, by0 - 3)], fill=SPARK)
    # cara
    fx, fy = bx0 + 3, by0 + 4
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
        d.line([(fx + 1, fy + 5), (fx + 5, fy + 5)], fill=PUPIL)  # boquita
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


VARIANTS = {"especulo": frames_especulo, "dildo_electrico": frames_dildo_electrico}
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


if __name__ == "__main__":
    for v in sys.argv[1:] or VARIANTS:
        anims = VARIANTS[v]()
        for name, frames in anims.items():
            for i, im in enumerate(frames):
                im.save(OUT / f"{v}_{name}_{i:02d}.png")
        write_frames_tres(v, anims)
        print("ok", v, sum(len(f) for f in anims.values()), "frames")
