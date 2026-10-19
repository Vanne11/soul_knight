"""Arte DEFINITIVO de ARCOIRIA (reino del Orgullo) con Gemini: recorta los originales y escribe en las
MISMAS rutas que usa el juego (el provisorio de gen_arcoiria_art.py), asi no se toca ninguna logica.

Uso: python3 tools/gen_arcoiria_art2.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten)
     python3 tools/gen_arcoiria_art2.py build [parte ...]  recorta, pixela y escribe los assets
Hojas (una imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/arcoiria/:
  commons prej_a prej_b boss_a boss_b icons floor motif wall decor      (10 llamadas; prompts en arc2_prompts.py)
Partes de build:
  enemigos  rumor comentario mirada fase armario hombre(+_l/_r) etiqueta -> assets/sprites/enemies/<v>_<anim>_NN.png 32x48
  jefe      destine (156x180, cuadros de BossAnimator) + <base>_p2/_p3     -> assets/sprites/enemies/destine_*
  iconos    assets/sprites/items/bandera_<color>.png y bandera_completa.png (24x24)
  suelo     assets/sprites/environment/floors/floor_orgullo.png + assets/tilesets/floor_orgullo.tres
  muros     assets/sprites/environment/walls/orgullo/* + assets/tilesets/walls_orgullo.tres
  decor     assets/sprites/environment/decor/orgullo_*.png
Densidad: 1 pixel de arte = 1 unidad de juego (como el heroe de 32x48); reduccion con contornos conservados,
paleta corta por personaje y SIN ampliar (NEAREST). Mismo recorte para humor: contra el prejuicio, nunca contra personas.
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arc2_cut as CUT  # noqa: E402
import arc2_gemini as GEM  # noqa: E402

ROOT = GEM.ROOT
RAW = GEM.RAW
EN = ROOT / "assets/sprites/enemies"
CW, CH = 32, 48
OL = (13, 11, 15)


# ------------------------------------------------------------------ utilidades de pixel art
def down(im: Image.Image, w: int, h: int) -> Image.Image:
    """Reduce conservando los contornos oscuros: promedio de caja, pero si el bloque trae contorno gana el pixel mas oscuro."""
    avg = np.array(im.resize((w, h), Image.BOX)).astype(np.int32)
    big = np.array(im.resize((w * 3, h * 3), Image.BOX)).astype(np.int32)
    lum = (big[:, :, 0] * 3 + big[:, :, 1] * 6 + big[:, :, 2]) // 10
    lum = np.where(big[:, :, 3] > 140, lum, 999)
    out = avg.copy()
    blocks = lum.reshape(h, 3, w, 3).transpose(0, 2, 1, 3).reshape(h, w, 9)
    colors = big[:, :, :3].reshape(h, 3, w, 3, 3).transpose(0, 2, 1, 3, 4).reshape(h, w, 9, 3)
    idx = blocks.argmin(-1)
    dark = np.take_along_axis(blocks, idx[:, :, None], -1)[:, :, 0]
    cnt = (blocks < 70).sum(-1)
    pick = np.take_along_axis(colors, idx[:, :, None, None], 2)[:, :, 0, :]
    use = (dark < 70) & (cnt >= 2)
    out[:, :, :3] = np.where(use[:, :, None], pick, out[:, :, :3])
    out[:, :, 3] = np.where(use, 255, out[:, :, 3])
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


def trim(im: Image.Image) -> Image.Image:
    bb = im.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    return im.crop(bb) if bb else im


def place(im: Image.Image, scale: float, cw=CW, ch=CH, maxw=None, maxh=None, foot=0) -> Image.Image:
    """Reduce la pose a `scale` (mismo valor para todo el personaje), pies abajo y centrada en x."""
    im = trim(im)
    maxw = maxw or cw - 2
    maxh = maxh or ch - 1
    k = min(scale, maxh / im.height, 1.6 * maxw / im.width)  # las poses anchas (brazo, etiqueta lanzada) no encogen al personaje: se recorta la punta
    w, h = max(1, round(im.width * k)), max(1, round(im.height * k))
    sm = down(im, w, h)
    cv = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    cv.alpha_composite(sm, ((cw - w) // 2 if w <= maxw else 1, ch - h - foot))
    return cv


def quantize_set(frames: dict, ncolors: int = 24) -> dict:
    """Una sola paleta corta para todas las poses del personaje (coherencia) y alfa binario."""
    px = []
    for im in frames.values():
        a = np.array(im)
        px.append(a[a[:, :, 3] > 128][:, :3])
    allpx = np.concatenate(px)
    n = len(allpx)
    side = int(math.ceil(math.sqrt(n)))
    mos = np.zeros((side * side, 3), np.uint8)
    mos[:n] = allpx
    mos[n:] = allpx[: max(1, side * side - n) % n] if n < side * side else mos[n:]
    pal_im = Image.fromarray(mos.reshape(side, side, 3), "RGB").quantize(colors=ncolors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    out = {}
    for k, im in frames.items():
        a = np.array(im)
        q = np.array(Image.fromarray(a[:, :, :3], "RGB").quantize(palette=pal_im, dither=Image.Dither.NONE).convert("RGB"))
        al = np.where(a[:, :, 3] > 128, 255, 0).astype(np.uint8)
        out[k] = Image.fromarray(np.dstack([q, al]), "RGBA")
    return out


def xf(im, sx=1.0, sy=1.0, rot=0.0, dx=0.0, dy=0.0):
    """Transformacion anclada en los pies (centro-abajo), vecino mas cercano: pixel art nitido."""
    w, h = im.size
    ax, ay = w / 2.0, h - 1.0
    c, sn = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    m11, m12, m21, m22 = c * sx, -sn * sy, sn * sx, c * sy
    det = m11 * m22 - m12 * m21
    i11, i12, i21, i22 = m22 / det, -m12 / det, -m21 / det, m11 / det
    tx = ax - (i11 * (ax + dx) + i12 * (ay + dy))
    ty = ay - (i21 * (ax + dx) + i22 * (ay + dy))
    return im.transform(im.size, Image.AFFINE, (i11, i12, tx, i21, i22, ty), resample=Image.NEAREST)


def lay(im, ang):
    """Gira la pose `ang` grados (cae al suelo), la ajusta al lienzo con vecino mas cercano y la deja con los pies abajo."""
    r = trim(im.rotate(ang, expand=True, resample=Image.NEAREST))
    k = min(1.0, (CW - 2) / r.width, (CH - 2) / r.height)
    if k < 1.0:
        r = r.resize((max(1, round(r.width * k)), max(1, round(r.height * k))), Image.NEAREST)
    cv = Image.new("RGBA", im.size, (0, 0, 0, 0))
    cv.alpha_composite(r, ((im.width - r.width) // 2, im.height - r.height))
    return cv


def flash(im, amt=0.55, col=(255, 255, 255)):
    a = np.array(im).astype(np.float32)
    m = a[:, :, 3] > 0
    for i in range(3):
        a[:, :, i] = np.where(m, a[:, :, i] * (1 - amt) + col[i] * amt, a[:, :, i])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def sheet_cells(name, gap=14):
    return [c for _, c, _ in CUT.cells(RAW / f"{name}.png", gap)[1]]


# ------------------------------------------------------------------ enemigos
# indices de pose en cada hoja (ver CUT.debug): idle, walk A, walk B, ataque 1, ataque 2, herido, muerto, [especiales]
SPEC = {
    "rumor": dict(sheet="commons", idx=dict(idle=0, wa=1, wb=2, a0=3, a1=5, hurt=6, dead=7), rowband=(0, 340)),
    "comentario": dict(sheet="commons", idx=dict(idle=9, wa=11, wb=13, a0=16, a1=17, hurt=18, dead=19), gap=4, merge=((9, 10), (11, 12), (13, 14), (14, 15))),
    "mirada": dict(sheet="commons", idx=dict(idle=20, wa=21, wb=22, hurt=26, dead=27), gap=4, derive_attack=True),
    "fase": dict(sheet="prej_a", idx=dict(idle=0, wa=1, wb=2, a0=3, a1=4, hurt=5, dead=6, sp0=7, sp1=8)),
    "armario": dict(sheet="prej_a", idx=dict(idle=18, wa=19, wb=20, a0=21, a1=22, hurt=23, dead=24, sp0=25, sp1=26)),
    "hombre": dict(sheet="prej_b", idx=dict(idle=0, wa=1, wb=2, a0=3, a1=4, hurt=5, dead=6, half_l=7, half_r=8)),
    "etiqueta": dict(sheet="prej_b", idx=dict(idle=18, wa=19, wb=20, a0=22, a1=23, hurt=24, dead=25)),
}
TARGET_H = 41  # alto del idle: como los provisorios (y 6..47 en 32x48)


def _poses(name):
    """Poses crudas de un personaje (recortadas de la hoja)."""
    sp = SPEC[name]
    path = RAW / f"{sp['sheet']}.png"
    im, cs = CUT.cells(path, sp.get("gap", 14))
    by = {i: c for i, c, _ in cs}
    return {k: by[v] for k, v in sp["idx"].items()}


def _rumor_poses():
    """El rumor lo dibujo Gemini en dos filas pegadas: se recorta solo la primera (banda y < 340 px)."""
    im = CUT.cut_bg(Image.open(RAW / "commons.png"))
    cols = [(0, 344), (344, 688), (688, 1032), (1032, 1376), (1376, 1720), (1720, 2064), (2064, 2408), (2408, 2752)]
    idx = dict(idle=0, wa=1, wb=2, a0=3, a1=5, hurt=6, dead=7)
    return {k: im.crop((cols[v][0], 0, cols[v][1], 340)) for k, v in idx.items()}


def _comentario_poses():
    """El '?!' flotante se separa del globo: se recorta por columna en la banda del globo."""
    im = CUT.cut_bg(Image.open(RAW / "commons.png"))
    cols = [(0, 344), (344, 688), (688, 1032), (1032, 1376), (1376, 1720), (1720, 2064), (2064, 2408), (2408, 2752)]
    idx = dict(idle=0, wa=1, wb=2, a0=4, a1=5, hurt=6, dead=7)
    return {k: im.crop((cols[v][0], 620, cols[v][1], 1030)) for k, v in idx.items()}


def _mirada_poses():
    im = CUT.cut_bg(Image.open(RAW / "commons.png"))
    cols = [(0, 344), (344, 688), (688, 1032), (1032, 1376), (1376, 1720), (1720, 2064), (2064, 2408), (2408, 2752)]
    idx = dict(idle=0, wa=1, wb=2, w3=3, hurt=6, dead=7)
    return {k: im.crop((cols[v][0], 1150, cols[v][1], 1536)) for k, v in idx.items()}


def build_enemy(name):
    if name == "rumor":
        raw = _rumor_poses()
    elif name == "comentario":
        raw = _comentario_poses()
    elif name == "mirada":
        raw = _mirada_poses()
    else:
        raw = _poses(name)
    return raw


def enemy_frames(name, raw):
    """raw: poses recortadas -> dict anim -> lista de 32x48 (misma cantidad de cuadros que el provisorio)."""
    idle_raw = trim(raw["idle"])
    s = TARGET_H / idle_raw.height
    for k in ("idle", "wa", "wb", "hurt"):
        s = min(s, 29.0 / trim(raw[k]).width)  # el cuerpo entero cabe en 32 px; solo las puntas (brazo, etiqueta lanzada) se recortan
    P = {k: place(v, s) for k, v in raw.items() if not k.startswith("half")}
    out = {}
    out["idle"] = [P["idle"]]
    out["walk"] = [P["wa"], P["idle"], P["wb"], P["idle"]]
    if "a0" in P:
        out["attack"] = [P["a0"], P["a1"], P["a1"]]
    else:  # la mirada no tiene ataque dibujado: se anima el idle (se echa atras y embiste)
        base = P["idle"]
        out["attack"] = [xf(base, sy=0.9, rot=-5, dx=-1), xf(base, sy=1.04, rot=5, dx=1), xf(base, rot=3, dx=1)]
    out["hurt"] = [P["hurt"], flash(P["hurt"], 0.5)]
    out["death"] = [P["hurt"], xf(P["hurt"], sy=0.82), P["dead"], P["dead"]]
    if "sp0" in raw:
        key = {"fase": "ghost", "armario": "open"}[name]
        spec = {k: place(raw[k], s) for k in ("sp0", "sp1")}
        out[key] = [spec["sp0"], spec["sp1"]]
    return out, s


def half_frames(raw, s, which):
    """Una mitad de 'El hombre' suelta: idle dibujado y el resto derivado por codigo (salto, embestida, desplome)."""
    base = place(raw[which], s)
    out = {"idle": [base]}
    out["walk"] = [xf(base, rot=-3), xf(base, dy=-1), xf(base, rot=3), xf(base, dy=-1)]
    out["attack"] = [xf(base, rot=-6, dx=-1), xf(base, rot=7, dx=2), xf(base, rot=4, dx=1)]
    out["hurt"] = [flash(xf(base, rot=-4, dx=-1)), flash(base, 0.5)]
    out["death"] = [flash(xf(base, rot=-4), 0.3), xf(base, sy=0.85), lay(base, 90), lay(base, 90)]
    return out


def save_frames(variant, frames, ncolors=24):
    flat = {(a, i): im for a, lst in frames.items() for i, im in enumerate(lst)}
    q = quantize_set(flat, ncolors)
    for (a, i), im in q.items():
        im.save(EN / f"{variant}_{a}_{i:02d}.png")


def build_enemigos(only=None):
    for name in SPEC:
        if only and name not in only and not (name == "hombre" and any(o.startswith("hombre") for o in only)):
            continue
        raw = build_enemy(name)
        frames, s = enemy_frames(name, raw)
        if name == "hombre":
            # misma paleta para el hombre entero y sus mitades
            flat = dict(frames)
            hl, hr = half_frames(raw, s, "half_l"), half_frames(raw, s, "half_r")
            allf = {}
            for tag, fr in (("hombre", frames), ("hombre_l", hl), ("hombre_r", hr)):
                for a, lst in fr.items():
                    for i, im in enumerate(lst):
                        allf[(tag, a, i)] = im
            q = quantize_set(allf, 28)
            for (tag, a, i), im in q.items():
                im.save(EN / f"{tag}_{a}_{i:02d}.png")
        else:
            save_frames(name, frames)
        print("enemigo", name, "escala", round(s, 3))


# ------------------------------------------------------------------ vista previa
def preview_enemigos(dest):
    names = [n for n in ("rumor", "comentario", "mirada", "fase", "armario", "hombre", "hombre_l", "hombre_r", "etiqueta")]
    anims = [("idle", 1), ("walk", 4), ("attack", 3), ("hurt", 2), ("death", 4), ("ghost", 2), ("open", 2)]
    S = 3
    rows = []
    for n in names:
        cells = []
        for a, c in anims:
            for i in range(c):
                p = EN / f"{n}_{a}_{i:02d}.png"
                if p.exists():
                    cells.append(Image.open(p).convert("RGBA"))
        rows.append(cells)
    W = max(len(r) for r in rows) * CW * S
    sheet = Image.new("RGBA", (W, len(rows) * CH * S), (58, 56, 84, 255))
    for y, r in enumerate(rows):
        for x, im in enumerate(r):
            sheet.alpha_composite(im.resize((CW * S, CH * S), Image.NEAREST), (x * CW * S, y * CH * S))
    sheet.convert("RGB").save(Path(dest) / "enemigos.png")


GEN_ORDER = ["commons", "prej_a", "prej_b", "boss_a", "boss_b", "icons", "floor", "motif", "wall", "decor"]

if __name__ == "__main__":
    import arc2_prompts as P

    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        for n in args or GEN_ORDER:
            if (RAW / f"{n}.png").exists() and not args:
                continue
            refs = ()
            if n == "boss_b":
                a = Image.open(RAW / "boss_a.png")
                refs = (a,)
            aspect = {"motif": "1:1"}.get(n, "16:9")
            GEM.generate(n, getattr(P, n.upper()), aspect=aspect, size="2K", refs=refs)
    elif cmd == "build":
        parts = args or ["enemigos"]
        if "enemigos" in parts:
            build_enemigos()
        if "jefe" in parts:
            import arc2_boss
            arc2_boss.build()
        if "preview" in parts:
            import arc2_boss
            dd = args[args.index("preview") + 1] if len(args) > args.index("preview") + 1 else "."
            preview_enemigos(dd)
            arc2_boss.preview(dd)
