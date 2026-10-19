"""Arte de los BICHOS INCOMODOS de los pasillos entre reinos (src/dungeon/corridor_pest.gd) con Gemini.
Escribe en assets/sprites/enemies/pasillos/<tipo>/ (cuadros sueltos + <tipo>_sprite_frames.tres).

Uso: python3 tools/gen_pasillos_art.py gen [hoja ...]     llama a Gemini (UNA llamada por hoja; tope 3; solo las que falten; con nombre la rehace)
     python3 tools/gen_pasillos_art.py build [tipo ...]   recorta, pixela y escribe PNG + .tres (sin args = todos)
     python3 tools/gen_pasillos_art.py preview DIR        hoja de contacto de las poses recortadas
Hojas (UNA imagen cada una, regla de Nico: nunca cuadro a cuadro): pas_a (tio, spam, vendedor, mosquito), pas_b (cunado,
notificacion, ex), pas_c (influencer, chicle, captcha). Cada FILA es un bicho y cada COLUMNA una pose:
idle, walk, annoy (su manera de molestar), hurt, defeated. Originales en .claude/arte_fuente/pasillos/ (y copia en
~/Videos/Rogue Reproductive/arte_gemini_original/pasillos/). Misma calidad que el resto de enemigos: contorno oscuro,
paleta corta, 1 pixel de arte = 1 unidad de juego (bichos de ~40 px de alto).
"""
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_testiculo_art as T  # noqa: E402
import arc2_gemini as GEM  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402
import gen_aduanero_art as AD  # noqa: E402  (_sin_rotulo / _sin_astillas)
from arc2_gemini import STYLE  # noqa: E402

ROOT = GEM.ROOT
RAW = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/pasillos")
COPY = Path("/home/nick/Vídeos/Rogue Reproductive/arte_gemini_original/pasillos")
REF = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/aduanero/funcionario.png")
GEM.RAW = RAW
T.RAW = RAW
DEST = ROOT / "assets/sprites/enemies/pasillos"
RES = "res://assets/sprites/enemies/pasillos/"
POSES = ("idle", "walk", "annoy", "hurt", "defeated")
CW, CH = 56, 56      # lienzo de cada cuadro
IDLE_H = 40          # alto del bicho en reposo (px)

_NOTEXT = (" ABSOLUTELY NO TEXT: never write letters, numbers, words, captions, pose names, labels or signs anywhere in the image "
           "(a chat bubble or a screen shows only plain wavy lines or simple icons, never letters); the bottom of every cell is empty green.")

CREATURES = {
    "tio": "'Tio Preguntón' (Nosy Uncle): a chubby middle-aged uncle in an orange-brown knitted cardigan over a white shirt, thinning grey hair, "
           "round rosy cheeks, bushy grey eyebrows, a nosy raised eyebrow, a small black question-mark-shaped curl floating over his head (a "
           "plain curl with a dot, drawn as a shape). No moustache. Annoy pose: leaning in very close with a pointing finger and a nosy smile.",
    "spam": "'Spam del Grupo Familiar' (Family Group Spam): a living bright-green SPEECH BUBBLE blob with two small eyes and a big cheerful "
            "smile, surrounded by small orbiting sticker icons (a red heart, a yellow flower, a thumbs-up, a sun), cheerful and relentless. "
            "Annoy pose: puffed up, spitting out a burst of many sticker icons all around.",
    "vendedor": "'Vendedor de Planes de Salud' (Health Plan Salesperson): a bean-shaped salesman in a shiny blue suit with a red tie, slicked hair, "
                "a very wide fake grin with a gold tooth glint, a name badge (blank), holding out a folded leaflet brochure with plain "
                "colored stripes. Annoy pose: shoving the brochure forward with a pen in the other hand.",
    "mosquito": "'Mosquito Moral' (Moral Mosquito): a tiny round mosquito with long thin legs, translucent buzzing wings, a long needle "
                "proboscis, a tiny golden halo above the head and a guilty-looking judgmental face with a tiny frown. Annoy pose: diving "
                "forward with the needle out and a buzz zig-zag line.",
    "cunado": "'Cuñado Experto' (Know-It-All Brother-in-Law): a stocky smug man in a tight polo shirt with the collar popped, sunglasses pushed "
              "up on his forehead, a smirk, hands on hips. Annoy pose: one index finger raised high lecturing, eyes closed with a superior "
              "smile.",
    "notificacion": "'Aviso Insistente' (Insistent Alert): a golden BELL-shaped creature with two eyes and a red round notification dot "
                    "on its top-right corner (plain red circle, nothing written), tiny feet. Annoy pose: ringing wildly, motion arcs and "
                    "tiny sound waves, eyes wide.",
    "ex": "'Ex Nocturno' (Late-Night Ex): a sleepy pale figure in a purple hoodie with dark circles under the eyes, holding a glowing "
          "smartphone whose screen shows three small typing dots, slouching, a faint moon glow. Annoy pose: holding the phone up to the viewer "
          "with a hopeful sheepish smile, three typing dots glowing.",
    "influencer": "'Influencer de Cremas' (Skincare Influencer): a glamorous round creature with a huge pink glossy hair swoosh, sparkling "
                  "eyes, a ring-light halo behind the head, holding a cream jar, glitter sparkles all around. Annoy pose: striking a "
                  "selfie pose spraying a pink glittery mist cloud.",
    "chicle": "'Chicle Pegado' (Stuck Chewing Gum): a gooey bubble-gum pink blob with stretchy sticky strings, tiny dirty footprint marks, "
              "two small tired eyes and a smirk, sticking to a bit of ground. Annoy pose: stretching two long sticky strings out to grab.",
    "captcha": "'Captcha Humano' (Human Captcha): a white square checkbox-shaped creature with a thick dark border, a big empty square tick "
               "box on its front like a face, small robotic suspicious eyes with a tiny magnifying glass. Annoy pose: freezing in a stern "
               "stop pose with a big check mark glowing above.",
}
SHEETS = {"pas_a": ["tio", "spam", "vendedor", "mosquito"], "pas_b": ["cunado", "notificacion", "ex"], "pas_c": ["influencer", "chicle", "captcha"]}

