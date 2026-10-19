"""Arte DEFINITIVO de DONA VENTANILLA (jefa alternativa femenina del Perineo, frente al Aduanero; id interno "prostata") y del
TIMBRE DE TURNO (su esbirro) con Gemini. Escribe en assets/sprites/enemies/perineo/prostata/ y perineo/timbre/.

Uso: python3 tools/gen_dona_ventanilla_art.py gen [hoja ...]     llama a Gemini (una llamada por hoja, solo las que falten; con nombre, la rehace)
     python3 tools/gen_dona_ventanilla_art.py build [parte ...]  recorta, pixela, interpola y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_dona_ventanilla_art.py preview DIR        hojas de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro), originales en .claude/arte_fuente/dona_ventanilla/:
  vent_a vent_b vent_c (sano) + _p2 y _p3 de cada una (dano visible)      (9 llamadas; tope 14; el timbre se reutiliza de la rama nuez)
Referencia de diseno: tools/_intro_raw/prostata_v3.png (caratula, fuera de git; ruta absoluta mas abajo).
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
RAW = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/dona_ventanilla")
GEM.RAW = RAW
T.RAW = RAW
COVER = Path("/home/nick/Escritorio/Proyectos/soul_knight/tools/_intro_raw/prostata_v3.png")
DEST = ROOT / "assets/sprites/enemies/perineo/prostata"
RES = "res://assets/sprites/enemies/perineo/prostata/"
SDEST = ROOT / "assets/sprites/enemies/perineo/timbre"
SRES = "res://assets/sprites/enemies/perineo/timbre/"

# ------------------------------------------------------------------ prompts
_NOTEXT = (
    " ABSOLUTELY NO TEXT of any kind anywhere in the image: no letters, no words, no digits, no numbers, no captions, no pose "
    "names, no labels, no signs with writing; paper sheets, tickets, the number dispenser and the shutter sign show only blank "
    "lines or tiny abstract scribble squiggles, never readable characters; the bottom 25% of every cell is empty flat green with nothing in it (no caption, no label, no pose name). Do not draw divider lines between cells. "
)
_BOSS = (
    "THE BOSS 'Dona Ventanilla' (Lady Window), a cartoon BUREAUCRAT that is a walking beige customer-service BOOTH (a tall boxy "
    "service counter kiosk, flat matte beige-tan panels with small rivets) with two thin skinny tan LEGS and flat shoes and two "
    "thin long tan ARMS with pointy hot-pink painted fingernails. The glass window of the booth is HER FACE: pale blue glass with a "
    "diagonal glint, two bored half-lidded eyes with heavy eyelids and arched brows, black cat-eye glasses with a beaded chain "
    "hanging down on both sides, red lips blowing a pink chewing-gum bubble. Above the glass a grey metal ROLL-UP SHUTTER (rolled "
    "cylinder on top) hangs like a drooping eyelid. On top of the shutter sits a big hairdo of pink hair-curlers (rollers) with "
    "brown curled hair. On the right side of the booth is a RED ticket-number dispenser box with a paper ticket hanging out of it. "
    "She can hold a rubber stamp in one hand and a small silver counter service bell in the other. Humorous satirical caricature "
    "of the bureaucracy of a health clinic ('take a number and wait'), family friendly, never mocking people. Palette: beige tan, "
    "pale glass blue, steel grey, hot pink, brown, red, cream paper white. Same character, same proportions, same colors and "
    "same design as the reference image, but redrawn as a clean game sprite with a premium look. "
)
_ORDER = (
    " All poses are the SAME character at the SAME scale and the same camera, full body visible and standing on its feet (feet at "
    "the bottom of the cell, no ground line and NO dark ellipse shadow under the feet), a single big character per cell, no extra characters except the props named. Effects "
    "and flying papers stay very close to the body and inside the cell. " + _NOTEXT
)
_DMG2 = (
    "It is the DAMAGED PHASE 2 of the SAME character as the reference sheet: same poses in the same order and positions, same design, "
    "but clearly stressed and battle-damaged: the glass window is CRACKED with a spider-web fracture, a few pink curlers have come "
    "loose and hair strands stick out, the roll-up shutter is slightly crooked and dented, the red dispenser is dented with a torn "
    "ticket, a few cream papers are torn, dents and scratches on the beige panels, a sweat drop, narrowed angrier eyes, darker shadows. "
)
_DMG3 = (
    "It is the HEAVILY DAMAGED, ENRAGED PHASE 3 of the SAME character as the reference sheet: same poses in the same order, same design, "
    "but frantic and furious: the glass is shattered with big cracks and a missing corner, most curlers have fallen off and the hair "
    "is a messy frizzy tangle, the shutter hangs bent and half off one side, the red dispenser is broken and sparking, the cat-eye "
    "glasses bent, papers shredded, deep dents in the beige panels, bloodshot wide angry eyes with tiny pupils, gritted teeth, a "
    "faint red rage aura. "
)
_POSES_A = (
    "Poses left to right, top row: (1) neutral IDLE standing, one hand holding the rubber stamp, bored half-lidded stare, chewing gum; "
    "(2) WALK frame 1: stepping forward with the right leg, the whole booth tilting slightly right, the other hand holding the "
    "bell; (3) WALK frame 2: the other leg forward, the booth tilting slightly left; (4) dramatic INTRO: arriving, arms spread wide, "
    "the shutter rolled up fully so the eyes are wide open and smug, papers fluttering around, imposing. Bottom row: (5) CALL-A-TURN "
    "WIND-UP: leaning back, pressing a hand on the red ticket dispenser, glowing, a ticket sliding out (no digits on it), a bit of "
    "gold light; (6) CALL-A-TURN RELEASE: leaning forward, arm thrust to the right pointing with a pink fingernail in a calling-the-next-person "
    "gesture, small cream paper tickets flying out to the right with motion lines; (7) PAPERWORK WIND-UP: gathering a big armful of "
    "papers and forms, hunched, papers swirling around her; (8) PAPERWORK RELEASE: spinning mid-twirl, a spiral of papers flung "
    "outwards with motion lines, arms wide."
)
_POSES_B = (
    "Poses left to right, top row: (1) TICKET WIND-UP: tearing a long cream ticket strip out of the red dispenser with both hands, "
    "glowing gold circles appearing around her feet; (2) TICKET RELEASE: slamming the rubber stamp down in front, rings of "
    "light and flying paper tickets; (3) RUSH HOUR WIND-UP: arms raised calling the crowd, the bell raised, a line of tiny silhouette "
    "people shadows queuing behind her (just dark grey blobs); (4) RUSH HOUR RELEASE: arms wide pointing sideways, a stampede wave "
    "of cream paper sheets flowing across with motion lines. Bottom row: (5) CUBICLES WIND-UP: the roll-up shutter lowering over "
    "the glass face, a grid shape of 3x3 boxes drawn glowing in the air around her; (6) CUBICLES RELEASE: the shutter slammed "
    "completely shut over the glass (blank grey slats), both fists slammed on the counter, the grid boxes snapping shut with sparks; "
    "(7) CHARGE WIND-UP: tilted forward like a bull about to ram, the booth leaning, shutter half-down like angry brows, curlers "
    "bristling, a red-orange glow; (8) CHARGE: stretched long, running forward horizontally to the right at full speed, papers "
    "flying behind, long speed lines."
)
_POSES_C = (
    "Poses left to right, top row: (1) CALL THE BELLS: raising the small silver counter service bell in one hand and ringing it, "
    "little gold ring arcs around the bell, lips pursed calling, tiny sparkles; (2) CHANNELING A HEALING on a COFFEE BREAK: eyes "
    "closed, serene, holding a steaming cup of coffee in one hand, a warm gold and cream aura, tiny plus signs and sparkles rising, "
    "the gum bubble floating; (3) EXHAUSTED: sagging and slumped, the shutter drooped completely half-shut, glasses slipping, "
    "panting, a sweat drop, papers slipping from her hands, the curlers drooping; (4) STUNNED and dizzy: tilted and wobbling, swirly "
    "spiral eyes behind the glasses, tiny stars circling the curlers, the stamp bouncing. Bottom row: (5) flinching pose, flinching, "
    "tilted back, eyes squeezed shut, the mouth a gasp, the gum bubble popping, papers bursting off, a small spray of sparks; then a "
    "theatrical DEATH in 3 steps: (6) shaking, the glass cracking all over, curlers flying off, papers flying; (7) glowing white-hot "
    "from inside, the booth bulging, cracks of light, the shutter rattling; (8) fallen: the roll-up shutter fully CLOSED over the "
    "whole window, a BLANK white cardboard sign hanging on it (no writing, completely empty), curlers scattered, a pile of papers, "
    "a tiny ghost leaving."
)

# descripciones en minusculas y sin palabras entre comillas: Gemini rotulaba las poses con las mayusculas
_POSES_A, _POSES_B, _POSES_C = _POSES_A.lower(), _POSES_B.lower(), _POSES_C.lower()
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
        " STYLE MATCH (critical): the reference sheet(s) show the approved look. Copy it EXACTLY: the same flat matte beige booth "
        "with rivets, the same pale blue glass face, the same cat-eye glasses with beaded chain, the same pink curlers, the same "
        "red dispenser, the same chunky pixel size and 1-pixel dark outline. No glossy plastic highlights, no smooth airbrushed "
        "shading. Do NOT write pose names or any caption."
    )
# el Timbre de turno (campanita de mostrador) se reutiliza de la rama nuez: combina con la campanita de Dona Ventanilla
GEN_ORDER = ["vent_a", "vent_b", "vent_c", "vent_a_p2", "vent_b_p2", "vent_c_p2", "vent_a_p3", "vent_b_p3", "vent_c_p3"]


def _cover(box):
    c = Image.open(COVER).convert("RGB").crop(box)
    return c


def gen(names):
    boss_ref = _cover((360, 15, 1100, 690))
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
        print("dona ventanilla", suf or "_p1", n, "cuadros")
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
        sheet(tiles, TW, TH, 8, 1).convert("RGB").save(dest / f"dona_ventanilla{suf}_poses_x1.png")
        sheet(tiles, TW, TH, 6, 2).convert("RGB").save(dest / f"dona_ventanilla{suf}_poses_x2.png")
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
