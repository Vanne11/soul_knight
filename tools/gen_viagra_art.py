"""Arte DEFINITIVO de DON VIAGRA (jefe alternativo del Conducto Deferente, Penelandia) y de la Pastillita azul con Gemini.
Escribe en assets/sprites/enemies/penelandia/don_viagra/ y penelandia/pastilla/ (carpetas de assets/data/enemy_art.json).

Uso: python3 tools/gen_viagra_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_viagra_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_viagra_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/viagra/:
  viagra_a viagra_b viagra_c (sano) + _p2 y _p3 de cada una (dano visible) + pastilla     (10 llamadas; tope 14)
Partes de build: don (176x184 -> don_viagra_sheet{,_p2,_p3}.png + don_viagra_sprite_frames{,_p2,_p3}.tres)
                 pastilla (32x48 -> pastilla_*_NN.png + pastilla_sprite_frames.tres)
SUBIDON: ademas de idle/walk trae idle_rush/walk_rush (medidor medio) e idle_max/walk_max (medidor al tope);
BossAnimator las elige leyendo boss._rush. Densidad: 1 pixel de arte = 1 unidad de juego, como Ovaria.
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
RAW = ROOT / ".claude/arte_fuente/viagra"
GEM.RAW = RAW
DEST = ROOT / "assets/sprites/enemies/penelandia/don_viagra"
RES = "res://assets/sprites/enemies/penelandia/don_viagra/"
OLD_BAK = RAW / "_idle_viejo.png"  # copia del sprite provisorio 80x120 (referencia de diseno)
CUT.cut_bg = PA.cut_bg

# ------------------------------------------------------------------ prompts
_DON = (
    "THE BOSS 'Don Viagra': a big glossy BLUE diamond-shaped (rhombus / lozenge) PILL, the classic little blue "
    "diamond pill, standing upright on two stubby legs with dark-blue boots. The diamond body IS head and torso "
    "at once: lighter sky-blue facets on the left, deeper royal-blue facets on the right, a vertical seam down "
    "the middle. A small black TOP HAT with a thin red band sits on the top tip. One eye is a white eye with a "
    "black pupil under a raised smug eyebrow, the other eye wears a golden MONOCLE. A little smug smirk line. "
    "Thin dark-blue noodle arms with little blue gloved hands. A vain, over-confident, never-tired "
    "gentleman-pill with four hours of stamina and zero sense of measure. Same character, same proportions, same "
    "colors and same design as the reference image(s), but redrawn with much more detail, richer shading and a "
    "premium look. No human anatomy, no genitals, family friendly cartoon humor. "
)
_ORDER = (
    " All poses are the SAME character at the SAME scale and the same camera, full body visible and grounded, "
    "feet at the bottom of each cell, a single big character per cell, no extra characters except the props named. "
    "Extra effects (sweat drops, sparkles, steam) stay very close to the body. "
)
_DMG2 = (
    "now clearly battle-damaged: a crack running across the diamond body, a chipped corner on the lower tip, a dented "
    "squashed top hat with a bent band, a cracked monocle, a sweat drop, angrier narrowed eyes, slightly darker "
    "shadows and a couple of scuffs on the boots. "
)
_DMG3 = (
    "HEAVILY DAMAGED and ENRAGED: big cracks across the diamond body with a chunk missing from one edge, the top hat "
    "crushed and torn with the band hanging, the monocle shattered, wide bloodshot furious eyes with big veins, "
    "gritted teeth, an angry red flush tinting the blue, a faint red rage aura and a cartoon plaster patch on the belly. "
)

PROMPTS = {
    "viagra_a": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses)." + _ORDER + _DON +
        "Poses left to right, top row: (1) neutral idle, smug, one hand tucked behind the back; (2) walking step, "
        "one boot forward, swaggering; (3) generic ATTACK WIND-UP, leaning back, one fist pulled back, gritted fierce "
        "face, a blue glint; (4) generic ATTACK RELEASE: lunging forward, a big punch thrown, motion lines. "
        "Bottom row: (5) RUSH WIND-UP: crouched low like a sprinter on the starting line, leaning forward, boot "
        "digging in, determined grin; (6) RUSH RELEASE: body stretched forward at full speed, horizontal, speed "
        "lines and a dust puff, hat flying back; (7) PILL-RAIN WIND-UP: both arms raised high holding a handful of "
        "tiny blue pills above the head, looking up; (8) PILL-RAIN RELEASE: arms flung upward and open, tiny blue "
        "pills flying up in the air, triumphant."
    ),
    "viagra_b": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses), the SAME character as the "
        "reference image (approved design), only the pose changes." + _ORDER + _DON +
        "Poses left to right, top row: (1) OVERDOSE WIND-UP: crouched deep, about to jump, knees bent, arms back, "
        "wide eyes; (2) OVERDOSE RELEASE: slamming down on both boots, a ground shockwave ring and tiny blue pills "
        "bursting out around him; (3) BLISTER WIND-UP: pulling a silver blister pack of blue pills out from behind "
        "his back, sly grin; (4) BLISTER RELEASE: holding the blister pack up open, one tiny blue pill popping out "
        "of it. Bottom row: (5) CHANNELING A HEALING SPELL: eyes closed, serene, hands joined in front, a blue "
        "glow with tiny sparkles; (6) HURT: flinching backwards, eyes squeezed, mouth "
        "open in an offended gasp, hat tilting; (7) EXHAUSTED: bent forward with hands on knees, panting, tongue "
        "out, big sweat drops, hat crooked, deflated; (8) STUNNED and dizzy, swirly spiral eyes, tiny stars "
        "circling above, arms limp, hat sliding off."
    ),
    "viagra_c": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses), the SAME character as the "
        "reference image (approved design), only the pose changes." + _ORDER + _DON +
        "Poses left to right, top row: (1) dramatic INTRO entrance, chin up, arms spread wide, triumphant, "
        "tipping the top hat with one hand, a sparkle on the monocle; (2) RUSH LEVEL 1 'getting hyped': a "
        "jittery, bouncy idle stance, a few sweat drops, slightly wider eyes, a nervous grin, small tremble lines; "
        "(3) RUSH LEVEL 2 'wired': a frantic sprinting stride, leaning forward, wide manic eyes, sweating, a flush "
        "of purple-red on the blue, speed lines; (4) RUSH LEVEL 3 'MAXED OUT': totally unhinged, hunched and "
        "vibrating, bulging red veiny eyes, a huge manic grin, a red-hot flush over the blue body, steam puffing "
        "from the hat, sweat flying, tremble lines. Bottom row, a theatrical DEATH in four steps: (5) clutching "
        "his chest, back of the hand on his forehead, dramatic faint, hat flying up; (6) falling backwards, "
        "off-balance, eyes closed; (7) fallen flat on his back, the whole diamond body tipped over and lying "
        "sideways on the ground like a fallen kite, stubby legs sticking out, X eyes, one arm limp, the top hat "
        "lying on the ground beside him (a completely NEW pose, do not copy any pose of the reference); (8) the same "
        "lying pose, deflated, a little white flag raised in one hand, a tiny ghost floating up."
    ),
    "viagra_a_p2": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). It is the DAMAGED PHASE 2 of the "
        "SAME character as the reference sheet: same poses in the same order and positions, same design, but " + _DMG2 +
        _ORDER + _DON + "Same eight poses as the reference: idle, walking step, attack wind-up, attack release, rush "
        "wind-up, rush release, pill-rain wind-up, pill-rain release."
    ),
    "viagra_a_p3": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). It is the PHASE 3 of the SAME "
        "character as the reference sheet: same poses in the same order and positions, same design, but " + _DMG3 +
        _ORDER + _DON + "Same eight poses as the reference: idle (panting with rage), walking step, attack wind-up, "
        "attack release, rush wind-up, rush release, pill-rain wind-up, pill-rain release."
    ),
    "viagra_b_p2": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). Two reference images: the FIRST is "
        "the healthy 'pose sheet B' of the character, the SECOND is the same character in his DAMAGED PHASE 2 look. "
        "Redraw EXACTLY the poses of the first reference (same order, same positions, same composition) but with the "
        "damaged look of the second reference: " + _DMG2 + _ORDER + _DON
    ),
    "viagra_b_p3": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). Two reference images: the FIRST is "
        "the character design to copy EXACTLY in its HEAVILY DAMAGED, ENRAGED PHASE 3 look (a plain diamond pill body "
        "that IS head and torso at once, NO human anatomy). The SECOND is a pose-layout reference of the same character "
        "in phase 2: redraw EXACTLY its 8 poses (same order, positions and composition) with the phase 3 design of the "
        "first reference, same proportions and same size: " + _DMG3 + _ORDER + _DON
    ),
    "viagra_c_p2": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). Two reference images: the FIRST is "
        "the character design to copy EXACTLY (same body, SAME small hat, SAME dark-blue gloved hands, same dark-blue "
        "legs and boots, same size) in his DAMAGED PHASE 2 look. The SECOND only shows the pose layout: redraw its 8 "
        "poses in the same order, positions and composition (intro tipping the hat, three rush levels getting more "
        "frantic and redder, then the four death steps ending with a white flag and a tiny ghost) using the design of the "
        "FIRST reference: " + _DMG2 + _ORDER + _DON
    ),
    "viagra_c_p3": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). Two reference images: the FIRST is "
        "the character design to copy EXACTLY (same body, SAME small hat, SAME dark-blue gloved hands, same dark-blue "
        "legs and boots, same size) in his HEAVILY DAMAGED PHASE 3 look. The SECOND only shows the pose layout: redraw "
        "its 8 poses in the same order, positions and composition (intro tipping the hat, three rush levels getting more "
        "frantic, then the four death steps ending with a white flag and a tiny ghost) using the design of the FIRST "
        "reference, with NO red glow or aura around him: " + _DMG3.replace("a faint red rage aura and ", "") + _ORDER + _DON
    ),
    "pastilla": (
        STYLE + "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses), the SAME tiny creature at the "
        "same scale in each cell." + _ORDER +
        "THE ENEMY 'Pastillita' (Little Pill): a small chubby glossy BLUE diamond-shaped pill (a tiny version of Don "
        "Viagra's body: lighter sky-blue facets on the left, royal-blue facets on the right, vertical seam), two "
        "small angry-cute eyes, a tiny mischievous grin, two stubby little feet and two tiny stubby arms. No hat, no "
        "monocle. Cute, mischievous and a bit dumb. Poses left to right, top row: (1) idle standing, bouncing "
        "slightly; (2) rolling-walk step A; (3) rolling-walk step B; (4) WARNING: dug into the ground, "
        "shaking, glowing bright cyan-white, eyes narrowed, about to launch. Bottom row: (5) ROLLING at full speed: "
        "curled up and tilted like a spinning pill, with speed lines; (6) hurt, flinching with a flattened body; "
        "(7) death part one: cracked in half with fragments flying; (8) death part two: a little pile of blue "
        "powder and pill shards with a tiny ghost leaving."
    ),
}
GEN_ORDER = ["viagra_a", "viagra_b", "viagra_c", "viagra_a_p2", "viagra_b_p2", "viagra_c_p2",
             "viagra_a_p3", "viagra_b_p3", "viagra_c_p3", "pastilla"]


def _flat(path, k=4):
    im = Image.open(path).convert("RGBA")
    im = im.resize((im.width * k, im.height * k), Image.NEAREST)
    bg = Image.new("RGBA", im.size, (96, 96, 112, 255))
    bg.alpha_composite(im)
    return bg


def _raw(n):
    return Image.open(RAW / f"{n}.png")


def gen(names):
    portrait = Image.open(ROOT / "assets/sprites/ui/bosses/don_viagra.png")
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n == "pastilla":
            refs = [_flat(OLD_BAK)]
        elif n == "viagra_a":
            refs = [_flat(OLD_BAK), portrait]
        elif n in ("viagra_b", "viagra_c", "viagra_a_p2"):
            refs = [_raw("viagra_a")]
        elif n == "viagra_a_p3":
            refs = [_raw("viagra_a"), _raw("viagra_a_p2")]
        elif n in ("viagra_c_p2", "viagra_c_p3"):  # el diseno (con su dano) manda; C sana solo da la disposicion
            refs = [_raw("viagra_a_p2" if n.endswith("p2") else "viagra_a_p3"), _raw("viagra_c")]
        elif n.endswith("_p2"):  # b_p2: hoja sana + aspecto danado
            refs = [_raw(n[:-3]), _raw("viagra_a_p2")]
        else:  # b_p3 / c_p3: diseno p3 + disposicion p2
            refs = [_raw("viagra_a_p3"), _raw(n[:-3] + "_p2")]
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K", refs=refs)
        print("LLAMADA a Gemini:", n)



# ------------------------------------------------------------------ recorte por rejilla (4 columnas x 2 filas)
W4 = [0, 688, 1376, 2064, 2752]
# filas (y0, y1) por hoja: las hojas B traen rotulos de texto debajo de cada pose y se dejan fuera
ROWS = {"b": ((0, 712), (768, 1482))}
MARG = {("c", 6): 70}  # poses que se salen de su celda (la caida lleva la galera a un lado)
GAPS = {("a", 5): 90, ("c", 0): 70, ("c", 4): 70, ("c", 5): 70, ("c", 7): 70, ("b", 7): 70}


def _bg(path, aura=False):
    im = PA.cut_bg(Image.open(path))
    a = np.array(im).astype(int)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    green = (g > np.maximum(r, b) + 18) & (a[:, :, 3] > 0)  # sombra verde oscura del suelo
    alpha = np.where(green, 0, a[:, :, 3])
    if aura:
        # aura roja que Gemini deja sobre el verde: queda naranja/marron fuera del contorno oscuro; se borra
        # inundando desde el fondo por los pixeles rojizos (el contorno oscuro la frena, el interior no se toca)
        cand = (r > b + 30) & (alpha > 0)
        gone = alpha == 0
        for _ in range(90):
            grow = np.zeros_like(gone)
            grow[1:] |= gone[:-1]
            grow[:-1] |= gone[1:]
            grow[:, 1:] |= gone[:, :-1]
            grow[:, :-1] |= gone[:, 1:]
            new = grow & cand & ~gone
            if not new.any():
                break
            gone |= new
        alpha = np.where(gone, 0, alpha)
    a[:, :, 3] = alpha
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def _grid(name, fam):
    im = _bg(RAW / f"{name}.png", aura=fam in ("a", "b") and name.endswith("_p3"))
    rows = ROWS.get(fam, ((0, 768), (768, im.height)))
    out = {}
    for r, (y0, y1) in enumerate(rows):
        for c in range(4):
            mg = MARG.get((fam, r * 4 + c), 0)
            out[r * 4 + c] = CUT.main_blob(im.crop((max(0, W4[c] - mg), y0, min(im.width, W4[c + 1] + mg), y1)), GAPS.get((fam, r * 4 + c), 40))
    return out


def _feet_x(im):
    a = np.array(im)[:, :, 3] > 128
    ys = np.nonzero(a.any(1))[0]
    lo = ys.max() - max(6, int(0.12 * (ys.max() - ys.min())))
    xs = np.nonzero(a[lo:].any(0))[0]
    return (xs.min() + xs.max()) / 2.0


def fit(raw, cw, ch, idle_h, ncol=44):
    """Todas las poses a la MISMA escala (idle -> idle_h), pies abajo y anclados en la base."""
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
    return A.quantize_set(out, ncol)


DW, DH = 176, 184
VARIANTS = {"": ("viagra_a", "viagra_b", "viagra_c"), "_p2": ("viagra_a_p2", "viagra_b_p2", "viagra_c_p2"),
            "_p3": ("viagra_a_p3", "viagra_b_p3", "viagra_c_p3")}


def don_poses(suffix):
    na, nb, nc = VARIANTS[suffix]
    a, b, c = _grid(na, "a"), _grid(nb, "b"), _grid(nc, "c")
    raw = dict(idle=a[0], walk=a[1], wind=a[2], punch=a[3], rwind=a[4], rrel=a[5], pwind=a[6], prel=a[7],
               owind=b[0], orel=b[1], bwind=b[2], brel=b[3], channel=b[4], hurt=b[5], tired=b[6], stun=b[7],
               intro=c[0], r1=c[1], r2=c[2], r3=c[3], d1=c[4], d2=c[5], d3=c[6], d4=c[7])
    return fit(raw, DW, DH, 150)


def don_anims(P):
    xf = A.xf
    I, W = P["idle"], P["walk"]
    f = {}
    f["idle"] = [I, xf(I, sy=0.985)]
    f["walk"] = [W, xf(W, rot=-2, dy=-2), I, xf(I, rot=2, dy=-2)]
    # SUBIDON: el cuerpo se ve cada vez mas desatado segun el medidor (BossAnimator lee boss._rush)
    r1, r2, r3 = P["r1"], P["r2"], P["r3"]
    f["idle_rush"] = [r1, xf(r1, dx=1), r1, xf(r1, dx=-1, sy=0.99)]
    f["walk_rush"] = [r2, xf(r2, rot=-2, dy=-3), r2, xf(r2, rot=2, dy=-3)]
    f["idle_max"] = [r3, xf(r3, dx=2, sy=0.99), r3, xf(r3, dx=-2, sy=1.01)]
    f["walk_max"] = [r3, xf(r3, rot=-3, dy=-3, dx=2), r3, xf(r3, rot=3, dy=-3, dx=-2)]
    f["intro"] = [P["intro"], P["intro"], xf(P["intro"], sy=1.02), I]
    f["attack"] = f["attack_fan"] = [I, xf(P["wind"], rot=-3), P["wind"]]
    f["release"] = f["release_fan"] = [P["punch"], xf(P["punch"], dx=2), P["punch"]]
    f["attack_subidon"] = [I, xf(P["rwind"], sy=0.97), P["rwind"]]
    f["release_subidon"] = [P["rrel"], P["rrel"], xf(P["rrel"], dx=2)]
    f["attack_lluvia"] = [I, xf(P["pwind"], sy=0.97), P["pwind"]]
    f["release_lluvia"] = [P["prel"], xf(P["prel"], sy=1.03), P["prel"]]
    f["attack_sobredosis"] = [I, xf(P["owind"], sy=0.97), P["owind"]]
    f["release_sobredosis"] = [P["orel"], xf(P["orel"], sy=1.03), P["orel"], xf(P["orel"], sy=0.99)]
    f["attack_blister"] = [I, xf(P["bwind"], sy=0.98), P["bwind"]]
    f["release_blister"] = [P["brel"], xf(P["brel"], dy=-1), P["brel"]]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]  # aturdido (mareo)
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], sy=0.985), P["tired"], xf(P["tired"], sy=1.012)]  # agotado: jadea
    f["stun_in"] = [P["hurt"], P["stun"]]
    f["channel"] = [P["channel"], xf(P["channel"], sy=1.015), P["channel"], xf(P["channel"], sy=0.99)]
    f["hurt"] = [P["hurt"], P["hurt"], xf(P["hurt"], dx=-1)]
    f["brake"] = [xf(I, rot=7, dx=2), xf(I, rot=3)]
    f["blink"] = [I, I]
    f["idle_stir"] = [xf(I, rot=-2), xf(I, rot=2), I]
    f["idle_impatient"] = [xf(I, dy=-2), I, xf(I, dy=-2), I]
    f["death"] = [P["hurt"], P["d1"], P["d2"], P["d3"], P["d4"], P["d4"]]
    return f


META = {
    "idle": (6.0, True), "walk": (8.0, True), "intro": (3.0, False), "attack": (12.0, False), "release": (14.0, False),
    "idle_rush": (12.0, True), "walk_rush": (11.0, True), "idle_max": (16.0, True), "walk_max": (14.0, True),
    "tired": (7.0, True), "recover": (7.0, True), "recover_in": (10.0, False), "stun_in": (12.0, False),
    "channel": (9.0, True), "hurt": (12.0, False), "death": (3.5, False), "brake": (12.0, False), "blink": (14.0, False),
    "idle_stir": (8.0, False), "idle_impatient": (8.0, False),
}
for _n in ("fan", "subidon", "lluvia", "sobredosis", "blister"):
    META["attack_" + _n] = (12.0, False)
    META["release_" + _n] = (14.0, False)


def write_boss(frames, cw, ch, suffix):
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
    DEST.mkdir(parents=True, exist_ok=True)
    sheet.save(DEST / f"don_viagra_sheet{suffix}.png")
    L = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(uniq) + 2), "",
         f'[ext_resource type="Texture2D" path="{RES}don_viagra_sheet{suffix}.png" id="1_sheet"]', ""]
    for i in range(len(uniq)):
        L += [f'[sub_resource type="AtlasTexture" id="f{i}"]', 'atlas = ExtResource("1_sheet")',
              f"region = Rect2({(i % cols) * cw}, {(i // cols) * ch}, {cw}, {ch})", ""]
    anim = []
    for n, lst in frames.items():
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("f%d")\n}' % index[im.tobytes()] for im in lst)
        sp, loop = META.get(n, (10.0, False))
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if loop else "false", n, sp))
    L += ["[resource]", "animations = [" + ", ".join(anim) + "]", ""]
    (DEST / f"don_viagra_sprite_frames{suffix}.tres").write_text("\n".join(L))
    print("don", suffix or "_p1", len(uniq), "cuadros")


def build_don():
    for suf in VARIANTS:
        write_boss(don_anims(don_poses(suf)), DW, DH, suf)
    for old in DEST.glob("don_viagra_*_[0-9][0-9].png*"):
        old.unlink()  # cuadros sueltos del arte provisorio (80x120): ahora todo va en la hoja


# ------------------------------------------------------------------ pastilla 32x48
PDEST = ROOT / "assets/sprites/enemies/penelandia/pastilla"
PRES = "res://assets/sprites/enemies/penelandia/pastilla/"
PBOX = [(0, 40, 688, 700), (688, 40, 1376, 700), (1376, 40, 2064, 700), (2064, 40, 2752, 700),
        (0, 790, 688, 1480), (688, 790, 1376, 1480), (1376, 790, 2064, 1480), (2064, 790, 2752, 1480)]


def pastilla_poses():
    im = _bg(RAW / "pastilla.png")
    raw = {k: A.trim(CUT.main_blob(im.crop(b), 30)) for k, b in zip(
        ("idle", "wa", "wb", "windup", "roll", "hurt", "d1", "d2"), PBOX)}
    s = 40.0 / raw["idle"].height
    out = {}
    for k, v in raw.items():
        m = min(1.0, 30.0 / (v.width * s), 47.0 / (v.height * s))
        w, h = max(1, round(v.width * s * m)), max(1, round(v.height * s * m))
        cv = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
        cv.alpha_composite(A.down(v, w, h), (max(0, (32 - w) // 2), 48 - h))
        out[k] = cv
    print("  pastilla escala", round(s, 3))
    return A.quantize_set(out, 24)


def build_pastilla():
    P = pastilla_poses()
    xf = A.xf
    I = P["idle"]
    f = {"idle": [I, xf(I, sy=0.96)], "walk": [P["wa"], I, P["wb"], I],
         "attack": [P["windup"], xf(P["windup"], dx=1), P["windup"], xf(P["windup"], dx=-1)],
         "roll": [P["roll"], P["roll"]],
         "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)], "death": [P["hurt"], P["d1"], P["d2"], P["d2"]]}
    speeds = {"idle": (4.0, True), "walk": (8.0, True), "attack": (14.0, True), "roll": (8.0, True), "hurt": (10.0, False), "death": (8.0, False)}
    PDEST.mkdir(parents=True, exist_ok=True)
    for old in PDEST.glob("pastilla_*"):
        old.unlink()
    res, anim = [], []
    for n, lst in f.items():
        fr = []
        for i, im in enumerate(lst):
            im.save(PDEST / f"pastilla_{n}_{i:02d}.png")
            rid = f"{n}{i}"
            res.append(f'[ext_resource type="Texture2D" path="{PRES}pastilla_{n}_{i:02d}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        sp, loop = speeds[n]
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
    (PDEST / "pastilla_sprite_frames.tres").write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(res) + "\n\n[resource]\nanimations = [" + ", ".join(anim) + "]\n")


# ------------------------------------------------------------------ hoja de contacto
def _sheet(items, cw, ch, cols, k, bg=(58, 56, 84, 255)):
    rows = (len(items) + cols - 1) // cols
    sh = Image.new("RGBA", (cols * cw * k, rows * ch * k), bg)
    for i, (_, im) in enumerate(items):
        big = im.resize((im.width * k, im.height * k), Image.NEAREST)
        sh.alpha_composite(big, ((i % cols) * cw * k + (cw * k - big.width) // 2, (i // cols) * ch * k + (ch * k - big.height)))
    return sh


def preview(dest):
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    tiles = []
    for suf in VARIANTS:
        for k, im in don_poses(suf).items():
            tiles.append((f"don{suf} {k}", im))
    c = []
    if PDEST.exists():
        for p in sorted(PDEST.glob("pastilla_*_[0-9][0-9].png")):
            c.append((p.stem, Image.open(p)))
    _sheet(tiles, DW, DH, 8, 1).convert("RGB").save(dest / "don_poses_x1.png")
    _sheet(tiles, DW, DH, 8, 3).convert("RGB").save(dest / "don_poses_x3.png")
    _sheet(c, 40, 52, 8, 1).convert("RGB").save(dest / "pastilla_x1.png")
    _sheet(c, 40, 52, 8, 3).convert("RGB").save(dest / "pastilla_x3.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["don", "pastilla"]
        if "don" in parts:
            build_don()
        if "pastilla" in parts:
            build_pastilla()
    elif cmd == "preview":
        preview(args[0] if args else ".")
