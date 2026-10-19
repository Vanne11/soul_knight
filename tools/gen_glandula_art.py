"""Arte DEFINITIVO de LA GLANDULA CALLADA (jefa unica de La Prostata) y del SINTOMA (su esbirro) con Gemini.
Escribe en assets/sprites/enemies/prostata/glandula/ y prostata/sintoma/ (carpetas de assets/data/enemy_art.json).

Uso: python3 tools/gen_glandula_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_glandula_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_glandula_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/glandula/:
  gla_a gla_b gla_c (sano) + _p2 y _p3 de cada una (dano visible) + sintoma      (10 llamadas; tope 14)
Referencia de diseno: tools/_intro_raw/glandula_v2.png (caratula, fuera de git; ruta absoluta mas abajo).
Partes de build: glandula (176x184 -> glandula_sheet{,_p2,_p3}.png + glandula_sprite_frames{,_p2,_p3}.tres)
                 sintoma (32x48 -> sintoma_*_NN.png + sintoma_sprite_frames.tres)
Densidad: 1 pixel de arte = 1 unidad de juego. La jefa CRECE en la pelea (boss_glandula.gd, escala x1 / x1.22 / x1.48 sobre la
base del animador): el cuadro idle mide ~140 px (cuerpo ancho y redondo) para que el agrandado quede dentro de la sala.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_testiculo_art as T  # noqa: E402  (recorte por rejilla, ajuste de escala, escritor de .tres)
import arc2_gemini as GEM  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402
from arc2_gemini import STYLE  # noqa: E402

ROOT = GEM.ROOT
RAW = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/glandula")
GEM.RAW = RAW
T.RAW = RAW
COVER = Path("/home/nick/Escritorio/Proyectos/soul_knight/tools/_intro_raw/glandula_v2.png")
DEST = ROOT / "assets/sprites/enemies/prostata/glandula"
RES = "res://assets/sprites/enemies/prostata/glandula/"
SDEST = ROOT / "assets/sprites/enemies/prostata/sintoma"
SRES = "res://assets/sprites/enemies/prostata/sintoma/"

# ------------------------------------------------------------------ prompts
_NOTEXT = " ABSOLUTELY NO TEXT: no letters, no numbers, no digits, no captions, no labels, no pose names, no words anywhere in the image. "
_GLA = (
    "THE BOSS 'La Glandula Callada' (the Silent Gland), a prostate gland: a big plump round WALNUT-shaped body in dusty rosy "
    "pink-brown (salmon pink with warm brown shading), made of two lobes split by a vertical groove down the middle, with soft "
    "wrinkled texture and faint veins. A tired, sleepy FACE: two heavy-lidded tired eyes with big dark bags under them, cream "
    "sclera and dark half-hidden pupils, flat worried brows; the MOUTH is a small horizontal line SEWN SHUT with 5 dark vertical "
    "stitches. Two short stubby arms and two short stubby legs with dark shoes. On its side a small cream-white paper WAITING "
    "NUMBER TICKET with a red stripe and only abstract tiny marks (no readable digits) is stuck to the body. Silent, patient, "
    "exhausted, a bit sad and bureaucratic, humorous and dry, family friendly (it is about prostate checkups, never mocking illness). "
    "Palette: rosy pink, warm brown, cream, dark outline, a touch of peach and soft yellow. "
    "Same character, same proportions, same colors and same design as the reference image, but redrawn with much more detail, "
    "richer shading and a premium look, WITHOUT the waiting-room chair or the room (only the gland itself). "
)
_ORDER = (
    " All poses are the SAME character at the SAME scale and the same camera, full body visible, standing on its short legs (a "
    "small flat contact point with the ground, no cast shadow), a single big character per cell, no extra characters except the "
    "props named. Extra effects (rings, drops, arrows, sweat) stay very close to the body and inside the cell. Never draw text, "
    "letters or numbers. "
)
_DMG2 = (
    "It is the DAMAGED PHASE 2 of the SAME character as the reference sheet: same poses in the same order and positions, same "
    "design, but visibly more strained and swollen: a bit larger and rounder, thicker bulging purple-red veins, the stitches of "
    "the mouth pulled TAUT with the skin puckering around them, deeper darker eye bags, redder bloodshot tired eyes, patches of "
    "inflamed darker red-pink skin, a sweat drop, a small plaster patch, more tension. "
)
_DMG3 = (
    "It is the HEAVILY DAMAGED, ENRAGED PHASE 3 of the SAME character as the reference sheet: same poses in the same order, same "
    "design, but desperate and strained to the limit: noticeably bigger and swollen, many bulging purple veins, deep cracks of "
    "paler skin, large inflamed red patches, the stitches of the mouth straining with two stitches popped and a tiny dark gap "
    "showing, the mouth ABOUT TO OPEN, wide bloodshot eyes with tiny pupils and very dark bags, sweat drops, a plaster patch, "
    "steam puffs, a faint warm red aura. "
)
_POSES_A = (
    "Poses left to right, top row: (1) neutral IDLE: standing quietly, arms hanging, a tired look straight at the viewer, mouth "
    "sewn shut; (2) WALK frame 1: waddling forward to the right, leaning slightly, left leg forward; (3) WALK frame 2: passing "
    "step, body a little higher, legs together; (4) WALK frame 3: waddling, right leg forward, leaning the other way. Bottom row: "
    "(5) DRIP WIND-UP: trembling, shoulders hunched, a glistening yellow DROP forming and welling out from the bottom of the body "
    "and a few small yellow drops hanging; (6) DRIP RELEASE: leaning back, a spiral spray of round yellow drops spurting out "
    "to the right with motion lines; (7) PUSH WIND-UP: INFLATING, puffed up bigger like a balloon, eyes shut tight with effort, "
    "arms pressed to the sides, a peach-colored ring of light contracting around the body; (8) PUSH RELEASE: fully swollen at its "
    "biggest, eyes wide open, a big PRESSURE RING shockwave of peach colored chevron arrows expanding outward from the body, "
    "lines of force."
)
_POSES_B = (
    "Poses left to right, top row: (1) dramatic INTRO entrance: arriving slowly and heavily, a spotlight above, holding up its "
    "waiting ticket with one arm, tired but majestic, a puff of dust at the feet; (2) EXHAUSTED: slumped and deflated, sagging "
    "down, eyes half shut, panting, a sweat drop, arms dangling limp, the ticket drooping; (3) STUNNED and dizzy: tilted and "
    "wobbling, swirly spiral eyes, tiny stars circling the top of the body, legs crossed unsteadily; (4) CHANNELING A HEALING: "
    "eyes closed, serene, arms raised, a warm soft pink-gold aura, tiny plus signs and sparkles rising, a faint contented line in "
    "the stitched mouth. Bottom row: (5) flinching pose: flinching, tilted back, eyes squeezed shut, a dent in one lobe, a small "
    "spray of sparks; then a theatrical DEATH in 3 steps: (6) shaking, the stitches straining, sweat flying, cracked, eyes "
    "spinning; (7) swelling and glowing from inside, the groove down the middle splitting open with light, the stitches popping; "
    "(8) deflated and collapsed: a slumped flat sagging walnut shape with a long relieved sigh puff leaving the opened mouth, X "
    "eyes, the ticket on the floor, a tiny white flag, a tiny ghost leaving."
)
_POSES_C = (
    "Poses left to right, top row: (1) EDGE-SQUEEZE WIND-UP: hunched, both arms stretching out to the sides, the body swelling, "
    "four flat peach-colored pressure bands starting to appear at the edges of the cell, eyes narrowed; (2) EDGE-SQUEEZE RELEASE: "
    "arms thrown wide, body swollen and pulsing, flat peach bars pushing inwards from both sides with motion lines; (3) SLOW "
    "CHARGE WIND-UP: leaning forward, bracing low with the head down, legs dug in, steam puffing; (4) SLOW CHARGE: plowing "
    "forward to the right heavily like a bulldozer, leaning, dust clouds and slow motion lines behind. Bottom row: (5) FAN "
    "WIND-UP: the cheeks bulging, three yellow drops pressing against the surface of the body in a fan, trembling; (6) FAN "
    "RELEASE: leaning back, three yellow drops flying out to the right in a fan with a puff; (7) SUMMON SYMPTOMS WIND-UP: raising "
    "both arms, a small pale teal-blue droplet creature bulging out of the side of the body; (8) SUMMON SYMPTOMS RELEASE: "
    "arms wide, two or three small pale teal-blue droplet creatures with big worried eyes popping out of the body and flying "
    "out to the sides, small sparkles."
)
_SIN = (
    "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses), the SAME tiny creature at the same scale in each cell. "
    "THE ENEMY 'Sintoma' (the Symptom): a small round worried GOTITA, a droplet-shaped blob in pale muted teal-blue-gray with a "
    "lighter belly highlight and darker blue-gray shading, with two big round white eyes with small dark pupils and tiny worried "
    "brows, a tiny anxious mouth, and two tiny stubby feet, a small tuft on top. Restless, nervous, cute but a bit sickly, "
    "humorous. Same design as the reference images (the little blue-gray droplet creatures in the waiting room). Poses left to "
    "right, top row: (1) idle: standing, looking around nervously; (2) idle frame 2: bobbing, squashed slightly, wobbling; (3) "
    "WARNING pose: swelling up, glowing bright pale yellow, eyes wide, trembling, mouth open, pointed to the right; (4) SHOOT "
    "pose: leaning back, mouth open spitting a fan of three small yellow drops to the right. Bottom row: (5) flinching pose: "
    "flinching, eyes squeezed shut, squashed, a little spray; (6) death part one: cracked, spinning eyes, wobbling; (7) death "
    "part two: bursting into droplets, pieces flying; (8) death part three: a small puddle with a tiny ghost leaving."
) + _ORDER

PROMPTS = {}
for _k, _p in (("a", _POSES_A), ("b", _POSES_B), ("c", _POSES_C)):
    _lead = "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses)."
    PROMPTS[f"gla_{_k}"] = STYLE + _lead + _ORDER + _GLA + _p + _NOTEXT
    PROMPTS[f"gla_{_k}_p2"] = STYLE + _lead + " " + _DMG2 + _ORDER + _GLA + _p + _NOTEXT
    PROMPTS[f"gla_{_k}_p3"] = STYLE + _lead + " " + _DMG3 + _ORDER + _GLA + _p + _NOTEXT
_MATCH = (
    " STYLE MATCH (critical): keep EXACTLY the silhouette, proportions, face size, stubby limbs and walnut shape of the reference "
    "sheet, the same chunky pixel size and 1-pixel dark outline, the same pose composition in every cell; only add the damage "
    "described. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
)
for _n in list(PROMPTS):
    if _n.endswith("_p2") or _n.endswith("_p3"):
        PROMPTS[_n] += _MATCH
for _n in ("gla_b", "gla_c"):
    PROMPTS[_n] += (
        " STYLE MATCH (critical): the reference sheet(s) show the approved look. Copy it EXACTLY: the same flat matte rosy "
        "pink-brown walnut body, the same sewn mouth, the same tired eyes with dark bags, the same chunky pixel size and 1-pixel "
        "dark outline. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
    )
PROMPTS["gla_c"] += (
    " IMPORTANT: use EXACTLY the body of the reference sheets: the deep vertical groove splitting the walnut into two lobes, the "
    "same sleepy eyes, the mouth sewn with the same 5 thick stitches, the same stubby limbs. The body surface is a MATTE heavily wrinkled brain-like walnut texture with many pale peach wrinkle strokes and dark brown crease lines (never smooth, never glossy, no big white specular blobs), the eyes have thick dark bags, the thick brows are flat. NO ground shadow ellipse under the "
    "feet (flat green all around), no flat translucent overlay squares in the corners."
)
PROMPTS["sintoma"] = STYLE + _SIN + _NOTEXT + " The bottom of every cell is empty green."
GEN_ORDER = ["gla_a", "gla_b", "gla_c", "gla_a_p2", "gla_b_p2", "gla_c_p2", "gla_a_p3", "gla_b_p3", "gla_c_p3", "sintoma"]


def _cover(box):
    c = Image.open(COVER).convert("RGB").crop(box)
    return c.resize((c.width * 2, c.height * 2), Image.NEAREST)


def gen(names):
    boss_ref = _cover((440, 50, 920, 500))
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n == "gla_a":
            refs = [boss_ref]
        elif n in ("gla_b", "gla_c"):
            refs = [boss_ref, Image.open(RAW / "gla_a.png")]
            if n == "gla_c":
                refs = [Image.open(RAW / "gla_a.png"), Image.open(RAW / "gla_b.png")]
            if n == "gla_b" and (RAW / "gla_c.png").exists():
                refs.append(Image.open(RAW / "gla_c.png"))
            if n == "gla_c" and (RAW / "gla_b.png").exists():
                refs.append(Image.open(RAW / "gla_b.png"))
        elif n == "sintoma":
            refs = [_cover((255, 365, 445, 565)), _cover((1055, 270, 1240, 485)), boss_ref]
        else:
            base, suf = n.rsplit("_", 1)
            refs = [Image.open(RAW / f"{base}.png")]
            if base != "gla_a":
                refs.append(Image.open(RAW / f"gla_a_{suf}.png"))
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K", refs=refs)
        print("LLAMADA a Gemini:", n)


# ------------------------------------------------------------------ jefa 176x184
TW, TH = T.TW, T.TH
VARIANTS = {"": ("gla_a", "gla_b", "gla_c"), "_p2": ("gla_a_p2", "gla_b_p2", "gla_c_p2"), "_p3": ("gla_a_p3", "gla_b_p3", "gla_c_p3")}


def clean(im, gap):
    """Deja solo la figura: borra los pedazos sueltos (rotulos, barras, esquinas de efecto) a mas de `gap` px del cuerpo mayor."""
    from collections import deque
    from PIL import ImageFilter
    a = np.array(im.convert("RGBA"))
    m = a[:, :, 3] > 128
    K = 3  # etiquetado en baja resolucion
    h, w = m.shape
    sm = np.zeros(((h + K - 1) // K, (w + K - 1) // K), bool)
    for y in range(sm.shape[0]):
        for x in range(sm.shape[1]):
            sm[y, x] = m[y * K:(y + 1) * K, x * K:(x + 1) * K].any()
    lab = np.zeros(sm.shape, int)
    n = 0
    sizes = {}
    for y0, x0 in zip(*np.nonzero(sm)):
        if lab[y0, x0]:
            continue
        n += 1
        lab[y0, x0] = n
        q = deque([(y0, x0)])
        c = 0
        while q:
            y, x = q.popleft()
            c += 1
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < sm.shape[0] and 0 <= xx < sm.shape[1] and sm[yy, xx] and not lab[yy, xx]:
                        lab[yy, xx] = n
                        q.append((yy, xx))
        sizes[n] = c
    if n <= 1:
        return im
    big = max(sizes, key=sizes.get)
    k = max(3, (2 * (gap // K) + 1) | 1)
    main = Image.fromarray(((lab == big) * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(k))
    near = np.array(main) > 0
    keep_lab = {i for i in range(1, n + 1) if (near & (lab == i)).any()}
    for i in list(keep_lab):  # rectangulos macizos (barras de efecto) fuera
        if i == big:
            continue
        ys, xs = np.nonzero(lab == i)
        if len(ys) > 25 and len(ys) / ((np.ptp(ys) + 1) * (np.ptp(xs) + 1)) > 0.85 and max(np.ptp(ys), np.ptp(xs)) > 8:
            keep_lab.discard(i)
    keep_sm = np.isin(lab, list(keep_lab))
    keep = np.kron(keep_sm, np.ones((K, K), bool))[:h, :w]
    a[~keep] = 0
    return Image.fromarray(a, "RGBA")


def boss_poses(suffix):
    na, nb, nc = VARIANTS[suffix]
    a, b, c = T._grid(na), T._grid(nb), T._grid(nc)
    raw = dict(idle=a[0], w1=a[1], w2=a[2], w3=a[3], dripw=a[4], dripr=a[5], pushw=a[6], pushr=a[7],
               intro=b[0], tired=b[1], stun=b[2], channel=b[3], hurt=b[4], x1=b[5], x2=b[6], x3=b[7],
               edgew=c[0], edger=c[1], chw=c[2], chr=c[3], fanw=c[4], fanr=c[5], sumw=c[6], sumr=c[7])
    if suffix:
        raw["intro"] = raw["idle"]  # la entrada solo se ve en la fase 1 (el foco rojo del arte danado no sirve)
    raw = {k: clean(v, 3 if k in ("edgew", "edger") else 28) for k, v in raw.items()}
    return T.fit(raw, TW, TH, 140)


def boss_anims(P):
    xf = A.xf
    I = P["idle"]
    f = {}
    f["idle"] = [I, xf(I, sy=0.985), I, xf(I, sx=1.01, sy=0.99)]  # respira, pesada
    f["walk"] = [P["w1"], xf(P["w2"], dy=-1), P["w3"], xf(P["w2"], dy=-1)]
    f["intro"] = [P["intro"], P["intro"], xf(P["intro"], sy=1.02), I]
    f["attack"] = f["attack_fan"] = [I, xf(P["fanw"], rot=-2), P["fanw"]]
    f["release"] = f["release_fan"] = [P["fanr"], xf(P["fanr"], dx=2), xf(P["fanr"], dy=1)]
    f["attack_goteo"] = [I, xf(P["dripw"], sx=0.99), P["dripw"], xf(P["dripw"], dy=1)]
    f["release_goteo"] = [P["dripr"], xf(P["dripr"], dx=2), P["dripr"], xf(P["dripr"], dx=1)]
    f["attack_empuje"] = [I, xf(P["pushw"], sx=0.96, sy=0.96), P["pushw"], xf(P["pushw"], sx=1.01, sy=1.01)]  # se hincha
    f["release_empuje"] = [P["pushr"], xf(P["pushr"], sx=1.02, sy=1.02), P["pushr"]]
    f["attack_borde"] = [I, xf(P["edgew"], sy=0.98), P["edgew"]]
    f["release_borde"] = [P["edger"], xf(P["edger"], sx=1.02), P["edger"], xf(P["edger"], sx=0.99)]
    f["attack_sintomas"] = [I, xf(P["sumw"], dy=1), P["sumw"]]
    f["release_sintomas"] = [P["sumr"], xf(P["sumr"], dy=-1), P["sumr"]]
    f["attack_embestida"] = [I, xf(P["chw"], sy=0.97), P["chw"], xf(P["chw"], dx=-1)]
    f["charge"] = [P["chr"], xf(P["chr"], dx=2), P["chr"]]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]  # aturdida: mareo (distinto del agotamiento)
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], dy=1), P["tired"], xf(P["tired"], dy=2, sy=0.99)]  # agotada: jadea y se hunde
    f["stun_in"] = [P["hurt"], P["stun"]]
    f["channel"] = [P["channel"], xf(P["channel"], dy=-1), P["channel"], xf(P["channel"], sy=1.012)]
    f["hurt"] = [P["hurt"], P["hurt"], xf(P["hurt"], dx=-1)]
    f["brake"] = [P["chw"], xf(P["chw"], sy=0.98)]
    f["blink"] = [I, I]
    f["idle_stir"] = [xf(I, rot=-2), xf(I, rot=2), I]
    f["idle_impatient"] = [xf(I, dy=-2), I, xf(I, dy=-2), I]  # tamborilea: espera su turno
    f["death"] = [P["hurt"], P["x1"], xf(P["x1"], dx=1), P["x2"], xf(P["x2"], dx=-1), P["x3"], P["x3"]]
    return f


T.META.update({"idle": (4.0, True)})
for _n in ("goteo", "empuje", "borde", "sintomas", "embestida"):
    T.META["attack_" + _n] = (12.0, False)
    T.META["release_" + _n] = (14.0, False)
T.META["charge"] = (12.0, True)


def build_glandula():
    DEST.mkdir(parents=True, exist_ok=True)
    for suf in VARIANTS:
        n = T._tres(boss_anims(boss_poses(suf)), DEST / f"glandula_sheet{suf}.png", f"{RES}glandula_sheet{suf}.png", TW, TH, 6,
                    DEST / f"glandula_sprite_frames{suf}.tres")
        print("glandula", suf or "_p1", n, "cuadros")
    for old in DEST.glob("glandula_*_[0-9][0-9].png*"):
        old.unlink()  # cuadros sueltos del arte provisorio (40x60): ahora todo va en la hoja


# ------------------------------------------------------------------ sintoma 32x48
SW_, SH_ = 32, 48


def sintoma_poses():
    g = T._grid("sintoma", 30, 40)
    raw = dict(zip(("idle", "idle2", "aviso", "shoot", "hurt", "d1", "d2", "d3"), (g[i] for i in range(8))))
    raw = {k: A.trim(v) for k, v in raw.items()}
    s = 34.0 / raw["idle"].height
    out = {}
    for k, v in raw.items():
        m = min(1.0, 30.0 / (v.width * s), 47.0 / (v.height * s))
        w, h = max(1, round(v.width * s * m)), max(1, round(v.height * s * m))
        cv = Image.new("RGBA", (SW_, SH_), (0, 0, 0, 0))
        cv.alpha_composite(A.down(v, w, h), (max(0, (SW_ - w) // 2), SH_ - h - 2))
        out[k] = cv
    print("  sintoma escala", round(s, 3))
    return A.quantize_set(out, 30)


def build_sintoma():
    P = sintoma_poses()
    xf = A.xf
    I = P["idle"]
    f = {"idle": [I, P["idle2"]], "walk": [P["idle2"], I, xf(I, dy=-1), P["idle2"]],
         "attack": [P["aviso"], xf(P["aviso"], dx=1), P["aviso"], xf(P["aviso"], dx=-1)], "shoot": [P["shoot"], xf(P["shoot"], dx=-1)],
         "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)], "death": [P["d1"], P["d2"], P["d3"], P["d3"]]}
    speeds = {"idle": (4.0, True), "walk": (8.0, True), "attack": (16.0, True), "shoot": (10.0, False), "hurt": (10.0, False), "death": (8.0, False)}
    SDEST.mkdir(parents=True, exist_ok=True)
    for old in SDEST.glob("sintoma_*"):
        old.unlink()
    res, anim = [], []
    for n, lst in f.items():
        fr = []
        for i, im in enumerate(lst):
            im.save(SDEST / f"sintoma_{n}_{i:02d}.png")
            rid = f"{n}{i}"
            res.append(f'[ext_resource type="Texture2D" path="{SRES}sintoma_{n}_{i:02d}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        sp, loop = speeds[n]
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
    (SDEST / "sintoma_sprite_frames.tres").write_text(
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
        tiles = list(boss_poses(suf).items())
        sheet(tiles, TW, TH, 8, 1).convert("RGB").save(dest / f"glandula{suf}_poses_x1.png")
        sheet(tiles, TW, TH, 6, 2).convert("RGB").save(dest / f"glandula{suf}_poses_x2.png")
        sheet(tiles, TW, TH, 4, 3).convert("RGB").save(dest / f"glandula{suf}_poses_x3.png")
    sat = list(sintoma_poses().items())
    sheet(sat, SW_, SH_, 8, 1).convert("RGB").save(dest / "sintoma_x1.png")
    sheet(sat, SW_, SH_, 8, 3).convert("RGB").save(dest / "sintoma_x3.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["glandula", "sintoma"]
        if "glandula" in parts:
            build_glandula()
        if "sintoma" in parts:
            build_sintoma()
    elif cmd == "preview":
        preview(args[0] if args else ".")
