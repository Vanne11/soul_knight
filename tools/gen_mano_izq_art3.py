"""Arte de las DEFENSAS de MANO IZQUIERDA (tercera tanda) con Gemini: UNA hoja con 10 iconos (2 filas x 5).
Escribe assets/sprites/items/<id>.png (24x24). Los efectos en el mundo (aura, zona, marcas...) se dibujan por codigo.

Uso: python3 tools/gen_mano_izq_art3.py gen     llama a Gemini (UNA llamada; solo si falta la hoja)
     python3 tools/gen_mano_izq_art3.py build   recorta, pixela y escribe los PNG (los que no salgan bien se pintan por codigo)
Original: <repo principal>/.claude/arte_fuente/mano_izquierda/iconos3.png (respaldo en ~/Vídeos/Rogue Reproductive/arte_gemini_original/mano_izquierda/).
"""
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_aduanero_art as AD  # noqa: E402  (_sin_rotulo / _sin_astillas)
import gen_mano_izq_art2 as P2  # noqa: E402  (_grid5 / _fit)
import arc2_gemini as GEM  # noqa: E402
import gen_arcoiria_art2 as A  # noqa: E402
from arc2_gemini import STYLE  # noqa: E402

ROOT = GEM.ROOT
RAW = P2.RAW
BACKUP = P2.BACKUP

IDS = ("def_condon_interno", "def_anillo", "def_prep", "def_pep", "def_autotest",
       "def_app_ciclo", "def_termometro", "def_espermicida", "def_mascarilla", "def_sosten")
ICON_PX = (24, 24)

PROMPT = STYLE.replace("Characters face RIGHT in a three-quarter top-down game view. ", "") + (
    "ITEM ICON SHEET with exactly 2 rows of 5 item icons (10 icons), each item alone in its own cell, no characters, each drawn "
    "front view, chunky and readable at a tiny size. TOP ROW: (1) 'Condon interno': a soft translucent pale-lavender pouch "
    "shaped like a small rounded sleeve with a flexible ring at each end, glossy, shining; (2) 'Anillo vaginal': a thin flexible "
    "translucent ring-shaped loop in soft pink with a pale highlight, drawn as a simple thick circle; (3) 'PrEP': a small "
    "round amber pill bottle with a white cap and a single blue pill next to it, a tiny red ribbon bow on the bottle; "
    "(4) 'PEP': a red-and-white emergency pill box with a white cross and a small clock face on it, urgent look, two capsules "
    "beside it; (5) 'Autotest': a slim white rapid-test stick device with a small result window showing a tiny teal check, "
    "a little round swab beside it. BOTTOM ROW: (6) 'App del ciclo': a small smartphone with a lilac screen showing a tiny "
    "calendar grid with a few dots and a drop-shaped highlight, no letters; (7) 'Termometro': a classic glass thermometer "
    "with red mercury and a few tick marks, tilted, tiny sweat drop beside it; (8) 'Espermicida': a small squeeze tube of "
    "cream in white and mustard-yellow with a round cap and a dollop of gel, medicinal look; (9) 'Mascarilla': a light-blue "
    "pleated surgical face mask with two ear loops, clean and bright; (10) 'Sosten deportivo': a sporty teal-and-white crop "
    "sports bra top drawn flat on its own like clothing on a display, with a bright accent stripe. "
    "1-pixel dark outline, palette per item as described. Humorous but family-friendly, nothing explicit, no body parts. "
    "ABSOLUTELY NO TEXT: never write letters, numbers, words, captions or labels anywhere; the bottom of every cell is empty green."
)


def gen():
    if (RAW / "iconos3.png").exists():
        print("ya existe la hoja; no se llama a Gemini")
        return
    print("LLAMADA a Gemini: iconos3", flush=True)
    GEM.generate("iconos3", PROMPT, aspect="16:9", size="2K")
    BACKUP.mkdir(parents=True, exist_ok=True)
    shutil.copy(RAW / "iconos3.png", BACKUP / "iconos3.png")


