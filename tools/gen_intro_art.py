"""Ilustraciones de la intro con Gemini (modelo de imagen barato) + pixelado.

Uso: python3 tools/gen_intro_art.py [n|menu|gameover|victory ...]   (sin args = las 9 diapositivas)
Lee la key de ~/.kaggle/gemini_key (o GEMINI_API_KEY). Guarda el original en
tools/_intro_raw/ (ignorado) y la version final 320x180 en
assets/sprites/intro/slide_NN.png: se reduce, se cuantiza a una paleta corta y
el juego la muestra a 4x con filtro nearest => pixel art de verdad, nitido.
Nota: la slide_00 original traia dibujado "PENELANDIA / VULVANIA" (el modelo no hizo caso al
"No text"); se borraron esos rotulos a mano en el PNG final para que valga en todos los idiomas.
Si se regenera, revisar que no vuelva a salir texto dibujado.
"""
import base64
import json
import os
import sys
import urllib.request
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RAW = Path(__file__).resolve().parent / "_intro_raw"
OUT = ROOT / "assets/sprites/intro"
MODEL = os.environ.get("GEMINI_IMAGE_MODEL", "gemini-3.1-flash-lite-image")
W, H, COLORS = 320, 180, 40

STYLE = (
    "Wide 16:9 retro pixel art illustration in the style of a 16-bit SNES/GBA game cutscene. "
    "Chunky pixels, bold dark outlines, limited palette, cel shading, cute cartoon characters with big round eyes, "
    "humorous tone. No text, no letters, no UI, no watermark. Full-bleed scene that fills the whole frame edge to edge: "
    "no borders, no frames, no black bars, no letterboxing. Main subject slightly above the center. "
)

CREATURES = (
    "IMPORTANT: there are NO humans, NO humanoid people and NO animals. Every character is a cute abstract "
    "blob creature drawn exactly in the style of the attached reference sprites: chunky simple shapes, big round "
    "cartoon eyes, tiny stubby legs. "
)
PENE = ("Penelandia citizens are like the first reference sheet: pink capsule-shaped creatures with golden Greek "
        "hoplite helmets and red crests, wrinkly pink round creatures with one sleepy eye and a curly tail on top, "
        "tiny white tadpoles with blue tails, teal pear-shaped creatures. ")
VULVA = ("Vulvania citizens are like the second reference sheet: magenta bean-shaped creatures with winged Viking "
         "helmets, round pale-pink egg creatures wearing tiny golden crowns, hot pink tube-shaped creatures with a "
         "frilly end. ")

SLIDES = [
    "Two rival fantasy kingdoms facing each other across a sunny valley with a river in the middle. "
    "Left: PENELANDIA, a blue and gold kingdom of ancient Greek columns, sturdy round towers and banners. "
    "Right: VULVANIA, a pink and magenta kingdom of curvy organic architecture, flowers, hearts and lush gardens. "
    "Bright, colorful, joyful, uncensored world. Small cute citizens waving from both sides. " + CREATURES + PENE + VULVA,
    "A tense comic cold war across a border fence on a battlefield under a dramatic red sky. Left: an army of Penelandia "
    "creatures in formation with spears and round shields. Right: an army of Vulvania creatures in formation. "
    "They glare at each other. In the middle, on a little pedestal like a diplomatic incident, a toilet with its seat "
    "lifted up. " + CREATURES + PENE + VULVA,
    "Comic allergy scene split in two halves. Left half: the pink capsule hoplite creature (first reference) sneezing "
    "violently inside a pink flowery land full of pollen. Right half: the magenta winged-helmet creature (second "
    "reference) sneezing and crying big emotional tears inside a blue land of Greek columns. Tissues flying. " + CREATURES,
    "A giant prim green fig leaf character floating in the sky with tiny round glasses and a pearl necklace, arms crossed, "
    "looking down in disapproval, dramatic light rays behind her, the colorful kingdoms below look up in fear.",
    "The giant fig leaf lady covering everything: classical statues and paintings get fig leaves stuck on them, books are closed, "
    "and the color drains from the world: the landscape is turning gray and desaturated from right to left.",
    "A gloomy gray desaturated village where grumpy creatures from both kingdoms wander around with black censorship "
    "bars over their eyes and blurry pixelated censor squares on their bodies; they look irritated and ready to fight. "
    "Overcast sky. Also a small green crab-like louse creature with big eyes. " + CREATURES + PENE + VULVA,
    "Three small heroes seen from behind on a hill: a pink hero with a golden Greek hoplite helmet and red crest, "
    "a magenta valkyrie with a winged helmet, and a teal platypus with a straw hat. They look toward a distant gray palace "
    "on a mountain, beyond a wild jungle, a blue kingdom and a pink kingdom. Epic adventure mood, sunset.",
    "A cute hero holding up a glowing potion vial with a gender symbol on it, sparkles around, while sneezing comically; "
    "a blue vial with the male symbol and a pink vial with the female symbol float nearby. Magical laboratory background.",
    "A smug old-fashioned radio microphone character with a mustache standing on a small theater stage under a spotlight, "
    "red velvet curtains, as if narrating a story, winking at the viewer. Cozy dark background.",
]


