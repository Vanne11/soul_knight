"""Arte de las DEFENSAS de MANO IZQUIERDA (segunda tanda) con Gemini: UNA hoja con 10 iconos (2 filas x 5).
Escribe assets/sprites/items/<id>.png (24x24). Los efectos en el mundo (nube, aura, latigo...) se dibujan por codigo.

Uso: python3 tools/gen_mano_izq_art2.py gen     llama a Gemini (UNA llamada; solo si falta la hoja)
     python3 tools/gen_mano_izq_art2.py build   recorta, pixela y escribe los PNG (los que no salgan bien se pintan por codigo)
Original: <repo principal>/.claude/arte_fuente/mano_izquierda/iconos2.png (respaldo en ~/Vídeos/Rogue Reproductive/arte_gemini_original/mano_izquierda/).
"""
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

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

IDS = ("def_implante", "def_tampon_ancla", "def_suspensorio", "def_parche", "def_talco",
       "def_toallita", "def_bolsa_agua", "def_pastilla_dia_despues", "def_latigo_seda", "def_esposas")
ICON_PX = (24, 24)

PROMPT = STYLE.replace("Characters face RIGHT in a three-quarter top-down game view. ", "") + (
    "ITEM ICON SHEET with exactly 2 rows of 5 item icons (10 icons), each item alone in its own cell, no characters, each drawn "
    "front view, chunky and readable at a tiny size. TOP ROW: (1) 'Implante': a tiny thin matchstick-sized rod of pale cream "
    "plastic, slightly glowing mint-green, lying diagonally, with a little shine; (2) 'Tampon Ancla': a white cotton tampon with a "
    "short string and a small dark-blue ship anchor attached to the string, funny; (3) 'Suspensorio blindado': a rugged "
    "metal-and-grey athletic cup guard shaped like a small rounded shield with rivets and a sports waistband strap, steel blue; "
    "(4) 'Parche': a square skin-tone adhesive patch with rounded corners, a tiny pink cross and a peel-off clear corner, "
    "beige-pink; (5) 'Talco': a small round talcum powder tin with a perforated top, a puff of white powder floating out, pastel "
    "blue label with no text. BOTTOM ROW: (6) 'Toallita humeda': a pink-and-white flip-top pack of wet wipes with a single "
    "wipe sticking out and a water droplet; (7) 'Bolsa de agua caliente': a rubber hot water bottle in warm red with a ridged "
    "surface and a screw cap, little steam wisps; (8) 'Pastilla del dia despues': a single round white pill with a small "
    "curved arrow looping backwards, on a tiny strip of foil blister, light teal; (9) 'Latigo de seda': a glossy fuchsia silk "
    "riding crop-like whip ribbon with a heart-shaped tip and a golden handle, coiled elegantly; (10) 'Esposas peludas': a pair "
    "of handcuffs covered in fluffy hot-pink fur, silver chain between, funny. 1-pixel dark outline, palette per item as "
    "described. Humorous but family-friendly, nothing explicit, no body parts. ABSOLUTELY NO TEXT: never write letters, numbers, "
    "words, captions or labels anywhere; the bottom of every cell is empty green."
)


def gen():
    if (RAW / "iconos2.png").exists():
        print("ya existe la hoja; no se llama a Gemini")
        return
    print("LLAMADA a Gemini: iconos2", flush=True)
    GEM.generate("iconos2", PROMPT, aspect="16:9", size="2K")
    BACKUP.mkdir(parents=True, exist_ok=True)
    shutil.copy(RAW / "iconos2.png", BACKUP / "iconos2.png")


def _fit(im, box):
    im = A.trim(im)
    s = min(box[0] / im.width, box[1] / im.height)
    w, h = max(1, round(im.width * s)), max(1, round(im.height * s))
    return A.down(im, w, h)


def _splitn(al, n, gap):
    """n cajas x de una fila: los n tramos de mas masa; si faltan, partes iguales."""
    col = (al > 128).sum(0)
    runs = T._runs(col, gap)
    runs = sorted(sorted(runs, key=lambda r: -col[r[0]:r[1]].sum())[:n])
    if len(runs) != n:
        w = al.shape[1] // n
        return [(i * w, (i + 1) * w) for i in range(n)]
    return runs


def _grid5(name, gap=30, blob_gap=40):
    im = T._bg(RAW / f"{name}.png")
    al = np.array(im)[:, :, 3]
    rows = (al > 128).sum(1)
    mid = im.height // 2
    lo, hi = mid - 220, mid + 220
    ys = lo + int(np.argmin(np.convolve(rows[lo:hi], np.ones(15) / 15, "same")))
    out = {}
    for r, (y0, y1) in enumerate(((0, ys), (ys, im.height))):
        band = im.crop((0, y0, im.width, y1))
        band = band.crop((0, 0, band.width, T._no_label(np.array(band)[:, :, 3])))
        band = band.crop((0, T._no_label_top(np.array(band)[:, :, 3]), band.width, band.height))
        for c, (x0, x1) in enumerate(_splitn(np.array(band)[:, :, 3], 5, gap)):
            pad = 20
            box = band.crop((max(0, x0 - pad), 0, min(im.width, x1 + pad), band.height))
            out[r * 5 + c] = T.CUT.main_blob(box, blob_gap)
    return out


