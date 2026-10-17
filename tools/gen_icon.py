"""Genera el icono del juego (assets/icon.png y assets/icon.ico).

Uso: python3 tools/gen_icon.py
Solo Vulvalquiria, sin fondo: su sprite idle recortado, centrado en un cuadrado
transparente y con un contorno oscuro de 1 px para que se lea en tamanos chicos.
Se guarda a 256 (NEAREST) y el .ico lleva los tamanos que pide Windows.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
HERO = ROOT / "assets/sprites/player/vulvalquiria/idle_00.png"
OUTLINE = (13, 11, 15, 255)


def main():
    hero = Image.open(HERO).convert("RGBA")
    hero = hero.crop(hero.getbbox())
    side = max(hero.width, hero.height) + 4  # 2 px de aire para el contorno
    im = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    hx = (side - hero.width) // 2
    hy = (side - hero.height) // 2
    sil = Image.new("RGBA", hero.size, OUTLINE)
    alpha = hero.split()[3]
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        im.paste(sil, (hx + dx, hy + dy), alpha)
    im.paste(hero, (hx, hy), hero)

    big = im.resize((256, 256), Image.NEAREST)
    big.save(ROOT / "assets/icon.png")
    big.save(ROOT / "assets/icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("icono listo: assets/icon.png, assets/icon.ico")


if __name__ == "__main__":
    main()
