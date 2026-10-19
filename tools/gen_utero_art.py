"""Arte de EL UTERO (etapa V): Dona Regla (80x120 + SpriteFrames) y folículo.

Uso: python3 tools/gen_utero_art.py [regla|foliculo|intro|intro_pil ...]   (sin args = todo menos intro)
  regla     assets/sprites/enemies/regla_<anim>_NN.png + regla_sprite_frames.tres
  foliculo  assets/sprites/utero/foliculo.png
  intro     presentacion a pantalla completa assets/sprites/ui/bosses/regla.png con Gemini (UNA llamada;
            reusa tools/gen_boss_art.py / gen_intro_art.py y la key de ~/.kaggle/gemini_key)
  intro_pil lo mismo dibujado con Pillow (por si falla la cuota)
Mismo estilo que gen_enemy_art.py: poligonos a 1x y contorno automatico #0d0b0f.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_enemy_art as G  # noqa: E402

ROOT = G.ROOT
OUT = G.OUT

DRESS = (200, 38, 62, 255)
DRESS_HI = (244, 96, 112, 255)
DRESS_DK = (130, 20, 44, 255)
SKIN = (250, 208, 184, 255)
SKIN_DK = (220, 160, 140, 255)
HAIR = (96, 52, 40, 255)
HAIR_HI = (140, 84, 60, 255)
WOOD = (236, 204, 124, 255)
WOOD_HI = (255, 236, 168, 255)
WOOD_DK = (176, 132, 68, 255)
INK = (40, 24, 20, 255)
PAPER = (252, 246, 232, 255)
SHOE = (60, 40, 70, 255)
GLASS = (255, 255, 255, 255)


def ruler(angle=0.0, hand=(62, 70)):
    """La regla de 2 m (vertical, sostenida por la mano) girada `angle` grados alrededor de la mano."""
    layer = Image.new("RGBA", (80, 120), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.rectangle([58, 2, 67, 114], fill=WOOD)
    d.rectangle([58, 2, 59, 114], fill=WOOD_HI)
    d.rectangle([66, 2, 67, 114], fill=WOOD_DK)
    for i, y in enumerate(range(5, 113, 3)):  # marcas de centimetro: largas cada 5
        long_ = i % 5 == 0
        d.line([(60, y), (63 if long_ else 61, y)], fill=INK)
    d.rectangle([58, 2, 67, 114], outline=INK)
    if angle:
        layer = layer.rotate(angle, resample=Image.NEAREST, center=hand)
    return layer


def regla(bob=0, legs=(0, 0), lean=0, eyes="angry", mouth="stern", rul=0.0, arm="down", flash=0):
    im = Image.new("RGBA", (80, 120), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    b = bob
    # piernas y zapatos
    for i, off in enumerate(legs):
        x = 30 + i * 14
        d.rectangle([x, 104 + b, x + 5, 114 - abs(off)], fill=SKIN_DK)
        d.rectangle([x - 1, 113 - abs(off), x + 7, 116 - abs(off)], fill=SHOE)
    # vestido: campana roja con volante y pliegues
    d.polygon([(26 + lean, 54 + b), (54 + lean, 54 + b), (62, 108 + b), (18, 108 + b)], fill=DRESS)
    d.polygon([(26 + lean, 54 + b), (34 + lean, 54 + b), (28, 108 + b), (18, 108 + b)], fill=DRESS_DK)
    d.polygon([(46 + lean, 54 + b), (54 + lean, 54 + b), (62, 108 + b), (52, 108 + b)], fill=DRESS_HI)
    d.line([(40, 66 + b), (40, 106 + b)], fill=DRESS_DK)
    d.rectangle([18, 104 + b, 62, 108 + b], fill=DRESS_DK)
    d.rectangle([30 + lean, 54 + b, 50 + lean, 58 + b], fill=PAPER)  # cuello blanco
    d.ellipse([37 + lean, 57 + b, 43 + lean, 62 + b], fill=DRESS_DK)  # boton
    # brazo izquierdo con un calendario
    d.polygon([(28 + lean, 58 + b), (23 + lean, 60 + b), (17, 76 + b), (21, 78 + b)], fill=DRESS)
    d.rectangle([7, 66 + b, 22, 84 + b], fill=PAPER)
    d.rectangle([7, 66 + b, 22, 71 + b], fill=DRESS)
    for gy in range(74, 84, 3):
        for gx in range(9, 21, 3):
            d.point((gx, gy + b), fill=INK)
    d.rectangle([14, 74 + b, 16, 76 + b], fill=DRESS)  # el dia marcado
    d.ellipse([16, 74 + b, 22, 80 + b], fill=SKIN)  # mano
    # cabeza
    d.ellipse([24 + lean, 17 + b, 56 + lean, 53 + b], fill=SKIN)
    d.ellipse([24 + lean, 38 + b, 56 + lean, 53 + b], fill=SKIN)
    d.ellipse([28 + lean, 44 + b, 36 + lean, 50 + b], fill=(250, 150, 160, 255))  # colorete
    d.ellipse([44 + lean, 44 + b, 52 + lean, 50 + b], fill=(250, 150, 160, 255))
    # pelo: casquete y mono
    d.pieslice([23 + lean, 13 + b, 57 + lean, 47 + b], 180, 360, fill=HAIR)
    d.ellipse([31 + lean, 3 + b, 49 + lean, 21 + b], fill=HAIR)
    d.ellipse([34 + lean, 5 + b, 41 + lean, 11 + b], fill=HAIR_HI)
    d.rectangle([34 + lean, 20 + b, 46 + lean, 22 + b], fill=DRESS)  # cinta roja
    # lentes redondos
    for cx in (33, 47):
        d.ellipse([cx - 5 + lean, 29 + b, cx + 5 + lean, 39 + b], fill=GLASS, outline=INK)
        if eyes == "x":
            d.line([(cx - 3 + lean, 31 + b), (cx + 3 + lean, 37 + b)], fill=INK)
            d.line([(cx - 3 + lean, 37 + b), (cx + 3 + lean, 31 + b)], fill=INK)
        else:
            d.rectangle([cx - 1 + lean, 32 + b, cx + 2 + lean, 36 + b], fill=INK)
    d.line([(38 + lean, 33 + b), (42 + lean, 33 + b)], fill=INK)  # puente
    if eyes == "angry":
        d.line([(27 + lean, 26 + b), (38 + lean, 30 + b)], fill=INK, width=2)
        d.line([(53 + lean, 26 + b), (42 + lean, 30 + b)], fill=INK, width=2)
    # boca
    if mouth == "open":
        d.ellipse([36 + lean, 43 + b, 44 + lean, 50 + b], fill=(120, 24, 40, 255))
    else:
        d.rectangle([35 + lean, 45 + b, 45 + lean, 46 + b], fill=(150, 30, 50, 255))
    # regla + brazo derecho (hacia la regla)
    sx, sy = 54 + lean, 58 + b
    hx, hy = 62, (72 if arm == "down" else 58) + b
    d.line([(sx, sy), (hx, hy)], fill=DRESS, width=5)
    layer = ruler(rul, (hx, hy))
    if b:
        layer = layer.transform(layer.size, Image.AFFINE, (1, 0, 0, 0, 1, -b), resample=Image.NEAREST)
    im.alpha_composite(layer)
    d2 = ImageDraw.Draw(im)
    d2.ellipse([hx - 4, hy - 3, hx + 4, hy + 4], fill=SKIN)  # el puno sobre la regla
    out = G.outline(im)
    if flash:
        out = G.tint(out, (255, 255, 255), 0.55)
    return out


def frames_regla():
    idle = regla(0)
    walk = [regla(0, (3, 0)), regla(-1, (0, 0), 0), regla(0, (0, 3)), regla(-1, (0, 0), 0)]
    attack = [regla(0, rul=-14, arm="up", mouth="open"), regla(-1, rul=-60, arm="up", mouth="open", lean=-2),
              regla(1, rul=-100, arm="up", mouth="open", lean=-3)]
    hurt = [regla(2, lean=-3, eyes="x", mouth="open", flash=1), regla(1, lean=-2, eyes="x", mouth="open")]
    dead = regla(0, eyes="x", mouth="open")
    death = [G.death_frame(dead, i, center=(40, 112)) for i in range(4)]
    return {"idle": [idle], "walk": walk, "attack": attack, "hurt": hurt, "death": death}


def make_regla():
    anims = frames_regla()
    for name, frames in anims.items():
        for i, im in enumerate(frames):
            im.save(OUT / f"regla_{name}_{i:02d}.png")
    G.write_frames_tres("regla", anims)
    print("ok regla", sum(len(f) for f in anims.values()), "frames")


# ------------------------------------------------------------------ folículo (28x36)
def make_foliculo():
    im = Image.new("RGBA", (28, 36), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.line([(14, 22), (14, 34)], fill=(70, 150, 80, 255), width=2)      # tallito
    d.polygon([(14, 30), (7, 27), (9, 32)], fill=(96, 190, 100, 255))   # hojas
    d.polygon([(14, 32), (21, 29), (19, 34)], fill=(96, 190, 100, 255))
    d.ellipse([2, 1, 25, 26], fill=(255, 190, 214, 255))                # cuerpo hinchado
    d.ellipse([2, 12, 25, 26], fill=(255, 190, 214, 255))
    d.ellipse([5, 4, 22, 22], fill=(255, 228, 238, 255))                # liquido folicular
    d.ellipse([10, 9, 17, 16], fill=(255, 250, 214, 255))               # el ovocito
    d.ellipse([12, 11, 15, 14], fill=(255, 196, 80, 255))
    d.ellipse([7, 6, 11, 10], fill=(255, 255, 255, 255))                # brillo
    d.arc([2, 1, 25, 26], 200, 330, fill=(214, 100, 150, 255))
    im = G.outline(im)
    (ROOT / "assets/sprites/utero").mkdir(parents=True, exist_ok=True)
    im.save(ROOT / "assets/sprites/utero/foliculo.png")
    print("ok foliculo")


# ------------------------------------------------------------------ presentacion a pantalla completa
PROMPT = ("A dramatic boss reveal: the boss from the reference, a stern tall lady-shaped ruler creature in a red dress with a "
          "brown hair bun, round glasses and a huge two-meter wooden ruler with black tick marks in one hand and a paper "
          "calendar in the other, towering in a warm red-pink tissue chamber of the uterus: soft wavy walls, red mist, floating "
          "calendar pages and little clocks. Low camera angle, strict and punctual, comic villain pose. ")


def make_intro_gemini():
    import gen_intro_art as g
    g.SHEETS["regla"] = ["enemies/regla_idle_00"]
    g.SCREENS["regla"] = (PROMPT + g.CREATURES + "Do not write the boss name or any text. Dark vignette at the bottom third. ",
                          ["sheet:regla"])
    raw = g.RAW / "regla.png"
    if not raw.exists():
        raw = g.generate("regla")
    g.pixelate(raw, "regla")
    src = g.ROOT / "assets/sprites/ui/screens/regla.png"
    dst = g.ROOT / "assets/sprites/ui/bosses/regla.png"
    dst.parent.mkdir(parents=True, exist_ok=True)
    src.replace(dst)
    print("ok intro (gemini)")


def make_intro_pil():
    """Plan B sin red: escena de 320x180 con la sprite agrandada sobre un fondo de camara roja."""
    W, H = 320, 180
    im = Image.new("RGB", (W, H), (120, 28, 52))
    d = ImageDraw.Draw(im)
    for y in range(H):  # degradado: rojo oscuro arriba, rosa abajo
        k = y / H
        d.line([(0, y), (W, y)], fill=(int(110 + 90 * k), int(24 + 40 * k), int(50 + 50 * k)))
    for i in range(7):  # paredes ondulantes
        x = i * 54 - 10
        d.ellipse([x, -40, x + 70, 150], outline=(230, 110, 130), width=3)
        d.ellipse([x + 14, -20, x + 56, 130], outline=(190, 70, 100), width=2)
    for i in range(9):  # paginas de calendario flotando
        x, y = 14 + i * 36, 18 + (i * 37) % 70
        d.rectangle([x, y, x + 14, y + 16], fill=(252, 246, 232), outline=(40, 24, 20))
        d.rectangle([x, y, x + 14, y + 4], fill=(200, 38, 62))
    sp = Image.open(OUT / "regla_idle_00.png").convert("RGBA")
    sp = sp.crop(sp.getbbox())
    k = 1.45 * H / sp.height
    sp = sp.resize((int(sp.width * k), int(sp.height * k)), Image.NEAREST)
    im.paste(sp, ((W - sp.width) // 2, H - sp.height + 30), sp)
    vig = Image.new("L", (W, H), 0)
    vd = ImageDraw.Draw(vig)
    for y in range(H // 2, H):
        vd.line([(0, y), (W, y)], fill=int(150 * (y - H // 2) / (H // 2)))
    im.paste((10, 4, 12), mask=vig)
    dst = ROOT / "assets/sprites/ui/bosses/regla.png"
    dst.parent.mkdir(parents=True, exist_ok=True)
    im.save(dst)
    print("ok intro (pil)")


if __name__ == "__main__":
    todo = sys.argv[1:] or ["regla", "foliculo"]
    for t in todo:
        {"regla": make_regla, "foliculo": make_foliculo,
         "intro": make_intro_gemini, "intro_pil": make_intro_pil}[t]()