# ---------------------------------------------------------------- respaldo por codigo (24x24)
def _code_icon(wid):
    """Icono pintado a mano para el caso en que Gemini no entregue la hoja."""
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    K = (20, 16, 28, 255)
    if wid == "def_implante":
        d.line((5, 18, 18, 5), fill=K, width=5)
        d.line((5, 18, 18, 5), fill=(240, 232, 200, 255), width=3)
        d.line((8, 15, 12, 11), fill=(120, 230, 170, 255), width=1)
    elif wid == "def_tampon_ancla":
        d.rounded_rectangle((8, 2, 15, 13), 3, fill=(250, 250, 250, 255), outline=K)
        d.line((11, 13, 11, 17), fill=(200, 200, 210, 255))
        d.arc((6, 15, 17, 24), 0, 180, fill=K, width=2)
        d.line((11, 17, 11, 21), fill=(60, 90, 160, 255), width=2)
    elif wid == "def_suspensorio":
        d.pieslice((3, 3, 20, 22), 180, 360, fill=(120, 150, 190, 255), outline=K)
        d.rectangle((3, 10, 20, 17), fill=(120, 150, 190, 255), outline=K)
        d.rectangle((1, 5, 22, 7), fill=(60, 70, 90, 255))
    elif wid == "def_parche":
        d.rounded_rectangle((4, 4, 19, 19), 3, fill=(240, 190, 170, 255), outline=K)
        d.rectangle((10, 8, 13, 15), fill=(230, 100, 140, 255))
        d.rectangle((8, 10, 15, 13), fill=(230, 100, 140, 255))
    elif wid == "def_talco":
        d.rounded_rectangle((6, 9, 18, 21), 2, fill=(150, 190, 240, 255), outline=K)
        d.rectangle((6, 6, 18, 9), fill=(210, 220, 235, 255), outline=K)
        for p in ((8, 2), (12, 1), (16, 3), (10, 4)):
            d.ellipse((p[0], p[1], p[0] + 3, p[1] + 3), fill=(250, 250, 255, 255))
    elif wid == "def_toallita":
        d.rounded_rectangle((4, 8, 19, 21), 2, fill=(250, 170, 200, 255), outline=K)
        d.rectangle((8, 3, 16, 9), fill=(255, 255, 255, 255), outline=K)
        d.ellipse((10, 13, 14, 18), fill=(120, 200, 255, 255))
    elif wid == "def_bolsa_agua":
        d.rounded_rectangle((5, 6, 18, 22), 5, fill=(220, 70, 60, 255), outline=K)
        d.rectangle((9, 2, 14, 6), fill=(240, 200, 90, 255), outline=K)
        for y in (10, 14, 18):
            d.line((7, y, 16, y), fill=(160, 40, 40, 255))
    elif wid == "def_pastilla_dia_despues":
        d.rounded_rectangle((2, 5, 21, 20), 3, fill=(170, 220, 215, 255), outline=K)
        d.ellipse((6, 8, 17, 17), fill=(255, 255, 255, 255), outline=K)
        d.arc((8, 9, 15, 16), 90, 330, fill=(40, 130, 140, 255), width=1)
    elif wid == "def_latigo_seda":
        d.line((4, 20, 10, 12), fill=(240, 200, 90, 255), width=3)
        d.arc((8, 3, 22, 16), 120, 400, fill=K, width=4)
        d.arc((8, 3, 22, 16), 120, 400, fill=(230, 60, 150, 255), width=2)
        d.polygon([(19, 15), (22, 12), (23, 16)], fill=(230, 60, 150, 255))
    elif wid == "def_esposas":
        for cx in (6, 17):
            d.ellipse((cx - 5, 8, cx + 5, 20), fill=(255, 130, 190, 255), outline=K)
            d.ellipse((cx - 2, 12, cx + 2, 16), fill=(0, 0, 0, 0), outline=K)
        d.line((10, 14, 13, 14), fill=(210, 210, 225, 255), width=2)
    return im


def build(only=None):
    g = {}
    if (RAW / "iconos2.png").exists():
        g = {k: AD._sin_rotulo(v) for k, v in _grid5("iconos2").items()}
    out = ROOT / "assets/sprites/items"
    for i, wid in enumerate(IDS):
        if only and wid not in only:
            continue
        if i in g and not (only is not None and wid in only and "codigo" in only):
            icon = _fit(g[i], ICON_PX)
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
