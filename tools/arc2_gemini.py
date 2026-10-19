"""Llamadas a Gemini para el arte definitivo de Arcoiria (tools/gen_arcoiria_art2.py).

Cada hoja es UNA imagen con todas las poses (regla de Nico: nunca cuadro a cuadro). Los originales
quedan en .claude/arte_fuente/arcoiria/<hoja>.png (fuera de git). La key sale de GEMINI_API_KEY o de
~/.kaggle/gemini_key; el modelo de GEMINI_IMAGE_MODEL.
"""
import base64
import io
import json
import os
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / ".claude/arte_fuente/arcoiria"
MODEL = os.environ.get("GEMINI_IMAGE_MODEL", "gemini-3.1-flash-image")

STYLE = (
    "Premium indie pixel art in the style of Enter the Gungeon and Dead Cells: crisp chunky pixels (low-res look, "
    "no anti-aliasing blur, no gradients), a clean 1-pixel near-black outline, rich cel shading with hue-shifted "
    "shadows and bright highlights, strong readable silhouettes and strong light/dark value contrast, expressive "
    "faces, a humorous satirical tone. Characters face RIGHT in a three-quarter top-down game view. "
    "Background: ONE perfectly flat solid pure green (#00FF00) with no ground, no cast shadows, no text, no labels, "
    "no grid lines, no borders. Every pose sits in its own cell with generous empty green space around it; poses never "
    "touch or overlap each other and nothing is cropped. Never use pure green (#00FF00) inside the artwork. "
)


def key() -> str:
    k = os.environ.get("GEMINI_API_KEY")
    if not k:
        k = (Path.home() / ".kaggle/gemini_key").read_text().strip()
    return k


def _img_part(im: Image.Image) -> dict:
    buf = io.BytesIO()
    im.convert("RGB").save(buf, "PNG")
    return {"inlineData": {"mimeType": "image/png", "data": base64.b64encode(buf.getvalue()).decode()}}


def generate(name: str, prompt: str, aspect="16:9", size="2K", refs=()) -> Path:
    """UNA llamada a Gemini: devuelve la ruta de la hoja guardada en RAW/<name>.png."""
    parts = [_img_part(r) for r in refs] + [{"text": prompt}]
    body = {
        "contents": [{"parts": parts}],
        "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": aspect, "imageSize": size}},
    }
    req = urllib.request.Request(
        f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "x-goog-api-key": key()},
    )
    with urllib.request.urlopen(req, timeout=300) as r:
        data = json.load(r)
    for part in data["candidates"][0]["content"]["parts"]:
        if "inlineData" in part:
            RAW.mkdir(parents=True, exist_ok=True)
            out = RAW / f"{name}.png"
            out.write_bytes(base64.b64decode(part["inlineData"]["data"]))
            print("hoja", name, Image.open(out).size, data.get("usageMetadata", {}))
            return out
    raise RuntimeError(f"{name}: sin imagen: {json.dumps(data)[:500]}")
