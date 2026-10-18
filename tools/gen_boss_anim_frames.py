"""Cuadros intermedios de Dona Cera por script (PIL) a partir de las poses clave de Gemini.

Lo llama `python3 tools/gen_boss_anim_art.py build`. Cada animacion sale de una pose clave con
transformaciones de pixel art (estirar/aplastar, inclinar, saltito) mas capas dibujadas a mano:
goteo del borde, vapor, sudor, destellos, lineas de velocidad. Tres juegos de cuadros segun el dano
(sano, grietas, destrozada), cada uno en una hoja PNG + SpriteFrames con AtlasTexture:
  boss_cera_sprite_frames.tres  (fase 1)   boss_cera_sprite_frames_p2.tres   boss_cera_sprite_frames_p3.tres
El animador (src/enemies/boss_animator.gd) cambia de juego al cambiar de fase.
"""
import math

from PIL import Image, ImageDraw

import gen_boss_anim_art as G

CW, CH, OUT, ROOT = G.CW, G.CH, G.OUT, G.ROOT

GOLD = (255, 201, 60, 255)
GOLD_HI = (255, 232, 140, 255)
CRACK = (96, 20, 64, 255)
SWEAT = (140, 220, 255, 255)
SPARK = (255, 240, 150, 255)


def is_gold(p):
    return p[3] > 0 and p[0] > 200 and p[1] > 130 and p[2] < 140 and p[0] - p[2] > 90


def is_pink(p):
    return p[3] > 0 and p[0] > 200 and p[1] < 130 and p[2] > 90


def xf(im, sx=1.0, sy=1.0, rot=0.0, dx=0.0, dy=0.0, shear=0.0):
    """Transformacion anclada en los pies (centro-abajo), vecino mas cercano: pixel art nitido."""
    ax, ay = CW / 2.0, CH - 1.0
    c, sn = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    a11, a12, a22 = sx, shear * sy, sy
    m11, m12 = c * a11, c * a12 - sn * a22
    m21, m22 = sn * a11, sn * a12 + c * a22
    det = m11 * m22 - m12 * m21
    i11, i12, i21, i22 = m22 / det, -m12 / det, -m21 / det, m11 / det
    tx = ax - (i11 * (ax + dx) + i12 * (ay + dy))
    ty = ay - (i21 * (ax + dx) + i22 * (ay + dy))
    return im.transform(im.size, Image.AFFINE, (i11, i12, tx, i21, i22, ty), resample=Image.NEAREST)


def body_box(im):
    px = im.load()
    pts = [(x, y) for y in range(im.height) for x in range(im.width) if is_pink(px[x, y])]
    if not pts:
        return (0, 0, 1, 1)
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return (min(xs), min(ys), max(xs), max(ys))


# grietas en coordenadas relativas al cuerpo rosado (0..1)
CRACKS = [
    [(0.62, 0.05), (0.55, 0.22), (0.66, 0.34), (0.58, 0.5)],
    [(0.12, 0.45), (0.28, 0.52), (0.24, 0.66), (0.38, 0.78)],
    [(0.8, 0.55), (0.7, 0.68), (0.78, 0.82), (0.68, 0.95)],
    [(0.35, 0.1), (0.3, 0.2), (0.4, 0.28)],
    [(0.9, 0.2), (0.82, 0.3), (0.88, 0.42)],
]
MELT_X = [0.12, 0.3, 0.52, 0.74, 0.9]


def damage(im, level):
    """Capa de dano sobre una pose: grietas (solo sobre rosado) y cera derretida bajando por el cuerpo."""
    if level <= 0:
        return im
    im = im.copy()
    b = body_box(im)
    bw, bh = b[2] - b[0], b[3] - b[1]
    px = im.load()
    for poly in CRACKS[: 2 if level == 1 else 5]:
        pts = [(b[0] + u * bw, b[1] + v * bh) for u, v in poly]
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
            for t in range(steps + 1):
                x = int(round(x0 + (x1 - x0) * t / steps))
                y = int(round(y0 + (y1 - y0) * t / steps))
                if 0 <= x < im.width and 0 <= y < im.height and is_pink(px[x, y]):
                    px[x, y] = CRACK
    ln = [5, 9, 13] if level == 1 else [9, 15, 22]
    for k, u in enumerate(MELT_X[: 3 if level == 1 else 5]):
        x = int(b[0] + u * bw)
        y0 = next((y for y in range(im.height) if is_pink(px[x, y])), None)
        if y0 is None:
            continue
        for y in range(y0, min(b[3] - 2, y0 + ln[k % 3])):
            if is_pink(px[x, y]) or is_gold(px[x, y]):
                px[x, y] = GOLD if (y - y0) % 4 else GOLD_HI
                if level == 2 and x + 1 < im.width and is_pink(px[x + 1, y]):
                    px[x + 1, y] = GOLD
    return im


