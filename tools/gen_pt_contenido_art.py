"""Arte de los 6 enemigos nuevos y las 4 armas nuevas de LA PUERTA TRASERA (reino secreto del Perineo), con Gemini.
Escribe en assets/sprites/enemies/puerta_trasera/<enemigo>/ y assets/sprites/items|projectiles/ (armas).

Uso: python3 tools/gen_pt_contenido_art.py gen [hoja ...]     llama a Gemini (UNA llamada por hoja; solo las que falten)
     python3 tools/gen_pt_contenido_art.py build [parte ...]  recorta, pixela y escribe PNG + .tres (sin args = todo)
     python3 tools/gen_pt_contenido_art.py preview DIR        hoja de contacto de los sprites nuevos
Hojas (7 llamadas; tope del encargo: 14), originales en el repo principal .claude/arte_fuente/puerta_trasera/
(respaldo en ~/Vídeos/Rogue Reproductive/arte_gemini_original/puerta_trasera/):
  fisura pujon cartel aceite todos polipo   (2 filas x 4 poses: reposo, caminar, aviso, golpe, herido, muerte x3)
  armas                                      (fila 1: 4 iconos de arma; fila 2: sus 4 proyectiles)
"""
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_aduanero_art as AD  # noqa: E402  (_sin_rotulo / _sin_astillas)
import gen_testiculo_art as T  # noqa: E402
import arc2_gemini as GEM  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402
from arc2_gemini import STYLE  # noqa: E402

ROOT = GEM.ROOT
RAW = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/puerta_trasera")
BACKUP = Path.home() / "Vídeos/Rogue Reproductive/arte_gemini_original/puerta_trasera"
GEM.RAW = RAW
T.RAW = RAW
EDIR = ROOT / "assets/sprites/enemies/puerta_trasera"
ERES = "res://assets/sprites/enemies/puerta_trasera/"

_NOTEXT = (" ABSOLUTELY NO TEXT: never write letters, numbers, words, captions, pose names, labels or signs anywhere in the image; "
           "the bottom of every cell is empty green.")
_ORDER = (
    " The sheet has exactly 2 rows of 4 poses (8 poses) of the SAME tiny creature at the SAME scale and camera, full body "
    "visible, standing on the ground (feet at the bottom of the cell), one single character per cell, nothing else. Small "
    "effects (dust, drops, sparkles) stay very close to the body and inside the cell." + _NOTEXT
)
_POSES = (
    " Poses left to right, top row: (1) idle standing; (2) walking step; (3) WARNING pose: {aviso}; (4) ATTACK: {ataque}. "
    "Bottom row: (5) hurt, flinching with squashed body and closed eyes; (6) death part one: {m1}; (7) death part two: {m2}; "
    "(8) death part three: {m3}."
)
_TONE = (" Humorous, cute-grumpy, family-friendly cartoon mascot, not gross, no blood, no anatomy, nothing realistic. "
         "Same design and proportions in every pose. ")

