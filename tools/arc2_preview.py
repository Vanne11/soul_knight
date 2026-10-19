"""Hoja de contacto del arte de Arcoiria (suelo, muros, decorado, iconos) para revisarlo a ojo."""
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def main(dest):
    S = 3
    bg = (58, 56, 84, 255)
    items = []
    for p in ["assets/sprites/environment/floors/floor_orgullo.png", "assets/sprites/environment/walls/orgullo/atlas.png"]:
        items.append(Image.open(ROOT / p).convert("RGBA"))
    small = []
    wd = ROOT / "assets/sprites/environment/walls/orgullo"
    for n in ["zocalo_top", "zocalo_bottom", "zocalo_side", "banner", "painting", "window", "frame", "step"]:
        small.append(Image.open(wd / f"{n}.png").convert("RGBA"))
    for n in ["guirnalda", "farol", "maceta", "mural", "carro", "sombrilla", "tambor", "regalos", "banderin"]:
        small.append(Image.open(ROOT / f"assets/sprites/environment/decor/orgullo_{n}.png").convert("RGBA"))
    for n in ["rojo", "naranja", "amarillo", "verde", "azul", "violeta", "completa"]:
        small.append(Image.open(ROOT / f"assets/sprites/items/bandera_{n}.png").convert("RGBA"))
    W = 1500
    sheet = Image.new("RGBA", (W, 1400), bg)
    y = 0
    for im in items:
        k = 2 if im.width > 300 else 3
        sheet.alpha_composite(im.resize((im.width * k, im.height * k), Image.NEAREST), (0, y))
        y += im.height * k + 8
    x = 0
    rowh = 0
    for im in small:
        k = 3
        r = im.resize((im.width * k, im.height * k), Image.NEAREST)
        if x + r.width > W:
            x, y, rowh = 0, y + rowh + 8, 0
        sheet.alpha_composite(r, (x, y))
        x += r.width + 10
        rowh = max(rowh, r.height)
    sheet.crop((0, 0, W, y + rowh + 4)).convert("RGB").save(Path(dest) / "mundo.png")


main(sys.argv[1])
