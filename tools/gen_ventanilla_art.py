"""Arte DEFINITIVO de LA VENTANILLA UNICA (jefa alternativa de la Aduana Interior, Perineo; id interno "prostata") y del
TIMBRE DE TURNO (su esbirro) con Gemini. Escribe en assets/sprites/enemies/perineo/prostata/ y perineo/timbre/.

Uso: python3 tools/gen_ventanilla_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_ventanilla_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_ventanilla_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/ventanilla/:
  vent_a vent_b vent_c (sano) + _p2 y _p3 de cada una (dano visible) + timbre      (10 llamadas; tope 14)
Referencia de diseno: tools/_intro_raw/prostata_v2.png (caratula, fuera de git; ruta absoluta mas abajo).
Partes de build: vent (176x184 -> prostata_sheet{,_p2,_p3}.png + prostata_sprite_frames{,_p2,_p3}.tres)
                 timbre (32x48 -> timbre_*_NN.png + timbre_sprite_frames.tres)
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
RAW = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/ventanilla")
GEM.RAW = RAW
T.RAW = RAW
COVER = Path("/home/nick/Escritorio/Proyectos/soul_knight/tools/_intro_raw/prostata_v2.png")
DEST = ROOT / "assets/sprites/enemies/perineo/prostata"
RES = "res://assets/sprites/enemies/perineo/prostata/"
SDEST = ROOT / "assets/sprites/enemies/perineo/timbre"
SRES = "res://assets/sprites/enemies/perineo/timbre/"

# ------------------------------------------------------------------ prompts
_NOTEXT = (
    " ABSOLUTELY NO TEXT of any kind: no letters, no words, no digits, no numbers, no captions, no pose names, no labels; paper "
    "sheets, tickets, badges and signs show only blank lines or tiny abstract scribble squiggles, never readable characters; the "
    "bottom of every cell is empty green. "
)
_BOSS = (
    "THE BOSS 'La Ventanilla Unica' (the One-Window), a cartoon BUREAUCRAT shaped like a WALNUT-SIZED PROSTATE gland: a rounded "
    "walnut-brown peach-orange body (nut-shaped, wider at the top, with a vertical center crease line like a coffee bean, a lighter "
    "highlight on the left and darker brown shading on the right), a tiny dark tuft of hair on top, small round glasses with thin "
    "dark frames over two white eyes with black pupils and flat deadpan brows, a flat straight mouth (serious, tired, pedantic), a "
    "slate-grey-blue NECKTIE hanging down the front, a small white-and-blue ID badge pinned on the chest, tiny dark stubby arms "
    "(little brown nubs that can hold a paper) and two short dark legs with navy shoes. Humorous satirical caricature of a bureaucratic "
    "gland ('first you must get the check-up'), family friendly, never mocking health. Palette: walnut orange-brown, cream paper white, "
    "slate grey-blue, navy, a touch of muted red. Same character, same proportions, same colors and same design as the reference image, "
    "but redrawn with much more detail, richer shading and a premium look. "
)
_ORDER = (
    " All poses are the SAME character at the SAME scale and the same camera, full body visible and standing on its feet (feet at "
    "the bottom of the cell, no ground line), a single big character per cell, no extra characters except the props named. Effects "
    "and flying papers stay very close to the body and inside the cell. " + _NOTEXT
)
_DMG2 = (
    "It is the DAMAGED PHASE 2 of the SAME character as the reference sheet: same poses in the same order and positions, same design, "
    "but clearly stressed and battle-damaged: the glasses are crooked with a cracked lens, the necktie is loosened and crooked, "
    "a few cream papers are torn with ragged edges, a few cracks and a chip on the nut-shell body, a sweat drop, narrowed angrier eyes, "
    "darker shadows. "
)
_DMG3 = (
    "It is the HEAVILY DAMAGED, ENRAGED PHASE 3 of the SAME character as the reference sheet: same poses in the same order, same design, "
    "but frantic and furious: glasses bent and one lens shattered, the necktie half undone and hanging in tatters, papers shredded "
    "and crumpled, the nut-shell body deeply CRACKED with a big split along the crease and chipped pieces, bloodshot wide angry eyes "
    "with tiny pupils, a gritted mouth, messy tuft of hair, a faint red rage aura. "
)
_POSES_A = (
    "Poses left to right, top row: (1) neutral IDLE standing, one tiny hand holding a clipboard paper, deadpan stare; "
    "(2) WALK frame 1: stepping forward with the right leg, leaning slightly to the right, a paper under the arm; (3) WALK frame 2: "
    "the other leg forward, body bobbing; (4) dramatic INTRO: arriving, arms spread with papers fluttering around him, glasses "
    "glinting, smug and imposing. Bottom row: (5) CALL-A-TURN WIND-UP: leaning back, pressing a hand on a small red ticket-number "
    "dispenser gadget held in front of him, glowing (no digits on it), a bit of gold light; (6) CALL-A-TURN RELEASE: leaning forward, "
    "arm thrust to the right pointing at the viewer's target in a 'NEXT!' gesture, small cream paper tickets flying out to the right "
    "with motion lines; (7) PAPERWORK WIND-UP: gathering a big armful of papers and forms, hunched, papers swirling around him; "
    "(8) PAPERWORK RELEASE: spinning mid-twirl, a spiral of papers flung outwards with motion lines, arms wide."
)
_POSES_B = (
    "Poses left to right, top row: (1) TICKET WIND-UP: tearing a cream ticket strip from a roll in both hands, glowing "
    "gold circles appearing around his feet; (2) TICKET RELEASE: slamming a ticket stamp down in front, rings of "
    "light and flying paper tickets; (3) RUSH HOUR WIND-UP: arms raised calling the crowd, a bell raised, a line of tiny silhouette "
    "people shadows queuing behind him (just dark grey blobs); (4) RUSH HOUR RELEASE: arms wide pointing sideways, a stampede wave "
    "of cream paper sheets flowing across with motion lines. Bottom row: (5) CUBICLES WIND-UP: holding up a floor-plan sheet, "
    "grid shape of 3x3 boxes drawn glowing in the air around him; (6) CUBICLES RELEASE: slamming both fists on the counter, the "
    "grid boxes snapping shut like shutters with sparks; (7) CHARGE WIND-UP: tilted forward like a bull about to ram, head down, "
    "glasses glinting red, a stack of papers like a battering ram in front, red-orange glow; (8) CHARGE: stretched long, "
    "running forward horizontally to the right at full speed, papers flying behind, long speed lines."
)
_POSES_C = (
    "Poses left to right, top row: (1) CALL THE BELLS: raising a small brass counter service bell in one hand and ringing it, "
    "little gold ring arcs around the bell, mouth open calling, tiny sparkles; (2) CHANNELING A HEALING: eyes closed, serene, "
    "arms raised, a warm gold and cream aura, tiny plus signs and sparkles rising, a cup of coffee floating; (3) EXHAUSTED: "
    "sagging and slumped, glasses slipping down his nose, tie hanging limp, eyes half shut, panting, a sweat drop, papers slipping "
    "from his hands; (4) STUNNED and dizzy: tilted and wobbling, swirly spiral eyes behind the glasses, tiny stars circling the "
    "tuft, a stamp bouncing. Bottom row: (5) flinching pose, flinching, tilted back, eyes squeezed shut, the mouth a gasp, papers "
    "bursting off, a small spray of sparks; then a theatrical DEATH in 3 steps: (6) shaking, the nut-shell cracking all over, glasses "
    "flying off, papers flying; (7) glowing white-hot from inside, the body bulging, cracks of light, the tie flapping; (8) fallen "
    "apart: the nut-shell broken into two halves lying flat with a pile of papers, X-shaped eyes on the biggest half, a tiny white "
    "flag, a tiny ghost leaving."
)
_TIMBRE = (
    "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses), the SAME tiny creature at the same scale in each cell. "
    "THE ENEMY 'Timbre de turno': a small cute grumpy brass counter SERVICE BELL (the dome kind with a button on top) with two "
    "tiny dark stubby legs and navy shoes, two small white eyes with black pupils and angry brows on the dome, a little flat mouth, "
    "brass gold-yellow with a darker amber shading and a pale highlight, a round silver-grey base. Cute but aggressive and humorous. "
    "Palette: brass gold-yellow, amber, silver-grey, navy, a touch of cream. Poses left to right, top row: (1) idle standing; "
    "(2) idle frame 2: hopping slightly, button up; (3) WARNING pose: shaking, glowing bright yellow-white, a clear thick ring "
    "(a circular shockwave outline) drawn around it, eyes wide; (4) DING release: the button pressed, the bell flaring open with "
    "four small gold dots flying out in a cross shape (up, down, left, right) and a bright ring. Bottom row: (5) flinching pose, "
    "flinching, eyes squeezed shut, dent in the dome, sparks; (6) death part one: cracked and smoking, spinning eye, the button "
    "popping off; (7) death part two: bursting into brass pieces, the dome and the base flying apart; (8) death part three: a "
    "tiny puff with few brass bits and a small ghost leaving."
) + _NOTEXT

PROMPTS = {}
for _k, _p in (("a", _POSES_A), ("b", _POSES_B), ("c", _POSES_C)):
    _lead = "BOSS SPRITE SHEET with exactly 2 rows of 4 large poses (8 poses)."
    PROMPTS[f"vent_{_k}"] = STYLE + _lead + _ORDER + _BOSS + _p
    PROMPTS[f"vent_{_k}_p2"] = STYLE + _lead + " " + _DMG2 + _ORDER + _BOSS + _p
    PROMPTS[f"vent_{_k}_p3"] = STYLE + _lead + " " + _DMG3 + _ORDER + _BOSS + _p
_MATCH = (
    " STYLE MATCH (critical): keep EXACTLY the silhouette, proportions, face size, glasses size and body shape of the reference "
    "sheet, the same chunky pixel size and 1-pixel dark outline, the same pose composition in every cell; only add the damage "
    "described. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
)
for _n in list(PROMPTS):
    if _n.endswith("_p2") or _n.endswith("_p3"):
        PROMPTS[_n] += _MATCH
for _n in ("vent_b", "vent_c"):
    PROMPTS[_n] += (
        " STYLE MATCH (critical): the reference sheet(s) show the approved look. Copy it EXACTLY: the same flat matte walnut "
        "orange-brown body with the center crease, the same round glasses, the same grey-blue tie, the same chunky pixel size and "
        "1-pixel dark outline. No glossy plastic highlights, no smooth airbrushed shading. Do NOT write pose names or any caption."
    )
PROMPTS["timbre"] = STYLE + _TIMBRE
GEN_ORDER = ["vent_a", "vent_b", "vent_c", "vent_a_p2", "vent_b_p2", "vent_c_p2", "vent_a_p3", "vent_b_p3", "vent_c_p3", "timbre"]


def _cover(box):
    c = Image.open(COVER).convert("RGB").crop(box)
    return c.resize((c.width * 2, c.height * 2), Image.NEAREST)


def gen(names):
    boss_ref = _cover((500, 190, 880, 535))
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        if n == "vent_a":
            refs = [boss_ref]
        elif n in ("vent_b", "vent_c"):
            refs = [boss_ref, Image.open(RAW / "vent_a.png")]
        elif n == "timbre":
            refs = [Image.open(RAW / "vent_c.png")] if (RAW / "vent_c.png").exists() else [boss_ref]
        else:
            base, suf = n.rsplit("_", 1)
            refs = [Image.open(RAW / f"{base}.png")]
            if base != "vent_a":
                refs.append(Image.open(RAW / f"vent_a_{suf}.png"))
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K", refs=refs)
        print("LLAMADA a Gemini:", n)


# ------------------------------------------------------------------ jefa 176x184
TW, TH = T.TW, T.TH
VARIANTS = {"": ("vent_a", "vent_b", "vent_c"), "_p2": ("vent_a_p2", "vent_b_p2", "vent_c_p2"), "_p3": ("vent_a_p3", "vent_b_p3", "vent_c_p3")}


def boss_poses(suffix):
    na, nb, nc = VARIANTS[suffix]
    a, b, c = T._grid(na), T._grid(nb), T._grid(nc)
    raw = dict(idle=a[0], w1=a[1], w2=a[2], intro=a[3], turw=a[4], turr=a[5], papw=a[6], papr=a[7],
               tikw=b[0], tikr=b[1], colw=b[2], colr=b[3], cubw=b[4], cubr=b[5], chw=b[6], chr=b[7],
               belw=c[0], channel=c[1], tired=c[2], stun=c[3], hurt=c[4], x1=c[5], x2=c[6], x3=c[7])
    return T.fit(raw, TW, TH, 150)


def boss_anims(P):
    xf = A.xf
    I = P["idle"]
    f = {}
    f["idle"] = [I, xf(I, sy=0.985), I, xf(I, sx=1.01, sy=0.99)]
    f["walk"] = [P["w1"], xf(I, dy=-2), P["w2"], xf(I, dy=-2)]
    f["intro"] = [P["intro"], P["intro"], xf(P["intro"], sy=1.02), I]
    f["attack"] = f["attack_turnos"] = [I, xf(P["turw"], rot=-2), P["turw"]]
    f["release"] = f["release_turnos"] = [P["turr"], xf(P["turr"], dx=2), xf(P["turr"], dy=1)]
    f["attack_papeleo"] = [I, xf(P["papw"], sy=0.98), P["papw"]]
    f["release_papeleo"] = [P["papr"], xf(P["papr"], rot=3), P["papr"], xf(P["papr"], rot=-3)]
    f["attack_ticket"] = [I, xf(P["tikw"], sy=0.98), P["tikw"]]
    f["release_ticket"] = [P["tikr"], xf(P["tikr"], dy=1), P["tikr"]]
    f["attack_cola"] = [I, xf(P["colw"], dy=-1), P["colw"]]
    f["release_cola"] = [P["colr"], xf(P["colr"], dx=2), P["colr"], xf(P["colr"], dx=-2)]
    f["attack_cubiculos"] = [I, xf(P["cubw"], sy=0.98), P["cubw"]]
    f["release_cubiculos"] = [P["cubr"], xf(P["cubr"], sy=0.97), P["cubr"]]
    f["attack_embestida"] = [I, xf(P["chw"], sy=0.97), P["chw"], xf(P["chw"], dx=-1)]
    f["charge"] = [P["chr"], xf(P["chr"], dx=3), P["chr"]]
    f["attack_timbres"] = [I, xf(P["belw"], dy=-1), P["belw"]]
    f["release_timbres"] = [P["belw"], xf(P["belw"], dy=-2, rot=2), xf(P["belw"], dy=-1, rot=-2), P["belw"]]
    f["tired"] = [P["stun"], xf(P["stun"], dy=1)]  # aturdida: mareo (distinto del agotamiento)
    f["recover_in"] = [P["tired"]]
    f["recover"] = [P["tired"], xf(P["tired"], dy=1), P["tired"], xf(P["tired"], dy=2, sy=0.99)]  # agotada: jadea y se hunde
    f["stun_in"] = [P["hurt"], P["stun"]]
    f["channel"] = [P["channel"], xf(P["channel"], dy=-2), P["channel"], xf(P["channel"], dy=-1)]
    f["hurt"] = [P["hurt"], P["hurt"], xf(P["hurt"], dx=-1)]
    f["brake"] = [P["chw"], xf(P["chw"], sy=0.98)]
    f["blink"] = [I, I]
    f["idle_stir"] = [xf(I, rot=-2), xf(I, rot=2), I]
    f["idle_impatient"] = [xf(I, dy=-2), I, xf(I, dy=-2), I]
    f["death"] = [P["hurt"], P["x1"], xf(P["x1"], dx=1), P["x2"], xf(P["x2"], dx=-1), P["x3"], P["x3"]]
    return f


T.META.update({"idle": (4.0, True), "walk": (8.0, True)})
for _n in ("turnos", "papeleo", "ticket", "cola", "cubiculos", "embestida", "timbres"):
    T.META["attack_" + _n] = (12.0, False)
    T.META["release_" + _n] = (14.0, False)
T.META["charge"] = (14.0, True)


def build_vent():
    DEST.mkdir(parents=True, exist_ok=True)
    for suf in VARIANTS:
        n = T._tres(boss_anims(boss_poses(suf)), DEST / f"prostata_sheet{suf}.png", f"{RES}prostata_sheet{suf}.png", TW, TH, 6,
                    DEST / f"prostata_sprite_frames{suf}.tres")
        print("ventanilla", suf or "_p1", n, "cuadros")
    for old in DEST.glob("prostata_*_[0-9][0-9].png*"):
        old.unlink()  # cuadros sueltos del arte provisorio (40x60): ahora todo va en la hoja


# ------------------------------------------------------------------ timbre 32x48
SW_, SH_ = 32, 48


def timbre_poses():
    g = T._grid("timbre", 30, 40)
    raw = dict(zip(("idle", "idle2", "warn", "ding", "hurt", "d1", "d2", "d3"), (g[i] for i in range(8))))
    raw = {k: A.trim(v) for k, v in raw.items()}
    s = 36.0 / raw["idle"].height
    out = {}
    for k, v in raw.items():
        m = min(1.0, 31.0 / (v.width * s), 47.0 / (v.height * s))
        w, h = max(1, round(v.width * s * m)), max(1, round(v.height * s * m))
        cv = Image.new("RGBA", (SW_, SH_), (0, 0, 0, 0))
        cv.alpha_composite(A.down(v, w, h), (max(0, (SW_ - w) // 2), SH_ - h - 1))
        out[k] = cv
    print("  timbre escala", round(s, 3))
    return A.quantize_set(out, 32)


def build_timbre():
    P = timbre_poses()
    xf = A.xf
    I = P["idle"]
    f = {"idle": [I, P["idle2"]], "walk": [P["idle2"], I, xf(I, dy=-1), P["idle2"]],
         "attack": [P["warn"], xf(P["warn"], dx=1), P["warn"], xf(P["warn"], dx=-1)], "ding": [P["ding"], xf(P["ding"], dy=-1)],
         "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)], "death": [P["d1"], P["d2"], P["d3"], P["d3"]]}
    speeds = {"idle": (4.0, True), "walk": (8.0, True), "attack": (16.0, True), "ding": (12.0, False), "hurt": (10.0, False), "death": (8.0, False)}
    SDEST.mkdir(parents=True, exist_ok=True)
    for old in SDEST.glob("timbre_*"):
        old.unlink()
    res, anim = [], []
    for n, lst in f.items():
        fr = []
        for i, im in enumerate(lst):
            im.save(SDEST / f"timbre_{n}_{i:02d}.png")
            rid = f"{n}{i}"
            res.append(f'[ext_resource type="Texture2D" path="{SRES}timbre_{n}_{i:02d}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        sp, loop = speeds[n]
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
    (SDEST / "timbre_sprite_frames.tres").write_text(
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
        sheet(tiles, TW, TH, 8, 1).convert("RGB").save(dest / f"ventanilla{suf}_poses_x1.png")
        sheet(tiles, TW, TH, 6, 2).convert("RGB").save(dest / f"ventanilla{suf}_poses_x2.png")
    sat = list(timbre_poses().items())
    sheet(sat, SW_, SH_, 8, 1).convert("RGB").save(dest / "timbre_x1.png")
    sheet(sat, SW_, SH_, 8, 4).convert("RGB").save(dest / "timbre_x4.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        parts = args or ["vent", "timbre"]
        if "vent" in parts:
            build_vent()
        if "timbre" in parts:
            build_timbre()
    elif cmd == "preview":
        preview(args[0] if args else ".")
