"""Arte DEFINITIVO de SU MAJESTAD OVARIA II (jefa de Trompas), de sus huevos y de la Cria ovarica con Gemini.
Escribe en assets/sprites/enemies/vulvania/reina_ovaria/ (la carpeta de assets/data/enemy_art.json).

Uso: python3 tools/gen_ovaria_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_ovaria_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_ovaria_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/ovaria/:
  reina_a reina_b reina_p2 reina_p3 huevo cria          (6 llamadas; el resto del presupuesto de 18 queda para reintentos)
Partes de build: reina (160x180 -> reina_ovaria_sheet{,_p2,_p3}.png + reina_ovaria_sprite_frames{,_p2,_p3}.tres)
                 huevo (64x64 -> ovaria_huevo_sheet.png)   cria (32x48 -> cria_ovarica_*_NN.png + cria_ovarica_sprite_frames.tres)
Densidad: 1 pixel de arte = 1 unidad de juego (como el heroe de 32x48), reduccion con contornos conservados,
paleta corta fija por variante, SIN ampliar (NEAREST). Cuadros intermedios por script (xf), como Dona Cera.
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
RAW = ROOT / ".claude/arte_fuente/ovaria"
GEM.RAW = RAW
DEST = ROOT / "assets/sprites/enemies/vulvania/reina_ovaria"
RES = "res://assets/sprites/enemies/vulvania/reina_ovaria/"
OLD = DEST / "reina_ovaria_idle_00.png"
CUT.cut_bg = PA.cut_bg  # los personajes de Ovaria son rosados: la clave verde estricta basta

# ------------------------------------------------------------------ prompts
_REINA = (
    "THE BOSS 'Su Majestad Ovaria II' (Her Majesty Ovaria the Second), queen of the fallopian tubes: a big plump "
    "pink OVAL egg-shaped body (an ovary) with a smug regal face: half-closed heavy-lidded eyes with long lashes, "
    "round blush cheeks and a small smirking smile. A tall spiky GOLD CROWN with cyan and pink gems sits on top. "
    "Several cream-white round FOLLICLE spots on her belly. Pink noodle arms with purple gloved hands, a purple "
    "royal gown skirt with a cream hem, tiny yellow shoes. A vain, theatrical, diva queen of the menstrual cycle. "
    "Same character, same proportions, same colors and same design as the reference image(s), but redrawn with much "
    "more detail, richer shading and a premium look. "
)
_ORDER = (
    " All poses are the SAME character at the SAME scale and the same camera, full body visible and grounded, "
    "feet at the bottom of each cell, a single big character per cell, no extra characters except the props named. "
)

PROMPTS = {
    "reina_a": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses)." + _ORDER + _REINA +
        "Poses left to right, top row: (1) neutral idle, haughty, one hand on hip; (2) walking step, one foot "
        "forward, skirt swaying; (3) generic attack wind-up, leaning back, arms pulled in, pink energy gathering, "
        "gritted fierce face; (4) LAYING EGGS: crouched slightly, straining with a theatrical push, a small pink "
        "glowing egg dropping out below her skirt. Bottom row: (5) FOLLICLE WIND-UP: both arms raised high over "
        "her crown holding a big glossy pink water-balloon-like follicle ball; (6) FOLLICLE RELEASE: both arms "
        "thrown forward and down, lunging, hurling the balloon, motion lines; (7) CHANNELING A HEALING SPELL: eyes "
        "closed, serene, hands joined in front, a pink glowing aura with tiny sparkles and hearts; (8) HURT: "
        "flinching backwards, eyes squeezed, mouth open in an offended gasp, crown tilting."
    ),
    "reina_b": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses), the SAME character as the "
        "reference image (approved design: identical egg body, crown, gown, colors, proportions, art style), only "
        "the pose changes." + _ORDER + _REINA +
        "Poses left to right, top row: (1) dramatic INTRO entrance, chin up, arms spread wide, triumphant and "
        "smug, crown gleaming; (2) EXHAUSTED: bent forward, hands on knees, panting, tongue out, sweat drops, "
        "crown crooked, deflated; (3) STUNNED and dizzy, swirly spiral eyes, tiny stars circling her head, arms "
        "limp, crown sliding off, tongue out; (4) SHOCKWAVE RELEASE: arms spread wide, mouth wide open in a big "
        "operatic scream, rings of pink energy radiating from her body. Bottom row, a theatrical DEATH in four "
        "steps: (5) clutching her chest with one hand, back of the hand on her forehead, a dramatic faint, crown "
        "flying up; (6) falling backwards, off-balance, eyes closed; (7) lying flat on her back on the ground, "
        "X eyes, arms spread, the crown rolling beside her; (8) the same lying pose with a cracked shell, a "
        "little white flag raised in one hand, tiny hearts and a tiny ghost floating up."
    ),
    "reina_p2": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). It is the DAMAGED PHASE 2 of "
        "the SAME character as the reference sheet: same poses in the same order and positions as the reference "
        "sheet's top row and bottom row, same design, but now clearly battle-damaged: a crack running across her "
        "oval body, a chipped crown with a missing spike, scuffed torn gown, one smeared eyelash, angrier "
        "narrowed eyes, a sweat drop, slightly deeper red-pink skin with darker shadows and a couple of cracked "
        "follicle spots." + _ORDER + _REINA +
        "Poses left to right, top row: (1) neutral idle, angrier; (2) walking step; (3) attack wind-up; (4) "
        "laying eggs. Bottom row: (5) follicle wind-up, balloon raised; (6) follicle release; (7) channeling a "
        "healing spell, eyes closed; (8) hurt, flinching."
    ),
    "reina_p3": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). It is the HEAVILY DAMAGED, "
        "ENRAGED PHASE 3 of the SAME character as the reference sheet: same poses in the same order as the "
        "reference sheet, same design, but desperate and furious: big cracks across the oval body, "
        "a broken crown with two spikes snapped off, tattered shredded gown, "
        "messy mascara running down her face in black streaks, wide furious angry eyes, gritted teeth, "
        "a darker, redder angry flushed skin tone, a faint red rage aura, a cartoon plaster patch on the belly."
        + _ORDER + _REINA +
        "Poses left to right, top row: (1) neutral idle, panting with rage; (2) walking step; (3) attack "
        "wind-up; (4) laying eggs. Bottom row: (5) follicle wind-up, balloon raised; (6) follicle release; (7) "
        "channeling a healing spell, eyes closed, painfully; (8) hurt, flinching."
    ),
    "reina_b_p2": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). Two reference images: the FIRST is "
        "the healthy 'pose sheet B' of the character, the SECOND is the same character in her DAMAGED PHASE 2 look. "
        "Redraw EXACTLY the poses of the first reference (same order, same positions, same composition: intro with "
        "arms spread, exhausted, stunned with spiral eyes, shockwave scream, then the four death steps) but with the "
        "damaged look of the second reference: crack across the oval body, chipped crown with a missing spike, scuffed "
        "torn gown, one smeared eyelash, deeper red-pink skin, a sweat drop, cracked follicle spots." + _ORDER + _REINA
    ),
    "reina_b_p3": (
        STYLE + "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses). Two reference images: the FIRST is "
        "the character design to copy EXACTLY in its HEAVILY DAMAGED, ENRAGED PHASE 3 look (a plain big OVAL EGG-shaped "
        "red body that IS the head and torso at once, NO neck, NO bodice, NO breasts, NO human anatomy; big cracks, "
        "broken crown, tattered gown hanging from the egg body, mascara streaks, cartoon plaster patch on the belly, "
        "darker redder skin, faint red aura). The SECOND is a pose-layout reference of the same character in phase 2: "
        "redraw EXACTLY its 8 poses (same order, positions and composition: intro with arms spread, exhausted, stunned "
        "with spiral eyes, shockwave scream, then the four death steps ending with a white flag and a tiny ghost) but "
        "with the phase 3 design of the first reference, same oval proportions and same size as in the first "
        "reference." + _ORDER + _REINA
    ),
    "huevo": (
        STYLE + "PROP SPRITE SHEET with exactly 1 row of 4 props (4 cells), all the same scale: "
        "(1) a plump glossy pale pink-cream EGG (an ovum), seen in three-quarter top-down view standing upright, a "
        "highlight on the shell and a faint dark-red nucleus glowing through the shell; (2) the same egg ABOUT TO "
        "HATCH: shaking, covered in cracks, a bright red-pink glow leaking through the cracks, tiny motion lines; "
        "(3) the same egg BROKEN: two cracked shell halves open with a gooey pink splash and shell shards "
        "flying, lying on the ground; (4) a BIG ROYAL EGG, the same egg design but twice as large, with a small "
        "gold crown on its top and gold bands around it, glossy and menacing. ONLY eggs, there is NO character, NO face, "
        "NO arms in any cell. Each egg sits alone in its own cell, evenly spaced in one horizontal row. No text."
    ),
    "cria": (
        STYLE + "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses), the SAME tiny creature at the "
        "same scale in each cell." + _ORDER +
        "THE ENEMY 'Cria Ovarica' (Ovarian Hatchling): a small chubby baby version of the Queen, a tiny round "
        "pale pink egg-shaped chick with a cracked eggshell cap stuck on its head like a hat, big watery sad eyes, "
        "a wobbling mouth, tiny stubby arms and feet, cream spots, crying huge tears. Cute but pathetic, "
        "humorous. Palette: pink, cream, a touch of purple, light blue tears. Poses left to right, top row: (1) "
        "idle standing, sniffling; (2) walking step A; (3) walking step B; (4) wind-up for crying: head tilted back, "
        "mouth wide open, eyes squeezed, about to wail. Bottom row: (5) wailing, leaning forward, a big blue "
        "teardrop projectile flying out of its mouth; (6) hurt, flinching with a flattened body; (7) death part "
        "one: squashed and flattened, the eggshell cap flying off; (8) death part two: popped into a flat puddle "
        "with shell bits and a tiny ghost leaving."
    ),
}
GEN_ORDER = ["reina_a", "reina_b", "reina_p2", "reina_p3", "reina_b_p2", "reina_b_p3", "huevo", "cria"]


def _flat(path, k=4):
    im = Image.open(path).convert("RGBA")
    im = im.resize((im.width * k, im.height * k), Image.NEAREST)
    bg = Image.new("RGBA", im.size, (96, 96, 112, 255))
    bg.alpha_composite(im)
    return bg


def gen(names):
    portrait = Image.open(ROOT / "assets/sprites/ui/bosses/reina_ovaria.png")
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n == "huevo":
            refs = []
        elif n in ("reina_b_p2", "reina_b_p3"):
            refs = ([Image.open(RAW / "reina_b.png"), Image.open(RAW / "reina_p2.png")] if n.endswith("p2")
                    else [Image.open(RAW / "reina_p3.png"), Image.open(RAW / "reina_b_p2.png")])
        elif n == "reina_a":
            refs = ([_flat(OLD)] if OLD.exists() else []) + [portrait]
        else:
            refs = [Image.open(RAW / "reina_a.png")]
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K", refs=refs)
        print("LLAMADA a Gemini:", n)


# ------------------------------------------------------------------ recorte por rejilla
SPLIT_Y = 768
STD = [0, 700, 1376, 2064, 2752]
# (x0, x1, gap) por pose; fila 1 = poses 0-3, fila 2 = poses 4-7 (coordenadas de la hoja original 2752x1536)
GRID_A = [[(STD[i], STD[i + 1], 40) for i in range(4)], [(0, 690, 40), (690, 1470, 40), (1470, 2050, 40), (2050, 2752, 40)]]
GRID_B = [[(0, 700, 40), (700, 1376, 40), (1376, 2064, 40), (2064, 2752, 40)],
          [(0, 690, 40), (690, 1385, 40), (1385, 2075, 24), (2000, 2752, 24)]]


def _bg(path):
    im = PA.cut_bg(Image.open(path))
    a = np.array(im).astype(int)
    green = (a[:, :, 1] > np.maximum(a[:, :, 0], a[:, :, 2]) + 18) & (a[:, :, 3] > 0)  # sombra verde oscura del suelo
    a[:, :, 3] = np.where(green, 0, a[:, :, 3])
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def _grid(name, grid, y_split=SPLIT_Y):
    im = _bg(RAW / f"{name}.png")
    out = {}
    for r, (y0, y1) in enumerate(((0, y_split), (y_split, im.height))):
        for c, (x0, x1, gap) in enumerate(grid[r]):
            out[r * 4 + c] = CUT.main_blob(im.crop((x0, y0, x1, y1)), gap)
    return out


def _feet_x(im):
    a = np.array(im)[:, :, 3] > 128
    ys = np.nonzero(a.any(1))[0]
    lo = ys.max() - max(6, int(0.12 * (ys.max() - ys.min())))
    xs = np.nonzero(a[lo:].any(0))[0]
    return (xs.min() + xs.max()) / 2.0


def fit(raw, cw, ch, idle_h):
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
    return A.quantize_set(out, 40)


RW, RH = 176, 184
VARIANTS = {"": ("reina_a", "reina_b"), "_p2": ("reina_p2", "reina_b_p2"), "_p3": ("reina_p3", "reina_b_p3")}


def reina_poses(suffix):
    na, nb = VARIANTS[suffix]
    a, b = _grid(na, GRID_A), _grid(nb, GRID_B)
    raw = dict(idle=a[0], walk=a[1], wind=a[2], lay=a[3], folw=a[4], folr=a[5], channel=a[6], hurt=a[7],
               intro=b[0], tired=b[1], stun=b[2], shock=b[3], d1=b[4], d2=b[5], d3=b[6], d4=b[7])
    return fit(raw, RW, RH, 160)


def reina_anims(P):
    xf = A.xf
    I = P["idle"]
    f = {}
    f["idle"] = [I, xf(I, sy=0.985)]
    f["walk"] = [P["walk"], xf(P["walk"], rot=-2, dy=-2), I, xf(I, rot=2, dy=-2)]
    f["intro"] = [P["intro"], P["intro"], xf(P["intro"], sy=1.02), I]
    # generico (abanico): se echa atras con energia y suelta de golpe hacia delante
    f["attack"] = f["attack_fan"] = [I, xf(P["wind"], rot=-3), P["wind"]]
    f["release"] = f["release_fan"] = [xf(P["wind"], rot=6, dx=3, sx=1.05), xf(P["wind"], rot=4, dx=2), xf(P["wind"], rot=2, dy=1)]
    f["attack_ondas"] = [I, xf(P["shock"], sy=0.97), P["shock"]]
    f["release_ondas"] = [P["shock"], xf(P["shock"], sx=1.03, sy=1.03), P["shock"], xf(P["shock"], sy=0.98)]
    f["attack_huevos"] = [I, xf(P["lay"], sy=0.97), P["lay"]]
    f["release_huevos"] = [P["lay"], xf(P["lay"], sy=1.03), P["lay"], xf(P["lay"], sy=0.98)]
    f["attack_foliculos"] = [I, xf(P["folw"], sy=0.97), P["folw"]]
    f["release_foliculos"] = [P["folr"], P["folr"], xf(P["folr"], dy=1)]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]  # aturdida (mareo)
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], sy=0.985), P["tired"], xf(P["tired"], sy=1.012)]  # agotada: jadea
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
    "tired": (7.0, True), "recover": (7.0, True), "recover_in": (10.0, False), "stun_in": (12.0, False),
    "channel": (9.0, True), "hurt": (12.0, False), "death": (3.5, False), "brake": (12.0, False), "blink": (14.0, False),
    "idle_stir": (8.0, False), "idle_impatient": (8.0, False),
}
for _n in ("fan", "ondas", "huevos", "foliculos"):
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
    sheet.save(DEST / f"reina_ovaria_sheet{suffix}.png")
    L = ['[gd_resource type="SpriteFrames" load_steps=%d format=3]' % (len(uniq) + 2), "",
         f'[ext_resource type="Texture2D" path="{RES}reina_ovaria_sheet{suffix}.png" id="1_sheet"]', ""]
    for i in range(len(uniq)):
        L += [f'[sub_resource type="AtlasTexture" id="f{i}"]', 'atlas = ExtResource("1_sheet")',
              f"region = Rect2({(i % cols) * cw}, {(i // cols) * ch}, {cw}, {ch})", ""]
    anim = []
    for n, lst in frames.items():
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("f%d")\n}' % index[im.tobytes()] for im in lst)
        sp, loop = META.get(n, (10.0, False))
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if loop else "false", n, sp))
    L += ["[resource]", "animations = [" + ", ".join(anim) + "]", ""]
    (DEST / f"reina_ovaria_sprite_frames{suffix}.tres").write_text("\n".join(L))
    print("reina", suffix or "_p1", len(uniq), "cuadros")


def build_reina():
    for suf in VARIANTS:
        write_boss(reina_anims(reina_poses(suf)), RW, RH, suf)
    for old in DEST.glob("reina_ovaria_*_[0-9][0-9].png*"):
        old.unlink()  # cuadros sueltos del arte provisorio: ahora todo va en la hoja


# ------------------------------------------------------------------ huevo
def build_huevo():
    im = _bg(RAW / "huevo.png")
    row = im.crop((0, 0, im.width, 740))
    xs = [(0, 690), (690, 1376), (1376, 2064), (2064, 2752)]  # 4 huevos centrados cada ~688 px
    raw = {k: A.trim(CUT.main_blob(row.crop((x0, 0, x1, row.height)), 30)) for k, (x0, x1) in zip(("normal", "hatch", "broken", "royal"), xs)}
    s = 50.0 / raw["normal"].height  # huevo de 38x50 como el dibujo por codigo
    sr = 116.0 / raw["royal"].height  # Ovulo Real: el nodo va a escala 2.3 y el dibujo la compensa
    out = {}
    for k, v in raw.items():
        k_ = sr if k == "royal" else s
        out[k] = A.down(v, max(1, round(v.width * k_)), max(1, round(v.height * k_)))
    q = A.quantize_set(out, 28)
    for k, v in q.items():
        v.save(DEST / f"reina_ovaria_huevo_{k}.png")
        print("huevo", k, v.size)


# ------------------------------------------------------------------ cria 32x48
CDEST = ROOT / "assets/sprites/enemies/vulvania/cria_ovarica"
CRES = "res://assets/sprites/enemies/vulvania/cria_ovarica/"
# cajas de las poses (x0, y0, x1, y1) en la hoja 2752x1536 SIN las etiquetas de texto que Gemini escribio debajo
CRIA_BOX = [(0, 60, 700, 660), (700, 60, 1380, 660), (1380, 60, 2050, 660), (2050, 60, 2752, 660),
            (0, 860, 490, 1430), (790, 860, 1270, 1430), (1300, 860, 2050, 1430), (2180, 1250, 2650, 1430)]


def cria_poses():
    im = _bg(RAW / "cria.png")
    raw = {k: A.trim(CUT.main_blob(im.crop(b), 30)) for k, b in zip(
        ("idle", "wa", "wb", "windup", "wail", "hurt", "d1", "d2"), CRIA_BOX)}
    s = 41.0 / raw["idle"].height
    out = {}
    for k, v in raw.items():
        m = min(1.0, 30.0 / (v.width * s), 47.0 / (v.height * s))
        w, h = max(1, round(v.width * s * m)), max(1, round(v.height * s * m))
        cv = Image.new("RGBA", (32, 48), (0, 0, 0, 0))
        cv.alpha_composite(A.down(v, w, h), (max(0, (32 - w) // 2), 48 - h))
        out[k] = cv
    print("  cria escala", round(s, 3))
    return A.quantize_set(out, 24)


def build_cria():
    P = cria_poses()
    xf = A.xf
    I = P["idle"]
    f = {"idle": [I, xf(I, sy=0.97)], "walk": [P["wa"], I, P["wb"], I],
         "attack": [xf(I, sy=0.95), P["windup"], P["windup"]], "cry": [P["wail"], P["wail"]],
         "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)], "death": [P["hurt"], P["d1"], P["d2"], P["d2"]]}
    speeds = {"idle": (4.0, True), "walk": (8.0, True), "attack": (5.0, False), "cry": (8.0, False), "hurt": (10.0, False), "death": (8.0, False)}
    CDEST.mkdir(parents=True, exist_ok=True)
    for old in CDEST.glob("cria_ovarica_*"):
        old.unlink()
    res, anim = [], []
    for n, lst in f.items():
        fr = []
        for i, im in enumerate(lst):
            im.save(CDEST / f"cria_ovarica_{n}_{i:02d}.png")
            rid = f"{n}{i}"
            res.append(f'[ext_resource type="Texture2D" path="{CRES}cria_ovarica_{n}_{i:02d}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        sp, loop = speeds[n]
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
    (CDEST / "cria_ovarica_sprite_frames.tres").write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(res) + "\n\n[resource]\nanimations = [" + ", ".join(anim) + "]\n")


# ------------------------------------------------------------------ hoja de contacto
def preview(dest):
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    BG = (58, 56, 84, 255)
    tiles = []
    for suf in VARIANTS:
        for k, im in reina_poses(suf).items():
            tiles.append((f"reina{suf} {k}", im))
    sheets = [("huevo_" + k, Image.open(DEST / f"reina_ovaria_huevo_{k}.png")) for k in ("normal", "hatch", "broken", "royal")]
    c = []
    if CDEST.exists():
        for p in sorted(CDEST.glob("cria_ovarica_*_[0-9][0-9].png")):
            c.append((p.stem.replace("cria_ovarica_", "cria "), Image.open(p)))

    def sheet(items, cw, ch, cols, k):
        rows = (len(items) + cols - 1) // cols
        sh = Image.new("RGBA", (cols * cw * k, rows * ch * k), BG)
        for i, (_, im) in enumerate(items):
            big = im.resize((im.width * k, im.height * k), Image.NEAREST)
            sh.alpha_composite(big, ((i % cols) * cw * k + (cw * k - big.width) // 2, (i // cols) * ch * k + (ch * k - big.height)))
        return sh
    sheet(tiles, RW, RH, 8, 1).convert("RGB").save(dest / "reina_poses_x1.png")
    sheet(tiles, RW, RH, 8, 3).convert("RGB").save(dest / "reina_poses_x3.png")
    sheet(sheets + c, 120, 120, 8, 1).convert("RGB").save(dest / "huevo_cria_x1.png")
    sheet(sheets + c, 120, 120, 8, 3).convert("RGB").save(dest / "huevo_cria_x3.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["reina", "huevo", "cria"]
        if "reina" in parts:
            build_reina()
        if "huevo" in parts:
            build_huevo()
        if "cria" in parts:
            build_cria()
    elif cmd == "preview":
        preview(args[0] if args else ".")
