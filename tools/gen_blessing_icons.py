"""Genera los 13 iconos de bendicion (assets/sprites/ui/blessings/<id>.png).

Uso: python3 tools/gen_blessing_icons.py   [hoja.png]  (con argumento, guarda ademas una hoja de contacto)
Cada icono: marco biselado del color de su reino (pene 6ec6ff, vulva ff7ac0,
mixto ffc93c) + glifo de 12x12 px de arte; 18x18 a 1x, guardado a 2x (NEAREST),
igual que el resto del HUD. Se dibuja con el bevel_box de gen_ui_art.py.
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_ui_art import O, bevel_box, new  # noqa: E402

OUT = Path(__file__).resolve().parent.parent / "assets/sprites/ui/blessings"
SCALE = 2
WHITE = (255, 255, 255, 255)

KINGDOMS = {
    "pene": (0x6E, 0xC6, 0xFF),
    "vulva": (0xFF, 0x7A, 0xC0),
    "mixto": (0xFF, 0xC9, 0x3C),
}


def shade(c, k):
    return tuple(min(255, int(v * k)) for v in c) + (255,)


# Glifos 12x12. X = color de reino, L = claro, D = oscuro, W = blanco, O = contorno,
# R = rojo, Y = amarillo, P = rosa, B = azul.
GLYPHS = {
    "calibre": [  # bala gorda
        "............",
        "....OOOO....",
        "...OLXXXO...",
        "..OLXXXXXO..",
        "..OLXXXXXO..",
        "..OLXXXXDO..",
        "..OXXXXXDO..",
        "..OOOOOOOO..",
        "..OYYYYYYO..",
        "..OYYYYYYO..",
        "..OOOOOOOO..",
        "............",
    ],
    "descarga": [  # tres balas en abanico
        "............",
        "..L...L...L.",
        "..X..LXL..X.",
        "..X..LXL..X.",
        "..X..XXX..X.",
        "..D..XXX..D.",
        "...D.XXX.D..",
        "....DXXXD...",
        ".....YYY....",
        ".....YYY....",
        "............",
        "............",
    ],
    "embestida": [  # bala empujando: lineas de impulso
        "............",
        "............",
        "..L.....OO..",
        "..XL...OLXO.",
        "LLXXXXXLXXXO",
        "XXXXXXXXXXXO",
        "XXXXXXXXXXXO",
        "LLXXXXXLXXXO",
        "..XD...ODXO.",
        "..D.....OO..",
        "............",
        "............",
    ],
    "penetracion": [  # flecha que atraviesa un bloque
        "............",
        "....ODO.....",
        "....OLO.....",
        "....OLO..L..",
        "....OLO..XL.",
        "LXXXXXXXXXXX",
        "LXXXXXXXXXXD",
        "....OLO..XD.",
        "....OLO..D..",
        "....OLO.....",
        "....ODO.....",
        "............",
    ],
    "orgullo": [  # corazon herido rodeado de 8 balas
        "L....L....L.",
        "............",
        "...OO.OO....",
        "..ORROORRO..",
        "..ORRRRRRO..",
        "L.ORRRRRRO.L",
        "...ORRRRO...",
        "....ORRO....",
        ".....OO.....",
        "............",
        "L....L....L.",
        "............",
    ],
    "testosterona": [  # cruz de vida con escudo
        "............",
        "....OOOO....",
        "....OXXO....",
        "..OOOXXOOO..",
        "..OXXXXXXO..",
        "..OLLXXLLO..",
        "..OOOXXOOO..",
        "....OXXO....",
        "....ODDO....",
        "....OOOO....",
        "............",
        "............",
    ],
    "ciclo": [  # flechas circulares
        "............",
        "...XXXXX....",
        "..XL...XXX..",
        ".XL.....XXL.",
        ".X........X.",
        ".X.....XXXXX",
        ".X......XXX.",
        ".XD......X..",
        "..XD.....X..",
        "...XDDXXX...",
        "............",
        "............",
    ],
    "escurridiza": [  # gota veloz
        "............",
        ".....L......",
        "....LXL.....",
        "...LXXXL....",
        "..LXXXXXL...",
        ".LXXWXXXXL..",
        ".XXWXXXXXD..",
        ".XXXXXXXXD..",
        "..XXXXXDD...",
        "...DDDDD....",
        "XX..........",
        "..XX........",
    ],
    "filo": [  # tajo en diagonal
        "..........WW",
        ".........WLO",
        "........WLXO",
        ".......WLXO.",
        "......WLXO..",
        ".....WLXO...",
        "....WLXO....",
        "..YYLXO.....",
        ".YYYXO......",
        "YYYYO.......",
        "YYY.........",
        "............",
    ],
    "intuicion": [  # ojo
        "............",
        "............",
        "....OOOO....",
        "..OOXXXXOO..",
        ".OXXXWWXXXO.",
        "OXXXWBBWXXXO",
        "OXXXWBBWXXXO",
        ".OXXXWWXXXO.",
        "..OOXXXXOO..",
        "....OOOO....",
        "............",
        "............",
    ],
    "regla": [  # gota de sangre con cruz
        ".....R......",
        "....RRR.....",
        "...RRRRR....",
        "..RRRRRRR...",
        ".RRWRRRRRR..",
        ".RRWRRRRRR..",
        ".RRRRRRRRD..",
        ".RRRRRRRDD..",
        "..RRRRRDD...",
        "...DDDDD....",
        "............",
        "............",
    ],
    "caderas": [  # chevrons de velocidad
        "............",
        "............",
        "XX..XX..XX..",
        ".XX..XX..XX.",
        "..XX..XX..XX",
        "...XX..XX..X",
        "...XX..XX..X",
        "..XX..XX..XX",
        ".XX..XX..XX.",
        "XX..XX..XX..",
        "............",
        "............",
    ],
    "equilibrio": [  # circulo mitad azul / mitad rosa
        "............",
        "....OOOO....",
        "..OOBBPPOO..",
        ".OBBBBPPPPO.",
        ".OBBLBPPPPO.",
        "OBBBBBPPPPPO",
        "OBBBBBPPPPPO",
        ".OBBBBPPLPO.",
        ".OBBBBPPPPO.",
        "..OODDDDOO..",
        "....OOOO....",
        "............",
    ],
}

ORDER = ["calibre", "descarga", "embestida", "penetracion", "orgullo", "testosterona",
         "ciclo", "escurridiza", "filo", "intuicion", "regla", "caderas", "equilibrio"]
KINGDOM_OF = {i: "pene" for i in ORDER[:6]}
KINGDOM_OF.update({i: "vulva" for i in ORDER[6:12]})
KINGDOM_OF["equilibrio"] = "mixto"


def icon(bid):
    base = KINGDOMS[KINGDOM_OF[bid]]
    pal = {
        "X": base + (255,),
        "L": shade(base, 1.3),
        "D": shade(base, 0.6),
        "W": WHITE,
        "O": O,
        "R": (228, 59, 68, 255),
        "Y": (255, 214, 90, 255),
        "P": (255, 122, 192, 255),
        "B": (110, 198, 255, 255),
    }
    if bid == "equilibrio":
        pal["L"] = (255, 255, 255, 255)
        pal["D"] = (150, 100, 40, 255)
    if bid == "intuicion":
        pal["B"] = (40, 30, 70, 255)
    if bid == "regla":
        pal["R"] = (232, 70, 130, 255)
        pal["D"] = (150, 36, 80, 255)
    rows = GLYPHS[bid]
    assert len(rows) == 12 and all(len(r) == 12 for r in rows), bid
    im = new(18, 18)
    bevel_box(im, 0, 0, 17, 17, shade(base, 0.22), hi=shade(base, 1.0), lo=shade(base, 0.55), spark=shade(base, 1.4))
    px = im.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                px[3 + x, 3 + y] = pal[ch]
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGBA", (7 * 40 + 4, 2 * 40 + 4), (26, 15, 38, 255))
    for i, bid in enumerate(ORDER):
        im = icon(bid)
        big = im.resize((18 * SCALE, 18 * SCALE), Image.NEAREST)
        big.save(OUT / f"{bid}.png")
        sheet.paste(big, (4 + (i % 7) * 40, 4 + (i // 7) * 40), big)
    sheet = sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST)
    if len(sys.argv) > 1:
        sheet.save(sys.argv[1])
    print("ok ->", OUT)


if __name__ == "__main__":
    main()
