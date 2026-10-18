"""Genera el arte de los guiños pequeños a Vanessa (assets/sprites/guinos/).

Uso: python3 tools/gen_guinos_art.py
Biblia (historia.md, seccion 7): discretos, nunca en el texto del narrador.
  graffiti_v_es.png / graffiti_v_en.png  "V. ESTUVO AQUI" / "V. WAS HERE" pintado en spray rosa,
                                         con un par de chorreones (se cuelga de la cara de un muro)
  nota.png                               notita doblada que queda en el suelo bajo el jefe final
  estante_archivo.png                    estante del Archivo Clasificado: tomos tachados con barra
                                         negra y UNO sin tachar ("Manual de Educacion Sexual, V.")
Arte a 1x, contorno oscuro y luz arriba-izquierda, igual que gen_decor_art.py. Determinista.
"""
from pathlib import Path

from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets/sprites/guinos"
CLEAR = (0, 0, 0, 0)
OL = (13, 11, 15, 255)


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def new(w, h):
    return Image.new("RGBA", (w, h), CLEAR)


def put(im, x, y, c):
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), c)


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(im, x, y, c)


def outline(im, c=OL):
    src = im.copy()
    for y in range(im.height):
        for x in range(im.width):
            if src.getpixel((x, y))[3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < im.width and 0 <= yy < im.height and src.getpixel((xx, yy))[3] > 0:
                        im.putpixel((x, y), c)
                        break
    return im


def save(im, name):
    OUT.mkdir(parents=True, exist_ok=True)
    im.save(OUT / f"{name}.png")


# fuente 4x6 (solo lo que hace falta aqui; mas legible que la 3x5 de los carteles)
G = {
    "A": [".##.", "#..#", "#..#", "####", "#..#", "#..#"], "E": ["####", "#...", "###.", "#...", "#...", "####"],
    "H": ["#..#", "#..#", "####", "#..#", "#..#", "#..#"], "I": ["###.", ".#..", ".#..", ".#..", ".#..", "###."],
    "O": [".##.", "#..#", "#..#", "#..#", "#..#", ".##."], "Q": [".##.", "#..#", "#..#", "#..#", "#.#.", ".#.#"],
    "R": ["###.", "#..#", "###.", "#.#.", "#..#", "#..#"], "S": [".###", "#...", ".##.", "...#", "...#", "###."],
    "T": ["####", ".#..", ".#..", ".#..", ".#..", ".#.."], "U": ["#..#", "#..#", "#..#", "#..#", "#..#", ".##."],
    "V": ["#...#", "#...#", "#...#", ".#.#.", ".#.#.", "..#.."], "W": ["#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
    "L": ["#...", "#...", "#...", "#...", "#...", "####"],
    ".": ["....", "....", "....", "....", ".##.", ".##."], " ": ["....", "....", "....", "....", "....", "...."],
}
GH, GW = 6, 4


def glyph_pixels(s):
    """Pixeles (x, y) del texto con la fuente 4x6. 'Í' pone la tilde arriba (y=-1)."""
    pts = []
    x = 0
    for ch in s:
        acc = ch in "ÍÉÀ"
        g = G[{"Í": "I", "É": "E", "À": "A"}.get(ch, ch)]
        for gy in range(GH):
            for gx in range(len(g[0])):
                if g[gy][gx] == "#":
                    pts.append((x + gx, gy))
        if acc:
            pts += [(x + 1, -3), (x + 2, -2)] if ch == "À" else [(x + 2, -2), (x + 3, -3)]
        x += 3 if ch == " " else len(g[0]) + 1
    return pts


def graffiti(text):
    """Spray rosa con sombra oscura abajo-derecha, ligera pendiente y dos chorreones."""
    pts = glyph_pixels(text)
    w = max(p[0] for p in pts) + 1
    PINK, PINK_HI, PINK_SH = C("ff4f9a"), C("ffa0cb"), C("b02a6e")
    im = new(w + 5, 16)
    ox, oy = 2, 4
    # un renglon sube un pixel cada cierto tramo: pintado a mano alzada
    def dy(x):
        return 0 if x < w * 0.45 else (1 if x < w * 0.8 else 0)
    cols = {}
    for x, y in pts:
        cols.setdefault(x, []).append(y)
        put(im, ox + x + 1, oy + y + dy(x) + 1, PINK_SH)
    for x, y in pts:
        put(im, ox + x, oy + y + dy(x), PINK_HI if y == 0 else PINK)
    # chorreones: bajan desde la base de dos letras
    for x0, n in ((5, 3), (w - 6, 2)):
        ys = [y for y in cols.get(x0, []) if y == GH - 1]
        if not ys:
            x0 += 1
            ys = [y for y in cols.get(x0, []) if y == GH - 1]
        if ys:
            for k in range(1, n + 1):
                put(im, ox + x0, oy + GH - 1 + dy(x0) + k, PINK)
            put(im, ox + x0, oy + GH - 1 + dy(x0) + n + 1, PINK_SH)
    return im


def nota():
    """Notita doblada, ligeramente torcida, con garabatos de tinta y un corazoncito."""
    im = new(24, 18)
    PAPER, PAPER_HI, PAPER_SH = C("f6eed2"), C("fffbe8"), C("cdbf91")
    INK, RED = C("3a2a2a"), C("d8404a")
    # cuerpo (paralelogramo suave)
    for y in range(2, 15):
        shift = (y - 2) // 6
        rect(im, 2 + shift, y, 20 + shift, y, PAPER)
    for x in range(2, 22):
        put(im, x, 2, PAPER_HI)
    for y in range(2, 15):
        put(im, 2 + (y - 2) // 6, y, PAPER_HI)
        put(im, 20 + (y - 2) // 6, y, PAPER_SH)
    for x in range(3, 23):
        put(im, x, 14, PAPER_SH)
    # doblez central
    for y in range(3, 14):
        put(im, 11 + (y - 2) // 6, y, PAPER_SH)
    # renglones de "texto" y firma
    for i, yy in enumerate((5, 7, 9)):
        for x in range(5 + i % 2, 17 - (i * 2) % 5):
            if (x + i) % 5 != 0:
                put(im, x, yy, INK)
    # corazon
    for p in ((15, 11), (17, 11), (14, 12), (15, 12), (16, 12), (17, 12), (18, 12), (15, 13), (16, 13), (17, 13), (16, 14)):
        put(im, p[0], p[1], RED)
    return outline(im)


def estante():
    """Estante de 2 baldas (64x44: cabe bajo el muro): tomos grises con barra negra de censura y,
    abajo a la derecha, UNO sin tachar con "V." en el lomo."""
    W, H = 64, 44
    im = new(W, H)
    W_HI, W_BASE, W_SH, W_DEEP = C("b88850"), C("8a5c34"), C("5e3a20"), C("2a190d")
    rect(im, 1, 1, W - 2, H - 1, W_BASE)
    rect(im, 1, 1, W - 2, 2, W_HI)
    rect(im, 1, 1, 2, H - 1, W_HI)
    rect(im, W - 3, 3, W - 2, H - 1, W_SH)
    rect(im, 4, 4, W - 5, 19, W_DEEP)       # hueco de arriba
    rect(im, 4, 24, W - 5, H - 6, W_DEEP)   # hueco de abajo
    rect(im, 3, 20, W - 4, 23, W_HI)        # balda
    rect(im, 3, 23, W - 4, 23, W_SH)
    rect(im, 3, H - 5, W - 4, H - 3, W_HI)  # base
    rect(im, 3, H - 3, W - 4, H - 3, W_SH)
    GREYS = [(C("8d8d9c"), C("5e5e70")), (C("a7a39a"), C("6c685f")), (C("7e8aa0"), C("4c566a")),
             (C("9c8f86"), C("65584f")), (C("8fa093"), C("586859"))]

    def tomo_gris(x, top, bottom, w, k):
        base, sh = GREYS[k % len(GREYS)]
        rect(im, x, top, x + w - 1, bottom, base)
        rect(im, x + w - 1, top, x + w - 1, bottom, sh)
        rect(im, x, top, x, bottom, C("c9c9d6"))
        by = top + (bottom - top) // 2 - 1
        rect(im, x, by, x + w - 1, by + 2, OL)  # barra negra de censura cruzando el lomo

    x = 5
    for k, (w, h) in enumerate([(6, 13), (5, 14), (7, 11), (5, 14), (6, 13), (7, 12), (5, 10), (6, 14), (7, 13)]):
        if x + w > W - 6:
            break
        tomo_gris(x, 19 - h, 19, w, k)
        x += w + 1
    x = 5
    for k, (w, h) in enumerate([(7, 12), (5, 13), (6, 10), (5, 13), (7, 11)]):
        tomo_gris(x, H - 6 - h, H - 6, w, k + 2)
        x += w + 1
    # EL tomo: crema y rosado, SIN barra; "V." en el lomo, corazon y marcapaginas
    bx = x + 3
    top, bot = H - 6 - 14, H - 6
    rect(im, bx, top, bx + 11, bot, C("f6eed2"))
    rect(im, bx, top, bx + 1, bot, C("ff8fb0"))
    rect(im, bx + 11, top, bx + 11, bot, C("cdbf91"))
    rect(im, bx + 2, top, bx + 10, top, C("fffbe8"))
    for gy, row in enumerate(["#...#", "#...#", "#...#", ".#.#.", "..#.."]):
        for gx, ch in enumerate(row):
            if ch == "#":
                put(im, bx + 3 + gx, top + 2 + gy, C("b02a6e"))
    put(im, bx + 5, top + 8, C("b02a6e"))
    for p in ((bx + 4, top + 10), (bx + 6, top + 10), (bx + 4, top + 11), (bx + 5, top + 11), (bx + 6, top + 11), (bx + 5, top + 12)):
        put(im, p[0], p[1], C("d8404a"))
    rect(im, bx + 8, bot, bx + 9, bot + 1, C("ff4f9a"))  # marcapaginas que asoma
    return outline(im)


def main():
    save(graffiti("V. ESTUVO AQUÍ"), "graffiti_v_es")
    save(graffiti("V. WAS HERE"), "graffiti_v_en")
    save(graffiti("V. \u00c9TAIT L\u00c0"), "graffiti_v_fr")
    save(nota(), "nota")
    save(estante(), "estante_archivo")
    print("ok ->", OUT)


if __name__ == "__main__":
    main()
