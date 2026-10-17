"""Genera el icono del juego (assets/icon.png y assets/icon.ico).

Uso: python3 tools/gen_icon.py
Arte a 64x64 (paleta del HUD: morado noche + oro) con Pitocles sobre un halo rosado
y su barra de censura, como manda el reino. Se guarda a 256 (NEAREST) y el .ico
lleva los tamanos que pide Windows.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
HERO = ROOT / "assets/sprites/player/pitocles/idle_00.png"

O = (13, 11, 15, 255)
BG0 = (26, 15, 38, 255)
BG1 = (40, 24, 58, 255)
G0 = (255, 241, 168, 255)
G1 = (240, 192, 74, 255)
G2 = (176, 141, 74, 255)
G3 = (110, 79, 36, 255)
PINK = (255, 90, 170)
BAR = (8, 6, 10, 255)
CREAM = (242, 234, 214, 255)

S = 64


def rounded_mask(size, r):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], r, fill=255)
    return m


def main():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = im.load()
    # Fondo: degradado vertical morado + halo rosado tras el heroe (en escalones, pixel art).
    for y in range(S):
        for x in range(S):
            t = y / (S - 1)
            c = tuple(int(BG1[i] * (1 - t) + BG0[i] * t) for i in range(3))
            d = ((x - 32) ** 2 + ((y - 30) * 1.1) ** 2) ** 0.5
            k = 0.0
            for r, a in ((26, 0.18), (20, 0.32), (14, 0.48)):
                if d < r:
                    k = a
            c = tuple(int(c[i] * (1 - k) + PINK[i] * k) for i in range(3))
            px[x, y] = c + (255,)
    # Marco dorado con bisel (luz arriba-izquierda, sombra abajo-derecha).
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, S - 1, S - 1], 9, outline=O, width=1)
    d.rounded_rectangle([1, 1, S - 2, S - 2], 8, outline=G2, width=2)
    d.arc([1, 1, 18, 18], 180, 270, fill=G0)
    d.line([9, 1, 40, 1], fill=G1)
    d.line([1, 9, 1, 40], fill=G1)
    d.line([24, S - 2, S - 10, S - 2], fill=G3)
    d.line([S - 2, 24, S - 2, S - 10], fill=G3)
    d.rounded_rectangle([3, 3, S - 4, S - 4], 6, outline=O, width=1)
    # Heroe: Pitocles con contorno oscuro de 1 px para que se lea en chico.
    hero = Image.open(HERO).convert("RGBA")
    bbox = hero.getbbox()
    hero = hero.crop(bbox)
    hx = (S - hero.width) // 2
    hy = S - 6 - hero.height
    alpha = hero.split()[3]
    sil = Image.new("RGBA", hero.size, O)
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        im.paste(sil, (hx + dx, hy + dy), alpha)
    # Sombra en el suelo.
    d.ellipse([hx + 2, S - 9, hx + hero.width - 3, S - 5], fill=(10, 6, 14, 255))
    im.paste(hero, (hx, hy), hero)
    # Barra de censura sobre la cadera (el chiste de la casa).
    by = hy + int(hero.height * 0.66)
    d.rectangle([hx - 3, by, hx + hero.width + 2, by + 4], fill=BAR)
    d.line([hx - 2, by + 1, hx + hero.width + 1, by + 1], fill=(40, 34, 46, 255))
    # Destellos dorados.
    for sx, sy in ((10, 12), (53, 16), (50, 44)):
        d.point([(sx, sy)], fill=G0)
        d.point([(sx - 1, sy), (sx + 1, sy), (sx, sy - 1), (sx, sy + 1)], fill=G1)
    # Esquinas transparentes.
    im.putalpha(Image.composite(im.split()[3], Image.new("L", (S, S), 0), rounded_mask(S, 9)))

    big = im.resize((256, 256), Image.NEAREST)
    big.save(ROOT / "assets/icon.png")
    big.save(ROOT / "assets/icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("icono listo: assets/icon.png, assets/icon.ico")


if __name__ == "__main__":
    main()
