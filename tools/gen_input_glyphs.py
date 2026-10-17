#!/usr/bin/env python3
"""Genera los glifos de entrada pixel art (teclado/raton/mando Xbox) en
assets/sprites/ui/glyphs/. Se dibujan a 1 px de arte; en pantalla van a 2x (NEAREST).
Los usa src/ui/input_glyphs.gd. Uso: python3 tools/gen_input_glyphs.py"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets/sprites/ui/glyphs"
DARK = (13, 11, 15, 255)
CREAM = (255, 241, 214, 255)
GOLD = (240, 192, 74, 255)
GREY = (74, 68, 86, 255)
GREY_HI = (112, 104, 130, 255)
GREY_LO = (46, 41, 58, 255)
CLEAR = (0, 0, 0, 0)

# fuente 3x5 minima (solo lo que hace falta)
F = {
    "A": ["010", "101", "111", "101", "101"],
    "B": ["110", "101", "110", "101", "110"],
    "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"],
    "L": ["100", "100", "100", "100", "111"],
    "R": ["110", "101", "110", "101", "101"],
    "T": ["111", "010", "010", "010", "010"],
}


def img(w, h):
    return Image.new("RGBA", (w, h), CLEAR)


def text(im, s, x, y, col):
    for ch in s:
        for r, row in enumerate(F[ch]):
            for c, v in enumerate(row):
                if v == "1":
                    im.putpixel((x + c, y + r), col)
        x += 4


def rect(im, x0, y0, x1, y1, col):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            im.putpixel((x, y), col)


def disc(im, size, fill, hi, lo):
    """Circulo con borde oscuro, brillo arriba-izquierda y sombra abajo-derecha."""
    c = (size - 1) / 2
    r = size / 2
    for y in range(size):
        for x in range(size):
            d = ((x - c) ** 2 + (y - c) ** 2) ** 0.5
            if d <= r - 0.3:
                col = fill
                if d > r - 1.6:
                    col = lo if (x + y) > size - 1 else hi
                im.putpixel((x, y), DARK if d > r - 1.0 else col)


def pad_button(name, letter, fill, hi, lo):
    im = img(14, 14)
    disc(im, 14, fill, hi, lo)
    text(im, letter, 5, 4, CREAM if letter != "Y" else DARK)
    im.save(OUT / f"pad_{name}.png")


def pill(im, x0, y0, x1, y1, col, hi):
    rect(im, x0, y0, x1, y1, DARK)
    rect(im, x0 + 1, y0 + 1, x1 - 1, y1 - 1, col)
    rect(im, x0 + 1, y0 + 1, x1 - 1, y0 + 1, hi)
    for (x, y) in [(x0, y0), (x1, y0), (x0, y1), (x1, y1)]:
        im.putpixel((x, y), CLEAR)


def shoulder(name, letters, trigger):
    h = 14 if trigger else 11
    im = img(20, h)
    pill(im, 0, 0, 19, h - 1, GREY, GREY_HI)
    text(im, letters, 6, (h - 5) // 2 + (1 if trigger else 0), CREAM)
    if trigger:  # el gatillo es mas gordo y oscuro abajo
        rect(im, 1, h - 3, 18, h - 2, GREY_LO)
        text(im, letters, 6, (h - 5) // 2 + 1, CREAM)
    im.save(OUT / f"pad_{name}.png")


def dpad(arm):
    im = img(14, 14)
    rect(im, 4, 0, 9, 13, DARK)
    rect(im, 0, 4, 13, 9, DARK)
    rect(im, 5, 1, 8, 12, GREY)
    rect(im, 1, 5, 12, 8, GREY)
    arms = {"up": (5, 1, 8, 4), "down": (5, 9, 8, 12), "left": (1, 5, 4, 8), "right": (9, 5, 12, 8)}
    rect(im, *arms[arm], GOLD)
    im.save(OUT / f"pad_dpad_{arm}.png")


def small_pill(name):
    im = img(16, 12)
    pill(im, 0, 0, 15, 11, GREY, GREY_HI)
    if name == "start":
        for y in (3, 5, 7):
            rect(im, 4, y, 11, y, CREAM)
    else:  # back: dos hojas
        rect(im, 4, 3, 9, 7, CREAM)
        rect(im, 5, 4, 8, 6, GREY)
        rect(im, 7, 5, 11, 8, CREAM)
        rect(im, 8, 6, 10, 7, GREY)
    im.save(OUT / f"pad_{name}.png")


def mouse(which):
    im = img(12, 16)
    rect(im, 1, 0, 10, 15, DARK)
    rect(im, 0, 3, 11, 12, DARK)
    rect(im, 2, 1, 9, 14, GREY)
    rect(im, 1, 4, 10, 11, GREY)
    rect(im, 2, 7, 9, 7, DARK)  # corte botones / cuerpo
    rect(im, 5, 1, 6, 6, DARK)  # separacion izquierdo / derecho
    rect(im, 2, 1, 4, 6, GREY_HI)
    rect(im, 7, 1, 9, 6, GREY_HI)
    if which == "left":
        rect(im, 2, 1, 4, 6, GOLD)
    else:
        rect(im, 7, 1, 9, 6, GOLD)
    im.save(OUT / f"mouse_{which}.png")


def keycap():
    """9-slice 14x14, margen 4: tecla con cara clara y canto inferior oscuro."""
    im = img(14, 14)
    rect(im, 1, 0, 12, 13, DARK)
    rect(im, 0, 1, 13, 12, DARK)
    rect(im, 1, 1, 12, 11, (226, 214, 190, 255))
    rect(im, 1, 1, 12, 1, CREAM)
    rect(im, 1, 11, 12, 12, (150, 128, 96, 255))
    rect(im, 2, 2, 11, 10, (240, 230, 208, 255))
    im.save(OUT / "key_cap.png")


# iconos de accion 14x14 (mano izquierda/derecha y dash del HUD). Faciles de reemplazar:
# basta con sustituir el PNG act_<nombre>.png por otro de cualquier tamano.
PAL = {"k": DARK, "c": CREAM, "g": GOLD, "b": (58, 158, 232, 255), "d": (30, 90, 160, 255),
       "r": (228, 59, 68, 255), "p": (240, 150, 190, 255), "w": (255, 255, 255, 255),
       "e": (200, 224, 74, 255), "o": (120, 150, 40, 255), "s": (200, 200, 215, 255)}
ACT = {
    "shield": [
        "..............", "..kkkkkkkkkk..", ".kbbbbbbbbbbk.", ".kbwwbbbbbbdk.",
        ".kbwbbggbbbdk.", ".kbbbbggbbbdk.", ".kbbggggggbdk.", ".kbbggggggbdk.",
        ".kbbbbggbbbdk.", "..kbbbggbbdk..", "..kbbbbbbbdk..", "...kdbbbbdk...",
        "....kkddkk....", "......kk......",
    ],
    "wings": [
        "..............", "kk..........kk", "kck........kck", "kccck.kk.kccck",
        "kcccck.kk.kcck", ".kccck....kcck", ".kcccck..kccck", "..kcccck.kcck.",
        "..kkcccckkcck.", "...kkcccckck..", "....kkcccck...", ".....kkkkk....",
        "..............", "..............",
    ],
    "scream": [
        "..............", "......kk......", "....kkrrkk....", "..kkrrrrrrkk..",
        ".krrrrwwrrrrk.", ".krrrwwwwrrrk.", "krrrwkkkkwrrrk", ".krrrwwwwrrrk.",
        ".krrrrwwrrrrk.", "..kkrrrrrrkk..", "....kkrrkk....", "......kk......",
        "..............", "..............",
    ],
    "spur": [
        "..............", "...........kk.", "..........kssk", ".........kssk.",
        "........kssk..", ".......kssk...", "......kssk....", "..kk.kssk.....",
        ".kggkssk......", ".kgggsk.......", "..kgggk.......", "...kkk........",
        "..............", "..............",
    ],
    "egg": [
        "..............", "......kk......", ".....kccck....", "....kcccwck...",
        "...kccccwcck..", "...kccgcccck..", "..kcccgggcccck", "..kccccgcccck.",
        "..kcgccccgcck.", "..kgggcccggck.", "...kcgcccgck..", "...kcccccck...",
        "....kkkkkk....", "..............",
    ],
    "fist": [
        "..............", "..kkkkkkkk....", ".kppkppkppkk..", ".kppkppkppkpk.",
        ".kppppppppkpk.", ".kppppppppkpk.", ".kppppppppkk..", ".kpkkpppppk...",
        ".kpppkpppk....", "..kppppppk....", "..kppppppk....", "..kkkkkkkk....",
        "..............", "..............",
    ],
}


def act_icons():
    for name, rows in ACT.items():
        im = img(14, 14)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != ".":
                    im.putpixel((x, y), PAL[ch])
        im.save(OUT / f"act_{name}.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pad_button("a", "A", (60, 170, 70, 255), (120, 220, 120, 255), (30, 110, 40, 255))
    pad_button("b", "B", (220, 60, 60, 255), (255, 130, 120, 255), (140, 30, 40, 255))
    pad_button("x", "X", (60, 120, 230, 255), (130, 175, 255, 255), (30, 70, 160, 255))
    pad_button("y", "Y", (240, 200, 50, 255), (255, 235, 130, 255), (170, 130, 20, 255))
    shoulder("lb", "LB", False)
    shoulder("rb", "RB", False)
    shoulder("lt", "LT", True)
    shoulder("rt", "RT", True)
    for a in ("up", "down", "left", "right"):
        dpad(a)
    small_pill("start")
    small_pill("back")
    mouse("left")
    mouse("right")
    keycap()
    act_icons()
    print("glifos en", OUT)


if __name__ == "__main__":
    main()
