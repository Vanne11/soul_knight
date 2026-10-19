"""Iconos de poderes, suelo, muros y decorado del reino de ARCOIRIA (Orgullo) a partir de las hojas de Gemini.

Lo llama gen_arcoiria_art2.py (`build iconos suelo muros decor`).
  iconos  assets/sprites/items/bandera_<color>.png + bandera_completa.png (24x24)
  suelo   assets/sprites/environment/floors/floor_orgullo.png (atlas 512x384, mismo reparto que gen_floor_art.py)
          + assets/tilesets/floor_orgullo.tres (reusa gen_floor_art.write_tileset)
  muros   assets/sprites/environment/walls/orgullo/*.png + assets/tilesets/walls_orgullo.tres (gen_wall_art.tileset_text)
  decor   assets/sprites/environment/decor/orgullo_*.png
Escala siempre con reduccion de contornos conservados (A.down) y paleta corta, SIN ampliar.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import arc2_cut as CUT
import gen_arcoiria_art2 as A

ROOT, RAW = A.ROOT, A.RAW
OL = (13, 11, 15, 255)
STRIPES = [(232, 64, 72), (255, 150, 48), (255, 214, 64), (78, 190, 96), (64, 130, 230), (150, 96, 220)]


def sheet(name):
    return CUT.cut_bg(Image.open(RAW / f"{name}.png"))


def fit(im, w, h, nearest=False):
    """Escala (no uniforme si hace falta) a w x h conservando contornos."""
    return A.down(im, w, h)


# ------------------------------------------------------------------ iconos
# (centro x, centro y, radio) de cada medallon en la hoja original de 2752x1536
ICON_CIRCLES = dict(
    rojo=(351, 361, 330), naranja=(1042, 388, 322), amarillo=(1723, 385, 322), verde=(2415, 351, 318),
    azul=(832, 1190, 262), violeta=(1369, 1190, 262), completa=(2463, 1194, 268),
)


def build_iconos():
    sh = sheet("icons")
    out = {}
    for k, (cx, cy, r) in ICON_CIRCLES.items():
        m = int(r * 1.04)
        c = sh.crop((cx - m, cy - m, cx + m, cy + m))
        yy, xx = np.mgrid[0:2 * m, 0:2 * m]
        circ = ((xx - m) ** 2 + (yy - m) ** 2) <= (r + 6) ** 2
        a = np.array(c)
        a[:, :, 3] = np.where(circ, a[:, :, 3], 0)
        c = Image.fromarray(a, "RGBA")
        out[k] = A.down(A.trim(c), 24, 24)
    q = A.quantize_set(out, 40)
    for k, im in q.items():
        im.save(ROOT / f"assets/sprites/items/bandera_{k}.png")
    print("iconos", ", ".join(q))


# ------------------------------------------------------------------ suelo
T = 64


def slab_tiles():
    """12 losas de la hoja: 8 lisas + 4 ornamentadas, cada una a 64x64 (interior sin su borde: las juntas las pinto yo)."""
    cs = [c for _, c, _ in CUT.cells(RAW / "floor.png", 4)[1]]
    assert len(cs) == 12, len(cs)
    tiles = []
    for c in cs:
        w, h = c.size
        ix, iy = int(w * 0.07), int(h * 0.09)
        c = c.crop((ix, iy, w - ix, h - iy))
        s = min(c.width, c.height)
        c = c.crop(((c.width - s) // 2, (c.height - s) // 2, (c.width - s) // 2 + s, (c.height - s) // 2 + s))
        tiles.append(c.resize((T, T), Image.BOX))
    return tiles


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def slab(im, shade=0.0):
    """Losa de 64x64: juntas de 1 px oscuras a la derecha/abajo, brillo 1 px arriba/izquierda (embaldosan sin costura)."""
    a = np.array(im.convert("RGBA")).astype(np.int32)
    a[:, :, 3] = 255
    base = a[T // 2, T // 2, :3]
    dark = np.array(lerp(base, (60, 40, 70), 0.42))
    light = np.array(lerp(base, (255, 255, 255), 0.5))
    a[T - 1, :, :3] = dark
    a[:, T - 1, :3] = dark
    a[T - 2, 1:T - 1, :3] = lerp(base, (60, 40, 70), 0.18)
    a[1:T - 1, T - 2, :3] = lerp(base, (60, 40, 70), 0.18)
    a[0, :T - 1, :3] = light
    a[:T - 1, 0, :3] = light
    if shade:
        a[:, :, :3] = np.clip(a[:, :, :3] * (1 + shade), 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def band(kind):
    """Franja pegada al muro de ARRIBA (se gira para las otras): sombra de contacto + cinta de 6 colores (A) o banderines (B)."""
    im = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    px = im.load()
    for y in range(15):  # sombra de contacto
        al = int(110 * (1 - y / 15.0) ** 1.5)
        for x in range(T):
            px[x, y] = (40, 24, 56, al)
    if kind == 0:
        for i, col in enumerate(STRIPES):
            for x in range(T):
                px[x, 5 + i] = col + (255,)
        for x in range(T):
            px[x, 4] = OL
            px[x, 11] = OL
    else:
        for x in range(T):
            px[x, 3] = OL
        for k in range(8):  # banderines triangulares colgando de un cordel
            col = STRIPES[k % 6]
            x0 = k * 8 + 1
            for dy in range(4):
                for xx in range(x0 + dy, x0 + 7 - dy):
                    px[xx, 4 + dy] = col + (255,)
            px[x0 + 3, 8] = OL
    return im


def rot(im, k):
    return im.rotate({0: 0, 1: 90, 2: 180, 3: -90}[k], resample=Image.NEAREST)


def build_suelo():
    tiles = slab_tiles()
    cream = Image.new("RGB", (T, T), (246, 238, 224))

    def soft(t, k):
        return Image.blend(t.convert("RGB"), cream, k).convert("RGBA")

    # reparto de colores: FloorTiles elige 0-4 casi siempre (suelo crema con apenas un tinte), 5-7 a veces (mas color) y
    # 8-11 casi nunca (losas a todo color): el suelo es una plaza clara con acentos, no un patchwork que compita con los actores
    calm = [soft(tiles[i], 0.82) for i in (2, 1, 0, 6, 5)] + [soft(tiles[i], 0.55) for i in (3, 4, 7)]
    plain = [slab(t, s) for t, s in zip(calm, (0.0, 0.02, -0.02, 0.03, -0.03, 0.01, 0.0, -0.01))]
    loud = [slab(tiles[i]).rotate(180) for i in (0, 3, 4, 5)]
    ornate = [slab(soft(t, 0.25)) for t in tiles[8:]]
    atlas = Image.new("RGBA", (8 * T, 6 * T), (0, 0, 0, 0))

    def paste(im, col, row):
        atlas.alpha_composite(im, (col * T, row * T))

    for i in range(8):
        paste(plain[i], i, 0)
    for i in range(4):  # fill 8-11: losas a todo color (raras)
        paste(loud[i], i, 1)
    for i in range(4):
        paste(ornate[i], 4 + i, 1)
    base_edge = plain[0]
    for b in (0, 1):
        bd = band(b)
        for d, k in enumerate((0, -1, 2, 1)):  # N, E, S, O
            t = base_edge.copy()
            t.alpha_composite(rot(bd, {0: 0, -1: 3, 2: 2, 1: 1}[k]))
            paste(t, d, 2 + b)
    bn, bo = band(0), band(0)
    for d, (r1, r2) in enumerate(((0, 1), (0, 3), (3, 2), (2, 1))):  # NO, NE, SE, SO
        t = base_edge.copy()
        t.alpha_composite(rot(bn, r1))
        t.alpha_composite(rot(bo, r2))
        paste(t, 4 + d, 2)
    # motivo 3x3: medallon de Gemini sobre 9 losas lisas
    mo = Image.open(RAW / "motif.png").convert("RGBA")
    S = mo.width
    cx = cy = int(S * 0.4995)
    rr = int(S * 0.415)
    yy, xx = np.mgrid[0:S, 0:S]
    from PIL import ImageEnhance
    mo = ImageEnhance.Brightness(mo.convert("RGB")).enhance(1.22).convert("RGBA")  # mas claro: en gris no debe parecer una tapa de alcantarilla
    a = np.array(mo)
    a[:, :, 3] = np.where(((xx - cx) ** 2 + (yy - cy) ** 2) <= rr * rr, 255, 0)
    med = A.down(Image.fromarray(a, "RGBA"), 192, 192)
    big = Image.new("RGBA", (3 * T, 3 * T), (0, 0, 0, 0))
    for j in range(3):
        for i in range(3):
            big.alpha_composite(plain[(i + j * 3) % 8], (i * T, j * T))
    big.alpha_composite(med)
    atlas.alpha_composite(big, (5 * T, 3 * T))
    q = A.quantize_set({"a": atlas}, 96)["a"]
    # la cuantizacion binariza el alfa: el atlas es opaco salvo celdas vacias (se conserva el alfa original)
    qa = np.array(q)
    qa[:, :, 3] = np.where(np.array(atlas)[:, :, 3] > 128, 255, 0)
    out_dir = ROOT / "assets/sprites/environment/floors"
    Image.fromarray(qa, "RGBA").save(out_dir / "floor_orgullo.png")
    import gen_floor_art as GF
    GF.write_tileset("orgullo")
    print("suelo floor_orgullo.png + floor_orgullo.tres")


# ------------------------------------------------------------------ muros
def build_muros():
    out_dir = ROOT / "assets/sprites/environment/walls/orgullo"
    out_dir.mkdir(parents=True, exist_ok=True)
    sh = sheet("wall")
    cs = {i: c for i, c, _ in CUT.cells(RAW / "wall.png", 14)[1]}
    assert len(cs) == 6, len(cs)
    face_a, face_b, cap, flag, mural, win = (cs[i] for i in range(6))
    # ---- cara frontal A (franjas de arcoiris): cuadrado central del interior (sin el borde ni el remate de los lados)
    w, h = face_a.size
    ix = int(w * 0.06)
    inner = face_a.crop((ix, int(h * 0.02), w - ix, h))
    s = inner.height
    inner = inner.crop(((inner.width - s) // 2, 0, (inner.width - s) // 2 + s, s))
    fa = A.down(inner, T, T)
    # ---- cara B: la misma pared de franjas un poco mas oscura (mezclada con la A en la misma pared no hace parches de otro material;
    # el ladrillo con banderines de la hoja queda en los originales por si se quiere para otra pared)
    from PIL import ImageEnhance
    fb = ImageEnhance.Brightness(fa.convert("RGB")).enhance(0.93).convert("RGBA")
    fb.putalpha(fa.getchannel("A"))
    # ---- tapa
    w, h = cap.size
    cp = cap.crop((int(w * 0.01), int(h * 0.02), w - int(w * 0.01), int(h * 0.92)))
    cap_a = A.down(cp, T, T)
    cap_b = cap_a.transpose(Image.FLIP_LEFT_RIGHT)
    atlas = Image.new("RGBA", (4 * T, T), (0, 0, 0, 0))
    for i, im in enumerate((cap_a, fa, cap_b, fb)):
        atlas.alpha_composite(im, (i * T, 0))
    # ---- zocalo: del rodapie de la cara A
    w, h = face_a.size
    base_strip = face_a.crop((ix, int(h * 0.90), w - ix, h))
    zt = A.down(base_strip, T, 12)
    zb = A.down(base_strip, T, 8)
    zs = zb.transpose(Image.ROTATE_270).transpose(Image.FLIP_LEFT_RIGHT)
    # ---- banderin colgante, cuadro, ventana
    banner = A.down(flag, 26, 42)
    painting = A.down(mural, 32, 38)
    ww, wh = win.size
    port = A.down(win, 26, 26)
    window = Image.new("RGBA", (26, 40), (0, 0, 0, 0))
    window.alpha_composite(port, (0, 7))
    pieces = {"atlas": atlas, "zocalo_top": zt, "zocalo_bottom": zb, "zocalo_side": zs,
              "banner": banner, "painting": painting, "window": window}
    q = A.quantize_set(pieces, 64)
    for k, im in q.items():
        im.save(out_dir / f"{k}.png")
    frame_img().save(out_dir / "frame.png")
    step_img().save(out_dir / "step.png")
    import gen_wall_art as GW
    (GW.TILESETS / "walls_orgullo.tres").write_text(GW.tileset_text("orgullo"))
    print("muros", ", ".join(list(q) + ["frame", "step"]))


def frame_img():
    """Marco de puerta 88x88 con hueco de 64x64: yeso crema y cinta de la bandera por dentro."""
    im = Image.new("RGBA", (88, 88), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cream = [(255, 244, 224), (248, 228, 200), (226, 200, 172), (200, 170, 146)]
    layers = [OL[:3]] + [cream[0], cream[0], cream[1], cream[2]] + list(STRIPES) + [OL[:3]]  # 12 anillos
    for i, col in enumerate(layers):
        d.rectangle([i, i, 87 - i, 87 - i], outline=col + (255,))
    d.rectangle([12, 12, 75, 75], fill=(0, 0, 0, 0))
    return im


def step_img():
    im = Image.new("RGBA", (84, 14), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 83, 13], fill=(238, 220, 194, 255), outline=OL)
    d.rectangle([1, 1, 82, 2], fill=(255, 248, 232, 255))
    d.rectangle([1, 10, 82, 12], fill=(196, 168, 142, 255))
    return im


# ------------------------------------------------------------------ decorado
DECOR = [  # (indice en la hoja, nombre, alto de salida)
    (0, "orgullo_guirnalda", 40), (1, "orgullo_farol", 76), (2, "orgullo_maceta", 34), (3, "orgullo_mural", 44),
    (4, "orgullo_carro", 52), (5, "orgullo_sombrilla", 44), (6, "orgullo_tambor", 40), (7, "orgullo_regalos", 40),
]


def build_decor():
    cs = {i: c for i, c, _ in CUT.cells(RAW / "decor.png", 20)[1]}
    assert len(cs) >= 8, len(cs)
    out = {}
    for i, name, hh in DECOR:
        c = cs[i]
        if name == "orgullo_farol":  # el halo amarillo-verdoso del farol se mezclo con el fondo: fuera
            a = np.array(c).astype(int)
            glow = (a[:, :, 1] >= a[:, :, 0] - 8) & (a[:, :, 1] > a[:, :, 2] + 50) & (a[:, :, 1] > 110)
            a[glow, 3] = 0
            c = Image.fromarray(a.astype(np.uint8), "RGBA")
        c = A.trim(c)
        s = hh / c.height
        out[name] = A.down(c, max(1, round(c.width * s)), hh)
    # banderin colgante: la tira vertical de banderines de la hoja de muros
    wsh = CUT.cells(RAW / "wall.png", 14)[1]
    flag = A.trim(dict((i, c) for i, c, _ in wsh)[3])
    out["orgullo_banderin"] = A.down(flag, 14, 38)
    q = A.quantize_set(out, 56)
    d = ROOT / "assets/sprites/environment/decor"
    for k, im in q.items():
        A.trim(im).save(d / f"{k}.png")
    print("decor", ", ".join(q))
