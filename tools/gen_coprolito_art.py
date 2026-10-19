"""Arte DEFINITIVO de EL COPROLITO (jefe de LA PUERTA TRASERA, reino secreto del Perineo) y de su esbirro, el GUIJARRO, con Gemini.
Escribe en assets/sprites/enemies/puerta_trasera/coprolito/ y puerta_trasera/guijarro/ (carpetas de assets/data/enemy_art.json).
Mismo metodo que gen_aduanero_art.py / gen_regla_art.py (176x184, idle ~150 px, contorno oscuro, _p2/_p3 con dano creciente).

Uso: python3 tools/gen_coprolito_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_coprolito_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_coprolito_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/coprolito/
(respaldo en ~/Vídeos/Rogue Reproductive/arte_gemini_original/coprolito/):
  copro_a copro_b copro_c (sano) + _p2 y _p3 de cada una (dano visible) + guijarro      (10 llamadas; tope del encargo: 16 con la caratula)
Partes de build: coprolito (176x184 -> coprolito_sheet{,_p2,_p3}.png + coprolito_sprite_frames{,_p2,_p3}.tres)
                 guijarro (32x48 -> guijarro_*_NN.png + guijarro_sprite_frames.tres)
El diseno es discreto y de dibujo animado: un fosil de roca enrollado (espiral), nada realista ni asqueroso.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_aduanero_art as AD  # noqa: E402  (_sin_rotulo / _sin_astillas: Gemini pone rotulos aunque se prohiba)
import gen_testiculo_art as T  # noqa: E402
import arc2_gemini as GEM  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402
from arc2_gemini import STYLE  # noqa: E402

ROOT = GEM.ROOT
RAW = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/coprolito")
GEM.RAW = RAW  # gen_aduanero_art fija las rutas del aduanero al importarse: se corrigen
T.RAW = RAW
DEST = ROOT / "assets/sprites/enemies/puerta_trasera/coprolito"
RES = "res://assets/sprites/enemies/puerta_trasera/coprolito/"
SDEST = ROOT / "assets/sprites/enemies/puerta_trasera/guijarro"
SRES = "res://assets/sprites/enemies/puerta_trasera/guijarro/"

# ------------------------------------------------------------------ prompts
_NOTEXT = (" ABSOLUTELY NO TEXT: never write letters, numbers, words, captions, pose names, labels or signs anywhere in the image; "
           "the bottom of every cell is empty green.")
_COP = (
    "THE BOSS 'El Coprolito' (The Coprolite): an ancient FOSSIL creature, a chubby coiled SWIRL-shaped petrified rock, like a "
    "soft-serve spiral of three stacked rounded coils tapering to a small curled tip on top, matte brown-grey stone with darker "
    "brown veins and cracks running through it, tiny ammonite spiral shells and a small fern-leaf imprint embedded in the stone "
    "surface, tired wise heavy-lidded OLD-MAN eyes, bushy eyebrows and a long beard made of grey-green moss, a small round "
    "golden MONOCLE over one eye, tiny stubby stone arms and short stubby stone legs, a gnarled wooden walking cane held in one "
    "hand. Solemn, ancient, pompous and ridiculous at the same time, deadpan, like a grumpy old museum professor made of rock; "
    "humorous and satirical, family friendly, cartoon style, simple and discreet: nothing gross, nothing realistic, no slime, "
    "no shine, it is just a petrified rock sculpture with a face. Palette: brown, grey-brown, beige, dark umber, moss green, "
    "a touch of gold. "
)
_ORDER = (
    " All poses are the SAME character at the SAME scale and the same camera, full body visible, standing on the ground (feet at "
    "the bottom of the cell), a single big character per cell, no extra characters except the props named. Extra effects (dust, "
    "pebbles, small cracks) stay very close to the body and inside the cell." + _NOTEXT
)
_DMG2 = (
    "It is the DAMAGED PHASE 2 of the SAME character as the reference sheet: same poses in the same order and positions, same "
    "design, but clearly battle-worn: a big diagonal crack across the body with a faint warm orange glow inside, a chunk broken "
    "off the top tip, the monocle cracked, the moss beard singed and thinner, a few small stone fragments floating around the "
    "body, darker shadows, narrowed angrier eyes. "
)
_DMG3 = (
    "It is the HEAVILY DAMAGED, ENRAGED PHASE 3 of the SAME character as the reference sheet: same poses in the same order, same "
    "design, but cracked apart and furious: the body split by many deep glowing orange cracks, whole slabs chipped away showing "
    "pale stone underneath, the top tip broken off, the monocle shattered, the moss beard wild and half burnt, the cane snapped "
    "in two, several stone fragments floating around the body, wide bloodshot angry eyes, dust puffs of rage. "
)
_POSES_A = (
    "Poses left to right, top row: (1) neutral IDLE standing, solemn deadpan face, cane planted on the ground in the right hand; "
    "(2) WALK frame 1: lumbering forward to the right, heavy and slow, left foot forward, body tilted a little; (3) WALK frame 2: "
    "passing pose, body bobbing slightly higher; (4) WALK frame 3: lumbering, right foot forward, tilted the other way. Bottom "
    "row: (5) EARTHQUAKE WIND-UP: crouching low and gathering strength, both fists and the cane raised high above the head, "
    "eyes narrowed; (6) EARTHQUAKE RELEASE: slamming the cane and both fists down hard on the ground, cracks radiating on the "
    "floor, rock dust bursting, an impact star; (7) FOSSIL-RAIN WIND-UP: leaning back, both arms thrown up to the sky, small "
    "rocks levitating above, a stern shout; (8) FOSSIL-RAIN RELEASE: arms swept forward and down, flinging a spray of small "
    "stone fragments and tiny ammonite shells forward to the right, motion lines."
)
_POSES_B = (
    "Poses left to right, top row: (1) dramatic INTRO entrance: arriving majestically, chest puffed out, the cane raised "
    "triumphantly, a proud solemn expression under the monocle, a few pebbles and dust floating around; (2) EXHAUSTED: slumped and "
    "sagging forward, the monocle sliding down, panting heavily, leaning on the cane, a sweat drop and a tired sigh cloud; (3) "
    "STUNNED and dizzy: tilted and wobbling, swirly spiral eyes, the monocle spinning, tiny stars circling and pebbles fluttering; "
    "(4) CHANNELING A HEALING: eyes closed, serene, both hands on the cane held up, a glowing warm golden aura, tiny golden "
    "sparkles and plus signs rising. Bottom row: (5) flinching pose: tilted back, eyes squeezed shut, the mouth a gasp, the "
    "monocle knocked sideways, a small spray of stone chips; then a theatrical DEATH in 3 steps: (6) shaking, the monocle flying "
    "off, cracks running across the body, eyes spinning, the cane falling; (7) melodramatic collapse: falling backwards with a "
    "hand on the forehead, the cane flying, stone fragments bursting out; (8) lying flat as a heap of broken rock pieces "
    "and a pile of dust, a few X-eyed face fragments visible, the monocle and the cane beside the pile, a tiny white flag, a "
    "tiny ghost leaving."
)
_POSES_C = (
    "Poses left to right, top row: (1) GENERIC ATTACK WIND-UP: leaning back, the cane raised, small pebbles gathering around, "
    "eyes narrowed; (2) GENERIC ATTACK RELEASE: leaning forward, flinging a fan of stone shards forward to the right with motion "
    "lines; (3) THE PLUG WIND-UP: straining with effort, both fists clenched, eyes squeezed shut, cheeks puffed, the whole body "
    "shaking and compressed, small pressure lines and dust around; (4) THE PLUG RELEASE: a big round boulder-like stone plug "
    "popping out and being flung to the front right, the body relaxed with a relieved face, motion lines. Bottom row: (5) CALL-THE-"
    "PEBBLES WIND-UP: one hand cupped beside the mouth shouting, the other hand holding the cane, leaning forward; (6) CALL-THE-"
    "PEBBLES RELEASE: the cane thumped on the ground, small cracks opening on the floor, a puff of dust, a smug solemn look; "
    "(7) CHARGE WIND-UP: lowering the body like a bull, the cane held back, a stern stare ahead, dust at the feet; (8) CHARGE "
    "RELEASE: rolling forward fast like a boulder in a rolling stance, motion trail lines and rock dust behind."
)
_GUI = (
    "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses), the SAME tiny creature at the same scale in each cell. "
    "THE ENEMY 'Guijarro' (the little pebble minion of the Coprolite boss): a small round PEBBLE-shaped stone creature, smaller and "
    "paler than the boss (light grey-brown stone), with a tiny ammonite spiral fossil on its body, two small round black eyes with "
    "grumpy eyebrows, a tiny moss tuft on top like hair, tiny stubby stone legs and arms. Cute, grumpy and obedient, humorous. "
    "Palette: grey-brown, beige, moss green, a touch of orange for the cracks. Same design family as the boss in the reference "
    "image. Poses left to right, top row: (1) idle standing; (2) walking frame, mid-step, tilted a little; (3) WARNING pose: standing "
    "still, trembling, eyes wide, cracks glowing with a warm orange aura; (4) BURST pose: the body cracking open in a small burst "
    "with four little stone chips flying outward in a cross, an impact star. Bottom row: (5) flinching pose: eyes squeezed shut, a "
    "few chips flying; (6) death part one: shaking, a crack across the body, spinning eyes; (7) death part two: breaking into "
    "two halves, chips bursting; (8) death part three: a tiny heap of pebbles, X eyes on one piece, a small puff, a small ghost "
    "leaving."
) + _ORDER

PROMPTS = {}
for _k, _p in (("a", _POSES_A), ("b", _POSES_B), ("c", _POSES_C)):
    _lead = "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses)."
    PROMPTS[f"copro_{_k}"] = STYLE + _lead + _ORDER + _COP + _p
    PROMPTS[f"copro_{_k}_p2"] = STYLE + _lead + " " + _DMG2 + _ORDER + _COP + _p
    PROMPTS[f"copro_{_k}_p3"] = STYLE + _lead + " " + _DMG3 + _ORDER + _COP + _p
_MATCH = (
    " STYLE MATCH (critical): keep EXACTLY the silhouette, proportions, face size, monocle size and beard of the reference "
    "sheet, the same chunky pixel size and 1-pixel dark outline, the same pose composition in every cell; only add the damage "
    "described. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
)
for _n in list(PROMPTS):
    if _n.endswith("_p2") or _n.endswith("_p3"):
        PROMPTS[_n] += _MATCH
for _n in ("copro_b", "copro_c"):
    PROMPTS[_n] += (
        " STYLE MATCH (critical): the reference sheet(s) show the approved look. Copy it EXACTLY: the same flat matte brown-grey "
        "stone with lighter highlights, the same moss beard, the same monocle, the same small tired eyes, the same chunky pixel size "
        "and 1-pixel dark outline. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
    )
PROMPTS["guijarro"] = STYLE + _GUI
GEN_ORDER = ["copro_a", "copro_b", "copro_c", "copro_a_p2", "copro_b_p2", "copro_c_p2", "copro_a_p3", "copro_b_p3", "copro_c_p3", "guijarro"]


def gen(names):
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n == "copro_a":
            refs = []
        elif n in ("copro_b", "copro_c"):
            refs = [Image.open(RAW / "copro_a.png")]
            if n == "copro_c" and (RAW / "copro_b.png").exists():
                refs.append(Image.open(RAW / "copro_b.png"))
        elif n == "guijarro":
            refs = [Image.open(RAW / "copro_a.png")]
        else:
            base, suf = n.rsplit("_", 1)
            refs = [Image.open(RAW / f"{base}.png")]
            if base != "copro_a":
                refs.append(Image.open(RAW / f"copro_a_{suf}.png"))
        print("LLAMADA a Gemini:", n, flush=True)
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K", refs=refs)


# ------------------------------------------------------------------ jefe 176x184
TW, TH = T.TW, T.TH


def _grid(name, gap=40, blob_gap=60):
    return {k: AD._sin_rotulo(v) for k, v in T._grid(name, gap, blob_gap).items()}


VARIANTS = {"": ("copro_a", "copro_b", "copro_c"), "_p2": ("copro_a_p2", "copro_b_p2", "copro_c_p2"),
            "_p3": ("copro_a_p3", "copro_b_p3", "copro_c_p3")}


def boss_poses(suffix):
    na, nb, nc = VARIANTS[suffix]
    a, b, c = _grid(na), _grid(nb), _grid(nc)
    raw = dict(idle=a[0], w1=a[1], w2=a[2], w3=a[3], temw=a[4], temr=a[5], fosw=a[6], fosr=a[7],
               intro=b[0], tired=b[1], stun=b[2], channel=b[3], hurt=b[4], x1=b[5], x2=b[6], x3=b[7],
               fanw=c[0], fanr=c[1], tapw=c[2], tapr=c[3], llaw=c[4], llar=c[5], chaw=c[6], char=c[7])
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
    f["attack_temblor"] = [I, xf(P["temw"], sy=0.98), P["temw"], xf(P["temw"], dy=-1)]
    f["release_temblor"] = [P["temr"], xf(P["temr"], dy=1, sy=0.98), P["temr"]]
    f["attack_fosiles"] = [I, xf(P["fosw"], sy=0.98), P["fosw"]]
    f["release_fosiles"] = [P["fosr"], xf(P["fosr"], dx=2), P["fosr"], xf(P["fosr"], dx=-1)]
    f["attack_tapon"] = [I, xf(P["tapw"], sy=0.98), P["tapw"], xf(P["tapw"], dx=1), P["tapw"]]
    f["release_tapon"] = [P["tapr"], xf(P["tapr"], dx=2), P["tapr"]]
    f["attack_llamar"] = [I, xf(P["llaw"], sy=0.98), P["llaw"]]
    f["release_llamar"] = [P["llar"], xf(P["llar"], dx=2), P["llar"]]
    f["attack_embestida"] = [I, xf(P["chaw"], sy=0.98), P["chaw"]]
    f["release_embestida"] = f["charge"] = [P["char"], xf(P["char"], dx=2), P["char"], xf(P["char"], dx=1)]
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
for _n in ("temblor", "fosiles", "tapon", "llamar", "embestida"):
    T.META["attack_" + _n] = (12.0, False)
    T.META["release_" + _n] = (14.0, False)


def build_coprolito():
    DEST.mkdir(parents=True, exist_ok=True)
    for suf in VARIANTS:
        n = T._tres(boss_anims(boss_poses(suf)), DEST / f"coprolito_sheet{suf}.png", f"{RES}coprolito_sheet{suf}.png", TW, TH, 6,
                    DEST / f"coprolito_sprite_frames{suf}.tres")
        print("coprolito", suf or "_p1", n, "cuadros")


# ------------------------------------------------------------------ guijarro 32x48
SW_, SH_ = 32, 48


def guijarro_poses():
    g = {k: AD._sin_rotulo(v) for k, v in T._grid("guijarro", 30, 40).items()}
    raw = dict(zip(("idle", "walk", "aim", "burst", "hurt", "d1", "d2", "d3"), (g[i] for i in range(8))))
    raw = {k: A.trim(v) for k, v in raw.items()}
    s = 40.0 / raw["idle"].height
    out = {}
    for k, v in raw.items():
        s_k = 40.0 / v.height if k == "walk" else s  # Gemini dibuja el paso mas alto que el reposo
        m = min(1.0, 30.0 / (v.width * s_k), 47.0 / (v.height * s_k))
        fx = T._feet_x(v)
        w, h = max(1, round(v.width * s_k * m)), max(1, round(v.height * s_k * m))
        cv = Image.new("RGBA", (SW_, SH_), (0, 0, 0, 0))
        x0 = max(0, min(SW_ - w, int(round(SW_ / 2 - fx * s_k * m))))
        cv.alpha_composite(A.down(v, w, h), (x0, SH_ - h - 1))  # pies abajo (camina por el suelo)
        out[k] = cv
    print("  guijarro escala", round(s, 3))
    return A.quantize_set(out, 40)


def build_guijarro():
    P = guijarro_poses()
    xf = A.xf
    I = P["idle"]
    f = {"idle": [I, xf(I, sy=0.98)], "walk": [P["walk"], I, xf(P["walk"], dy=-1), I],
         "attack": [P["aim"], xf(P["aim"], dx=1), P["aim"], xf(P["aim"], dx=-1)], "burst": [P["burst"], xf(P["burst"], dy=1)],
         "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)], "death": [P["d1"], P["d2"], P["d3"], P["d3"]]}
    speeds = {"idle": (4.0, True), "walk": (8.0, True), "attack": (16.0, True), "burst": (10.0, True), "hurt": (10.0, False), "death": (8.0, False)}
    SDEST.mkdir(parents=True, exist_ok=True)
    for old in SDEST.glob("guijarro_*"):
        old.unlink()
    res, anim = [], []
    for n, lst in f.items():
        fr = []
        for i, im in enumerate(lst):
            im.save(SDEST / f"guijarro_{n}_{i:02d}.png")
            rid = f"{n}{i}"
            res.append(f'[ext_resource type="Texture2D" path="{SRES}guijarro_{n}_{i:02d}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        sp, loop = speeds[n]
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
    (SDEST / "guijarro_sprite_frames.tres").write_text(
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
        if not all((RAW / f"{n}.png").exists() for n in VARIANTS[suf]):
            continue
        tiles = list(boss_poses(suf).items())
        sheet(tiles, TW, TH, 8, 1).convert("RGB").save(dest / f"coprolito{suf}_poses_x1.png")
        sheet(tiles, TW, TH, 6, 2).convert("RGB").save(dest / f"coprolito{suf}_poses_x2.png")
    if (RAW / "guijarro.png").exists():
        sat = list(guijarro_poses().items())
        sheet(sat, SW_, SH_, 8, 4).convert("RGB").save(dest / "guijarro_x4.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["coprolito", "guijarro"]
        if "coprolito" in parts:
            build_coprolito()
        if "guijarro" in parts:
            build_guijarro()
    elif cmd == "preview":
        preview(args[0] if args else ".")
