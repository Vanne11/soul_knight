"""Arte del MONTE DE VENUS (loma en mesetas estilo A Link to the Past) con Gemini.

Uso: python3 tools/gen_monte_venus_art2.py gen [terreno|props ...]   (llama a la API; una hoja por llamada)
     python3 tools/gen_monte_venus_art2.py build                      (recorta las hojas y escribe los PNG del juego)
Reglas de Nico: cada hoja es UNA sola imagen con todas las piezas (nunca cuadro a cuadro). Los originales
quedan en .claude/arte_fuente/monte_venus/ (fuera de git); `build` es reproducible desde ellos.
La key sale de ~/.kaggle/gemini_key o GEMINI_API_KEY; el modelo de GEMINI_IMAGE_MODEL.
Salida (assets/sprites/environment/monte/): piezas sueltas a 1 px arte = 1 px mundo (el heroe mide 32x48).
"""
import base64
import io
import json
import os
import sys
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / ".claude/arte_fuente/monte_venus"
OUT = ROOT / "assets/sprites/environment/monte"
MODEL = os.environ.get("GEMINI_IMAGE_MODEL", "gemini-3.1-flash-lite-image")

STYLE = (
    "Pixel art game asset sheet in the style of Zelda: A Link to the Past and Enter the Gungeon: premium indie finish, "
    "chunky readable pixels, clean dark outlines, rich cel shading with 3-4 tones per material, light from the top-left, "
    "warm saturated jungle palette, top-down 3/4 view (camera looking down at about 45 degrees). "
    "ONE single image that is a sprite sheet: every piece drawn separately on a perfectly flat solid pure magenta (#FF00FF) "
    "background, with wide empty magenta gaps between pieces so they never touch, no shadows on the background, no text, "
    "no labels, no grid lines, no border. Humorous, tasteful, nothing explicit. "
)

SHEETS = {
    "terreno": (
        "Sheet of terrain pieces for a stepped grassy hill (a jungle plateau with earthen cliffs), arranged in 3 rows of 4 "
        "pieces. Row 1: (1) a flat seamless square tile of top-down lush green-pink jungle meadow grass, (2) another grass tile "
        "with tiny clover and pebbles, (3) a long horizontal strip of earthen cliff wall seen from the front (3/4 view): a "
        "grass lip overhanging on top, then brown-ochre packed earth with roots and small stones, darker toward the bottom, "
        "tileable horizontally, (4) a second variant of the same cliff wall strip with a few mossy rocks. Row 2: (5) the LEFT "
        "end of that cliff wall where the plateau corner turns (front wall plus a narrow side face on the left), (6) the RIGHT "
        "end, mirrored, (7) a vertical strip of the plateau's left side edge seen from above: grass lip over a narrow dirt side, "
        "(8) the same for the right side. Row 3: (9) a carved earthen RAMP going up, seen from the front in 3/4 view, wide, "
        "with carved flat steps and small wooden log borders on both sides, (10) a ramp variant made of rough stone steps with "
        "grass tufts, (11) a summit detail: a round patch of grass with a circle of small pink flowers and a flat stone at the "
        "center, seen from above, (12) a small round stepping stone slab with moss. "
    ),
    "props": (
        "Sheet of props for a jungle hill, arranged in 2 rows of 5. Row 1: four DIFFERENT tall clumps of curly dark chestnut "
        "brown body hair as stylized tall grass (springy spiral curls, each about as tall as a character's knees to waist, "
        "chunky and cartoon, tasteful and funny, nothing explicit, dark outlines, warm brown with lighter highlights), and (5) "
        "a small bent-over variant. Row 2: (6) a puddle of hardened golden-yellow candle wax seen from the 3/4 top-down view, "
        "round lumpy blob with shiny highlights and drips, a chunky solid obstacle about knee high, (7) the SAME wax block but "
        "broken: cracked with chips falling off, lower and crumbled, (8) a small pile of wax crumbs and shards, (9) a tall "
        "wooden flagpole with a pink flag flying from it carrying a white Venus symbol (circle with a small cross under it), "
        "the pole stuck in a small mound of dirt, (10) a pink sticky note on a little wooden stake with a hot-pink pushpin, "
        "plus a blue bow drawn at its corner, no text on the note. "
    ),
}


