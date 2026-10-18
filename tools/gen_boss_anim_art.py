"""Poses clave de Dona Cera Caliente con Gemini + cuadros intermedios por script (PIL).

Uso: python3 tools/gen_boss_anim_art.py gen [pose ...]    (llama a la API; sin args = todas las que falten)
     python3 tools/gen_boss_anim_art.py build            (recorta, pixela, interpola y escribe assets + .tres)
Los originales de Gemini quedan en .claude_tmp/cera_raw/ (fuera de git). La key sale de
~/.kaggle/gemini_key (misma que gen_intro_art.py). Cada pose se pide con el diseno base y el sprite
actual como REFERENCIA para que no cambie de cara ni de colores, sobre fondo verde plano que se recorta.
Pixelado: se reduce a 156x180 (mismo grosor de pixel que el heroe) con paleta fija de ~36 colores
sin ampliar: el sprite va a scale 1.0 (BossAnimator lo ajusta al ver cuadros de alta densidad).
"""
import base64
import io
import json
import math
import os
import sys
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / ".claude_tmp/cera_raw"
OUT = ROOT / "assets/sprites/enemies"
MODEL = os.environ.get("GEMINI_IMAGE_MODEL", "gemini-3.1-flash-lite-image")
KEY_BG = (0, 255, 0)
CW, CH = 156, 180  # lienzo final 156x180 a escala 1: 1 pixel de arte = 1 unidad de juego, como el heroe (32x48)
K = 3  # factor respecto al lienzo viejo de 52x60 (las distancias de los efectos se dan en esas unidades)
CUR = ROOT / "assets/sprites/enemies/boss_cera_idle_00.png"

STYLE = (
    "Pixel art game sprite in the style of a 16-bit SNES/GBA game: chunky pixels, bold dark outlines, cel shading, "
    "limited palette, cute cartoon, big round eyes, humorous. Single character, FULL BODY visible, centered, facing "
    "the viewer slightly to the right, on a perfectly flat solid pure green (#00FF00) background with no ground, no "
    "shadow, no text, no border. The character is an abstract blob creature, NOT a human. "
)
BOSS = (
    "Dona Cera Caliente: a pink rectangular cooking-pot creature with a thick rim of dripping hot golden wax on top, "
    "a blue bow on her head, two round white eyes with black pupils, a small pink mouth, stubby arms and legs, a wooden "
    "ladle in one hand and a depilatory wax strip book/pad in the other, steam rising. Colors: hot pink body, golden "
    "wax, cream white, teal-blue bow, dark outline. "
)

POSES = {
    "base": "Neutral standing idle pose, smug and menacing, ladle held up at shoulder height. Clean readable design "
            "sheet pose, improved and more detailed than the reference but SAME character, same colors, same proportions.",
    "idle": "Relaxed idle pose, slight smile, ladle resting low, wax dripping from the rim, steam above.",
    "windup": "Anticipation pose before attacking: leaning far backwards, arms pulled back, ladle raised high over her head, "
              "eyes narrowed and angry, wax rim sloshing, mouth gritted.",
    "strike": "Strike pose: lunging forward with the whole body stretched, swinging the ladle down hard, throwing a "
              "long strip of golden wax, mouth wide open yelling, speed feeling.",
    "tired": "Exhausted and dizzy after attacking: slumped forward, panting with tongue out and sweat drops, eyes as "
             "swirls, arms hanging limp, ladle dragging on the ground, wax rim droopy, little stars circling her head.",
    "channel": "Channeling a healing spell: arms raised up to the sky, eyes closed in concentration, glowing pink-gold "
               "aura, golden wax flowing upward and swirling around her, steam rising, rim bubbling.",
    "damaged": "Damaged and furious: the same character but her pink pot body is cracked with dark crack lines and big "
               "melted wax drips sliding down her sides, the bow crooked and burnt, one eye twitching, angry teeth, "
               "wax rim half-melted and sagging.",
    "death": "Theatrical defeat: melting into a golden-pink puddle of wax, the pot collapsed and slumped, eyes as X, "
             "tongue out, the ladle falling, the blue bow sliding off, a white ghost-like steam puff rising.",
    "intro": "Dramatic entrance pose: both arms spread wide, chest out, grinning with confidence, ladle raised in one hand "
             "like a trophy, wax splashing around her feet as if she just landed, steam and sparkles.",
    "spit": "Spitting attack pose: head tilted back then thrust forward, mouth open spitting blobs of golden wax into the "
            "air in an arc, ladle held out to the side.",
    "cross": "Arms spread out horizontally in a T shape, holding two long wax strips in each hand forming a cross, "
             "spinning, dizzying angry face.",
    "pull": "Pulling pose: both hands gripping a long wax strip and yanking it back toward her, leaning back with feet "
            "planted, determined grin, straining.",
}
ORDER = ["base", "idle", "windup", "strike", "tired", "channel", "damaged", "death", "intro", "spit", "cross", "pull"]


