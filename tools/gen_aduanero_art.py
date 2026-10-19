"""Arte DEFINITIVO de EL ADUANERO HORMONAL (jefe de la Aduana Interior, Perineo) y del MINI-FUNCIONARIO (esbirro) con Gemini.
Escribe en assets/sprites/enemies/perineo/aduanero/ y perineo/funcionario/ (carpetas de assets/data/enemy_art.json).

Uso: python3 tools/gen_aduanero_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_aduanero_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_aduanero_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/aduanero/:
  adu_a adu_b adu_c (sano) + _p2 y _p3 de cada una (dano visible) + funcionario      (10 llamadas; tope 14)
Referencia de diseno: tools/_intro_raw/aduanero_v2.png (caratula, fuera de git; ruta absoluta mas abajo).
Partes de build: aduanero (176x184 -> aduanero_sheet{,_p2,_p3}.png + aduanero_sprite_frames{,_p2,_p3}.tres)
                 funcionario (32x48 -> funcionario_*_NN.png + funcionario_sprite_frames.tres)
Densidad: 1 pixel de arte = 1 unidad de juego, como Ovaria / Testiculo / Sildenafil (reutiliza sus utilidades de recorte y ajuste).
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
RAW = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/aduanero")
GEM.RAW = RAW
T.RAW = RAW
COVER = Path("/home/nick/Escritorio/Proyectos/soul_knight/tools/_intro_raw/aduanero_v2.png")
DEST = ROOT / "assets/sprites/enemies/perineo/aduanero"
RES = "res://assets/sprites/enemies/perineo/aduanero/"
SDEST = ROOT / "assets/sprites/enemies/perineo/funcionario"
SRES = "res://assets/sprites/enemies/perineo/funcionario/"

# ------------------------------------------------------------------ prompts
_NOTEXT = (" ABSOLUTELY NO TEXT: never write letters, numbers, words, captions, pose names, labels or signs anywhere in the image "
           "(the clipboard paper shows only plain wavy lines, scribbles and a red check mark, never letters); "
           "the bottom of every cell is empty green.")
_ADU = (
    "THE BOSS 'El Aduanero Hormonal' (the Hormonal Customs Officer): a chubby egg-shaped orange BEAN-like bureaucrat with a round "
    "body, tiny purple shoes, a purple customs officer cap with a small yellow round badge, small round black eyes with stern "
    "eyebrows, a big brown handlebar MOUSTACHE, a light-blue NECKTIE, short stubby arms. In one hand he holds a wooden CLIPBOARD "
    "with a white paper (blue scribbled lines and a red check mark), in the other hand a big rubber STAMP with a round RED knob "
    "handle and a yellow and red base. Smug, officious, deadpan, a little bit menacing, humorous and satirical, family friendly. "
    "Palette: orange, purple, light blue, brown, red, yellow, white. Same character, same proportions, same colors and same "
    "design as the reference image, but redrawn with much more detail, richer shading and a premium look. "
)
_ORDER = (
    " All poses are the SAME character at the SAME scale and the same camera, full body visible, standing on the ground (feet at "
    "the bottom of the cell), a single big character per cell, no extra characters except the props named. Extra effects (stars, "
    "papers, sweat drops) stay very close to the body and inside the cell." + _NOTEXT
)
_DMG2 = (
    "It is the DAMAGED PHASE 2 of the SAME character as the reference sheet: same poses in the same order and positions, same design, "
    "but clearly battle-worn and stressed: the cap is crooked and dented, the moustache is disheveled with a few loose hairs, the "
    "necktie is loosened and askew, the clipboard paper is creased and torn at a corner, a crack in the red stamp knob, bags under "
    "the eyes, a sweat drop, narrowed angrier eyes, darker shadows. "
)
_DMG3 = (
    "It is the HEAVILY DAMAGED, ENRAGED PHASE 3 of the SAME character as the reference sheet: same poses in the same order, same "
    "design, but frazzled and furious: the cap is flopped over to one side with a big tear and a bent badge, the moustache is wildly "
    "messy and half-singed, the necktie torn short and twisted, the clipboard snapped with shredded papers flying, the red stamp "
    "knob snapped and taped, a plaster patch and a bruise on the body, a red flushed face, bloodshot wide eyes, steam puffs of rage. "
)
_POSES_A = (
    "Poses left to right, top row: (1) neutral IDLE standing, smug stern face, clipboard in the left hand, stamp held low in the "
    "right hand; (2) WALK frame 1: waddling forward to the right, left foot forward, body tilted a little; (3) WALK frame 2: "
    "passing pose, body bobbing slightly higher; (4) WALK frame 3: waddling, right foot forward, tilted the other way. Bottom row: "
    "(5) STAMP WIND-UP: leaning back, the right arm raised high with the big stamp above the head, eyes narrowed; (6) STAMP "
    "RELEASE: leaning forward, slamming the stamp down hard to the front, a burst of dust and small paper scraps, an impact star; "
    "(7) CLOSE-THE-WINDOWS WIND-UP: the clipboard tucked under the arm, one flat open palm raised in a stern STOP command gesture, "
    "the other arm pulled back, chest puffed; (8) CLOSE-THE-WINDOWS RELEASE: the arm chopping sharply sideways like closing a "
    "shutter, motion arc lines, pointing the way, a stern open-mouthed shout (no words)."
)
_POSES_B = (
    "Poses left to right, top row: (1) dramatic INTRO entrance: arriving majestically, chest puffed out, the stamp raised "
    "triumphantly high in one hand and the clipboard held proudly in the other, a smug grin under the moustache, a few small "
    "papers floating around; (2) EXHAUSTED: slumped and sagging forward, the cap sliding down, panting, the stamp dragging on the "
    "ground, the clipboard drooping, a sweat drop and a bored sigh cloud; (3) STUNNED and dizzy: tilted and wobbling, swirly spiral "
    "eyes, the cap spinning above the head, tiny stars circling and papers fluttering; (4) CHANNELING A HEALING: eyes closed, "
    "serene, the clipboard held up in both hands with a glowing golden aura and a big red check mark, tiny golden sparkles and "
    "plus signs rising. Bottom row: (5) flinching pose: tilted back, eyes squeezed shut, the mouth a gasp, the cap knocked "
    "sideways, a small spray of paper scraps; then a theatrical DEATH in 3 steps: (6) shaking, the cap flying off, papers bursting "
    "out all around, eyes spinning, the stamp falling; (7) melodramatic collapse: falling backwards with a hand on the forehead, "
    "the clipboard and the stamp flying, papers raining; (8) lying flat on his back deflated, X-shaped eyes, the cap over the face "
    "partly, the stamp broken beside him, a tiny white flag, a tiny ghost leaving."
)
_POSES_C = (
    "Poses left to right, top row: (1) GENERIC ATTACK WIND-UP: leaning back, the stamp raised, small papers gathering around, "
    "eyes narrowed; (2) GENERIC ATTACK RELEASE: leaning forward, flinging a fan of papers and stamp prints forward to the right "
    "with motion lines; (3) THROW-CHASING-STAMPS WIND-UP: both hands raised, each holding a small round red rubber stamp that glows, "
    "chest puffed, a mean grin; (4) THROW-CHASING-STAMPS RELEASE: both arms thrown forward, two round red stamps flying out to "
    "the right with long trails. Bottom row: (5) CHECK-DOCUMENTS WIND-UP: holding the clipboard up close in front of the face, "
    "one eyebrow raised, eyes scrutinizing, a pen in the other hand; (6) CHECK-DOCUMENTS RELEASE: the clipboard thrust forward, "
    "a finger pointing sharply at the viewer, a stern mouth wide open shouting (no words), exclamation-style motion lines; "
    "(7) CALL-THE-NEXT WIND-UP: one hand cupped beside the mouth shouting, the other holding the clipboard, leaning forward; "
    "(8) CALL-THE-NEXT RELEASE: one arm swept wide in a beckoning flick, a small puff of papers, motion arc lines, a smug smile."
)
_FUN = (
    "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses), the SAME tiny creature at the same scale in each cell. "
    "THE ENEMY 'Mini-funcionario' (the little clerk minion of the Customs Officer boss): a small chubby egg-shaped BEAN-like "
    "clerk, smaller and paler than the boss (light tan-orange body), with a little purple cap with a tiny yellow badge, two small "
    "round black eyes with tired eyebrows, a tiny light-blue necktie, tiny purple shoes, short stubby arms, holding a small rubber "
    "stamp with a red knob handle. Cute, bored and obedient, humorous. Palette: tan orange, purple, light blue, red, a touch of "
    "white. Same design family as the boss in the reference image. Poses left to right, top row: (1) idle standing, stamp held "
    "low; (2) walking frame, mid-step, tilted a little; (3) WARNING pose: standing still, the stamp raised high, eyes wide, "
    "glowing with a warm yellow aura; (4) STAMPING pose: leaning forward slamming the stamp down in front, a small impact star "
    "and dust. Bottom row: (5) flinching pose: flinching, eyes squeezed shut, the cap askew, a few paper scraps; (6) death part "
    "one: shaking, cap flying off, spinning eyes; (7) death part two: falling backwards, the stamp flying away, papers bursting; "
    "(8) death part three: lying flat, X eyes, a tiny puff, a small ghost leaving."
) + _ORDER

PROMPTS = {}
for _k, _p in (("a", _POSES_A), ("b", _POSES_B), ("c", _POSES_C)):
    _lead = "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses)."
    PROMPTS[f"adu_{_k}"] = STYLE + _lead + _ORDER + _ADU + _p
    PROMPTS[f"adu_{_k}_p2"] = STYLE + _lead + " " + _DMG2 + _ORDER + _ADU + _p
    PROMPTS[f"adu_{_k}_p3"] = STYLE + _lead + " " + _DMG3 + _ORDER + _ADU + _p
_MATCH = (
    " STYLE MATCH (critical): keep EXACTLY the silhouette, proportions, face size, cap size and moustache of the reference "
    "sheet, the same chunky pixel size and 1-pixel dark outline, the same pose composition in every cell; only add the damage "
    "described. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
)
for _n in list(PROMPTS):
    if _n.endswith("_p2") or _n.endswith("_p3"):
        PROMPTS[_n] += _MATCH
for _n in ("adu_b", "adu_c"):
    PROMPTS[_n] += (
        " STYLE MATCH (critical): the reference sheet(s) show the approved look. Copy it EXACTLY: the same flat matte orange body "
        "with a lighter highlight, the same purple cap, the same small round eyes, the same chunky pixel size and 1-pixel dark "
        "outline. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
    )
PROMPTS["funcionario"] = STYLE + _FUN
GEN_ORDER = ["adu_a", "adu_b", "adu_c", "adu_a_p2", "adu_b_p2", "adu_c_p2", "adu_a_p3", "adu_b_p3", "adu_c_p3", "funcionario"]


def _cover(box):
    c = Image.open(COVER).convert("RGB").crop(box)
    return c.resize((c.width * 2, c.height * 2), Image.NEAREST)


def gen(names):
    boss_ref = _cover((510, 205, 900, 545))
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n == "adu_a":
            refs = [boss_ref]
        elif n in ("adu_b", "adu_c"):
            refs = [boss_ref, Image.open(RAW / "adu_a.png")]
            if n == "adu_b" and (RAW / "adu_c.png").exists():
                refs.append(Image.open(RAW / "adu_c.png"))
        elif n == "funcionario":
            refs = [boss_ref, Image.open(RAW / "adu_a.png")]
        else:
            base, suf = n.rsplit("_", 1)
            refs = [Image.open(RAW / f"{base}.png")]
            if base != "adu_a":
                refs.append(Image.open(RAW / f"adu_a_{suf}.png"))
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K", refs=refs)
        print("LLAMADA a Gemini:", n)


# ------------------------------------------------------------------ jefe 176x184
TW, TH = T.TW, T.TH


def _sin_rotulo(im):
    """Quita un rotulo (texto que Gemini cuela bajo la pose) separado del cuerpo por un hueco vacio: corta la ultima franja corta."""
    al = np.array(im)[:, :, 3] > 128
    rows = al.any(1)
    ys = np.nonzero(rows)[0]
    runs, st = [], ys[0]
    for a, b in zip(ys[:-1], ys[1:]):
        if b - a > 14:
            runs.append((st, a))
            st = b
    runs.append((st, ys[-1]))
    while len(runs) > 1 and (runs[-1][1] - runs[-1][0]) < 0.22 * (runs[-1][1] - runs[0][0]):
        runs.pop()
        im = im.crop((0, 0, im.width, runs[-1][1] + 1))
    # rotulo ARRIBA (a veces Gemini lo pone sobre la pose): franja baja y muy ancha, separada del cuerpo
    while len(runs) > 1:
        y0, y1 = runs[0]
        cols = np.nonzero(al[y0:y1 + 1].any(0))[0]
        wide = (cols.max() - cols.min() + 1) > 2.5 * (y1 - y0 + 1)
        if not (wide and (y1 - y0) < 0.08 * (runs[-1][1] - y0)):
            break
        runs.pop(0)
        im = im.crop((0, runs[0][0], im.width, im.height))
        runs = [(a - runs[0][0], b - runs[0][0]) for a, b in runs]
        al = np.array(im)[:, :, 3] > 128
    return _sin_astillas(im)


def _sin_astillas(im):
    """Borra pedazos chicos pegados al borde izq/der de la celda (restos de la pose vecina al cortar la hoja)."""
    from collections import deque
    a = np.array(im)
    al = a[:, :, 3] > 128
    h, w = al.shape
    total = int(al.sum())
    seen = np.zeros_like(al)
    for y0 in range(h):
        for x0 in (0, w - 1):
            if not al[y0, x0] or seen[y0, x0]:
                continue
            comp, q = [], deque([(y0, x0)])
            seen[y0, x0] = True
            while q:
                y, x = q.popleft()
                comp.append((y, x))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        yy, xx = y + dy, x + dx
                        if 0 <= yy < h and 0 <= xx < w and al[yy, xx] and not seen[yy, xx]:
                            seen[yy, xx] = True
                            q.append((yy, xx))
            if len(comp) < 0.03 * total:
                for y, x in comp:
                    a[y, x, 3] = 0
    return Image.fromarray(a, "RGBA")


def _grid(name, gap=40, blob_gap=60):
    return {k: _sin_rotulo(v) for k, v in T._grid(name, gap, blob_gap).items()}


VARIANTS = {"": ("adu_a", "adu_b", "adu_c"), "_p2": ("adu_a_p2", "adu_b_p2", "adu_c_p2"), "_p3": ("adu_a_p3", "adu_b_p3", "adu_c_p3")}


def boss_poses(suffix):
    na, nb, nc = VARIANTS[suffix]
    a, b, c = _grid(na), _grid(nb), _grid(nc)
    raw = dict(idle=a[0], w1=a[1], w2=a[2], w3=a[3], selw=a[4], selr=a[5], venw=a[6], venr=a[7],
               intro=b[0], tired=b[1], stun=b[2], channel=b[3], hurt=b[4], x1=b[5], x2=b[6], x3=b[7],
               fanw=c[0], fanr=c[1], perw=c[2], perr=c[3], docw=c[4], docr=c[5], llaw=c[6], llar=c[7])
    return T.fit(raw, TW, TH, 150)


def boss_anims(P):
    xf = A.xf
    I = P["idle"]
    f = {}
    f["idle"] = [I, xf(I, sy=0.985), I, xf(I, sx=1.01, sy=0.99)]
    f["walk"] = [P["w1"], xf(P["w2"], dy=-1), P["w3"], xf(P["w2"], dy=-1)]
    f["intro"] = [P["intro"], P["intro"], xf(P["intro"], sy=1.02), I]
    f["attack"] = f["attack_fan"] = [I, xf(P["fanw"], rot=-2), P["fanw"]]
    f["release"] = f["release_fan"] = [P["fanr"], xf(P["fanr"], dx=2), xf(P["fanr"], dy=1)]
    # sellos sueltos / ventanillas / aduana / persigue / documentos / llamar
    f["attack_sellos"] = [I, xf(P["selw"], sy=0.98), P["selw"], xf(P["selw"], dy=-1)]
    f["release_sellos"] = [P["selr"], xf(P["selr"], dy=1, sy=0.98), P["selr"]]
    f["attack_ventanillas"] = [I, xf(P["venw"], sy=0.98), P["venw"]]
    f["release_ventanillas"] = [P["venr"], xf(P["venr"], dx=2), P["venr"], xf(P["venr"], dx=-1)]
    f["attack_aduana"] = [I, xf(P["venw"], sy=0.98), P["venw"]]
    f["release_aduana"] = [P["venr"], xf(P["venr"], dx=2), P["venr"]]
    f["attack_persigue"] = [I, xf(P["perw"], sy=0.98), P["perw"]]
    f["release_persigue"] = [P["perr"], xf(P["perr"], dx=2), P["perr"], xf(P["perr"], dx=1)]
    f["attack_documentos"] = [I, xf(P["docw"], sy=0.98), P["docw"], xf(P["docw"], dy=-1)]
    f["release_documentos"] = [P["docr"], xf(P["docr"], dx=2), P["docr"]]
    f["attack_llamar"] = [I, xf(P["llaw"], sy=0.98), P["llaw"]]
    f["release_llamar"] = [P["llar"], xf(P["llar"], dx=2), P["llar"]]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]  # aturdido: mareo (distinto del agotamiento)
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], sy=0.985), P["tired"], xf(P["tired"], dy=1, sy=0.99)]  # agotado: jadea
    f["stun_in"] = [P["hurt"], P["stun"]]
    f["channel"] = [P["channel"], xf(P["channel"], dy=-2), P["channel"], xf(P["channel"], dy=-1)]
    f["hurt"] = [P["hurt"], P["hurt"], xf(P["hurt"], dx=-1)]
    f["brake"] = [I, xf(I, sy=0.98)]
    f["blink"] = [I, I]
    f["idle_stir"] = [xf(I, rot=-2), xf(I, rot=2), I]
    f["idle_impatient"] = [xf(I, dy=-2), I, xf(I, dy=-2), I]
    f["death"] = [P["hurt"], P["x1"], xf(P["x1"], dx=1), P["x2"], xf(P["x2"], dx=-1), P["x3"], P["x3"]]
    return f


T.META.update({"idle": (4.0, True)})
for _n in ("sellos", "ventanillas", "aduana", "persigue", "documentos", "llamar"):
    T.META["attack_" + _n] = (12.0, False)
    T.META["release_" + _n] = (14.0, False)


def build_aduanero():
    DEST.mkdir(parents=True, exist_ok=True)
    for suf in VARIANTS:
        n = T._tres(boss_anims(boss_poses(suf)), DEST / f"aduanero_sheet{suf}.png", f"{RES}aduanero_sheet{suf}.png", TW, TH, 6,
                    DEST / f"aduanero_sprite_frames{suf}.tres")
        print("aduanero", suf or "_p1", n, "cuadros")
    for old in DEST.glob("aduanero_*_[0-9][0-9].png*"):
        old.unlink()  # cuadros sueltos del arte provisorio (40x60): ahora todo va en la hoja


# ------------------------------------------------------------------ funcionario 32x48
SW_, SH_ = 32, 48


def funcionario_poses():
    g = _grid("funcionario", 30, 40)
    raw = dict(zip(("idle", "walk", "aim", "stamp", "hurt", "d1", "d2", "d3"), (g[i] for i in range(8))))
    raw = {k: A.trim(v) for k, v in raw.items()}
    s = 40.0 / raw["idle"].height
    out = {}
    for k, v in raw.items():
        if k == "walk":  # Gemini lo dibuja mas alto que el reposo: misma altura de cuerpo
            s_k = 40.0 / v.height
        else:
            s_k = s
        m = min(1.0, 30.0 / (v.width * s_k), 47.0 / (v.height * s_k))
        fx = T._feet_x(v)
        w, h = max(1, round(v.width * s_k * m)), max(1, round(v.height * s_k * m))
        cv = Image.new("RGBA", (SW_, SH_), (0, 0, 0, 0))
        x0 = max(0, min(SW_ - w, int(round(SW_ / 2 - fx * s_k * m))))
        cv.alpha_composite(A.down(v, w, h), (x0, SH_ - h - 1))  # pies abajo (camina por el suelo)
        out[k] = cv
    print("  funcionario escala", round(s, 3))
    for k, im in out.items():  # la corbata azul se agrisa al reducir: se satura antes de cuantizar
        a = np.array(im).astype(float)
        m = (a[:, :, 2] > a[:, :, 0] + 8) & (a[:, :, 2] >= a[:, :, 1] - 10) & (a[:, :, 3] > 128)
        a[m, 0] *= 0.7
        a[m, 1] = np.minimum(255, a[m, 1] * 0.95)
        a[m, 2] = np.minimum(255, a[m, 2] * 1.25)
        out[k] = Image.fromarray(a.astype(np.uint8), "RGBA")
    return A.quantize_set(out, 40)


def build_funcionario():
    P = funcionario_poses()
    xf = A.xf
    I = P["idle"]
    f = {"idle": [I, xf(I, sy=0.98)], "walk": [P["walk"], I, xf(P["walk"], dy=-1), I],
         "attack": [P["aim"], xf(P["aim"], dx=1), P["aim"], xf(P["aim"], dx=-1)], "stamp": [P["stamp"], xf(P["stamp"], dy=1)],
         "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)], "death": [P["d1"], P["d2"], P["d3"], P["d3"]]}
    speeds = {"idle": (4.0, True), "walk": (8.0, True), "attack": (16.0, True), "stamp": (10.0, True), "hurt": (10.0, False), "death": (8.0, False)}
    SDEST.mkdir(parents=True, exist_ok=True)
    for old in SDEST.glob("funcionario_*"):
        old.unlink()
    res, anim = [], []
    for n, lst in f.items():
        fr = []
        for i, im in enumerate(lst):
            im.save(SDEST / f"funcionario_{n}_{i:02d}.png")
            rid = f"{n}{i}"
            res.append(f'[ext_resource type="Texture2D" path="{SRES}funcionario_{n}_{i:02d}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        sp, loop = speeds[n]
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
    (SDEST / "funcionario_sprite_frames.tres").write_text(
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
        sheet(tiles, TW, TH, 8, 1).convert("RGB").save(dest / f"aduanero{suf}_poses_x1.png")
        sheet(tiles, TW, TH, 6, 2).convert("RGB").save(dest / f"aduanero{suf}_poses_x2.png")
    sat = list(funcionario_poses().items())
    sheet(sat, SW_, SH_, 8, 1).convert("RGB").save(dest / "funcionario_x1.png")
    sheet(sat, SW_, SH_, 8, 4).convert("RGB").save(dest / "funcionario_x4.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["aduanero", "funcionario"]
        if "aduanero" in parts:
            build_aduanero()
        if "funcionario" in parts:
            build_funcionario()
    elif cmd == "preview":
        preview(args[0] if args else ".")