ENEMIES = {
    "fisura": dict(
        size=(32, 48), idle_h=38,
        body=("THE ENEMY 'Fisura Fina' (Thin Fissure): a small chunk of pale beige bathroom TILE shaped like a tall thin shard, with a "
              "big jagged dark-brown lightning-shaped CRACK running down its face, two tiny narrow wincing eyes, a small pained "
              "grimace, a tiny cartoon adhesive bandage across one corner, two thin quick legs and tiny arms. Palette: beige, "
              "cream, dark brown crack, a touch of pink bandage."),
        aviso="crouching low, the crack glowing orange, leaning forward ready to dash, eyes narrowed",
        ataque="DASHING forward fast, body stretched thin like a lightning bolt with speed lines, leaving a small dark crack mark behind",
        m1="splitting along its crack in two halves", m2="two halves falling apart with tiny tile chips flying",
        m3="two small broken tile halves on the ground, the bandage fluttering down"),
    "pujon": dict(
        size=(40, 48), idle_h=38,
        body=("THE ENEMY 'Pujon' (The Strainer): a plump round tomato-red balloon creature with a straining face (eyes squeezed shut, "
              "gritted teeth, a big sweat drop and a tiny vein mark on the forehead), two tiny stubby legs, one tiny hand holding a "
              "small smartphone (a classic bathroom-scrolling joke) and a roll of toilet paper tucked under the other arm. Palette: "
              "tomato red, pink, cream paper, dark grey phone."),
        aviso="INFLATED to nearly double size, puffed cheeks, turning deeper red, trembling lines around the body, phone dropped",
        ataque="releasing the pressure: body squashed wide like a pop with a big circular shockwave burst of lines and puffs around it",
        m1="deflating with a surprised face, a puff of air", m2="flat and wrinkly like a limp deflated balloon on the ground",
        m3="a tiny relieved smiling deflated shape with a small heart above it"),
    "cartel": dict(
        size=(36, 48), idle_h=42,
        body=("THE ENEMY 'Cartel Falso' (Fake Sign): a wooden warning SIGN on a short post, the sign board is a bright red rectangle with "
              "a thick yellow border and TWO huge white exclamation marks (symbols only, no words), with a smug lying smirk and one raised "
              "eyebrow, two small round shifty eyes on the board, two stubby wooden legs at the bottom of the post and thin stick arms. "
              "Palette: warning red, yellow, wood brown, white."),
        aviso="leaning back with the board tilted, a sly smirk, one eye winking and one hand with crossed fingers behind its back",
        ataque="charging forward leaning the sign board like a battering ram, mouth open shouting, speed lines",
        m1="the board cracking in the middle", m2="the board flipped around showing a calm green sign with a big white check mark and a smiley face, no text",
        m3="the green sign lying flat on the ground with a small smiling face and little sparkles"),
    "aceite": dict(
        size=(32, 48), idle_h=38,
        body=("THE ENEMY 'Aceite Traicionero' (Treacherous Oil): a small glass BOTTLE of golden-amber oil with a little cork, a plain "
              "blank cream label (no text) with only a simple oil drop icon, a sly grin with half-lidded sneaky eyes and one raised "
              "eyebrow, tiny arms, tiny feet, a slick golden puddle dripping beneath it. Palette: amber gold, glass teal highlights, cork "
              "tan, cream label."),
        aviso="tilting forward pouring a big slick golden puddle from the neck, a mischievous smile",
        ataque="sliding forward on its own oil puddle like on a skate, arms spread, a trail of golden shine behind",
        m1="slipping on its own oil with a shocked face, feet in the air", m2="bottle lying on its side, the cork popped, oil spilling",
        m3="an empty bottle lying on its side with a tiny ghost drop leaving"),
    "todos": dict(
        size=(32, 48), idle_h=38,
        body=("THE ENEMY 'Todos-lo-Hacen' (Everybody-Does-It, peer pressure): a small round lavender-blue blob creature with a huge "
              "overly-friendly pushy toothy grin and wide eyes, a little striped party hat, one stubby arm waving 'come on' and a tiny "
              "pennant flag reading nothing (blank). A cheerful bandwagon pressure mascot. Palette: lavender, light blue, white teeth, "
              "yellow hat stripes."),
        aviso="arms wide open, grin even bigger, calling for friends with little sound-wave arcs, a bright glow",
        ataque="bouncing forward in a hurry like a crowd rushing, leaning, arms swinging, motion lines",
        m1="the grin dropping into a surprised 'oh' face, the hat flying off", m2="shrinking and wobbling with sparkles as the pressure fades",
        m3="a tiny polite lavender puff with a small white flag and a small 'no thanks' hand wave"),
    "polipo": dict(
        size=(32, 48), idle_h=36,
        body=("THE ENEMY 'Polipo Callado' (Silent Polyp): a very quiet small pale pink-beige MUSHROOM-like growth on a short thick stalk, "
              "round smooth cap, closed sleepy eyes and a tiny shy closed smile, a faint semi-transparent ghostly look, tiny stubby base "
              "roots, a tiny 'shhh' finger gesture. Cute, calm and a bit eerie. Palette: pale pink, cream, soft lilac shadows, a touch of mint."),
        aviso="waking: eyes opening wide, the cap growing bigger and blushing, small wobble lines",
        ataque="puffing out a ring of tiny spores from the cap, body leaning back, eyes wide",
        m1="the cap wilting with a surprised face", m2="shrinking back to a tiny stalk with sparkles",
        m3="a tiny stalk with a small relieved smile and a little check-mark sparkle"),
}

