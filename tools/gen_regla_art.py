"""Arte DEFINITIVO de DONA REGLA (jefa del Utero) y del esbirro CENTIMETRO con Gemini.
Escribe en assets/sprites/enemies/utero/regla/ y utero/centimetro/ (carpetas de assets/data/enemy_art.json).

Uso: python3 tools/gen_regla_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_regla_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_regla_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/regla/ (ruta
ABSOLUTA del repo principal: el worktree se borra):
  regla_a regla_b regla_c (sana, 3x3 poses) + _p2 y _p3 de cada una (dano visible) + centimetro     (10 llamadas; tope 14)
Partes de build: regla (176x184 -> regla_sheet{,_p2,_p3}.png + regla_sprite_frames{,_p2,_p3}.tres)
                 centimetro (32x48 -> centimetro_*_NN.png + centimetro_sprite_frames.tres)
Referencia de diseno: la caratula nueva (tools/_intro_raw/regla_v2.png, fuera de git) recortada en _ref_regla_v2_crop.png.
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
# los originales viven en el repo principal (el worktree de trabajo se borra)
_MAIN = Path("/home/nick/Escritorio/Proyectos/soul_knight")
RAW = (_MAIN if _MAIN.exists() else ROOT) / ".claude/arte_fuente/regla"
GEM.RAW = RAW
DEST = ROOT / "assets/sprites/enemies/utero/regla"
RES = "res://assets/sprites/enemies/utero/regla/"
REF = RAW / "_ref_regla_v2_crop.png"
CUT.cut_bg = PA.cut_bg

# ------------------------------------------------------------------ prompts
_REGLA = (
    "THE BOSS 'Dona Regla' (Mrs. Ruler): a short, round, chubby little old schoolteacher lady. Her head and torso "
    "are one rounded bell/egg shape: a big dark-brown hair bun on top of her head, brown hair framing a cream-colored face, "
    "BIG round dark-rimmed glasses with big round black eyes with white highlights, strict frowning eyebrows and a small "
    "stern frown, a cream lace collar, a plain RED dress (no pattern) with a dark hem, two stubby cream-colored feet. "
    "Cream round little hands. She carries a GIANT wooden RULER (a tall flat wooden ruler with black tick marks, taller "
    "than she is) and a small wall CALENDAR (cream paper with a red top strip, a small red heart and a grid of days). "
    "A pedantic, punctual, strict and funny school-teacher boss who measures everything. Same character, same proportions, "
    "same colors and same design as the reference image, but redrawn as a clean game sprite on a flat green background "
    "(ignore the red background of the reference). No blood, no gore, no human anatomy, family friendly cartoon humor. "
)
_ORDER = (
    " All poses are the SAME character at the SAME scale and the same camera, full body visible and grounded, "
    "feet at the bottom of each cell, ONE big character per cell, nothing else except the props named (ruler, calendar, "
    "a watch, tiny effect lines). Extra effects (sweat drops, sparkles, motion lines) stay very close to the body. "
    "The big ruler must never leave its cell. "
)
_DMG2 = (
    "now clearly battle-damaged: one lens of her glasses is CRACKED with a visible crack line, the hair bun is coming "
    "loose with a few messy strands sticking out, the ruler has a big crack and a chipped splinter, the calendar has a "
    "torn corner, her collar is crooked, a sweat drop, angrier narrowed eyes, slightly darker shadows. "
)
_DMG3 = (
    "HEAVILY DAMAGED and FURIOUS: BOTH lenses of her glasses are shattered with spider cracks and the glasses sit crooked, the "
    "hair bun is completely undone with long messy hair hanging down, the wooden ruler is SNAPPED about a third shorter with a jagged "
    "splintered end and a strip of tape, the calendar is battered with torn loose pages, the dress is ripped at the hem, gritted "
    "teeth, furious wide eyes, flushed cheeks, a cartoon plaster patch on her cheek. No red aura, no blood. "
)

PROMPTS = {
    "regla_a": (
        STYLE + "BOSS SPRITE SHEET with exactly 3 rows of 3 large poses (9 poses), in reading order." + _ORDER + _REGLA +
        "Poses left to right, top row: (1) neutral IDLE, standing stern, the big ruler planted on the ground beside her held "
        "with one hand, the calendar held in the other; (2) WALKING step, one foot forward, bustling like a hurried teacher; "
        "(3) WIND-UP of a ruler SLAM: both hands raising the giant ruler high above her head, leaning back, strict fierce face. "
        "Middle row: (4) RELEASE of the slam: the ruler smashed down vertically onto the ground in front of her, leaning forward, "
        "impact lines; (5) SIDE WIND-UP: the ruler pulled back to one side at hip height like a baseball bat, twisted torso; "
        "(6) SIDE RELEASE: the ruler swung horizontally forward at full stretch, with a motion arc, torso twisted the other way. "
        "Bottom row: (7) MEASURING wind-up: the ruler held out forward like a lance aimed to the right, one eye "
        "squinting, a calculating narrowed look, a tiny sweat drop; (8) MEASURING release: the ruler thrust sharply forward "
        "like a spear, leaning in, motion lines; (9) second WALKING step (the other foot forward), the ruler on her shoulder."
    ),
    "regla_b": (
        STYLE + "BOSS SPRITE SHEET with exactly 3 rows of 3 large poses (9 poses), in reading order, the SAME character as the "
        "reference image (approved design), only the pose changes." + _ORDER + _REGLA +
        "Poses left to right, top row: (1) 180-DEGREE SWEEP wind-up: the giant ruler held out straight to her back side at "
        "shoulder height, body twisted and braced, determined; (2) SWEEP release: spinning, the giant ruler stretched out "
        "horizontally in front of her at full length with a big curved motion arc behind it, hair bun leaning; "
        "(3) 'ARRIVING ON TIME' wind-up: she is fading out, semi-faded outline, looking at a small round wristwatch on her wrist "
        "with the other hand raised, with tiny clock symbols around. "
        "Middle row: (4) 'ARRIVING ON TIME' release: she has just appeared, smug, tapping her wristwatch, a puff of cream "
        "smoke at her feet; (5) CALENDAR wind-up: holding the calendar up beside her face with one hand and flipping it with "
        "the other, scheming; (6) CALENDAR release: thrusting the big calendar forward, the days grid clearly "
        "visible with a few red marked days, stern; (7) CHARGE wind-up: crouched forward, head down like a bull, the ruler held "
        "low and forward like a battering ram, determined glare. "
        "Bottom row: (8) CHARGE release: sprinting forward at full speed leaning way forward, ruler pointed ahead, speed lines "
        "and a dust puff; (9) SUMMONING: the ruler raised high in one hand like a conductor's baton, the other hand pointing, "
        "tiny sparkles, commanding expression."
    ),
    "regla_c": (
        STYLE + "BOSS SPRITE SHEET with exactly 3 rows of 3 large poses (9 poses), in reading order, the SAME character as the "
        "reference image (approved design), only the pose changes." + _ORDER + _REGLA +
        "Poses left to right, top row: (1) CHANNELING A HEALING SPELL: eyes closed, serene, hands joined holding the "
        "ruler upright in front of her, the calendar floating beside her, a soft warm glow and tiny sparkles; (2) EXHAUSTED: "
        "bent forward panting with hands on her knees, the ruler dropped lying on the ground beside her, glasses sliding down, "
        "big sweat drops, hair bun drooping; (3) STUNNED and dizzy: swirly spiral eyes behind the glasses, tiny stars circling "
        "above her head, arms limp, the ruler tipping over. "
        "Middle row: (4) HURT: flinching backwards, eyes squeezed shut, mouth open in an offended gasp, glasses tilting, bun "
        "bouncing; (5) dramatic INTRO entrance: chin up, standing tall, ruler held up high in one hand, the calendar in the "
        "other, a glint on her glasses, authoritative; (6) theatrical DEATH step 1: clutching her chest with the back of one "
        "hand on her forehead, dramatic faint, the glasses flying off. "
        "Bottom row: (7) DEATH step 2: falling backwards off-balance, eyes closed, the ruler slipping from her hand; "
        "(8) DEATH step 3: fallen flat on her back on the ground, the whole round body lying on its back, stubby feet sticking "
        "out, X-eyes, arms limp, the giant ruler lying on the ground beside her, bun squashed (a completely NEW pose, do not "
        "copy any pose of the reference); (9) DEATH step 4: the same lying pose, deflated, a little white flag raised in one hand, "
        "a tiny ghost of her floating up."
    ),
    "regla_a_p2": (
        STYLE + "BOSS SPRITE SHEET with exactly 3 rows of 3 large poses (9 poses). It is the DAMAGED PHASE 2 of the "
        "SAME character as the reference sheet: same poses in the same order and positions, same design, but " + _DMG2 +
        _ORDER + _REGLA + "Same nine poses as the reference: idle, walking step, slam wind-up, slam release, side wind-up, "
        "side release, measuring wind-up, measuring release, second walking step."
    ),
    "regla_a_p3": (
        STYLE + "BOSS SPRITE SHEET with exactly 3 rows of 3 large poses (9 poses). It is the PHASE 3 of the SAME "
        "character as the first reference sheet (same poses in the same order and positions, same design) but " + _DMG3 +
        "The second reference shows the phase 2 damage; go further than it. " +
        _ORDER + _REGLA + "Same nine poses as the reference: idle (panting with rage), walking step, slam wind-up, slam release, "
        "side wind-up, side release, measuring wind-up, measuring release, second walking step."
    ),
    "regla_b_p2": (
        STYLE + "BOSS SPRITE SHEET with exactly 3 rows of 3 large poses (9 poses). Two reference images: the FIRST is "
        "the healthy 'pose sheet B' of the character, the SECOND is the same character in her DAMAGED PHASE 2 look. "
        "Redraw EXACTLY the poses of the first reference (same order, same positions, same composition) but with the "
        "damaged look of the second reference: " + _DMG2 + _ORDER + _REGLA
    ),
    "regla_b_p3": (
        STYLE + "BOSS SPRITE SHEET with exactly 3 rows of 3 large poses (9 poses). Two reference images: the FIRST is "
        "the character design to copy EXACTLY in her HEAVILY DAMAGED PHASE 3 look. The SECOND is a pose-layout reference of "
        "the same character in phase 2: redraw EXACTLY its 9 poses (same order, positions and composition) with the phase 3 "
        "design of the first reference, same proportions and same size: " + _DMG3 + _ORDER + _REGLA
    ),
    "regla_c_p2": (
        STYLE + "BOSS SPRITE SHEET with exactly 3 rows of 3 large poses (9 poses). Two reference images: the FIRST is "
        "the character design to copy EXACTLY (same body, same glasses, same dress, same size) in her DAMAGED PHASE 2 look. The "
        "SECOND only shows the pose layout: redraw its 9 poses in the same order, positions and composition (channeling, exhausted, "
        "stunned, hurt, intro, then the four death steps ending with a white flag and a tiny ghost) using the design of the "
        "FIRST reference: " + _DMG2 + _ORDER + _REGLA
    ),
    "regla_c_p3": (
        STYLE + "BOSS SPRITE SHEET with exactly 3 rows of 3 large poses (9 poses). Two reference images: the FIRST is "
        "the character design to copy EXACTLY (same body, same dress, same size) in her HEAVILY DAMAGED PHASE 3 look. The SECOND "
        "only shows the pose layout: redraw its 9 poses in the same order, positions and composition (channeling, exhausted, "
        "stunned, hurt, intro, then the four death steps ending with a white flag and a tiny ghost) using the design of the "
        "FIRST reference: " + _DMG3 + _ORDER + _REGLA
    ),
    "centimetro": (
        STYLE + "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses), the SAME tiny creature at the "
        "same scale in each cell." + _ORDER +
        "THE ENEMY 'Centimetro' (Centimeter): a small living wooden RULER minion of Mrs. Ruler: a short flat light-wood ruler "
        "(about 30 cm, with black tick marks and tiny red numbers) standing upright, a tiny stern face with two small round "
        "dark eyes and a small frown at the top part, two stubby cream feet and two tiny stick arms, a little red scarf. "
        "Cute, pedantic and a bit grumpy. No blood. Poses left to right, top row: (1) idle standing; (2) walking "
        "step A; (3) walking step B; (4) MEASURING warning: leaning forward and aiming one end forward, glowing bright, eyes narrowed. "
        "Bottom row: (5) STRIKE: bending forward and lowering its whole body like a ruler slamming down, motion lines; (6) hurt, "
        "flinching with a squashed body; (7) death part one: snapping in half with splinters flying; (8) death part two: two "
        "broken ruler halves on the ground with a tiny ghost leaving."
    ),
}
GEN_ORDER = ["regla_a", "regla_b", "regla_c", "regla_a_p2", "regla_b_p2", "regla_c_p2",
             "regla_a_p3", "regla_b_p3", "regla_c_p3", "centimetro"]


def _raw(n):
    return Image.open(RAW / f"{n}.png")


def gen(names):
    ref = Image.open(REF)
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n in ("regla_a", "centimetro"):
            refs = [ref]
        elif n in ("regla_b", "regla_c", "regla_a_p2"):
            refs = [_raw("regla_a")]
        elif n == "regla_a_p3":
            refs = [_raw("regla_a"), _raw("regla_a_p2")]
        elif n in ("regla_c_p2", "regla_c_p3"):  # el diseno (con su dano) manda; C sana solo da la disposicion
            refs = [_raw("regla_a_p2" if n.endswith("p2") else "regla_a_p3"), _raw("regla_c")]
        elif n.endswith("_p2"):  # b_p2: hoja sana + aspecto danado
            refs = [_raw(n[:-3]), _raw("regla_a_p2")]
        else:  # b_p3: diseno p3 + disposicion p2
            refs = [_raw("regla_a_p3"), _raw(n[:-3] + "_p2")]
        GEM.generate(n, PROMPTS[n], aspect="4:3" if n != "centimetro" else "16:9", size="2K", refs=refs)
        print("LLAMADA a Gemini:", n)


# ------------------------------------------------------------------ recorte por rejilla (3 columnas x 3 filas)
MARG = {}  # (hoja, pose): margen extra para poses que se salen de su celda
GAPS = {}


def _bg(path):
    im = PA.cut_bg(Image.open(path))
    a = np.array(im).astype(int)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    green = (g > np.maximum(r, b) + 18) & (a[:, :, 3] > 0)  # sombra verde oscura del suelo
    a[:, :, 3] = np.where(green, 0, a[:, :, 3])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def _grid(name, fam):
    im = _bg(RAW / f"{name}.png")
    cw, ch = im.width / 3.0, im.height / 3.0
    out = {}
    for r in range(3):
        for c in range(3):
            k = r * 3 + c
            mg = MARG.get((fam, k), int(cw * 0.06))
            box = (max(0, int(c * cw) - mg), max(0, int(r * ch) - mg), min(im.width, int((c + 1) * cw) + mg), min(im.height, int((r + 1) * ch) + mg))
            out[k] = CUT.main_blob(im.crop(box), GAPS.get((fam, k), 16))
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
VARIANTS = {"": ("regla_a", "regla_b", "regla_c"), "_p2": ("regla_a_p2", "regla_b_p2", "regla_c_p2"),
            "_p3": ("regla_a_p3", "regla_b_p3", "regla_c_p3")}


def regla_poses(suffix):
    na, nb, nc = VARIANTS[suffix]
    a, b, c = _grid(na, "a"), _grid(nb, "b"), _grid(nc, "c")
    raw = dict(idle=a[0], walk=a[1], wind=a[2], slam=a[3], swind=a[4], srel=a[5], mwind=a[6], mrel=a[7], walk2=a[8],
               bwind=b[0], brel=b[1], pwind=b[2], prel=b[3], cwind=b[4], crel=b[5], rwind=b[6], rrel=b[7], summon=b[8],
               channel=c[0], tired=c[1], stun=c[2], hurt=c[3], intro=c[4], d1=c[5], d2=c[6], d3=c[7], d4=c[8])
    return fit(raw, DW, DH, 150)


def regla_anims(P):
    xf = A.xf
    I, W = P["idle"], P["walk"]
    f = {}
    f["idle"] = [I, xf(I, sy=0.985)]
    f["walk"] = [W, xf(W, dy=-2), P["walk2"], xf(P["walk2"], dy=-2)]
    f["intro"] = [P["intro"], P["intro"], xf(P["intro"], sy=1.02), I]
    # golpes de regla (atk_golpes) y ataque generico
    f["attack"] = f["attack_golpes"] = [I, xf(P["wind"], rot=-3), P["wind"]]
    f["release"] = f["release_golpes"] = [P["slam"], xf(P["slam"], dx=2), P["slam"]]
    f["attack_fan"] = [I, xf(P["swind"], rot=-3), P["swind"]]
    f["release_fan"] = [P["srel"], xf(P["srel"], dx=2), P["srel"]]
    f["attack_mide"] = [I, xf(P["mwind"], sy=0.97), P["mwind"]]
    f["release_mide"] = [P["mrel"], xf(P["mrel"], dx=2), P["mrel"]]
    f["attack_barrido"] = [I, xf(P["bwind"], rot=-2), P["bwind"]]
    f["release_barrido"] = [P["brel"], xf(P["brel"], rot=3), P["brel"], xf(P["brel"], rot=-3)]
    f["attack_puntual"] = [I, P["pwind"], A.flash(P["pwind"], 0.3)]
    f["release_puntual"] = [P["prel"], xf(P["prel"], sy=1.03), P["prel"]]  # llega puntual: la pose queda mientras reaparece
    f["attack_calendario"] = [I, xf(P["cwind"], sy=0.98), P["cwind"]]
    f["release_calendario"] = [P["crel"], xf(P["crel"], dy=-1), P["crel"]]
    f["attack_reglazo"] = [I, xf(P["rwind"], sy=0.97), P["rwind"]]
    f["release_reglazo"] = [P["rrel"], P["rrel"], xf(P["rrel"], dx=2)]
    # agotada (recover) distinta de aturdida (tired tras stun_in)
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], sy=0.985), P["tired"], xf(P["tired"], sy=1.012)]
    f["stun_in"] = [P["hurt"], P["stun"]]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]
    f["channel"] = [P["channel"], xf(P["channel"], sy=1.015), P["channel"], xf(P["channel"], sy=0.99)]
    f["hurt"] = [P["hurt"], P["hurt"], xf(P["hurt"], dx=-1)]
    f["brake"] = [xf(I, rot=7, dx=2), xf(I, rot=3)]
    f["blink"] = [I, I]
    f["idle_stir"] = [P["summon"], P["summon"], xf(P["summon"], sy=1.015), I]  # gesto: levanta la regla como directora
    f["idle_impatient"] = [xf(I, dy=-2), I, xf(I, dy=-2), I]
    f["summon"] = [P["summon"], xf(P["summon"], sy=1.02), P["summon"]]
    f["death"] = [P["hurt"], P["d1"], P["d2"], P["d3"], P["d4"], P["d4"]]
    return f


META = {
    "idle": (6.0, True), "walk": (8.0, True), "intro": (3.0, False), "attack": (12.0, False), "release": (14.0, False),
    "tired": (7.0, True), "recover": (7.0, True), "recover_in": (10.0, False), "stun_in": (12.0, False),
    "channel": (9.0, True), "hurt": (12.0, False), "death": (3.5, False), "brake": (12.0, False), "blink": (14.0, False),
    "idle_stir": (6.0, False), "idle_impatient": (8.0, False), "summon": (8.0, False),
}
for _n in ("golpes", "fan", "mide", "barrido", "puntual", "calendario", "reglazo"):
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
    sheet.save(DEST / f"regla_sheet{suffix}.png")
    L = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(uniq) + 2), "",
         f'[ext_resource type="Texture2D" path="{RES}regla_sheet{suffix}.png" id="1_sheet"]', ""]
    for i in range(len(uniq)):
        L += [f'[sub_resource type="AtlasTexture" id="f{i}"]', 'atlas = ExtResource("1_sheet")',
              f"region = Rect2({(i % cols) * cw}, {(i // cols) * ch}, {cw}, {ch})", ""]
    anim = []
    for n, lst in frames.items():
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("f%d")\n}' % index[im.tobytes()] for im in lst)
        sp, loop = META.get(n, (10.0, False))
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if loop else "false", n, sp))
    L += ["[resource]", "animations = [" + ", ".join(anim) + "]", ""]
    (DEST / f"regla_sprite_frames{suffix}.tres").write_text("\n".join(L))
    print("regla", suffix or "_p1", len(uniq), "cuadros")


def build_regla():
    for suf in VARIANTS:
        write_boss(regla_anims(regla_poses(suf)), DW, DH, suf)
    for old in DEST.glob("regla_*_[0-9][0-9].png*"):
        old.unlink()  # cuadros sueltos del arte provisorio (40x60): ahora todo va en la hoja


# ------------------------------------------------------------------ centimetro 32x48
CDEST = ROOT / "assets/sprites/enemies/utero/centimetro"
CRES = "res://assets/sprites/enemies/utero/centimetro/"


def centimetro_poses():
    im = _bg(RAW / "centimetro.png")
    cw, ch = im.width / 4.0, im.height / 2.0
    keys = ("idle", "wa", "wb", "aim", "strike", "hurt", "d1", "d2")
    raw = {}
    for i, k in enumerate(keys):
        r, c = divmod(i, 4)
        mg = int(cw * 0.05)
        box = (max(0, int(c * cw) - mg), max(0, int(r * ch) - mg), min(im.width, int((c + 1) * cw) + mg), min(im.height, int((r + 1) * ch) + mg))
        raw[k] = A.trim(CUT.main_blob(im.crop(box), 30))
    s = 40.0 / raw["idle"].height
    out = {}
    for k, v in raw.items():
        m = min(1.0, 30.0 / (v.width * s), 47.0 / (v.height * s))
        w, h = max(1, round(v.width * s * m)), max(1, round(v.height * s * m))
        cv = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
        cv.alpha_composite(A.down(v, w, h), (max(0, (32 - w) // 2), 48 - h))
        out[k] = cv
    print("  centimetro escala", round(s, 3))
    return A.quantize_set(out, 24)


def build_centimetro():
    P = centimetro_poses()
    xf = A.xf
    I = P["idle"]
    f = {"idle": [I, xf(I, sy=0.96)], "walk": [P["wa"], I, P["wb"], I],
         "aim": [P["aim"], xf(P["aim"], dx=1), P["aim"], xf(P["aim"], dx=-1)],
         "strike": [P["strike"], P["strike"]],
         "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)], "death": [P["hurt"], P["d1"], P["d2"], P["d2"]]}
    speeds = {"idle": (4.0, True), "walk": (8.0, True), "aim": (14.0, True), "strike": (8.0, False), "hurt": (10.0, False), "death": (8.0, False)}
    CDEST.mkdir(parents=True, exist_ok=True)
    for old in CDEST.glob("centimetro_*"):
        old.unlink()
    res, anim = [], []
    for n, lst in f.items():
        fr = []
        for i, im in enumerate(lst):
            im.save(CDEST / f"centimetro_{n}_{i:02d}.png")
            rid = f"{n}{i}"
            res.append(f'[ext_resource type="Texture2D" path="{CRES}centimetro_{n}_{i:02d}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        sp, loop = speeds[n]
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
    (CDEST / "centimetro_sprite_frames.tres").write_text(
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
        for k, im in regla_poses(suf).items():
            tiles.append((f"regla{suf} {k}", im))
    c = []
    if CDEST.exists():
        for p in sorted(CDEST.glob("centimetro_*_[0-9][0-9].png")):
            c.append((p.stem, Image.open(p)))
    _sheet(tiles, DW, DH, 9, 1).convert("RGB").save(dest / "regla_poses_x1.png")
    _sheet(tiles, DW, DH, 9, 3).convert("RGB").save(dest / "regla_poses_x3.png")
    _sheet(c, 40, 52, 8, 1).convert("RGB").save(dest / "centimetro_x1.png")
    _sheet(c, 40, 52, 8, 3).convert("RGB").save(dest / "centimetro_x3.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["regla", "centimetro"]
        if "regla" in parts:
            build_regla()
        if "centimetro" in parts:
            build_centimetro()
    elif cmd == "preview":
        preview(args[0] if args else ".")
