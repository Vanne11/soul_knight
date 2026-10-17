"""Genera sprites de items 24x24 en pixel art a partir de mapas ASCII.

Uso: python3 tools/gen_item_art.py [id ...]   (sin args = todos)
Estilo igual a los items existentes: contorno #0d0b0f + 3 tonos por material.
"""
import sys
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets/sprites/items"

PAL = {
    "o": (13, 11, 15),        # contorno
    "w": (255, 255, 255),
    # rosa
    "p": (255, 150, 214), "P": (232, 84, 178), "d": (150, 40, 118),
    # gris metal
    "g": (216, 221, 227), "G": (134, 138, 153), "k": (70, 72, 86),
    # electricidad
    "c": (120, 240, 255), "y": (255, 240, 110), "b": (60, 140, 255),
    # rose gold
    "r": (255, 214, 196), "R": (232, 158, 140), "D": (160, 92, 86),
    "h": (60, 20, 40),        # hueco
}

SPRITES = {
    "dildo_taser": [
        "........................",
        "........................",
        "........................",
        "......................y.",
        ".....................c..",
        "..ooo..........oooo..y.c",
        ".ogGko........oppppo.c..",
        ".ogGkooooooooopPPPPPo.y.",
        ".ogGkoppppppppdpPPPPPocy",
        ".ogGkoPPPPPPPPdPPPPPPoyc",
        ".ogGkoPPPPPPPPdPPPPPPocy",
        ".ogGkoddddddddddPPPPdo.y",
        ".ogGkooooooooooddddo.c..",
        ".ogGko...okGGo.oooo..y..",
        "..ooo....oGGGo.......c..",
        ".........okGGo..........",
        ".........oGGGo..........",
        "........okGGo...........",
        "........oGGGo...........",
        "........ooooo...........",
        "........................",
        "........................",
        "........................",
        "........................",
    ],
    "satisfyer": [
        "........................",
        "........................",
        "........oooooooo........",
        ".......orrrrrrrRo.......",
        "......orrRoooooRRo......",
        "......orRohhhhoRDo......",
        "......orRohhhhoRDo......",
        "......orRRoooooRDo......",
        ".......oRRRRRRRDo.......",
        "........oRRRRRDo........",
        "........orRRRRDo........",
        ".......orrRRRRRDo.......",
        ".......orRRRRRRDo.......",
        "......orrRRRRRRRDo......",
        "......orRRRwwRRRDo......",
        "......orRRRRRRRRDo......",
        "......orRRRRRRRRDo......",
        "......orRRRRRRRRDo......",
        ".......oRRRRRRRDo.......",
        ".......oDRRRRRDDo.......",
        "........oDDDDDDo........",
        ".........oooooo.........",
        "........................",
        "........................",
    ],
}


def render(name: str) -> Image.Image:
    rows = SPRITES[name]
    assert len(rows) == 24, f"{name}: {len(rows)} filas"
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        assert len(row) == 24, f"{name} fila {y}: {len(row)} cols"
        for x, ch in enumerate(row):
            if ch != ".":
                im.putpixel((x, y), PAL[ch] + (255,))
    return im


if __name__ == "__main__":
    for name in sys.argv[1:] or SPRITES:
        render(name).save(OUT / f"{name}.png")
        print("ok", name)