_POSES_TXT = ("Each ROW is ONE creature and each of the 5 COLUMNS is one pose, left to right: (1) neutral IDLE standing; (2) WALK, mid-step; "
              "(3) ANNOY: its signature way of being a nuisance (described per creature); (4) HURT flinch (eyes squeezed, jolted back); "
              "(5) DEFEATED: deflated and lying/slumped flat with X eyes and a tiny puff. ")


def _prompt(names):
    rows = len(names)
    head = (f"ENEMY SPRITE SHEET with exactly {rows} rows and 5 columns of equal cells ({rows * 5} poses). "
            "These are cute, humorous, harmless-but-very-annoying everyday-life nuisances (a satirical roguelike). "
            "The SAME creature has the SAME design, scale and colors in all 5 poses of its row; every creature is small and chunky "
            "(about 3 heads tall at most), drawn full body with its feet at the bottom of the cell. "
            "Match the look of the reference image (same chunky pixel size, same 1-pixel dark outline, flat matte colors with a lighter highlight, "
            "no glossy plastic shading). Family friendly, no sensitive topics. ")
    body = " ".join(f"ROW {i + 1}: {CREATURES[n]}" for i, n in enumerate(names))
    extra = (" CRITICAL: every cell of a row shows THAT row's creature (never another row's creature or a human-like body in a "
             "different row); the DEFEATED pose of each row is that same creature deflated/flattened. Do NOT write the pose names "
             "(idle, walk, annoy, hurt, defeated) or the creature names under or over the poses: no captions at all.")
    return STYLE + head + _POSES_TXT + body + _NOTEXT + extra


def gen(names):
    RAW.mkdir(parents=True, exist_ok=True)
    COPY.mkdir(parents=True, exist_ok=True)
    refs = [Image.open(REF)] if REF.exists() else []
    for n in names or list(SHEETS):
        if (RAW / f"{n}.png").exists() and not names:
            continue
        GEM.generate(n, _prompt(SHEETS[n]), aspect="16:9", size="2K", refs=refs)
        shutil.copy(RAW / f"{n}.png", COPY / f"{n}.png")
        print("LLAMADA a Gemini:", n)