def key() -> str:
    k = os.environ.get("GEMINI_API_KEY")
    if not k:
        k = (Path.home() / ".kaggle/gemini_key").read_text().strip()
    return k


def _img_part(im: Image.Image) -> dict:
    buf = io.BytesIO()
    im.convert("RGB").save(buf, "PNG")
    return {"inlineData": {"mimeType": "image/png", "data": base64.b64encode(buf.getvalue()).decode()}}


def _cur_ref() -> Image.Image:
    sp = Image.open(CUR).convert("RGBA")
    sp = sp.crop(sp.getbbox()).resize((sp.crop(sp.getbbox()).width * 6, sp.crop(sp.getbbox()).height * 6), Image.NEAREST)
    bg = Image.new("RGBA", (640, 760), (40, 40, 48, 255))
    bg.alpha_composite(sp, ((640 - sp.width) // 2, (760 - sp.height) // 2))
    return bg


def generate(name: str) -> Path:
    refs = [_img_part(_cur_ref())]
    note = ("The first reference image is the CURRENT low-res sprite of the character: keep its design. ")
    if name != "base":
        base = RAW / "base.png"
        refs.append(_img_part(Image.open(base)))
        note += ("The second reference image is the approved base design: the character MUST look exactly like it "
                 "(same face, same colors, same proportions, same art style), only the pose changes. ")
    text = STYLE + note + BOSS + "POSE: " + POSES[name]
    body = {
        "contents": [{"parts": refs + [{"text": text}]}],
        "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "1:1", "imageSize": "1K"}},
    }
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key()},
    )
    with urllib.request.urlopen(req, timeout=180) as r:
        data = json.load(r)
    for part in data["candidates"][0]["content"]["parts"]:
        if "inlineData" in part:
            RAW.mkdir(parents=True, exist_ok=True)
            out = RAW / f"{name}.png"
            out.write_bytes(base64.b64decode(part["inlineData"]["data"]))
            print("pose", name, Image.open(out).size, data.get("usageMetadata", {}))
            return out
    raise RuntimeError(f"{name}: sin imagen: {json.dumps(data)[:400]}")


# ---------------------------------------------------------------- recorte y pixelado
def cut_bg(im: Image.Image) -> Image.Image:
    """Quita el fondo verde plano: distancia al verde + relleno desde los bordes."""
    im = im.convert("RGB")
    w, h = im.size
    px = im.load()
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if g > 140 and g - max(r, b) > 60:
                mp[x, y] = 255
    # solo lo conectado a los bordes cuenta como fondo (no borra verde interior)
    seen = Image.new("L", (w, h), 0)
    sp = seen.load()
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or sp[x, y] or not mp[x, y]:
            continue
        sp[x, y] = 255
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    alpha = ImageChops.invert(seen).filter(ImageFilter.MinFilter(3))  # come el halo verde
    # el vapor sale verdoso (mezclado con el fondo): fuera, el vapor lo dibuja el codigo
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if ap[x, y] and g > r + 22 and g > b + 22:
                ap[x, y] = 0
    out = im.convert("RGBA")
    out.putalpha(alpha)
    return out


def load_pose(name: str) -> Image.Image:
    return cut_bg(Image.open(RAW / f"{name}.png"))


