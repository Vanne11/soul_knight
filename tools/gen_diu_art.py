"""Arte DEFINITIVO del DIU COSMICO (jefe alternativo de Trompas de Falopio, Vulvania) y del SATELITE DE COBRE con Gemini.
Escribe en assets/sprites/enemies/vulvania/diu_cosmico/ y vulvania/satelite_cobre/ (carpetas de assets/data/enemy_art.json).

Uso: python3 tools/gen_diu_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_diu_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_diu_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/diu/:
  diu_a diu_b diu_c (sano) + _p2 y _p3 de cada una (dano visible) + satelite      (10 llamadas; tope 14)
Referencia de diseno: tools/_intro_raw/diu_cosmico_v2.png (caratula, fuera de git; ruta absoluta mas abajo).
Partes de build: diu (176x184 -> diu_cosmico_sheet{,_p2,_p3}.png + diu_cosmico_sprite_frames{,_p2,_p3}.tres)
                 satelite (32x48 -> satelite_cobre_*_NN.png + satelite_cobre_sprite_frames.tres)
Densidad: 1 pixel de arte = 1 unidad de juego, como Ovaria / Testiculo / Sildenafil (reutiliza sus utilidades de recorte y ajuste).
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_testiculo_art as T  # noqa: E402  (recorte por rejilla, ajuste de escala, escritor de .tres)
import arc2_gemini as GEM  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402
from arc2_gemini import STYLE  # noqa: E402

ROOT = GEM.ROOT
RAW = ROOT / ".claude/arte_fuente/diu"
GEM.RAW = RAW
T.RAW = RAW
COVER = Path("/home/nick/Escritorio/Proyectos/soul_knight/tools/_intro_raw/diu_cosmico_v2.png")
DEST = ROOT / "assets/sprites/enemies/vulvania/diu_cosmico"
RES = "res://assets/sprites/enemies/vulvania/diu_cosmico/"
SDEST = ROOT / "assets/sprites/enemies/vulvania/satelite_cobre"
SRES = "res://assets/sprites/enemies/vulvania/satelite_cobre/"

# ------------------------------------------------------------------ prompts
_DIU = (
    "THE BOSS 'El DIU Cosmico' (the Cosmic IUD), a copper IUD (intrauterine device, the real T-shaped copper contraceptive) "
    "floating in outer space: a tall straight vertical copper-ORANGE cylinder shaft with lighter orange highlight stripe and "
    "darker brown-orange shading, and on top two copper ARMS that spread out diagonally upward-left and upward-right like a wide "
    "letter T / Y with rounded ends; a round glossy pale VIOLET gem (a little crystal ball) sits at the junction where the arms meet "
    "the shaft. On the shaft is a SERIOUS DEADPAN FACE: two square white eyes with black pupils under flat stern brows, and a flat "
    "straight line mouth. At the bottom end of the shaft two thin white threads (the IUD removal strings) hang down and act as tiny "
    "legs. Smug, cold, patient, a little bit bureaucratic, humorous and satirical, family friendly. Palette: copper orange, brown, "
    "violet, white. Same character, same proportions, same colors and same design as the reference image, but redrawn with much "
    "more detail, richer shading and a premium look. "
)
_ORDER = (
    " All poses are the SAME character at the SAME scale and the same camera, full body visible, FLOATING in the air (no ground, "
    "no standing), a single big character per cell, no extra characters except the props named. Extra effects (rings, sparks, "
    "stars, sweat drops) stay very close to the body and inside the cell. Never draw text, letters or numbers. "
)
_DMG2 = (
    "It is the DAMAGED PHASE 2 of the SAME character as the reference sheet: same poses in the same order and positions, same design, "
    "but clearly battle-damaged: one of the two arms is bent at a kink, dents and scratches on the shaft, patches of blue-teal "
    "turquoise VERDIGRIS oxidation (more blue than green, never bright green) on the copper, a thin crack across the violet gem, "
    "a sweat drop, narrowed angrier stern eyes, one thread frayed, darker shadows. "
)
_DMG3 = (
    "It is the HEAVILY DAMAGED, ENRAGED PHASE 3 of the SAME character as the reference sheet: same poses in the same order, same design, "
    "but desperate and furious: both arms bent and drooping at sharp kinks with one tip chipped, large areas of blue-teal turquoise "
    "VERDIGRIS oxidation (more blue than green, never bright green) over the dull copper, a violet gem split by a big crack and "
    "glowing a hot magenta, deep dents, a cartoon plaster patch on the shaft, bloodshot wide angry eyes with tiny pupils, a gritted "
    "mouth, frayed tangled threads, a faint red-violet rage aura. "
)
_POSES_A = (
    "Poses left to right, top row: (1) neutral IDLE hovering, arms spread in a wide T, stern deadpan face, threads dangling; "
    "(2) DRIFT frame 1: floating forward leaning slightly to the right, arms swept back, threads trailing, small sparkle trail; "
    "(3) DRIFT frame 2: bobbing slightly higher, tilted the other way, the arms a little lower; (4) DRIFT frame 3: upright, "
    "arms raised a little higher, threads swinging the other way. Bottom row: (5) GENERIC ATTACK WIND-UP: leaning back, arms "
    "pulled back, the violet gem charging with a glow and small copper sparks gathering at the tips of the arms; (6) GENERIC "
    "ATTACK RELEASE: leaning forward, arms thrust forward, a fan of small copper and violet orbs flying out to the right with "
    "motion lines; (7) CHARGE WIND-UP: tilted nose-down like a missile aimed to the right, arms swept back along the body, gem "
    "glowing, squashed with a red-violet glow; (8) CHARGE: stretched long and fast, horizontal diving to the right as a streak, "
    "arms folded back, threads flying, long speed lines and a copper comet trail."
)
_POSES_B = (
    "Poses left to right, top row: (1) dramatic INTRO entrance: descending majestically from above, arms spread wide, the violet "
    "gem blazing with rays, eyes narrowed and smug, a few cosmic stars around; (2) EXHAUSTED: drooping and sagging, the arms hanging "
    "down limp like a wilted T, the gem dull, eyes half shut, panting, a sweat drop, threads limp; (3) STUNNED and dizzy: tilted "
    "and wobbling, swirly spiral eyes, tiny stars circling the gem, gem flickering; (4) CHANNELING A HEALING: eyes closed, serene, "
    "arms raised, a warm orange-gold and violet aura, tiny plus signs and sparkles rising, the gem pulsing with light. Bottom row: "
    "(5) HURT: flinching, tilted back, eyes squeezed shut, the mouth a gasp, a dent in the shaft, a small spray of sparks; then a "
    "theatrical DEATH in 3 steps: (6) shaking, cracked all over, sparks flying, the gem cracking, eyes spinning; (7) glowing "
    "white-hot from inside, the shaft bulging, the gem about to burst, cracks of light; (8) fallen apart: the shaft and the two arms "
    "broken into several separate copper pieces floating loosely around a small violet gem, X-shaped eyes on the biggest piece, a "
    "tiny white flag on a thread, a tiny ghost leaving."
)
_POSES_C = (
    "Poses left to right, top row: (1) ORBITS WIND-UP: arms raised, small copper and violet orbs appearing and circling around the "
    "body in a ring, the gem glowing; (2) ORBITS RELEASE: spinning mid-twirl, the ring of orbs flung outwards with motion lines, "
    "arms wide; (3) ARMS ATTACK WIND-UP: both arms stretched out perfectly horizontal like a straight bar, glowing copper-orange, "
    "gem charging; (4) ARMS ATTACK RELEASE: both arms horizontal and spinning, a circular motion blur, a spiral swoosh, sparks. "
    "Bottom row: (5) SUPERNOVA WIND-UP (the copper core): hunched and shaking, the whole body overheating glowing orange then "
    "white-hot, cracks of light, the gem blazing; (6) SUPERNOVA RELEASE: arms flung open wide, a huge bright burst ring of violet "
    "and copper light radiating from the body, eyes wide; (7) GRAVITY PULSE: arms opened wide, the gem blazing, concentric violet "
    "rings contracting inwards toward the body, small stars being pulled in; (8) SUMMON SATELLITES: arms thrown up, two tiny "
    "copper satellites with little solar-panel wings popping out of the gem, sparkles."
)
_SAT = (
    "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses), the SAME tiny creature at the same scale in each cell. "
    "THE ENEMY 'Satelite de cobre': a small cute grumpy copper satellite: a rounded copper-orange cylinder body with a little "
    "violet gem lens and a small antenna on top, ONE big googly eye with a dark pupil and an angry brow in the middle of the body, "
    "and two small square solar-panel wings, one on each side (copper-orange panels with darker brown grid lines and a violet "
    "tint). Hovering, no legs. Cute but aggressive and humorous. Palette: copper orange, brown, violet, a touch of white. "
    "Same design as the reference image (the small satellites around the big copper IUD). Poses left to right, top row: "
    "(1) idle hovering, wings level; (2) idle frame 2: tilted slightly, wings angled, as if orbiting; (3) AIMING: the eye glowing, "
    "body trembling, the gem glowing bright, red-violet glow, a thin aiming line to the right; (4) DIVE: stretched forward as a "
    "streak diving to the right, wings folded back, speed lines. Bottom row: (5) HURT: flinching, eye squeezed shut, wings "
    "bent, sparks; (6) death part one: cracked and smoking, spinning eye, a wing detaching; (7) death part two: bursting "
    "into copper pieces, the gem and the wings flying apart; (8) death part three: a tiny puff with few copper bits and a "
    "small ghost leaving."
) + _ORDER

PROMPTS = {}
for _k, _p in (("a", _POSES_A), ("b", _POSES_B), ("c", _POSES_C)):
    _lead = "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses)."
    PROMPTS[f"diu_{_k}"] = STYLE + _lead + _ORDER + _DIU + _p
    PROMPTS[f"diu_{_k}_p2"] = STYLE + _lead + " " + _DMG2 + _ORDER + _DIU + _p
    PROMPTS[f"diu_{_k}_p3"] = STYLE + _lead + " " + _DMG3 + _ORDER + _DIU + _p
_MATCH = (
    " STYLE MATCH (critical): keep EXACTLY the silhouette, proportions, face size, gem size and thin-thread legs of the reference "
    "sheet, the same chunky pixel size and 1-pixel dark outline, the same pose composition in every cell; only add the damage "
    "described. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
)
for _n in list(PROMPTS):
    if _n.endswith("_p2") or _n.endswith("_p3"):
        PROMPTS[_n] += _MATCH
for _n in ("diu_b", "diu_c"):
    PROMPTS[_n] += (
        " STYLE MATCH (critical): the reference sheet(s) show the approved look. Copy it EXACTLY: the same flat matte copper "
        "orange with a lighter highlight stripe, the same violet gem, the same square eyes, the same chunky pixel size and 1-pixel "
        "dark outline. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
    )
PROMPTS["satelite"] = STYLE + _SAT
GEN_ORDER = ["diu_a", "diu_b", "diu_c", "diu_a_p2", "diu_b_p2", "diu_c_p2", "diu_a_p3", "diu_b_p3", "diu_c_p3", "satelite"]


def _cover(box):
    c = Image.open(COVER).convert("RGB").crop(box)
    return c.resize((c.width * 2, c.height * 2), Image.NEAREST)


def gen(names):
    boss_ref = _cover((470, 15, 900, 515))
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n == "diu_a":
            refs = [boss_ref]
        elif n in ("diu_b", "diu_c"):
            refs = [boss_ref, Image.open(RAW / "diu_a.png")]
        elif n == "satelite":
            refs = [_cover((225, 290, 375, 415)), _cover((955, 50, 1110, 165)), boss_ref]
        else:
            base, suf = n.rsplit("_", 1)
            refs = [Image.open(RAW / f"{base}.png")]
            if base != "diu_a":
                refs.append(Image.open(RAW / f"diu_a_{suf}.png"))
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K", refs=refs)
        print("LLAMADA a Gemini:", n)


# ------------------------------------------------------------------ jefe 176x184
TW, TH = T.TW, T.TH
VARIANTS = {"": ("diu_a", "diu_b", "diu_c"), "_p2": ("diu_a_p2", "diu_b_p2", "diu_c_p2"), "_p3": ("diu_a_p3", "diu_b_p3", "diu_c_p3")}


def boss_poses(suffix):
    na, nb, nc = VARIANTS[suffix]
    a, b, c = T._grid(na), T._grid(nb), T._grid(nc)
    raw = dict(idle=a[0], d1=a[1], d2=a[2], d3=a[3], fanw=a[4], fanr=a[5], chw=a[6], chr=a[7],
               intro=b[0], tired=b[1], stun=b[2], channel=b[3], hurt=b[4], x1=b[5], x2=b[6], x3=b[7],
               orbw=c[0], orbr=c[1], armw=c[2], armr=c[3], novw=c[4], novr=c[5], grav=c[6], summ=c[7])
    return T.fit(raw, TW, TH, 150)


def boss_anims(P):
    xf = A.xf
    I = P["idle"]
    f = {}
    f["idle"] = [I, xf(I, dy=-2), xf(I, dy=-3, sy=1.005), xf(I, dy=-2)]  # flota
    f["walk"] = [P["d1"], xf(P["d2"], dy=-2), P["d3"], xf(P["d2"], dy=-2)]
    f["intro"] = [P["intro"], P["intro"], xf(P["intro"], sy=1.02), I]
    f["attack"] = f["attack_fan"] = [I, xf(P["fanw"], rot=-2), P["fanw"]]
    f["release"] = f["release_fan"] = [P["fanr"], xf(P["fanr"], dx=2), xf(P["fanr"], dy=1)]
    f["attack_hilos"] = [I, xf(P["grav"], sy=0.98), P["grav"]]
    f["release_hilos"] = [P["fanr"], xf(P["fanr"], dx=2), P["fanr"]]
    f["attack_meteoros"] = [I, xf(P["summ"], dy=1), P["summ"]]
    f["release_meteoros"] = [P["summ"], xf(P["summ"], dy=-2), P["summ"], xf(P["summ"], dy=-1)]
    f["attack_brazos"] = [I, xf(P["armw"], sx=0.99), P["armw"], xf(P["armw"], dy=-1)]
    f["release_brazos"] = [P["armr"], xf(P["armr"], rot=2), P["armr"], xf(P["armr"], rot=-2)]
    f["attack_orbitas"] = [I, xf(P["orbw"], sy=0.98), P["orbw"]]
    f["release_orbitas"] = [P["orbr"], xf(P["orbr"], rot=3), P["orbr"], xf(P["orbr"], rot=-3)]
    f["attack_supernova"] = [I, xf(P["novw"], sx=0.98), P["novw"], xf(P["novw"], sx=1.02, sy=0.99), xf(P["novw"], sx=0.98)]
    f["release_supernova"] = [P["novr"], xf(P["novr"], sx=1.03, sy=1.02), P["novr"]]
    f["attack_embestida"] = [I, xf(P["chw"], sy=0.97), P["chw"], xf(P["chw"], dx=-1)]
    f["charge"] = [P["chr"], xf(P["chr"], dx=3), P["chr"]]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]  # aturdido: mareo (distinto del agotamiento)
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], dy=1), P["tired"], xf(P["tired"], dy=2, sy=0.99)]  # agotado: jadea y se hunde
    f["stun_in"] = [P["hurt"], P["stun"]]
    f["channel"] = [P["channel"], xf(P["channel"], dy=-2), P["channel"], xf(P["channel"], dy=-1)]
    f["hurt"] = [P["hurt"], P["hurt"], xf(P["hurt"], dx=-1)]
    f["brake"] = [P["chw"], xf(P["chw"], sy=0.98)]
    f["blink"] = [I, I]
    f["idle_stir"] = [xf(I, rot=-2), xf(I, rot=2), I]
    f["idle_impatient"] = [xf(I, dy=-3), I, xf(I, dy=-3), I]
    f["death"] = [P["hurt"], P["x1"], xf(P["x1"], dx=1), P["x2"], xf(P["x2"], dx=-1), P["x3"], P["x3"]]
    return f


T.META.update({"idle": (4.0, True)})
for _n in ("hilos", "meteoros", "brazos", "orbitas", "supernova", "embestida"):
    T.META["attack_" + _n] = (12.0, False)
    T.META["release_" + _n] = (14.0, False)
T.META["charge"] = (14.0, True)


def build_diu():
    DEST.mkdir(parents=True, exist_ok=True)
    for suf in VARIANTS:
        n = T._tres(boss_anims(boss_poses(suf)), DEST / f"diu_cosmico_sheet{suf}.png", f"{RES}diu_cosmico_sheet{suf}.png", TW, TH, 6,
                    DEST / f"diu_cosmico_sprite_frames{suf}.tres")
        print("diu", suf or "_p1", n, "cuadros")
    for old in DEST.glob("diu_cosmico_*_[0-9][0-9].png*"):
        old.unlink()  # cuadros sueltos del arte provisorio (40x60): ahora todo va en la hoja


# ------------------------------------------------------------------ satelite 32x48
SW_, SH_ = 32, 48


def satelite_poses():
    g = T._grid("satelite", 30, 40)
    raw = dict(zip(("idle", "idle2", "aim", "dive", "hurt", "d1", "d2", "d3"), (g[i] for i in range(8))))
    raw = {k: A.trim(v) for k, v in raw.items()}
    s = 34.0 / raw["idle"].height
    out = {}
    for k, v in raw.items():
        m = min(1.0, 30.0 / (v.width * s), 47.0 / (v.height * s))
        w, h = max(1, round(v.width * s * m)), max(1, round(v.height * s * m))
        cv = Image.new("RGBA", (SW_, SH_), (0, 0, 0, 0))
        cv.alpha_composite(A.down(v, w, h), (max(0, (SW_ - w) // 2), (SH_ - h) // 2))  # centrado: orbita, no pisa el suelo
        out[k] = cv
    print("  satelite escala", round(s, 3))
    return A.quantize_set(out, 24)


def build_satelite():
    P = satelite_poses()
    xf = A.xf
    I = P["idle"]
    f = {"idle": [I, P["idle2"]], "walk": [P["idle2"], I, xf(I, dy=-1), P["idle2"]],
         "attack": [P["aim"], xf(P["aim"], dx=1), P["aim"], xf(P["aim"], dx=-1)], "dive": [P["dive"], xf(P["dive"], dx=2)],
         "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)], "death": [P["d1"], P["d2"], P["d3"], P["d3"]]}
    speeds = {"idle": (4.0, True), "walk": (8.0, True), "attack": (16.0, True), "dive": (12.0, True), "hurt": (10.0, False), "death": (8.0, False)}
    SDEST.mkdir(parents=True, exist_ok=True)
    for old in SDEST.glob("satelite_cobre_*"):
        old.unlink()
    res, anim = [], []
    for n, lst in f.items():
        fr = []
        for i, im in enumerate(lst):
            im.save(SDEST / f"satelite_cobre_{n}_{i:02d}.png")
            rid = f"{n}{i}"
            res.append(f'[ext_resource type="Texture2D" path="{SRES}satelite_cobre_{n}_{i:02d}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        sp, loop = speeds[n]
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
    (SDEST / "satelite_cobre_sprite_frames.tres").write_text(
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
        sheet(tiles, TW, TH, 8, 1).convert("RGB").save(dest / f"diu{suf}_poses_x1.png")
        sheet(tiles, TW, TH, 6, 2).convert("RGB").save(dest / f"diu{suf}_poses_x2.png")
    sat = list(satelite_poses().items())
    sheet(sat, SW_, SH_, 8, 1).convert("RGB").save(dest / "satelite_x1.png")
    sheet(sat, SW_, SH_, 8, 4).convert("RGB").save(dest / "satelite_x4.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["diu", "satelite"]
        if "diu" in parts:
            build_diu()
        if "satelite" in parts:
            build_satelite()
    elif cmd == "preview":
        preview(args[0] if args else ".")