## Imagenes de referencia por diapositiva (mantener personajes consistentes).
## "raw:N" = la ilustracion original de otra diapositiva; si no, ruta del proyecto.
PORTRAITS = ["assets/sprites/player/%s/portrait.png" % c for c in ("pitocles", "vulvalquiria", "ornitorrinco")]
SHEETS = {
    "penelandia": ["player/pitocles/idle_00", "enemies/testiculo_idle_00", "enemies/espermatozoide_idle_00", "enemies/vesicula_idle_00"],
    "vulvania": ["player/vulvalquiria/idle_00", "enemies/ovulo_idle_00", "enemies/trompa_idle_00"],
    "pitocles": ["player/pitocles/idle_00"],
    "vulvalquiria": ["player/vulvalquiria/idle_00"],
    "ladilla": ["enemies/ladilla_idle_00"],
    "ornitorrinco": ["player/ornitorrinco/idle_00"],
}
REFS = {
    0: ["sheet:penelandia", "sheet:vulvania"],
    1: ["sheet:penelandia", "sheet:vulvania"],
    2: ["sheet:pitocles", "sheet:vulvalquiria"],
    5: ["sheet:penelandia", "sheet:vulvania", "sheet:ladilla"],
    4: ["raw:3"],
    6: PORTRAITS,
    7: PORTRAITS[:1],
}
REF_NOTE = {
    4: "The fig leaf lady MUST be exactly the same green fig leaf character from the reference image "
       "(a leaf with a face, tiny round glasses and a pearl necklace), not a human. ",
    6: "The three heroes MUST look like the three characters in the reference portraits: "
       "1) pink hero with golden Greek helmet and red crest, 2) magenta valkyrie with winged helmet, 3) teal platypus with straw hat. ",
    7: "The hero MUST be the character from the reference portrait: a pink hero with a golden Greek hoplite helmet and red crest, round glasses-like eyes. ",
}