def pixelate_set(poses: dict, colors: int = 28) -> dict:
    """Pixela todas las poses con la MISMA escala (la de la base) y la misma paleta corta, 40x60."""
    boxes = {n: im.getbbox() for n, im in poses.items()}
    bb = boxes["base"]
    # escala: el cuerpo de la base ocupa ~52 px de alto en 60 (como el sprite actual)
    s = 150.0 / (bb[3] - bb[1])
    res = {}
    for n, im in poses.items():
        b = boxes[n]
        c = im.crop(b)
        k = s
        # si la pose (brazos extendidos, charco) no cabe, se achica solo esa pose
        k = min(k, (CW - 1.0) / c.width, (CH - 2.0) / c.height)
        c = down(c, max(1, round(c.width * k)), max(1, round(c.height * k)))
        cv = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
        # centrado en x, pegado abajo (pies en y=59)
        cv.alpha_composite(c, ((CW - c.width) // 2, CH - c.height))
        res[n] = cv
    # paleta fija con rampas de matiz + limpieza + contorno selectivo + luz (gen_boss_anim_polish)
    import gen_boss_anim_polish as pol
    return {n: Image.fromarray(pol.finish(np.array(im)), "RGBA") for n, im in res.items()}


PALETTE = [
    (13, 11, 15), (246, 75, 163), (245, 120, 177), (213, 67, 144), (158, 54, 111), (119, 44, 88),
    (255, 201, 60), (255, 232, 140), (221, 174, 56), (164, 129, 50), (255, 241, 214), (237, 190, 149),
    (63, 214, 232), (113, 220, 227), (49, 137, 153), (187, 112, 60), (139, 86, 56), (102, 60, 40),
    (219, 230, 224), (134, 138, 153), (255, 255, 255), (255, 72, 72), (255, 166, 68), (96, 20, 64),
    (255, 168, 205), (232, 98, 160), (184, 60, 126), (255, 214, 96), (196, 150, 52), (140, 104, 44),
    (255, 226, 190), (216, 160, 118), (90, 170, 190), (28, 24, 34), (70, 60, 80), (255, 140, 70),
]


def down(im: Image.Image, w: int, h: int) -> Image.Image:
    """Reduce conservando los contornos oscuros: promedio de caja, pero si el bloque trae contorno gana el pixel mas oscuro."""
    avg = np.array(im.resize((w, h), Image.BOX)).astype(np.int32)
    big = np.array(im.resize((w * 3, h * 3), Image.BOX)).astype(np.int32)
    lum = (big[:, :, 0] * 3 + big[:, :, 1] * 6 + big[:, :, 2]) // 10
    lum = np.where(big[:, :, 3] > 140, lum, 999)
    out = avg.copy()
    blocks = lum.reshape(h, 3, w, 3).transpose(0, 2, 1, 3).reshape(h, w, 9)
    colors = big[:, :, :3].reshape(h, 3, w, 3, 3).transpose(0, 2, 1, 3, 4).reshape(h, w, 9, 3)
    idx = blocks.argmin(-1)
    dark = np.take_along_axis(blocks, idx[:, :, None], -1)[:, :, 0]
    cnt = (blocks < 70).sum(-1)
    pick = np.take_along_axis(colors, idx[:, :, None, None], 2)[:, :, 0, :]
    use = (dark < 70) & (cnt >= 2)
    out[:, :, :3] = np.where(use[:, :, None], pick, out[:, :, :3])
    out[:, :, 3] = np.where(use, 255, out[:, :, 3])
    return Image.fromarray(out.clip(0, 255).astype(np.uint8), "RGBA")


def up2(im: Image.Image) -> Image.Image:
    return im.resize((CW * 2, CH * 2), Image.NEAREST)


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "build"
    if cmd == "gen":
        todo = sys.argv[2:] or ORDER
        for n in todo:
            if (RAW / f"{n}.png").exists() and len(sys.argv) <= 2:
                continue
            generate(n)
    else:
        import gen_boss_anim_frames  # cuadros intermedios y SpriteFrames
        gen_boss_anim_frames.build()
