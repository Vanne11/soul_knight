"""Arte DEFINITIVO del TESTICULO PRIMORDIAL (jefe del Conducto Deferente, Penelandia), sus MITADES (fase 3) y el REBOTIN con Gemini.
Escribe en assets/sprites/enemies/penelandia/testiculo_primordial/ y penelandia/rebotin/ (carpetas de assets/data/enemy_art.json).

Uso: python3 tools/gen_testiculo_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_testiculo_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_testiculo_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/testiculo/:
  test_a test_b test_c   (sano)    test_a_p2 test_b_p2 test_c_p2   (fase 2)    test_a_p3 test_b_p3 test_c_p3   (fase 3)
  mitades                rebotin                                                (11 + 2 = 13 llamadas; 14 es el tope)
Partes de build: boss (176x184 -> testiculo_primordial_sheet{,_p2,_p3}.png + testiculo_primordial_sprite_frames{,_p2,_p3}.tres)
                 mitades (96x96 -> testiculo_mitad_{a,b}_sheet.png: pinza + 4 cuadros de rodar)
                 rebotin (32x48 -> rebotin_*_NN.png + rebotin_sprite_frames.tres)
Densidad: 1 pixel de arte = 1 unidad de juego (como el heroe de 32x48), reduccion con contornos conservados,
paleta corta fija por variante, SIN ampliar (NEAREST). Cuadros intermedios por script (xf), como Dona Cera y Ovaria.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import arc2_cut as CUT  # noqa: E402
import arc2_gemini as GEM  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402
import gen_parra_art2 as PA  # noqa: E402  (cut_bg estricto para fondo verde)
from arc2_gemini import STYLE  # noqa: E402

ROOT = GEM.ROOT
RAW = ROOT / ".claude/arte_fuente/testiculo"
GEM.RAW = RAW
DEST = ROOT / "assets/sprites/enemies/penelandia/testiculo_primordial"
RES = "res://assets/sprites/enemies/penelandia/testiculo_primordial/"
OLD = DEST / "testiculo_primordial_idle_00.png"
CUT.cut_bg = PA.cut_bg

# ------------------------------------------------------------------ prompts
_TEST = (
    "THE BOSS 'Testiculo Primordial' (the Primordial Testicle), grumpy guardian of the vas deferens and a living "
    "pinball bumper: a big plump round salmon-PINK testicle body, a bit wider than tall, with horizontal skin-fold "
    "wrinkle lines and thin magenta veins; ONE giant cyclops EYE in the middle, heavy-lidded, sleepy and grumpy, cream "
    "sclera with a dark pupil; a downturned frown mouth under the eye; on top a short curved tube-like stalk (the "
    "epididymis) with two gold bands; a wide GOLD BELT band around the lower body like a pinball bumper ring; underneath "
    "four short stubby tentacle-legs with gold-tipped feet. Bad-tempered, humorous, satirical. "
    "Same character, same proportions, same colors and same design as the reference image(s), but redrawn with much "
    "more detail, richer shading and a premium look. "
)
_ORDER = (
    " All poses are the SAME character at the SAME scale and the same camera, full body visible, a single big character "
    "per cell, no extra characters except the props named. Never draw text, letters or numbers. "
)
_DMG2 = (
    "It is the DAMAGED PHASE 2 of the SAME character as the reference sheet: same poses in the same order and positions, "
    "same design, but clearly battle-damaged: a long crack across the body, a dented gold belt, a bent stalk with one chipped "
    "band, bruised darker pink patches, a bloodshot eye with red veins, angrier narrowed lid, a sweat drop, "
    "slightly deeper red-pink skin with darker shadows. "
)
_DMG3 = (
    "It is the HEAVILY DAMAGED, ENRAGED PHASE 3 of the SAME character as the reference sheet: same poses in the same order, "
    "same design, but desperate and furious: a vertical seam splitting the body in two held with cartoon stitches and a "
    "plaster patch, big cracks, a broken kinked stalk with a gold band missing, a cracked hanging gold belt, a very "
    "bloodshot twitchy eye with a tiny pupil, gritted frown, a much darker redder angry flushed skin tone, steam puffs. "
)
_POSES_A = (
    "Poses left to right, top row: (1) neutral IDLE standing, grumpy, tentacle-legs planted; (2) ROLLING frame 1: the whole "
    "round body tumbling forward tilted about 90 degrees so the eye faces up-right and the stalk points forward, legs flailing, "
    "speed lines behind; (3) ROLLING frame 2: the body rolled upside down (180 degrees), the stalk pointing at the ground, the "
    "legs up in the air, eye upside down, speed lines; (4) ROLLING frame 3: the body rolled about 270 degrees so the stalk "
    "points backwards and the eye faces down, legs flailing, motion blur lines. Bottom row: (5) PINBALL WIND-UP: squashed "
    "and coiled low like a compressed spring, legs splayed, the gold belt vibrating, eye narrowed and furious, a red glow; "
    "(6) PINBALL STRIKE: stretched long forward mid-lunge as a fiery streak, eye wide open, legs trailing behind, big motion "
    "trail; (7) SPERM WAVE WIND-UP: the body inflated like a balloon, the frown mouth gaping wide open, cream-white sperm cells "
    "with long tails gathering in front of the mouth; (8) SPERM WAVE RELEASE: mouth wide open firing a stream of small "
    "cream-white sperm cells with tails forward, recoiling backwards."
)
_POSES_B = (
    "Poses left to right, top row: (1) dramatic INTRO entrance: standing proudly with the tentacle-legs spread, eye wide and "
    "smug, stalk straight up, gold belt gleaming, a bounce of dust; (2) EXHAUSTED: slumped and flattened, deflated, eye "
    "half shut, panting steam, sweat drops, stalk drooping; (3) STUNNED and dizzy, a swirly spiral eye, tiny stars circling "
    "the stalk, wobbling tilted, legs limp; (4) CHANNELING A HEALING: eye closed, serene, glowing warm orange-gold aura, "
    "tiny plus signs and hearts rising, the stalk pulsing with light. Bottom row, (5) HURT: flinching backwards, the eye "
    "squeezed shut, mouth gasping, a small spray of sweat, body dented; then a theatrical DEATH in 3 steps: (6) shaking, "
    "cracked all over and steaming, eye popping; (7) puffed up like an overinflated balloon about to burst, the seams "
    "stretched, eye spinning; (8) completely deflated into a sad shriveled wrinkly raisin-sized lump on the ground with a "
    "tiny white flag in the stalk, X eye, and a tiny ghost leaving."
)
_POSES_C = (
    "Poses left to right, top row: (1) GENERIC ATTACK WIND-UP: leaning back, the legs braced, the eye narrowed, a ring of "
    "cream-white sperm cells gathered and spinning in front; (2) GENERIC ATTACK RELEASE: leaning forward, firing a fan of "
    "cream-white sperm cells forward with motion lines; (3) SPLIT WIND-UP: a glowing white-orange crack running vertically "
    "from the stalk down to the belt, the body trembling and bulging, the eye pupil shaking; (4) SPLIT RELEASE: the body "
    "tearing apart along the crack, two halves bursting outwards left and right with gooey strands between them. Bottom "
    "row: (5) MINION WIND-UP: cheeks puffed up, the stalk pointing up like a pipe, little pinball balls bubbling at the "
    "stalk top; (6) MINION RELEASE: burping out small round pinball balls with tiny feet from the stalk top, recoiling; "
    "(7) BRAKING: skidding to a halt with the legs dug in, the body leaning forward squashed, dust cloud; (8) ROLLING frame "
    "4: the body squashed and tilted forward mid-roll at about 45 degrees, legs tucked, speed lines."
)
_HALVES = (
    "ENEMY SPRITE SHEET with exactly 2 rows of 4 poses (8 poses). Two reference images: the first is the full boss 'Testiculo "
    "Primordial' (a round pink testicle with a cyclops eye, gold belt, tentacle legs, stalk on top); the second is its "
    "damaged phase. This sheet shows the boss SPLIT IN TWO HALVES in phase 3, each half is a pink hemisphere DOME: the outer "
    "curved side keeps the skin wrinkles, veins and half of the gold belt; the flat CUT side shows gooey pink flesh with "
    "cream-white tubule swirls; each half has one angry eye, a furious frown, and two stubby gold-tipped tentacle-legs. "
    "Top row = the LEFT HALF (cut side facing right): (1) PINCER READY pose: crouched, glowing, eye furious, about to "
    "charge; (2) ROLLING frame 1; (3) ROLLING frame 2 (rotated about 90 degrees); (4) ROLLING frame 3 (rotated about 180 "
    "degrees), with speed lines. Bottom row = the RIGHT HALF (cut side facing left), the mirror twin with the same four "
    "poses. Same scale and same palette in every cell." + _ORDER
)
_REBOTIN = (
    "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses), the SAME tiny creature at the same scale in each cell. "
    "THE ENEMY 'Rebotin': a small pinball come to life, a round glossy cream-pearl and pale gold metallic BALL with one big "
    "googly eye with a dark pupil, a small angry brow, a gold stripe around its middle, and two tiny stubby legs with gold "
    "shoes, a small dent on its side. Cute but aggressive and humorous. Palette: cream, pale gold, a touch of pink. "
    "Poses left to right, top row: (1) idle standing, bouncing slightly; (2) CHARGE TREMBLE A: squashed low and vibrating, "
    "flushed red, angry eyes narrowed, motion lines; (3) CHARGE TREMBLE B: squashed even lower, shaking the other way, gritted, "
    "a red glow, steam; (4) ROLLING: tucked fully into a perfect ball (no legs visible), a streak and speed lines behind. "
    "Bottom row: (5) ROLLING frame 2: the ball tilted, the eye peeking out, motion lines; (6) DIZZY: wobbling, swirly spiral "
    "eye, tiny stars circling, tongue-less drunk smile; (7) death part one: dented and flattened, the eye popping out; "
    "(8) death part two: burst into a puff of springs, screws and gold bits with a tiny ghost leaving." + _ORDER
)

PROMPTS = {}
for _k, _p in (("a", _POSES_A), ("b", _POSES_B), ("c", _POSES_C)):
    _lead = "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses)."
    PROMPTS[f"test_{_k}"] = STYLE + _lead + _ORDER + _TEST + _p
    PROMPTS[f"test_{_k}_p2"] = STYLE + _lead + " " + _DMG2 + _ORDER + _TEST + _p
    PROMPTS[f"test_{_k}_p3"] = STYLE + _lead + " " + _DMG3 + _ORDER + _TEST + _p
_MATCH = (
    " STYLE MATCH (critical): keep EXACTLY the silhouette, proportions, eye size, thin gold belt position and thin stubby legs of "
    "the reference sheet, the same chunky pixel size and 1-pixel dark outline, the same pose composition in every cell; only add the "
    "damage described. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
)
for _n in list(PROMPTS):
    if _n.endswith("_p2") or _n.endswith("_p3"):
        PROMPTS[_n] += _MATCH
PROMPTS["test_b"] = PROMPTS["test_b"] + (
    " STYLE MATCH (critical): the two reference sheets show the approved look. Copy it EXACTLY: the same flat matte salmon-pink "
    "skin with fine horizontal wrinkle lines and thin magenta veins, the same THIN gold belt band (not a fat glossy ring), the "
    "same thin stubby legs, the same eye size, the same chunky pixel size and 1-pixel dark outline. No glossy plastic highlights, "
    "no smooth airbrushed shading, no orange tint. Do NOT write pose names or any caption under the poses."
)
PROMPTS["mitades"] = STYLE + _HALVES
PROMPTS["rebotin"] = STYLE + _REBOTIN
GEN_ORDER = ["test_a", "test_b", "test_c", "test_a_p2", "test_b_p2", "test_c_p2", "test_a_p3", "test_b_p3", "test_c_p3", "mitades", "rebotin"]


def _flat(path, k=4):
    im = Image.open(path).convert("RGBA")
    im = im.resize((im.width * k, im.height * k), Image.NEAREST)
    bg = Image.new("RGBA", im.size, (96, 96, 112, 255))
    bg.alpha_composite(im)
    return bg


def gen(names):
    portrait = Image.open(ROOT / "assets/sprites/ui/bosses/testiculo_primordial.png")
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n == "test_a":
            refs = ([_flat(OLD)] if OLD.exists() else []) + [portrait]
        elif n == "rebotin":
            refs = []
        elif n == "mitades":
            refs = [Image.open(RAW / "test_a.png"), Image.open(RAW / "test_a_p3.png")]
        elif n == "test_b":
            refs = [Image.open(RAW / "test_a.png"), Image.open(RAW / "test_c.png")]
        elif n == "test_c":
            refs = [Image.open(RAW / "test_a.png")]
        elif n.endswith("_p2") or n.endswith("_p3"):
            # primera ref: la hoja sana del mismo tipo (poses); la fase se pide por texto y con la hoja A de la fase como diseno
            base = n.rsplit("_", 1)[0]
            suf = n.rsplit("_", 1)[1]
            refs = [Image.open(RAW / f"{base}.png")]
            if base != "test_a":
                refs.append(Image.open(RAW / f"test_a_{suf}.png"))
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K", refs=refs)
        print("LLAMADA a Gemini:", n)


# ------------------------------------------------------------------ recorte por rejilla (automatico)
def _bg(path):
    im = PA.cut_bg(Image.open(path))
    a = np.array(im).astype(int)
    green = (a[:, :, 1] > np.maximum(a[:, :, 0], a[:, :, 2]) + 18) & (a[:, :, 3] > 0)
    a[:, :, 3] = np.where(green, 0, a[:, :, 3])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def _runs(col, gap):
    """Tramos continuos de columnas con contenido, uniendo huecos menores que gap."""
    idx = np.nonzero(col > 0)[0]
    if len(idx) == 0:
        return []
    runs, s, p = [], idx[0], idx[0]
    for i in idx[1:]:
        if i - p > gap:
            runs.append((s, p + 1))
            s = i
        p = i
    runs.append((s, p + 1))
    return runs


def _split4(al, gap=40):
    """Cuatro cajas x de una fila: los 4 tramos de mas masa; si faltan, cuartos iguales."""
    col = (al > 128).sum(0)
    runs = _runs(col, gap)
    runs = sorted(sorted(runs, key=lambda r: -col[r[0]:r[1]].sum())[:4])
    if len(runs) != 4:
        w = al.shape[1] // 4
        return [(i * w, (i + 1) * w) for i in range(4)]
    return runs


def _no_label_top(al):
    runs = _runs((al > 128).sum(1), 10)
    if len(runs) >= 2 and runs[0][1] - runs[0][0] < 75 and runs[1][0] - runs[0][1] >= 10:
        return runs[1][0] - 2
    return 0


def _no_label(al):
    """Altura util de la banda: quita la ultima franja de texto (etiqueta que Gemini escribe a veces bajo las poses)."""
    rows = np.nonzero((al > 128).sum(1) > 0)[0]
    runs = _runs((al > 128).sum(1), 10)
    if len(runs) >= 2 and runs[-1][1] - runs[-1][0] < 75 and runs[-1][0] - runs[-2][1] >= 10:
        return runs[-2][1] + 4
    return al.shape[0]


def _grid(name, gap=40, blob_gap=60):
    im = _bg(RAW / f"{name}.png")
    al = np.array(im)[:, :, 3]
    rows = (al > 128).sum(1)
    mid = im.height // 2
    lo, hi = mid - 220, mid + 220
    ys = lo + int(np.argmin(np.convolve(rows[lo:hi], np.ones(15) / 15, "same")))  # corte en el hueco mas vacio
    out = {}
    for r, (y0, y1) in enumerate(((0, ys), (ys, im.height))):
        band = im.crop((0, y0, im.width, y1))
        band = band.crop((0, 0, band.width, _no_label(np.array(band)[:, :, 3])))
        band = band.crop((0, _no_label_top(np.array(band)[:, :, 3]), band.width, band.height))
        for c, (x0, x1) in enumerate(_split4(np.array(band)[:, :, 3], gap)):
            pad = 20
            box = band.crop((max(0, x0 - pad), 0, min(im.width, x1 + pad), band.height))
            out[r * 4 + c] = CUT.main_blob(box, blob_gap)
    return out


def _feet_x(im):
    a = np.array(im)[:, :, 3] > 128
    ys = np.nonzero(a.any(1))[0]
    lo = ys.max() - max(6, int(0.12 * (ys.max() - ys.min())))
    xs = np.nonzero(a[lo:].any(0))[0]
    return (xs.min() + xs.max()) / 2.0


def fit(raw, cw, ch, idle_h, ncolors=40):
    """Todas las poses a la MISMA escala (idle -> idle_h), pies abajo y anclados en la base; la pose que no cabe se encoge sola."""
    raw = {k: A.trim(v) for k, v in raw.items()}
    s = idle_h / raw["idle"].height
    out = {}
    for k, im in raw.items():
        m = min(1.0, (cw - 2) / (im.width * s), (ch - 1) / (im.height * s))
        fx = _feet_x(im)
        w, h = max(1, round(im.width * s * m)), max(1, round(im.height * s * m))
        sm = A.down(im, w, h)
        x0 = max(1, min(cw - w - 1, int(round(cw / 2 - fx * s * m))))
        cv = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        cv.alpha_composite(sm, (x0, ch - h))
        out[k] = cv
    print("  escala", round(s, 3))
    return A.quantize_set(out, ncolors)


TW, TH = 176, 184
VARIANTS = {"": ("test_a", "test_b", "test_c"), "_p2": ("test_a_p2", "test_b_p2", "test_c_p2"), "_p3": ("test_a_p3", "test_b_p3", "test_c_p3")}


def boss_poses(suffix):
    na, nb, nc = VARIANTS[suffix]
    a, b, c = _grid(na), _grid(nb), _grid(nc)
    raw = dict(idle=a[0], r1=a[1], r2=a[2], r3=a[3], pinw=a[4], pins=a[5], olew=a[7 if suffix == "_p3" else 6], oler=a[7],
               intro=b[0], tired=b[1], stun=b[2], channel=b[3], hurt=b[4], d1=b[5], d2=b[6], d3=b[7],
               fanw=c[0], fanr=c[1], splw=c[2], splr=c[3], reb_w=c[4], reb_r=c[5], brake=c[6], r4=c[7])
    return fit(raw, TW, TH, 150)


def boss_anims(P):
    xf = A.xf
    I = P["idle"]
    f = {}
    f["idle"] = [I, xf(I, sy=0.985), I, xf(I, sx=1.01, sy=0.99)]
    # rodar: la bola da vueltas (cuadros de giro) con rebote
    f["walk"] = [P["r4"], xf(P["r1"], dy=-3), xf(P["r2"], dy=-1), xf(P["r3"], dy=-3)]
    f["intro"] = [P["intro"], P["intro"], xf(P["intro"], sy=1.02), I]
    f["attack"] = f["attack_fan"] = [I, xf(P["fanw"], rot=-2), P["fanw"]]
    f["release"] = f["release_fan"] = [P["fanr"], xf(P["fanr"], dx=2), xf(P["fanr"], dy=1)]
    f["attack_pinball"] = [I, xf(P["pinw"], sy=0.97), P["pinw"], xf(P["pinw"], dx=-1)]
    f["release_pinball"] = [P["pins"], xf(P["pins"], dx=3), P["pins"]]
    f["attack_oleada"] = [I, xf(P["olew"], sy=0.97), P["olew"]]
    f["release_oleada"] = [P["oler"], xf(P["oler"], dx=-2), P["oler"], xf(P["oler"], dx=-1, sy=0.99)]
    f["attack_mitades"] = [I, xf(P["splw"], sx=0.98), P["splw"], xf(P["splw"], sx=1.02)]
    f["release_mitades"] = [P["splr"], xf(P["splr"], sx=1.03), P["splr"]]
    f["attack_rebotines"] = [I, xf(P["reb_w"], sy=0.97), P["reb_w"]]
    f["release_rebotines"] = [P["reb_r"], xf(P["reb_r"], dy=1), P["reb_r"]]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]  # aturdido: mareo (distinto del agotamiento)
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], sy=0.985), P["tired"], xf(P["tired"], sy=1.012)]  # agotado: jadea
    f["stun_in"] = [P["hurt"], P["stun"]]
    f["channel"] = [P["channel"], xf(P["channel"], sy=1.015), P["channel"], xf(P["channel"], sy=0.99)]
    f["hurt"] = [P["hurt"], P["hurt"], xf(P["hurt"], dx=-1)]
    f["brake"] = [P["brake"], xf(P["brake"], sy=0.98)]
    f["blink"] = [I, I]
    f["idle_stir"] = [xf(I, rot=-2), xf(I, rot=2), I]
    f["idle_impatient"] = [xf(I, dy=-2), I, xf(I, dy=-2), I]
    f["death"] = [P["hurt"], P["d1"], xf(P["d1"], dx=1), P["d2"], P["d3"], P["d3"]]
    return f


META = {
    "idle": (5.0, True), "walk": (11.0, True), "intro": (3.0, False), "attack": (12.0, False), "release": (14.0, False),
    "tired": (7.0, True), "recover": (7.0, True), "recover_in": (10.0, False), "stun_in": (12.0, False),
    "channel": (9.0, True), "hurt": (12.0, False), "death": (3.5, False), "brake": (12.0, False), "blink": (14.0, False),
    "idle_stir": (8.0, False), "idle_impatient": (8.0, False),
}
for _n in ("fan", "pinball", "oleada", "mitades", "rebotines"):
    META["attack_" + _n] = (12.0, False)
    META["release_" + _n] = (14.0, False)


def _tres(frames, sheet_file, sheet_res, cw, ch, cols, out_file):
    uniq, index = [], {}
    for lst in frames.values():
        for im in lst:
            k = im.tobytes()
            if k not in index:
                index[k] = len(uniq)
                uniq.append(im)
    rows = (len(uniq) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    for i, im in enumerate(uniq):
        sheet.alpha_composite(im, ((i % cols) * cw, (i // cols) * ch))
    sheet.save(sheet_file)
    L = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(uniq) + 2), "",
         f'[ext_resource type="Texture2D" path="{sheet_res}" id="1_sheet"]', ""]
    for i in range(len(uniq)):
        L += [f'[sub_resource type="AtlasTexture" id="f{i}"]', 'atlas = ExtResource("1_sheet")',
              f"region = Rect2({(i % cols) * cw}, {(i // cols) * ch}, {cw}, {ch})", ""]
    anim = []
    for n, lst in frames.items():
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("f%d")\n}' % index[im.tobytes()] for im in lst)
        sp, loop = META.get(n, (10.0, False))
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if loop else "false", n, sp))
    L += ["[resource]", "animations = [" + ", ".join(anim) + "]", ""]
    Path(out_file).write_text("\n".join(L))
    return len(uniq)


def write_boss(frames, suffix):
    DEST.mkdir(parents=True, exist_ok=True)
    n = _tres(frames, DEST / f"testiculo_primordial_sheet{suffix}.png", f"{RES}testiculo_primordial_sheet{suffix}.png", TW, TH, 6,
              DEST / f"testiculo_primordial_sprite_frames{suffix}.tres")
    print("testiculo", suffix or "_p1", n, "cuadros")


def build_boss():
    for suf in VARIANTS:
        write_boss(boss_anims(boss_poses(suf)), suf)
    for old in DEST.glob("testiculo_primordial_*_[0-9][0-9].png*"):
        old.unlink()  # cuadros sueltos del arte provisorio (40x60): ahora todo va en la hoja


# ------------------------------------------------------------------ mitades 96x96
HW = 96


def mitades_poses():
    g = _grid("mitades")
    raw = {}
    for side, base in (("a", 0), ("b", 4)):
        raw.update({f"{side}_ready": g[base], f"{side}_r1": g[base + 1], f"{side}_r2": g[base + 2], f"{side}_r3": g[base + 3]})
    # escala comun: la pose lista de la mitad A mide 84 px de alto
    s = 84.0 / A.trim(raw["a_ready"]).height
    out = {}
    for k, v in raw.items():
        v = A.trim(v)
        m = min(1.0, (HW - 2) / (v.width * s), (HW - 2) / (v.height * s))
        w, h = max(1, round(v.width * s * m)), max(1, round(v.height * s * m))
        cv = Image.new("RGBA", (HW, HW), (0, 0, 0, 0))
        cv.alpha_composite(A.down(v, w, h), ((HW - w) // 2, HW - h - (HW - 84) // 2))
        out[k] = cv
    print("  mitades escala", round(s, 3))
    return A.quantize_set(out, 32)


def build_mitades():
    P = mitades_poses()
    DEST.mkdir(parents=True, exist_ok=True)
    for side in ("a", "b"):
        sheet = Image.new("RGBA", (HW * 4, HW), (0, 0, 0, 0))
        for i, k in enumerate(("ready", "r1", "r2", "r3")):
            sheet.alpha_composite(P[f"{side}_{k}"], (i * HW, 0))
        sheet.save(DEST / f"testiculo_mitad_{side}_sheet.png")


# ------------------------------------------------------------------ rebotin 32x48
RDEST = ROOT / "assets/sprites/enemies/penelandia/rebotin"
RRES = "res://assets/sprites/enemies/penelandia/rebotin/"
RW_, RH_ = 32, 48


def rebotin_poses():
    g = _grid("rebotin", 30, 40)
    raw = dict(zip(("idle", "tr_a", "tr_b", "roll_a", "roll_b", "dizzy", "d1", "d2"), (g[i] for i in range(8))))
    raw = {k: A.trim(v) for k, v in raw.items()}
    s = 34.0 / raw["idle"].height
    out = {}
    for k, v in raw.items():
        m = min(1.0, 30.0 / (v.width * s), 47.0 / (v.height * s))
        w, h = max(1, round(v.width * s * m)), max(1, round(v.height * s * m))
        cv = Image.new("RGBA", (RW_, RH_), (0, 0, 0, 0))
        cv.alpha_composite(A.down(v, w, h), (max(0, (RW_ - w) // 2), RH_ - h))
        out[k] = cv
    print("  rebotin escala", round(s, 3))
    return A.quantize_set(out, 22)


def build_rebotin():
    P = rebotin_poses()
    xf = A.xf
    I = P["idle"]
    f = {"idle": [I, xf(I, sy=0.96)], "walk": [P["roll_a"], P["roll_b"]], "attack": [P["tr_a"], P["tr_b"]],
         "dizzy": [P["dizzy"], xf(P["dizzy"], rot=4), P["dizzy"], xf(P["dizzy"], rot=-4)],
         "hurt": [P["d1"], A.flash(P["d1"], 0.5)], "death": [P["d1"], P["d2"], P["d2"]]}
    speeds = {"idle": (4.0, True), "walk": (12.0, True), "attack": (16.0, True), "dizzy": (7.0, True), "hurt": (10.0, False), "death": (8.0, False)}
    RDEST.mkdir(parents=True, exist_ok=True)
    for old in RDEST.glob("rebotin_*"):
        old.unlink()
    res, anim = [], []
    for n, lst in f.items():
        fr = []
        for i, im in enumerate(lst):
            im.save(RDEST / f"rebotin_{n}_{i:02d}.png")
            rid = f"{n}{i}"
            res.append(f'[ext_resource type="Texture2D" path="{RRES}rebotin_{n}_{i:02d}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        sp, loop = speeds[n]
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
    (RDEST / "rebotin_sprite_frames.tres").write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(res) + "\n\n[resource]\nanimations = [" + ", ".join(anim) + "]\n")


# ------------------------------------------------------------------ hoja de contacto
def preview(dest):
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    BG = (58, 56, 84, 255)

    def sheet(items, cw, ch, cols, k):
        rows = (len(items) + cols - 1) // cols
        sh = Image.new("RGBA", (cols * cw * k, rows * ch * k), BG)
        for i, (_, im) in enumerate(items):
            big = im.resize((im.width * k, im.height * k), Image.NEAREST)
            sh.alpha_composite(big, ((i % cols) * cw * k + (cw * k - big.width) // 2, (i // cols) * ch * k + (ch * k - big.height)))
        return sh
    for suf in VARIANTS:
        tiles = [(k, im) for k, im in boss_poses(suf).items()]
        sheet(tiles, TW, TH, 8, 1).convert("RGB").save(dest / f"testiculo{suf}_poses_x1.png")
        sheet(tiles, TW, TH, 6, 2).convert("RGB").save(dest / f"testiculo{suf}_poses_x2.png")
    extra = [(k, im) for k, im in mitades_poses().items()] + [(k, im) for k, im in rebotin_poses().items()]
    sheet(extra, 96, 96, 8, 1).convert("RGB").save(dest / "mitades_rebotin_x1.png")
    sheet(extra, 96, 96, 8, 3).convert("RGB").save(dest / "mitades_rebotin_x3.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["boss", "mitades", "rebotin"]
        if "boss" in parts:
            build_boss()
        if "mitades" in parts:
            build_mitades()
        if "rebotin" in parts:
            build_rebotin()
    elif cmd == "preview":
        preview(args[0] if args else ".")
