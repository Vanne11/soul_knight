"""Jefe LA CENSURA QUE DESTINE (156x180, cuadros de BossAnimator) con las hojas boss_a / boss_b de Gemini.

Lo llama `python3 tools/gen_arcoiria_art2.py build jefe`. Escribe assets/sprites/enemies/destine_sheet[_p2|_p3].png y
destine_sprite_frames[_p2|_p3].tres (misma ruta que usaba el provisorio). Las fases 2 y 3 son la misma
hoja con manchas de color que se le cuelan por la bata (el dano lo va recoloreando).
"""
from pathlib import Path

import numpy as np
from PIL import Image

import arc2_cut as CUT
import gen_arcoiria_art2 as A

RAW, EN = A.RAW, A.EN
BW, BH = 156, 180
STRIPES = [(232, 64, 72), (255, 150, 48), (255, 214, 64), (78, 190, 96), (64, 130, 230), (150, 96, 220)]
# poses: (hoja, indice de componente | caja de recorte en px de la hoja original)
POSES = dict(
    idle=("boss_a", 0), roller_up=("boss_a", 1), roller_hit=("boss_a", 2), stamp_up=("boss_a", 3),
    stamp_hit=("boss_a", 4), tired=("boss_a", 5), channel=("boss_a", 6), hurt=("boss_a", 7),
    intro=("boss_b", (0, 0, 720, 790)), stun=("boss_b", (1400, 800, 2060, 1536)),
    hat_off=("boss_b", (2130, 0, 2752, 790)), melt=("boss_b", (2060, 790, 2752, 1536)),
)
SCALE_H = 138  # alto del idle en el lienzo (los ataques con el rodillo en alto necesitan margen)


def coat_mask(a):
    lum = (a[:, :, 0] * 3 + a[:, :, 1] * 6 + a[:, :, 2]) // 10
    return (a[:, :, 3] > 200) & (lum > 135) & (a[:, :, 2] > a[:, :, 0] + 8)


def coat_x(im):
    """x del centro de la bata (gris azulado claro): ancla comun de todas las poses (no depende de rodillo ni sello)."""
    ys, xs = np.nonzero(coat_mask(np.array(im).astype(int)))
    return float(np.median(xs)) if len(xs) > 50 else im.width / 2.0


def poses():
    sheets = {n: CUT.cut_bg(Image.open(RAW / f"{n}.png")) for n in ("boss_a", "boss_b")}
    cells_a = {i: c for i, c, _ in CUT.cells(RAW / "boss_a.png", 24)[1]}
    raw = {}
    for k, (sh, ref) in POSES.items():
        raw[k] = cells_a[ref] if isinstance(ref, int) else CUT.main_blob(sheets[sh].crop(ref))
    s = SCALE_H / A.trim(raw["idle"]).height
    out = {}
    for k, im in raw.items():
        im = A.trim(im)
        cx = coat_x(im)
        w, h = round(im.width * s), round(im.height * s)
        kfit = min(1.0, (BW - 2) / w, (BH - 1) / h)
        w, h = max(1, round(w * kfit)), max(1, round(h * kfit))
        sm = A.down(im, w, h)
        x0 = int(round(BW / 2 - cx * s * kfit))
        x0 = max(1, min(BW - w - 1, x0))
        cv = Image.new("RGBA", (BW, BH), (0, 0, 0, 0))
        cv.alpha_composite(sm, (x0, BH - h))
        out[k] = cv
    return A.quantize_set(out, 48)


def stain(im, level, seed=5):
    """Fases 2 y 3: manchas de la bandera sobre la bata gris."""
    if level <= 0:
        return im
    a = np.array(im).astype(int)
    coat = coat_mask(a)
    rng = np.random.RandomState(seed)
    ys, xs = np.mgrid[0:BH, 0:BW]
    out = np.array(im).copy()
    for i in range(3 if level == 1 else 8):
        cx, cy, r = 78 + rng.randint(-30, 30), 132 + rng.randint(-22, 22), rng.randint(5, 9)
        col = np.array(STRIPES[i % 6])
        d = ((xs - cx) ** 2 + (ys - cy) ** 2) ** 0.5 + rng.rand(BH, BW) * 3.5
        m = coat & (d < r) & (ys > 112)
        out[m, :3] = col
        out[m & (xs < cx - 1) & (ys < cy - 1) & (d < r * 0.6), :3] = np.minimum(255, col + 70)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def anims(P):
    xf = A.xf
    I = P["idle"]
    f = {}
    f["idle"] = [I, xf(I, sy=0.985)]
    f["walk"] = [xf(I, rot=-2.5), xf(I, dy=-3), xf(I, rot=2.5), xf(I, dy=-3)]
    f["attack"] = [I, xf(P["roller_up"], rot=-3), P["roller_up"]]
    f["attack_rodillo"] = f["attack"]
    f["attack_sello"] = [I, xf(P["stamp_up"], rot=-3), P["stamp_up"]]
    f["attack_pinta"] = [I, xf(P["channel"], sy=0.97), P["channel"]]
    f["attack_embestida"] = [I, xf(I, rot=-9, dx=-3), xf(I, rot=-12, dx=-4)]
    f["release"] = [P["roller_hit"], P["roller_hit"], xf(P["roller_hit"], dy=1)]
    f["charge"] = [P["stamp_hit"], xf(P["stamp_hit"], dy=-3)]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]
    f["channel"] = [P["channel"], xf(P["channel"], sy=1.015), P["channel"], xf(P["channel"], sy=0.99)]
    f["hurt"] = [P["hurt"], P["hurt"], xf(P["hurt"], dx=-1)]
    f["death"] = [P["hurt"], P["hat_off"], P["melt"], P["melt"]]
    f["intro"] = [P["intro"], P["intro"], P["intro"], I]
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], sy=0.985), P["tired"], xf(P["tired"], sy=1.012)]
    f["stun_in"] = [P["hurt"], P["stun"]]
    f["brake"] = [xf(I, rot=7, dx=2), xf(I, rot=3)]
    f["blink"] = [I, I]
    f["idle_stir"] = [xf(I, rot=-2), xf(I, rot=2), I]
    f["idle_impatient"] = [xf(I, dy=-2), I, xf(I, dy=-2), I]
    # nombres que BossAnimator puede pedir aunque Destine no los use: se resuelven con poses vecinas
    for n, src in (("attack_tiron", "attack"), ("attack_salpicadura", "attack"), ("attack_cruz", "attack"),
                   ("release_spit", "release"), ("spitting", "release"), ("cross_spin", "charge"),
                   ("drag", "tired"), ("stuck", "tired")):
        f[n] = f[src]
    return f


