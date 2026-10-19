"""Iconos 24x24 de las armas de la etapa 6d y sus proyectiles (pixel art por script).

Uso: python3 tools/gen_weapon_art_6d.py [id ...]   (sin args = todo)
Armas apuntando a la derecha (empunadura a la izquierda), como las existentes.
Mismo estilo que tools/gen_item_art.py (primitivas de Pillow + contorno #0d0b0f).
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_item_art import OUT, _c, _new, _outline  # noqa: E402

PROJ = OUT.parent / "projectiles"


def art_laser_depilador():
    im, d = _new()
    body, hi, dark = _c(255, 150, 214), _c(255, 214, 236), _c(176, 60, 140)
    metal, mdark = _c(216, 221, 227), _c(110, 114, 130)
    d.rounded_rectangle([2, 10, 9, 20], radius=2, fill=dark)               # empunadura
    d.line([(3, 11), (3, 19)], fill=body)
    d.rounded_rectangle([5, 6, 18, 13], radius=2, fill=body)               # cuerpo
    d.line([(6, 7), (17, 7)], fill=hi)
    d.rectangle([9, 9, 12, 11], fill=_c(60, 20, 40))                       # visor
    d.point([(10, 10)], fill=_c(120, 240, 255))
    d.rectangle([18, 8, 21, 11], fill=metal)                               # boca del rayo
    d.rectangle([18, 11, 21, 11], fill=mdark)
    d.point([(22, 9), (22, 10)], fill=_c(255, 90, 90))                     # haz rojo
    d.point([(23, 9), (23, 10)], fill=_c(255, 200, 120))
    d.rectangle([13, 4, 15, 6], fill=mdark)                                # aletas de calor
    d.line([(13, 4), (15, 4)], fill=metal)
    return _outline(im)


def art_boomerang_silicona():
    im, d = _new()
    body, hi, dark = _c(255, 106, 140), _c(255, 178, 196), _c(176, 40, 84)
    a = [(4, 18), (4, 8), (8, 4), (13, 3)]
    b = [(4, 18), (10, 20), (17, 18), (20, 12)]
    for pts in (a, b):
        d.line(pts, fill=dark, width=5)
        d.line(pts, fill=body, width=3)
    d.line([(4, 15), (4, 9), (8, 5), (12, 4)], fill=hi, width=1)
    d.line([(6, 18), (10, 19), (16, 17)], fill=hi, width=1)
    d.point([(4, 17), (5, 18)], fill=_c(255, 235, 240))
    return _outline(im)


def art_globos_agua():
    im, d = _new()
    metal, mdark = _c(216, 221, 227), _c(110, 114, 130)
    water, wh = _c(80, 170, 255), _c(190, 230, 255)
    d.rounded_rectangle([2, 12, 8, 21], radius=2, fill=mdark)              # empunadura
    d.rectangle([7, 10, 16, 14], fill=metal)                               # tubo
    d.line([(7, 10), (16, 10)], fill=_c(255, 255, 255))
    d.line([(7, 14), (16, 14)], fill=mdark)
    d.ellipse([15, 3, 23, 13], fill=water)                                 # globo
    d.ellipse([16, 4, 19, 7], fill=wh)
    d.polygon([(14, 10), (16, 9), (16, 13)], fill=_c(40, 110, 220))        # nudo
    d.point([(21, 14), (22, 16)], fill=wh)                                 # gotitas
    return _outline(im)


def art_tarro_masilla():
    im, d = _new()
    can, ch, cd = _c(150, 168, 150), _c(196, 212, 190), _c(88, 104, 92)    # lata gris-verdosa
    lid, lh, ld = _c(216, 221, 227), _c(255, 255, 255), _c(110, 114, 130)  # tapa metalica
    putty, ph = _c(168, 182, 150), _c(214, 226, 196)
    d.rounded_rectangle([3, 9, 16, 21], radius=2, fill=can)                # cuerpo del tarro
    d.line([(4, 11), (4, 19)], fill=ch)
    d.line([(15, 11), (15, 20)], fill=cd)
    d.line([(4, 20), (15, 20)], fill=cd)
    d.rectangle([5, 12, 14, 17], fill=_c(232, 200, 70))                    # etiqueta
    d.rectangle([5, 14, 14, 15], fill=_c(200, 60, 50))
    d.point([(7, 13), (9, 13), (11, 13)], fill=_c(80, 60, 20))
    d.rounded_rectangle([2, 6, 17, 10], radius=1, fill=lid)                # tapa
    d.line([(3, 7), (16, 7)], fill=lh)
    d.line([(3, 10), (16, 10)], fill=ld)
    d.ellipse([4, 3, 14, 7], fill=putty)                                   # masilla asomando
    d.line([(6, 4), (11, 4)], fill=ph)
    d.line([(17, 18), (22, 5)], fill=_c(120, 78, 44), width=2)             # mango de la espatula
    d.polygon([(19, 6), (23, 2), (23, 8), (20, 9)], fill=lid)              # hoja
    d.line([(21, 3), (22, 3)], fill=lh)
    return _outline(im)


def art_ballesta_tantrica():
    im, d = _new()
    wood, wh, wd = _c(168, 108, 60), _c(214, 156, 96), _c(98, 60, 34)
    cord = _c(240, 236, 220)
    d.line([(13, 3), (16, 12), (13, 21)], fill=wd, width=3)                # arco
    d.line([(13, 4), (16, 12), (13, 20)], fill=wood, width=1)
    d.line([(13, 3), (7, 12), (13, 21)], fill=cord)                        # cuerda tensa
    d.rectangle([2, 11, 19, 13], fill=wood)                                # cureña
    d.line([(2, 11), (19, 11)], fill=wh)
    d.rectangle([2, 13, 5, 16], fill=wd)                                   # culata
    d.polygon([(19, 10), (23, 12), (19, 14)], fill=_c(216, 221, 227))      # punta del virote
    d.point([(21, 12)], fill=_c(255, 255, 255))
    d.rectangle([8, 9, 9, 10], fill=_c(232, 70, 70))                       # plumas
    return _outline(im)


def art_canon_confeti():
    im, d = _new()
    tube, hi, dark = _c(255, 214, 90), _c(255, 240, 160), _c(190, 130, 30)
    d.polygon([(2, 15), (4, 8), (16, 5), (22, 3), (22, 15), (16, 14)], fill=tube)   # cono
    d.line([(5, 9), (17, 6)], fill=hi)
    d.line([(3, 15), (16, 14)], fill=dark)
    d.rectangle([6, 8, 8, 14], fill=_c(255, 90, 140))                      # franjas
    d.rectangle([11, 7, 13, 14], fill=_c(90, 200, 255))
    d.rectangle([2, 15, 7, 21], fill=dark)                                 # mango
    for x, y, c in ((19, 1, (255, 90, 140)), (22, 6, (90, 220, 150)), (21, 18, (90, 160, 255)),
                    (23, 11, (255, 120, 60)), (17, 20, (255, 255, 255)), (20, 14, (255, 90, 140))):
        d.rectangle([x, y, x + 1, y], fill=_c(*c))
    return _outline(im)


def art_preservativo_atrapabalas():
    im, d = _new()
    metal, mdark = _c(216, 221, 227), _c(110, 114, 130)
    latex, lh = _c(120, 230, 200), _c(200, 255, 240)
    d.rounded_rectangle([2, 12, 8, 21], radius=2, fill=mdark)              # empunadura
    d.rectangle([7, 10, 13, 14], fill=metal)                               # boquilla
    d.line([(7, 10), (13, 10)], fill=_c(255, 255, 255))
    d.ellipse([12, 4, 23, 17], fill=latex)                                 # condon inflado
    d.ellipse([14, 6, 18, 10], fill=lh)
    d.ellipse([19, 9, 21, 11], fill=_c(60, 130, 120))                      # bala atrapada
    d.rectangle([12, 9, 14, 12], fill=_c(60, 160, 140))                    # aro de la base
    return _outline(im)


def art_chancleta_voladora():
    im, d = _new()
    sole, sd, strap = _c(232, 160, 80), _c(150, 90, 40), _c(70, 130, 220)
    d.rounded_rectangle([3, 7, 22, 16], radius=4, fill=sole)               # suela
    d.line([(5, 8), (20, 8)], fill=_c(255, 214, 150))
    d.line([(4, 16), (21, 16)], fill=sd)
    d.polygon([(8, 7), (10, 7), (14, 12), (10, 16), (8, 16), (11, 12)], fill=strap)  # correa en Y
    d.polygon([(13, 7), (15, 7), (16, 12)], fill=strap)
    d.point([(11, 12)], fill=_c(160, 200, 255))
    d.point([(19, 11), (18, 13)], fill=sd)                                 # desgaste
    d.line([(0, 4), (3, 5)], fill=_c(255, 255, 255))                       # lineas de velocidad
    d.line([(0, 19), (3, 18)], fill=_c(255, 255, 255))
    return _outline(im)


ART = {n[4:]: f for n, f in globals().items() if n.startswith("art_")}


def _proj(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def proj_boomerang():
    im = _proj(16, 16)
    d = ImageDraw.Draw(im)
    body, hi, dark = _c(255, 106, 140), _c(255, 178, 196), _c(176, 40, 84)
    for pts in ([(3, 13), (3, 6), (7, 3), (12, 3)], [(3, 13), (8, 14), (13, 12)]):
        d.line(pts, fill=dark, width=4)
        d.line(pts, fill=body, width=2)
    d.point([(3, 8), (6, 4)], fill=hi)
    return _outline(im)


def proj_water_balloon():
    im = _proj(12, 14)
    d = ImageDraw.Draw(im)
    d.ellipse([1, 1, 10, 11], fill=_c(80, 170, 255))
    d.ellipse([3, 3, 5, 5], fill=_c(200, 235, 255))
    d.polygon([(4, 11), (7, 11), (6, 13), (5, 13)], fill=_c(40, 110, 220))
    return _outline(im)


def proj_tarro_masilla():
    im = _proj(14, 14)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([2, 4, 11, 12], radius=1, fill=_c(150, 168, 150))
    d.line([(3, 6), (3, 11)], fill=_c(196, 212, 190))
    d.rectangle([3, 7, 10, 9], fill=_c(232, 200, 70))
    d.rectangle([1, 2, 12, 4], fill=_c(216, 221, 227))
    d.line([(2, 2), (11, 2)], fill=_c(255, 255, 255))
    d.ellipse([3, 0, 9, 3], fill=_c(168, 182, 150))
    return _outline(im)


def proj_condom_bubble():
    im = _proj(40, 40)
    d = ImageDraw.Draw(im)
    d.ellipse([3, 3, 36, 36], fill=(120, 230, 200, 70), outline=(190, 255, 235, 230), width=2)
    d.ellipse([9, 8, 17, 14], fill=(235, 255, 250, 200))
    d.arc([6, 6, 33, 33], 200, 250, fill=(255, 255, 255, 230), width=2)
    return im


def proj_confetti():
    im = _proj(4, 4)
    for x in range(4):
        for y in range(4):
            im.putpixel((x, y), (255, 255, 255, 255))
    return im


PROJS = {n[5:]: f for n, f in globals().items() if n.startswith("proj_")}

if __name__ == "__main__":
    names = sys.argv[1:]
    for name in names or list(ART):
        if name in ART:
            ART[name]().save(OUT / f"{name}.png")
            print("ok", name)
    for name in names or list(PROJS):
        if name in PROJS:
            PROJS[name]().save(PROJ / f"{name}.png")
            print("ok proj", name)