def _sheet(name: str) -> Image.Image:
    """Hoja de referencia: los sprites del juego agrandados en fila."""
    fs = SHEETS[name]
    im = Image.new("RGBA", (len(fs) * 200, 300), (40, 40, 48, 255))
    for i, f in enumerate(fs):
        sp = Image.open(ROOT / f"assets/sprites/{f}.png").convert("RGBA")
        sp = sp.crop(sp.getbbox())
        k = min(180 // sp.width, 280 // sp.height)
        sp = sp.resize((sp.width * k, sp.height * k), Image.NEAREST)
        im.alpha_composite(sp, (i * 200 + (200 - sp.width) // 2, 290 - sp.height))
    return im


def _ref_part(ref: str) -> dict:
    if ref.startswith("sheet:"):
        im = _sheet(ref[6:])
    else:
        path = RAW / f"slide_{int(ref[4:]):02d}.png" if ref.startswith("raw:") else ROOT / ref
        im = Image.open(path).convert("RGBA")
    if im.width < 256:  # retratos 64x64: agrandar sin suavizar
        im = im.resize((256, 256), Image.NEAREST)
    bg = Image.new("RGB", im.size, (40, 40, 48))
    bg.paste(im, mask=im.split()[3])
    import io
    buf = io.BytesIO()
    bg.save(buf, "PNG")
    return {"inlineData": {"mimeType": "image/png", "data": base64.b64encode(buf.getvalue()).decode()}}


## Pantallas fuera de la intro: nombre -> (prompt, refs). Salen en assets/sprites/ui/screens/.
SCREENS = {
    "menu": ("Title screen key art. In the foreground on a grassy hill, the three heroes facing the viewer, heroic poses: "
             "a pink capsule hero with a golden Greek hoplite helmet, red crest and round shield (first reference), a magenta "
             "bean-shaped valkyrie with a winged helmet (second reference), a teal platypus with a straw hat (third reference). "
             "Behind them on the left the blue Greek-column kingdom, on the right the pink flowery kingdom, and far away in the "
             "center a gray gloomy palace on a mountain with a giant fig leaf banner, gray clouds of censorship leaking from it. "
             "The upper third is open sky with soft clouds and nothing else (the game logo goes there). " + CREATURES,
             ["sheet:pitocles", "sheet:vulvalquiria", "sheet:ornitorrinco"]),
    "gameover": ("A gloomy funny game over scene in a gray censored graveyard at night: a small tombstone with a pixel skull, "
                 "and the ghost of the pink capsule hero with a golden Greek helmet (reference) floating out of it, looking "
                 "embarrassed. Behind, the giant green fig leaf character with tiny round glasses and pearl necklace laughs at "
                 "him smugly. Moonlight, purple and gray tones. " + CREATURES,
                 ["sheet:pitocles", "raw:3"]),
    "victory": ("A joyful victory celebration: color bursting back into the world like a rainbow wave, fireworks and confetti, "
                "the three heroes (references) cheering on top of the ruins of a gray palace, a torn fig leaf flag on the ground, "
                "creatures from the blue and pink kingdoms dancing together below. " + CREATURES,
                ["sheet:pitocles", "sheet:vulvalquiria", "sheet:ornitorrinco"]),
}


def key() -> str:
    k = os.environ.get("GEMINI_API_KEY")
    if not k:
        k = (Path.home() / ".kaggle/gemini_key").read_text().strip()
    return k


def _image_config() -> dict:
    cfg = {"aspectRatio": "16:9"}
    if os.environ.get("GEMINI_IMAGE_SIZE"):  # p.ej. "1K"
        cfg["imageSize"] = os.environ["GEMINI_IMAGE_SIZE"]
    return cfg


def generate(n) -> Path:
    if isinstance(n, str):
        prompt, refs = SCREENS[n]
        text = STYLE + prompt
    else:
        refs = REFS.get(n, [])
        text = STYLE + REF_NOTE.get(n, "") + SLIDES[n]
    body = {
        "contents": [{"parts": [_ref_part(r) for r in refs] + [{"text": text}]}],
        "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": _image_config()},
    }
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key()},
    )
    with urllib.request.urlopen(req, timeout=180) as r:
        data = json.load(r)
    usage = data.get("usageMetadata", {})
    for part in data["candidates"][0]["content"]["parts"]:
        if "inlineData" in part:
            RAW.mkdir(exist_ok=True)
            out = RAW / (f"{n}.png" if isinstance(n, str) else f"slide_{n:02d}.png")
            out.write_bytes(base64.b64decode(part["inlineData"]["data"]))
            print(f"slide {n}: {Image.open(out).size} tokens={usage}")
            return out
    raise RuntimeError(f"slide {n}: sin imagen: {json.dumps(data)[:400]}")


def pixelate(src: Path, n) -> None:
    im = Image.open(src).convert("RGB")
    # recorte 16:9 centrado por si el modelo devuelve otra proporcion
    w, h = im.size
    if w / h > W / H:
        nw = int(h * W / H)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w * H / W)
        im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    im = im.resize((W, H), Image.LANCZOS)
    im = im.quantize(COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    dst = ROOT / f"assets/sprites/ui/screens/{n}.png" if isinstance(n, str) else OUT / f"slide_{n:02d}.png"
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)


if __name__ == "__main__":
    for n in [a if a in SCREENS else int(a) for a in sys.argv[1:]] or range(len(SLIDES)):
        raw = RAW / (f"{n}.png" if isinstance(n, str) else f"slide_{n:02d}.png")
        if not raw.exists() or os.environ.get("REGEN"):
            raw = generate(n)
        pixelate(raw, n)
