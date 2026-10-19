"""Arte DEFINITIVO de la HOJA DE PARRA (jefe final, forma 1), LA PARRA ENTERA (forma 2) y la HOJITA CENSORA (esbirro)
con Gemini. Recorta los originales y escribe en las MISMAS rutas que usa el juego (los provisorios de
gen_parra_art.py y del espermatozoide teñido), asi no se toca ninguna logica de combate.

Uso: python3 tools/gen_parra_art2.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten)
     python3 tools/gen_parra_art2.py build [parte ...]  recorta, pixela y escribe los assets (sin args = todo)
Hojas (una imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/parra/:
  hoja_a hoja_b parra_a parra_b hojita        (5 llamadas; prompts en parra_prompts.py)
Partes de build:
  hoja     156x180, cuadros de BossAnimator -> assets/sprites/enemies/hoja_de_parra_sheet.png + hoja_de_parra_sprite_frames.tres
  parra    224x256, cuadros de BossAnimator -> assets/sprites/enemies/parra_sheet.png + parra_sprite_frames.tres
  hojita   32x48 -> assets/sprites/enemies/hojita_censora_<anim>_NN.png + hojita_censora_sprite_frames.tres
Densidad: 1 pixel de arte = 1 unidad de juego (como el heroe de 32x48); reduccion con contornos conservados,
paleta corta por personaje y SIN ampliar (NEAREST).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arc2_cut as CUT  # noqa: E402
import arc2_gemini as GEM  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402

ROOT = GEM.ROOT
RAW = ROOT / ".claude/arte_fuente/parra"
GEM.RAW = RAW
EN = A.EN
OLD_SIGNATURE = "hoja_de_parra_idle_00.png"
KEY = np.array([0, 253, 2])


def cut_bg(im: Image.Image) -> Image.Image:
    """Quita el fondo verde plano. Los personajes SON verdes: la clave es estricta (distancia al verde exacto del
    fondo) y solo se borra el verde conectado a los bordes, asi el verde de la hoja no se pierde."""
    a = np.array(im.convert("RGB")).astype(int)
    h, w = a.shape[:2]
    near = np.sqrt(((a - KEY) ** 2).sum(-1)) < 70
    seen = np.zeros((h, w), bool)
    stack = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    while stack:
        y, x = stack.pop()
        if y < 0 or x < 0 or y >= h or x >= w or seen[y, x] or not near[y, x]:
            continue
        seen[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    mid = np.sqrt(((a - KEY) ** 2).sum(-1)) < 130  # halo verdoso pegado al fondo
    grow = np.array(Image.fromarray((seen * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(3))) > 0
    seen |= grow & mid
    return Image.fromarray(np.dstack([a.astype(np.uint8), np.where(seen, 0, 255).astype(np.uint8)]), "RGBA")


CUT.cut_bg = cut_bg


def _flat(path, k=4):
    """El sprite actual ampliado (NEAREST) sobre gris: referencia de diseno para Gemini."""
    im = Image.open(path).convert("RGBA")
    im = im.resize((im.width * k, im.height * k), Image.NEAREST)
    bg = Image.new("RGBA", im.size, (96, 96, 112, 255))
    bg.alpha_composite(im)
    return bg


GEN_ORDER = ["hoja_a", "hoja_b", "parra_a", "parra_b", "hojita"]


def gen(names):
    import parra_prompts as P

    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        aspect = "16:9"
        if n == "hoja_a":
            refs = (Image.open(ROOT / "assets/sprites/ui/bosses/hoja_de_parra.png"),)
            if (EN / OLD_SIGNATURE).exists():  # el sprite provisorio ya no esta tras el build: el retrato basta
                refs = (_flat(EN / OLD_SIGNATURE),) + refs
        elif n == "hoja_b":
            refs = (Image.open(RAW / "hoja_a.png"),)
        elif n == "parra_a":
            refs = (Image.open(RAW / "hoja_a.png"),)
        elif n == "parra_b":
            refs = (Image.open(RAW / "parra_a.png"),)
        else:
            refs = (Image.open(RAW / "hoja_a.png"),)
        GEM.generate(n, getattr(P, n.upper()), aspect=aspect, size="2K", refs=refs)


# ------------------------------------------------------------------ recorte de poses
def _cells(name, gap=24):
    return {i: c for i, c, _ in CUT.cells(RAW / f"{name}.png", gap)[1]}


def _grid(name, cols, y_split=784):
    """Hoja de 2 filas x 4 columnas recortada por rejilla (las poses de la Parra se tocan por las enredaderas).
    cols: limites x de las 4 columnas; cada recorte se queda solo con su pose mas grande."""
    im = cut_bg(Image.open(RAW / f"{name}.png"))
    out = {}
    for r, (y0, y1) in enumerate(((0, y_split), (y_split, im.height))):
        for c in range(4):
            out[r * 4 + c] = CUT.main_blob(im.crop((cols[c], y0, cols[c + 1], y1)))
    return out


def _feet_x(im):
    """x del centro de la base (pies / raices): ancla comun de todas las poses del personaje."""
    a = np.array(im)[:, :, 3] > 128
    ys = np.nonzero(a.any(1))[0]
    lo = ys.max() - max(6, int(0.12 * (ys.max() - ys.min())))
    xs = np.nonzero(a[lo:].any(0))[0]
    return (xs.min() + xs.max()) / 2.0


def fit(raw, cw, ch, scale_h, mult=None):
    """Todas las poses a la MISMA escala (idle -> scale_h de alto o lo que deje el lienzo), pies abajo y ancladas en la base.
    mult: factor propio de las poses que Gemini dibujo mas de cerca (la cara sale mas grande que en el idle)."""
    mult = mult or {}
    raw = {k: A.trim(v) for k, v in raw.items()}
    s = scale_h / raw["idle"].height
    for k, v in raw.items():
        m = mult.get(k, 1.0)
        s = min(s, (ch - 1) / (v.height * m), (cw - 2) / (v.width * m))
    out = {}
    for k, im in raw.items():
        fx = _feet_x(im)
        m = mult.get(k, 1.0)
        w, h = max(1, round(im.width * s * m)), max(1, round(im.height * s * m))
        sm = A.down(im, w, h)
        x0 = int(round(cw / 2 - fx * s * m))
        x0 = max(1, min(cw - w - 1, x0))
        cv = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        cv.alpha_composite(sm, (x0, ch - h))
        out[k] = cv
    print("  escala", round(s, 3))
    return A.quantize_set(out, 56)


# ------------------------------------------------------------------ jefe (hoja de cuadros para BossAnimator)
META = {  # (velocidad, bucle) como Dona Cera; attack_<x> y release_<x> usan (10, no bucle)
    "idle": (6.0, True), "walk": (10.0, True), "attack": (12.0, False), "release": (14.0, False),
    "tired": (7.0, True), "channel": (9.0, True), "hurt": (12.0, False), "death": (3.5, False), "intro": (3.0, False),
    "recover_in": (10.0, False), "recover": (7.0, True), "stun_in": (12.0, False), "blink": (14.0, False),
    "idle_stir": (8.0, False), "idle_impatient": (8.0, False), "brake": (12.0, False), "charge": (14.0, True),
    "stuck": (9.0, True), "drag": (10.0, True), "cross_spin": (10.0, True), "release_spit": (12.0, False),
    "spitting": (10.0, True),
}


def write_boss(frames, cw, ch, base):
    """Hoja PNG (cada cuadro distinto una vez) + SpriteFrames con AtlasTexture, como destine_* y boss_cera_*."""
    uniq, index = [], {}
    for lst in frames.values():
        for im in lst:
            k = im.tobytes()
            if k not in index:
                index[k] = len(uniq)
                uniq.append(im)
    cols = 6
    rows = (len(uniq) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    for i, im in enumerate(uniq):
        sheet.alpha_composite(im, ((i % cols) * cw, (i // cols) * ch))
    sheet.save(EN / f"{base}_sheet.png")
    L = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(uniq) + 2), "",
         f'[ext_resource type="Texture2D" path="res://assets/sprites/enemies/{base}_sheet.png" id="1_sheet"]', ""]
    for i in range(len(uniq)):
        L += [f'[sub_resource type="AtlasTexture" id="f{i}"]', 'atlas = ExtResource("1_sheet")',
              f"region = Rect2({(i % cols) * cw}, {(i // cols) * ch}, {cw}, {ch})", ""]
    anim = []
    for n, lst in frames.items():
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("f%d")\n}' % index[im.tobytes()] for im in lst)
        sp, loop = META.get(n, (10.0, False))
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if loop else "false", n, sp))
    L += ["[resource]", "animations = [" + ", ".join(anim) + "]", ""]
    (EN / f"{base}_sprite_frames.tres").write_text("\n".join(L))
    for old in EN.glob(f"{base}_*_[0-9][0-9].png*"):
        old.unlink()  # cuadros sueltos del provisorio: ahora todo va en la hoja
    print("jefe", base, len(uniq), "cuadros")


def _common(P, f):
    """Animaciones que BossAnimator puede pedir y que se resuelven igual en las dos formas."""
    xf = A.xf
    I = P["idle"]
    f["idle"] = [I, xf(I, sy=0.985)]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]
    f["channel"] = [P["channel"], xf(P["channel"], sy=1.015), P["channel"], xf(P["channel"], sy=0.99)]
    f["hurt"] = [P["hurt"], P["hurt"], xf(P["hurt"], dx=-1)]
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], sy=0.985), P["tired"], xf(P["tired"], sy=1.012)]
    f["stun_in"] = [P["hurt"], P["stun"]]
    f["brake"] = [xf(I, rot=7, dx=2), xf(I, rot=3)]
    f["blink"] = [I, I]
    f["idle_stir"] = [xf(I, rot=-2), xf(I, rot=2), I]
    f["idle_impatient"] = [xf(I, dy=-2), I, xf(I, dy=-2), I]
    # nombres que BossAnimator puede pedir aunque la Hoja y la Parra no los usen: se resuelven con poses vecinas
    for n, src in (("attack_tiron", "attack"), ("attack_salpicadura", "attack"), ("attack_cruz", "attack"),
                   ("attack_embestida", "attack"), ("release_spit", "release"), ("spitting", "release"),
                   ("cross_spin", "release"), ("charge", "release"), ("drag", "tired"), ("stuck", "tired")):
        f[n] = f[src]


HW, HH = 156, 180


def hoja_poses():
    a, b = _cells("hoja_a"), _cells("hoja_b")
    raw = dict(idle=a[0], wa=a[1], wb=a[2], windup=a[3], release=a[4], tired=a[5], channel=a[6], hurt=a[7],
               intro=b[0], stun=b[1], d1=b[2], d2=b[6], d3=b[3], d4=b[7])
    return fit(raw, HW, HH, 166)


def hoja_anims(P):
    xf = A.xf
    I = P["idle"]
    f = {}
    f["walk"] = [P["wa"], I, P["wb"], I]
    f["attack"] = [I, xf(P["windup"], rot=-3), P["windup"]]
    f["release"] = [P["release"], P["release"], xf(P["release"], dy=1)]
    f["attack_tapar"] = f["attack_escudo"] = [I, xf(P["channel"], sy=0.97), P["channel"]]
    f["death"] = [P["hurt"], P["d1"], P["d2"], P["d3"], P["d4"], P["d4"]]
    f["intro"] = [P["intro"], P["intro"], P["intro"], I]
    _common(P, f)
    return f


def build_hoja():
    write_boss(hoja_anims(hoja_poses()), HW, HH, "hoja_de_parra")


# ------------------------------------------------------------------ LA PARRA ENTERA
PW, PH = 240, 264


def parra_poses():
    a = _grid("parra_a", [0, 690, 1380, 2100, 2752])
    b = _grid("parra_b", [0, 690, 1380, 2064, 2752])
    raw = dict(idle=a[0], whip_up=a[1], whip=a[2], roots_up=a[3], roots=a[4], channel=a[5], tired=a[6], hurt=a[7],
               stun=b[0], strangle=b[1], d1=b[2], d2=b[6], d3=b[3], d4=b[7], sprout=b[5])
    close = {k: 0.78 for k in ('channel', 'tired', 'hurt', 'd2', 'sprout')}  # dibujadas de cerca: mas cara que el idle
    return fit(raw, PW, PH, 236, close)


def parra_anims(P):
    xf = A.xf
    I = P["idle"]
    f = {}
    f["walk"] = f["intro"] = [I, xf(I, sy=0.985)]
    f["attack"] = [I, xf(P["whip_up"], rot=-1), P["whip_up"]]
    f["attack_latigazo"] = f["attack"]
    f["release"] = f["release_latigazo"] = [P["whip"], P["whip"], xf(P["whip"], dy=1)]
    f["attack_raices"] = [I, xf(P["roots_up"], sy=0.99), P["roots_up"]]
    f["release_raices"] = [P["roots"], P["roots"], xf(P["roots"], dy=1)]
    f["attack_estrangula"] = [I, xf(P["strangle"], sy=0.98), P["strangle"]]
    f["release_estrangula"] = [P["strangle"], xf(P["strangle"], sy=1.012), P["strangle"]]
    f["attack_brotes"] = [I, xf(P["sprout"], sy=0.98), P["sprout"]]
    f["release_brotes"] = [P["sprout"], xf(P["sprout"], sy=1.012)]
    f["death"] = [P["hurt"], P["d1"], P["d2"], P["d3"], P["d4"], P["d4"]]
    _common(P, f)
    return f


def build_parra():
    write_boss(parra_anims(parra_poses()), PW, PH, "parra")


# ------------------------------------------------------------------ esbirro: hojita censora
def hojita_frames():
    c = _cells("hojita")
    raw = dict(idle=c[0], wa=c[1], wb=c[2], plant=c[3], shoot=c[4], hurt=c[5], d1=c[6], d2=c[7])
    s = A.TARGET_H / A.trim(raw["idle"]).height
    for k in ("idle", "wa", "wb", "hurt"):
        s = min(s, 29.0 / A.trim(raw[k]).width)
    P = {k: A.place(v, s) for k, v in raw.items()}
    f = {"idle": [P["idle"], A.xf(P["idle"], sy=0.97)], "walk": [P["wa"], P["idle"], P["wb"], P["idle"]],
         "plant": [A.xf(P["idle"], sy=0.94), P["plant"], P["plant"]],
         "attack": [P["shoot"], P["shoot"]],
         "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)],
         "death": [P["hurt"], P["d1"], P["d2"], P["d2"]]}
    print("hojita escala", round(s, 3))
    return f


HOJITA_SPEEDS = {"idle": (4.0, True), "walk": (8.0, True), "plant": (8.0, False), "attack": (10.0, False),
                 "hurt": (10.0, False), "death": (8.0, False)}


def build_hojita():
    frames = hojita_frames()
    A.save_frames("hojita_censora", frames, 24)
    res, anim = [], []
    for n, lst in frames.items():
        fr = []
        for i in range(len(lst)):
            rid = f"{n}{i}"
            res.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/enemies/hojita_censora_{n}_{i:02d}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        sp, loop = HOJITA_SPEEDS[n]
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
    (EN / "hojita_censora_sprite_frames.tres").write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(res) + "\n\n[resource]\nanimations = [" + ", ".join(anim) + "]\n")


def preview(dest):
    """Hoja de contacto de las poses de la Hoja y de la Parra para revisarlas a ojo."""
    for nm, P in (("hoja", hoja_poses()), ("parra", parra_poses())):
        cw, ch = next(iter(P.values())).size
        cols = 5
        sh = Image.new("RGBA", (cols * cw, ((len(P) + cols - 1) // cols) * ch), (58, 56, 84, 255))
        for i, im in enumerate(P.values()):
            sh.alpha_composite(im, ((i % cols) * cw, (i // cols) * ch))
        sh.convert("RGB").save(Path(dest) / f"{nm}_poses.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["hoja", "parra", "hojita"]
        if "hoja" in parts:
            build_hoja()
        if "parra" in parts:
            build_parra()
        if "hojita" in parts:
            build_hojita()
    elif cmd == "preview":
        preview(args[0] if args else ".")