# ------------------------------------------------------------------ recorte
def _key(path, strict):
    """Quita el verde del fondo. strict: solo el verde puro del fondo (la hoja A trae un bicho verde, el Spam)."""
    if not strict:
        return T._bg(path)
    im = Image.open(path).convert("RGBA")
    a = np.array(im).astype(int)
    bg = (a[:, :, 1] > 170) & (a[:, :, 0] < 95) & (a[:, :, 2] < 95)
    a[:, :, 3] = np.where(bg, 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


def _row_bands(im, rows, gap=14, margin=8):
    """Franjas verticales de las filas: tramos con contenido separados por huecos; los rotulos (franjas bajitas) se descartan."""
    al = np.array(im)[:, :, 3] > 128
    prof = al.sum(1)
    H = im.height
    runs, start, last = [], None, None
    for y in range(H):
        if prof[y] > 2:
            if start is None:
                start = y
            last = y
        elif start is not None and y - last > gap:
            runs.append((start, last + 1))
            start = None
    if start is not None:
        runs.append((start, last + 1))
    bands = [r for r in runs if r[1] - r[0] > 0.09 * H]
    if len(bands) == rows:
        return [(max(0, a - margin), min(H, b + margin)) for a, b in bands]
    return [(r * H // rows, (r + 1) * H // rows) for r in range(rows)]


def _cells(sheet, rows):
    """Recorta la hoja en rows x 5 celdas y deja la pose principal de cada una (sin rotulos ni astillas vecinas)."""
    im = _key(RAW / f"{sheet}.png", sheet == "pas_a")
    W, H = im.size
    bands = _row_bands(im, rows, 3 if sheet == "pas_a" else 14, 0 if sheet == "pas_a" else 8)
    out = {}
    for r in range(rows):
        for c in range(5):
            box = (c * W // 5, bands[r][0], (c + 1) * W // 5, bands[r][1])
            cell = im.crop(box)
            cell = T.CUT.main_blob(cell, 60)
            try:
                cell = AD._sin_rotulo(cell)
            except Exception:
                pass
            out[(r, c)] = A.trim(cell)
    return out


def creature_poses(name):
    for sheet, names in SHEETS.items():
        if name in names and (RAW / f"{sheet}.png").exists():
            cells = _cells(sheet, len(names))
            r = names.index(name)
            raw = {POSES[c]: cells[(r, c)] for c in range(5)}
            break
    else:
        return None
    # la hoja A mezclo filas: del spam solo valen idle/walk/hurt; vendedor y mosquito traen la derrota del tio
    if name == "spam":
        raw["annoy"] = A.xf(raw["idle"], sx=1.18, sy=0.88)
    if name in ("spam", "vendedor", "mosquito"):
        raw["defeated"] = A.trim(raw["hurt"].rotate(90, expand=True, resample=Image.NEAREST))
    s = IDLE_H / raw["idle"].height
    out = {}
    for k, v in raw.items():
        sk = s
        m = min(1.0, (CW - 2) / (v.width * sk), (CH - 1) / (v.height * sk))
        fx = T._feet_x(v)
        w, h = max(1, round(v.width * sk * m)), max(1, round(v.height * sk * m))
        cv = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
        x0 = max(0, min(CW - w, int(round(CW / 2 - fx * sk * m))))
        cv.alpha_composite(A.down(v, w, h), (x0, CH - h - 1))
        out[k] = cv
    return A.quantize_set(out, 40)


def build(only):
    xf = A.xf
    DEST.mkdir(parents=True, exist_ok=True)
    for name in only or CREATURES:
        P = creature_poses(name)
        if P is None:
            print("sin hoja para", name)
            continue
        I = P["idle"]
        f = {"idle": [I, xf(I, sy=0.985)], "walk": [P["walk"], I, xf(P["walk"], dy=-1), I],
             "annoy": [P["annoy"], xf(P["annoy"], dx=1), P["annoy"], xf(P["annoy"], dx=-1)],
             "hurt": [P["hurt"], A.flash(P["hurt"], 0.5)], "death": [P["hurt"], P["defeated"], P["defeated"]]}
        speeds = {"idle": (4.0, True), "walk": (8.0, True), "annoy": (10.0, True), "hurt": (10.0, False), "death": (6.0, False)}
        d = DEST / name
        d.mkdir(parents=True, exist_ok=True)
        for old in d.glob(f"{name}_*"):
            old.unlink()
        res, anim = [], []
        for n, lst in f.items():
            fr = []
            for i, im in enumerate(lst):
                im.save(d / f"{name}_{n}_{i:02d}.png")
                rid = f"{n}{i}"
                res.append(f'[ext_resource type="Texture2D" path="{RES}{name}/{name}_{n}_{i:02d}.png" id="{rid}"]')
                fr.append('{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % rid)
            sp, loop = speeds[n]
            anim.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (", ".join(fr), "true" if loop else "false", n, sp))
        (d / f"{name}_sprite_frames.tres").write_text('[gd_resource type="SpriteFrames" format=3]\n\n' + "\n".join(res) + "\n\n[resource]\nanimations = [" + ", ".join(anim) + "]\n")
        print("bicho", name, "ok")


def preview(dest):
    dest = Path(dest)
    dest.mkdir(parents=True, exist_ok=True)
    BG = (58, 56, 84, 255)
    for name in CREATURES:
        P = creature_poses(name)
        if P is None:
            continue
        k = 4
        sh = Image.new("RGBA", (len(POSES) * CW * k, CH * k), BG)
        for i, p in enumerate(POSES):
            sh.alpha_composite(P[p].resize((CW * k, CH * k), Image.NEAREST), (i * CW * k, 0))
        sh.convert("RGB").save(dest / f"{name}_x4.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    args = sys.argv[2:]
    if cmd == "gen":
        gen(args)
    elif cmd == "build":
        build(args)
    elif cmd == "preview":
        preview(args[0] if args else ".")