def rim_drips(im, t, n=4, maxlen=7):
    """Goteo animado de cera desde el borde dorado; t en [0,1) (ciclo)."""
    im = im.copy()
    px = im.load()
    cols = []
    for x in range(2, im.width - 2):
        ys = [y for y in range(im.height) if is_gold(px[x, y])]
        if ys:
            cols.append((x, max(ys)))
    if not cols:
        return im
    step = max(1, len(cols) // (n + 1))
    for k in range(n):
        x, yb = cols[min(len(cols) - 1, step * (k + 1))]
        ph = (t + k * 0.27) % 1.0
        ln = int(maxlen * math.sin(min(ph / 0.7, 1.0) * math.pi / 2)) if ph < 0.7 else 0
        for j in range(1, ln + 1):
            if 0 <= yb + j < im.height and px[x, yb + j][3] == 0:
                px[x, yb + j] = GOLD
        if ph >= 0.7:  # gota suelta
            yy = yb + maxlen + int((ph - 0.7) / 0.3 * 6)
            if 0 <= yy < im.height and px[x, yy][3] == 0:
                px[x, yy] = GOLD_HI
    return im


def steam(im, t):
    """Vapor: motitas claras que suben y se mecen sobre la olla (pixeles opacos)."""
    im = im.copy()
    px = im.load()
    ys = [y for y in range(im.height) if any(px[x, y][3] for x in range(im.width))]
    if not ys:
        return im
    top = min(ys)
    xs = [x for x in range(im.width) if any(px[x, y][3] for y in range(top, top + 6))]
    cx = (min(xs) + max(xs)) // 2
    for k, off in enumerate((-5, 0, 5)):
        for j in range(4):
            ph = (t + k * 0.33 + j * 0.12) % 1.0
            y = top - 1 - int(ph * 7)
            x = cx + off + int(round(math.sin((t * 2 + k + j * 0.6) * math.pi) * 1.6))
            if 0 <= y < im.height and 0 <= x < im.width and px[x, y][3] == 0 and ph < 0.85 and (j + k) % 2 == 0:
                px[x, y] = (235, 240, 245, 255)
    return im


def sweat(im, t):
    im = im.copy()
    px = im.load()
    for k, x in enumerate((6, 44)):
        y = 14 + int(((t + k * 0.5) % 1.0) * 14)
        for j in (0, 1):
            if px[x, y + j][3] == 0:
                px[x, y + j] = SWEAT
    return im


def sparkles(im, t, cx=26, cy=34, r=22):
    im = im.copy()
    px = im.load()
    for k in range(5):
        a = (t + k / 5.0) * 2 * math.pi
        x = int(cx + math.cos(a) * r * (0.7 + 0.3 * math.sin(k)))
        y = int(cy - 10 + math.sin(a * 2) * 14)
        if 0 <= x < im.width and 0 <= y < im.height and px[x, y][3] == 0:
            px[x, y] = SPARK
            if (int(t * 8) + k) % 2 == 0 and x + 1 < im.width and px[x + 1, y][3] == 0:
                px[x + 1, y] = SPARK
    return im


def speed_lines(im, dirx=-1, n=3):
    im = im.copy()
    px = im.load()
    for k in range(n):
        y = 24 + k * 9
        for x in range(0, 10):
            xx = (CW - 1 - x) if dirx > 0 else x
            if px[xx, y][3] == 0:
                px[xx, y] = (255, 255, 255, 255) if x % 3 else GOLD_HI
    return im


def S(i, n):
    return math.sin(2 * math.pi * i / n)


def frame_sets(P, level):
    """{animacion: [imagenes 52x60]} para un nivel de dano (0 sano, 1 grietas, 2 destrozada)."""
    def pz(name):
        n = {"base": "damaged", "idle": "damaged"}.get(name, name) if level == 2 else name
        return P[n] if n in ("damaged", "death") else damage(P[n], level)

    A = {}
    # idle: respira (estira y aplasta), goteo y vapor vivos
    fr = []
    for i in range(8):
        im = xf(pz("base") if i in (3, 4) else pz("idle"), sx=1 - 0.018 * S(i, 8), sy=1 + 0.035 * S(i, 8), rot=0.8 * S(i + 2, 8))
        fr.append(steam(rim_drips(im, i / 8.0), i / 8.0))
    A["idle"] = fr
    # walk: saltito con balanceo y aplastamiento al caer
    fr = []
    for i in range(8):
        hop = abs(S(i, 8)) * 3.0
        land = 1 if hop < 0.9 else 0
        im = xf(pz("idle" if i % 4 < 2 else "base"), sx=1 + 0.06 * land, sy=1 - 0.07 * land + 0.02 * (hop > 2), rot=4.0 * S(i, 8), dy=-hop)
        fr.append(steam(rim_drips(im, i / 8.0, 3), i / 8.0))
    A["walk"] = fr
    # attack generico: encoge, se echa atras y se queda en anticipacion (sin bucle)
    A["attack"] = [
        xf(pz("base"), sx=1.05, sy=0.93),
        xf(pz("windup"), sy=0.95, rot=-3),
        xf(pz("windup"), sx=0.98, sy=1.03),
        xf(pz("windup"), dx=-1),
        rim_drips(xf(pz("windup"), sx=1.02, sy=0.99, dx=-1), 0.3, 3),
    ]
    A["attack_tiron"] = [
        xf(pz("base"), sx=1.04, sy=0.94),
        xf(pz("pull"), sy=0.96, dx=1),
        xf(pz("pull"), sx=1.02, dx=2),
        xf(pz("pull"), sy=1.02, dx=3),
        xf(pz("pull"), sx=1.03, sy=0.99, dx=2),
        xf(pz("pull"), dx=3),
    ]
    A["attack_salpicadura"] = [
        xf(pz("base"), sx=1.04, sy=0.94),
        xf(pz("windup"), rot=-5, sy=0.97),
        xf(pz("spit"), rot=-3, dx=-1, sy=1.03),
        xf(pz("spit"), rot=-1),
        xf(pz("spit"), rot=-2, sy=1.04),
        xf(pz("spit")),
    ]
    A["attack_cruz"] = [
        xf(pz("cross"), sx=1 + 0.04 * S(i, 6), sy=1 - 0.03 * S(i, 6), rot=2.5 * S(i + 1, 6), dy=-abs(S(i, 6)) * 1.5) for i in range(6)
    ]
    A["attack_embestida"] = [
        xf(pz("base"), sx=1.1, sy=0.88),
        xf(pz("windup"), sx=1.06, sy=0.9, rot=-6, dx=-1),
        xf(pz("windup"), sx=1.08, sy=0.88, rot=-8, dx=-2),
        xf(pz("windup"), sx=1.1, sy=0.86, rot=-9, dx=-3),
    ]
    # release: se juegan al soltar el golpe
    A["release"] = [
        xf(pz("strike"), sx=1.1, sy=0.92, dx=2),
        xf(pz("strike"), dx=3),
        xf(pz("strike"), sx=0.97, sy=1.04, dx=2),
        xf(pz("base"), sx=1.04, sy=0.96),
        xf(pz("base")),
    ]
    A["release_spit"] = [
        xf(pz("spit"), sx=1.03, sy=1.04),
        xf(pz("spit")),
        xf(pz("base"), sx=1.03, sy=0.97),
        xf(pz("base")),
    ]
    A["charge"] = [speed_lines(xf(pz("strike"), rot=4 + 1.5 * S(i, 4), dy=-abs(S(i, 4)) * 2), 1) for i in range(4)]
    # tired: jadea (respiracion rapida, sudor, estrellitas ya en la pose)
    A["tired"] = [
        sweat(xf(pz("tired"), sx=1 + 0.03 * S(i, 6), sy=1 - 0.05 * S(i, 6), rot=1.5 * S(i + 1, 6), dy=0.5 * S(i, 6)), i / 6.0) for i in range(6)
    ]
    # channel: aura pulsante y vapor
    A["channel"] = [
        sparkles(steam(xf(pz("channel"), sx=1 + 0.035 * S(i, 8), sy=1 + 0.05 * S(i, 8), dy=-1.2 * abs(S(i, 8))), i / 8.0), i / 8.0)
        for i in range(8)
    ]
    A["hurt"] = [
        xf(pz("base"), sx=1.14, sy=0.86, rot=-6, dx=-2),
        xf(pz("damaged"), sx=0.95, sy=1.06, rot=-9, dx=-3),
        xf(pz("damaged"), sx=1.04, sy=0.97, rot=-4, dx=-1),
        xf(pz("base")),
    ]
    # muerte teatral: golpe, bamboleo, se aplasta y se derrite en charco con fantasma de vapor
    A["death"] = [
        xf(pz("base"), sx=1.14, sy=0.86, rot=-8, dx=-2),
        xf(pz("damaged"), sx=0.96, sy=1.06, rot=-14, dx=-3),
        xf(pz("tired"), rot=6, dx=1),
        xf(pz("tired"), sx=1.04, sy=0.94, rot=-9),
        xf(pz("tired"), sx=1.08, sy=0.86, rot=12, dx=2),
        xf(pz("death"), sx=1.05, sy=0.55),
        xf(pz("death"), sx=1.02, sy=0.75),
        xf(pz("death"), sx=0.99, sy=0.92),
        xf(pz("death")),
        xf(pz("death"), sy=0.97),
        xf(pz("death")),
        xf(pz("death"), sy=0.98),
    ]
    # intro: aterriza (en juego la baja el codigo), aplastamiento, pose triunfal con saltito y destellos
    A["intro"] = [
        xf(pz("base"), sx=0.9, sy=1.12),
        xf(pz("base"), sx=1.18, sy=0.8),
        xf(pz("intro"), sx=1.12, sy=0.86),
        xf(pz("intro"), sx=0.94, sy=1.1, dy=-3),
        xf(pz("intro"), dy=-1),
        xf(pz("intro"), sx=1.02, sy=0.98),
        sparkles(xf(pz("intro"), sy=1.02), 0.2),
        sparkles(xf(pz("intro")), 0.45),
        sparkles(xf(pz("intro"), sx=1.01, sy=0.99), 0.7),
        steam(xf(pz("base")), 0.5),
    ]
    return A


# (fps, loop) por animacion
ANIM_META = {
    "idle": (8, True), "walk": (10, True), "attack": (12, False), "attack_tiron": (8, False),
    "attack_salpicadura": (10, False), "attack_cruz": (8, True), "attack_embestida": (10, False),
    "release": (14, False), "release_spit": (12, False), "charge": (14, True), "tired": (7, True),
    "channel": (9, True), "hurt": (12, False), "death": (9, False), "intro": (6, False),
}
SHEET_COLS = 12


def write_sheet(A, level):
    tag = "" if level == 0 else f"_p{level + 1}"
    names = list(ANIM_META)
    total = sum(len(A[n]) for n in names)
    rows = (total + SHEET_COLS - 1) // SHEET_COLS
    sheet = Image.new("RGBA", (SHEET_COLS * CW * 2, rows * CH * 2), (0, 0, 0, 0))
    regions = {}
    k = 0
    for n in names:
        regions[n] = []
        for im in A[n]:
            x, y = (k % SHEET_COLS) * CW * 2, (k // SHEET_COLS) * CH * 2
            sheet.alpha_composite(G.up2(im), (x, y))
            regions[n].append((x, y))
            k += 1
    png = OUT / f"boss_cera_sheet{tag}.png"
    sheet.save(png)
    L = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (total + 2), "",
         '[ext_resource type="Texture2D" path="res://assets/sprites/enemies/%s" id="1_sheet"]' % png.name, ""]
    for n in names:
        for j, (x, y) in enumerate(regions[n]):
            L += [f'[sub_resource type="AtlasTexture" id="{n}_{j}"]', 'atlas = ExtResource("1_sheet")',
                  f"region = Rect2({x}, {y}, {CW * 2}, {CH * 2})", ""]
    L += ["[resource]", "animations = ["]
    ents = []
    for n in names:
        fps, loop = ANIM_META[n]
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % (n, j) for j in range(len(regions[n])))
        ents.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if loop else "false", n, fps))
    L.append(", ".join(ents))
    L.append("]")
    tres = OUT / f"boss_cera_sprite_frames{tag}.tres"
    tres.write_text("\n".join(L) + "\n")
    print("escrito", png.name, tres.name, total, "cuadros")


def build():
    raw = {n: G.load_pose(n) for n in G.ORDER}
    P = G.pixelate_set(raw)
    for n, im in P.items():
        G.up2(im).save(ROOT / f".claude_tmp/cera_pose_{n}.png")
    for level in range(3):
        write_sheet(frame_sets(P, level), level)