def key() -> str:
    k = os.environ.get("GEMINI_API_KEY")
    if not k:
        k = (Path.home() / ".kaggle/gemini_key").read_text().strip()
    return k


def _img_part(path: Path) -> dict:
    buf = io.BytesIO()
    Image.open(path).convert("RGB").save(buf, "PNG")
    return {"inlineData": {"mimeType": "image/png", "data": base64.b64encode(buf.getvalue()).decode()}}


def generate(name: str, refs=()) -> Path:
    note = ""
    if refs:
        note = "The reference image shows the game's existing look (floor and character scale): match its palette and pixel density. "
    body = {
        "contents": [{"parts": [_img_part(Path(r)) for r in refs] + [{"text": STYLE + note + SHEETS[name]}]}],
        "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "1:1", "imageSize": "1K"}},
    }
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key()},
    )
    with urllib.request.urlopen(req, timeout=240) as r:
        data = json.load(r)
    for part in data["candidates"][0]["content"]["parts"]:
        if "inlineData" in part:
            RAW.mkdir(parents=True, exist_ok=True)
            out = RAW / f"{name}.png"
            out.write_bytes(base64.b64decode(part["inlineData"]["data"]))
            print("hoja", name, Image.open(out).size, data.get("usageMetadata", {}))
            return out
    raise RuntimeError(f"{name}: sin imagen: {json.dumps(data)[:400]}")


# ---------------------------------------------------------------- recorte (reproducible desde los originales)
# nombre: (hoja, punto dentro de la pieza (o caja x0,y0,x1,y1) en la hoja de 1024 px, tamano final en px de juego o None = escala 0.25)
PIECES = {
    "grass_a": ("terreno", (120, 130), None),
    "grass_b": ("terreno", (380, 130), None),
    "wall_a": ("terreno", (760, 150), (128, 40)),
    "wall_b": ("terreno", (760, 400), (128, 40)),
    "rim_side": ("terreno", (665, 600), (16, 56)),
    "ramp_wood": ("terreno", (130, 800), (64, 62)),
    "ramp_stone": ("terreno", (410, 810), (64, 62)),
    "summit": ("terreno", (675, 845), (88, 76)),
    "stone": ("terreno", (908, 820), (30, 22)),
    "tuft_a": ("props", (125, 300), (30, 40)),
    "tuft_b": ("props", (325, 330), (30, 40)),
    "tuft_c": ("props", (520, 350), (30, 40)),
    "tuft_d": ("props", (715, 320), (32, 40)),
    "tuft_e": ("props", (910, 410), (34, 24)),
    "wax": ("props", (125, 740), (52, 56)),
    "wax_broken": ("props", (320, 750), (54, 38)),
    "wax_crumbs": ("props", (440, 725, 590, 810), (30, 18)),  # trozos sueltos: toda la caja
    "flag": ("props", (740, 640), (44, 68)),
    "note": ("props", (905, 690), (30, 46)),
}


def _is_bg(a: np.ndarray) -> np.ndarray:
    """Fondo magenta plano (con el ruido de la compresion)."""
    r, g, b = a[:, :, 0].astype(int), a[:, :, 1].astype(int), a[:, :, 2].astype(int)
    return (r > 150) & (b > 200) & (g < 70) & (abs(r - b) < 50)


def _component(bg: np.ndarray, seed) -> np.ndarray:
    """Mascara de la pieza que contiene `seed` (relleno de la figura sobre el fondo)."""
    h, w = bg.shape
    mask = np.zeros((h, w), bool)
    stack = [(seed[1], seed[0])]
    while stack:
        y, x = stack.pop()
        if y < 0 or x < 0 or y >= h or x >= w or mask[y, x] or bg[y, x]:
            continue
        mask[y, x] = True
        stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    return mask


