"""Arte DEFINITIVO de LA AFEITADORA ELECTRICA (jefa alternativa del Foliculo Profundo, Selva) y de la PELUSA ESTATICA con Gemini.
Escribe en assets/sprites/enemies/selva/afeitadora/ y selva/pelusa_estatica/ (carpetas de assets/data/enemy_art.json).

Uso: python3 tools/gen_afeitadora_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_afeitadora_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_afeitadora_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro). Originales FUERA del worktree (se borra):
  /home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/afeitadora/   (copia: ~/Videos/Rogue Reproductive/arte_gemini_original/afeitadora/)
  afei_a afei_b afei_c (sana) + _p2 y _p3 de cada una (dano visible) + pelusa      (10 llamadas; tope 14)
Partes de build: afeitadora (176x184 -> afeitadora_sheet{,_p2,_p3}.png + afeitadora_sprite_frames{,_p2,_p3}.tres)
                 pelusa (32x48 -> pelusa_estatica_sheet.png + pelusa_estatica_sprite_frames.tres)
Referencia de diseno: tools/_intro_raw/afeitadora_v2.png (fuera de git; ruta absoluta del repo principal).
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
MAIN = Path("/home/nick/Escritorio/Proyectos/soul_knight")
RAW = MAIN / ".claude/arte_fuente/afeitadora"
GEM.RAW = RAW
DEST = ROOT / "assets/sprites/enemies/selva/afeitadora"
RES = "res://assets/sprites/enemies/selva/afeitadora/"
DESIGN = MAIN / "tools/_intro_raw/afeitadora_v2.png"
CUT.cut_bg = PA.cut_bg

# ------------------------------------------------------------------ prompts
_AFE = (
    "THE BOSS 'La Afeitadora Electrica' (The Electric Shaver): a chunky cobalt-blue ELECTRIC SHAVER with a face, standing upright on "
    "two short dark slate-blue stubby legs with flat feet. A wide rounded-rectangle royal-blue body (lighter blue highlight on the "
    "left, deep navy shadow stripe on the right). Two small white angry eyes with black pupils under heavy thick black angry eyebrows "
    "and a tiny flat mouth line. A big wide light-grey SILVER shaver HEAD on top, wider than the body: a rounded slab with a pale "
    "highlight bar and a row of comb-like vertical dark teeth/slits along its lower edge (the cutting foil); little CYAN-blue electric "
    "sparks crackle around it. One small round emerald-green LED light (#2fbf5f, clearly darker than the background) on the lower "
    "right of the body. Short blue stubby arm bulges at the sides ending in small blue fists. A thick black power CABLE comes out of "
    "the lower right of the body, trails on the floor and ends in a grey two-prong PLUG. Cold, irritable and obsessed with removing "
    "everything that grows. Same character, same proportions, same colors and same design as the reference image(s), but redrawn "
    "with much more detail and a premium look. No human anatomy, no genitals, family friendly cartoon humor. "
)
_ORDER = (
    " All poses are the SAME character at the SAME scale and the same camera, full body visible and grounded, "
    "feet at the bottom of each cell, a single big character per cell, no extra characters except the props named. "
    "Extra effects (sparks, smoke, speed lines) stay very close to the body. The cable and plug always stay close to the body. "
)
_DMG2 = (
    "now clearly battle-damaged: a big dent and scratches on the silver head, a couple of bent comb teeth, a crack across the blue "
    "body, more crackling cyan sparks, the black cable nicked with a bit of exposed copper wire, angrier narrowed eyes, "
    "slightly darker shadows. "
)
_DMG3 = (
    "HEAVILY DAMAGED and OVERLOADED: the silver head cracked and tilted with several comb teeth missing, a deep dent and a chunk "
    "missing from the blue body, bare sparking wires poking out, the black cable frayed with exposed copper, wide furious "
    "bloodshot eyes, gritted teeth, a thin wisp of grey smoke, many cyan sparks, a cartoon plaster patch on the body and the LED "
    "turned orange. "
)
_MATCH = (
    " STYLE MATCH (critical): keep EXACTLY the silhouette, proportions, eye size, the wide silver head, the green LED position and "
    "the stubby legs of the reference sheet, the same chunky pixel size and 1-pixel dark outline, the same pose composition in every "
    "cell; only add the damage described. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
)

PROMPTS = {
    "afei_a": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). The reference image shows the approved design "
        "(copy it faithfully, same chunky blocky style)." + _ORDER + _AFE +
        "Poses left to right, top row: (1) neutral idle, arms at sides, glaring; (2) walking step, one foot forward, waddling, "
        "head bobbing; (3) walking step with the OTHER foot forward; (4) generic ATTACK WIND-UP: the silver head buzzing and "
        "vibrating, leaning back, sparks gathering, fierce face. Bottom row: (5) generic ATTACK RELEASE: leaning forward, a bright "
        "cyan spark bolt discharging from the head, motion lines; (6) ZIGZAG WIND-UP: crouched low and leaning forward like a "
        "charging bull, head lowered, feet digging in, the green LED bright; (7) ZIGZAG RELEASE: body stretched forward at full "
        "speed, tilted, cable streaming behind, long speed lines and a dust puff; (8) BOUNCING OFF A WALL: squashed and "
        "compressed sideways, eyes squeezed, sparks flying, about to rebound."
    ),
    "afei_b": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses), the SAME character as the "
        "reference image (approved design), only the pose changes." + _ORDER + _AFE +
        "Poses left to right, top row: (1) BLADES WIND-UP: the silver head lifting off a little and spinning up, cutting teeth "
        "glowing, braced stance; (2) BLADES RELEASE: the silver head spinning as a fast blur with whirling cyan-white blades "
        "around it, leaning forward aggressively; (3) LINT-SUMMON WIND-UP: the head's lid popping open, sucking in with a "
        "vacuum pose, arms raised; (4) LINT-SUMMON RELEASE: head tilted up spitting out small round fuzzy lint balls flying "
        "out around it. Bottom row: (5) CHANNELING A HEALING SPELL: unplugged, holding the plug in one hand, the green LED "
        "glowing big and bright, serene closed eyes, eerie cyan glow and sparkles; (6) HURT: flinching backwards, eyes "
        "squeezed, a spark bursting from the head; (7) EXHAUSTED: slumped forward, head drooping, smoke puffing out, eyes "
        "half closed, panting, deflated; (8) STUNNED and short-circuiting: swirly spiral eyes, little stars and sparks "
        "circling the head, arms limp, the cable cut and sparking."
    ),
    "afei_c": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses), the SAME character as the "
        "reference image (approved design), only the pose changes." + _ORDER + _AFE +
        "Poses left to right, top row: (1) dramatic INTRO entrance: standing tall, arms spread, head buzzing with a big burst "
        "of sparks, menacing glare, the teeth gleaming; (2) walking step THREE, a heavier stomp, one fist clenched; "
        "(3) idle GESTURE: tapping one foot impatiently, one fist on the side, glaring sideways; (4) BLINK: the same idle "
        "pose with the eyes closed. Bottom row, a theatrical DEATH in four steps: (5) short-circuiting: shaking, lightning "
        "arcs all over the body, the silver head popping up off its seat; (6) the head flying off to one side and the body "
        "reeling backwards, off-balance, eyes spinning; (7) fallen flat on its back, the whole body tipped over lying "
        "sideways on the ground, stubby legs sticking out, X eyes, the head lying beside it, smoke rising, the plug lying "
        "on the ground (a completely NEW pose, do not copy any pose of the reference); (8) the same lying pose, all dead and "
        "deflated, a little white flag stuck in the plug, a tiny wisp of smoke forming a little ghost."
    ),
}
PROMPTS["afei_a_p2"] = (
    STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). It is the DAMAGED PHASE 2 of the SAME character as the "
    "reference sheet: same poses in the same order and positions, same design, but " + _DMG2 + _ORDER + _AFE +
    "Same eight poses as the reference: idle, walking step, walking step, attack wind-up, attack release, zigzag wind-up, "
    "zigzag release, bouncing off a wall." + _MATCH)
PROMPTS["afei_a_p3"] = (
    STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). It is the PHASE 3 of the SAME character as the "
    "reference sheet: same poses in the same order and positions, same design, but " + _DMG3 + _ORDER + _AFE +
    "Same eight poses as the reference: idle (panting with rage), walking step, walking step, attack wind-up, attack release, "
    "zigzag wind-up, zigzag release, bouncing off a wall." + _MATCH)
for _s in ("b", "c"):
    PROMPTS[f"afei_{_s}_p2"] = (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). Two reference images: the FIRST is the healthy "
        f"'pose sheet {_s.upper()}' of the character, the SECOND is the same character in his DAMAGED PHASE 2 look. Redraw EXACTLY the "
        "poses of the first reference (same order, same positions, same composition) but with the damaged look of the second "
        "reference: " + _DMG2 + _ORDER + _AFE + _MATCH)
    PROMPTS[f"afei_{_s}_p3"] = (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). Two reference images: the FIRST is the character "
        "design to copy EXACTLY in its HEAVILY DAMAGED, OVERLOADED PHASE 3 look. The SECOND is a pose-layout reference of the same "
        "character in phase 2: redraw EXACTLY its 8 poses (same order, positions and composition) with the phase 3 design of the "
        "first reference, same proportions and same size, with NO red glow or aura around it: " + _DMG3 + _ORDER + _AFE + _MATCH)
PROMPTS["pelusa"] = (
    STYLE + "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses), the SAME tiny creature at the same scale in each "
    "cell. All poses are the SAME character at the SAME scale, a single small creature per cell, bottom at the bottom of "
    "each cell, effects very close to the body. THE ENEMY 'Pelusa Estatica' (Static Lint): a small round fluffy ball of tan-brown "
    "lint fuzz with two big wide anxious googly white eyes with black pupils, a tiny worried mouth, no limbs, hovering just above "
    "the ground, a cute fragile fuzzy creature. Same design as the reference image, redrawn crisp and premium. Poses left to "
    "right, top row: (1) idle floating, calm; (2) floating drift step A, tilted slightly; (3) floating drift step B, tilted "
    "the other way; (4) CHARGING: all the fuzz standing on end, bristling and puffed up, shaking, eyes wide, tiny cyan sparks "
    "crackling over it. Bottom row: (5) DISCHARGE: the fuzz flattened out and a bright cyan-white spark ring blasting out, eyes "
    "squeezed shut; (6) hurt, flinching with a squashed body; (7) death part one: bursting into loose tufts flying apart; "
    "(8) death part two: a few loose lint tufts and a wisp of smoke on the ground. Cyan sparks only, never green."
)
GEN_ORDER = ["afei_a", "afei_b", "afei_c", "afei_a_p2", "afei_b_p2", "afei_c_p2", "afei_a_p3", "afei_b_p3", "afei_c_p3", "pelusa"]


def _raw(n):
    return Image.open(RAW / f"{n}.png")


def _design_ref():
    im = Image.open(DESIGN).convert("RGB").crop((480, 50, 900, 620))
    return im.resize((im.width * 2, im.height * 2), Image.NEAREST)


def _pelusa_ref():
    im = Image.open(DESIGN).convert("RGB").crop((820, 610, 1000, 750))
    return im.resize((im.width * 4, im.height * 4), Image.NEAREST)


def gen(names):
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n == "pelusa":
            refs = [_pelusa_ref()]
        elif n == "afei_a":
            refs = [_design_ref()]
        elif n in ("afei_b", "afei_c", "afei_a_p2"):
            refs = [_raw("afei_a")]
        elif n == "afei_a_p3":
            refs = [_raw("afei_a"), _raw("afei_a_p2")]
        elif n in ("afei_c_p2", "afei_c_p3"):
            refs = [_raw("afei_a_" + n[-2:]), _raw("afei_c")]
        elif n.endswith("_p2"):
            refs = [_raw(n[:-3]), _raw("afei_a_p2")]
        else:
            refs = [_raw("afei_a_p3"), _raw(n[:-3] + "_p2")]
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K", refs=refs)
        print("LLAMADA a Gemini:", n)


# ------------------------------------------------------------------ recorte por rejilla (4 columnas x 2 filas)
W4 = [0, 688, 1376, 2064, 2752]
ROWS = {}
MARG = {}
GAPS = {}


def _bg(path):
    im = PA.cut_bg(Image.open(path))
    a = np.array(im).astype(int)
    r, g, b = a[:, :, 0], a[:, :, 1], a[:, :, 2]
    green = (g > np.maximum(r, b) + 18) & (a[:, :, 3] > 0) & (g < 150) & (r < 90) & (b < 90)  # sombra verde oscura del suelo
    a[:, :, 3] = np.where(green, 0, a[:, :, 3])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def _grid(name, fam):
    im = _bg(RAW / f"{name}.png")
    rows = ROWS.get(fam, ((0, im.height // 2), (im.height // 2, im.height)))
    out = {}
    for r, (y0, y1) in enumerate(rows):
        for c in range(4):
            k = r * 4 + c
            mg = MARG.get((fam, k), 0)
            x0, x1 = (W4[c] * im.width) // 2752, (W4[c + 1] * im.width) // 2752
            out[k] = CUT.main_blob(im.crop((max(0, x0 - mg), y0, min(im.width, x1 + mg), y1)), GAPS.get((fam, k), 40))
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
VARIANTS = {"": ("afei_a", "afei_b", "afei_c"), "_p2": ("afei_a_p2", "afei_b_p2", "afei_c_p2"),
            "_p3": ("afei_a_p3", "afei_b_p3", "afei_c_p3")}


def poses(suffix):
    na, nb, nc = VARIANTS[suffix]
    a, b, c = _grid(na, "a"), _grid(nb, "b"), _grid(nc, "c")
    raw = dict(idle=a[0], walk=a[1], walk2=a[2], wind=a[3], spark=a[4], zwind=a[5], zrel=a[6], bounce=a[7],
               cwind=b[0], crel=b[1], pwind=b[2], prel=b[3], channel=b[4], hurt=b[5], tired=b[6], stun=b[7],
               intro=c[0], walk3=c[1], gesture=c[2], blink=c[3], d1=c[4], d2=c[5], d3=c[6], d4=c[7])
    return fit(raw, DW, DH, 150)


def anims(P):
    xf = A.xf
    I, W, W2 = P["idle"], P["walk"], P["walk2"]
    f = {}
    f["idle"] = [I, xf(I, sy=0.985)]
    f["walk"] = [W, xf(W, dy=-2), W2, xf(W2, dy=-2), P["walk3"], xf(P["walk3"], dy=-2)]
    f["intro"] = [P["intro"], P["intro"], xf(P["intro"], sy=1.02), I]
    f["attack"] = [I, xf(P["wind"], rot=-3), P["wind"]]
    f["release"] = [P["spark"], xf(P["spark"], dx=2), P["spark"]]
    f["attack_zigzag"] = [I, xf(P["zwind"], sy=0.97), P["zwind"]]
    f["release_zigzag"] = [P["zrel"], P["zrel"], xf(P["zrel"], dx=2)]
    f["attack_cuchillas"] = [I, xf(P["cwind"], sy=0.97), P["cwind"]]
    f["release_cuchillas"] = [P["crel"], xf(P["crel"], rot=2), P["crel"], xf(P["crel"], rot=-2)]
    f["attack_pelusas"] = [I, xf(P["pwind"], sy=0.97), P["pwind"]]
    f["release_pelusas"] = [P["prel"], xf(P["prel"], sy=1.03), P["prel"]]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]  # aturdida (cortocircuito)
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], sy=0.985), P["tired"], xf(P["tired"], sy=1.012)]  # agotada: humea
    f["stun_in"] = [P["hurt"], P["stun"]]
    f["channel"] = [P["channel"], xf(P["channel"], sy=1.015), P["channel"], xf(P["channel"], sy=0.99)]
    f["hurt"] = [P["hurt"], P["hurt"], xf(P["hurt"], dx=-1)]
    f["brake"] = [P["bounce"], xf(I, rot=4, dx=2)]
    f["blink"] = [P["blink"], P["blink"]]
    f["idle_stir"] = [xf(I, rot=-2), xf(I, rot=2), I]
    f["idle_impatient"] = [P["gesture"], xf(P["gesture"], dy=-1), P["gesture"], xf(P["gesture"], dy=-1)]
    f["death"] = [P["hurt"], P["d1"], P["d2"], P["d3"], P["d4"], P["d4"]]
    return f


META = {
    "idle": (6.0, True), "walk": (10.0, True), "intro": (3.0, False), "attack": (12.0, False), "release": (14.0, False),
    "tired": (7.0, True), "recover": (7.0, True), "recover_in": (10.0, False), "stun_in": (12.0, False),
    "channel": (9.0, True), "hurt": (12.0, False), "death": (3.5, False), "brake": (12.0, False), "blink": (14.0, False),
    "idle_stir": (8.0, False), "idle_impatient": (8.0, False),
}
for _n in ("zigzag", "cuchillas", "pelusas"):
    META["attack_" + _n] = (12.0, False)
    META["release_" + _n] = (14.0, False)


def _uniq_sheet(frames, cw, ch, cols=6):
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
    return sheet, uniq, index


def _write_tres(path, res_png, frames, uniq, index, cw, ch, cols=6):
    L = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(uniq) + 2), "",
         f'[ext_resource type="Texture2D" path="{res_png}" id="1_sheet"]', ""]
    for i in range(len(uniq)):
        L += [f'[sub_resource type="AtlasTexture" id="f{i}"]', 'atlas = ExtResource("1_sheet")',
              f"region = Rect2({(i % cols) * cw}, {(i // cols) * ch}, {cw}, {ch})", ""]
    anim = []
    for n, lst in frames.items():
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("f%d")\n}' % index[im.tobytes()] for im in lst)
        sp, loop = META.get(n, (10.0, False))
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if loop else "false", n, sp))
    L += ["[resource]", "animations = [" + ", ".join(anim) + "]", ""]
    Path(path).write_text("\n".join(L))


def build_boss():
    DEST.mkdir(parents=True, exist_ok=True)
    for suf in VARIANTS:
        frames = anims(poses(suf))
        sheet, uniq, index = _uniq_sheet(frames, DW, DH)
        sheet.save(DEST / f"afeitadora_sheet{suf}.png")
        _write_tres(DEST / f"afeitadora_sprite_frames{suf}.tres", f"{RES}afeitadora_sheet{suf}.png", frames, uniq, index, DW, DH)
        print("afeitadora", suf or "_p1", len(uniq), "cuadros")
    for old in DEST.glob("afeitadora_*_[0-9][0-9].png*"):
        old.unlink()  # cuadros sueltos del arte provisorio (40x60): ahora todo va en la hoja


# ------------------------------------------------------------------ pelusa 32x48
PDEST = ROOT / "assets/sprites/enemies/selva/pelusa_estatica"
PRES = "res://assets/sprites/enemies/selva/pelusa_estatica/"


def pelusa_poses():
    im = _bg(RAW / "pelusa.png")
    h2 = im.height // 2
    raw = {}
    for k, name in enumerate(("idle", "wa", "wb", "charge", "zap", "hurt", "d1", "d2")):
        c, r = k % 4, k // 4
        x0, x1 = (W4[c] * im.width) // 2752, (W4[c + 1] * im.width) // 2752
        raw[name] = A.trim(CUT.main_blob(im.crop((x0, r * h2, x1, (r + 1) * h2)), 30))
    s = 38.0 / raw["idle"].height
    out = {}
    for k, v in raw.items():
        m = min(1.0, 31.0 / (v.width * s), 47.0 / (v.height * s))
        w, h = max(1, round(v.width * s * m)), max(1, round(v.height * s * m))
        cv = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
        cv.alpha_composite(A.down(v, w, h), (max(0, (32 - w) // 2), 48 - h))
        out[k] = cv
    print("  pelusa escala", round(s, 3))
    return A.quantize_set(out, 24)


def pelusa_anims(P):
    xf = A.xf
    I = P["idle"]
    return {"idle": [I, xf(I, sy=0.96)], "walk": [P["wa"], I, P["wb"], I],
            "charge": [P["charge"], xf(P["charge"], dx=1), P["charge"], xf(P["charge"], dx=-1)],
            "zap": [P["zap"], P["zap"]],
            "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)], "death": [P["hurt"], P["d1"], P["d2"], P["d2"]]}


PMETA = {"idle": (4.0, True), "walk": (8.0, True), "charge": (14.0, True), "zap": (8.0, False), "hurt": (10.0, False), "death": (8.0, False)}


def build_pelusa():
    PDEST.mkdir(parents=True, exist_ok=True)
    for old in PDEST.glob("pelusa_estatica_*"):
        old.unlink()
    frames = pelusa_anims(pelusa_poses())
    sheet, uniq, index = _uniq_sheet(frames, 32, 48, cols=8)
    sheet.save(PDEST / "pelusa_estatica_sheet.png")
    META.update(PMETA)
    _write_tres(PDEST / "pelusa_estatica_sprite_frames.tres", f"{PRES}pelusa_estatica_sheet.png", frames, uniq, index, 32, 48, cols=8)


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
        for k, im in poses(suf).items():
            tiles.append((f"afei{suf} {k}", im))
    _sheet(tiles, DW, DH, 8, 1).convert("RGB").save(dest / "afei_poses_x1.png")
    _sheet(tiles, DW, DH, 8, 3).convert("RGB").save(dest / "afei_poses_x3.png")
    if (RAW / "pelusa.png").exists():
        c = list(pelusa_poses().items())
        _sheet(c, 40, 52, 8, 1).convert("RGB").save(dest / "pelusa_x1.png")
        _sheet(c, 40, 52, 8, 4).convert("RGB").save(dest / "pelusa_x4.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["afeitadora", "pelusa"]
        if "afeitadora" in parts:
            build_boss()
        if "pelusa" in parts:
            build_pelusa()
    elif cmd == "preview":
        preview(args[0] if args else ".")
