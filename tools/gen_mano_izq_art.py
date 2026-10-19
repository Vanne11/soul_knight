"""Arte de las DEFENSAS de MANO IZQUIERDA (primera tanda) con Gemini: UNA hoja con 8 iconos (2 filas x 4).
Escribe assets/sprites/items/<id>.png (24x24). Los efectos en el mundo (burbuja, orbita, muro...) se dibujan por codigo.

Uso: python3 tools/gen_mano_izq_art.py gen     llama a Gemini (UNA llamada; solo si falta la hoja)
     python3 tools/gen_mano_izq_art.py build   recorta, pixela y escribe los PNG
Original: <repo principal>/.claude/arte_fuente/mano_izquierda/iconos.png (respaldo en ~/Vídeos/Rogue Reproductive/arte_gemini_original/mano_izquierda/).
"""
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_aduanero_art as AD  # noqa: E402  (_sin_rotulo / _sin_astillas)
import gen_testiculo_art as T  # noqa: E402
import arc2_gemini as GEM  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402
from arc2_gemini import STYLE  # noqa: E402

ROOT = GEM.ROOT
RAW = Path("/home/nick/Escritorio/Proyectos/soul_knight/.claude/arte_fuente/mano_izquierda")
BACKUP = Path.home() / "Vídeos/Rogue Reproductive/arte_gemini_original/mano_izquierda"
GEM.RAW = RAW
T.RAW = RAW

IDS = ("def_condon_escudo", "def_diafragma", "def_toalla_nocturna", "def_copa_menstrual",
       "def_diu_cobre", "def_barrera_latex", "def_vacuna_vph", "def_condon_escudo_roto")
ICON_PX = (24, 24)

PROMPT = STYLE.replace("Characters face RIGHT in a three-quarter top-down game view. ", "") + (
    "ITEM ICON SHEET with exactly 2 rows of 4 item icons (8 icons), each item alone in its own cell, no characters, each drawn "
    "front view, chunky and readable at a tiny size. TOP ROW: (1) 'Condon Escudo': a round buckler SHIELD made of a glossy translucent "
    "teal latex condom, ring-shaped rim, a small reservoir tip on top, shiny white highlight; (2) 'Diafragma': a shallow dome of soft "
    "pale pink silicone with a flexible silver metal rim ring, like a tiny round shield; (3) 'Toalla Nocturna': a long white absorbent "
    "night pad with two little side wings and a soft lavender core stripe, drawn upright like a tall kite shield; (4) 'Copa Menstrual': "
    "a bell-shaped soft silicone cup in violet with a small stem and little air holes near the rim, glossy. BOTTOM ROW: (5) 'DIU de "
    "Cobre': a T-shaped intrauterine device made of white plastic with fine copper-orange wire coiled around its arms, a short "
    "string tail, a faint copper glow; (6) 'Barrera de Latex': a thin square translucent light-blue latex sheet with slightly "
    "wavy corners and a bright sheen; (7) 'Vacuna VPH': a medical syringe with a purple-and-mint vial and a tiny shield-with-check "
    "sparkle; (8) 'Condon Escudo roto': the same teal latex round shield as item 1 but torn and deflated, with a ragged hole and "
    "crack lines, faded grey-teal, sad. 1-pixel dark outline, palette per item as described. Humorous but family-friendly, nothing "
    "explicit, no body parts. ABSOLUTELY NO TEXT: never write letters, numbers, words, captions or labels anywhere; the bottom of "
    "every cell is empty green."
)


def gen():
    if (RAW / "iconos.png").exists():
        print("ya existe la hoja; no se llama a Gemini")
        return
    print("LLAMADA a Gemini: iconos", flush=True)
    GEM.generate("iconos", PROMPT, aspect="16:9", size="2K")
    BACKUP.mkdir(parents=True, exist_ok=True)
    shutil.copy(RAW / "iconos.png", BACKUP / "iconos.png")


def _fit(im, box):
    im = A.trim(im)
    s = min(box[0] / im.width, box[1] / im.height)
    w, h = max(1, round(im.width * s)), max(1, round(im.height * s))
    return A.down(im, w, h)


def build():
    g = {k: AD._sin_rotulo(v) for k, v in T._grid("iconos", 30, 40).items()}
    out = ROOT / "assets/sprites/items"
    for i, wid in enumerate(IDS):
        icon = _fit(g[i], ICON_PX)
        cv = Image.new("RGBA", ICON_PX, (0, 0, 0, 0))
        cv.alpha_composite(icon, ((ICON_PX[0] - icon.width) // 2, (ICON_PX[1] - icon.height) // 2))
        cv = A.quantize_set({0: cv}, 32)[0]
        cv.save(out / f"{wid}.png")
        print("icono", wid, icon.size)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    gen() if cmd == "gen" else build()
