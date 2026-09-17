"""Genera el arte placeholder del prototipo (PNG 16x16 estilo pixel art).

Se ejecuta con:  python3 tools/gen_placeholder_art.py
Cuando tengamos arte real, basta con sobreescribir los PNG de assets/sprites/.
"""
from PIL import Image, ImageDraw
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")

# --- Paleta -----------------------------------------------------------------
T    = (0, 0, 0, 0)
OUT  = (26, 20, 32, 255)       # contorno
SKIN = (240, 192, 144, 255)
ARM  = (74, 122, 192, 255)     # armadura azul
ARMD = (46, 77, 128, 255)
GRN  = (106, 192, 74, 255)
GRND = (63, 122, 46, 255)
FLR  = (58, 53, 80, 255)
FLR2 = (49, 45, 69, 255)
WAL  = (107, 95, 138, 255)
WALD = (69, 61, 94, 255)
MET  = (190, 195, 205, 255)
METD = (110, 116, 132, 255)
YEL  = (255, 214, 102, 255)
RED  = (222, 72, 84, 255)
REDD = (150, 40, 55, 255)
CYAN = (110, 220, 235, 255)
WHT  = (255, 255, 255, 255)

PALETTE = {
    ".": T, "o": OUT, "s": SKIN,
    "b": ARM, "B": ARMD,
    "g": GRN, "G": GRND,
    "m": MET, "M": METD,
    "y": YEL, "r": RED, "R": REDD,
    "c": CYAN, "w": WHT,
}


def from_grid(rows, size=16):
    """Convierte una rejilla de caracteres en una imagen RGBA."""
    img = Image.new("RGBA", (size, size), T)
    px = img.load()
    for y, row in enumerate(rows[:size]):
        row = row.ljust(size, ".")[:size]
        for x, ch in enumerate(row):
            px[x, y] = PALETTE[ch]
    return img


def outline(img, color=OUT):
    """Anade un contorno de 1px alrededor de todo pixel opaco."""
    w, h = img.size
    src = img.copy()
    sp, dp = src.load(), img.load()
    for y in range(h):
        for x in range(w):
            if sp[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and sp[nx, ny][3] != 0:
                    dp[x, y] = color
                    break
    return img


def save(img, name):
    path = os.path.normpath(os.path.join(OUT_DIR, name))
    img.save(path)
    print("  ", os.path.relpath(path, os.path.join(OUT_DIR, "..", "..")))


# --- Jugador (caballero, vista 3/4 mirando a camara) ------------------------
# 'h'/'H' = casco metalico (se traducen a m/M antes de pintar).
player = from_grid([r.replace("h", "m").replace("H", "M") for r in [
    "................",
    ".....oooooo.....",
    "....ohhhhhho....",
    "...ohhhhhhhho...",
    "...oHssssssHo...",
    "...oHssssssHo...",
    "....ohhhhhho....",
    "...obbbbbbbbo...",
    "..obbbbbbbbbbo..",
    "..obBbbbbbbBbo..",
    "..obBbbbbbbBbo..",
    "..oobbbbbbbboo..",
    "...obbbbbbbbo...",
    "...oBBo..oBBo...",
    "...oBBo..oBBo...",
    "....oo....oo....",
]])
save(player, "player.png")

# --- Slime ------------------------------------------------------------------
slime = Image.new("RGBA", (16, 16), T)
d = ImageDraw.Draw(slime)
d.ellipse([2, 4, 13, 13], fill=GRN)
d.rectangle([2, 12, 13, 13], fill=GRND)
d.ellipse([2, 10, 13, 14], fill=GRND)
d.ellipse([2, 4, 13, 11], fill=GRN)
d.rectangle([5, 8, 6, 9], fill=OUT)     # ojo izquierdo
d.rectangle([9, 8, 10, 9], fill=OUT)    # ojo derecho
d.point((4, 6), fill=WHT)               # brillo
d.point((5, 6), fill=WHT)
save(outline(slime), "slime.png")

# --- Bala del jugador (proyectil de energia) --------------------------------
bullet = Image.new("RGBA", (8, 8), T)
d = ImageDraw.Draw(bullet)
d.ellipse([1, 2, 6, 5], fill=YEL)
d.ellipse([2, 3, 4, 4], fill=WHT)
save(outline(bullet), "bullet.png")

# --- Bala enemiga -----------------------------------------------------------
ebullet = Image.new("RGBA", (8, 8), T)
d = ImageDraw.Draw(ebullet)
d.ellipse([1, 1, 6, 6], fill=RED)
d.ellipse([2, 2, 4, 4], fill=(255, 170, 180, 255))
save(outline(ebullet), "bullet_enemy.png")

# --- Pistola (apunta a la derecha; la empunadura queda en x=5) --------------
# Se dibuja dentro de un lienzo de 16x16 pero ocupa solo ~9px de largo, para
# que quede proporcionada frente a un personaje de 16px de alto.
gun = Image.new("RGBA", (16, 16), T)
d = ImageDraw.Draw(gun)
d.rectangle([4, 8, 6, 11], fill=METD)    # empunadura
d.rectangle([3, 6, 8, 8], fill=MET)      # cuerpo
d.rectangle([8, 6, 11, 7], fill=METD)    # canon
d.point((4, 7), fill=WHT)
save(outline(gun), "pistol.png")

# --- Iconos de HUD ----------------------------------------------------------
heart = from_grid([
    "..oo..oo..",
    ".orroorro.",
    "orrrrrrrro",
    "orrrrrrrro",
    "oRrrrrrrRo",
    ".oRrrrrRo.",
    "..oRrrRo..",
    "...oRRo...",
    "....oo....",
    "..........",
], size=10)
save(heart, "heart.png")

shield = from_grid([
    "..oooooo..",
    ".occcccco.",
    "occcccccco",
    "occcccccco",
    ".occcccco.",
    ".occcccco.",
    "..occcco..",
    "...occo...",
    "....oo....",
    "..........",
], size=10)
save(shield, "shield.png")

# --- Atlas de tiles: 0=suelo 1=suelo alt 2=muro 3=remate de muro ------------
tiles = Image.new("RGBA", (16 * 4, 16), T)
d = ImageDraw.Draw(tiles)
# 0: suelo liso
d.rectangle([0, 0, 15, 15], fill=FLR)
d.rectangle([0, 0, 15, 0], fill=FLR2)
d.rectangle([0, 0, 0, 15], fill=FLR2)
# 1: suelo con grietas
d.rectangle([16, 0, 31, 15], fill=FLR)
d.rectangle([16, 0, 31, 0], fill=FLR2)
d.rectangle([16, 0, 16, 15], fill=FLR2)
for p in [(20, 5), (21, 6), (22, 6), (23, 7), (26, 11), (27, 11), (25, 12)]:
    d.point(p, fill=FLR2)
# 2: muro (cuerpo)
d.rectangle([32, 0, 47, 15], fill=WALD)
d.rectangle([33, 1, 46, 14], fill=WAL)
d.rectangle([33, 1, 46, 2], fill=(128, 116, 160, 255))
# 3: remate superior del muro
d.rectangle([48, 0, 63, 15], fill=WALD)
d.rectangle([48, 0, 63, 5], fill=(138, 126, 172, 255))
d.rectangle([48, 6, 63, 7], fill=(90, 80, 118, 255))
save(tiles, "tiles.png")

print("Listo.")
