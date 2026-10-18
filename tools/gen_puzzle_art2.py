"""Arte de los acertijos nuevos (assets/sprites/environment/puzzles/): sombras, minigolf,
huellas, diario y esfinge. Reusa los ayudantes de gen_puzzle_art.py.

Uso: python3 tools/gen_puzzle_art2.py

  glyph_sun / glyph_moon          glifos de las placas de sombra (luz / tapada)
  golf_ball, golf_hole, golf_flag, golf_block, golf_pit   minigolf (la bola es un testiculo)
  track_print, track_sack, track_hole, mud_patch           huellas en el barro
  diary_closed / diary_open, dial_post, diary_page          diario intimo
  sphinx                                                    esfinge de Penelandia
Todo es determinista.
"""
import math
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_puzzle_art import (C, CLEAR, OL, OUT, WHITE, disc, dk, line, mix, new, outline,  # noqa: E402
                            padded, px, rect, save)


def ellipse(im, cx, cy, rx, ry, col):
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                px(im, x, y, col)


# ------------------------------------------------------------------ sombras
def glyph_sun():
    im = new(18, 18)
    for k in range(8):
        a = math.radians(k * 45)
        line(im, 9, 9, round(9 + math.cos(a) * 8), round(9 + math.sin(a) * 8), C("ffd75a"))
    disc(im, 9, 9, 4.5, C("ffe27a"))
    disc(im, 8, 8, 2, C("fff6c8"))
    return outline(padded(im, 0))


def glyph_moon():
    im = new(18, 18)
    disc(im, 9, 9, 7, C("9aa0d8"))
    for y in range(18):
        for x in range(18):
            if (x - 12) ** 2 + (y - 7) ** 2 <= 36:
                im.putpixel((x, y), CLEAR)
    disc(im, 6, 12, 1.2, C("6a70a8"))
    return outline(padded(im, 0))


# ------------------------------------------------------------------ minigolf
def golf_ball():
    """El testiculo: ovalo rosado con arrugas y unos pelitos."""
    im = new(14, 16)
    skin = C("e8a090")
    ellipse(im, 7, 8, 5.5, 6.5, dk(skin, 0.8))
    ellipse(im, 6.5, 7.5, 4.8, 5.8, skin)
    ellipse(im, 5.5, 5.5, 2.2, 2.6, mix(skin, WHITE, 0.35))
    for (x, y) in ((8, 8), (9, 10), (6, 11), (4, 9), (8, 5)):
        px(im, x, y, dk(skin, 0.7))
    line(im, 7, 2, 7, 13, dk(skin, 0.85))   # costura central
    px(im, 6, 1, C("5a3a2a"))
    px(im, 8, 1, C("5a3a2a"))
    px(im, 10, 13, C("5a3a2a"))
    return outline(padded(im))


def golf_hole():
    im = new(30, 18)
    ellipse(im, 15, 9, 13, 7, C("3a2a22"))
    ellipse(im, 15, 10, 11, 5.5, C("120d10"))
    for x in range(5, 25):
        px(im, x, 3, C("7a5a40"))
    return outline(padded(im))


def golf_flag():
    im = new(14, 34)
    rect(im, 2, 2, 3, 31, C("c9c4d0"))
    rect(im, 2, 2, 2, 31, WHITE)
    for y in range(3, 11):
        w = 10 - abs(y - 6) * 1.2
        rect(im, 4, y, 4 + round(w) - 1, y, C("e0525a"))
    rect(im, 0, 31, 6, 32, C("6a6470"))
    return outline(padded(im))


def golf_block():
    im = new(30, 30)
    st, stl, std = C("a9a5b0"), C("cfcbd6"), C("77737f")
    rng = random.Random(3)
    rect(im, 2, 6, 27, 27, st)
    rect(im, 2, 2, 27, 7, stl)
    rect(im, 2, 24, 27, 27, std)
    rect(im, 25, 6, 27, 27, std)
    for _ in range(18):
        px(im, rng.randint(3, 24), rng.randint(9, 22), rng.choice((std, stl)))
    for x in range(4, 26, 7):
        line(im, x, 3, x + 1, 6, std)
    return outline(padded(im))