WEAPONS = (
    "WEAPON ICON SHEET with exactly 2 rows of 4 items (8 items), each item alone in its own cell, no characters. TOP ROW: four "
    "handheld weapon item icons, all drawn pointing to the right, side view: (1) 'Ducha Anal': a handheld bidet / hand shower sprayer "
    "with a chrome nozzle head, a pistol-like grip and a short coiled blue hose, with tiny water drops; (2) 'Globocondon': a small "
    "blue-and-white balloon pump gun that inflates a big translucent teal latex balloon at its muzzle (a bubble-launching toy gun); "
    "(3) 'Lubricante a base de agua': a translucent light-blue pump bottle with a pump nozzle and a blank white label (no text) with a "
    "single water drop icon, a glossy blob dripping from the nozzle; (4) 'Fibra Canon': a small wooden toy cannon stuffed with oat "
    "grains and wheat ears with a little bowl of bran, warm tan and golden colors. BOTTOM ROW: the matching PROJECTILES, each tiny "
    "and simple, all in one cell each, same order: (5) a streak of blue pressurized water jet with droplets; (6) a round translucent "
    "teal latex balloon bubble with a white highlight and a small knot; (7) a glossy light-blue slippery blob of lube with a bright "
    "highlight; (8) a few golden oat grains / bran flakes in a small cluster. Palette per item as described, 1-pixel dark outline. "
    "Humorous but family-friendly, nothing explicit." + _NOTEXT
)

PROMPTS = {}
for _k, _e in ENEMIES.items():
    PROMPTS[_k] = (STYLE + "ENEMY SPRITE SHEET with exactly 2 rows of 4 small poses (8 poses)." + _ORDER + _e["body"] + _TONE +
                   _POSES.format(**{k: _e[k] for k in ("aviso", "ataque", "m1", "m2", "m3")}))
PUERTA = (
    "DOOR ANIMATION SHEET with exactly 3 rows of 4 cells (12 cells) of the SAME door, drawn as a front view, same size, same position "
    "and same camera in every cell, centered, nothing else in the cell. THE DOOR: a cartoon BIOLOGICAL round iris hatch, a soft pinkish-flesh "
    "colored organic sphincter-like iris of thick rubbery tissue with deep radial folds that all converge toward the center (like a camera "
    "iris or a pinched pouch), glossy highlights, set into a square frame of beige Perineum stone and bathroom TILE wall with a dark "
    "rim. Cute, caricature, silly and not realistic, nothing explicit, no anatomy details beyond a rubbery pink iris, no blood. "
    "Palette: pink, salmon, deep rose shadows, beige tile, dark brown-grey outline. Cells in reading order: (1) closed at rest; "
    "(2) closed at rest breathing in, slightly swollen; (3) closed at rest breathing out, slightly sunken; (4) closed, trembling, shifted "
    "a little to the left with small shake lines; (5) closed, trembling, shifted a little to the right with small shake lines; "
    "(6) OPENING 1: the center starts to part, folds loosening; (7) OPENING 2: the folds retracting in a spiral, a small dark hole in the middle; "
    "(8) OPENING 3: a bigger dark opening; (9) OPENING 4: the folds pulled far back in a spiral, a wide dark passage; "
    "(10) OPENING 5: nearly fully open, the folds bunched around the rim; (11) OPEN: fully open, a big round pure dark passage, the folds "
    "bunched around the rim; (12) OPEN again with a slight wobble of the folds. Keep the frame identical in all cells, only the iris changes."
    + _NOTEXT
)
PROMPTS["puerta"] = STYLE + PUERTA
PROMPTS["armas"] = STYLE.replace("Characters face RIGHT in a three-quarter top-down game view. ", "") + WEAPONS
GEN_ORDER = list(ENEMIES) + ["armas", "puerta"]


