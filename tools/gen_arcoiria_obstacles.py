"""Arma el arte de obstaculos de Arcoiria (assets/sprites/environment/obstacles/orgullo/).

Uso: python3 tools/gen_arcoiria_obstacles.py
Parte del decor ya recortado de las hojas de Gemini (assets/sprites/environment/decor/orgullo_*.png,
ver tools/arc2_cut.py), asi que mantiene el mismo estilo y paleta. Piezas (igual que gen_obstacle_art.py):
  rock_a = carro de fiesta, rock_b = maceta, column = farol, barrel = tambor, crate = regalos,
  extra = banco pastel (dibujado aqui), *_broken y chunk = restos con confeti, spikes = pinchos caramelo.
Determinista (semillas fijas).
"""
import random
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
DECOR = ROOT / "assets/sprites/environment/decor"
OUT = ROOT / "assets/sprites/environment/obstacles/orgullo"
MIXTO = ROOT / "assets/sprites/environment/obstacles/mixto"
OL = (13, 11, 15, 255)
CONFETI = [(242, 112, 138, 255), (246, 200, 74, 255), (90, 200, 138, 255), (90, 138, 230, 255), (168, 106, 224, 255)]


def decor(name):
    return Image.open(DECOR / f"orgullo_{name}.png").convert("RGBA")


def save(im, name):
    OUT.mkdir(parents=True, exist_ok=True)
    im.save(OUT / f"{name}.png")


def bench():
    im = Image.new("RGBA", (66, 30))
    d = ImageDraw.Draw(im)
    wood, hi = (214, 176, 120, 255), (240, 212, 160, 255)
    for x in (5, 55):  # patas
        d.rectangle([x, 14, x + 5, 28], fill=(150, 112, 80, 255), outline=OL)
    for y, c in ((15, wood), (8, wood)):  # asiento y respaldo
        d.rectangle([1, y, 64, y + 5], fill=c, outline=OL)
        d.line([2, y + 1, 63, y + 1], fill=hi)
    for i, x in enumerate(range(2, 64, 12)):  # listones pastel en el respaldo
        d.rectangle([x, 9, x + 9, 12], fill=[(244, 184, 200, 255), (184, 224, 208, 255), (184, 200, 240, 255)][i % 3])
    d.line([4, 29, 62, 29], fill=(0, 0, 0, 60))
    return im


def broken(src, h, seed):
    """Mitad de abajo del objeto con confeti alrededor."""
    rng = random.Random(seed)
    base = src.crop((0, src.height - h // 2 - 4, src.width, src.height))
    im = Image.new("RGBA", (src.width, h))
    im.alpha_composite(base, (0, h - base.height))
    for _ in range(12):
        x, y = rng.randrange(1, im.width - 2), rng.randrange(2, h - 2)
        c = rng.choice(CONFETI)
        im.putpixel((x, y), c)
        im.putpixel((x + 1, y), c)
    return im


def chunks():
    im = Image.new("RGBA", (24, 6))
    d = ImageDraw.Draw(im)
    for i, c in enumerate(CONFETI[:4]):
        d.rectangle([i * 6, 0, i * 6 + 5, 5], fill=c, outline=OL)
    return im


def spikes(name):
    """Pinchos del Perineo teñidos de rosa caramelo (misma silueta, para que midan igual)."""
    src = Image.open(MIXTO / f"{name}.png").convert("RGBA")
    px = src.load()
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = px[x, y]
            if a:
                lum = (r + g + b) / 3 / 255
                px[x, y] = (int(60 + 190 * lum), int(40 + 150 * lum), int(70 + 160 * lum), a)
    return src


def main():
    drum, gifts = decor("tambor"), decor("regalos")
    save(decor("carro"), "rock_a")
    save(decor("maceta"), "rock_b")
    save(decor("farol"), "column")
    save(drum, "barrel")
    save(gifts, "crate")
    save(bench(), "extra")
    save(broken(drum, 22, "tambor"), "barrel_broken")
    save(broken(gifts, 24, "regalos"), "crate_broken")
    save(chunks(), "chunk")
    save(spikes("spikes"), "spikes")
    save(spikes("spikes_s"), "spikes_s")


if __name__ == "__main__":
    main()
