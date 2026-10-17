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


# ---------------------------------------------------------------- consumibles de afinidad
# Dibujados con primitivas (mas rapido que mapas ASCII) y contorno automatico #0d0b0f.
from PIL import ImageDraw

OL = (13, 11, 15, 255)


def _outline(im: Image.Image) -> Image.Image:
    w, h = im.size
    src, out = im.load(), im.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] and src[nx, ny] != OL:
                    dst[x, y] = OL
                    break
    return out


def _new():
    im = Image.new("RGBA", (24, 24), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def _c(r, g, b):
    return (r, g, b, 255)


def art_chocolate_bar():
    im, d = _new()
    foil, foil_d = _c(222, 226, 235), _c(150, 156, 176)
    brown, brown_h, brown_d = _c(124, 72, 40), _c(160, 100, 58), _c(78, 42, 24)
    d.rectangle([4, 11, 18, 20], fill=foil)           # envoltorio plateado
    d.rectangle([4, 19, 18, 20], fill=foil_d)
    d.polygon([(5, 11), (18, 11), (20, 3), (7, 3)], fill=brown)   # barra asomando
    for x0 in (8, 12, 16):
        d.line([(x0, 4), (x0 - 1, 10)], fill=brown_d)
    d.line([(7, 7), (19, 7)], fill=brown_d)
    d.line([(6, 4), (19, 4)], fill=brown_h)
    d.rectangle([4, 11, 18, 12], fill=_c(240, 120, 150))          # banda rosa del envoltorio
    d.rectangle([8, 14, 14, 17], fill=_c(255, 235, 240))          # etiqueta
    d.point([(10, 15), (12, 15)], fill=_c(232, 84, 120))
    return _outline(im)


def art_wet_wipe():
    im, d = _new()
    d.rounded_rectangle([5, 4, 18, 20], radius=2, fill=_c(190, 230, 250))
    d.rectangle([5, 4, 18, 6], fill=_c(120, 190, 235))             # sello superior
    d.rectangle([5, 18, 18, 20], fill=_c(120, 190, 235))
    d.polygon([(12, 8), (15, 13), (14, 15), (10, 15), (9, 13)], fill=_c(255, 255, 255))   # gota
    d.line([(10, 13), (10, 14)], fill=_c(120, 190, 235))
    d.line([(6, 5), (17, 5)], fill=_c(160, 210, 245))
    return _outline(im)


def art_chamomile_tea():
    im, d = _new()
    d.ellipse([3, 17, 20, 21], fill=_c(214, 220, 232))             # plato
    d.rounded_rectangle([5, 9, 16, 19], radius=3, fill=_c(250, 246, 236))
    d.rectangle([5, 9, 16, 10], fill=_c(232, 190, 90))             # te
    d.arc([14, 11, 21, 17], 270, 90, fill=_c(250, 246, 236), width=2)  # asa
    d.rectangle([7, 12, 8, 17], fill=_c(255, 255, 255))
    d.line([(6, 14), (15, 14)], fill=_c(130, 180, 120))            # cinta verde
    # flor de manzanilla
    d.ellipse([10, 2, 16, 8], fill=_c(255, 255, 255))
    d.ellipse([11, 3, 15, 7], fill=_c(255, 255, 255))
    d.rectangle([12, 4, 14, 6], fill=_c(255, 210, 60))
    d.line([(13, 8), (13, 9)], fill=_c(90, 160, 90))
    return _outline(im)


def art_ibuprofen():
    im, d = _new()
    d.rounded_rectangle([3, 5, 20, 19], radius=2, fill=_c(238, 238, 244))   # blister
    d.rectangle([3, 5, 20, 6], fill=_c(210, 214, 226))
    for (x0, y0) in ((5, 8), (12, 8), (5, 14), (12, 14)):
        d.ellipse([x0, y0, x0 + 6, y0 + 4], fill=_c(255, 150, 60))
        d.line([(x0 + 1, y0 + 1), (x0 + 3, y0 + 1)], fill=_c(255, 210, 150))
    return _outline(im)


def art_lube_gel():
    im, d = _new()
    d.polygon([(7, 7), (17, 7), (16, 21), (8, 21)], fill=_c(120, 220, 210))   # sobre/tubo
    d.rectangle([8, 3, 16, 7], fill=_c(240, 240, 250))                         # tapa
    d.line([(9, 4), (15, 4)], fill=_c(255, 255, 255))
    d.rectangle([9, 11, 15, 15], fill=_c(255, 255, 255))
    d.polygon([(12, 11), (14, 14), (10, 14)], fill=_c(60, 170, 200))           # gotita
    d.line([(9, 8), (9, 20)], fill=_c(170, 245, 235))
    d.line([(15, 8), (15, 20)], fill=_c(70, 170, 170))
    return _outline(im)


def art_hot_water_bottle():
    im, d = _new()
    body, body_h, body_d = _c(244, 110, 160), _c(255, 160, 200), _c(180, 56, 112)
    d.rounded_rectangle([4, 7, 19, 21], radius=5, fill=body)
    for y in (11, 14, 17):                                    # ranuras de goma
        d.line([(7, y), (16, y)], fill=body_d)
    d.line([(6, 9), (6, 17)], fill=body_h)
    d.rectangle([5, 3, 9, 7], fill=_c(230, 230, 240))         # tapon
    d.rectangle([5, 3, 9, 4], fill=_c(255, 255, 255))
    # vapor
    d.line([(15, 2), (16, 4)], fill=_c(255, 255, 255))
    d.line([(18, 1), (17, 3)], fill=_c(255, 255, 255))
    return _outline(im)


def art_menstrual_cup():
    im, d = _new()
    body, body_h, body_d = _c(196, 120, 220), _c(226, 170, 242), _c(130, 70, 160)
    d.polygon([(5, 5), (18, 5), (16, 17), (7, 17)], fill=body)    # copa
    d.ellipse([5, 3, 18, 8], fill=body_h)
    d.ellipse([7, 4, 16, 7], fill=_c(90, 40, 120))                 # boca
    d.line([(7, 9), (8, 16)], fill=body_h)
    d.line([(16, 9), (15, 16)], fill=body_d)
    d.rectangle([11, 17, 12, 21], fill=body_d)                     # tallo
    d.rectangle([10, 21, 13, 21], fill=body)
    # refuerzo
    d.line([(8, 12), (15, 12)], fill=_c(255, 215, 90))
    return _outline(im)


def art_morning_after_pill():
    im, d = _new()
    d.rounded_rectangle([3, 8, 20, 19], radius=2, fill=_c(250, 244, 250))     # cajita
    d.rectangle([3, 8, 20, 10], fill=_c(232, 84, 178))
    d.ellipse([7, 3, 17, 13], fill=_c(255, 255, 255))                          # pastilla
    d.pieslice([7, 3, 17, 13], 90, 270, fill=_c(255, 150, 214))
    d.line([(12, 3), (12, 13)], fill=_c(200, 120, 170))
    d.line([(9, 5), (10, 4)], fill=_c(255, 255, 255))
    d.line([(7, 15), (16, 15)], fill=_c(232, 84, 178))
    d.line([(7, 17), (13, 17)], fill=_c(190, 190, 205))
    return _outline(im)


def art_viagra_feria():
    im, d = _new()
    d.polygon([(12, 3), (21, 12), (12, 21), (3, 12)], fill=_c(70, 150, 255))   # pastilla rombo azul
    d.polygon([(12, 3), (21, 12), (12, 12)], fill=_c(130, 190, 255))
    d.polygon([(12, 21), (3, 12), (12, 12)], fill=_c(40, 90, 200))
    d.line([(7, 8), (11, 5)], fill=_c(255, 255, 255))
    d.rectangle([10, 10, 14, 14], fill=_c(255, 240, 110))       # estrellita de "oferta"
    d.line([(12, 9), (12, 15)], fill=_c(255, 240, 110))
    d.line([(9, 12), (15, 12)], fill=_c(255, 240, 110))
    return _outline(im)


def art_jockstrap():
    im, d = _new()
    d.rectangle([2, 4, 21, 8], fill=_c(240, 242, 250))              # cintura
    d.line([(2, 5), (21, 5)], fill=_c(70, 140, 255))
    d.line([(2, 7), (21, 7)], fill=_c(70, 140, 255))
    d.polygon([(6, 9), (17, 9), (15, 19), (12, 21), (9, 19)], fill=_c(210, 218, 234))   # bolsa
    d.polygon([(8, 11), (15, 11), (13, 18), (12, 19), (10, 18)], fill=_c(240, 242, 250))
    d.line([(10, 12), (10, 16)], fill=_c(255, 255, 255))
    d.line([(2, 9), (7, 16)], fill=_c(70, 140, 255))
    d.line([(21, 9), (16, 16)], fill=_c(70, 140, 255))
    return _outline(im)


def art_protein_shake():
    im, d = _new()
    d.rounded_rectangle([6, 7, 17, 21], radius=2, fill=_c(250, 240, 214))      # vaso
    d.rectangle([6, 7, 17, 9], fill=_c(220, 120, 80))
    d.rectangle([7, 2, 16, 7], fill=_c(60, 60, 78))                             # tapa
    d.rectangle([7, 2, 16, 3], fill=_c(100, 100, 124))
    d.rectangle([9, 4, 10, 7], fill=_c(60, 60, 78))
    d.rectangle([7, 11, 16, 17], fill=_c(70, 140, 255))                         # etiqueta
    d.line([(9, 15), (10, 13), (13, 13), (14, 15)], fill=_c(255, 255, 255))     # bicep naif
    d.line([(8, 19), (15, 19)], fill=_c(214, 196, 150))
    return _outline(im)


ART_FUNCS = {n[4:]: f for n, f in globals().items() if n.startswith("art_")}


def render(name: str) -> Image.Image:
    if name in ART_FUNCS:
        return ART_FUNCS[name]()
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
    for name in sys.argv[1:] or (list(SPRITES) + list(ART_FUNCS)):
        render(name).save(OUT / f"{name}.png")
        print("ok", name)