def golf_pit():
    """Charco pegajoso: la bola que cae aqui se va al inicio."""
    im = new(44, 32)
    ellipse(im, 22, 16, 20, 13, C("5a4a3a"))
    ellipse(im, 22, 17, 18, 11, C("d6d0b8"))
    ellipse(im, 22, 17, 15, 9, C("efe9d0"))
    for (x, y) in ((14, 14), (27, 19), (20, 20), (30, 13), (12, 20)):
        disc(im, x, y, 1.6, WHITE)
    for (x, y) in ((24, 13), (17, 17)):
        px(im, x, y, C("c9c3a8"))
    return outline(padded(im))


# ------------------------------------------------------------------ huellas
def track_print():
    """Huella de algo con tres dedos de garra, mirando ARRIBA (se gira en el juego)."""
    im = new(11, 14)
    mud = C("2e2016")
    ellipse(im, 5, 9, 3.6, 3.8, mud)
    for (x, y) in ((1, 3), (5, 1), (9, 3)):
        ellipse(im, x, y + 1, 1.5, 2.2, mud)
    return im


def mud_patch():
    im = new(80, 52)
    rng = random.Random(11)
    base = C("6b4e33")
    ellipse(im, 40, 26, 38, 23, dk(base, 0.7))
    ellipse(im, 40, 26, 35, 20, base)
    for _ in range(60):
        x, y = rng.randint(8, 72), rng.randint(8, 44)
        if ((x - 40) / 34) ** 2 + ((y - 26) / 19) ** 2 < 1:
            px(im, x, y, rng.choice((dk(base, 0.8), mix(base, WHITE, 0.15))))
    return im


def track_sack():
    im = new(24, 26)
    ellipse(im, 12, 16, 9, 8, C("c9a24a"))
    ellipse(im, 10, 14, 5, 5, C("e8c76a"))
    rect(im, 8, 6, 15, 9, C("c9a24a"))
    rect(im, 8, 8, 15, 8, C("7a5a2a"))
    rect(im, 11, 11, 12, 18, C("7a5a2a"))
    px(im, 11, 14, C("fff0a0"))
    return outline(padded(im))


def track_hole():
    im = new(26, 18)
    ellipse(im, 13, 10, 11, 6, C("3a2a1c"))
    ellipse(im, 13, 11, 8, 4, C("0e0a08"))
    for (x1, y1, x2, y2) in ((2, 3, 13, 10), (24, 3, 13, 10), (4, 15, 13, 10), (22, 15, 13, 10)):
        line(im, x1, y1, x2, y2, C("cfcbd6"))
    return outline(padded(im))


# ------------------------------------------------------------------ diario
def diary_book(open_):
    im = new(40, 34)
    cover, cdark = C("c04a8a"), C("8a2a62")
    if not open_:
        rect(im, 4, 6, 35, 29, cover)
        rect(im, 4, 26, 35, 29, cdark)
        rect(im, 4, 6, 6, 29, mix(cover, WHITE, 0.25))
        rect(im, 33, 6, 35, 29, cdark)
        rect(im, 7, 7, 8, 28, cdark)   # lomo
        # corazon dorado + candado
        gold = C("e8c76a")
        disc(im, 17, 15, 3.4, gold)
        disc(im, 23, 15, 3.4, gold)
        for y in range(16, 24):
            w = max(0, 6 - (y - 16) * 0.8)
            rect(im, round(20 - w), y, round(20 + w) - 1, y, gold)
        rect(im, 19, 13, 20, 17, dk(gold, 0.6))
        rect(im, 29, 14, 33, 19, C("8a8a96"))
        rect(im, 30, 11, 32, 14, C("c9c4d0"))
        px(im, 31, 12, OL)
    else:
        page = C("efe6cf")
        rect(im, 2, 8, 19, 28, page)
        rect(im, 20, 8, 37, 28, dk(page, 0.92))
        rect(im, 2, 27, 37, 29, cdark)
        for y in range(11, 26, 3):
            rect(im, 5, y, 16, y, C("a39a82"))
            rect(im, 23, y, 34, y, C("a39a82"))
        disc(im, 28, 18, 3, C("e0525a"))
        disc(im, 32, 18, 3, C("e0525a"))
        rect(im, 25, 19, 34, 21, C("e0525a"))
        rect(im, 19, 8, 20, 28, dk(page, 0.7))
    return outline(padded(im))


