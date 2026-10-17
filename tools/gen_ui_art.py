"""Genera el arte pixel del HUD (assets/sprites/ui/hud/).

Uso: python3 tools/gen_ui_art.py
Todo se dibuja a 1x y se guarda a 2x (NEAREST): 1 pixel de arte = 2x2 en
pantalla, igual para todas las piezas, asi el HUD tiene un solo "tamano de pixel".
Paleta: morado noche + oro (el dorado b08d4a que ya usaba el juego).
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets/sprites/ui/hud"
SCALE = 2

O = (13, 11, 15, 255)
BG0 = (26, 15, 38, 255)
BG1 = (40, 24, 58, 255)
BG2 = (18, 10, 27, 255)
G0 = (255, 241, 168, 255)
G1 = (240, 192, 74, 255)
G2 = (176, 141, 74, 255)
G3 = (110, 79, 36, 255)
TRK = (34, 20, 50, 255)
TRK2 = (21, 12, 32, 255)
CLEAR = (0, 0, 0, 0)


def new(w, h, fill=CLEAR):
    return Image.new("RGBA", (w, h), fill)


def save(im, name):
    OUT.mkdir(parents=True, exist_ok=True)
    im.resize((im.width * SCALE, im.height * SCALE), Image.NEAREST).save(OUT / f"{name}.png")


def bevel_box(im, x0, y0, x1, y1, center, cut=True, hi=G1, lo=G3, spark=G0):
    """Marco: contorno + bisel dorado (luz arriba-izq, sombra abajo-der) + linea interior."""
    px = im.load()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            edge = min(x - x0, y - y0, x1 - x, y1 - y)
            if edge == 0:
                c = O
            elif edge == 1:
                c = hi if (x - x0 == 1 or y - y0 == 1) and not (x1 - x == 1 or y1 - y == 1) else lo
                if (x - x0, y - y0) in ((1, 1), (2, 1), (1, 2)):
                    c = spark
            elif edge == 2:
                c = O
            else:
                c = center
            px[x, y] = c
    if cut:  # esquinas redondeadas de 1 px
        for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
            px[x, y] = CLEAR
        for x, y in ((x0 + 1, y0 + 1), (x1 - 1, y0 + 1), (x0 + 1, y1 - 1), (x1 - 1, y1 - 1)):
            px[x, y] = O


# ------------------------------------------------------------------ franja
def band():
    """Tile de 32x36 (72 en pantalla): tela morada con puntada + ribete dorado con remache."""
    im = new(32, 36, BG0)
    px = im.load()
    for x in range(32):
        px[x, 0] = BG1
        px[x, 1] = BG2
        for y in range(2, 30):
            if (x + y) % 8 == 0 and y % 2 == 0:
                px[x, y] = BG1  # puntada diagonal
        px[x, 30] = BG2
        px[x, 31] = O
        px[x, 32] = G1
        px[x, 33] = G2
        px[x, 34] = G3
        px[x, 35] = O
    for x, y, c in ((15, 32, G2), (16, 32, G0), (17, 32, G2), (15, 33, G3), (16, 33, G1), (17, 33, G3), (16, 34, O)):
        px[x, y] = c
    save(im, "band")


def panel():
    """9-slice generico (caja del narrador, minimapa). Margen 4 px de arte."""
    im = new(16, 16)
    bevel_box(im, 0, 0, 15, 15, (20, 11, 30, 232))
    save(im, "panel")


def bar_frame():
    """9-slice de la barra: 12x14, margen 3 px de arte; el centro (8 px) es el riel vacio."""
    im = new(12, 14)
    bevel_box(im, 0, 0, 11, 13, TRK)
    px = im.load()
    for x in range(3, 9):
        px[x, 3] = TRK2  # sombra interior arriba
    save(im, "bar_frame")


def bar_fill():
    """Relleno en grises (se tine con modulate) + brillo encima sin tenir."""
    rows = [1.0, 0.96, 0.96, 0.96, 0.96, 0.86, 0.68, 0.5]
    im = new(12, 8)
    px = im.load()
    for y in range(8):
        v = rows[y]
        for x in range(12):
            k = v * (0.72 if x == 11 else 1.0)  # muesca cada 12 px: barra segmentada
            px[x, y] = (int(255 * k), int(255 * k), int(255 * k), 255)
    save(im, "bar_fill")
    g = new(12, 8)
    gp = g.load()
    for x in range(12):
        gp[x, 0] = (255, 255, 255, 120)
        if x % 12 < 4:
            gp[x, 1] = (255, 255, 255, 50)
    save(g, "bar_gloss")


ICONS = {
    "heart": ({"R": (228, 59, 68), "D": (150, 36, 52), "W": (255, 190, 190)}, [
        "...........",
        "..ooo.ooo..",
        ".oWRRoRRRo.",
        "oWRRRRRRRRo",
        "oRRRRRRRRDo",
        "oRRRRRRRRDo",
        ".oRRRRRRDo.",
        "..oRRRRDo..",
        "...oRRDo...",
        "....oDo....",
        ".....o.....",
    ]),
    "shield": ({"B": (58, 158, 232), "D": (36, 84, 164), "W": (200, 238, 255), "L": (140, 205, 250)}, [
        ".ooooooooo.",
        "oWWBBLBBBDo",
        "oWBBBLBBBDo",
        "oWBBBLBBBDo",
        "oBLLLLLLLDo",
        "oBBBBLBBBDo",
        ".oBBBLBBDo.",
        ".oBBBLBBDo.",
        "..oBBLBDo..",
        "...oBBDo...",
        "....ooo....",
    ]),
    "bolt": ({"Y": (242, 197, 61), "W": (255, 245, 154), "D": (194, 124, 30)}, [
        ".....ooooo.",
        "....oWYYo..",
        "...oWYYo...",
        "..oWYYooooo",
        ".oYYYYYYYYo",
        ".ooooYYYDo.",
        "....oYYDo..",
        "...oYYDo...",
        "..oYDDo....",
        ".oDDo......",
        ".ooo.......",
    ]),
    "bottle": ({"C": (150, 96, 52), "G": (200, 226, 236), "W": (255, 255, 255), "P": (196, 70, 212), "D": (120, 34, 136)}, [
        "....ooo....",
        "....oCo....",
        "....ooo....",
        "....oGo....",
        "...oWGGo...",
        "..oWGGGGo..",
        ".oWPPPPPDo.",
        ".oPPWPPPDo.",
        ".oPPPPPPDo.",
        ".oDPPPPDDo.",
        "..ooooooo..",
    ]),
    "coin": ({"Y": (240, 192, 74), "W": (255, 241, 168), "D": (168, 112, 36)}, [
        "...ooooo...",
        ".ooWYYYYoo.",
        ".oWYYYYYDo.",
        "oWYYDDDYYDo",
        "oYYDYYYDYDo",
        "oYYDYYYYYDo",
        "oYYDYYYDYDo",
        "oYYYDDDYYDo",
        ".oYYYYYYDo.",
        ".ooDDDDDoo.",
        "...ooooo...",
    ]),
    "skull": ({"W": (236, 232, 222), "L": (160, 150, 142)}, [
        "...........",
        "..ooooooo..",
        ".oWWWWWWWo.",
        "oWWWWWWWWLo",
        "oWoooWoooLo",
        "oWoooWoooLo",
        "oWWWWoWWWLo",
        ".oWWWWWWLo.",
        "..oWoWoWo..",
        "..ooooooo..",
        "...........",
    ]),
}


def icons():
    for name, (pal, rows) in ICONS.items():
        assert len(rows) == 11 and all(len(r) == 11 for r in rows), name
        im = new(11, 11)
        px = im.load()
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "o":
                    px[x, y] = O
                elif ch != ".":
                    px[x, y] = pal[ch] + (255,)
        save(im, "icon_" + name)


def slot():
    """Casilla de objeto 30x30 (60 en pantalla): hueco hundido de 24 (48) con trama."""
    im = new(30, 30)
    bevel_box(im, 0, 0, 29, 29, BG2)
    px = im.load()
    for y in range(3, 27):
        for x in range(3, 27):
            if (x // 2 + y // 2) % 2 == 0:
                px[x, y] = (22, 13, 33, 255)
    for i in range(3, 27):
        px[i, 3] = TRK2
        px[3, i] = TRK2
    save(im, "slot")


def key_badge():
    """Tecla de la casilla: 11x11 (22 en pantalla), oscura con bisel dorado."""
    im = new(11, 11)
    bevel_box(im, 0, 0, 10, 10, BG1)
    save(im, "key_badge")


def portrait_frame():
    """Marco 30x30 (60 en pantalla) con hueco para el retrato."""
    im = new(30, 30)
    bevel_box(im, 0, 0, 29, 29, CLEAR)
    px = im.load()
    # remaches en las esquinas del bisel
    for x, y in ((1, 1), (28, 1), (1, 28), (28, 28)):
        px[x, y] = G0
    save(im, "portrait_frame")


def buttons():
    """Boton 9-slice 16x14 (margen 3 px de arte) en sus 4 estados."""
    states = {
        "btn_normal": dict(center=BG1, hi=G1, lo=G3, spark=G0),
        "btn_hover": dict(center=(64, 36, 88, 255), hi=G0, lo=G2, spark=(255, 255, 255, 255)),
        "btn_pressed": dict(center=BG2, hi=G3, lo=G1, spark=G3),
        "btn_disabled": dict(center=(30, 26, 36, 255), hi=(96, 90, 104, 255), lo=(60, 56, 68, 255), spark=(110, 104, 118, 255)),
    }
    for name, kw in states.items():
        im = new(16, 14)
        bevel_box(im, 0, 0, 15, 13, **kw)
        px = im.load()
        if name == "btn_hover":  # brillo arriba
            for x in range(3, 13):
                px[x, 3] = (84, 52, 112, 255)
        save(im, name)


EXTRA_ICONS = {
    "bone": ({"W": (240, 234, 220), "L": (170, 160, 148)}, [
        "...........",
        ".oo.....oo.",
        "oWWo...oWWo",
        "oWWWoooWWLo",
        ".oWWWWWWLo.",
        "..oWWWWLo..",
        ".oWWLLLWWo.",
        "oWWLoooLWLo",
        "oWLo...oLLo",
        ".oo.....oo.",
        "...........",
    ]),
    "clock": ({"W": (255, 241, 214), "R": (228, 59, 68), "G": (176, 141, 74)}, [
        "...ooooo...",
        "..oGGGGGo..",
        ".oGWWoWWGo.",
        "oGWWWoWWWGo",
        "oGWWWoWWWGo",
        "oGWWWooRWGo",
        "oGWWWWWWWGo",
        "oGWWWWWWWGo",
        ".oGWWWWWGo.",
        "..oGGGGGo..",
        "...ooooo...",
    ]),
    "stairs": ({"S": (150, 132, 112), "L": (200, 184, 160), "D": (90, 76, 66)}, [
        "...........",
        "........ooo",
        "........oLo",
        "......oooSo",
        "......oLLSo",
        "....oooSSSo",
        "....oLLSSSo",
        "..oooSSSSDo",
        "..oLLSSSSDo",
        "ooSSSSSSDDo",
        "ooooooooooo",
    ]),
}


def _outline(im, o=O):
    """Contorno de 1 px de arte alrededor de todo lo opaco (8 vecinos)."""
    src = im.copy()
    px, sp = im.load(), src.load()
    for y in range(im.height):
        for x in range(im.width):
            if sp[x, y][3]:
                continue
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < im.width and 0 <= ny < im.height and sp[nx, ny][3] and sp[nx, ny] != o:
                        px[x, y] = o


def _save_cursor(im, name):
    """Cursores a 2x (por defecto) y 3x (_3x) para ventanas grandes: el stretch no los escala."""
    OUT.mkdir(parents=True, exist_ok=True)
    for sc, suf in ((2, ""), (3, "_3x")):
        im.resize((im.width * sc, im.height * sc), Image.NEAREST).save(OUT / f"{name}{suf}.png")


def cursors():
    # Mira: 15x15 de arte, centro exacto en (7,7). 4 tramos con hueco + punto central.
    CREAM = (255, 241, 214, 255)
    im = new(15, 15)
    px = im.load()
    for d in (4, 5, 6):
        px[7 - d, 7] = px[7 + d, 7] = px[7, 7 - d] = px[7, 7 + d] = CREAM
    px[7, 7] = CREAM
    _outline(im)
    _save_cursor(im, "cursor_aim")
    # Puntero dorado del HUD: punta en (1,1) (el contorno ocupa la fila/columna 0).
    rows = [
        "L",
        "LB",
        "LBB",
        "LBBB",
        "LBBBB",
        "LBBBBB",
        "LBBBBBB",
        "LBBBBBBB",
        "LBBBBBBBS",
        "LBBBBBSSS",
        "LBBLBBS",
        "LBL.LBBS",
        "LL...LBBS",
        ".....LBBS",
        "......LBS",
        "......SS",
    ]
    cols = {"L": G0, "B": G1, "S": G3}
    im = new(13, 19)
    px = im.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c in cols:
                px[1 + x, 1 + y] = cols[c]
    _outline(im)
    _save_cursor(im, "cursor_pointer")
    # Toallita higienica con alas para los menus (idea de Nico): punta arriba al centro.
    rows = [
        "....WWWWW....",
        "...WWWWWWL...",
        "...WWPPPWL...",
        "...WPPPPPL...",
        "...WPPBPPL...",
        ".WWWPBBBPLWL.",
        "WWWWPBBBPLWWL",
        "WWWWPPPPPLWWL",
        ".LLWPPPPPLLL.",
        "...WPPPPPL...",
        "...WPPPPPL...",
        "...WWPPPWL...",
        "...WWWWWWL...",
        "....LLLLL....",
    ]
    cols = {"W": (255, 250, 242, 255), "P": (255, 196, 222, 255), "B": (110, 182, 255, 255), "L": (196, 184, 200, 255)}
    im = new(15, 16)
    px = im.load()
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c in cols:
                px[1 + x, 1 + y] = cols[c]
    _outline(im)
    _save_cursor(im, "cursor_pad")


if __name__ == "__main__":
    ICONS.update(EXTRA_ICONS)
    buttons()
    band()
    panel()
    bar_frame()
    bar_fill()
    icons()
    slot()
    key_badge()
    portrait_frame()
    cursors()
    print("ok ->", OUT)
