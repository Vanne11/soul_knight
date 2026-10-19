"""LA PARRA ENTERA (2a forma de la Hoja de Parra): arte PROVISORIO con Pillow.

Genera assets/sprites/enemies/parra_<anim>_NN.png (128x168, pies en el borde inferior) y
parra_sprite_frames.tres. Es un placeholder prolijo (tronco retorcido, copa de hojas con la cara
de la Hoja, racimos de uva, raices) para la tanda de arte con Gemini, que lo reemplaza.
Uso: python3 tools/gen_parra_art.py
"""
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "enemies"
W, H = 128, 168

OUTLINE = (24, 22, 30, 255)
BARK = (112, 78, 52, 255)
BARK_L = (150, 108, 70, 255)
LEAF_D = (42, 122, 52, 255)
LEAF = (74, 172, 70, 255)
LEAF_L = (140, 214, 96, 255)
VEIN = (30, 96, 46, 255)
GRAPE = (116, 64, 150, 255)
GRAPE_L = (176, 120, 206, 255)
GOLD = (242, 204, 60, 255)
LIP = (210, 54, 74, 255)
WILT = (150, 132, 70, 255)


def leaf(d, cx, cy, ang, ln, wd, col, light):
    """Hoja de parra: lobulos alrededor de un punto, apuntando a `ang` (rad)."""
    # contorno: un ovalo con 3 picos
    pts = []
    steps = 30
    for i in range(steps):
        a = math.tau * i / steps
        r = 1.0 + 0.28 * math.cos(a * 3.0)
        x = math.cos(a) * ln * r * 0.5
        y = math.sin(a) * wd * r * 0.5
        ca, sa = math.cos(ang), math.sin(ang)
        pts.append((cx + x * ca - y * sa + math.cos(ang) * ln * 0.45, cy + x * sa + y * ca + math.sin(ang) * ln * 0.45))
    d.polygon(pts, fill=col)
    inner = [(cx + (px - cx) * 0.62 + math.cos(ang) * ln * 0.12, cy + (py - cy) * 0.62 + math.sin(ang) * ln * 0.12) for px, py in pts]
    d.polygon(inner, fill=light)
    ex, ey = cx + math.cos(ang) * ln * 0.9, cy + math.sin(ang) * ln * 0.9
    d.line([(cx, cy), (ex, ey)], fill=VEIN, width=1)


def grapes(d, cx, cy, n=7, r=4):
    for i in range(n):
        row = int((math.sqrt(8 * i + 1) - 1) / 2)
        col = i - row * (row + 1) // 2
        x = cx + (col - row / 2.0) * (r * 2 - 1)
        y = cy + row * (r * 2 - 2)
        d.ellipse([x - r, y - r, x + r, y + r], fill=GRAPE)
        d.ellipse([x - r + 1, y - r + 1, x - 1, y - 1], fill=GRAPE_L)