META = {  # (velocidad, bucle) como Dona Cera
    "idle": (6.0, True), "walk": (10.0, True), "attack": (12.0, False), "attack_rodillo": (10.0, False),
    "attack_sello": (10.0, False), "attack_pinta": (10.0, False), "attack_embestida": (10.0, False),
    "attack_tiron": (10.0, False), "attack_salpicadura": (10.0, False), "attack_cruz": (10.0, False),
    "release": (14.0, False), "release_spit": (12.0, False), "spitting": (10.0, True), "charge": (14.0, True),
    "tired": (7.0, True), "channel": (9.0, True), "hurt": (12.0, False), "death": (4.0, False), "intro": (3.0, False),
    "cross_spin": (10.0, True), "recover_in": (10.0, False), "recover": (7.0, True), "stun_in": (12.0, False),
    "stuck": (9.0, True), "drag": (10.0, True), "brake": (12.0, False), "blink": (14.0, False),
    "idle_stir": (8.0, False), "idle_impatient": (8.0, False),
}


def write_frames(frames, tag):
    """Hoja PNG (cada cuadro distinto una vez) + SpriteFrames con AtlasTexture, como boss_cera_*."""
    uniq, index = [], {}
    for lst in frames.values():
        for im in lst:
            k = im.tobytes()
            if k not in index:
                index[k] = len(uniq)
                uniq.append(im)
    cols = 8
    rows = (len(uniq) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * BW, rows * BH), (0, 0, 0, 0))
    for i, im in enumerate(uniq):
        sheet.alpha_composite(im, ((i % cols) * BW, (i // cols) * BH))
    png = EN / f"destine_sheet{tag}.png"
    sheet.save(png)
    L = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(uniq) + 2), "",
         f'[ext_resource type="Texture2D" path="res://assets/sprites/enemies/{png.name}" id="1_sheet"]', ""]
    for i in range(len(uniq)):
        L += [f'[sub_resource type="AtlasTexture" id="f{i}"]', 'atlas = ExtResource("1_sheet")',
              f"region = Rect2({(i % cols) * BW}, {(i // cols) * BH}, {BW}, {BH})", ""]
    anim = []
    for n, lst in frames.items():
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("f%d")\n}' % index[im.tobytes()] for im in lst)
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if META[n][1] else "false", n, META[n][0]))
    L += ["[resource]", "animations = [" + ", ".join(anim) + "]", ""]
    (EN / f"destine_sprite_frames{tag}.tres").write_text("\n".join(L))
    print("jefe", png.name, len(uniq), "cuadros")


def build():
    P = poses()
    for level, tag in ((0, ""), (1, "_p2"), (2, "_p3")):
        write_frames(anims({k: stain(v, level) for k, v in P.items()}), tag)
    for old in EN.glob("destine_*_[0-9][0-9].png*"):
        old.unlink()  # los cuadros sueltos del provisorio (80x120): ahora todo va en la hoja


def preview(dest):
    P = poses()
    cols = 6
    sheet = Image.new("RGBA", (cols * BW, ((len(P) + cols - 1) // cols) * BH), (58, 56, 84, 255))
    for i, im in enumerate(P.values()):
        sheet.alpha_composite(im, ((i % cols) * BW, (i // cols) * BH))
    sheet.convert("RGB").save(Path(dest) / "jefe_poses.png")
    st = Image.new("RGBA", (3 * BW, BH), (58, 56, 84, 255))
    for i in range(3):
        st.alpha_composite(stain(P["idle"], i), (i * BW, 0))
    st.convert("RGB").save(Path(dest) / "jefe_fases.png")