def _code_icon(wid):
    """Icono pintado a mano para el caso en que Gemini no entregue la hoja."""
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    K = (20, 16, 28, 255)
    if wid == "def_condon_interno":
        d.rounded_rectangle((6, 3, 17, 21), 5, fill=(190, 170, 235, 255), outline=K)
        d.ellipse((4, 1, 19, 6), outline=K, fill=(225, 215, 250, 255))
        d.line((9, 8, 9, 17), fill=(245, 240, 255, 255))
    elif wid == "def_anillo":
        d.ellipse((3, 3, 20, 20), outline=K, width=5)
        d.ellipse((3, 3, 20, 20), outline=(245, 150, 190, 255), width=3)
        d.arc((5, 5, 14, 14), 190, 270, fill=(255, 235, 245, 255), width=1)
    elif wid == "def_prep":
        d.rounded_rectangle((4, 7, 14, 21), 2, fill=(240, 170, 60, 255), outline=K)
        d.rectangle((5, 3, 13, 7), fill=(250, 250, 250, 255), outline=K)
        d.ellipse((15, 15, 21, 20), fill=(90, 150, 240, 255), outline=K)
    elif wid == "def_pep":
        d.rounded_rectangle((2, 6, 18, 20), 2, fill=(245, 245, 245, 255), outline=K)
        d.rectangle((9, 9, 11, 17), fill=(220, 60, 60, 255))
        d.rectangle((6, 12, 14, 14), fill=(220, 60, 60, 255))
        d.ellipse((15, 2, 22, 9), fill=(255, 255, 255, 255), outline=K)
        d.line((18, 5, 18, 3), fill=K)
        d.line((18, 5, 20, 6), fill=K)
    elif wid == "def_autotest":
        d.rounded_rectangle((7, 2, 16, 22), 3, fill=(245, 245, 250, 255), outline=K)
        d.rectangle((9, 7, 14, 12), fill=(90, 200, 190, 255), outline=K)
        d.line((10, 10, 11, 11), fill=(255, 255, 255, 255))
        d.line((11, 11, 13, 8), fill=(255, 255, 255, 255))
        d.ellipse((9, 15, 14, 20), fill=(210, 215, 225, 255), outline=K)
    elif wid == "def_app_ciclo":
        d.rounded_rectangle((5, 1, 18, 22), 3, fill=(170, 140, 230, 255), outline=K)
        for y in (6, 10, 14):
            for x in (7, 10, 13):
                d.point((x, y), fill=(255, 255, 255, 255))
        d.ellipse((13, 15, 17, 20), fill=(240, 90, 130, 255))
    elif wid == "def_termometro":
        d.line((5, 19, 17, 5), fill=K, width=5)
        d.line((5, 19, 17, 5), fill=(235, 240, 245, 255), width=3)
        d.line((5, 19, 11, 12), fill=(230, 60, 60, 255), width=2)
        d.ellipse((2, 16, 8, 22), fill=(230, 60, 60, 255), outline=K)
        d.ellipse((18, 8, 21, 12), fill=(120, 200, 255, 255))
    elif wid == "def_espermicida":
        d.polygon([(5, 20), (18, 20), (16, 6), (7, 6)], fill=(250, 250, 245, 255), outline=K)
        d.rectangle((7, 2, 16, 6), fill=(235, 190, 70, 255), outline=K)
        d.rectangle((6, 13, 17, 16), fill=(235, 190, 70, 255))
        d.ellipse((17, 18, 22, 22), fill=(255, 255, 230, 255), outline=K)
    elif wid == "def_mascarilla":
        d.rounded_rectangle((5, 6, 18, 17), 3, fill=(150, 210, 240, 255), outline=K)
        for y in (9, 12, 15):
            d.line((6, y, 17, y), fill=(110, 170, 215, 255))
        d.arc((0, 5, 7, 18), 90, 270, fill=K)
        d.arc((16, 5, 23, 18), 270, 90, fill=K)
    elif wid == "def_sosten":
        d.polygon([(3, 5), (9, 5), (12, 11), (15, 5), (21, 5), (20, 16), (13, 18), (11, 18), (4, 16)],
                  fill=(60, 190, 180, 255), outline=K)
        d.line((4, 12, 20, 12), fill=(250, 250, 250, 255), width=2)
        d.line((5, 5, 8, 1), fill=K)
        d.line((19, 5, 16, 1), fill=K)
    return im


def build(only=None):
    g = {}
    if (RAW / "iconos3.png").exists():
        g = {k: AD._sin_rotulo(v) for k, v in P2._grid5("iconos3").items()}
    out = ROOT / "assets/sprites/items"
    for i, wid in enumerate(IDS):
        if only and wid not in only:
            continue
        if i in g and not (only is not None and "codigo" in only):
            icon = P2._fit(g[i], ICON_PX)
            src = "gemini"
        else:
            icon = _code_icon(wid)
            src = "codigo"
        cv = Image.new("RGBA", ICON_PX, (0, 0, 0, 0))
        cv.alpha_composite(icon, ((ICON_PX[0] - icon.width) // 2, (ICON_PX[1] - icon.height) // 2))
        cv = A.quantize_set({0: cv}, 32)[0]
        cv.save(out / f"{wid}.png")
        print("icono", wid, icon.size, src)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    gen() if cmd == "gen" else build(set(sys.argv[2:]) or None)