def frame(sway=0.0, flare=0.0, mouth=0.0, wilt=0.0, hurt=False, droop=0.0):
    """sway: balanceo (px); flare: abre las hojas (0-1); mouth: boca abierta (0-1); wilt: marchita (0-1)."""
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    bark = tuple(int(c + (w - c) * wilt) for c, w in zip(BARK, WILT))
    cx = W // 2
    # raices que se abren por el suelo
    for k, a in enumerate([-0.9, -0.5, 0.5, 0.9, -0.2, 0.2]):
        x0, y0 = cx + a * 8, H - 24
        x1, y1 = cx + a * 54, H - 4 - (k % 2) * 3
        d.line([(x0, y0), ((x0 + x1) / 2 + a * 6, H - 6), (x1, y1)], fill=bark, width=7 - (k % 3))
    # tronco retorcido (dos cuerdas trenzadas)
    base_y, top_y = H - 20, 74 + int(droop * 14)
    for strand, ph in enumerate([0.0, math.pi]):
        pts = []
        for i in range(24):
            t = i / 23.0
            y = base_y + (top_y - base_y) * t
            x = cx + math.sin(t * 7.0 + ph) * (9 - 3 * t) + sway * t
            pts.append((x, y))
        d.line(pts, fill=bark, width=14, joint="curve")
        d.line([(x - 3, y) for x, y in pts], fill=BARK_L if wilt < 0.5 else WILT, width=3)
    # copa: hojas grandes en abanico, atras las oscuras
    top = (cx + sway, top_y + 6)
    n = 9
    for i in range(n):
        a = math.pi * (1.08 + 0.84 * i / (n - 1))  # de izquierda a derecha, hacia arriba
        a += (flare * 0.35) * (i - (n - 1) / 2.0) / (n / 2.0) + droop * 0.6 * math.cos(a)
        ln = 54 - 5 * abs(i - (n - 1) / 2.0) + flare * 8
        col, light = (LEAF_D, LEAF) if i % 2 == 0 else (LEAF, LEAF_L)
        if wilt > 0:
            col = tuple(int(c + (w - c) * wilt) for c, w in zip(col, WILT))[:3] + (255,)
            light = tuple(int(c + (w - c) * wilt) for c, w in zip(light, WILT))[:3] + (255,)
        leaf(d, top[0], top[1], a, ln, 36, col, light)
    # racimos de uva colgando
    for gx, gy in [(cx - 34 + sway, top_y + 20), (cx + 34 + sway, top_y + 22), (cx + sway, top_y + 34)]:
        grapes(d, gx, gy + droop * 10, 6, 4)
    # hoja-cara central (la Hoja de siempre, mas grande)
    fx, fy = cx + sway, top_y - 14
    face = [(fx + math.cos(a) * 24 * (1 + 0.1 * math.cos(a * 3)), fy + math.sin(a) * 28 * (1 + 0.1 * math.cos(a * 3))) for a in [math.tau * i / 30 for i in range(30)]]
    d.polygon(face, fill=LEAF_L if wilt < 0.5 else WILT)
    d.polygon([(fx + (x - fx) * 0.8, fy + (y - fy) * 0.8) for x, y in face], fill=LEAF)
    # lentes redondos dorados y ojos
    for ex in (-9, 9):
        d.ellipse([fx + ex - 6, fy - 12, fx + ex + 6, fy], outline=GOLD, width=2, fill=(250, 250, 240, 255))
        d.ellipse([fx + ex - 2, fy - 8, fx + ex + 2, fy - 3], fill=OUTLINE)
    d.line([(fx - 3, fy - 6), (fx + 3, fy - 6)], fill=GOLD, width=1)
    # cejas severas
    d.line([(fx - 15, fy - 17 + (2 if hurt else 0)), (fx - 4, fy - 14)], fill=OUTLINE, width=2)
    d.line([(fx + 15, fy - 17 + (2 if hurt else 0)), (fx + 4, fy - 14)], fill=OUTLINE, width=2)
    # boca (cerrada = linea; abierta = ovalo rojo)
    my = fy + 9
    if mouth > 0.1:
        h = int(3 + 7 * mouth)
        d.ellipse([fx - 7, my - h // 2, fx + 7, my + h // 2 + 2], fill=LIP, outline=OUTLINE)
    else:
        d.line([(fx - 6, my), (fx + 6, my)], fill=LIP, width=2)
    # contorno oscuro de toda la silueta (estilo pixel art)
    alpha = im.getchannel("A")
    grown = alpha.filter(ImageFilter.MaxFilter(3))
    edge = Image.new("RGBA", (W, H), OUTLINE)
    edge.putalpha(ImageChops.subtract(grown, alpha))
    out = Image.alpha_composite(edge, im)
    if hurt:
        r, g, b, a = out.split()
        out = Image.merge("RGBA", (r.point(lambda v: min(255, v + 90)), g.point(lambda v: v), b.point(lambda v: v), a))
    return out


def main():
    anims = {
        "idle": [frame(sway=-1.5), frame(sway=1.5)],
        "attack": [frame(flare=0.3, mouth=0.4, sway=-2), frame(flare=0.8, mouth=1.0), frame(flare=1.0, mouth=0.6, sway=2)],
        "hurt": [frame(hurt=True, mouth=0.8, sway=-3), frame(hurt=True, mouth=0.5, sway=3)],
        "death": [frame(wilt=0.25, droop=0.2), frame(wilt=0.55, droop=0.5), frame(wilt=0.8, droop=0.8), frame(wilt=1.0, droop=1.0)],
    }
    OUT.mkdir(parents=True, exist_ok=True)
    res, entries = [], []
    n = 1
    for name, frs in anims.items():
        for i, im in enumerate(frs):
            f = "parra_%s_%02d.png" % (name, i)
            im.save(OUT / f)
            res.append('[ext_resource type="Texture2D" path="res://assets/sprites/enemies/%s" id="%d_%s"]' % (f, n, name))
            entries.append((name, i, "%d_%s" % (n, name)))
            n += 1
    speeds = {"idle": (3.0, True), "attack": (10.0, False), "hurt": (10.0, False), "death": (5.0, False)}
    anim_txt = []
    for name in ["idle", "attack", "hurt", "death"]:
        frames = ", ".join('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % e[2] for e in entries if e[0] == name)
        sp, loop = speeds[name]
        anim_txt.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (frames, "true" if loop else "false", name, sp))
    # el jefe pide "walk": la Parra esta enraizada, pero la base lo usa si se mueve
    walk = ", ".join('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % e[2] for e in entries if e[0] == "idle")
    anim_txt.append('{\n"frames": [%s],\n"loop": true,\n"name": &"walk",\n"speed": 3.0\n}' % walk)
    tres = '[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(res) + "\n\n[resource]\nanimations = [" + ", ".join(anim_txt) + "]\n"
    (OUT / "parra_sprite_frames.tres").write_text(tres)
    print("ok:", n - 1, "cuadros")


if __name__ == "__main__":
    main()