def cut(name: str) -> Image.Image:
    sheet, seed, size = PIECES[name]
    im = Image.open(RAW / f"{sheet}.png").convert("RGB")
    a = np.array(im)
    bg = _is_bg(a)
    # une los huecos finos entre contorno y relleno para que el relleno no se rompa
    if len(seed) == 4:
        mask = np.zeros_like(bg)
        mask[seed[1]:seed[3], seed[0]:seed[2]] = ~bg[seed[1]:seed[3], seed[0]:seed[2]]
    else:
        mask = _component(bg, seed)
    # come el halo magenta del borde (2 px de la hoja de 1024)
    m = Image.fromarray((mask * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(5))
    mask = np.array(m) > 0
    ys, xs = np.where(mask)
    box = (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)
    rgba = np.dstack([a, (mask * 255).astype(np.uint8)])[box[1]:box[3], box[0]:box[2]]
    piece = Image.fromarray(rgba, "RGBA")
    w, h = piece.size
    tw, th = size if size else (round(w * 0.25), round(h * 0.25))
    return shrink(piece, tw, th)


def shrink(im: Image.Image, w: int, h: int) -> Image.Image:
    """Reduce con promedio de caja sobre color premultiplicado; el alfa se binariza (pixel art, sin bordes suaves)."""
    a = np.array(im).astype(np.float32)
    al = a[:, :, 3:4] / 255.0
    pm = Image.fromarray((np.dstack([a[:, :, :3] * al, a[:, :, 3:4]])).astype(np.uint8), "RGBA")
    small = np.array(pm.resize((w, h), Image.BOX)).astype(np.float32)
    alpha = small[:, :, 3:4] / 255.0
    rgb = np.where(alpha > 0.01, small[:, :, :3] / np.maximum(alpha, 0.01), 0)
    out = np.dstack([rgb.clip(0, 255), np.where(alpha > 0.5, 255, 0)]).astype(np.uint8)
    out[:, :, :3] = np.where(out[:, :, 3:4] > 0, out[:, :, :3], 0)
    return Image.fromarray(out, "RGBA")


def grass_tile(name: str) -> Image.Image:
    """Baldosa de pasto 64x64 sin costuras: el centro del dibujo (sin el contorno) espejado en 2x2."""
    sheet, seed, _ = PIECES[name]
    a = np.array(Image.open(RAW / f"{sheet}.png").convert("RGB"))
    x0, y0 = seed[0] - 85, seed[1] - 85
    core = Image.fromarray(a[y0:y0 + 170, x0:x0 + 170]).resize((32, 32), Image.BOX)
    t = Image.new("RGB", (64, 64))
    t.paste(core, (0, 0))
    t.paste(core.transpose(Image.FLIP_LEFT_RIGHT), (32, 0))
    t.paste(core.transpose(Image.FLIP_TOP_BOTTOM), (0, 32))
    t.paste(core.transpose(Image.ROTATE_180), (32, 32))
    return t.convert("RGBA")


def build() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name in PIECES:
        if name.startswith("grass"):
            grass_tile(name).save(OUT / f"{name}.png")
        else:
            cut(name).save(OUT / f"{name}.png")
        print("ok", name)
    # borde norte: el labio de pasto de la pared, volteado (el contorno oscuro queda hacia afuera)
    wall = Image.open(OUT / "wall_a.png")
    lip = wall.crop((0, 0, 128, 14)).transpose(Image.FLIP_TOP_BOTTOM)
    lip.save(OUT / "rim_north.png")
    # borde lateral: tapa, centro (se repite) y pie de tierra
    side = Image.open(OUT / "rim_side.png")
    side.crop((0, 0, 16, 10)).save(OUT / "rim_side_top.png")
    side.crop((0, 10, 16, 34)).save(OUT / "rim_side_mid.png")
    side.crop((0, 34, 16, 56)).save(OUT / "rim_side_bot.png")
    (OUT / "rim_side.png").unlink()


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    if cmd == "gen":
        for n in sys.argv[2:] or SHEETS:
            generate(n)
    else:
        build()