def gen(names):
    for n in names or GEN_ORDER:
        if (RAW / f"{n}.png").exists() and not names:
            continue
        print("LLAMADA a Gemini:", n, flush=True)
        GEM.generate(n, PROMPTS[n], aspect="16:9", size="2K")
        BACKUP.mkdir(parents=True, exist_ok=True)
        shutil.copy(RAW / f"{n}.png", BACKUP / f"{n}.png")


DOOR_DIR = ROOT / "assets/sprites/environment/iris_door"
DOOR_RES = "res://assets/sprites/environment/iris_door/"
# Vanessa: al abrirse, como la BOCA DE UN PEZ: se frunce y abre en "o" redonda, ritmica (o-o-o), y queda boqueando suave.
# Cuadros: 0-2 reposo (respira), 3-4 temblor, 5-10 apertura en espiral (7 = "o" chica fruncida, 9-10 = "o" ancha), 11 abierta con ondulacion.
DOOR_ANIMS = (("idle", (0, 1, 0, 2), 3.0, True), ("shake", (3, 4, 3, 4), 14.0, False),
              ("open", (5, 6, 7, 6, 8, 7, 9, 7, 10, 8, 10, 9), 10.0, False),
              ("opened", (10, 9, 8, 9, 10, 10, 11, 10), 3.5, True))


def build_puerta():
    im = T._bg(RAW / "puerta.png")
    cw, ch = im.width / 4.0, im.height / 3.0
    cells = []
    for i in range(12):
        r, c = divmod(i, 4)
        cells.append(im.crop((int(c * cw), int(r * ch), int((c + 1) * cw), int((r + 1) * ch))))
    box = None
    for c in cells:  # caja comun: todos los cuadros quedan registrados igual
        b = c.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    side = max(box[2] - box[0], box[3] - box[1])
    cx, cy = (box[0] + box[2]) // 2, (box[1] + box[3]) // 2
    sq = (cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2)
    frames = {}
    for i, c in enumerate(cells):
        f = c.crop(sq).resize((64, 64), Image.LANCZOS)
        a = np.array(f)
        a[:, :, 3] = np.where(a[:, :, 3] > 128, 255, 0)
        frames[i] = Image.fromarray(a, "RGBA")
    frames = A.quantize_set(frames, 40)
    DOOR_DIR.mkdir(parents=True, exist_ok=True)
    res, anim = [], []
    for i, f in frames.items():
        f.save(DOOR_DIR / f"iris_door_{i:02d}.png")
        res.append(f'[ext_resource type="Texture2D" path="{DOOR_RES}iris_door_{i:02d}.png" id="f{i}"]')
    for n, idx, sp, loop in DOOR_ANIMS:
        fr = ", ".join('{\n"duration": 1.0,\n"texture": ExtResource("f%d")\n}' % k for k in idx)
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (fr, "true" if loop else "false", n, sp))
    (DOOR_DIR / "iris_door_sprite_frames.tres").write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(res) + "\n\n[resource]\nanimations = [" + ", ".join(anim) + "]\n")
    print("puerta iris 12 cuadros 64x64")


def _cells(name):
    return {k: AD._sin_rotulo(v) for k, v in T._grid(name, 30, 40).items()}


def poses(name):
    cfg = ENEMIES[name]
    cw, ch = cfg["size"]
    g = _cells(name)
    raw = dict(zip(("idle", "walk", "aim", "strike", "hurt", "d1", "d2", "d3"), (A.trim(g[i]) for i in range(8))))
    s = cfg["idle_h"] / raw["idle"].height
    out = {}
    for k, v in raw.items():
        m = min(1.0, (cw - 2) / (v.width * s), (ch - 1) / (v.height * s))
        fx = T._feet_x(v)
        w, h = max(1, round(v.width * s * m)), max(1, round(v.height * s * m))
        cv = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        x0 = max(0, min(cw - w, int(round(cw / 2 - fx * s * m))))
        cv.alpha_composite(A.down(v, w, h), (x0, ch - h - 1))
        out[k] = cv
    print("  ", name, "escala", round(s, 3))
    return A.quantize_set(out, 40)