def dial_post():
    im = new(22, 34)
    rect(im, 3, 26, 18, 30, C("6e6a78"))
    rect(im, 3, 26, 18, 27, C("a6a2b2"))
    rect(im, 5, 8, 16, 26, C("c9a24a"))
    rect(im, 5, 8, 7, 26, C("f1d98a"))
    rect(im, 14, 8, 16, 26, C("8a6a2a"))
    rect(im, 7, 11, 14, 22, C("14121a"))     # ventana del numero
    rect(im, 8, 3, 13, 8, C("8a6a2a"))
    rect(im, 8, 3, 13, 4, C("c9a24a"))
    return outline(padded(im))


def diary_page():
    """Pagina arrancada del diario, pegada al muro; el numero lo pone el juego encima."""
    im = new(22, 26)
    rect(im, 2, 2, 19, 23, C("efe6cf"))
    rect(im, 2, 2, 19, 3, C("fffbe9"))
    rect(im, 17, 4, 19, 23, C("c9bd9d"))
    rect(im, 8, 0, 13, 4, C("c9c4d0"))   # chincheta
    px(im, 10, 1, C("e0525a"))
    for y in (18, 20, 22):
        rect(im, 5, y, 14, y, C("a39a82"))
    return outline(padded(im))


# ------------------------------------------------------------------ esfinge
def sphinx():
    im = new(72, 60)
    st, stl, std = C("d6b87a"), C("f0d9a0"), C("a38a52")
    glans = C("e8a090")
    # cuerpo de leon echado
    rect(im, 6, 36, 62, 52, st)
    rect(im, 6, 36, 62, 38, stl)
    rect(im, 6, 49, 62, 52, std)
    ellipse(im, 10, 44, 6, 9, st)
    ellipse(im, 62, 44, 6, 9, std)
    # patas delanteras
    rect(im, 4, 46, 28, 54, st)
    rect(im, 4, 46, 28, 47, stl)
    rect(im, 4, 52, 28, 54, std)
    for x in (10, 16, 22):
        line(im, x, 49, x, 54, std)
    # pecho y cuello
    rect(im, 22, 24, 40, 40, st)
    rect(im, 22, 24, 24, 40, stl)
    # cabeza con klaft (panuelo) rayado
    rect(im, 18, 14, 44, 34, C("2f5fa8"))
    for x in range(19, 44, 4):
        line(im, x, 15, x, 34, C("e8c76a"))
    rect(im, 25, 18, 37, 32, stl)       # cara
    rect(im, 25, 18, 27, 32, st)
    rect(im, 27, 22, 29, 23, OL)        # ojos
    rect(im, 33, 22, 35, 23, OL)
    line(im, 28, 28, 34, 28, OL)        # sonrisa picara
    px(im, 27, 27, OL)
    px(im, 35, 27, OL)
    # corona: un glande XL, como corresponde a Penelandia
    ellipse(im, 31, 9, 10, 8, glans)
    rect(im, 22, 10, 40, 14, glans)
    ellipse(im, 29, 6, 4, 3, mix(glans, WHITE, 0.4))
    line(im, 31, 2, 31, 8, dk(glans, 0.6))   # hendidura
    rect(im, 21, 14, 41, 15, C("c9a24a"))
    # cola
    line(im, 62, 44, 68, 34, std)
    line(im, 63, 44, 69, 34, std)
    disc(im, 68, 32, 2.5, std)
    return outline(padded(im))


def main():
    save(glyph_sun(), OUT / "glyph_sun.png")
    save(glyph_moon(), OUT / "glyph_moon.png")
    save(golf_ball(), OUT / "golf_ball.png")
    save(golf_hole(), OUT / "golf_hole.png")
    save(golf_flag(), OUT / "golf_flag.png")
    save(golf_block(), OUT / "golf_block.png")
    save(golf_pit(), OUT / "golf_pit.png")
    save(track_print(), OUT / "track_print.png")
    save(mud_patch(), OUT / "mud_patch.png")
    save(track_sack(), OUT / "track_sack.png")
    save(track_hole(), OUT / "track_hole.png")
    save(diary_book(False), OUT / "diary_closed.png")
    save(diary_book(True), OUT / "diary_open.png")
    save(dial_post(), OUT / "dial_post.png")
    save(diary_page(), OUT / "diary_page.png")
    save(sphinx(), OUT / "sphinx.png")
    print("listo")


if __name__ == "__main__":
    main()
