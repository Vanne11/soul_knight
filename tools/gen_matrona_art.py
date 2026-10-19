"""Arte de LA MATRONA (antes Dra. Preventina / Doctora V.) con Gemini: consultorio (edu) y Consulta del Utero.
Escribe en assets/sprites/edu/matrona_*.png (cuadros sueltos 48x64, pies abajo).

Uso: python3 tools/gen_matrona_art.py gen      UNA llamada a Gemini (hoja 2x4 en una imagen; rehace con `gen matrona`)
     python3 tools/gen_matrona_art.py build    recorta, pixela, cuantiza y escribe los PNG
     python3 tools/gen_matrona_art.py preview DIR   hoja de contacto de las poses
Originales (fuera de git): .claude/arte_fuente/matrona/ y ~/Videos/Rogue Reproductive/arte_gemini_original/matrona/
Poses (orden de la hoja): idle, blink, talk_a, talk_b, wave, give (preservativo), leaflet (folleto), write (anota en su ficha).
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_testiculo_art as T  # noqa: E402
import arc2_gemini as GEM  # noqa: E402
import gen_aduanero_art as AD  # noqa: E402  (_sin_rotulo / _sin_astillas)
from arc2_gemini import STYLE  # noqa: E402

ROOT = GEM.ROOT
RAW = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/matrona")
COPY = Path("/home/nick/Vídeos/Rogue Reproductive/arte_gemini_original/matrona")
GEM.RAW = RAW
T.RAW = RAW
DEST = ROOT / "assets/sprites/edu"
OLD = ROOT / "assets/sprites/edu/doctora_idle_1.png"  # referencia de diseno (la doctora provisoria)
CW, CH = 48, 64
NAMES = ["idle", "blink", "talk_a", "talk_b", "wave", "give", "leaflet", "write"]

PROMPT = STYLE + (
    "NPC SPRITE SHEET with exactly 2 rows of 4 poses (8 poses), the SAME character at the SAME scale in every cell, full body "
    "visible, standing on the ground (feet at the bottom of the cell), one single character per cell. "
    "THE CHARACTER 'La Matrona' (the Midwife, a friendly sexual and reproductive health professional): a cartoon chubby "
    "BLOB-like little person, NOT a realistic human, same design family as the reference image (big round head, tiny body, "
    "round glasses, rosy cheeks, short stubby arms and small feet) but redrawn with more detail and a premium look: purple hair "
    "tied in a neat bun, round glasses with big friendly eyes, a warm smile, a white and mint-teal short tunic (scrubs) with a "
    "small pink heart on the chest pocket, a stethoscope around the neck, a name badge on a lanyard (plain, no writing), teal "
    "clogs. Kind, calm, reassuring, with a gentle humorous touch, family friendly. Palette: white, mint teal, purple, peach skin, "
    "pink, a bit of yellow. Poses left to right, top row: (1) neutral IDLE, standing relaxed with a gentle smile, hands in front; "
    "(2) the same IDLE but eyes closed in a calm blink; (3) TALKING and EXPLAINING: mouth open, one hand raised palm-up in a "
    "gesture; (4) TALKING: mouth in a small round 'o', the other index finger raised making a point. Bottom row: (5) WAVING "
    "hello with a big smile, one hand raised high; (6) HANDING OVER a small wrapped CONDOM packet (a little square foil packet with "
    "a round ring shape, plain, no writing) held out toward the viewer on the right, with a reassuring smile; (7) HANDING OVER a "
    "small folded paper LEAFLET (plain wavy lines and a tiny heart, no letters) held out to the right; (8) WRITING NOTES on a "
    "patient chart: a clipboard held in one arm and a pen in the other hand, head tilted down looking at the paper, the paper "
    "shows only plain wavy lines and a red check mark. ABSOLUTELY NO TEXT: never write letters, numbers, words, captions, pose "
    "names or labels anywhere in the image; the bottom of every cell is empty green. Extra effects stay very close to the body."
)


def gen(names):
    RAW.mkdir(parents=True, exist_ok=True)
    n = "matrona"
    if (RAW / f"{n}.png").exists() and not names:
        print("ya existe", n)
        return
    ref = Image.open(OLD).convert("RGBA")
    bg = Image.new("RGBA", ref.size, (255, 255, 255, 255))
    bg.alpha_composite(ref)
    ref = bg.resize((ref.width * 8, ref.height * 8), Image.NEAREST)
    GEM.generate(n, PROMPT, aspect="16:9", size="2K", refs=[ref])
    print("LLAMADA a Gemini:", n)
    COPY.mkdir(parents=True, exist_ok=True)
    shutil.copy2(RAW / f"{n}.png", COPY / f"{n}.png")


def _cells():
    """Hoja 4x2 con lineas negras de celda: se corta por rejilla exacta, con margen para dejar fuera las lineas."""
    im = T._bg(RAW / "matrona.png")
    cw, ch = im.width // 4, im.height // 2
    m = 30
    out = []
    for i in range(8):
        r, c = divmod(i, 4)
        box = im.crop((c * cw + m, r * ch + m, (c + 1) * cw - m, (r + 1) * ch - m))
        out.append(T.CUT.main_blob(box, 60))
    return out


def poses():
    g = _cells()
    raw = dict(zip(NAMES, g))
    P = T.fit(raw, CW, CH, 60, 56)
    return P


def build():
    P = poses()
    for k, im in P.items():
        im.save(DEST / f"matrona_{k}.png")
    print("matrona", len(P), "poses")


def preview(dest):
    P = poses()
    s = 5
    sh = Image.new("RGBA", (CW * s * 4 + 50, CH * s * 2 + 30), (70, 70, 80, 255))
    for i, k in enumerate(NAMES):
        im = P[k].resize((CW * s, CH * s), Image.NEAREST)
        sh.alpha_composite(im, (10 + (i % 4) * (CW * s + 10), 10 + (i // 4) * (CH * s + 10)))
    Path(dest).mkdir(parents=True, exist_ok=True)
    sh.save(Path(dest) / "matrona_poses.png")
    print("preview ->", Path(dest) / "matrona_poses.png")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    if cmd == "gen":
        gen(sys.argv[2:])
    elif cmd == "preview":
        preview(sys.argv[2])
    else:
        build()