def build_enemy(name):
    P = poses(name)
    xf = A.xf
    I = P["idle"]
    f = {"idle": [I, xf(I, sy=0.98)], "walk": [P["walk"], I, xf(P["walk"], dy=-1), I],
         "attack": [P["aim"], xf(P["aim"], dx=1), P["aim"], xf(P["aim"], dx=-1)],
         "strike": [P["strike"], xf(P["strike"], dy=1)],
         "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)], "death": [P["hurt"], P["d1"], P["d2"], P["d3"], P["d3"]]}
    speeds = {"idle": (4.0, True), "walk": (8.0, True), "attack": (14.0, True), "strike": (10.0, True), "hurt": (10.0, False), "death": (7.0, False)}
    d = EDIR / name
    d.mkdir(parents=True, exist_ok=True)
    for old in d.glob(f"{name}_*"):
        old.unlink()
    res, anim = [], []
    for n, lst in f.items():
        fr = []
        for i, im in enumerate(lst):
            im.save(d / f"{name}_{n}_{i:02d}.png")
            rid = f"{n}{i}"
            res.append(f'[ext_resource type="Texture2D" path="{ERES}{name}/{name}_{n}_{i:02d}.png" id="{rid}"]')
            fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
        sp, loop = speeds[n]
        anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
    (d / f"{name}_sprite_frames.tres").write_text(
        '[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(res) + "\n\n[resource]\nanimations = [" + ", ".join(anim) + "]\n")


WEAPON_IDS = ("ducha_anal", "globocondon", "lubricante_agua", "fibra_canon")
ICON_PX = (30, 24)
PROJ_PX = {"ducha_anal": (20, 8), "globocondon": (26, 26), "lubricante_agua": (16, 16), "fibra_canon": (10, 10)}


def _fit(im, box):
    im = A.trim(im)
    s = min(box[0] / im.width, box[1] / im.height)
    w, h = max(1, round(im.width * s)), max(1, round(im.height * s))
    return A.down(im, w, h)


def build_weapons():
    g = {k: AD._sin_rotulo(v) for k, v in T._grid("armas", 30, 40).items()}
    for i, wid in enumerate(WEAPON_IDS):
        icon = _fit(g[i], ICON_PX)
        (ROOT / "assets/sprites/items").mkdir(parents=True, exist_ok=True)
        icon.save(ROOT / f"assets/sprites/items/{wid}.png")
        proj = _fit(g[4 + i], PROJ_PX[wid])
        proj.save(ROOT / f"assets/sprites/projectiles/{wid}.png")
        print("arma", wid, icon.size, proj.size)


def preview(dest):
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    BG = (58, 56, 84, 255)
    k = 4
    tiles = []
    for name, cfg in ENEMIES.items():
        for i in sorted((EDIR / name).glob(f"{name}_*_00.png")):
            tiles.append(Image.open(i))
    rows = {n: [Image.open(p) for p in sorted((EDIR / n).glob(f"{n}_*.png"))] for n in ENEMIES if (EDIR / n).exists()}
    cw, ch = 44 * k, 52 * k
    cols = 12
    nrows = len(rows)
    sh = Image.new("RGBA", (cols * cw, max(1, nrows) * ch + 40 * k), BG)
    for r, (n, lst) in enumerate(rows.items()):
        for c, im in enumerate(lst[:cols]):
            big = im.resize((im.width * k, im.height * k), Image.NEAREST)
            sh.alpha_composite(big, (c * cw + (cw - big.width) // 2, r * ch + ch - big.height))
    y = nrows * ch + 4 * k
    x = 6 * k
    for wid in WEAPON_IDS:
        for p in (ROOT / f"assets/sprites/items/{wid}.png", ROOT / f"assets/sprites/projectiles/{wid}.png"):
            if p.exists():
                im = Image.open(p)
                big = im.resize((im.width * k, im.height * k), Image.NEAREST)
                sh.alpha_composite(big, (x, y))
                x += big.width + 8 * k
    sh.convert("RGB").save(dest / "sprites_nuevos.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        for n in args or list(ENEMIES) + ["armas", "puerta"]:
            if n == "armas":
                if (RAW / "armas.png").exists():
                    build_weapons()
            elif n == "puerta":
                if (RAW / "puerta.png").exists():
                    build_puerta()
            elif (RAW / f"{n}.png").exists():
                build_enemy(n)
    elif cmd == "preview":
        preview(args[0] if args else ".")
